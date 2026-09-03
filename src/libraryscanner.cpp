#include "libraryscanner.h"

#include "audioformats.h"
#include "database.h"
#include "tagreader.h"

#include <QDateTime>
#include <QDirIterator>
#include <QFileInfo>
#include <QHash>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariant>

#include <string_view>

// The scanner's SQLite connection name is contractual: no other slice may reuse it.
// Pinned here so that renaming it in database.h fails the build instead of silently
// letting two components share a connection across threads.
static_assert(std::string_view(Database::kScannerConnection) == "melodarium-scanner",
              "the scanner connection name must stay \"melodarium-scanner\"");

namespace {

// Drops the scanner's SQLite connection on every exit path, cancellation included. Qt only
// accepts the removal once the last QSqlDatabase copy is gone, so this is declared before
// the scope that holds them and runs after it.
struct ConnectionGuard {
    QString name;
    ~ConnectionGuard() { QSqlDatabase::removeDatabase(name); }
};

struct KnownTrack {
    int id = 0;
    qint64 mtime = 0;
    qint64 size = 0;
    QString contentHash;
    bool titleMissing = false;
};

// Resolves a name to a row id in a lookup table, inserting it when new.
int idFor(QSqlDatabase &db, const QString &table, const QString &name)
{
    if (name.isEmpty())
        return 0;
    QSqlQuery sel(db);
    sel.prepare(QStringLiteral("SELECT id FROM %1 WHERE name = ?").arg(table));
    sel.addBindValue(name);
    if (sel.exec() && sel.next())
        return sel.value(0).toInt();

    QSqlQuery ins(db);
    ins.prepare(QStringLiteral("INSERT INTO %1 (name) VALUES (?)").arg(table));
    ins.addBindValue(name);
    return ins.exec() ? ins.lastInsertId().toInt() : 0;
}

int albumIdFor(QSqlDatabase &db, const QString &title, int albumArtistId, int year)
{
    if (title.isEmpty())
        return 0;
    QSqlQuery sel(db);
    sel.prepare(QStringLiteral(
        "SELECT id FROM albums WHERE title = ? AND IFNULL(album_artist_id,0) = ?"));
    sel.addBindValue(title);
    sel.addBindValue(albumArtistId);
    if (sel.exec() && sel.next())
        return sel.value(0).toInt();

    QSqlQuery ins(db);
    ins.prepare(QStringLiteral(
        "INSERT INTO albums (title, album_artist_id, year) VALUES (?, ?, ?)"));
    ins.addBindValue(title);
    ins.addBindValue(albumArtistId > 0 ? QVariant(albumArtistId) : QVariant());
    ins.addBindValue(year > 0 ? QVariant(year) : QVariant());
    return ins.exec() ? ins.lastInsertId().toInt() : 0;
}

void bindTrack(QSqlQuery &q, const TrackRecord &r, int artistId, int albumId, int genreId)
{
    q.addBindValue(r.mtime);
    q.addBindValue(r.size);
    q.addBindValue(r.contentHash);
    q.addBindValue(r.durationMs);
    q.addBindValue(r.sampleRate > 0 ? QVariant(r.sampleRate) : QVariant());
    q.addBindValue(r.bitsPerSample > 0 ? QVariant(r.bitsPerSample) : QVariant());
    q.addBindValue(r.channels > 0 ? QVariant(r.channels) : QVariant());
    q.addBindValue(r.bitrateKbps > 0 ? QVariant(r.bitrateKbps) : QVariant());
    q.addBindValue(r.codec);
    q.addBindValue(r.title);
    q.addBindValue(r.trackNo > 0 ? QVariant(r.trackNo) : QVariant());
    q.addBindValue(r.discNo > 0 ? QVariant(r.discNo) : QVariant());
    q.addBindValue(r.year > 0 ? QVariant(r.year) : QVariant());
    q.addBindValue(r.composer);
    q.addBindValue(artistId > 0 ? QVariant(artistId) : QVariant());
    q.addBindValue(albumId > 0 ? QVariant(albumId) : QVariant());
    q.addBindValue(genreId > 0 ? QVariant(genreId) : QVariant());
    q.addBindValue(r.hasReplayGain ? QVariant(r.replayGainTrackDb) : QVariant());
    q.addBindValue(r.hasReplayGain ? QVariant(r.replayGainAlbumDb) : QVariant());
    q.addBindValue(r.musicBrainzTrackId);
}

} // namespace

