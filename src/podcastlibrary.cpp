#include "podcastlibrary.h"

#include "database.h"
#include "episodedownloader.h"
#include "podcastscope.h"
#include "tagreader.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QSet>
#include <QVariant>
#include <QtConcurrent/QtConcurrentRun>

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

struct LocalEpisode
{
    QString title;
    qint64 publishedAt = 0;
    qint64 durationMs = 0;
    QString path;
};

struct LocalShowBatch
{
    QString folderPath;
    QString title;
    QList<LocalEpisode> episodes;
};

struct PodcastScanResult
{
    bool ok = false;
    bool changed = false;
    QString error;
};

struct PodcastWriterGuard
{
    QString connectionName;

    ~PodcastWriterGuard()
    {
        if (!QSqlDatabase::contains(connectionName))
            return;
        {
            QSqlDatabase db = QSqlDatabase::database(connectionName, false);
            if (db.isValid())
                db.close();
        }
        QSqlDatabase::removeDatabase(connectionName);
    }
};

PodcastScanResult runLocalPodcastScan(const QString &rootPath, const QString &dbPath)
{
    const QString connectionName = QStringLiteral("melodarium-podcast-writer");
    const PodcastWriterGuard guard{connectionName};
    PodcastScanResult result;
    if (!Database::openConnection(connectionName, dbPath)) {
        result.error = QStringLiteral("could not open podcast writer connection");
        return result;
    }
    QSqlDatabase db = QSqlDatabase::database(connectionName);

    QSet<QString> knownPaths;
    QSqlQuery known(db);
    if (!known.exec(QStringLiteral(
            "SELECT local_path FROM podcast_episodes WHERE local_path IS NOT NULL"))) {
        result.error = known.lastError().text();
        return result;
    }
    while (known.next())
        knownPaths.insert(known.value(0).toString());
    known.finish();

    // All filesystem and TagLib work happens before the short writer transaction.
    const QDir root(rootPath);
    QStringList folders = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    folders.prepend(QString());
    QList<LocalShowBatch> batches;
    for (const QString &folder : folders) {
        LocalShowBatch batch;
        batch.folderPath = folder.isEmpty() ? root.absolutePath() : root.absoluteFilePath(folder);
        batch.title = folder.isEmpty() ? QObject::tr("Avulsos") : folder;

        const QDir showDir(batch.folderPath);
        const QStringList files = showDir.entryList(QDir::Files);
        for (const QString &file : files) {
            if (!podcastSuffixes().contains(QFileInfo(file).suffix().toLower()))
                continue;
            const QString path = showDir.absoluteFilePath(file);
            if (knownPaths.contains(path))
                continue;
            const TrackRecord record = TagReader::read(path);
            const QFileInfo info(path);
            batch.episodes.append(
                {record.valid && !record.title.isEmpty() ? record.title
                                                         : info.completeBaseName(),
                 info.lastModified().toSecsSinceEpoch(),
                 record.valid ? record.durationMs : 0,
                 path});
        }
        if (!batch.episodes.isEmpty())
            batches.append(std::move(batch));
    }

    if (!db.transaction()) {
        result.error = db.lastError().text();
        return result;
    }

    bool changed = false;
    for (const LocalShowBatch &batch : batches) {
        int showId = 0;
        QSqlQuery selectShow(db);
        selectShow.prepare(QStringLiteral(
            "SELECT id FROM podcast_shows WHERE folder_path = ?"));
        selectShow.addBindValue(batch.folderPath);
        if (!selectShow.exec()) {
            result.error = selectShow.lastError().text();
            db.rollback();
            return result;
        }
        if (selectShow.next()) {
            showId = selectShow.value(0).toInt();
        } else {
            QSqlQuery insertShow(db);
            insertShow.prepare(QStringLiteral(
                "INSERT INTO podcast_shows (title, folder_path) VALUES (?, ?)"));
            insertShow.addBindValue(batch.title);
            insertShow.addBindValue(batch.folderPath);
            if (!insertShow.exec()) {
                result.error = insertShow.lastError().text();
                db.rollback();
                return result;
            }
            showId = insertShow.lastInsertId().toInt();
            changed = true;
        }

        for (const LocalEpisode &episode : batch.episodes) {
            QSqlQuery insertEpisode(db);
            insertEpisode.prepare(QStringLiteral(
                "INSERT OR IGNORE INTO podcast_episodes "
                "(show_id, guid, title, published_at, duration_ms, local_path) "
                "VALUES (?, ?, ?, ?, ?, ?)"));
            insertEpisode.addBindValue(showId);
            insertEpisode.addBindValue(episode.path);
            insertEpisode.addBindValue(episode.title);
            insertEpisode.addBindValue(episode.publishedAt);
            insertEpisode.addBindValue(episode.durationMs);
            insertEpisode.addBindValue(episode.path);
            if (!insertEpisode.exec()) {
                result.error = insertEpisode.lastError().text();
                db.rollback();
                return result;
            }
            changed = changed || insertEpisode.numRowsAffected() > 0;
        }
    }

    if (!db.commit()) {
        result.error = db.lastError().text();
        db.rollback();
        return result;
    }
    result.ok = true;
    result.changed = changed;
    return result;
}

} // namespace

