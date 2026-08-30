#include <QtTest/QtTest>
#include <QElapsedTimer>
#include <QFile>
#include <QProcess>
#include <QScopeGuard>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "collectionmanager.h"
#include "database.h"
#include "ytdlpdownloader.h"

class TstYtDlp : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;

    int scalar(const QString &sql)
    {
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        QSqlQuery q(db);
        return (q.exec(sql) && q.next()) ? q.value(0).toInt() : -1;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QVERIFY(Database::openConnection(QLatin1String(Database::kUiConnection),
                                         m_dir.filePath(QStringLiteral("t.db"))));
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        Database::applyPragmas(db);
        QVERIFY(Database::migrate(db));
    }

    // The YouTube columns arrive in migration 6; later slices append their own, so the exact
    // number is not the contract — only that this database is at or past that migration.
    void schemaIsAtLeastAtVersionSix()
    {
        QVERIFY(scalar(QStringLiteral("PRAGMA user_version")) >= 6);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM pragma_table_info('tracks') "
                                       "WHERE name = 'source_kind'")),
                 1);
    }

    void argumentsNeverConcatenateTheUrl()
    {
        const QUrl url(QStringLiteral("https://youtu.be/abc; rm -rf /"));
        const QStringList args = YtDlpDownloader::buildArguments(
            url, QStringLiteral("/tmp/out"), QString());

        // The whole URL must be exactly one element: QProcess execs with no shell, so even a
        // hostile link cannot become a second command.
        QCOMPARE(args.last(), url.toString());
        QCOMPARE(args.count(url.toString()), 1);
        for (const QString &a : args)
            QVERIFY2(!a.contains(QStringLiteral("rm -rf")) || a == url.toString(),
                     "user input leaked into another argument");
    }

    void argumentsKeepTheQualityContract()
    {
        const QStringList args = YtDlpDownloader::buildArguments(
            QUrl(QStringLiteral("https://youtu.be/x")), QStringLiteral("/tmp/out"), QString());

        QVERIFY(args.contains(QStringLiteral("bestaudio/best")));
        // "best" means do not re-encode. A fixed codec here would degrade already-lossy audio.
        const int formatIndex = args.indexOf(QStringLiteral("--audio-format"));
        QVERIFY(formatIndex >= 0);
        QCOMPARE(args.at(formatIndex + 1), QStringLiteral("best"));
        QVERIFY(!args.contains(QStringLiteral("mp3")));
        QVERIFY(args.contains(QStringLiteral("--embed-thumbnail")));
        QVERIFY(args.contains(QStringLiteral("--no-playlist")));
    }

    void ffmpegLocationOnlyWhenItWasLookedUp()
    {
        const QStringList without = YtDlpDownloader::buildArguments(
            QUrl(QStringLiteral("https://youtu.be/x")), QStringLiteral("/tmp"), QString());
        QVERIFY(!without.contains(QStringLiteral("--ffmpeg-location")));

        const QStringList with = YtDlpDownloader::buildArguments(
            QUrl(QStringLiteral("https://youtu.be/x")), QStringLiteral("/tmp"),
            QStringLiteral("/usr/bin"));
        const int idx = with.indexOf(QStringLiteral("--ffmpeg-location"));
        QVERIFY(idx >= 0);
        QCOMPARE(with.at(idx + 1), QStringLiteral("/usr/bin"));
    }

    void progressLineParsesRealOutput()
    {
        qint64 got = 0;
        qint64 total = 0;
        QVERIFY(YtDlpDownloader::parseProgressLine(
            QStringLiteral("MELODIA_PROGRESS 4302011 8588123"), &got, &total));
        QCOMPARE(got, 4302011);
        QCOMPARE(total, 8588123);
    }

    void unknownTotalBecomesMinusOneNotAFailure()
    {
        qint64 got = 0;
        qint64 total = 0;
        // yt-dlp emits "NA" when the server declares no size.
        QVERIFY(YtDlpDownloader::parseProgressLine(
            QStringLiteral("MELODIA_PROGRESS 1024 NA"), &got, &total));
        QCOMPARE(got, 1024);
        QCOMPARE(total, -1);
    }

    void unrelatedOutputIsIgnored()
    {
        qint64 got = 0;
        qint64 total = 0;
        QVERIFY(!YtDlpDownloader::parseProgressLine(
            QStringLiteral("[youtube] Extracting URL: https://..."), &got, &total));
        QVERIFY(!YtDlpDownloader::parseProgressLine(QString(), &got, &total));
        QVERIFY(!YtDlpDownloader::parseProgressLine(QStringLiteral("MELODIA_PROGRESS"), &got, &total));
    }

    void probeReturnsBeforeTheToolFinishes()
    {
        QTemporaryDir tools;
        QVERIFY(tools.isValid());
        const QString executable = tools.filePath(QStringLiteral("yt-dlp"));
        QFile script(executable);
        QVERIFY(script.open(QIODevice::WriteOnly));
        script.write("#!/bin/sh\n/usr/bin/sleep 1\nprintf 'test-version\\n'\n");
        script.close();
        QVERIFY(script.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner
                                      | QFileDevice::ExeOwner));

        const QByteArray originalPath = qgetenv("PATH");
        const auto restorePath = qScopeGuard([originalPath]() { qputenv("PATH", originalPath); });
        qputenv("PATH", tools.path().toUtf8());

        YtDlpDownloader downloader;
        QSignalSpy availabilitySpy(&downloader, &YtDlpDownloader::availabilityChanged);
        QElapsedTimer elapsed;
        elapsed.start();
        downloader.probe();

        QVERIFY2(elapsed.elapsed() < 100, "probe() blocked while yt-dlp was running");
        QVERIFY2(availabilitySpy.wait(3000), "asynchronous probe never completed");
        QVERIFY(downloader.available());
        QCOMPARE(downloader.toolVersion(), QStringLiteral("test-version"));
    }

    void ingestedFileIsMarkedAsYouTubeAndJoinsTheCollection()
    {
        // Build a real tagged file so TagReader has something valid to read.
        const QString path = m_dir.filePath(QStringLiteral("baixado.flac"));
        QProcess ff;
        ff.start(QStringLiteral("ffmpeg"),
                 {QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"),
                  QStringLiteral("error"), QStringLiteral("-f"), QStringLiteral("lavfi"),
                  QStringLiteral("-i"), QStringLiteral("sine=440:d=1"),
                  QStringLiteral("-metadata"), QStringLiteral("title=Do YouTube"),
                  QStringLiteral("-y"), path});
        if (!ff.waitForStarted(3000))
            QSKIP("ffmpeg unavailable");
        ff.waitForFinished(15000);
        QVERIFY(QFile::exists(path));

        CollectionManager cm;
        const int collectionId = cm.createCollection(QStringLiteral("Pra codar"));
        QVERIFY(collectionId > 0);

        const int trackId = cm.ingestDownloadedFile(
            path, collectionId, QStringLiteral("https://youtu.be/abc"), QStringLiteral("YouTube"));
        QVERIFY(trackId > 0);

        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE id = %1 "
                                       "AND source_kind = 'youtube'")
                            .arg(trackId)),
                 1);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM collection_tracks "
                                       "WHERE collection_id = %1 AND track_id = %2")
                            .arg(collectionId)
                            .arg(trackId)),
                 1);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM track_stats WHERE track_id = %1")
                            .arg(trackId)),
                 1);
    }

    void ingestingTheSamePathTwiceDoesNotDuplicate()
    {
        const QString path = m_dir.filePath(QStringLiteral("baixado.flac"));
        if (!QFile::exists(path))
            QSKIP("fixture missing");

        CollectionManager cm;
        const int before = scalar(QStringLiteral("SELECT COUNT(*) FROM tracks"));
        const int trackId = cm.ingestDownloadedFile(path, 0, QStringLiteral("https://youtu.be/abc"),
                                                    QStringLiteral("YouTube"));
        QVERIFY(trackId > 0);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks")), before);
    }

    void missingFileIsRejectedCleanly()
    {
        CollectionManager cm;
        QCOMPARE(cm.ingestDownloadedFile(QStringLiteral("/nao/existe.opus"), 0,
                                         QStringLiteral("https://youtu.be/z"), QString()),
                 0);
    }
};

QTEST_MAIN(TstYtDlp)
#include "tst_ytdlp.moc"
