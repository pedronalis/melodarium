#include "librarybrowser.h"

#include "database.h"
#include "podcastscope.h"

#include <QDateTime>
#include <QFileInfo>
#include <QLocale>
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

QVariantList LibraryBrowser::bindingsFor(int id)
{
    return id > 0 ? QVariantList{id} : QVariantList{};
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

QString LibraryBrowser::clauseRecentlyPlayed()
{
    return QStringLiteral(
               "t.removed_at IS NULL AND t.id IN ("
               "SELECT track_id FROM track_stats WHERE last_played_at IS NOT NULL) "
               "ORDER BY (SELECT last_played_at FROM track_stats WHERE track_id = t.id) DESC, "
               "t.id ASC LIMIT %1")
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
        "IFNULL(t.sample_rate,0), IFNULL(t.bits_per_sample,0), t.liked_at IS NOT NULL, "
        "IFNULL(t.duration_ms,0) "
        "FROM tracks t "
        "LEFT JOIN artists ar ON ar.id = t.artist_id "
        "LEFT JOIN albums al ON al.id = t.album_id "
        "WHERE t.path = ?"));
    q.addBindValue(path);
    if (!q.exec() || !q.next())
        return out;

    out.insert(QStringLiteral("path"), path);
    out.insert(QStringLiteral("id"), q.value(0).toInt());
    const QString title = q.value(1).toString();
    out.insert(QStringLiteral("title"),
               title.isEmpty() ? QFileInfo(path).completeBaseName() : title);
    out.insert(QStringLiteral("artist"), q.value(2).toString());
    out.insert(QStringLiteral("album"), q.value(3).toString());
    out.insert(QStringLiteral("albumId"), q.value(4).toInt());
    out.insert(QStringLiteral("year"), q.value(5).toInt());
    out.insert(QStringLiteral("codec"), q.value(6).toString());
    out.insert(QStringLiteral("sampleRate"), q.value(7).toInt());
    out.insert(QStringLiteral("bitsPerSample"), q.value(8).toInt());
    out.insert(QStringLiteral("liked"), q.value(9).toBool());
    // The next-up card names the track and says how long it is; without this the card would
    // have to ask the engine, which only knows the duration of the file it has open.
    out.insert(QStringLiteral("durationMs"), q.value(10).toLongLong());
    return out;
}

namespace {

QString formatClock(int ms)
{
    if (ms <= 0)
        return QString();
    const int total = ms / 1000;
    return QStringLiteral("%1:%2")
        .arg(total / 60)
        .arg(total % 60, 2, 10, QLatin1Char('0'));
}

// Um episódio é longo: "41 min" diz mais do que "41:07", e é o que o desenho mostra.
QString formatMinutes(int ms)
{
    if (ms <= 0)
        return QString();
    const int minutes = ms / 60000;
    if (minutes < 60)
        return QStringLiteral("%1 min").arg(minutes);
    return QStringLiteral("%1 h %2").arg(minutes / 60).arg(minutes % 60, 2, 10, QLatin1Char('0'));
}

QString formatShortDate(qint64 secs)
{
    if (secs <= 0)
        return QString();
    return QLocale().toString(QDateTime::fromSecsSinceEpoch(secs).date(),
                              QStringLiteral("dd MMM"));
}

// "1 álbuns" salta aos olhos numa lista curta: a busca conta em português.
QString plural(int n, const QString &singular, const QString &plural)
{
    return QStringLiteral("%1 %2").arg(n).arg(n == 1 ? singular : plural);
}

QString joinParts(const QStringList &parts)
{
    QStringList kept;
    for (const QString &p : parts) {
        if (!p.isEmpty())
            kept.append(p);
    }
    return kept.join(QStringLiteral(" · "));
}

} // namespace