PodcastLibrary::PodcastLibrary(QObject *parent)
    : QObject(parent)
{
    m_podcastPath = PodcastScope::currentRoot();

    // Anything left in .part came from a crash or a kill: no download survives a restart.
    EpisodeDownloader::sweepOrphanParts(downloadDirectory());

    m_checkTimer.setInterval(kFeedCheckIntervalMs);
    connect(&m_checkTimer, &QTimer::timeout, this, &PodcastLibrary::checkAllFeeds);
    // Deferred by one event-loop turn: this object can be constructed before the Database
    // singleton opens the connection, and counting feeds before that reads zero every time.
    QTimer::singleShot(0, this, [this]() { refreshCheckTimer(); });
}

PodcastLibrary::~PodcastLibrary()
{
    if (m_scanWatcher)
        m_scanWatcher->waitForFinished();
}

void PodcastLibrary::setPodcastPath(const QString &path)
{
    const QString cleanPath = PodcastScope::normaliseRoot(path);
    if (m_podcastPath == cleanPath)
        return;
    m_podcastPath = cleanPath;
    QSettings().setValue(QStringLiteral("podcast/path"), cleanPath);
    emit podcastPathChanged();
}

void PodcastLibrary::scanPodcastFolder()
{
    if (m_podcastPath.isEmpty() || m_scanning)
        return;

    m_scanning = true;
    emit scanningChanged();

    const QString rootPath = m_podcastPath;
    const QString dbPath = uiDb().databaseName();
    auto *watcher = new QFutureWatcher<PodcastScanResult>(this);
    m_scanWatcher = watcher;
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher]() {
        const PodcastScanResult result = watcher->result();
        m_scanWatcher = nullptr;
        watcher->deleteLater();
        m_scanning = false;
        emit scanningChanged();
        if (!result.ok) {
            qWarning().noquote() << "local podcast scan rolled back:" << result.error;
            return;
        }
        // PodcastPane refreshes shows and episodes from either signal. Emit one update for
        // the whole committed batch, not one per folder plus another global refresh.
        if (result.changed)
            emit showsChanged();
    }, Qt::QueuedConnection);
    watcher->setFuture(QtConcurrent::run(runLocalPodcastScan, rootPath, dbPath));
}

QVariantList PodcastLibrary::shows()
{
    QSqlQuery q(uiDb());
    QVariantList out;
    const QString sql =
        QStringLiteral(
            "SELECT s.id, s.title, IFNULL(s.cover_path,''), COUNT(e.id), "
            "SUM(CASE WHEN e.played = 0 THEN 1 ELSE 0 END), "
            "IFNULL(s.last_checked_at,0), IFNULL(s.feed_url,'') "
            "FROM podcast_shows s LEFT JOIN podcast_episodes e ON e.show_id = s.id WHERE ")
        + PodcastScope::visibleShowClause(QStringLiteral("s"))
        + QStringLiteral(" GROUP BY s.id ORDER BY s.title COLLATE NOCASE");
    q.prepare(sql);
    PodcastScope::bindVisibleShow(q, m_podcastPath);
    if (!q.exec())
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("title"), q.value(1).toString()},
                               {QStringLiteral("coverPath"), q.value(2).toString()},
                               {QStringLiteral("episodeCount"), q.value(3).toInt()},
                               {QStringLiteral("unplayedCount"), q.value(4).toInt()},
                               {QStringLiteral("lastCheckedAt"), q.value(5).toLongLong()},
                               {QStringLiteral("feedUrl"), q.value(6).toString()}});
    }
    return out;
}

