#include "legacymigration.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>

namespace {

bool moveFileWithoutOverwrite(const QString &source, const QString &destination)
{
    if (QFileInfo::exists(destination))
        return false;
    QDir().mkpath(QFileInfo(destination).absolutePath());
    if (QFile::rename(source, destination))
        return true;
    if (!QFile::copy(source, destination))
        return false;
    return QFile::remove(source);
}

void mergeDirectory(const QString &sourcePath, const QString &destinationPath,
                    const QString &oldName, const QString &newName, bool renameDatabase)
{
    QDir source(sourcePath);
    if (!source.exists())
        return;

    if (!QDir(destinationPath).exists()) {
        QDir().mkpath(QFileInfo(destinationPath).absolutePath());
        if (QDir().rename(sourcePath, destinationPath)) {
            if (renameDatabase) {
                QDir destination(destinationPath);
                const QStringList suffixes = {
                    QString(), QStringLiteral("-wal"), QStringLiteral("-shm")
                };
                for (const QString &suffix : suffixes) {
                    const QString from = destination.filePath(
                        oldName + QStringLiteral(".db") + suffix);
                    const QString to = destination.filePath(
                        newName + QStringLiteral(".db") + suffix);
                    if (QFileInfo::exists(from) && !QFileInfo::exists(to))
                        QFile::rename(from, to);
                }
            }
            return;
        }
    }

    QDir().mkpath(destinationPath);
    const QFileInfoList entries = source.entryInfoList(
        QDir::NoDotAndDotDot | QDir::AllEntries | QDir::Hidden | QDir::System);
    for (const QFileInfo &entry : entries) {
        QString destinationName = entry.fileName();
        if (renameDatabase && destinationName.startsWith(oldName + QStringLiteral(".db")))
            destinationName.replace(0, oldName.size(), newName);
        const QString destination = QDir(destinationPath).filePath(destinationName);
        if (entry.isDir())
            mergeDirectory(entry.absoluteFilePath(), destination, oldName, newName, false);
        else
            moveFileWithoutOverwrite(entry.absoluteFilePath(), destination);
    }
    QDir().rmdir(sourcePath);
}

} // namespace

void migrateLegacyApplicationData(const QString &oldName, const QString &newName)
{
    if (oldName.isEmpty() || newName.isEmpty() || oldName == newName)
        return;

    QSettings current;
    QSettings legacy(QSettings::NativeFormat, QSettings::UserScope, oldName, oldName);
    for (const QString &key : legacy.allKeys()) {
        if (!current.contains(key))
            current.setValue(key, legacy.value(key));
    }
    current.sync();

    struct MigrationPath {
        QString destination;
        QString source;
        bool renameDatabase;
    };
    const QList<MigrationPath> paths = {
        {QStandardPaths::writableLocation(QStandardPaths::AppDataLocation),
         QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
             + QLatin1Char('/') + oldName + QLatin1Char('/') + oldName,
         true},
        {QStandardPaths::writableLocation(QStandardPaths::CacheLocation),
         QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation)
             + QLatin1Char('/') + oldName + QLatin1Char('/') + oldName,
         false},
    };

    for (const MigrationPath &path : paths) {
        mergeDirectory(path.source, path.destination, oldName, newName, path.renameDatabase);
        QDir().rmdir(QFileInfo(path.source).absolutePath());
    }
}
