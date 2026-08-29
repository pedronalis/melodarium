#pragma once

#include <QAbstractListModel>
#include <QFutureWatcher>
#include <QString>
#include <QVariantList>
#include <QVector>
#include <QtQmlIntegration/qqmlintegration.h>

// The model behind the in-app folder picker. It lists the SUBFOLDERS of one directory and
// hands the screen three ready-made lists: the current path sliced into clickable crumbs, the
// user's places (home, music, downloads) and the volumes actually mounted on this machine.
//
// Why it exists at all: the app used to open QtQuick.Dialogs' FolderDialog, which on Wayland
// is the desktop portal — another program's window, with another program's palette, and no
// idea what a music folder is. Picking the folder is the very first thing a new user does.
class FolderBrowser : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(QString parentPath READ parentPath NOTIFY pathChanged)
    Q_PROPERTY(bool readable READ readable NOTIFY pathChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(QVariantList crumbs READ crumbs NOTIFY pathChanged)
    Q_PROPERTY(QVariantList places READ places CONSTANT)
    Q_PROPERTY(QVariantList volumes READ volumes NOTIFY volumesChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        AudioCountRole, // -1 while the background count has not landed yet
        EntryReadableRole,
    };

    explicit FolderBrowser(QObject *parent = nullptr);
    ~FolderBrowser() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString path() const { return m_path; }
    void setPath(const QString &path);
    QString parentPath() const;
    bool readable() const { return m_readable; }
    bool showHidden() const { return m_showHidden; }
    void setShowHidden(bool on);
    int count() const { return int(m_entries.size()); }

    QVariantList crumbs() const;
    QVariantList places() const;
    QVariantList volumes() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshVolumes();
    Q_INVOKABLE void enter(int row);
    Q_INVOKABLE QString pathAt(int row) const;
    Q_INVOKABLE void goUp();

    // Empty string means it worked; anything else is the reason to show on screen.
    Q_INVOKABLE QString createFolder(const QString &name);

    // Turns whatever was typed or pasted — "~/Música", "file:///media/x", a relative name, or
    // the path of a file inside the folder — into an existing directory, or "" when there is
    // no such directory to go to.
    Q_INVOKABLE QString resolveInput(const QString &text) const;

signals:
    void pathChanged();
    void showHiddenChanged();
    void volumesChanged();
    void countChanged();

private:
    struct Entry {
        QString name;
        QString path;
        int audioCount = -1;
        bool readable = true;
    };

    void applyCounts();

    QString m_path;
    bool m_readable = true;
    bool m_showHidden = false;
    QVector<Entry> m_entries;

    // The folder that motivated this feature lives on an external drive: counting the audio
    // files of 200 subfolders on a cold spin-up freezes the window mid-click. The count runs
    // off-thread and lands later; m_countingPath is what tells a late result that the user has
    // already walked somewhere else and it should be dropped.
    QFutureWatcher<QVector<int>> *m_counter = nullptr;
    QString m_countingPath;
};
