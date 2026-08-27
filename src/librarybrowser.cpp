#include "librarybrowser.h"

#include "database.h"

#include <QRegularExpression>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariantMap>

namespace {

QVariantList runLookup(const QString &sql)
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    QVariantList out;
    if (!q.exec(sql))
        return out;
    while (q.next()) {
        QVariantMap row;
        row.insert(QStringLiteral("id"), q.value(0).toInt());
        row.insert(QStringLiteral("name"), q.value(1).toString());
        row.insert(QStringLiteral("count"), q.value(2).toInt());
        row.insert(QStringLiteral("subtitle"), q.value(3).toString());
        out.append(row);
    }
    return out;
}

} // namespace

LibraryBrowser::LibraryBrowser(QObject *parent)
    : QObject(parent)
{
}

QVariantList LibraryBrowser::artists()
{
    return runLookup(QStringLiteral(
        "SELECT ar.id, ar.name, COUNT(t.id), '' "
        "FROM artists ar JOIN tracks t ON t.artist_id = ar.id AND t.removed_at IS NULL "
        "GROUP BY ar.id ORDER BY ar.name COLLATE NOCASE"));
}

QVariantList LibraryBrowser::albums(int artistId)
{
    const QString filter = artistId > 0
                               ? QStringLiteral("AND al.album_artist_id = %1").arg(artistId)
                               : QString();
    return runLookup(QStringLiteral(
                         "SELECT al.id, al.title, COUNT(t.id), IFNULL(ar.name,'') "
                         "FROM albums al "
                         "JOIN tracks t ON t.album_id = al.id AND t.removed_at IS NULL "
                         "LEFT JOIN artists ar ON ar.id = al.album_artist_id "
                         "WHERE 1=1 %1 "
                         "GROUP BY al.id ORDER BY al.title COLLATE NOCASE")
                         .arg(filter));
}

QVariantList LibraryBrowser::genres()
{
    return runLookup(QStringLiteral(
        "SELECT g.id, g.name, COUNT(t.id), '' "
        "FROM genres g JOIN tracks t ON t.genre_id = g.id AND t.removed_at IS NULL "
        "GROUP BY g.id ORDER BY g.name COLLATE NOCASE"));
}

QString LibraryBrowser::clauseForArtist(int)
{
    return QStringLiteral("t.removed_at IS NULL AND t.artist_id = ?");
}

QString LibraryBrowser::clauseForAlbum(int)
{
    return QStringLiteral("t.removed_at IS NULL AND t.album_id = ?");
}

QString LibraryBrowser::clauseForGenre(int)
{
    return QStringLiteral("t.removed_at IS NULL AND t.genre_id = ?");
}

QString LibraryBrowser::clauseForAll()
{
    return QStringLiteral("t.removed_at IS NULL");
}

QString LibraryBrowser::clauseForSearch(const QString &text)
{
    if (text.trimmed().isEmpty())
        return clauseForAll();
    return QStringLiteral(
        "t.removed_at IS NULL AND t.id IN (SELECT rowid FROM tracks_fts WHERE tracks_fts MATCH ?)");
}

QVariantList LibraryBrowser::bindingsFor(int id)
{
    return id > 0 ? QVariantList{id} : QVariantList{};
}

QVariantList LibraryBrowser::bindingsForSearch(const QString &text)
{
    if (text.trimmed().isEmpty())
        return {};
    return QVariantList{toFtsPrefixQuery(text)};
}

QString LibraryBrowser::toFtsPrefixQuery(const QString &text)
{
    // FTS5 treats quotes, '-', '*', ':' and friends as syntax. Strip everything that is not
    // a letter or a digit, then turn each remaining word into a prefix term.
    static const QRegularExpression nonWord(QStringLiteral("[^\\w]+"),
                                            QRegularExpression::UseUnicodePropertiesOption);
    const QStringList words = text.trimmed().split(nonWord, Qt::SkipEmptyParts);
    QStringList terms;
    terms.reserve(words.size());
    for (const QString &w : words)
        terms.append(w + QLatin1Char('*'));
    return terms.join(QLatin1Char(' '));
}

