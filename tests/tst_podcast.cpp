#include <QtTest/QtTest>
#include <QSignalSpy>
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

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QVERIFY(Database::openConnection(QLatin1String(Database::kUiConnection),
                                         m_dir.filePath(QStringLiteral("t.db"))));
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        Database::applyPragmas(db);
        QVERIFY(Database::migrate(db));

        exec(QStringLiteral(
            "INSERT INTO podcast_shows (id, title, folder_path) VALUES (1, 'Programa', '/p')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_episodes (id, show_id, guid, title, published_at, duration_ms, "
            "local_path) VALUES (1, 1, 'g1', 'Ep 1', 100, 600000, '/p/1.mp3')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_episodes (id, show_id, guid, title, published_at, duration_ms, "
            "local_path) VALUES (2, 1, 'g2', 'Ep 2', 200, 600000, '/p/2.mp3')"));
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
        PodcastLibrary lib;
        const QVariantList list = lib.continueListening();
        QCOMPARE(list.size(), 1); // episode 1 only: 2 is finished, and nothing else was started
        QCOMPARE(list.first().toMap().value(QStringLiteral("id")).toInt(), 1);
        QVERIFY(list.first().toMap().value(QStringLiteral("progress")).toDouble() > 0.15);
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
};

QTEST_MAIN(TstPodcast)
#include "tst_podcast.moc"
