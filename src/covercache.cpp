#include "covercache.h"
#include "tagreader.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>
#include <QtConcurrent/QtConcurrentRun>

namespace {

bool writeAtomically(const QString &path, const QByteArray &data)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    if (!data.isEmpty() && file.write(data) != data.size())
        return false;
    return file.commit();
}

QString trackKey(const QString &trackPath)
{
    return QString::fromLatin1(
        QCryptographicHash::hash(trackPath.toUtf8(), QCryptographicHash::Sha1).toHex());
}

} // namespace

CoverCache::CoverCache(QObject *parent)
    : QObject(parent)
{
    QDir().mkpath(cacheDirectory() + QStringLiteral("/blobs"));
    QDir().mkpath(cacheDirectory() + QStringLiteral("/refs"));
}

QString CoverCache::cacheDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
           + QStringLiteral("/covers");
}

QString CoverCache::siblingCoverFile(const QString &trackPath)
{
    const QDir dir = QFileInfo(trackPath).absoluteDir();
    const QStringList candidates = {QStringLiteral("cover.jpg"), QStringLiteral("cover.png"),
                                    QStringLiteral("folder.jpg"), QStringLiteral("folder.png"),
                                    QStringLiteral("front.jpg")};
    const QStringList present = dir.entryList(QDir::Files);
    for (const QString &wanted : candidates) {
        for (const QString &have : present) {
            if (have.compare(wanted, Qt::CaseInsensitive) == 0)
                return dir.absoluteFilePath(have);
        }
    }
    return {};
}

QString CoverCache::coverUrlForTrack(const QString &trackPath, int albumId)
{
    Q_UNUSED(albumId)
    if (trackPath.isEmpty())
        return {};
    if (m_resolved.contains(trackPath))
        return m_resolved.value(trackPath);

    const QString key = trackKey(trackPath);
    const QString ref = cacheDirectory() + QStringLiteral("/refs/") + key
                        + QStringLiteral(".ref");
    const QString none = cacheDirectory() + QStringLiteral("/refs/") + key
                         + QStringLiteral(".none");
    if (QFile::exists(ref)) {
        QFile file(ref);
        if (file.open(QIODevice::ReadOnly)) {
            const QString url = QString::fromUtf8(file.readAll()).trimmed();
            const QString local = QUrl(url).toLocalFile();
            if (!url.isEmpty() && !local.isEmpty() && QFile::exists(local)) {
                m_resolved.insert(trackPath, url);
                return url;
            }
        }
    }
    if (QFile::exists(none)) {
        m_resolved.insert(trackPath, QString());
        return {};
    }

    // Keep the old cache visible while it is migrated to content-addressed storage. The
    // worker reads and hashes it without making the first frame wait or deleting recoverable data.
    const QString jpg = cacheDirectory() + QLatin1Char('/') + key + QStringLiteral(".jpg");
    const QString png = cacheDirectory() + QLatin1Char('/') + key + QStringLiteral(".png");
    const QString legacyNone = cacheDirectory() + QLatin1Char('/') + key + QStringLiteral(".none");

    if (QFile::exists(jpg)) {
        scheduleResolution(trackPath, key, jpg);
        return QUrl::fromLocalFile(jpg).toString();
    }
    if (QFile::exists(png)) {
        scheduleResolution(trackPath, key, png);
        return QUrl::fromLocalFile(png).toString();
    }
    if (QFile::exists(legacyNone)) {
        m_resolved.insert(trackPath, QString());
        return {}; // negative cache: do not re-open the file on every scroll
    }

    scheduleResolution(trackPath, key);
    return {};
}

void CoverCache::scheduleResolution(const QString &trackPath, const QString &key,
                                    const QString &legacyPath)
{
    if (m_pending.contains(trackPath))
        return;
    m_pending.insert(trackPath);

    auto *watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this,
            [this, watcher, trackPath]() {
                const QString result = watcher->result();
                watcher->deleteLater();
                m_pending.remove(trackPath);
                m_resolved.insert(trackPath, result);
                ++m_revision;
                emit revisionChanged();
            });
    watcher->setFuture(QtConcurrent::run(&CoverCache::resolveCover, trackPath, key, legacyPath));
}

QString CoverCache::resolveCover(const QString &trackPath, const QString &key,
                                 const QString &legacyPath)
{
    QByteArray data;
    QString mime;
    QString sourcePath = legacyPath;

    if (!legacyPath.isEmpty()) {
        QFile legacy(legacyPath);
        if (legacy.open(QIODevice::ReadOnly))
            data = legacy.readAll();
    } else {
        data = TagReader::readCover(trackPath, &mime);
    }

    if (data.isEmpty()) {
        sourcePath = siblingCoverFile(trackPath);
        if (!sourcePath.isEmpty()) {
            QFile sibling(sourcePath);
            if (sibling.open(QIODevice::ReadOnly))
                data = sibling.readAll();
        }
    }

    const QString refs = cacheDirectory() + QStringLiteral("/refs/");
    const QString ref = refs + key + QStringLiteral(".ref");
    const QString none = refs + key + QStringLiteral(".none");
    if (data.isEmpty()) {
        writeAtomically(none, {});
        QFile::remove(ref);
        return {};
    }

    const bool png = mime.contains(QStringLiteral("png"), Qt::CaseInsensitive)
                     || QFileInfo(sourcePath).suffix().compare(QStringLiteral("png"),
                                                               Qt::CaseInsensitive) == 0;
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex());
    const QString blob = cacheDirectory() + QStringLiteral("/blobs/") + hash
                         + (png ? QStringLiteral(".png") : QStringLiteral(".jpg"));
    if (!QFile::exists(blob) && !writeAtomically(blob, data)) {
        writeAtomically(none, {});
        return {};
    }

    const QString url = QUrl::fromLocalFile(blob).toString();
    if (!writeAtomically(ref, url.toUtf8()))
        return {};
    QFile::remove(none);
    return url;
}