const QStringList &LibraryScanner::audioSuffixes()
{
    return AudioFormats::supportedSuffixes();
}

LibraryScanner::LibraryScanner(QObject *parent)
    : QObject(parent)
{
}

void LibraryScanner::cancel()
{
    m_cancelled.store(true);
}

void LibraryScanner::run(const QString &rootPath, const QString &dbPath)
{
    int added = 0, updated = 0, removed = 0;

    // Armed before the scope below so the connection is dropped after every QSqlDatabase
    // copy has died — otherwise Qt warns that it is "still in use".
    const ConnectionGuard guard{QString::fromLatin1(Database::kScannerConnection)};

    {
        if (!Database::openConnection(QLatin1String(Database::kScannerConnection), dbPath)) {
            emit failed(QStringLiteral("could not open the library database"));
            return;
        }
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kScannerConnection));
        Database::applyPragmas(db);

        // 1. Everything the scanner needs to compare, in one query — no file is read yet.
        QHash<QString, KnownTrack> known;
        {
            QSqlQuery q(db);
            q.exec(QStringLiteral(
                "SELECT id, path, mtime, size, content_hash, IFNULL(title, '') = '' "
                "FROM tracks WHERE removed_at IS NULL"));
            while (q.next()) {
                KnownTrack k;
                k.id = q.value(0).toInt();
                k.mtime = q.value(2).toLongLong();
                k.size = q.value(3).toLongLong();
                k.contentHash = q.value(4).toString();
                k.titleMissing = q.value(5).toBool();
                known.insert(q.value(1).toString(), k);
            }
        }

        // 2. Enumerate the files on disk.
        QStringList files;
        QDirIterator it(rootPath, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            if (LibraryScanner::audioSuffixes().contains(QFileInfo(path).suffix().toLower()))
                files.append(path);
        }

        const qint64 now = QDateTime::currentSecsSinceEpoch();
        QSet<QString> seen;
        // Row ids this scan re-pointed at a path that exists. Their OLD path is absent from
        // `seen`, so without this the soft-delete pass below would immediately bury the very
        // track it just recognised as moved.
        QSet<int> movedIds;
        db.transaction();

        for (int i = 0; i < files.size(); ++i) {
            if (m_cancelled.load()) {
                db.rollback();
                db.close();
                emit failed(QStringLiteral("scan cancelled"));
                return;
            }

            const QString path = files.at(i);
            seen.insert(path);
            const QFileInfo info(path);

            const auto knownIt = known.constFind(path);
            QString currentContentHash;
            if (knownIt != known.constEnd() && knownIt->mtime == info.lastModified().toSecsSinceEpoch()
                && knownIt->size == info.size()) {
                // A missing title can be stale even when coarse mtime and file size match.
                // Only these suspicious rows pay for the sampled hash comparison.
                if (knownIt->titleMissing)
                    currentContentHash = TagReader::computeContentHash(path);
                if (!knownIt->titleMissing || currentContentHash == knownIt->contentHash) {
                    if (i % 50 == 0)
                        emit progress(i, files.size());
                    continue; // unchanged: never opened with TagLib
                }
            }

            TrackRecord r = TagReader::read(path);
            if (!r.valid) {
                if (i % 50 == 0)
                    emit progress(i, files.size());
                continue; // corrupt or unsupported: skip this one, never abort the batch
            }
            r.contentHash = currentContentHash.isEmpty()
                                ? TagReader::computeContentHash(path)
                                : currentContentHash;

            const int artistId = idFor(db, QStringLiteral("artists"), r.artist);
            const int albumArtistId = idFor(db, QStringLiteral("artists"), r.albumArtist);
            const int genreId = idFor(db, QStringLiteral("genres"), r.genre);
            const int albumId = albumIdFor(db, r.album, albumArtistId, r.year);

            if (knownIt != known.constEnd()) {
                QSqlQuery q(db);
                q.prepare(QStringLiteral(
                    "UPDATE tracks SET mtime=?, size=?, content_hash=?, duration_ms=?, "
                    "sample_rate=?, bits_per_sample=?, channels=?, bitrate_kbps=?, codec=?, "
                    "title=?, track_no=?, disc_no=?, year=?, composer=?, artist_id=?, "
                    "album_id=?, genre_id=?, replaygain_track_gain=?, replaygain_album_gain=?, "
                    "musicbrainz_track_id=? WHERE id=?"));
                bindTrack(q, r, artistId, albumId, genreId);
                q.addBindValue(knownIt->id);
                if (q.exec())
                    ++updated;
            } else {
                // A new path whose content hash matches a row missing from this scan is a
                // move, not a new file: reuse the id so play counts and collections survive.
                int movedId = 0;
                if (!r.contentHash.isEmpty()) {
                    QSqlQuery mq(db);
                    mq.prepare(QStringLiteral(
                        "SELECT id, path FROM tracks WHERE content_hash = ? AND size = ?"));
                    mq.addBindValue(r.contentHash);
                    mq.addBindValue(r.size);
                    while (mq.exec() && mq.next()) {
                        const QString oldPath = mq.value(1).toString();
                        if (!seen.contains(oldPath) && !QFileInfo::exists(oldPath)) {
                            movedId = mq.value(0).toInt();
                            break;
                        }
                        break;
                    }
                }

                if (movedId > 0) {
                    QSqlQuery q(db);
                    q.prepare(QStringLiteral(
                        "UPDATE tracks SET path=?, mtime=?, size=?, removed_at=NULL WHERE id=?"));
                    q.addBindValue(path);
                    q.addBindValue(r.mtime);
                    q.addBindValue(r.size);
                    q.addBindValue(movedId);
                    if (q.exec()) {
                        ++updated;
                        movedIds.insert(movedId);
                    }
                } else {
                    QSqlQuery q(db);
                    q.prepare(QStringLiteral(
                        "INSERT INTO tracks (path, mtime, size, content_hash, duration_ms, "
                        "sample_rate, bits_per_sample, channels, bitrate_kbps, codec, title, "
                        "track_no, disc_no, year, composer, artist_id, album_id, genre_id, "
                        "replaygain_track_gain, replaygain_album_gain, musicbrainz_track_id, "
                        "added_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, "
                        "?, ?, ?, ?, ?)"));
                    q.addBindValue(path);
                    bindTrack(q, r, artistId, albumId, genreId);
                    q.addBindValue(now);
                    if (q.exec()) {
                        ++added;
                        QSqlQuery sq(db);
                        sq.prepare(QStringLiteral(
                            "INSERT INTO track_stats (track_id, first_seen_at) VALUES (?, ?)"));
                        sq.addBindValue(q.lastInsertId().toInt());
                        sq.addBindValue(now);
                        sq.exec();
                    }
                }
            }

            if (i % 50 == 0)
                emit progress(i, files.size());
        }

        // 3. Soft-delete what vanished: an unmounted external drive must not wipe the library.
        for (auto it2 = known.constBegin(); it2 != known.constEnd(); ++it2) {
            if (seen.contains(it2.key()) || movedIds.contains(it2->id))
                continue;
            QSqlQuery q(db);
            q.prepare(QStringLiteral("UPDATE tracks SET removed_at = ? WHERE id = ? AND removed_at IS NULL"));
            q.addBindValue(now);
            q.addBindValue(it2->id);
            if (q.exec() && q.numRowsAffected() > 0)
                ++removed;
        }

        // 4. Drop the lookup rows nothing points at any more. Re-reading tags renames
        //    artists and genres, and the old glued name ("Daft Punk Julian Casablancas")
        //    would otherwise sit in the table forever. A soft-deleted track still counts as
        //    a reference: an unmounted drive must not erase the artist of a track that is
        //    going to come back.
        {
            QSqlQuery q(db);
            q.exec(QStringLiteral(
                "DELETE FROM artists WHERE id NOT IN "
                "(SELECT artist_id FROM tracks WHERE artist_id IS NOT NULL) AND id NOT IN "
                "(SELECT album_artist_id FROM albums WHERE album_artist_id IS NOT NULL)"));
            QSqlQuery g(db);
            g.exec(QStringLiteral(
                "DELETE FROM genres WHERE id NOT IN "
                "(SELECT genre_id FROM tracks WHERE genre_id IS NOT NULL)"));
        }

        db.commit();
        emit progress(files.size(), files.size());
        db.close();
    }

    emit finished(added, updated, removed);
}
