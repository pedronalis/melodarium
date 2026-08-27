#include "collectionmanager.h"

#include "database.h"
#include "tagreader.h"

#include <QDateTime>
#include <QFileInfo>
#include <QList>
#include <QPair>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariantMap>

namespace {

QSqlDatabase uiDb()
{
    return QSqlDatabase::database(QLatin1String(Database::kUiConnection));
}

} // namespace

CollectionManager::CollectionManager(QObject *parent)
    : QObject(parent)
{
}

QString CollectionManager::normalise(const QString &raw)
{
    // Collapse inner whitespace and trim. Without this, "pra codar" and "pra  codar" become
    // two different names and the UNIQUE constraint never fires.
    return raw.simplified();
}

QVariantList CollectionManager::collections()
{
    QSqlQuery q(uiDb());
    QVariantList out;
    if (!q.exec(QStringLiteral(
            "SELECT c.id, c.name, COUNT(ct.track_id) "
            "FROM collections c "
            "LEFT JOIN collection_tracks ct ON ct.collection_id = c.id "
            "GROUP BY c.id ORDER BY c.name COLLATE NOCASE")))
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("name"), q.value(1).toString()},
                               {QStringLiteral("count"), q.value(2).toInt()}});
    }
    return out;
}

int CollectionManager::createCollection(const QString &name)
{
    const QString clean = normalise(name);
    if (clean.isEmpty())
        return 0;

    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral("INSERT INTO collections (name, created_at) VALUES (?, ?)"));
    q.addBindValue(clean);
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    if (!q.exec())
        return 0; // UNIQUE COLLATE NOCASE already rejected a duplicate name
    emit collectionsChanged();
    return q.lastInsertId().toInt();
}

bool CollectionManager::renameCollection(int collectionId, const QString &newName)
{
    const QString clean = normalise(newName);
    if (clean.isEmpty() || collectionId <= 0)
        return false;
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral("UPDATE collections SET name = ? WHERE id = ?"));
    q.addBindValue(clean);
    q.addBindValue(collectionId);
    const bool ok = q.exec() && q.numRowsAffected() > 0;
    if (ok)
        emit collectionsChanged();
    return ok;
}

bool CollectionManager::deleteCollection(int collectionId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral("DELETE FROM collections WHERE id = ?"));
    q.addBindValue(collectionId);
    const bool ok = q.exec() && q.numRowsAffected() > 0;
    if (ok)
        emit collectionsChanged(); // collection_tracks rows go with it via ON DELETE CASCADE
    return ok;
}

bool CollectionManager::addTrackToCollection(int collectionId, int trackId)
{
    if (collectionId <= 0 || trackId <= 0)
        return false;

    QSqlQuery pos(uiDb());
    pos.prepare(QStringLiteral(
        "SELECT IFNULL(MAX(position), 0) FROM collection_tracks WHERE collection_id = ?"));
    pos.addBindValue(collectionId);
    int next = kPositionStep;
    if (pos.exec() && pos.next())
        next = pos.value(0).toInt() + kPositionStep;

    QSqlQuery q(uiDb());
    // The one manual gesture in the whole product: adding the same track twice is a no-op,
    // never an error the user has to think about.
    q.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO collection_tracks (collection_id, track_id, position, added_at) "
        "VALUES (?, ?, ?, ?)"));
    q.addBindValue(collectionId);
    q.addBindValue(trackId);
    q.addBindValue(next);
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    if (!q.exec())
        return false;
    emit collectionsChanged();
    return true;
}

bool CollectionManager::removeTrackFromCollection(int collectionId, int trackId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "DELETE FROM collection_tracks WHERE collection_id = ? AND track_id = ?"));
    q.addBindValue(collectionId);
    q.addBindValue(trackId);
    const bool ok = q.exec() && q.numRowsAffected() > 0;
    if (ok)
        emit collectionsChanged();
    return ok;
}

QVariantList CollectionManager::collectionsForTrack(int trackId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT c.id, c.name FROM collections c "
        "JOIN collection_tracks ct ON ct.collection_id = c.id "
        "WHERE ct.track_id = ? ORDER BY c.name COLLATE NOCASE"));
    q.addBindValue(trackId);
    QVariantList out;
    if (!q.exec())
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("name"), q.value(1).toString()}});
    }
    return out;
}

