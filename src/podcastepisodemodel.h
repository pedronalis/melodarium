#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

struct EpisodeRowData {
    int id = 0;
    QString title;
    QString path;
    qint64 publishedAt = 0;
    int durationMs = 0;
    int positionMs = 0;
    bool played = false;
};

// Same boundary as PodcastLibrary: no collection and no tag roles here. Episodes belong to a
// show, and that is the only grouping the spec gives podcast.
class PodcastEpisodeModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int showId READ showId WRITE setShowId NOTIFY showIdChanged)
    Q_PROPERTY(QString currentPath READ currentPath WRITE setCurrentPath NOTIFY currentPathChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        PathRole,
        PublishedAtRole,
        DurationMsRole,
        PositionMsRole,
        PlayedRole,
        ProgressRole,
        IsCurrentRole,
    };
    Q_ENUM(Roles)

    explicit PodcastEpisodeModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int showId() const { return m_showId; }
    void setShowId(int id);
    QString currentPath() const { return m_currentPath; }
    void setCurrentPath(const QString &path);

    Q_INVOKABLE void loadForShow(int showId);
    Q_INVOKABLE QVariantMap episodeAt(int row) const;

    void setRowsForTesting(const QList<EpisodeRowData> &rows);

signals:
    void countChanged();
    void showIdChanged();
    void currentPathChanged();

private:
    QList<EpisodeRowData> m_rows;
    int m_showId = 0;
    QString m_currentPath;
};
