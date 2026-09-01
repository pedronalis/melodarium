#include "database.h"
#include "libraryscanner.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QSqlError>
#include <QSqlQuery>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QThread>
#include <QVariant>

namespace {

// Index = target version. migrations[0] takes the database from version 0 to 1.
// NEVER edit a published entry: a wrong migration is fixed by appending a new one.
const QList<QString> &migrations()
{
    static const QList<QString> list = {
        QStringLiteral(R"SQL(
CREATE TABLE artists (
    id             INTEGER PRIMARY KEY,
    name           TEXT NOT NULL UNIQUE,
    sort_name      TEXT,
    musicbrainz_id TEXT
);
CREATE TABLE albums (
    id              INTEGER PRIMARY KEY,
    title           TEXT NOT NULL,
    album_artist_id INTEGER REFERENCES artists(id) ON DELETE SET NULL,
    year            INTEGER,
    musicbrainz_id  TEXT,
    cover_path      TEXT,
    cover_source    TEXT CHECK(cover_source IN ('embedded','file','none')) DEFAULT 'none',
    UNIQUE(title, album_artist_id)
);
CREATE TABLE genres (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);
CREATE TABLE tracks (
    id                    INTEGER PRIMARY KEY,
    path                  TEXT NOT NULL UNIQUE,
    mtime                 INTEGER NOT NULL,
    size                  INTEGER NOT NULL,
    content_hash          TEXT,
    duration_ms           INTEGER,
    sample_rate           INTEGER,
    bits_per_sample       INTEGER,
    channels              INTEGER,
    bitrate_kbps          INTEGER,
    codec                 TEXT,
    title                 TEXT,
    track_no              INTEGER,
    disc_no               INTEGER,
    year                  INTEGER,
    composer              TEXT,
    artist_id             INTEGER REFERENCES artists(id) ON DELETE SET NULL,
    album_id              INTEGER REFERENCES albums(id) ON DELETE SET NULL,
    genre_id              INTEGER REFERENCES genres(id) ON DELETE SET NULL,
    replaygain_track_gain REAL,
    replaygain_album_gain REAL,
    musicbrainz_track_id  TEXT,
    added_at              INTEGER NOT NULL,
    removed_at            INTEGER
);
CREATE INDEX idx_tracks_album  ON tracks(album_id);
CREATE INDEX idx_tracks_artist ON tracks(artist_id);
CREATE INDEX idx_tracks_genre  ON tracks(genre_id);
CREATE INDEX idx_tracks_hash   ON tracks(content_hash);
CREATE INDEX idx_tracks_active ON tracks(removed_at) WHERE removed_at IS NULL;
CREATE TABLE track_stats (
    track_id       INTEGER PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE,
    play_count     INTEGER NOT NULL DEFAULT 0,
    skip_count     INTEGER NOT NULL DEFAULT 0,
    last_played_at INTEGER,
    first_seen_at  INTEGER NOT NULL
);
)SQL"),
        QStringLiteral(R"SQL(
CREATE VIRTUAL TABLE tracks_fts USING fts5(
    title, artist_name, album_title,
    content='',
    tokenize='unicode61 remove_diacritics 2'
);
CREATE TRIGGER trg_tracks_ai AFTER INSERT ON tracks BEGIN
    INSERT INTO tracks_fts(rowid, title, artist_name, album_title)
    SELECT new.id, IFNULL(new.title,''),
           IFNULL((SELECT name FROM artists WHERE id = new.artist_id),''),
           IFNULL((SELECT title FROM albums WHERE id = new.album_id),'');
END;
CREATE TRIGGER trg_tracks_ad AFTER DELETE ON tracks BEGIN
    INSERT INTO tracks_fts(tracks_fts, rowid, title, artist_name, album_title)
    VALUES('delete', old.id, IFNULL(old.title,''), '', '');
END;
CREATE TRIGGER trg_tracks_au AFTER UPDATE ON tracks BEGIN
    INSERT INTO tracks_fts(tracks_fts, rowid, title, artist_name, album_title)
    VALUES('delete', old.id, IFNULL(old.title,''), '', '');
    INSERT INTO tracks_fts(rowid, title, artist_name, album_title)
    SELECT new.id, IFNULL(new.title,''),
           IFNULL((SELECT name FROM artists WHERE id = new.artist_id),''),
           IFNULL((SELECT title FROM albums WHERE id = new.album_id),'');
END;
INSERT INTO tracks_fts(rowid, title, artist_name, album_title)
SELECT t.id, IFNULL(t.title,''), IFNULL(ar.name,''), IFNULL(al.title,'')
FROM tracks t
LEFT JOIN artists ar ON ar.id = t.artist_id
LEFT JOIN albums al ON al.id = t.album_id;
)SQL"),
        QStringLiteral(R"SQL(
CREATE TABLE collections (
    id         INTEGER PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE COLLATE NOCASE,
    created_at INTEGER NOT NULL
);
CREATE TABLE collection_tracks (
    collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    track_id      INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    position      INTEGER NOT NULL,
    added_at      INTEGER NOT NULL,
    PRIMARY KEY (collection_id, track_id)
);
CREATE INDEX idx_coltracks_order ON collection_tracks(collection_id, position);
CREATE TABLE tags (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE COLLATE NOCASE
);
CREATE TABLE track_tags (
    track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    tag_id   INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (track_id, tag_id)
);
CREATE INDEX idx_tags_name    ON tags(name);
CREATE INDEX idx_tracktags_tag ON track_tags(tag_id);
)SQL"),
        QStringLiteral(R"SQL(
CREATE TABLE podcast_shows (
    id              INTEGER PRIMARY KEY,
    title           TEXT NOT NULL,
    folder_path     TEXT UNIQUE,
    feed_url        TEXT UNIQUE,
    etag            TEXT,
    last_modified   TEXT,
    last_checked_at INTEGER,
    cover_path      TEXT
);
CREATE TABLE podcast_episodes (
    id           INTEGER PRIMARY KEY,
    show_id      INTEGER NOT NULL REFERENCES podcast_shows(id) ON DELETE CASCADE,
    guid         TEXT NOT NULL,
    title        TEXT NOT NULL,
    published_at INTEGER,
    duration_ms  INTEGER,
    local_path   TEXT,
    position_ms  INTEGER NOT NULL DEFAULT 0,
    played       INTEGER NOT NULL DEFAULT 0 CHECK(played IN (0,1)),
    last_played_at INTEGER,
    UNIQUE(show_id, guid)
);
CREATE INDEX idx_episodes_show   ON podcast_episodes(show_id, published_at DESC);
CREATE INDEX idx_episodes_resume ON podcast_episodes(last_played_at DESC) WHERE played = 0;
CREATE UNIQUE INDEX idx_episodes_path ON podcast_episodes(local_path) WHERE local_path IS NOT NULL;
)SQL"),
        QStringLiteral(R"SQL(
ALTER TABLE podcast_episodes ADD COLUMN remote_url TEXT;
ALTER TABLE podcast_episodes ADD COLUMN download_state TEXT
    CHECK(download_state IN ('none','downloading','done','failed')) DEFAULT 'none';
)SQL"),
        QStringLiteral(R"SQL(
ALTER TABLE tracks ADD COLUMN source_kind TEXT
    CHECK(source_kind IN ('local_file','youtube')) DEFAULT 'local_file';
ALTER TABLE tracks ADD COLUMN source_url TEXT;
ALTER TABLE tracks ADD COLUMN source_format_note TEXT;
ALTER TABLE tracks ADD COLUMN downloaded_at INTEGER;
CREATE INDEX idx_tracks_source ON tracks(source_kind);
)SQL"),
        QStringLiteral(R"SQL(
ALTER TABLE tracks ADD COLUMN liked_at INTEGER;
CREATE INDEX idx_tracks_liked ON tracks(liked_at) WHERE liked_at IS NOT NULL;
)SQL"),
        QStringLiteral(R"SQL(
ALTER TABLE track_stats ADD COLUMN last_position_ms INTEGER NOT NULL DEFAULT 0;
)SQL"),
        // Tag reading was fixed: a multi-value ARTIST used to be glued into one fake band
        // name. The scanner never opens a file whose mtime and size still match, so without
        // this every track already imported would keep the wrong name forever. Zeroing mtime
        // costs one full re-read, once. content_hash is left alone: it is what pairs a moved
        // file with its row, and each track comes back through the UPDATE branch with its
        // id, likes and play counts intact.
        QStringLiteral(R"SQL(
UPDATE tracks SET mtime = 0;
)SQL"),
    };
    return list;
}

// SQLite triggers carry their own ";" inside BEGIN ... END. Splitting the script on every ";"
// cuts a trigger in half and the migration dies with a syntax error, so the trigger body is
// kept whole here. String literals are tracked as well: a ";" inside quotes ends nothing.
QStringList splitStatements(const QString &script)
{
    auto triggerBodyStillOpen = [](const QString &stmt) {
        const QString up = stmt.trimmed().toUpper();
        if (!up.startsWith(QLatin1String("CREATE TRIGGER"))
            && !up.startsWith(QLatin1String("CREATE TEMP TRIGGER"))
            && !up.startsWith(QLatin1String("CREATE TEMPORARY TRIGGER")))
            return false;
        if (!up.endsWith(QLatin1String("END")))
            return true;
        // "END" has to be the closing keyword, not the tail of an identifier.
        return up.size() > 3 && !up.at(up.size() - 4).isSpace();
    };

    QStringList out;
    QString current;
    bool inString = false;
    for (int i = 0; i < script.size(); ++i) {
        const QChar c = script.at(i);
        if (inString) {
            current.append(c);
            if (c == QLatin1Char('\'')) {
                if (i + 1 < script.size() && script.at(i + 1) == QLatin1Char('\''))
                    current.append(script.at(++i)); // "''" is an escaped quote, not the end
                else
                    inString = false;
            }
            continue;
        }
        if (c == QLatin1Char('\'')) {
            inString = true;
            current.append(c);
            continue;
        }
        if (c == QLatin1Char(';') && !triggerBodyStillOpen(current)) {
            const QString stmt = current.trimmed();
            if (!stmt.isEmpty())
                out.append(stmt);
            current.clear();
            continue;
        }
        current.append(c);
    }
    const QString tail = current.trimmed();
    if (!tail.isEmpty())
        out.append(tail);
    return out;
}

bool quickCheck(QSqlDatabase &db, QString *error)
{
    QSqlQuery check(db);
    if (!check.exec(QStringLiteral("PRAGMA quick_check"))) {
        if (error)
            *error = check.lastError().text();
        return false;
    }
    while (check.next()) {
        const QString result = check.value(0).toString();
        if (result != QStringLiteral("ok")) {
            if (error)
                *error = result;
            return false;
        }
    }
    return true;
}

bool createMigrationBackup(QSqlDatabase &db, int currentVersion, QString *backupPath,
                           QString *error)
{
    if (currentVersion <= 0)
        return true;

    const QString path = db.databaseName()
                         + QStringLiteral(".pre-v%1.bak").arg(currentVersion);
    if (QFileInfo::exists(path)) {
        if (backupPath)
            *backupPath = path;
        return true;
    }

    QSqlQuery checkpoint(db);
    if (!checkpoint.exec(QStringLiteral("PRAGMA wal_checkpoint(FULL)"))) {
        if (error)
            *error = checkpoint.lastError().text();
        return false;
    }
    checkpoint.finish();

    QString escapedPath = path;
    escapedPath.replace(QLatin1Char('\''), QStringLiteral("''"));
    QSqlQuery backup(db);
    if (!backup.exec(QStringLiteral("VACUUM INTO '%1'").arg(escapedPath))) {
        if (error)
            *error = backup.lastError().text();
        return false;
    }
    if (backupPath)
        *backupPath = path;
    return true;
}

} // namespace

