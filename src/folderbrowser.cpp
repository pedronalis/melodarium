#include "folderbrowser.h"

#include "libraryscanner.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QLocale>
#include <QSet>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QUrl>
#include <QVariantMap>
#include <QtConcurrent/QtConcurrentRun>

#include <algorithm>
#include <utility>

namespace {

// Counting stops here. A folder with more audio files than this is unambiguously "a lot", and
// the number stops being information the moment it needs a thousands separator to be read.
constexpr int kCountCeiling = 9999;

// Mount points the kernel and the session manager keep around that are not places anyone
// stores music. Without this filter the sidebar lists forty entries, most of them /sys/fs/*.
bool isPseudoFileSystem(const QString &type)
{
    static const QSet<QString> pseudo = {
        QStringLiteral("tmpfs"),       QStringLiteral("devtmpfs"),
        QStringLiteral("ramfs"),       QStringLiteral("proc"),
        QStringLiteral("sysfs"),       QStringLiteral("cgroup"),
        QStringLiteral("cgroup2"),     QStringLiteral("devpts"),
        QStringLiteral("securityfs"),  QStringLiteral("pstore"),
        QStringLiteral("bpf"),         QStringLiteral("tracefs"),
        QStringLiteral("debugfs"),     QStringLiteral("configfs"),
        QStringLiteral("fusectl"),     QStringLiteral("mqueue"),
        QStringLiteral("hugetlbfs"),   QStringLiteral("autofs"),
        QStringLiteral("binfmt_misc"), QStringLiteral("efivarfs"),
        QStringLiteral("squashfs"),    QStringLiteral("overlay"),
        QStringLiteral("nsfs"),        QStringLiteral("selinuxfs"),
        QStringLiteral("rpc_pipefs"),  QStringLiteral("sunrpc"),
        QStringLiteral("fuse.gvfsd-fuse"), QStringLiteral("fuse.portal"),
    };
    return pseudo.contains(type.toLower());
}

bool isSystemMountPoint(const QString &root)
{
    if (root == QLatin1String("/"))
        return false;
    // /run/media/<user>/<label> is where Fedora mounts removable drives — the one branch of
    // /run that must survive.
    if (root.startsWith(QLatin1String("/run/media/")))
        return false;
    static const QStringList system = {
        QStringLiteral("/boot"),  QStringLiteral("/proc"), QStringLiteral("/sys"),
        QStringLiteral("/dev"),   QStringLiteral("/run"),  QStringLiteral("/snap"),
        QStringLiteral("/var/lib/docker"), QStringLiteral("/var/lib/snapd"),
        QStringLiteral("/var/lib/containers"),
    };
    for (const QString &prefix : system) {
        if (root == prefix || root.startsWith(prefix + QLatin1Char('/')))
            return true;
    }
    return false;
}

bool isNetworkFileSystem(const QString &type)
{
    const QString t = type.toLower();
    return t.startsWith(QLatin1String("nfs")) || t.startsWith(QLatin1String("cifs"))
        || t.startsWith(QLatin1String("smb")) || t.contains(QLatin1String("sshfs"))
        || t.startsWith(QLatin1String("ftp")) || t.startsWith(QLatin1String("davfs"));
}

int countAudioIn(const QString &dir)
{
    int found = 0;
    QDirIterator it(dir, QDir::Files | QDir::NoSymLinks);
    while (it.hasNext()) {
        it.next();
        if (LibraryScanner::audioSuffixes().contains(it.fileInfo().suffix().toLower())) {
            if (++found >= kCountCeiling)
                break;
        }
    }
    return found;
}

// Folders that are system plumbing on drives formatted elsewhere. They carry no dot, so the
// hidden filter never catches them, and on the external NTFS drive $RECYCLE.BIN lands on the
// FIRST line of the list — above every real folder.
bool isForeignSystemFolder(const QString &name)
{
    static const QSet<QString> junk = {
        QStringLiteral("$recycle.bin"),
        QStringLiteral("system volume information"),
        QStringLiteral("$windows.~ws"),
        QStringLiteral("lost+found"),
    };
    return junk.contains(name.toLower());
}

QVariantMap place(const QString &name, const QString &path, const QString &icon)
{
    QVariantMap m;
    m.insert(QStringLiteral("name"), name);
    m.insert(QStringLiteral("path"), path);
    m.insert(QStringLiteral("icon"), icon);
    return m;
}

} // namespace

FolderBrowser::FolderBrowser(QObject *parent)
    : QAbstractListModel(parent)
    , m_counter(new QFutureWatcher<QVector<int>>(this))
{
    connect(m_counter, &QFutureWatcher<QVector<int>>::finished, this, &FolderBrowser::applyCounts);
    m_path = QDir::homePath();
}