QString CollectionManager::clauseForCollection(int)
{
    // Ordered by the collection's own manual position, not by album/track number.
    return QStringLiteral(
        "t.removed_at IS NULL AND t.id IN (SELECT track_id FROM collection_tracks WHERE collection_id = ?) "
        "ORDER BY (SELECT position FROM collection_tracks ct WHERE ct.track_id = t.id "
        "AND ct.collection_id = ?)");
}

QVariantList CollectionManager::bindingsForCollection(int collectionId)
{
    return QVariantList{collectionId, collectionId}; // the clause binds the id twice
}

bool CollectionManager::moveTrackInCollection(int collectionId, int trackId, int newIndex)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT track_id, position FROM collection_tracks WHERE collection_id = ? ORDER BY position"));
    q.addBindValue(collectionId);
    if (!q.exec())
        return false;

    QList<QPair<int, int>> items;
    while (q.next())
        items.append({q.value(0).toInt(), q.value(1).toInt()});
    if (newIndex < 0 || newIndex >= items.size())
        return false;

    int before = 0;
    int after = 0;
    for (int i = 0; i < items.size(); ++i) {
        if (items.at(i).first == trackId)
            continue;
        if (i < newIndex)
            before = items.at(i).second;
        else if (after == 0)
            after = items.at(i).second;
    }
    // Land halfway between the neighbours; when the gap is exhausted, renumber the whole
    // collection with fresh steps.
    int target = (after > 0) ? (before + after) / 2 : before + kPositionStep;
    if (after > 0 && target <= before) {
        int p = kPositionStep;
        for (const auto &item : items) {
            QSqlQuery r(uiDb());
            r.prepare(QStringLiteral(
                "UPDATE collection_tracks SET position = ? WHERE collection_id = ? AND track_id = ?"));
            r.addBindValue(p);
            r.addBindValue(collectionId);
            r.addBindValue(item.first);
            r.exec();
            p += kPositionStep;
        }
        target = (newIndex + 1) * kPositionStep - kPositionStep / 2;
    }

    QSqlQuery up(uiDb());
    up.prepare(QStringLiteral(
        "UPDATE collection_tracks SET position = ? WHERE collection_id = ? AND track_id = ?"));
    up.addBindValue(target);
    up.addBindValue(collectionId);
    up.addBindValue(trackId);
    const bool ok = up.exec() && up.numRowsAffected() > 0;
    if (ok)
        emit collectionsChanged();
    return ok;
}

QVariantList CollectionManager::allTags()
{
    QSqlQuery q(uiDb());
    QVariantList out;
    if (!q.exec(QStringLiteral(
            "SELECT tg.id, tg.name, COUNT(tt.track_id) "
            "FROM tags tg LEFT JOIN track_tags tt ON tt.tag_id = tg.id "
            "GROUP BY tg.id ORDER BY tg.name COLLATE NOCASE")))
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("name"), q.value(1).toString()},
                               {QStringLiteral("count"), q.value(2).toInt()}});
    }
    return out;
}

QVariantList CollectionManager::tagsForTrack(int trackId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT tg.id, tg.name FROM tags tg JOIN track_tags tt ON tt.tag_id = tg.id "
        "WHERE tt.track_id = ? ORDER BY tg.name COLLATE NOCASE"));
    q.addBindValue(trackId);
    QVariantList out;
    if (!q.exec())
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("name"), q.value(1).toString()}});
    }
    return out;
}

QStringList CollectionManager::completeTag(const QString &prefix, int limit)
{
    const QString clean = normalise(prefix);
    if (clean.isEmpty())
        return {};
    QSqlQuery q(uiDb());
    // Prefix match only: this is the brake that stops "codar"/"programar"/"foco" from
    // becoming three near-identical tags.
    q.prepare(QStringLiteral(
        "SELECT name FROM tags WHERE name LIKE ? ORDER BY name COLLATE NOCASE LIMIT ?"));
    q.addBindValue(clean + QLatin1Char('%'));
    q.addBindValue(limit);
    QStringList out;
    if (!q.exec())
        return out;
    while (q.next())
        out.append(q.value(0).toString());
    return out;
}

bool CollectionManager::addTagToTrack(int trackId, const QString &tagName)
{
    const QString clean = normalise(tagName);
    if (trackId <= 0 || clean.isEmpty())
        return false;

    QSqlQuery ins(uiDb());
    ins.prepare(QStringLiteral("INSERT OR IGNORE INTO tags (name) VALUES (?)"));
    ins.addBindValue(clean);
    ins.exec();

    QSqlQuery sel(uiDb());
    sel.prepare(QStringLiteral("SELECT id FROM tags WHERE name = ?"));
    sel.addBindValue(clean);
    if (!sel.exec() || !sel.next())
        return false;

    QSqlQuery link(uiDb());
    link.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO track_tags (track_id, tag_id) VALUES (?, ?)"));
    link.addBindValue(trackId);
    link.addBindValue(sel.value(0).toInt());
    if (!link.exec())
        return false;
    emit tagsChanged(trackId);
    return true;
}

