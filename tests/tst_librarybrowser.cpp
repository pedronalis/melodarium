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

    // Um resultado por tipo, com o limite valendo POR TIPO e não no total, é o contrato que o
    // overlay de busca consome: ele desenha os grupos na ordem em que chegam.
    void searchGroupedReturnsKindsAndRespectsLimit()
    {
        LibraryBrowser browser;
        QCOMPARE(browser.searchGrouped(QString()).size(), 0);
        QCOMPARE(browser.searchGrouped(QStringLiteral("   ")).size(), 0);

        const QVariantList hits = browser.searchGrouped(QStringLiteral("João"), 4);
        QVERIFY(!hits.isEmpty());

        QSet<QString> kinds;
        int artistas = 0;
        for (const QVariant &v : hits) {
            const QVariantMap m = v.toMap();
            QVERIFY(m.contains(QStringLiteral("kind")));
            QVERIFY(m.contains(QStringLiteral("title")));
            QVERIFY(m.contains(QStringLiteral("subtitle")));
            QVERIFY(m.contains(QStringLiteral("path")));
            const QString kind = m.value(QStringLiteral("kind")).toString();
            kinds.insert(kind);
            if (kind == QLatin1String("artist"))
                ++artistas;
        }
        QVERIFY(kinds.contains(QStringLiteral("artist")));
        QVERIFY(artistas <= 4);
    }

    // A faixa é o único tipo que toca sozinho: sem caminho, o Enter não teria o que abrir.
    void searchGroupedGivesTracksAPathAndASubtitle()
    {
        LibraryBrowser browser;
        const QVariantList hits = browser.searchGrouped(QStringLiteral("Canção"), 4);

        bool sawTrack = false;
        for (const QVariant &v : hits) {
            const QVariantMap m = v.toMap();
            if (m.value(QStringLiteral("kind")).toString() != QLatin1String("track"))
                continue;
            sawTrack = true;
            QCOMPARE(m.value(QStringLiteral("path")).toString(), firstTrackPath());
            QVERIFY(m.value(QStringLiteral("subtitle")).toString()
                        .contains(QStringLiteral("João Malandro")));
        }
        QVERIFY(sawTrack);
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

    void trackForPathReturnsFieldsOrEmpty()
    {
        LibraryBrowser browser;
        const QVariantMap none = browser.trackForPath(QStringLiteral("/nao/existe.flac"));
        QVERIFY(none.isEmpty());

        const QVariantMap m = browser.trackForPath(firstTrackPath());
        QVERIFY(!m.isEmpty());
        QCOMPARE(m.value(QStringLiteral("id")).toInt(), firstTrackId());
        QVERIFY(m.contains(QStringLiteral("codec")));
        QCOMPARE(m.value(QStringLiteral("liked")).toBool(), false);
    }

    // O convite "continuar de onde parou" precisa de duas coisas: a última faixa tocada e o
    // minuto em que ela parou. Caminho desconhecido não pode escrever nada nem explodir.
    // Último teste do arquivo de propósito: ele arruma as estatísticas ao gosto dele.
    void savedPositionComesBackWithTheLastPlayedTrack()
    {
        PlayStatsRecorder rec;
        LibraryBrowser browser;

        exec(QStringLiteral("UPDATE track_stats SET last_played_at = NULL"));
        exec(QStringLiteral("UPDATE track_stats SET last_played_at = 1700000000 "
                            "WHERE track_id = %1").arg(firstTrackId()));
        rec.savePosition(firstTrackPath(), 107000);

        const QVariantMap last = browser.lastPlayed();
        QCOMPARE(last.value(QStringLiteral("path")).toString(), firstTrackPath());
        QCOMPARE(last.value(QStringLiteral("positionMs")).toInt(), 107000);
        QVERIFY(!last.value(QStringLiteral("title")).toString().isEmpty());

        // Caminho que não existe não escreve em ninguém.
        rec.savePosition(QStringLiteral("/nao/existe.flac"), 5000);
        QCOMPARE(browser.lastPlayed().value(QStringLiteral("positionMs")).toInt(), 107000);
    }

    // Os dois números que aparecem como distintivo nos atalhos da tela "nada tocando".
    void neverPlayedAndForgottenAreCounted()
    {
        LibraryBrowser browser;

        exec(QStringLiteral("UPDATE track_stats SET play_count = 0, last_played_at = NULL"));
        QCOMPARE(browser.neverPlayedCount(), 2);
        QCOMPARE(browser.forgottenCount(), 0);

        // Muito tocada e sem tocar há muito tempo: é exatamente o que "esquecida" quer dizer.
        exec(QStringLiteral("UPDATE track_stats SET play_count = 9, last_played_at = 1000000 "
                            "WHERE track_id = %1").arg(firstTrackId()));
        QCOMPARE(browser.neverPlayedCount(), 1);
        QCOMPARE(browser.forgottenCount(), 1);
    }

};

QTEST_MAIN(TstLibraryBrowser)
#include "tst_librarybrowser.moc"
