#include <QtTest/QtTest>

#include <QFile>
#include <QProcess>
#include <QSignalSpy>
#include <QTemporaryDir>

#include "database.h"
#include "librarywatcher.h"

class TstLibraryWatcher : public QObject
{
    Q_OBJECT

    static void writeFile(const QString &path, const QByteArray &contents = "x")
    {
        QFile file(path);
        QVERIFY2(file.open(QIODevice::WriteOnly), qPrintable(file.errorString()));
        QCOMPARE(file.write(contents), contents.size());
    }

    static void makeAudioFixture(const QString &path)
    {
        QProcess process;
        process.start(QStringLiteral("ffmpeg"),
                      {QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"),
                       QStringLiteral("error"), QStringLiteral("-f"), QStringLiteral("lavfi"),
                       QStringLiteral("-i"), QStringLiteral("sine=440:d=0.1"),
                       QStringLiteral("-y"), path});
        QVERIFY(process.waitForStarted(3000));
        QVERIFY(process.waitForFinished(15000));
        QCOMPARE(process.exitCode(), 0);
    }

private slots:
    void burstsEmitOnce()
    {
        QTemporaryDir root;
        QVERIFY(root.isValid());
        LibraryWatcher watcher;
        watcher.setDebounceInterval(60);
        watcher.setRoot(root.path());
        QSignalSpy requested(&watcher, &LibraryWatcher::scanRequested);

        for (int i = 0; i < 8; ++i)
            writeFile(root.filePath(QStringLiteral("burst-%1.flac").arg(i)));

        QTRY_COMPARE_WITH_TIMEOUT(requested.count(), 1, 1000);
        QTest::qWait(180);
        QCOMPARE(requested.count(), 1);
    }

    void newSubdirectoryIsWatchedAfterScanRearm()
    {
        QTemporaryDir root;
        QVERIFY(root.isValid());
        LibraryWatcher watcher;
        watcher.setDebounceInterval(40);
        watcher.setRoot(root.path());
        QSignalSpy requested(&watcher, &LibraryWatcher::scanRequested);

        QVERIFY(QDir(root.path()).mkpath(QStringLiteral("new-album")));
        QTRY_COMPARE_WITH_TIMEOUT(requested.count(), 1, 1000);

        watcher.scanStarted();
        watcher.scanFinished();
        writeFile(root.filePath(QStringLiteral("new-album/track.flac")));
        QTRY_COMPARE_WITH_TIMEOUT(requested.count(), 2, 1000);
    }

    void renamedDirectoryIsRearmedAfterScan()
    {
        QTemporaryDir root;
        QVERIFY(root.isValid());
        QVERIFY(QDir(root.path()).mkpath(QStringLiteral("before")));
        writeFile(root.filePath(QStringLiteral("before/track.flac")));

        LibraryWatcher watcher;
        watcher.setDebounceInterval(40);
        watcher.setRoot(root.path());
        QSignalSpy requested(&watcher, &LibraryWatcher::scanRequested);

        QVERIFY(QDir(root.path()).rename(QStringLiteral("before"), QStringLiteral("after")));
        QTRY_COMPARE_WITH_TIMEOUT(requested.count(), 1, 1000);

        watcher.scanStarted();
        watcher.scanFinished();
        writeFile(root.filePath(QStringLiteral("after/track.flac")), "changed");
        QTRY_COMPARE_WITH_TIMEOUT(requested.count(), 2, 1000);
    }

    void finishingScanConsumesTheCoveredDebounce()
    {
        QTemporaryDir root;
        QVERIFY(root.isValid());
        LibraryWatcher watcher;
        watcher.setDebounceInterval(80);
        watcher.setRoot(root.path());
        QSignalSpy changed(&watcher, &LibraryWatcher::changeDetected);
        QSignalSpy requested(&watcher, &LibraryWatcher::scanRequested);

        watcher.scanStarted();
        writeFile(root.filePath(QStringLiteral("during-scan.flac")));
        QTRY_COMPARE_WITH_TIMEOUT(changed.count(), 1, 1000);
        watcher.scanFinished();
        QTest::qWait(200);
        QCOMPARE(requested.count(), 0);

        writeFile(root.filePath(QStringLiteral("after-scan.flac")));
        QTRY_COMPARE_WITH_TIMEOUT(requested.count(), 1, 1000);
    }

    void changingOrDisablingTheRootDropsOldEvents()
    {
        QTemporaryDir outer;
        QVERIFY(outer.isValid());
        QVERIFY(QDir(outer.path()).mkpath(QStringLiteral("one")));
        QVERIFY(QDir(outer.path()).mkpath(QStringLiteral("two")));
        const QString one = outer.filePath(QStringLiteral("one"));
        const QString two = outer.filePath(QStringLiteral("two"));

        LibraryWatcher watcher;
        watcher.setDebounceInterval(80);
        watcher.setRoot(one);
        QSignalSpy requested(&watcher, &LibraryWatcher::scanRequested);

        writeFile(one + QStringLiteral("/stale.flac"));
        watcher.setRoot(two);
        QTest::qWait(200);
        QCOMPARE(requested.count(), 0);

        writeFile(one + QStringLiteral("/ignored.flac"));
        QTest::qWait(200);
        QCOMPARE(requested.count(), 0);

        writeFile(two + QStringLiteral("/current.flac"));
        QTRY_COMPARE_WITH_TIMEOUT(requested.count(), 1, 1000);

        watcher.setEnabled(false);
        writeFile(two + QStringLiteral("/disabled.flac"));
        QTest::qWait(200);
        QCOMPARE(requested.count(), 1);
    }

    void databaseCoalescesChangesDuringScanIntoOneFollowUp()
    {
        QTemporaryDir xdg;
        QTemporaryDir music;
        QVERIFY(xdg.isValid());
        QVERIFY(music.isValid());
        qputenv("XDG_CONFIG_HOME", xdg.filePath(QStringLiteral("config")).toUtf8());
        qputenv("XDG_DATA_HOME", xdg.filePath(QStringLiteral("data")).toUtf8());
        qputenv("XDG_CACHE_HOME", xdg.filePath(QStringLiteral("cache")).toUtf8());
        QCoreApplication::setOrganizationName(QStringLiteral("melodarium-watcher-test"));
        QCoreApplication::setApplicationName(QStringLiteral("melodarium-watcher-test"));

        const QString seed = music.filePath(QStringLiteral("seed.flac"));
        makeAudioFixture(seed);
        for (int i = 0; i < 100; ++i) {
            QVERIFY(QFile::copy(seed,
                                music.filePath(QStringLiteral("track-%1.flac").arg(i))));
        }

        Database database;
        QVERIFY(database.ready());
        database.setLibraryPath(music.path());
        QSignalSpy finished(&database, &Database::scanFinished);
        database.startScan();

        for (int i = 0; i < 8; ++i)
            writeFile(music.filePath(QStringLiteral("burst-%1.flac").arg(i)), "invalid");

        QTRY_COMPARE_WITH_TIMEOUT(finished.count(), 2, 15000);
        QTest::qWait(500);
        QCOMPARE(finished.count(), 2);
    }
};

QTEST_MAIN(TstLibraryWatcher)
#include "tst_librarywatcher.moc"
