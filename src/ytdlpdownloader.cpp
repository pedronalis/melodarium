#include "ytdlpdownloader.h"

#include "collectionmanager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

QString YtDlpDownloader::findFfmpeg()
{
    // yt-dlp looks for ffmpeg on PATH. When the app is launched from a .desktop file the
    // inherited PATH can be narrower than the user's shell, so we resolve it ourselves and
    // pass --ffmpeg-location only when we had to look it up.
    if (!QStandardPaths::findExecutable(QStringLiteral("ffmpeg")).isEmpty())
        return {};
    const QStringList extra = {QStringLiteral("/usr/bin"),
                               QStringLiteral("/usr/local/bin"),
                               QStringLiteral("/home/linuxbrew/.linuxbrew/bin")};
    const QString found = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"), extra);
    return found.isEmpty() ? QString() : QFileInfo(found).absolutePath();
}

QStringList YtDlpDownloader::buildArguments(const QUrl &url, const QString &destDir,
                                            const QString &ffmpegLocation)
{
    QStringList args;

    // bestaudio/best, not bestaudio alone: some videos expose no isolated audio stream, and
    // the fallback keeps those from failing with "requested format not available".
    args << QStringLiteral("-f") << QStringLiteral("bestaudio/best");

    // --audio-format best means "do not re-encode". Passing "mp3" here instead would transcode
    // audio that is ALREADY lossy (YouTube ships Opus at ~160 kbps), losing quality a second
    // time for nothing. The spec's hard requirement on audio is what forbids it, and the test
    // argumentsKeepTheQualityContract asserts "mp3" never reaches the argument list.
    args << QStringLiteral("--extract-audio") << QStringLiteral("--audio-format")
         << QStringLiteral("best");

    // Thumbnails come as webp; convert to jpg so tag readers and players actually show them.
    args << QStringLiteral("--embed-thumbnail") << QStringLiteral("--convert-thumbnails")
         << QStringLiteral("jpg") << QStringLiteral("--embed-metadata");

    args << QStringLiteral("--newline");
    // Fixed, self-defined progress format: parsing the human-readable bar with a regex breaks
    // across versions and locales.
    args << QStringLiteral("--progress-template")
         << QStringLiteral("download:MELODIA_PROGRESS %(progress.downloaded_bytes)s "
                           "%(progress.total_bytes)s");
    args << QStringLiteral("--no-playlist");
    args << QStringLiteral("-o") << QStringLiteral("%(title)s [%(id)s].%(ext)s");
    args << QStringLiteral("-P") << destDir;

    if (!ffmpegLocation.isEmpty())
        args << QStringLiteral("--ffmpeg-location") << ffmpegLocation;

    // The URL is the last argument and travels as its own list element: QProcess execs
    // directly with no shell, so quotes or semicolons in it cannot become commands.
    args << url.toString();
    return args;
}

bool YtDlpDownloader::parseProgressLine(const QString &line, qint64 *downloaded, qint64 *total)
{
    if (!line.startsWith(QStringLiteral("MELODIA_PROGRESS ")))
        return false;

    const QStringList parts = line.trimmed().split(QLatin1Char(' '), Qt::SkipEmptyParts);
    if (parts.size() < 3)
        return false;

    bool okDownloaded = false;
    const qint64 got = parts.at(1).toLongLong(&okDownloaded);
    if (!okDownloaded)
        return false;

    // total_bytes is "NA" when the server does not declare a size, and eta/speed arrive as
    // "None" on the first ticks. Unknown total becomes -1, never a parse failure.
    bool okTotal = false;
    const qint64 size = parts.at(2).toLongLong(&okTotal);

    if (downloaded)
        *downloaded = got;
    if (total)
        *total = okTotal ? size : -1;
    return true;
}

YtDlpDownloader::YtDlpDownloader(QObject *parent)
    : QObject(parent)
{
}

void YtDlpDownloader::probe()
{
    // Deliberately the yt-dlp on PATH, not a hardcoded /usr/bin/yt-dlp: the app calls whatever
    // the user installed, which is the whole point of not shipping the downloader. This
    // machine happens to have two (Homebrew on PATH, Fedora's in /usr/bin), which is exactly
    // why the version found is shown in the UI instead of assumed.
    QProcess probe;
    probe.start(QStringLiteral("yt-dlp"), {QStringLiteral("--version")});
    if (!probe.waitForStarted(2000)) {
        m_available = false; // QProcess::FailedToStart: not on PATH
        m_toolVersion.clear();
        emit availabilityChanged();
        return;
    }
    probe.waitForFinished(5000);
    m_available = probe.exitStatus() == QProcess::NormalExit && probe.exitCode() == 0;
    m_toolVersion = QString::fromUtf8(probe.readAllStandardOutput()).trimmed();
    emit availabilityChanged();
}

