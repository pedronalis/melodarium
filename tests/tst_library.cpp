#include <QtTest/QtTest>
#include <QCoreApplication>
#include <QFile>
#include <QProcess>
#include <QScopeGuard>
#include <QSignalSpy>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
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

    // Appends one more Vorbis field with the same name. ffmpeg cannot write a repeated
    // field, metaflac can, and a repeated field is exactly what this slice is about.
    static bool addTag(const QString &path, const QString &field, const QString &value)
    {
        QProcess p;
        p.start(QStringLiteral("metaflac"),
                {QStringLiteral("--set-tag=%1=%2").arg(field, value), path});
        if (!p.waitForStarted(3000))
            return false;
        p.waitForFinished(15000);
        return p.exitCode() == 0;
    }

    QString dbPath() const { return m_data.filePath(QStringLiteral("test.db")); }

    int scalar(const QString &sql)
    {
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("verify"));
        QSqlQuery q(db);
        return (q.exec(sql) && q.next()) ? q.value(0).toInt() : -1;
    }

    static bool rewindSchemaToVersion8(QSqlDatabase &db)
    {
        QSqlQuery q(db);
        return q.exec(QStringLiteral(
                   "ALTER TABLE podcast_shows DROP COLUMN retention_count"))
            && q.exec(QStringLiteral(
                "ALTER TABLE podcast_shows DROP COLUMN auto_download"))
            && q.exec(QStringLiteral("PRAGMA user_version = 8"));
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

    void databaseConnectionsWaitForTheOtherWriter()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString path = dir.filePath(QStringLiteral("busy.db"));
        QVERIFY(Database::openConnection(QStringLiteral("busy"), path));
        {
            QSqlDatabase db = QSqlDatabase::database(QStringLiteral("busy"));
            QSqlQuery reset(db);
            QVERIFY(reset.exec(QStringLiteral("PRAGMA busy_timeout = 0")));
            Database::applyPragmas(db);
            QSqlQuery timeout(db);
            QVERIFY(timeout.exec(QStringLiteral("PRAGMA busy_timeout")));
            QVERIFY(timeout.next());
            QCOMPARE(timeout.value(0).toInt(), 5000);
        }
        QSqlDatabase::removeDatabase(QStringLiteral("busy"));
    }

    void migrationCreatesARestorableBackupBeforeChangingSchema()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString path = dir.filePath(QStringLiteral("upgrade.db"));
        const QString backupPath = path + QStringLiteral(".pre-v8.bak");
        QVERIFY(Database::openConnection(QStringLiteral("upgrade"), path));
        {
            QSqlDatabase db = QSqlDatabase::database(QStringLiteral("upgrade"));
            Database::applyPragmas(db);
            QVERIFY(Database::migrate(db));

            {
                QSqlQuery marker(db);
                QVERIFY(marker.exec(QStringLiteral(
                    "INSERT INTO artists (id, name) VALUES (4242, 'Backup Marker')")));
                QVERIFY(rewindSchemaToVersion8(db));
            }

            QString migrationError;
            QVERIFY2(Database::migrate(db, &migrationError), qPrintable(migrationError));
            QVERIFY2(QFileInfo::exists(backupPath), qPrintable(backupPath));
        }
        QSqlDatabase::removeDatabase(QStringLiteral("upgrade"));

        QVERIFY(Database::openConnection(QStringLiteral("backup"), backupPath));
        {
            QSqlDatabase backup = QSqlDatabase::database(QStringLiteral("backup"));
            QSqlQuery version(backup);
            QVERIFY(version.exec(QStringLiteral("PRAGMA user_version")));
            QVERIFY(version.next());
            QCOMPARE(version.value(0).toInt(), 8);
            QSqlQuery marker(backup);
            QVERIFY(marker.exec(QStringLiteral(
                "SELECT COUNT(*) FROM artists WHERE id = 4242 AND name = 'Backup Marker'")));
            QVERIFY(marker.next());
            QCOMPARE(marker.value(0).toInt(), 1);
        }
        QSqlDatabase::removeDatabase(QStringLiteral("backup"));
    }

    void corruptDefaultDatabaseBecomesAVisibleStartupError()
    {
        QTemporaryDir xdg;
        QVERIFY(xdg.isValid());
        const QString previousName = QCoreApplication::applicationName();
        const QByteArray previousDataHome = qgetenv("XDG_DATA_HOME");
        const QByteArray previousConfigHome = qgetenv("XDG_CONFIG_HOME");
        const auto restoreEnvironment = qScopeGuard([=]() {
            if (previousDataHome.isNull())
                qunsetenv("XDG_DATA_HOME");
            else
                qputenv("XDG_DATA_HOME", previousDataHome);
            if (previousConfigHome.isNull())
                qunsetenv("XDG_CONFIG_HOME");
            else
                qputenv("XDG_CONFIG_HOME", previousConfigHome);
            QCoreApplication::setApplicationName(previousName);
        });
        qputenv("XDG_DATA_HOME", xdg.filePath(QStringLiteral("data")).toUtf8());
        qputenv("XDG_CONFIG_HOME", xdg.filePath(QStringLiteral("config")).toUtf8());
        QCoreApplication::setApplicationName(QStringLiteral("melodarium-corrupt-db-test"));
        const QString path = Database::defaultDatabasePath();
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile::remove(path);
        QFile corrupt(path);
        QVERIFY(corrupt.open(QIODevice::WriteOnly));
        QCOMPARE(corrupt.write("this is not sqlite", 18), 18);
        corrupt.close();

        {
            Database database;
            QVERIFY(database.metaObject()->indexOfProperty("ready") >= 0);
            QVERIFY(database.metaObject()->indexOfProperty("startupError") >= 0);
            QCOMPARE(database.property("ready").toBool(), false);
            QVERIFY(!database.property("startupError").toString().isEmpty());
            QVERIFY(database.property("startupError").toString().contains(path));
        }

        QSqlDatabase::removeDatabase(QLatin1String(Database::kUiConnection));
        QFile::remove(path);
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

    // Retomar do minuto exato exige guardar onde a faixa parou; o plano chama esta de
    // "migração 5", mas o que vale é a posição real dela na lista (a oitava).
    void migrationAddsLastPositionColumn()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("m5.db"));
        QVERIFY(Database::openConnection(QStringLiteral("m5"), path));
        {
            QSqlDatabase db = QSqlDatabase::database(QStringLiteral("m5"));
            QVERIFY(Database::migrate(db));

            QSqlQuery v(db);
            QVERIFY(v.exec(QStringLiteral("PRAGMA user_version")));
            QVERIFY(v.next());
            QVERIFY(v.value(0).toInt() >= 8);

            QSqlQuery c(db);
            QVERIFY(c.exec(QStringLiteral("SELECT COUNT(*) FROM pragma_table_info('track_stats') "
                                          "WHERE name = 'last_position_ms'")));
            QVERIFY(c.next());
            QCOMPARE(c.value(0).toInt(), 1);
        }
        QSqlDatabase::removeDatabase(QStringLiteral("m5"));
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

    // A correctly tagged file carries one ARTIST field per person. Reading it through
    // tag->artist() glues the list into "Daft Punk Julian Casablancas" — a band that never
    // existed, with a line of its own on the artists screen.
    void tagReaderKeepsOnlyTheMainArtist()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString path = dir.filePath(QStringLiteral("multi.flac"));
        if (makeTagged(path, QStringLiteral("Instant Crush"), QStringLiteral("Daft Punk"),
                       QStringLiteral("Random Access Memories"))
                .isEmpty())
            QSKIP("ffmpeg unavailable: cannot generate tagged fixtures");
        if (!addTag(path, QStringLiteral("ARTIST"), QStringLiteral("Julian Casablancas")))
            QSKIP("metaflac unavailable: cannot write a repeated Vorbis field");

        const TrackRecord r = TagReader::read(path);
        QVERIFY(r.valid);
        QCOMPARE(r.artist, QStringLiteral("Daft Punk")); // the guest gets no entry of its own
    }

    // The same defect was quietly wrecking the genres: "Rock Hard Rock Metal" instead of Rock.
    void tagReaderKeepsOnlyTheFirstGenre()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString path = dir.filePath(QStringLiteral("genres.flac"));
        if (makeTagged(path, QStringLiteral("Schism"), QStringLiteral("TOOL"),
                       QStringLiteral("Lateralus"))
                .isEmpty())
            QSKIP("ffmpeg unavailable: cannot generate tagged fixtures");
        if (!addTag(path, QStringLiteral("GENRE"), QStringLiteral("Rock"))
            || !addTag(path, QStringLiteral("GENRE"), QStringLiteral("Metal")))
            QSKIP("metaflac unavailable: cannot write a repeated Vorbis field");

        const TrackRecord r = TagReader::read(path);
        QVERIFY(r.valid);
        QCOMPARE(r.genre, QStringLiteral("Rock"));
    }

    // Badly tagged files stuff every name into one field. The rule is asked straight here,
    // with no audio behind it, because what it must NOT cut matters as much as what it cuts.
    void primaryNameCutsOnlyUnambiguousSeparators()
    {
        QCOMPARE(TagReader::primaryName(QStringLiteral("Daft Punk feat. Julian")),
                 QStringLiteral("Daft Punk"));
        QCOMPARE(TagReader::primaryName(QStringLiteral("Daft Punk FEAT Julian")),
                 QStringLiteral("Daft Punk"));
        QCOMPARE(TagReader::primaryName(QStringLiteral("Eminem ft. Rihanna")),
                 QStringLiteral("Eminem"));
        QCOMPARE(TagReader::primaryName(QStringLiteral("Queen featuring David Bowie")),
                 QStringLiteral("Queen"));
        QCOMPARE(TagReader::primaryName(QStringLiteral("A; B")), QStringLiteral("A"));

        // "&", "," and "/" are ambiguous: cutting there would destroy the name itself.
        QCOMPARE(TagReader::primaryName(QStringLiteral("Earth, Wind & Fire")),
                 QStringLiteral("Earth, Wind & Fire"));
        QCOMPARE(TagReader::primaryName(QStringLiteral("Simon & Garfunkel")),
                 QStringLiteral("Simon & Garfunkel"));
        QCOMPARE(TagReader::primaryName(QStringLiteral("AC/DC")), QStringLiteral("AC/DC"));

        // A name that only looks like a separator keeps its whole self.
        QCOMPARE(TagReader::primaryName(QStringLiteral("Fleetwood Mac")),
                 QStringLiteral("Fleetwood Mac"));
        QCOMPARE(TagReader::primaryName(QString()), QString());
        QCOMPARE(TagReader::primaryName(QStringLiteral("   ")), QString());
    }

    // Fixing the reader changes nothing on screen by itself: the scanner never opens a file
    // whose mtime and size still match, so every track already imported keeps the old name
    // until the migration wipes the mtime.
    void mtimeMigrationMakesTheScannerReadEverythingAgain()
    {
        QTemporaryDir music;
        QTemporaryDir data;
        QVERIFY(music.isValid());
        QVERIFY(data.isValid());
        if (makeTagged(music.filePath(QStringLiteral("inval.flac")), QStringLiteral("Uma"),
                       QStringLiteral("Artista"), QStringLiteral("Álbum"))
                .isEmpty())
            QSKIP("ffmpeg unavailable: cannot generate tagged fixtures");

        const QString path = data.filePath(QStringLiteral("inval.db"));
        QVERIFY(Database::openConnection(QStringLiteral("inval"), path));
        {
            QSqlDatabase db = QSqlDatabase::database(QStringLiteral("inval"));
            Database::applyPragmas(db);
            QVERIFY(Database::migrate(db));

            // Each query lives in its own scope: an unfinished read cursor keeps a read
            // transaction open in WAL mode, and the pragma write below then fails as locked.
            {
                QSqlQuery v(db);
                QVERIFY(v.exec(QStringLiteral("PRAGMA user_version")));
                QVERIFY(v.next());
                QVERIFY(v.value(0).toInt() >= 9); // the invalidation is the ninth migration
            }

            {
                LibraryScanner scanner;
                QSignalSpy done(&scanner, &LibraryScanner::finished);
                scanner.run(music.path(), path);
                QCOMPARE(done.at(0).at(0).toInt(), 1); // added
            }
            {
                LibraryScanner scanner;
                QSignalSpy done(&scanner, &LibraryScanner::finished);
                scanner.run(music.path(), path);
                QCOMPARE(done.at(0).at(1).toInt(), 0); // nothing changed on disk: file skipped
            }

            // Rewind to just before the invalidation and let it run for real.
            {
                QVERIFY(rewindSchemaToVersion8(db));
            }
            QVERIFY(Database::migrate(db));

            {
                QSqlQuery m(db);
                QVERIFY(m.exec(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE mtime <> 0")));
                QVERIFY(m.next());
                QCOMPARE(m.value(0).toInt(), 0); // every row is due for a re-read
            }

            {
                LibraryScanner scanner;
                QSignalSpy done(&scanner, &LibraryScanner::finished);
                scanner.run(music.path(), path);
                QCOMPARE(done.at(0).at(0).toInt(), 0); // still the same row
                QCOMPARE(done.at(0).at(1).toInt(), 1); // read again instead of skipped
            }
        }
        QSqlDatabase::removeDatabase(QStringLiteral("inval"));
    }

    // Renaming an artist leaves the old name behind. Invisible on screen, because every
    // listing joins tracks — but it is still in the table, and it is still wrong.
    void scanDropsArtistsAndGenresNothingPointsAt()
    {
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("verify"));
        QSqlQuery ghost(db);
        QVERIFY(ghost.exec(QStringLiteral(
            "INSERT INTO artists (name) VALUES ('Artista Convidado Fantasma')")));
        QSqlQuery ghostGenre(db);
        QVERIFY(ghostGenre.exec(QStringLiteral(
            "INSERT INTO genres (name) VALUES ('Rock Hard Rock Metal')")));

        // An artist held only by a soft-deleted track must survive: the drive comes back.
        QSqlQuery held(db);
        QVERIFY(held.exec(QStringLiteral("INSERT INTO artists (name) VALUES ('Artista Sumido')")));
        const int heldId = held.lastInsertId().toInt();
        QSqlQuery orphanTrack(db);
        orphanTrack.prepare(QStringLiteral(
            "INSERT INTO tracks (path, mtime, size, title, artist_id, added_at, removed_at) "
            "VALUES ('/nao/existe/sumida.flac', 1, 1, 'Sumida', ?, 1, 1)"));
        orphanTrack.addBindValue(heldId);
        QVERIFY(orphanTrack.exec());

        LibraryScanner scanner;
        QSignalSpy done(&scanner, &LibraryScanner::finished);
        scanner.run(m_music.path(), dbPath());
        QCOMPARE(done.count(), 1);

        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM artists WHERE name = 'Artista Convidado Fantasma'")),
                 0);
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM genres WHERE name = 'Rock Hard Rock Metal'")),
                 0);
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM artists WHERE name = 'Artista Sumido'")),
                 1);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM artists WHERE name = 'Artista'")), 1);
    }
};

QTEST_MAIN(TstLibrary)
#include "tst_library.moc"
