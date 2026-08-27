#include "podcastlibrary.h"

#include "database.h"
#include "tagreader.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariant>

// No collection and no tag queries live in this file, on purpose: the spec keeps podcast
// organized by show only, so CollectionManager is not a dependency of the podcast library.
// If a "collection of episodes" ever shows up here, it came from outside the spec.

namespace {

QSqlDatabase uiDb()
{
    return QSqlDatabase::database(QLatin1String(Database::kUiConnection));
}

const QStringList &podcastSuffixes()
{
    static const QStringList list = {QStringLiteral("mp3"), QStringLiteral("m4a"),
                                     QStringLiteral("opus"), QStringLiteral("ogg"),
                                     QStringLiteral("aac"), QStringLiteral("flac")};
    return list;
}

} // namespace

PodcastLibrary::PodcastLibrary(QObject *parent)
    : QObject(parent)
{
    m_podcastPath = QSettings().value(QStringLiteral("podcast/path")).toString();
}

void PodcastLibrary::setPodcastPath(const QString &path)
{
    if (m_podcastPath == path)
        return;
    m_podcastPath = path;
    QSettings().setValue(QStringLiteral("podcast/path"), path);
    emit podcastPathChanged();
}

int PodcastLibrary::ensureShow(const QString &folderPath, const QString &title)
{
    QSqlQuery sel(uiDb());
    sel.prepare(QStringLiteral("SELECT id FROM podcast_shows WHERE folder_path = ?"));
    sel.addBindValue(folderPath);
    if (sel.exec() && sel.next())
        return sel.value(0).toInt();

    QSqlQuery ins(uiDb());
    ins.prepare(QStringLiteral("INSERT INTO podcast_shows (title, folder_path) VALUES (?, ?)"));
    ins.addBindValue(title);
    ins.addBindValue(folderPath);
    return ins.exec() ? ins.lastInsertId().toInt() : 0;
}

void PodcastLibrary::scanPodcastFolder()
{
    if (m_podcastPath.isEmpty() || m_scanning)
        return;

    m_scanning = true;
    emit scanningChanged();

    // One folder per show. Files loose at the root go into a catch-all show so nothing
    // silently disappears from the user's view.
    const QDir root(m_podcastPath);
    QStringList folders = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    folders.prepend(QString()); // the root itself

    for (const QString &folder : folders) {
        const QString folderPath = folder.isEmpty() ? root.absolutePath()
                                                    : root.absoluteFilePath(folder);
        const QString showTitle = folder.isEmpty() ? QObject::tr("Avulsos") : folder;

        QDir showDir(folderPath);
        const QStringList files = showDir.entryList(QDir::Files);
        QStringList audio;
        for (const QString &f : files) {
            if (podcastSuffixes().contains(QFileInfo(f).suffix().toLower()))
                audio.append(showDir.absoluteFilePath(f));
        }
        if (audio.isEmpty())
            continue;

        const int showId = ensureShow(folderPath, showTitle);
        if (showId <= 0)
            continue;

        for (const QString &path : audio) {
            QSqlQuery exists(uiDb());
            exists.prepare(QStringLiteral("SELECT id FROM podcast_episodes WHERE local_path = ?"));
            exists.addBindValue(path);
            if (exists.exec() && exists.next())
                continue; // already catalogued: never re-read tags nor reset the position

            const TrackRecord rec = TagReader::read(path);
            const QFileInfo info(path);
            QSqlQuery ins(uiDb());
            ins.prepare(QStringLiteral(
                "INSERT INTO podcast_episodes (show_id, guid, title, published_at, duration_ms, "
                "local_path) VALUES (?, ?, ?, ?, ?, ?)"));
            ins.addBindValue(showId);
            // A local file has no RSS guid: the path is its identity until a feed claims it.
            ins.addBindValue(path);
            ins.addBindValue(rec.valid && !rec.title.isEmpty() ? rec.title : info.completeBaseName());
            ins.addBindValue(info.lastModified().toSecsSinceEpoch());
            ins.addBindValue(rec.valid ? rec.durationMs : 0);
            ins.addBindValue(path);
            ins.exec();
        }
        emit episodesChanged(showId);
    }

    m_scanning = false;
    emit scanningChanged();
    emit showsChanged();
}

QVariantList PodcastLibrary::shows()
{
    QSqlQuery q(uiDb());
    QVariantList out;
    if (!q.exec(QStringLiteral(
            "SELECT s.id, s.title, IFNULL(s.cover_path,''), COUNT(e.id), "
            "SUM(CASE WHEN e.played = 0 THEN 1 ELSE 0 END) "
            "FROM podcast_shows s LEFT JOIN podcast_episodes e ON e.show_id = s.id "
            "GROUP BY s.id ORDER BY s.title COLLATE NOCASE")))
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("title"), q.value(1).toString()},
                               {QStringLiteral("coverPath"), q.value(2).toString()},
                               {QStringLiteral("episodeCount"), q.value(3).toInt()},
                               {QStringLiteral("unplayedCount"), q.value(4).toInt()}});
    }
    return out;
}