QString LibraryBrowser::clauseRecent()
{
    // Carries its own ORDER BY; TrackListModel::loadFromQuery detects that and does not
    // append its default ordering. No trailing "--" comment: it would swallow whatever the
    // query builder appends on the same line.
    return QStringLiteral("t.removed_at IS NULL ORDER BY t.added_at DESC LIMIT %1")
        .arg(kAutoListLimit);
}

QString LibraryBrowser::clauseMostPlayed()
{
    return QStringLiteral(
               "t.removed_at IS NULL AND t.id IN ("
               "SELECT track_id FROM track_stats WHERE play_count > 0 "
               "ORDER BY play_count DESC LIMIT %1)")
        .arg(kAutoListLimit);
}

QString LibraryBrowser::clauseForgotten()
{
    return QStringLiteral(
               "t.removed_at IS NULL AND t.id IN ("
               "SELECT track_id FROM track_stats "
               "WHERE play_count >= %1 AND last_played_at IS NOT NULL "
               "AND last_played_at < strftime('%s','now') - %2*86400 "
               "ORDER BY play_count DESC, last_played_at ASC LIMIT %3)")
        .arg(kForgottenMinPlays)
        .arg(kForgottenDays)
        .arg(kAutoListLimit);
}

QString LibraryBrowser::clauseNeverPlayed()
{
    return QStringLiteral(
               "t.removed_at IS NULL AND t.id IN ("
               "SELECT track_id FROM track_stats WHERE play_count = 0 LIMIT %1)")
        .arg(kAutoListLimit);
}

bool LibraryBrowser::toggleLike(int trackId)
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    // A single UPDATE decides and applies: read-then-write would leave a window for two quick
    // clicks to store the same state.
    q.prepare(QStringLiteral(
        "UPDATE tracks SET liked_at = CASE WHEN liked_at IS NULL "
        "THEN CAST(strftime('%s','now') AS INTEGER) ELSE NULL END WHERE id = ?"));
    q.addBindValue(trackId);
    if (!q.exec() || q.numRowsAffected() <= 0)
        return false;

    const bool nowLiked = isLiked(trackId);
    emit likedChanged(trackId, nowLiked);
    return nowLiked;
}

bool LibraryBrowser::isLiked(int trackId)
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT liked_at IS NOT NULL FROM tracks WHERE id = ?"));
    q.addBindValue(trackId);
    if (!q.exec() || !q.next())
        return false;
    return q.value(0).toBool();
}

QString LibraryBrowser::clauseForLiked()
{
    return QStringLiteral("t.removed_at IS NULL AND t.liked_at IS NOT NULL "
                          "ORDER BY t.liked_at DESC");
}

int LibraryBrowser::likedCount()
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("SELECT COUNT(*) FROM tracks "
                               "WHERE removed_at IS NULL AND liked_at IS NOT NULL"))
        || !q.next())
        return 0;
    return q.value(0).toInt();
}

QVariantMap LibraryBrowser::trackForPath(const QString &path)
{
    QVariantMap out;
    if (path.isEmpty())
        return out;

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "SELECT t.id, IFNULL(t.title,''), IFNULL(ar.name,''), IFNULL(al.title,''), "
        "IFNULL(t.album_id,0), IFNULL(t.year,0), IFNULL(t.codec,''), "
        "IFNULL(t.sample_rate,0), IFNULL(t.bits_per_sample,0), t.liked_at IS NOT NULL "
        "FROM tracks t "
        "LEFT JOIN artists ar ON ar.id = t.artist_id "
        "LEFT JOIN albums al ON al.id = t.album_id "
        "WHERE t.path = ?"));
    q.addBindValue(path);
    if (!q.exec() || !q.next())
        return out;

    out.insert(QStringLiteral("id"), q.value(0).toInt());
    out.insert(QStringLiteral("title"), q.value(1).toString());
    out.insert(QStringLiteral("artist"), q.value(2).toString());
    out.insert(QStringLiteral("album"), q.value(3).toString());
    out.insert(QStringLiteral("albumId"), q.value(4).toInt());
    out.insert(QStringLiteral("year"), q.value(5).toInt());
    out.insert(QStringLiteral("codec"), q.value(6).toString());
    out.insert(QStringLiteral("sampleRate"), q.value(7).toInt());
    out.insert(QStringLiteral("bitsPerSample"), q.value(8).toInt());
    out.insert(QStringLiteral("liked"), q.value(9).toBool());
    return out;
}