Database::Database(QObject *parent)
    : QObject(parent)
{
    m_dbPath = defaultDatabasePath();
    QDir().mkpath(QFileInfo(m_dbPath).absolutePath());

    QString error;
    if (openConnection(QLatin1String(kUiConnection), m_dbPath)) {
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(kUiConnection));
        if (!quickCheck(db, &error)) {
            m_startupError = QStringLiteral("%1: integrity check failed: %2")
                                 .arg(m_dbPath, error);
        } else if (!migrate(db, &error, &m_lastBackupPath)) {
            m_startupError = QStringLiteral("%1: migration failed: %2").arg(m_dbPath, error);
        } else {
            m_ready = true;
        }
    } else {
        const QSqlDatabase db = QSqlDatabase::database(QLatin1String(kUiConnection), false);
        m_startupError = QStringLiteral("%1: open failed: %2")
                             .arg(m_dbPath, db.isValid() ? db.lastError().text()
                                                       : QStringLiteral("QSQLITE unavailable"));
    }

    QSettings settings;
    m_libraryPath = settings.value(QStringLiteral("library/path")).toString();
}

Database::~Database()
{
    cancelScan();
}

QString Database::defaultDatabasePath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    // Derivado do nome da aplicação, e não escrito à mão: é assim que o arquivo acompanha o
    // projeto se ele for rebatizado de novo. O fallback cobre os testes, que sobem sem
    // QCoreApplication nomeada.
    const QString nome = QCoreApplication::applicationName().isEmpty()
                             ? QStringLiteral("melodarium")
                             : QCoreApplication::applicationName();
    return dir + QLatin1Char('/') + nome + QStringLiteral(".db");
}

