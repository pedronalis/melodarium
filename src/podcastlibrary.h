#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

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

public:
    static constexpr int kSaveIntervalMs = 5000;
    static constexpr double kPlayedThreshold = 0.95;
    static constexpr int kResumeBackoffSec = 3;

    explicit PodcastLibrary(QObject *parent = nullptr);

    QString podcastPath() const { return m_podcastPath; }
    void setPodcastPath(const QString &path);
    bool scanning() const { return m_scanning; }

    Q_INVOKABLE QVariantList shows();
    Q_INVOKABLE QVariantList continueListening(int limit = 5);
    Q_INVOKABLE void scanPodcastFolder();
    Q_INVOKABLE void playEpisode(int episodeId);
    Q_INVOKABLE void savePosition(int episodeId, int positionMs);
    Q_INVOKABLE void markPlayed(int episodeId, bool played);
    Q_INVOKABLE QVariantMap episodeForPath(const QString &path);

signals:
    void podcastPathChanged();
    void scanningChanged();
    void showsChanged();
    void episodesChanged(int showId);
    void episodePlayRequested(const QString &path, int seekToSeconds);

private:
    int ensureShow(const QString &folderPath, const QString &title);
    void autoMarkPlayed(int episodeId);

    QString m_podcastPath;
    bool m_scanning = false;
};
