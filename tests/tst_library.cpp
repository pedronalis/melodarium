#include <QtTest/QtTest>
#include <QProcess>
#include <QSignalSpy>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "database.h"
#include "libraryscanner.h"
#include "tagreader.h"

class TstLibrary : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_music;
    QTemporaryDir m_data;

    // Writes a FLAC with real tags using ffmpeg. Empty return = ffmpeg missing.
    static QString makeTagged(const QString &path, const QString &title, const QString &artist,
                              const QString &album)
    {
        QProcess p;
        p.start(QStringLiteral("ffmpeg"),
                {QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"),
                 QStringLiteral("error"), QStringLiteral("-f"), QStringLiteral("lavfi"),
                 QStringLiteral("-i"), QStringLiteral("sine=440:d=1"),
                 QStringLiteral("-metadata"), QStringLiteral("title=%1").arg(title),
                 QStringLiteral("-metadata"), QStringLiteral("artist=%1").arg(artist),
                 QStringLiteral("-metadata"), QStringLiteral("album=%1").arg(album),
                 QStringLiteral("-y"), path});
        if (!p.waitForStarted(3000))
            return {};
        p.waitForFinished(15000);
        return (p.exitCode() == 0 && QFile::exists(path)) ? path : QString();
    }

    QString dbPath() const { return m_data.filePath(QStringLiteral("test.db")); }

    int scalar(const QString &sql)
    {
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("verify"));
        QSqlQuery q(db);
        return (q.exec(sql) && q.next()) ? q.value(0).toInt() : -1;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_music.isValid());
        QVERIFY(m_data.isValid());
        if (makeTagged(m_music.filePath(QStringLiteral("one.flac")),
                       QStringLiteral("Primeira"), QStringLiteral("Artista"),
                       QStringLiteral("Álbum"))
                .isEmpty())
            QSKIP("ffmpeg unavailable: cannot generate tagged fixtures");
        makeTagged(m_music.filePath(QStringLiteral("two.flac")), QStringLiteral("Segunda"),
                   QStringLiteral("Artista"), QStringLiteral("Álbum"));

        QVERIFY(Database::openConnection(QStringLiteral("verify"), dbPath()));
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("verify"));
        Database::applyPragmas(db);
        QVERIFY(Database::migrate(db));
    }

    void migrationSetsUserVersion()
    {
        // Later slices append migrations, so the exact number is not the contract: what this
        // asserts is that migrating moved the version off zero and created the base schema.
        QVERIFY(scalar(QStringLiteral("PRAGMA user_version")) >= 1);
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='tracks'")),
                 1);
    }

    void migrationIsIdempotent()
    {
        const int before = scalar(QStringLiteral("PRAGMA user_version"));
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("verify"));
        QVERIFY(Database::migrate(db)); // running it again must not fail nor duplicate anything
        QCOMPARE(scalar(QStringLiteral("PRAGMA user_version")), before);
    }

    void migration4AddsLikedColumn()
    {
        QTemporaryDir dir;
        const QString dbPath = dir.filePath(QStringLiteral("m4.db"));
        QVERIFY(Database::openConnection(QStringLiteral("m4"), dbPath));
        {
            QSqlDatabase db = QSqlDatabase::database(QStringLiteral("m4"));
            QVERIFY(Database::migrate(db));

            QSqlQuery v(db);
            QVERIFY(v.exec(QStringLiteral("PRAGMA user_version")));
            QVERIFY(v.next());
            // The liked_at script is the seventh migration, so a fully migrated database sits
            // at 7 or higher once later slices append their own.
            QVERIFY(v.value(0).toInt() >= 7);

            QSqlQuery c(db);
            QVERIFY(c.exec(QStringLiteral("SELECT COUNT(*) FROM pragma_table_info('tracks') "
                                          "WHERE name = 'liked_at'")));
            QVERIFY(c.next());
            QCOMPARE(c.value(0).toInt(), 1);

            QSqlQuery i(db);
            QVERIFY(i.exec(QStringLiteral("SELECT COUNT(*) FROM sqlite_master "
                                          "WHERE type='index' AND name='idx_tracks_liked'")));
            QVERIFY(i.next());
            QCOMPARE(i.value(0).toInt(), 1);
        }
        QSqlDatabase::removeDatabase(QStringLiteral("m4"));
    }

    void tagReaderReadsUtf8Metadata()
    {
        const TrackRecord r = TagReader::read(m_music.filePath(QStringLiteral("one.flac")));
        QVERIFY(r.valid);
        QCOMPARE(r.title, QStringLiteral("Primeira"));
        QCOMPARE(r.artist, QStringLiteral("Artista"));
        QCOMPARE(r.album, QStringLiteral("Álbum")); // accented text must survive round-trip
        QCOMPARE(r.codec, QStringLiteral("flac"));
        QVERIFY(r.durationMs > 500);
        QVERIFY(r.sampleRate > 0);
        QVERIFY(r.bitsPerSample > 0); // FLAC::Properties exposes it; lossy formats do not
    }

    void tagReaderSkipsGarbageInsteadOfCrashing()
    {
        const QString junk = m_music.filePath(QStringLiteral("junk.mp3"));
        QFile f(junk);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("this is definitely not an mp3");
        f.close();
        const TrackRecord r = TagReader::read(junk);
        QCOMPARE(r.valid, false); // no crash, no exception: caller just skips it
        QFile::remove(junk);
    }

    void scanPopulatesTheLibrary()
    {
        LibraryScanner scanner;
        QSignalSpy done(&scanner, &LibraryScanner::finished);
        scanner.run(m_music.path(), dbPath());
        QCOMPARE(done.count(), 1);
        QCOMPARE(done.at(0).at(0).toInt(), 2); // added
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE removed_at IS NULL")), 2);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM artists")), 1);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM track_stats")), 2);
    }

    void rescanOfUnchangedFilesAddsNothing()
    {
        LibraryScanner scanner;
        QSignalSpy done(&scanner, &LibraryScanner::finished);
        scanner.run(m_music.path(), dbPath());
        QCOMPARE(done.at(0).at(0).toInt(), 0); // added
        QCOMPARE(done.at(0).at(1).toInt(), 0); // updated
        QCOMPARE(done.at(0).at(2).toInt(), 0); // removed
    }

    void movedFileKeepsItsRowAndStats()
    {
        // Give the track a play count, then move the file and rescan.
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("verify"));
        QSqlQuery up(db);
        QVERIFY(up.exec(QStringLiteral(
            "UPDATE track_stats SET play_count = 7 WHERE track_id = "
            "(SELECT id FROM tracks WHERE path LIKE '%one.flac')")));

        QVERIFY(QDir(m_music.path()).mkpath(QStringLiteral("sub")));
        const QString from = m_music.filePath(QStringLiteral("one.flac"));
        const QString to = m_music.filePath(QStringLiteral("sub/one.flac"));
        QVERIFY(QFile::rename(from, to));

        LibraryScanner scanner;
        QSignalSpy done(&scanner, &LibraryScanner::finished);
        scanner.run(m_music.path(), dbPath());
        QCOMPARE(done.at(0).at(0).toInt(), 0); // nothing was added: it was recognised as a move

        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE removed_at IS NULL")), 2);
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT play_count FROM track_stats WHERE track_id = "
                     "(SELECT id FROM tracks WHERE path LIKE '%sub/one.flac')")),
                 7); // the play count survived the move
    }

    void deletedFileIsSoftDeleted()
    {
        QVERIFY(QFile::remove(m_music.filePath(QStringLiteral("two.flac"))));
        LibraryScanner scanner;
        QSignalSpy done(&scanner, &LibraryScanner::finished);
        scanner.run(m_music.path(), dbPath());
        QCOMPARE(done.at(0).at(2).toInt(), 1); // removed
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE removed_at IS NULL")), 1);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks")), 2); // row still there
    }
};

QTEST_MAIN(TstLibrary)
#include "tst_library.moc"