QVariantList PodcastLibrary::allEpisodes(int showId, int limit)
{
    QSqlQuery q(uiDb());
    const QString sql =
        QStringLiteral(
            "SELECT e.id, e.title, IFNULL(s.title,''), s.id, IFNULL(e.published_at,0), "
            "IFNULL(e.duration_ms,0), e.position_ms, e.played, IFNULL(e.local_path,'') "
            "FROM podcast_episodes e JOIN podcast_shows s ON s.id = e.show_id "
            "WHERE (? = 0 OR e.show_id = ?) AND ")
        + PodcastScope::visibleShowClause(QStringLiteral("s"))
        + QStringLiteral(" ORDER BY e.published_at DESC, e.id DESC LIMIT ?");
    q.prepare(sql);
    q.addBindValue(showId);
    q.addBindValue(showId);
    PodcastScope::bindVisibleShow(q, m_podcastPath);
    q.addBindValue(limit);

    QVariantList out;
    if (!q.exec())
        return out;
    while (q.next()) {
        const int position = q.value(6).toInt();
        const int duration = q.value(5).toInt();
        out.append(QVariantMap{
            {QStringLiteral("id"), q.value(0).toInt()},
            {QStringLiteral("title"), q.value(1).toString()},
            {QStringLiteral("showTitle"), q.value(2).toString()},
            {QStringLiteral("showId"), q.value(3).toInt()},
            {QStringLiteral("publishedAt"), q.value(4).toLongLong()},
            {QStringLiteral("durationMs"), duration},
            {QStringLiteral("positionMs"), position},
            {QStringLiteral("played"), q.value(7).toBool()},
            {QStringLiteral("progress"), duration > 0 ? double(position) / duration : 0.0},
            {QStringLiteral("path"), q.value(8).toString()}});
    }
    return out;
}

QVariantList PodcastLibrary::continueListening(int limit)
{
    QSqlQuery q(uiDb());
    // Started but not finished, most recently touched first. This is the top of the podcast
    // screen: the opposite of shuffling.
    const QString sql =
        QStringLiteral(
            "SELECT e.id, e.title, s.title, s.id, IFNULL(s.cover_path,''), "
            "e.position_ms, e.duration_ms, IFNULL(e.local_path,'') "
            "FROM podcast_episodes e JOIN podcast_shows s ON s.id = e.show_id "
            "WHERE e.played = 0 AND e.position_ms > 0 AND e.local_path IS NOT NULL AND ")
        + PodcastScope::visibleShowClause(QStringLiteral("s"))
        + QStringLiteral(" ORDER BY e.last_played_at DESC LIMIT ?");
    q.prepare(sql);
    PodcastScope::bindVisibleShow(q, m_podcastPath);
    q.addBindValue(limit);
    QVariantList out;
    if (!q.exec())
        return out;
    while (q.next()) {
        const int position = q.value(5).toInt();
        const int duration = q.value(6).toInt();
        out.append(QVariantMap{
            {QStringLiteral("id"), q.value(0).toInt()},
            {QStringLiteral("title"), q.value(1).toString()},
            {QStringLiteral("showTitle"), q.value(2).toString()},
            {QStringLiteral("showId"), q.value(3).toInt()},
            {QStringLiteral("coverPath"), q.value(4).toString()},
            {QStringLiteral("positionMs"), position},
            {QStringLiteral("durationMs"), duration},
            {QStringLiteral("progress"), duration > 0 ? double(position) / duration : 0.0},
            {QStringLiteral("path"), q.value(7).toString()}});
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
    // O painel mostra o episódio inteiro (programa e data), então o nome do programa vem
    // junto: sem ele a moldura diria "nada tocando" com um episódio no ar.
    q.prepare(QStringLiteral(
        "SELECT e.id, e.show_id, e.title, e.position_ms, e.duration_ms, e.played, "
        "IFNULL(s.title,''), IFNULL(e.published_at,0), IFNULL(s.cover_path,'') "
        "FROM podcast_episodes e LEFT JOIN podcast_shows s ON s.id = e.show_id "
        "WHERE e.local_path = ?"));
    q.addBindValue(path);
    if (!q.exec() || !q.next())
        return {};
    return QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                       {QStringLiteral("showId"), q.value(1).toInt()},
                       {QStringLiteral("title"), q.value(2).toString()},
                       {QStringLiteral("positionMs"), q.value(3).toInt()},
                       {QStringLiteral("durationMs"), q.value(4).toInt()},
                       {QStringLiteral("played"), q.value(5).toInt() == 1},
                       {QStringLiteral("showTitle"), q.value(6).toString()},
                       {QStringLiteral("publishedAt"), q.value(7).toLongLong()},
                       {QStringLiteral("coverPath"), q.value(8).toString()}};
}