bool Database::openConnection(const QString &connectionName, const QString &dbPath)
{
    QSqlDatabase db = QSqlDatabase::contains(connectionName)
                          ? QSqlDatabase::database(connectionName)
                          : QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
    db.setDatabaseName(dbPath);
    if (!db.open())
        return false;
    return applyPragmas(db);
}

bool Database::applyPragmas(QSqlDatabase &db, QString *error)
{
    QSqlQuery q(db);
    const QStringList pragmas = {
        QStringLiteral("PRAGMA foreign_keys = ON"),
        // WAL lets the scanner write while the UI reads. busy_timeout handles the one
        // remaining contention SQLite cannot remove: two writers arriving together.
        QStringLiteral("PRAGMA journal_mode = WAL"),
        QStringLiteral("PRAGMA synchronous = NORMAL"),
        QStringLiteral("PRAGMA busy_timeout = 5000"),
    };
    for (const QString &pragma : pragmas) {
        if (q.exec(pragma))
            continue;
        if (error)
            *error = q.lastError().text();
        return false;
    }
    return true;
}

bool Database::migrate(QSqlDatabase &db, QString *error, QString *backupPath)
{
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("PRAGMA user_version")) || !q.next()) {
        if (error)
            *error = q.lastError().text();
        return false;
    }
    int current = q.value(0).toInt();
    // VACUUM INTO needs an idle connection. Even a one-row PRAGMA cursor keeps a read
    // statement active until it is explicitly finished.
    q.finish();

    const QList<QString> &all = migrations();
    if (current < all.size() && !createMigrationBackup(db, current, backupPath, error))
        return false;
    for (int v = current; v < all.size(); ++v) {
        if (!db.transaction()) {
            if (error)
                *error = db.lastError().text();
            return false;
        }
        bool ok = true;
        // Each migration is a script: split on ";" and run statement by statement,
        // because QSqlQuery::exec runs exactly one statement per call.
        const QStringList statements = splitStatements(all.at(v));
        for (const QString &raw : statements) {
            const QString stmt = raw.trimmed();
            if (stmt.isEmpty())
                continue;
            QSqlQuery mq(db);
            if (!mq.exec(stmt)) {
                if (error)
                    *error = mq.lastError().text();
                ok = false;
                break;
            }
        }
        if (!ok) {
            db.rollback();
            return false;
        }
        QSqlQuery vq(db);
        if (!vq.exec(QStringLiteral("PRAGMA user_version = %1").arg(v + 1))) {
            if (error)
                *error = vq.lastError().text();
            db.rollback();
            return false;
        }
        if (!db.commit()) {
            if (error)
                *error = db.lastError().text();
            db.rollback();
            return false;
        }
    }
    return true;
}