FolderBrowser::~FolderBrowser()
{
    // The worker only reads paths it was handed by value, but the watcher must not outlive the
    // running future while it still points at this object.
    m_counter->disconnect(this);
    if (m_counter->isRunning())
        m_counter->waitForFinished();
}

int FolderBrowser::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_entries.size());
}

QVariant FolderBrowser::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_entries.size())
        return {};
    const Entry &e = m_entries.at(index.row());
    switch (role) {
    case NameRole:
        return e.name;
    case PathRole:
        return e.path;
    case AudioCountRole:
        return e.audioCount;
    case EntryReadableRole:
        return e.readable;
    default:
        return {};
    }
}

QHash<int, QByteArray> FolderBrowser::roleNames() const
{
    return {
        { NameRole, "name" },
        { PathRole, "path" },
        { AudioCountRole, "audioCount" },
        { EntryReadableRole, "entryReadable" },
    };
}

void FolderBrowser::setPath(const QString &path)
{
    QString wanted = path;
    if (wanted.isEmpty())
        wanted = QDir::homePath();
    const QString clean = QDir::cleanPath(wanted);
    if (clean == m_path) {
        ensureLoaded();
        return;
    }
    m_path = clean;
    refresh();
    emit pathChanged();
}

QString FolderBrowser::parentPath() const
{
    if (m_path == QLatin1String("/"))
        return {};
    const QString up = QDir::cleanPath(m_path + QLatin1String("/.."));
    return up == m_path ? QString() : up;
}

void FolderBrowser::setShowHidden(bool on)
{
    if (m_showHidden == on)
        return;
    m_showHidden = on;
    refresh();
    emit showHiddenChanged();
}

void FolderBrowser::refresh()
{
    m_loaded = true;
    QDir dir(m_path);
    QDir::Filters filters = QDir::Dirs | QDir::NoDotAndDotDot | QDir::NoSymLinks;
    if (m_showHidden)
        filters |= QDir::Hidden;

    const QFileInfo here(m_path);
    const bool ok = here.exists() && here.isDir() && here.isReadable();

    QVector<Entry> next;
    if (ok) {
        const QFileInfoList infos =
            dir.entryInfoList(filters, QDir::Name | QDir::IgnoreCase | QDir::LocaleAware);
        next.reserve(infos.size());
        for (const QFileInfo &info : infos) {
            if (!m_showHidden && isForeignSystemFolder(info.fileName()))
                continue;
            next.append({ info.fileName(), info.absoluteFilePath(), -1, info.isReadable() });
        }
    }

    const int before = int(m_entries.size());
    beginResetModel();
    m_entries = next;
    m_readable = ok;
    endResetModel();
    if (before != int(m_entries.size()))
        emit countChanged();

    // Hand the worker plain paths: it must not touch the model, which lives on this thread.
    QStringList toCount;
    toCount.reserve(next.size());
    for (const Entry &e : std::as_const(next))
        toCount.append(e.readable ? e.path : QString());

    m_countingPath = m_path;
    if (toCount.isEmpty())
        return;
    m_counter->setFuture(QtConcurrent::run([toCount]() {
        QVector<int> counts;
        counts.reserve(toCount.size());
        for (const QString &p : toCount)
            counts.append(p.isEmpty() ? -1 : countAudioIn(p));
        return counts;
    }));
}

void FolderBrowser::ensureLoaded()
{
    if (!m_loaded)
        refresh();
}

void FolderBrowser::applyCounts()
{
    // The user may have walked on while the drive was spinning up: a result for another folder
    // would paint one folder's numbers under another folder's names.
    if (m_countingPath != m_path)
        return;
    const QVector<int> counts = m_counter->result();
    if (counts.size() != m_entries.size())
        return;
    for (int i = 0; i < counts.size(); ++i)
        m_entries[i].audioCount = counts.at(i);
    emit dataChanged(index(0), index(int(m_entries.size()) - 1), { AudioCountRole });
}

void FolderBrowser::refreshVolumes()
{
    emit volumesChanged();
}

void FolderBrowser::enter(int row)
{
    if (row < 0 || row >= m_entries.size())
        return;
    setPath(m_entries.at(row).path);
}

QString FolderBrowser::pathAt(int row) const
{
    if (row < 0 || row >= m_entries.size())
        return {};
    return m_entries.at(row).path;
}

void FolderBrowser::goUp()
{
    const QString up = parentPath();
    if (!up.isEmpty())
        setPath(up);
}

QString FolderBrowser::createFolder(const QString &name)
{
    const QString clean = name.trimmed();
    if (clean.isEmpty())
        return tr("Dê um nome à pasta.");
    if (clean.contains(QLatin1Char('/')))
        return tr("O nome não pode conter “/”.");
    if (clean == QLatin1String(".") || clean == QLatin1String(".."))
        return tr("Esse nome é reservado pelo sistema.");

    QDir dir(m_path);
    if (dir.exists(clean))
        return tr("Já existe algo com esse nome aqui.");
    if (!dir.mkdir(clean))
        return tr("Não foi possível criar a pasta aqui — verifique a permissão.");

    refresh();
    return {};
}

