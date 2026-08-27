#include "covercache.h"
#include "tagreader.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>

CoverCache::CoverCache(QObject *parent)
    : QObject(parent)
{
    QDir().mkpath(cacheDirectory());
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

    const QString key = QString::fromLatin1(
        QCryptographicHash::hash(trackPath.toUtf8(), QCryptographicHash::Sha1).toHex());
    const QString jpg = cacheDirectory() + QLatin1Char('/') + key + QStringLiteral(".jpg");
    const QString png = cacheDirectory() + QLatin1Char('/') + key + QStringLiteral(".png");
    const QString miss = cacheDirectory() + QLatin1Char('/') + key + QStringLiteral(".none");

    if (QFile::exists(jpg))
        return QUrl::fromLocalFile(jpg).toString();
    if (QFile::exists(png))
        return QUrl::fromLocalFile(png).toString();
    if (QFile::exists(miss))
        return {}; // negative cache: do not re-open the file on every scroll

    QString mime;
    const QByteArray data = TagReader::readCover(trackPath, &mime);
    if (!data.isEmpty()) {
        const QString out = mime.contains(QStringLiteral("png")) ? png : jpg;
        QFile f(out);
        if (f.open(QIODevice::WriteOnly)) {
            f.write(data);
            f.close();
            return QUrl::fromLocalFile(out).toString();
        }
    }

    const QString sibling = siblingCoverFile(trackPath);
    if (!sibling.isEmpty())
        return QUrl::fromLocalFile(sibling).toString();

    QFile marker(miss);
    if (marker.open(QIODevice::WriteOnly))
        marker.close();
    return {};
}