QString YtDlpDownloader::downloadDirectory() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QStringLiteral("/youtube");
}

void YtDlpDownloader::fetchInfo(const QUrl &url)
{
    // -J implies --simulate, so nothing is downloaded — but it IS a real network request,
    // so the UI must show a waiting state before enabling the confirm button.
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this,
            [this, proc, url](int exitCode, QProcess::ExitStatus status) {
                proc->deleteLater();
                if (status != QProcess::NormalExit || exitCode != 0) {
                    emit infoFailed(url, QString::fromUtf8(proc->readAllStandardError())
                                             .trimmed()
                                             .section(QLatin1Char('\n'), -1));
                    return;
                }
                const QJsonObject obj =
                    QJsonDocument::fromJson(proc->readAllStandardOutput()).object();
                emit infoReady(url, obj.value(QStringLiteral("title")).toString(),
                               obj.value(QStringLiteral("channel")).toString(),
                               obj.value(QStringLiteral("duration")).toInt(),
                               obj.value(QStringLiteral("thumbnail")).toString());
            });
    connect(proc, &QProcess::errorOccurred, this, [this, url](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            emit infoFailed(url,
                            tr("yt-dlp não foi encontrado. Instale pelo gerenciador de pacotes "
                               "da sua distro e reabra o melodarium."));
        }
    });
    proc->start(QStringLiteral("yt-dlp"), {QStringLiteral("-J"), url.toString()});
}

void YtDlpDownloader::download(const QUrl &url, int collectionId)
{
    const QString key = url.toString();
    if (m_jobs.contains(key))
        return; // already downloading this exact link

    const QString destDir = downloadDirectory();
    QDir().mkpath(destDir);

    auto *proc = new QProcess(this);
    m_jobs.insert(key, proc);
    m_collectionForUrl.insert(key, collectionId);

    connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc, url]() {
        const QStringList lines = QString::fromUtf8(proc->readAllStandardOutput())
                                      .split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        for (const QString &line : lines) {
            qint64 got = 0;
            qint64 total = 0;
            if (parseProgressLine(line, &got, &total))
                emit progress(url, got, total);
            else if (line.contains(QStringLiteral("[ExtractAudio] Destination:")))
                m_lastDestination.insert(url.toString(),
                                         line.section(QStringLiteral("Destination: "), 1).trimmed());
        }
    });

    connect(proc, &QProcess::errorOccurred, this, [this, url](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            emit failed(url,
                        tr("yt-dlp não foi encontrado. Instale pelo gerenciador de pacotes da "
                           "sua distro e reabra o melodarium."));
        }
    });

    connect(proc, &QProcess::finished, this,
            [this, proc, url, key](int exitCode, QProcess::ExitStatus status) {
                proc->deleteLater();
                m_jobs.remove(key);
                const int collectionId = m_collectionForUrl.take(key);
                const QString destination = m_lastDestination.take(key);

                if (status != QProcess::NormalExit || exitCode != 0) {
                    emit failed(url, tr("o download falhou (código %1)").arg(exitCode));
                    return;
                }
                if (destination.isEmpty() || !QFile::exists(destination)) {
                    emit failed(url, tr("o arquivo baixado não foi encontrado"));
                    return;
                }

                CollectionManager manager;
                const int trackId = manager.ingestDownloadedFile(
                    destination, collectionId, url.toString(), QStringLiteral("YouTube"));
                if (trackId <= 0) {
                    emit failed(url, tr("não consegui registrar a faixa na biblioteca"));
                    return;
                }
                emit finished(url, trackId);
            });

    proc->start(QStringLiteral("yt-dlp"), buildArguments(url, destDir, findFfmpeg()));
}

void YtDlpDownloader::cancel(const QUrl &url)
{
    QProcess *proc = m_jobs.value(url.toString(), nullptr);
    if (!proc)
        return;
    proc->terminate(); // SIGTERM first: gives yt-dlp a chance to clean up its own .part
    if (!proc->waitForFinished(3000))
        proc->kill();
}
