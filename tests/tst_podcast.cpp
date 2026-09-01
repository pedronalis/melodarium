#include <QtTest/QtTest>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QProcess>
#include <QSignalSpy>
#include <QSettings>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "database.h"
#include "podcastepisodemodel.h"
#include "podcastlibrary.h"

class TstPodcast : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;

    void exec(const QString &sql)
    {
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        QSqlQuery q(db);
        QVERIFY2(q.exec(sql), qPrintable(q.lastError().text()));
    }

    int scalar(const QString &sql)
    {
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        QSqlQuery q(db);
        return (q.exec(sql) && q.next()) ? q.value(0).toInt() : -1;
    }

    static QSet<int> idsOf(const QVariantList &rows)
    {
        QSet<int> ids;
        for (const QVariant &row : rows)
            ids.insert(row.toMap().value(QStringLiteral("id")).toInt());
        return ids;
    }

    static void makeAudioFixture(const QString &path)
    {
        QProcess process;
        process.start(QStringLiteral("ffmpeg"),
                      {QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"),
                       QStringLiteral("error"), QStringLiteral("-f"), QStringLiteral("lavfi"),
                       QStringLiteral("-i"), QStringLiteral("sine=330:d=0.1"),
                       QStringLiteral("-metadata"), QStringLiteral("title=Fixture"),
                       QStringLiteral("-y"), path});
        QVERIFY(process.waitForStarted(3000));
        QVERIFY(process.waitForFinished(15000));
        QCOMPARE(process.exitCode(), 0);
    }

    static QString quoted(QString value)
    {
        value.replace(QLatin1Char('\''), QStringLiteral("''"));
        return QLatin1Char('\'') + value + QLatin1Char('\'');
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_dir.path());
        QSettings().clear();
        QSettings().setValue(QStringLiteral("podcast/path"), QStringLiteral("/p"));

        QVERIFY(Database::openConnection(QLatin1String(Database::kUiConnection),
                                         m_dir.filePath(QStringLiteral("t.db"))));
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        Database::applyPragmas(db);
        QVERIFY(Database::migrate(db));

        exec(QStringLiteral(
            "INSERT INTO podcast_shows (id, title, folder_path, cover_path) "
            "VALUES (1, 'Programa', '/p', '/covers/programa.jpg')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_episodes (id, show_id, guid, title, published_at, duration_ms, "
            "local_path) VALUES (1, 1, 'g1', 'Ep 1', 100, 600000, '/p/1.mp3')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_episodes (id, show_id, guid, title, published_at, duration_ms, "
            "local_path) VALUES (2, 1, 'g2', 'Ep 2', 200, 600000, '/p/2.mp3')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_shows (id, title, folder_path) "
            "VALUES (10, 'Raiz antiga', '/old')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_episodes (id, show_id, guid, title, local_path) "
            "VALUES (10, 10, 'old', 'Ep antigo', '/old/old.mp3')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_shows (id, title, folder_path) "
            "VALUES (11, 'Filho atual', '/p/show')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_episodes (id, show_id, guid, title, local_path) "
            "VALUES (11, 11, 'child', 'Ep filho', '/p/show/child.mp3')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_shows (id, title, folder_path) "
            "VALUES (12, 'Prefixo parecido', '/podcast')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_episodes (id, show_id, guid, title, local_path) "
            "VALUES (12, 12, 'sibling', 'Ep prefixo', '/podcast/sibling.mp3')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_shows (id, title, feed_url) "
            "VALUES (13, 'Feed assinado', 'https://example.com/feed.xml')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_episodes (id, show_id, guid, title, local_path) "
            "VALUES (13, 13, 'feed', 'Ep feed', '/downloads/feed.mp3')"));
    }

    // Same reasoning as tst_collections: assert that migration 4 ran, not that nothing ever
    // comes after it. The feed-rss slice appends migration 5 to these very tables.
    void schemaIncludesThePodcastMigration()
    {
        QVERIFY(scalar(QStringLiteral("PRAGMA user_version")) >= 4);
    }

    void savingPositionMarksTheEpisodeAsStarted()
    {
        PodcastLibrary lib;
        lib.savePosition(1, 120000); // 2 min into a 10 min episode
        QCOMPARE(scalar(QStringLiteral("SELECT position_ms FROM podcast_episodes WHERE id = 1")),
                 120000);
        QCOMPARE(scalar(QStringLiteral("SELECT played FROM podcast_episodes WHERE id = 1")), 0);
    }

    void reachingTheEndMarksItPlayedWithoutTheOutro()
    {
        PodcastLibrary lib;
        lib.savePosition(2, 580000); // 96.7% of 600000 — above kPlayedThreshold
        QCOMPARE(scalar(QStringLiteral("SELECT played FROM podcast_episodes WHERE id = 2")), 1);
    }

    void continueListeningShowsOnlyStartedAndUnfinished()
    {
        exec(QStringLiteral(
            "UPDATE podcast_episodes SET position_ms = 120000, last_played_at = 2000 "
            "WHERE id = 1"));
        PodcastLibrary lib;
        const QVariantList list = lib.continueListening();
        QCOMPARE(list.size(), 1); // episode 1 only: 2 is finished, and nothing else was started
        const QVariantMap episode = list.first().toMap();
        QCOMPARE(episode.value(QStringLiteral("id")).toInt(), 1);
        QCOMPARE(episode.value(QStringLiteral("showId")).toInt(), 1);
        QCOMPARE(episode.value(QStringLiteral("coverPath")).toString(),
                 QStringLiteral("/covers/programa.jpg"));
        QVERIFY(episode.value(QStringLiteral("progress")).toDouble() > 0.15);
    }

    void resumingRewindsAFewSeconds()
    {
        PodcastLibrary lib;
        QSignalSpy spy(&lib, &PodcastLibrary::episodePlayRequested);
        lib.playEpisode(1);
        QCOMPARE(spy.count(), 1);
        QCOMPARE(spy.at(0).at(0).toString(), QStringLiteral("/p/1.mp3"));
        // 120 s saved, minus kResumeBackoffSec
        QCOMPARE(spy.at(0).at(1).toInt(), 120 - PodcastLibrary::kResumeBackoffSec);
    }

    void unmarkingPlayedKeepsThePosition()
    {
        PodcastLibrary lib;
        lib.markPlayed(2, false);
        QCOMPARE(scalar(QStringLiteral("SELECT played FROM podcast_episodes WHERE id = 2")), 0);
        QCOMPARE(scalar(QStringLiteral("SELECT position_ms FROM podcast_episodes WHERE id = 2")),
                 580000);
    }

    void markingPlayedResetsThePosition()
    {
        PodcastLibrary lib;
        lib.markPlayed(1, true);
        QCOMPARE(scalar(QStringLiteral("SELECT position_ms FROM podcast_episodes WHERE id = 1")), 0);
    }

    void episodeModelOrdersNewestFirst()
    {
        PodcastEpisodeModel model;
        model.loadForShow(1);
        QCOMPARE(model.rowCount(), 2);
        QCOMPARE(model.data(model.index(0), PodcastEpisodeModel::TitleRole).toString(),
                 QStringLiteral("Ep 2"));
    }

    void changingFolderScopesLocalContentAndKeepsFeeds()
    {
        PodcastLibrary lib;

        lib.setPodcastPath(QStringLiteral("/old"));
        QCOMPARE(idsOf(lib.shows()), QSet<int>({10, 13}));

        lib.setPodcastPath(QStringLiteral("/p"));
        QCOMPARE(idsOf(lib.shows()), QSet<int>({1, 11, 13}));
        QCOMPARE(idsOf(lib.allEpisodes()), QSet<int>({1, 2, 11, 13}));
        QVERIFY(lib.allEpisodes(10).isEmpty());
    }

    void continueListeningIgnoresFormerLocalRoot()
    {
        exec(QStringLiteral(
            "UPDATE podcast_episodes SET position_ms = 1000, last_played_at = 1000 "
            "WHERE id IN (10, 13)"));

        PodcastLibrary lib;
        lib.setPodcastPath(QStringLiteral("/p"));
        const QSet<int> ids = idsOf(lib.continueListening());
        QVERIFY(ids.contains(13));
        QVERIFY(!ids.contains(10));
    }

    void episodeModelRejectsAFormerLocalRoot()
    {
        PodcastEpisodeModel model;
        model.loadForShow(10);
        QCOMPARE(model.rowCount(), 0);

        model.loadForShow(11);
        QCOMPARE(model.rowCount(), 1);

        model.loadForShow(13);
        QCOMPARE(model.rowCount(), 1);
    }

    void localScanKeepsTheMainThreadAliveAndRefreshesOnce()
    {
        const QString rootPath = m_dir.filePath(QStringLiteral("heartbeat-podcasts"));
        const QString showPath = rootPath + QStringLiteral("/Heartbeat Show");
        QVERIFY(QDir().mkpath(showPath));
        const QString seed = showPath + QStringLiteral("/seed.flac");
        makeAudioFixture(seed);
        for (int i = 0; i < 300; ++i) {
            QVERIFY(QFile::copy(seed, showPath + QStringLiteral("/episode-%1.flac").arg(i)));
        }

        PodcastLibrary library;
        library.setPodcastPath(rootPath);
        QSignalSpy showsChanged(&library, &PodcastLibrary::showsChanged);
        QSignalSpy episodesChanged(&library, &PodcastLibrary::episodesChanged);
        int heartbeat = 0;
        QTimer timer;
        timer.setInterval(1);
        connect(&timer, &QTimer::timeout, this, [&heartbeat]() { ++heartbeat; });
        timer.start();
        QElapsedTimer wall;
        wall.start();

        library.scanPodcastFolder();
        QVERIFY(library.scanning());
        QTRY_VERIFY_WITH_TIMEOUT(!library.scanning(), 30000);
        timer.stop();

        QVERIFY2(heartbeat >= 1, qPrintable(QStringLiteral("heartbeat=%1").arg(heartbeat)));
        QCOMPARE(showsChanged.count() + episodesChanged.count(), 1);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM podcast_episodes WHERE local_path "
                                       "LIKE %1").arg(quoted(rootPath + QStringLiteral("/%")))),
                 301);
        qInfo().noquote() << QStringLiteral("PODCAST_PERF fixtures=301 wall_ms=%1 heartbeat=%2")
                                 .arg(wall.elapsed())
                                 .arg(heartbeat);
    }

    void localScanRollsBackTheWholeBatchOnFailure()
    {
        const QString rootPath = m_dir.filePath(QStringLiteral("rollback-podcasts"));
        const QString showPath = rootPath + QStringLiteral("/Rollback Show");
        QVERIFY(QDir().mkpath(showPath));
        makeAudioFixture(showPath + QStringLiteral("/episode.flac"));

        const int showsBefore = scalar(QStringLiteral("SELECT COUNT(*) FROM podcast_shows"));
        const int episodesBefore = scalar(QStringLiteral("SELECT COUNT(*) FROM podcast_episodes"));
        exec(QStringLiteral(
                 "CREATE TRIGGER fail_local_podcast BEFORE INSERT ON podcast_episodes "
                 "WHEN NEW.local_path LIKE %1 BEGIN SELECT RAISE(ABORT, 'forced'); END")
                 .arg(quoted(rootPath + QStringLiteral("/%"))));

        PodcastLibrary library;
        library.setPodcastPath(rootPath);
        QSignalSpy showsChanged(&library, &PodcastLibrary::showsChanged);
        QSignalSpy episodesChanged(&library, &PodcastLibrary::episodesChanged);
        QSignalSpy scanFailed(&library, &PodcastLibrary::localScanFailed);
        library.scanPodcastFolder();
        QTRY_VERIFY_WITH_TIMEOUT(!library.scanning(), 10000);
        exec(QStringLiteral("DROP TRIGGER fail_local_podcast"));

        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM podcast_shows")), showsBefore);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM podcast_episodes")), episodesBefore);
        QCOMPARE(showsChanged.count() + episodesChanged.count(), 0);
        QCOMPARE(scanFailed.count(), 1);
    }
};

QTEST_MAIN(TstPodcast)
#include "tst_podcast.moc"
