#pragma once

#include <QHash>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

#include "podcastfeedfetcher.h"

class EpisodeDownloader;

// Deliberate boundary: podcast has no collection and no tag support, so CollectionManager is
// never consumed here. The spec organizes podcast by show only, with "continue listening" on
// top — see docs/specs/2026-08-27-player-musica-podcast.md, "Como fica organizado".
class PodcastLibrary : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString podcastPath READ podcastPath WRITE setPodcastPath NOTIFY podcastPathChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool checkingFeeds READ checkingFeeds NOTIFY checkingFeedsChanged)

public:
    static constexpr int kSaveIntervalMs = 5000;
    static constexpr double kPlayedThreshold = 0.95;
    static constexpr int kResumeBackoffSec = 3;
    static constexpr int kFeedCheckIntervalMs = 30 * 60 * 1000; // 30 min, app open only

    explicit PodcastLibrary(QObject *parent = nullptr);
    ~PodcastLibrary() override;

    QString podcastPath() const { return m_podcastPath; }
    void setPodcastPath(const QString &path);
    bool scanning() const { return m_scanning; }
    bool checkingFeeds() const { return m_checkingFeeds; }

    Q_INVOKABLE QVariantList shows();
    Q_INVOKABLE QVariantList continueListening(int limit = 5);
    Q_INVOKABLE void scanPodcastFolder();
    Q_INVOKABLE void playEpisode(int episodeId);
    Q_INVOKABLE void savePosition(int episodeId, int positionMs);
    Q_INVOKABLE void markPlayed(int episodeId, bool played);
    Q_INVOKABLE QVariantMap episodeForPath(const QString &path);

    Q_INVOKABLE void subscribe(const QUrl &feedUrl);
    Q_INVOKABLE void unsubscribe(int showId);
    Q_INVOKABLE void checkAllFeeds();
    Q_INVOKABLE void checkFeed(int showId);
    Q_INVOKABLE void downloadEpisode(int episodeId);
    Q_INVOKABLE void cancelDownload(int episodeId);
    Q_INVOKABLE QString downloadDirectory() const; // AppDataLocation + "/podcasts"

    // Test seam: the ingestion is where "what is a new episode" is decided, and it is worth
    // testing without a network round trip.
    void ingestFeed(int showId, const ParsedChannel &channel,
                    const QList<ParsedEpisode> &episodes, const QByteArray &etag,
                    const QByteArray &lastModified);

signals:
    void podcastPathChanged();
    void scanningChanged();
    void checkingFeedsChanged();
    void showsChanged();
    void episodesChanged(int showId);
    void episodePlayRequested(const QString &path, int seekToSeconds);
    void subscribeFailed(const QString &reason);
    void feedCheckFailed(int showId, const QString &reason);
    void downloadProgress(int episodeId, qint64 received, qint64 total);
    void downloadFinished(int episodeId);
    void downloadFailed(int episodeId, const QString &reason);

private:
    int ensureShow(const QString &folderPath, const QString &title);
    void autoMarkPlayed(int episodeId);
    void startFetch(int showId, const QUrl &feedUrl);
    void setCheckingFeeds(bool checking);
    void refreshCheckTimer();
    static QString sanitiseFileName(const QString &raw);

    QString m_podcastPath;
    bool m_scanning = false;
    bool m_checkingFeeds = false;
    int m_pendingChecks = 0;
    QTimer m_checkTimer;
    QHash<int, EpisodeDownloader *> m_downloads;
};