QVariantList PodcastLibrary::continueListening(int limit)
{
    QSqlQuery q(uiDb());
    // Started but not finished, most recently touched first. This is the top of the podcast
    // screen: the opposite of shuffling.
    q.prepare(QStringLiteral(
        "SELECT e.id, e.title, s.title, e.position_ms, e.duration_ms, IFNULL(e.local_path,'') "
        "FROM podcast_episodes e JOIN podcast_shows s ON s.id = e.show_id "
        "WHERE e.played = 0 AND e.position_ms > 0 AND e.local_path IS NOT NULL "
        "ORDER BY e.last_played_at DESC LIMIT ?"));
    q.addBindValue(limit);
    QVariantList out;
    if (!q.exec())
        return out;
    while (q.next()) {
        const int position = q.value(3).toInt();
        const int duration = q.value(4).toInt();
        out.append(QVariantMap{
            {QStringLiteral("id"), q.value(0).toInt()},
            {QStringLiteral("title"), q.value(1).toString()},
            {QStringLiteral("showTitle"), q.value(2).toString()},
            {QStringLiteral("positionMs"), position},
            {QStringLiteral("durationMs"), duration},
            {QStringLiteral("progress"), duration > 0 ? double(position) / duration : 0.0},
            {QStringLiteral("path"), q.value(5).toString()}});
    }
    return out;
}

void PodcastLibrary::playEpisode(int episodeId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT local_path, position_ms FROM podcast_episodes WHERE id = ?"));
    q.addBindValue(episodeId);
    if (!q.exec() || !q.next())
        return;

    const QString path = q.value(0).toString();
    if (path.isEmpty())
        return;

    // Rewind a few seconds: picking up mid-sentence loses the thread.
    const int seconds = qMax(0, q.value(1).toInt() / 1000 - kResumeBackoffSec);
    emit episodePlayRequested(path, seconds);
}

void PodcastLibrary::savePosition(int episodeId, int positionMs)
{
    if (episodeId <= 0 || positionMs < 0)
        return;

    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "UPDATE podcast_episodes SET position_ms = ?, last_played_at = ? WHERE id = ?"));
    q.addBindValue(positionMs);
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    q.addBindValue(episodeId);
    q.exec();

    // Near the end counts as listened: nobody sits through the outro to get the checkmark.
    QSqlQuery dur(uiDb());
    dur.prepare(QStringLiteral("SELECT duration_ms FROM podcast_episodes WHERE id = ?"));
    dur.addBindValue(episodeId);
    if (dur.exec() && dur.next()) {
        const int duration = dur.value(0).toInt();
        if (duration > 0 && double(positionMs) / duration >= kPlayedThreshold)
            autoMarkPlayed(episodeId);
    }
}

// The automatic mark is NOT the manual gesture. When the app decides on its own that the
// episode is over, it keeps the saved position: un-marking then gives the user back exactly
// where they were, instead of throwing them to the start of a two-hour episode. markPlayed()
// is the deliberate "I am done with this", and that one does clear it.
void PodcastLibrary::autoMarkPlayed(int episodeId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "UPDATE podcast_episodes SET played = 1 WHERE id = ? AND played = 0"));
    q.addBindValue(episodeId);
    if (!q.exec() || q.numRowsAffected() <= 0)
        return;

    QSqlQuery show(uiDb());
    show.prepare(QStringLiteral("SELECT show_id FROM podcast_episodes WHERE id = ?"));
    show.addBindValue(episodeId);
    if (show.exec() && show.next())
        emit episodesChanged(show.value(0).toInt());
    emit showsChanged();
}

void PodcastLibrary::markPlayed(int episodeId, bool played)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral("UPDATE podcast_episodes SET played = ?, position_ms = CASE "
                             "WHEN ? = 1 THEN 0 ELSE position_ms END WHERE id = ?"));
    q.addBindValue(played ? 1 : 0);
    q.addBindValue(played ? 1 : 0);
    q.addBindValue(episodeId);
    if (q.exec() && q.numRowsAffected() > 0) {
        QSqlQuery show(uiDb());
        show.prepare(QStringLiteral("SELECT show_id FROM podcast_episodes WHERE id = ?"));
        show.addBindValue(episodeId);
        if (show.exec() && show.next())
            emit episodesChanged(show.value(0).toInt());
        emit showsChanged();
    }
}

QVariantMap PodcastLibrary::episodeForPath(const QString &path)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT id, show_id, title, position_ms, duration_ms, played "
        "FROM podcast_episodes WHERE local_path = ?"));
    q.addBindValue(path);
    if (!q.exec() || !q.next())
        return {};
    return QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                       {QStringLiteral("showId"), q.value(1).toInt()},
                       {QStringLiteral("title"), q.value(2).toString()},
                       {QStringLiteral("positionMs"), q.value(3).toInt()},
                       {QStringLiteral("durationMs"), q.value(4).toInt()},
                       {QStringLiteral("played"), q.value(5).toInt() == 1}};
}