QVariantList LibraryBrowser::searchGrouped(const QString &text, int limitPerKind)
{
    QVariantList out;
    const QString trimmed = text.trimmed();
    if (trimmed.isEmpty())
        return out;

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    const QString like = QStringLiteral("%") + trimmed + QStringLiteral("%");

    auto append = [&out](const QString &kind, int id, const QString &title,
                         const QString &subtitle, const QString &path,
                         const QString &coverTrackPath = QString(), int albumId = 0,
                         const QString &coverPath = QString()) {
        QVariantMap row;
        row.insert(QStringLiteral("kind"), kind);
        row.insert(QStringLiteral("id"), id);
        row.insert(QStringLiteral("title"), title);
        row.insert(QStringLiteral("subtitle"), subtitle);
        row.insert(QStringLiteral("path"), path);
        row.insert(QStringLiteral("coverTrackPath"), coverTrackPath);
        row.insert(QStringLiteral("albumId"), albumId);
        row.insert(QStringLiteral("coverPath"), coverPath);
        out.append(row);
    };

    // Faixas — pelo FTS5 que a fatia de navegação já montou.
    QSqlQuery tq(db);
    tq.prepare(QStringLiteral(
        "SELECT t.id, IFNULL(t.title,''), IFNULL(ar.name,''), IFNULL(al.title,''), t.path, "
        "IFNULL(t.duration_ms,0), IFNULL(t.album_id,0) "
        "FROM tracks t "
        "LEFT JOIN artists ar ON ar.id = t.artist_id "
        "LEFT JOIN albums al ON al.id = t.album_id "
        "WHERE t.removed_at IS NULL AND t.id IN "
        "(SELECT rowid FROM tracks_fts WHERE tracks_fts MATCH ?) LIMIT ?"));
    tq.addBindValue(toFtsPrefixQuery(trimmed));
    tq.addBindValue(limitPerKind);
    if (tq.exec()) {
        while (tq.next()) {
            append(QStringLiteral("track"), tq.value(0).toInt(), tq.value(1).toString(),
                   joinParts({tq.value(2).toString(), tq.value(3).toString(),
                              formatClock(tq.value(5).toInt())}),
                   tq.value(4).toString(), tq.value(4).toString(), tq.value(6).toInt());
        }
    }

    QSqlQuery alq(db);
    alq.prepare(QStringLiteral(
        "SELECT al.id, al.title, IFNULL(ar.name,''), COUNT(t.id), IFNULL(al.year,0), "
        "MIN(t.path) "
        "FROM albums al "
        "LEFT JOIN artists ar ON ar.id = al.album_artist_id "
        "JOIN tracks t ON t.album_id = al.id AND t.removed_at IS NULL "
        "WHERE al.title LIKE ? GROUP BY al.id ORDER BY al.title COLLATE NOCASE LIMIT ?"));
    alq.addBindValue(like);
    alq.addBindValue(limitPerKind);
    if (alq.exec()) {
        while (alq.next()) {
            const int year = alq.value(4).toInt();
            append(QStringLiteral("album"), alq.value(0).toInt(), alq.value(1).toString(),
                   joinParts({alq.value(2).toString(),
                              year > 0 ? QString::number(year) : QString(),
                              plural(alq.value(3).toInt(), QStringLiteral("faixa"),
                                     QStringLiteral("faixas"))}),
                   QString(), alq.value(5).toString(), alq.value(0).toInt());
        }
    }

    QSqlQuery arq(db);
    arq.prepare(QStringLiteral(
        "SELECT ar.id, ar.name, COUNT(t.id), COUNT(DISTINCT t.album_id) "
        "FROM artists ar JOIN tracks t ON t.artist_id = ar.id AND t.removed_at IS NULL "
        "WHERE ar.name LIKE ? GROUP BY ar.id ORDER BY ar.name COLLATE NOCASE LIMIT ?"));
    arq.addBindValue(like);
    arq.addBindValue(limitPerKind);
    if (arq.exec()) {
        while (arq.next()) {
            const int albums = arq.value(3).toInt();
            append(QStringLiteral("artist"), arq.value(0).toInt(), arq.value(1).toString(),
                   joinParts({plural(arq.value(2).toInt(), QStringLiteral("faixa"),
                                     QStringLiteral("faixas")),
                              albums > 0 ? plural(albums, QStringLiteral("álbum"),
                                                  QStringLiteral("álbuns"))
                                         : QString()}),
                   QString());
        }
    }

    // A collection nobody can search for only exists for whoever remembers where it is.
    QSqlQuery cq(db);
    cq.prepare(QStringLiteral(
        "SELECT c.id, c.name, COUNT(ct.track_id) "
        "FROM collections c "
        "LEFT JOIN collection_tracks ct ON ct.collection_id = c.id "
        "WHERE c.name LIKE ? GROUP BY c.id ORDER BY c.name COLLATE NOCASE LIMIT ?"));
    cq.addBindValue(like);
    cq.addBindValue(limitPerKind);
    if (cq.exec()) {
        while (cq.next()) {
            append(QStringLiteral("collection"), cq.value(0).toInt(), cq.value(1).toString(),
                   plural(cq.value(2).toInt(), QStringLiteral("faixa"),
                          QStringLiteral("faixas")),
                   QString());
        }
    }

    QSqlQuery eq(db);
    const QString episodeSql =
        QStringLiteral(
            "SELECT e.id, e.title, IFNULL(s.title,''), IFNULL(e.local_path,''), "
            "IFNULL(e.published_at,0), IFNULL(e.duration_ms,0), IFNULL(s.cover_path,'') "
            "FROM podcast_episodes e LEFT JOIN podcast_shows s ON s.id = e.show_id "
            "WHERE e.title LIKE ? AND ")
        + PodcastScope::visibleShowClause(QStringLiteral("s"))
        + QStringLiteral(" ORDER BY e.published_at DESC LIMIT ?");
    eq.prepare(episodeSql);
    eq.addBindValue(like);
    PodcastScope::bindVisibleShow(eq, PodcastScope::currentRoot());
    eq.addBindValue(limitPerKind);
    if (eq.exec()) {
        while (eq.next()) {
            append(QStringLiteral("episode"), eq.value(0).toInt(), eq.value(1).toString(),
                   joinParts({eq.value(2).toString(),
                              formatShortDate(eq.value(4).toLongLong()),
                              formatMinutes(eq.value(5).toInt())}),
                   eq.value(3).toString(), eq.value(3).toString(), 0,
                   eq.value(6).toString());
        }
    }

    return out;
}