int Database::schemaVersion() const
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kUiConnection));
    QSqlQuery q(db);
    if (q.exec(QStringLiteral("PRAGMA user_version")) && q.next())
        return q.value(0).toInt();
    return -1;
}

void Database::setLibraryPath(const QString &path)
{
    if (m_libraryPath == path)
        return;
    m_libraryPath = path;
    QSettings().setValue(QStringLiteral("library/path"), path);
    emit libraryPathChanged();
}

void Database::startScan()
{
    if (m_scanning || m_libraryPath.isEmpty())
        return;

    m_scanThread = new QThread(this);
    m_scanner = new LibraryScanner;
    m_scanner->moveToThread(m_scanThread);

    const QString root = m_libraryPath;
    const QString dbPath = m_dbPath;
    connect(m_scanThread, &QThread::started, m_scanner, [this, root, dbPath]() {
        m_scanner->run(root, dbPath);
    });
    connect(m_scanner, &LibraryScanner::progress, this, &Database::scanProgress);
    connect(m_scanner, &LibraryScanner::failed, this, &Database::scanFailed);
    connect(m_scanner, &LibraryScanner::finished, this,
            [this](int added, int updated, int removed) {
                m_scanning = false;
                emit scanningChanged();
                emit scanFinished(added, updated, removed);
            });
    connect(m_scanner, &LibraryScanner::finished, m_scanThread, &QThread::quit);
    connect(m_scanThread, &QThread::finished, m_scanner, &QObject::deleteLater);
    connect(m_scanThread, &QThread::finished, this, [this]() {
        m_scanner = nullptr;
        m_scanThread = nullptr;
    });

    m_scanning = true;
    emit scanningChanged();
    m_scanThread->start();
}

void Database::cancelScan()
{
    if (m_scanner)
        m_scanner->cancel();
    if (m_scanThread) {
        m_scanThread->quit();
        m_scanThread->wait(5000);
    }
}