QString FolderBrowser::resolveInput(const QString &text) const
{
    QString candidate = text.trimmed();
    if (candidate.isEmpty())
        return {};
    if (candidate.startsWith(QLatin1String("file://")))
        candidate = QUrl(candidate).toLocalFile();
    if (candidate == QLatin1String("~"))
        candidate = QDir::homePath();
    else if (candidate.startsWith(QLatin1String("~/")))
        candidate = QDir::homePath() + candidate.mid(1);
    else if (candidate.startsWith(QLatin1String("$HOME")))
        candidate = QDir::homePath() + candidate.mid(5);

    if (!candidate.startsWith(QLatin1Char('/')))
        candidate = QDir(m_path).absoluteFilePath(candidate);

    QFileInfo info(QDir::cleanPath(candidate));
    // Someone who pastes the path of a song means the folder that holds it.
    if (info.exists() && info.isFile())
        info = QFileInfo(info.absolutePath());
    if (!info.exists() || !info.isDir())
        return {};
    return info.absoluteFilePath();
}

QVariantList FolderBrowser::crumbs() const
{
    QVariantList out;
    QVariantMap root;
    root.insert(QStringLiteral("name"), QStringLiteral("/"));
    root.insert(QStringLiteral("path"), QStringLiteral("/"));
    out.append(root);
    if (m_path == QLatin1String("/"))
        return out;

    QString walked;
    const QStringList parts = m_path.split(QLatin1Char('/'), Qt::SkipEmptyParts);
    for (const QString &part : parts) {
        walked += QLatin1Char('/') + part;
        QVariantMap crumb;
        crumb.insert(QStringLiteral("name"), part);
        crumb.insert(QStringLiteral("path"), walked);
        out.append(crumb);
    }
    return out;
}

QVariantList FolderBrowser::places() const
{
    QVariantList out;
    const QString home = QDir::homePath();
    out.append(place(tr("Pasta pessoal"), home, QStringLiteral("home")));

    const auto add = [&out, &home](QStandardPaths::StandardLocation loc, const QString &label,
                                   const QString &icon) {
        const QString p = QStandardPaths::writableLocation(loc);
        if (p.isEmpty() || p == home || !QFileInfo::exists(p))
            return;
        out.append(place(label, p, icon));
    };
    add(QStandardPaths::MusicLocation, tr("Música"), QStringLiteral("music"));
    add(QStandardPaths::DownloadLocation, tr("Downloads"), QStringLiteral("download"));
    return out;
}

QVariantList FolderBrowser::volumes() const
{
    QVariantList out;
    QSet<QString> seenDevices;
    const QLocale locale = QLocale::system();

    for (const QStorageInfo &si : QStorageInfo::mountedVolumes()) {
        if (!si.isValid() || !si.isReady())
            continue;
        const QString type = QString::fromLatin1(si.fileSystemType());
        const QString root = si.rootPath();
        if (isPseudoFileSystem(type) || isSystemMountPoint(root))
            continue;
        // Bind mounts and btrfs subvolumes show the same disk two or three times over.
        const QString device = QString::fromLatin1(si.device());
        if (seenDevices.contains(device))
            continue;
        seenDevices.insert(device);

        QString name = si.displayName();
        if (root == QLatin1String("/"))
            name = tr("Sistema");
        else if (name.isEmpty() || name == root)
            name = QDir(root).dirName();
        if (name.isEmpty())
            name = root;

        QString icon = QStringLiteral("database");
        if (root == QLatin1String("/"))
            icon = QStringLiteral("device-desktop");
        else if (isNetworkFileSystem(type))
            icon = QStringLiteral("network");

        QVariantMap v;
        v.insert(QStringLiteral("name"), name);
        v.insert(QStringLiteral("path"), root);
        v.insert(QStringLiteral("icon"), icon);
        v.insert(QStringLiteral("free"), locale.formattedDataSize(si.bytesAvailable(), 1));
        v.insert(QStringLiteral("total"), locale.formattedDataSize(si.bytesTotal(), 1));
        v.insert(QStringLiteral("readOnly"), si.isReadOnly());
        out.append(v);
    }

    std::sort(out.begin(), out.end(), [](const QVariant &a, const QVariant &b) {
        const QString pa = a.toMap().value(QStringLiteral("path")).toString();
        const QString pb = b.toMap().value(QStringLiteral("path")).toString();
        if ((pa == QLatin1String("/")) != (pb == QLatin1String("/")))
            return pa == QLatin1String("/");
        return a.toMap().value(QStringLiteral("name")).toString().localeAwareCompare(
                   b.toMap().value(QStringLiteral("name")).toString())
            < 0;
    });
    return out;
}