// --- Feeds -------------------------------------------------------------------------------
//
// Everything below only runs while the app is open. That is not a limitation to hide: the UI
// says so out loud in FeedStatusRow.qml, because promising background downloads from a
// desktop app that is not running would be a lie.

QString PodcastLibrary::downloadDirectory() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QStringLiteral("/podcasts");
}

QString PodcastLibrary::sanitiseFileName(const QString &raw)
{
    QString clean = raw.simplified();
    // "/" would create a directory, and the rest are hostile on at least one of the two
    // platforms this app targets.
    static const QString forbidden = QStringLiteral("/\\:*?\"<>|");
    for (int i = 0; i < clean.size(); ++i) {
        if (forbidden.contains(clean.at(i)))
            clean[i] = QLatin1Char('-');
    }
    if (clean.isEmpty())
        clean = QStringLiteral("episode");
    return clean.left(120); // long titles exist; filesystem name limits do too
}

void PodcastLibrary::setCheckingFeeds(bool checking)
{
    if (m_checkingFeeds == checking)
        return;
    m_checkingFeeds = checking;
    emit checkingFeedsChanged();
}

void PodcastLibrary::refreshCheckTimer()
{
    QSqlQuery q(uiDb());
    const bool hasFeeds =
        q.exec(QStringLiteral("SELECT COUNT(*) FROM podcast_shows WHERE feed_url IS NOT NULL"))
        && q.next() && q.value(0).toInt() > 0;

    if (hasFeeds && !m_checkTimer.isActive())
        m_checkTimer.start();
    else if (!hasFeeds && m_checkTimer.isActive())
        m_checkTimer.stop();
}

void PodcastLibrary::ingestFeed(int showId, const ParsedChannel &channel,
                                const QList<ParsedEpisode> &episodes, const QByteArray &etag,
                                const QByteArray &lastModified)
{
    QSqlQuery meta(uiDb());
    meta.prepare(QStringLiteral(
        "UPDATE podcast_shows SET title = CASE WHEN ? <> '' THEN ? ELSE title END, "
        "etag = ?, last_modified = ?, last_checked_at = ? WHERE id = ?"));
    meta.addBindValue(channel.title);
    meta.addBindValue(channel.title);
    meta.addBindValue(QString::fromUtf8(etag));
    meta.addBindValue(QString::fromUtf8(lastModified));
    meta.addBindValue(QDateTime::currentSecsSinceEpoch());
    meta.addBindValue(showId);
    meta.exec();

    int inserted = 0;
    for (const ParsedEpisode &e : episodes) {
        // UNIQUE(show_id, guid) makes re-ingesting the same feed a no-op: a server that
        // ignores conditional GET costs bandwidth, never duplicate rows.
        QSqlQuery ins(uiDb());
        ins.prepare(QStringLiteral(
            "INSERT OR IGNORE INTO podcast_episodes (show_id, guid, title, published_at, "
            "duration_ms, remote_url) VALUES (?, ?, ?, ?, ?, ?)"));
        ins.addBindValue(showId);
        ins.addBindValue(e.guid);
        ins.addBindValue(e.title);
        ins.addBindValue(e.publishedAt.toSecsSinceEpoch());
        ins.addBindValue(e.durationSeconds * 1000);
        ins.addBindValue(e.enclosureUrl.toString());
        if (ins.exec() && ins.numRowsAffected() > 0)
            ++inserted;
    }

    if (inserted > 0) {
        emit episodesChanged(showId);
        emit showsChanged();
    }
}