QVariantMap LibraryBrowser::lastPlayed()
{
    QVariantMap out;
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral(
            "SELECT t.path, IFNULL(t.title,''), IFNULL(ar.name,''), "
            "IFNULL(ts.last_position_ms,0), IFNULL(t.album_id,0), IFNULL(t.duration_ms,0) "
            "FROM track_stats ts "
            "JOIN tracks t ON t.id = ts.track_id AND t.removed_at IS NULL "
            "LEFT JOIN artists ar ON ar.id = t.artist_id "
            "WHERE ts.last_played_at IS NOT NULL "
            "ORDER BY ts.last_played_at DESC LIMIT 1"))
        || !q.next())
        return out;

    out.insert(QStringLiteral("path"), q.value(0).toString());
    out.insert(QStringLiteral("title"), q.value(1).toString());
    out.insert(QStringLiteral("artist"), q.value(2).toString());
    out.insert(QStringLiteral("positionMs"), q.value(3).toInt());
    out.insert(QStringLiteral("albumId"), q.value(4).toInt());
    out.insert(QStringLiteral("durationMs"), q.value(5).toInt());
    return out;
}

int LibraryBrowser::neverPlayedCount()
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral(
            "SELECT COUNT(*) FROM tracks t "
            "LEFT JOIN track_stats ts ON ts.track_id = t.id "
            "WHERE t.removed_at IS NULL AND IFNULL(ts.play_count, 0) = 0"))
        || !q.next())
        return 0;
    return q.value(0).toInt();
}

int LibraryBrowser::forgottenCount()
{
    // Mesma definição de "esquecida" da clauseForgotten(): tocada o bastante para ter gostado,
    // e sem ser tocada há tempo demais.
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM tracks t JOIN track_stats ts ON ts.track_id = t.id "
        "WHERE t.removed_at IS NULL AND ts.play_count >= ? "
        "AND IFNULL(ts.last_played_at, 0) < CAST(strftime('%s','now') AS INTEGER) - ?"));
    q.addBindValue(kForgottenMinPlays);
    q.addBindValue(qint64(kForgottenDays) * 86400);
    if (!q.exec() || !q.next())
        return 0;
    return q.value(0).toInt();
}
