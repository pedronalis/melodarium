#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

class QThread;
class LibraryScanner;
class LibraryWatcher;

class Database : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int schemaVersion READ schemaVersion NOTIFY schemaVersionChanged)
    Q_PROPERTY(QString libraryPath READ libraryPath WRITE setLibraryPath NOTIFY libraryPathChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString startupError READ startupError NOTIFY startupErrorChanged)
    Q_PROPERTY(QString lastBackupPath READ lastBackupPath NOTIFY lastBackupPathChanged)

public:
    static constexpr const char *kUiConnection = "melodarium-ui";
    static constexpr const char *kScannerConnection = "melodarium-scanner";

    explicit Database(QObject *parent = nullptr);
    ~Database() override;

    static QString defaultDatabasePath();
    static bool openConnection(const QString &connectionName, const QString &dbPath);
    static bool applyPragmas(QSqlDatabase &db, QString *error = nullptr);
    static bool migrate(QSqlDatabase &db, QString *error = nullptr,
                        QString *backupPath = nullptr);

    int schemaVersion() const;
    QString libraryPath() const { return m_libraryPath; }
    void setLibraryPath(const QString &path);
    bool scanning() const { return m_scanning; }
    bool ready() const { return m_ready; }
    QString startupError() const { return m_startupError; }
    QString lastBackupPath() const { return m_lastBackupPath; }

    Q_INVOKABLE void startScan();
    Q_INVOKABLE void cancelScan();

signals:
    void schemaVersionChanged();
    void libraryPathChanged();
    void scanningChanged();
    void readyChanged();
    void startupErrorChanged();
    void lastBackupPathChanged();
    void scanProgress(int done, int total);
    void scanFinished(int added, int updated, int removed);
    void scanFailed(const QString &message);

private:
    QString m_dbPath;
    QString m_libraryPath;
    bool m_scanning = false;
    bool m_ready = false;
    QString m_startupError;
    QString m_lastBackupPath;
    QThread *m_scanThread = nullptr;
    LibraryScanner *m_scanner = nullptr;
    LibraryWatcher *m_libraryWatcher = nullptr;
    bool m_rescanPending = false;
};