void PodcastLibrary::startFetch(int showId, const QUrl &feedUrl)
{
    QSqlQuery meta(uiDb());
    meta.prepare(QStringLiteral(
        "SELECT IFNULL(etag,''), IFNULL(last_modified,'') FROM podcast_shows WHERE id = ?"));
    meta.addBindValue(showId);
    QByteArray etag;
    QByteArray lastModified;
    if (meta.exec() && meta.next()) {
        etag = meta.value(0).toString().toUtf8();
        lastModified = meta.value(1).toString().toUtf8();
    }

    // One fetcher per request, not one shared member: checkAllFeeds() has several requests in
    // flight at once, and a single fetcher could not say which show a reply belongs to.
    auto *fetcher = new PodcastFeedFetcher(this);
    ++m_pendingChecks;
    setCheckingFeeds(true);

    auto done = [this, fetcher]() {
        fetcher->deleteLater();
        if (--m_pendingChecks <= 0) {
            m_pendingChecks = 0;
            setCheckingFeeds(false);
        }
    };

    connect(fetcher, &PodcastFeedFetcher::feedParsed, this,
            [this, showId, done](const ParsedChannel &channel,
                                 const QList<ParsedEpisode> &episodes, const QByteArray &etag,
                                 const QByteArray &lastModified) {
                ingestFeed(showId, channel, episodes, etag, lastModified);
                done();
            });

    connect(fetcher, &PodcastFeedFetcher::notModified, this, [this, showId, done]() {
        // Nothing changed: only the "last checked" stamp moves, so the UI can say when.
        QSqlQuery q(uiDb());
        q.prepare(QStringLiteral("UPDATE podcast_shows SET last_checked_at = ? WHERE id = ?"));
        q.addBindValue(QDateTime::currentSecsSinceEpoch());
        q.addBindValue(showId);
        q.exec();
        emit showsChanged();
        done();
    });

    connect(fetcher, &PodcastFeedFetcher::fetchFailed, this,
            [this, showId, done](const QString &reason) {
                // No episode is deleted and no etag is cleared: being offline is a temporary
                // state, and the next cycle tries again from exactly where this one stopped.
                emit feedCheckFailed(showId, reason);
                done();
            });

    fetcher->fetch(feedUrl, etag, lastModified);
}

void PodcastLibrary::subscribe(const QUrl &feedUrl)
{
    if (!feedUrl.isValid() || feedUrl.host().isEmpty()
        || (feedUrl.scheme() != QLatin1String("http")
            && feedUrl.scheme() != QLatin1String("https"))) {
        emit subscribeFailed(tr("Endereço de feed inválido."));
        return;
    }

    QSqlQuery ins(uiDb());
    ins.prepare(QStringLiteral("INSERT INTO podcast_shows (title, feed_url) VALUES (?, ?)"));
    // Provisional name until the feed answers with its real <title>.
    ins.addBindValue(feedUrl.host());
    ins.addBindValue(feedUrl.toString());
    if (!ins.exec()) {
        // The UNIQUE on feed_url is what rejects subscribing twice to the same podcast.
        emit subscribeFailed(tr("Você já assina esse feed."));
        return;
    }

    const int showId = ins.lastInsertId().toInt();
    emit showsChanged();
    refreshCheckTimer();
    startFetch(showId, feedUrl);
}

void PodcastLibrary::unsubscribe(int showId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral("DELETE FROM podcast_shows WHERE id = ? AND feed_url IS NOT NULL"));
    q.addBindValue(showId);
    if (q.exec() && q.numRowsAffected() > 0) {
        emit showsChanged();
        refreshCheckTimer();
    }
}

