#include <QtTest/QtTest>
#include <QSignalSpy>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "database.h"
#include "librarybrowser.h"
#include "playstatsrecorder.h"
#include "tracklistmodel.h"

class TstLibraryBrowser : public QObject
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

    // The two seeded tracks are inserted with fixed ids; the first one is the fixture's
    // guinea pig for anything that needs one concrete track.
    static int firstTrackId() { return 1; }
    static QString firstTrackPath() { return QStringLiteral("/m/a.flac"); }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QVERIFY(Database::openConnection(QLatin1String(Database::kUiConnection),
                                         m_dir.filePath(QStringLiteral("t.db"))));
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        Database::applyPragmas(db);
        QVERIFY(Database::migrate(db));

        exec(QStringLiteral("INSERT INTO artists (id, name) VALUES (1, 'João Malandro')"));
        exec(QStringLiteral("INSERT INTO albums (id, title, album_artist_id) VALUES (1, 'Coração', 1)"));
        exec(QStringLiteral(
            "INSERT INTO tracks (id, path, mtime, size, title, artist_id, album_id, added_at) "
            "VALUES (1, '/m/a.flac', 1, 1, 'Canção do Mar', 1, 1, 1000)"));
        exec(QStringLiteral(
            "INSERT INTO tracks (id, path, mtime, size, title, artist_id, album_id, added_at) "
            "VALUES (2, '/m/b.flac', 1, 1, 'Outra Coisa', 1, 1, 2000)"));
        exec(QStringLiteral("INSERT INTO track_stats (track_id, first_seen_at) VALUES (1, 1000)"));
        exec(QStringLiteral("INSERT INTO track_stats (track_id, first_seen_at) VALUES (2, 2000)"));
    }

    // The FTS5 migration is entry 1 in the vector; later slices append their own, so what
    // matters here is that this database is at least at the version that created tracks_fts.
    void schemaIsAtLeastAtVersionTwo()
    {
        QVERIFY(scalar(QStringLiteral("PRAGMA user_version")) >= 2);
    }

    void artistsAreCountedFromActiveTracks()
    {
        LibraryBrowser browser;
        const QVariantList list = browser.artists();
        QCOMPARE(list.size(), 1);
        QCOMPARE(list.first().toMap().value(QStringLiteral("count")).toInt(), 2);
    }

    void ftsIndexWasBackfilledByTheMigration()
    {
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks_fts")), 2);
    }

    void searchMatchesIgnoringDiacritics()
    {
        // tokenize='unicode61 remove_diacritics 2' means "cancao" must find "Canção".
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM tracks_fts WHERE tracks_fts MATCH 'cancao*'")),
                 1);
    }

    void searchQuerySanitisesUserInput()
    {
        // Raw FTS5 syntax in user input must not reach the engine as syntax.
        QCOMPARE(LibraryBrowser::toFtsPrefixQuery(QStringLiteral("jo\" OR x:")),
                 QStringLiteral("jo* OR* x*"));
        QCOMPARE(LibraryBrowser::toFtsPrefixQuery(QStringLiteral("  mar  ")),
                 QStringLiteral("mar*"));
    }

    void recordPlayIncrementsTheCounter()
    {
        PlayStatsRecorder recorder;
        recorder.recordPlay(QStringLiteral("/m/a.flac"));
        recorder.recordPlay(QStringLiteral("/m/a.flac"));
        QCOMPARE(scalar(QStringLiteral("SELECT play_count FROM track_stats WHERE track_id = 1")), 2);
        QVERIFY(scalar(QStringLiteral(
                    "SELECT last_played_at IS NOT NULL FROM track_stats WHERE track_id = 1")) == 1);
    }

    void neverPlayedExcludesWhatWasPlayed()
    {
        LibraryBrowser browser;
        const QString sql = QStringLiteral("SELECT COUNT(*) FROM tracks t WHERE ")
                            + browser.clauseNeverPlayed();
        QCOMPARE(scalar(sql), 1); // track 2 only: track 1 has plays now
    }

    void forgottenNeedsBothPlaysAndAge()
    {
        exec(QStringLiteral("UPDATE track_stats SET play_count = 9, "
                            "last_played_at = strftime('%s','now') - 200*86400 WHERE track_id = 2"));
        LibraryBrowser browser;
        const QString sql = QStringLiteral("SELECT COUNT(*) FROM tracks t WHERE ")
                            + browser.clauseForgotten();
        QCOMPARE(scalar(sql), 1); // track 2: many plays, none recently
    }

    void toggleLikeFlipsAndPersists()
    {
        LibraryBrowser browser;
        const int id = firstTrackId();
        QVERIFY(!browser.isLiked(id));

        QSignalSpy spy(&browser, &LibraryBrowser::likedChanged);
        QCOMPARE(browser.toggleLike(id), true);
        QVERIFY(browser.isLiked(id));
        QCOMPARE(spy.count(), 1);
        QCOMPARE(spy.at(0).at(1).toBool(), true);

        QCOMPARE(browser.toggleLike(id), false);
        QVERIFY(!browser.isLiked(id));
        QCOMPARE(browser.likedCount(), 0);
    }

    void likedClauseOrdersByMostRecent()
    {
        LibraryBrowser browser;
        QVERIFY(browser.clauseForLiked().contains(QStringLiteral("liked_at IS NOT NULL")));
        QVERIFY(browser.clauseForLiked().contains(QStringLiteral("ORDER BY t.liked_at DESC")));

        TrackListModel model;
        browser.toggleLike(firstTrackId());
        model.loadFromQuery(browser.clauseForLiked(), {});
        QCOMPARE(model.rowCount(), 1);
        QCOMPARE(model.data(model.index(0), TrackListModel::LikedRole).toBool(), true);

        // Hand the shared fixture back unliked: the slots that follow assume a clean slate.
        browser.toggleLike(firstTrackId());
    }

    void toggleLikeOnMissingTrackIsHarmless()
    {
        LibraryBrowser browser;
        QCOMPARE(browser.toggleLike(999999), false);
        QCOMPARE(browser.likedCount(), 0);
    }
};

QTEST_MAIN(TstLibraryBrowser)
#include "tst_librarybrowser.moc"
