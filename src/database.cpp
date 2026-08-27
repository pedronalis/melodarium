#include "database.h"
#include "libraryscanner.h"

#include <QDir>
#include <QSettings>
#include <QSqlError>
#include <QSqlQuery>
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
    };
    return list;
}

} // namespace

Database::Database(QObject *parent)
    : QObject(parent)
{
    m_dbPath = defaultDatabasePath();
    QDir().mkpath(QFileInfo(m_dbPath).absolutePath());

    if (openConnection(QLatin1String(kUiConnection), m_dbPath)) {
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(kUiConnection));
        applyPragmas(db);
        migrate(db);
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
    return dir + QStringLiteral("/melodia.db");
}

bool Database::openConnection(const QString &connectionName, const QString &dbPath)
{
    QSqlDatabase db = QSqlDatabase::contains(connectionName)
                          ? QSqlDatabase::database(connectionName)
                          : QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
    db.setDatabaseName(dbPath);
    return db.open();
}

void Database::applyPragmas(QSqlDatabase &db)
{
    QSqlQuery q(db);
    q.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
    // WAL lets the scanner write while the UI reads, with no blocking.
    q.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
    q.exec(QStringLiteral("PRAGMA synchronous = NORMAL"));
}

bool Database::migrate(QSqlDatabase &db)
{
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("PRAGMA user_version")) || !q.next())
        return false;
    int current = q.value(0).toInt();

    const QList<QString> &all = migrations();
    for (int v = current; v < all.size(); ++v) {
        db.transaction();
        bool ok = true;
        // Each migration is a script: split on ";" and run statement by statement,
        // because QSqlQuery::exec runs exactly one statement per call.
        const QStringList statements = all.at(v).split(QLatin1Char(';'), Qt::SkipEmptyParts);
        for (const QString &raw : statements) {
            const QString stmt = raw.trimmed();
            if (stmt.isEmpty())
                continue;
            QSqlQuery mq(db);
            if (!mq.exec(stmt)) {
                ok = false;
                break;
            }
        }
        if (!ok) {
            db.rollback();
            return false;
        }
        QSqlQuery vq(db);
        vq.exec(QStringLiteral("PRAGMA user_version = %1").arg(v + 1));
        db.commit();
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