void PodcastLibrary::checkFeed(int showId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT feed_url FROM podcast_shows WHERE id = ? AND feed_url IS NOT NULL"));
    q.addBindValue(showId);
    if (q.exec() && q.next())
        startFetch(showId, QUrl(q.value(0).toString()));
}

void PodcastLibrary::checkAllFeeds()
{
    QSqlQuery q(uiDb());
    if (!q.exec(QStringLiteral(
            "SELECT id, feed_url FROM podcast_shows WHERE feed_url IS NOT NULL")))
        return;

    QList<QPair<int, QUrl>> targets;
    while (q.next())
        targets.append({q.value(0).toInt(), QUrl(q.value(1).toString())});

    // The query is drained before fetching: startFetch runs its own queries on the same
    // connection, which would invalidate the cursor being iterated.
    for (const auto &target : targets)
        startFetch(target.first, target.second);
}

void PodcastLibrary::downloadEpisode(int episodeId)
{
    if (m_downloads.contains(episodeId))
        return; // already in flight

    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT e.remote_url, e.title, e.guid, s.title, IFNULL(e.local_path,'') "
        "FROM podcast_episodes e JOIN podcast_shows s ON s.id = e.show_id WHERE e.id = ?"));
    q.addBindValue(episodeId);
    if (!q.exec() || !q.next())
        return;

    const QUrl url(q.value(0).toString());
    if (!url.isValid() || url.isEmpty()) {
        emit downloadFailed(episodeId, tr("esse episódio não tem arquivo para baixar"));
        return;
    }
    if (!q.value(4).toString().isEmpty())
        return; // already on disk

    const QString episodeTitle = q.value(1).toString();
    const QString showTitle = q.value(3).toString();

    QString suffix = QFileInfo(url.path()).suffix().toLower();
    if (suffix.isEmpty() || suffix.size() > 5)
        suffix = QStringLiteral("mp3"); // what podcast enclosures overwhelmingly are

    const QString destPath = downloadDirectory() + QLatin1Char('/') + sanitiseFileName(showTitle)
                             + QLatin1Char('/') + sanitiseFileName(episodeTitle)
                             + QLatin1Char('.') + suffix;

    auto *downloader = new EpisodeDownloader(this);
    m_downloads.insert(episodeId, downloader);

    QSqlQuery state(uiDb());
    state.prepare(QStringLiteral(
        "UPDATE podcast_episodes SET download_state = 'downloading' WHERE id = ?"));
    state.addBindValue(episodeId);
    state.exec();

    connect(downloader, &EpisodeDownloader::progress, this, &PodcastLibrary::downloadProgress);

    connect(downloader, &EpisodeDownloader::finished, this,
            [this, downloader](int id, const QString &localPath) {
                QSqlQuery done(uiDb());
                done.prepare(QStringLiteral(
                    "UPDATE podcast_episodes SET local_path = ?, download_state = 'done' "
                    "WHERE id = ?"));
                done.addBindValue(localPath);
                done.addBindValue(id);
                done.exec();

                QSqlQuery show(uiDb());
                show.prepare(QStringLiteral(
                    "SELECT show_id FROM podcast_episodes WHERE id = ?"));
                show.addBindValue(id);
                if (show.exec() && show.next())
                    emit episodesChanged(show.value(0).toInt());

                m_downloads.remove(id);
                downloader->deleteLater();
                emit downloadFinished(id);
            });

    connect(downloader, &EpisodeDownloader::failed, this,
            [this, downloader](int id, const QString &reason) {
                QSqlQuery bad(uiDb());
                bad.prepare(QStringLiteral(
                    "UPDATE podcast_episodes SET download_state = 'failed' WHERE id = ?"));
                bad.addBindValue(id);
                bad.exec();

                m_downloads.remove(id);
                downloader->deleteLater();
                emit downloadFailed(id, reason);
            });

    downloader->start(episodeId, url, destPath);
}

void PodcastLibrary::cancelDownload(int episodeId)
{
    EpisodeDownloader *downloader = m_downloads.value(episodeId, nullptr);
    if (downloader)
        downloader->cancel();
}
