#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QString>
#include <QTimer>

class LibraryWatcher : public QObject
{
    Q_OBJECT

public:
    explicit LibraryWatcher(QObject *parent = nullptr);

    QString root() const { return m_root; }
    bool enabled() const { return m_enabled; }

    void setRoot(const QString &root);
    void setEnabled(bool enabled);
    void setDebounceInterval(int milliseconds);
    void scanStarted();
    void scanFinished();

signals:
    void changeDetected();
    void scanRequested();

private:
    void clearWatches();
    void rebuildWatches();
    void scheduleScan(const QString &changedPath);
    bool belongsToCurrentRoot(const QString &path) const;

    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QString m_root;
    bool m_enabled = true;
    bool m_scanActive = false;
};