bool CollectionManager::removeTagFromTrack(int trackId, const QString &tagName)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "DELETE FROM track_tags WHERE track_id = ? "
        "AND tag_id = (SELECT id FROM tags WHERE name = ?)"));
    q.addBindValue(trackId);
    q.addBindValue(normalise(tagName));
    const bool ok = q.exec() && q.numRowsAffected() > 0;
    if (ok) {
        // A tag nobody uses any more is noise in the autocomplete: drop it.
        QSqlQuery gc(uiDb());
        gc.exec(QStringLiteral(
            "DELETE FROM tags WHERE id NOT IN (SELECT tag_id FROM track_tags)"));
        emit tagsChanged(trackId);
    }
    return ok;
}

QString CollectionManager::clauseForTag(const QString &)
{
    return QStringLiteral(
        "t.removed_at IS NULL AND t.id IN (SELECT tt.track_id FROM track_tags tt "
        "JOIN tags tg ON tg.id = tt.tag_id WHERE tg.name = ?)");
}

QVariantList CollectionManager::bindingsForTag(const QString &tagName)
{
    return QVariantList{normalise(tagName)};
}

int CollectionManager::ingestDownloadedFile(const QString &path, int collectionId,
                                            const QString &sourceUrl, const QString &formatNote)
{
    const QFileInfo info(path);
    if (!info.exists())
        return 0;

    const TrackRecord rec = TagReader::read(path);
    if (!rec.valid)
        return 0;

    QSqlQuery existing(uiDb());
    existing.prepare(QStringLiteral("SELECT id FROM tracks WHERE path = ?"));
    existing.addBindValue(path);
    int trackId = 0;
    if (existing.exec() && existing.next())
        trackId = existing.value(0).toInt();

    if (trackId == 0) {
        QSqlQuery artist(uiDb());
        artist.prepare(QStringLiteral("INSERT OR IGNORE INTO artists (name) VALUES (?)"));
        artist.addBindValue(rec.artist);
        artist.exec();

        QSqlQuery artistId(uiDb());
        artistId.prepare(QStringLiteral("SELECT id FROM artists WHERE name = ?"));
        artistId.addBindValue(rec.artist);
        const int aid = (artistId.exec() && artistId.next()) ? artistId.value(0).toInt() : 0;

        const qint64 now = QDateTime::currentSecsSinceEpoch();
        QSqlQuery ins(uiDb());
        ins.prepare(QStringLiteral(
            "INSERT INTO tracks (path, mtime, size, content_hash, duration_ms, sample_rate, "
            "channels, bitrate_kbps, codec, title, artist_id, added_at, source_kind, "
            "source_url, source_format_note, downloaded_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'youtube', ?, ?, ?)"));
        ins.addBindValue(path);
        ins.addBindValue(rec.mtime);
        ins.addBindValue(rec.size);
        ins.addBindValue(TagReader::computeContentHash(path));
        ins.addBindValue(rec.durationMs);
        ins.addBindValue(rec.sampleRate > 0 ? QVariant(rec.sampleRate) : QVariant());
        ins.addBindValue(rec.channels > 0 ? QVariant(rec.channels) : QVariant());
        ins.addBindValue(rec.bitrateKbps > 0 ? QVariant(rec.bitrateKbps) : QVariant());
        ins.addBindValue(rec.codec);
        ins.addBindValue(rec.title.isEmpty() ? info.completeBaseName() : rec.title);
        ins.addBindValue(aid > 0 ? QVariant(aid) : QVariant());
        ins.addBindValue(now);
        ins.addBindValue(sourceUrl);
        ins.addBindValue(formatNote);
        ins.addBindValue(now);
        if (!ins.exec())
            return 0;
        trackId = ins.lastInsertId().toInt();

        QSqlQuery stats(uiDb());
        stats.prepare(QStringLiteral(
            "INSERT OR IGNORE INTO track_stats (track_id, first_seen_at) VALUES (?, ?)"));
        stats.addBindValue(trackId);
        stats.addBindValue(now);
        stats.exec();
    }

    if (collectionId > 0)
        addTrackToCollection(collectionId, trackId);
    return trackId;
}
