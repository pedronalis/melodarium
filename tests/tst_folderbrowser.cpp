#include <QtTest/QtTest>
#include <QDir>
#include <QSignalSpy>
#include <QTemporaryDir>

#include "folderbrowser.h"

class TstFolderBrowser : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;

    QString at(const QString &relative) const { return m_dir.filePath(relative); }

    void touch(const QString &relative)
    {
        QFile f(at(relative));
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("x");
    }

    static QStringList namesOf(const FolderBrowser &b)
    {
        QStringList out;
        for (int i = 0; i < b.rowCount(); ++i)
            out << b.data(b.index(i), FolderBrowser::NameRole).toString();
        return out;
    }

    static int countOf(const FolderBrowser &b, const QString &name)
    {
        for (int i = 0; i < b.rowCount(); ++i) {
            if (b.data(b.index(i), FolderBrowser::NameRole).toString() == name)
                return b.data(b.index(i), FolderBrowser::AudioCountRole).toInt();
        }
        return -2;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QDir root(m_dir.path());
        // Deliberately out of alphabetical order on disk, mixed case, plus one hidden.
        QVERIFY(root.mkpath(QStringLiteral("Rock")));
        QVERIFY(root.mkpath(QStringLiteral("ambient")));
        QVERIFY(root.mkpath(QStringLiteral("Jazz/Bebop")));
        QVERIFY(root.mkpath(QStringLiteral(".oculta")));
        touch(QStringLiteral("Rock/a.flac"));
        touch(QStringLiteral("Rock/b.mp3"));
        touch(QStringLiteral("Rock/capa.jpg"));
        touch(QStringLiteral("Rock/leiame.txt"));
        touch(QStringLiteral("Jazz/nao-conta-recursivo.mp3"));
        touch(QStringLiteral("Jazz/Bebop/c.opus"));
        touch(QStringLiteral("raiz.mp3"));
    }

    // Only directories, sorted case-insensitively — a file in the folder is not a destination.
    void listsOnlySubfoldersSorted()
    {
        FolderBrowser b;
        b.setPath(m_dir.path());
        QCOMPARE(namesOf(b), QStringList({ "ambient", "Jazz", "Rock" }));
        QVERIFY(b.readable());
    }

    void hiddenFoldersAreOptIn()
    {
        FolderBrowser b;
        b.setPath(m_dir.path());
        QVERIFY(!namesOf(b).contains(QStringLiteral(".oculta")));
        QSignalSpy spy(&b, &FolderBrowser::showHiddenChanged);
        b.setShowHidden(true);
        QCOMPARE(spy.count(), 1);
        QVERIFY(namesOf(b).contains(QStringLiteral(".oculta")));
    }

    // The count is shallow on purpose: "Jazz" holds one loose mp3 and a subfolder with another
    // one, and only the loose one belongs to Jazz itself.
    void countsAudioShallowAndOffThread()
    {
        FolderBrowser b;
        b.setPath(m_dir.path());
        QTRY_COMPARE(countOf(b, QStringLiteral("Rock")), 2);
        QCOMPARE(countOf(b, QStringLiteral("Jazz")), 1);
        QCOMPARE(countOf(b, QStringLiteral("ambient")), 0);
    }

    void enterAndGoUpWalkTheTree()
    {
        FolderBrowser b;
        b.setPath(m_dir.path());
        const int jazz = namesOf(b).indexOf(QStringLiteral("Jazz"));
        QVERIFY(jazz >= 0);
        b.enter(jazz);
        QCOMPARE(b.path(), at(QStringLiteral("Jazz")));
        QCOMPARE(namesOf(b), QStringList({ "Bebop" }));
        b.goUp();
        QCOMPARE(b.path(), QDir::cleanPath(m_dir.path()));
        b.enter(999); // out of range must not move nor crash
        QCOMPARE(b.path(), QDir::cleanPath(m_dir.path()));
    }

    void theRootHasNoParent()
    {
        FolderBrowser b;
        b.setPath(QStringLiteral("/"));
        QVERIFY(b.parentPath().isEmpty());
        b.goUp();
        QCOMPARE(b.path(), QStringLiteral("/"));
    }

    void crumbsSliceThePath()
    {
        FolderBrowser b;
        b.setPath(at(QStringLiteral("Jazz/Bebop")));
        const QVariantList crumbs = b.crumbs();
        QVERIFY(crumbs.size() >= 3);
        QCOMPARE(crumbs.first().toMap().value(QStringLiteral("path")).toString(),
                 QStringLiteral("/"));
        const QVariantMap last = crumbs.last().toMap();
        QCOMPARE(last.value(QStringLiteral("name")).toString(), QStringLiteral("Bebop"));
        QCOMPARE(last.value(QStringLiteral("path")).toString(), at(QStringLiteral("Jazz/Bebop")));
    }

    // A path that does not exist must read as "cannot read this", not as "empty folder": the
    // screen shows a different thing for each.
    void aMissingPathIsNotAnEmptyFolder()
    {
        FolderBrowser b;
        b.setPath(at(QStringLiteral("nao-existe")));
        QVERIFY(!b.readable());
        QCOMPARE(b.rowCount(), 0);
    }

    void resolveInputAcceptsWhatPeoplePaste()
    {
        FolderBrowser b;
        b.setPath(m_dir.path());
        QCOMPARE(b.resolveInput(QStringLiteral("~")), QDir::homePath());
        QCOMPARE(b.resolveInput(QStringLiteral("  Rock  ")), at(QStringLiteral("Rock")));
        QCOMPARE(b.resolveInput(QStringLiteral("file://") + at(QStringLiteral("Rock"))),
                 at(QStringLiteral("Rock")));
        // The path of a song means the folder that holds it.
        QCOMPARE(b.resolveInput(at(QStringLiteral("Rock/a.flac"))), at(QStringLiteral("Rock")));
        QVERIFY(b.resolveInput(at(QStringLiteral("nao-existe"))).isEmpty());
        QVERIFY(b.resolveInput(QString()).isEmpty());
    }

    void createFolderReportsWhyItFailed()
    {
        FolderBrowser b;
        b.setPath(m_dir.path());
        QVERIFY(!b.createFolder(QStringLiteral("a/b")).isEmpty());
        QVERIFY(!b.createFolder(QStringLiteral("   ")).isEmpty());
        QVERIFY(!b.createFolder(QStringLiteral("Rock")).isEmpty()); // already there
        QVERIFY(b.createFolder(QStringLiteral("Novos")).isEmpty());
        QVERIFY(namesOf(b).contains(QStringLiteral("Novos")));
        QVERIFY(QFileInfo(at(QStringLiteral("Novos"))).isDir());
    }

    // The sidebar exists to reach another drive; it must show the machine's real mount points
    // and none of the kernel's pseudo-filesystems.
    void volumesAreRealDisksOnly()
    {
        FolderBrowser b;
        const QVariantList vols = b.volumes();
        QVERIFY(!vols.isEmpty());
        bool hasRoot = false;
        for (const QVariant &v : vols) {
            const QVariantMap m = v.toMap();
            const QString p = m.value(QStringLiteral("path")).toString();
            if (p == QLatin1String("/"))
                hasRoot = true;
            QVERIFY(!p.startsWith(QStringLiteral("/proc")));
            QVERIFY(!p.startsWith(QStringLiteral("/sys")));
            QVERIFY(!p.startsWith(QStringLiteral("/dev")));
            QVERIFY(!p.startsWith(QStringLiteral("/run/user")));
            QVERIFY(!m.value(QStringLiteral("name")).toString().isEmpty());
            QVERIFY(!m.value(QStringLiteral("free")).toString().isEmpty());
        }
        QVERIFY2(hasRoot, "the root filesystem must always be reachable from the sidebar");
        QCOMPARE(vols.first().toMap().value(QStringLiteral("path")).toString(),
                 QStringLiteral("/"));
    }

    void placesPointAtFoldersThatExist()
    {
        FolderBrowser b;
        const QVariantList places = b.places();
        QVERIFY(!places.isEmpty());
        QCOMPARE(places.first().toMap().value(QStringLiteral("path")).toString(),
                 QDir::homePath());
        for (const QVariant &p : places) {
            const QVariantMap m = p.toMap();
            QVERIFY(QFileInfo::exists(m.value(QStringLiteral("path")).toString()));
            QVERIFY(!m.value(QStringLiteral("icon")).toString().isEmpty());
        }
    }
};

QTEST_MAIN(TstFolderBrowser)
#include "tst_folderbrowser.moc"
