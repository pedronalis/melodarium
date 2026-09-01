#include "librarywatcher.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>

LibraryWatcher::LibraryWatcher(QObject *parent)
    : QObject(parent)
{
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(250);
    connect(&m_debounce, &QTimer::timeout, this, [this]() {
        if (m_enabled && !m_root.isEmpty())
            emit scanRequested();
    });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged,
            this, &LibraryWatcher::scheduleScan);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged,
            this, &LibraryWatcher::scheduleScan);
}

void LibraryWatcher::setRoot(const QString &root)
{
    const QString cleanRoot = root.isEmpty()
                                  ? QString()
                                  : QDir::cleanPath(QFileInfo(root).absoluteFilePath());
    if (m_root == cleanRoot)
        return;
    m_debounce.stop();
    clearWatches();
    m_root = cleanRoot;
    if (!m_scanActive)
        rebuildWatches();
}

void LibraryWatcher::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;
    m_debounce.stop();
    clearWatches();
    if (m_enabled && !m_scanActive)
        rebuildWatches();
}

void LibraryWatcher::setDebounceInterval(int milliseconds)
{
    m_debounce.setInterval(qMax(0, milliseconds));
}

void LibraryWatcher::scanStarted()
{
    m_scanActive = true;
}

void LibraryWatcher::scanFinished()
{
    m_scanActive = false;
    // Database already turned every change observed during the scan into one pending rescan.
    // Letting this timer survive would request a third scan after that rescan starts.
    m_debounce.stop();
    rebuildWatches();
}

void LibraryWatcher::clearWatches()
{
    const QStringList files = m_watcher.files();
    if (!files.isEmpty())
        m_watcher.removePaths(files);
    const QStringList directories = m_watcher.directories();
    if (!directories.isEmpty())
        m_watcher.removePaths(directories);
}

void LibraryWatcher::rebuildWatches()
{
    clearWatches();
    if (!m_enabled || m_root.isEmpty() || !QFileInfo(m_root).isDir())
        return;

    QStringList paths{m_root};
    QDirIterator iterator(m_root, QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot,
                          QDirIterator::Subdirectories);
    while (iterator.hasNext())
        paths.append(iterator.next());
    m_watcher.addPaths(paths);
}

void LibraryWatcher::scheduleScan(const QString &changedPath)
{
    if (!m_enabled || !belongsToCurrentRoot(changedPath))
        return;
    emit changeDetected();
    m_debounce.start();
}

bool LibraryWatcher::belongsToCurrentRoot(const QString &path) const
{
    if (m_root.isEmpty())
        return false;
    const QString cleanPath = QDir::cleanPath(QFileInfo(path).absoluteFilePath());
    return cleanPath == m_root || cleanPath.startsWith(m_root + QDir::separator());
}
