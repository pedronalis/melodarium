#include "podcastepisodemodel.h"

#include "database.h"

#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariant>

// This model reads podcast_episodes and nothing else: no collection join, no tag join. The
// spec keeps podcast outside the collection/tag axis, and this file is where that would leak
// in first, so the absence is stated rather than assumed.

PodcastEpisodeModel::PodcastEpisodeModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int PodcastEpisodeModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant PodcastEpisodeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};

    const EpisodeRowData &e = m_rows.at(index.row());
    switch (role) {
    case IdRole:
        return e.id;
    case TitleRole:
        return e.title;
    case PathRole:
        return e.path;
    case PublishedAtRole:
        return e.publishedAt;
    case DurationMsRole:
        return e.durationMs;
    case PositionMsRole:
        return e.positionMs;
    case PlayedRole:
        return e.played;
    case ProgressRole:
        return e.durationMs > 0 ? double(e.positionMs) / e.durationMs : 0.0;
    case IsCurrentRole:
        return !m_currentPath.isEmpty() && m_currentPath == e.path;
    default:
        return {};
    }
}

QHash<int, QByteArray> PodcastEpisodeModel::roleNames() const
{
    return {{IdRole, "episodeId"},       {TitleRole, "title"},
            {PathRole, "path"},          {PublishedAtRole, "publishedAt"},
            {DurationMsRole, "durationMs"}, {PositionMsRole, "positionMs"},
            {PlayedRole, "played"},      {ProgressRole, "progress"},
            {IsCurrentRole, "isCurrent"}};
}

void PodcastEpisodeModel::setShowId(int id)
{
    if (m_showId == id)
        return;
    m_showId = id;
    emit showIdChanged();
    loadForShow(id);
}

void PodcastEpisodeModel::setCurrentPath(const QString &path)
{
    if (m_currentPath == path)
        return;
    m_currentPath = path;
    emit currentPathChanged();
    if (!m_rows.isEmpty())
        emit dataChanged(index(0), index(m_rows.size() - 1), {IsCurrentRole});
}

void PodcastEpisodeModel::loadForShow(int showId)
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "SELECT id, title, IFNULL(local_path,''), IFNULL(published_at,0), "
        "IFNULL(duration_ms,0), position_ms, played "
        "FROM podcast_episodes WHERE show_id = ? ORDER BY published_at DESC"));
    q.addBindValue(showId);

    QList<EpisodeRowData> rows;
    if (q.exec()) {
        while (q.next()) {
            EpisodeRowData e;
            e.id = q.value(0).toInt();
            e.title = q.value(1).toString();
            e.path = q.value(2).toString();
            e.publishedAt = q.value(3).toLongLong();
            e.durationMs = q.value(4).toInt();
            e.positionMs = q.value(5).toInt();
            e.played = q.value(6).toInt() == 1;
            rows.append(e);
        }
    }

    beginResetModel();
    m_rows = std::move(rows);
    endResetModel();
    emit countChanged();
}

QVariantMap PodcastEpisodeModel::episodeAt(int row) const
{
    if (row < 0 || row >= m_rows.size())
        return {};
    const EpisodeRowData &e = m_rows.at(row);
    return {{QStringLiteral("id"), e.id},
            {QStringLiteral("title"), e.title},
            {QStringLiteral("path"), e.path},
            {QStringLiteral("positionMs"), e.positionMs},
            {QStringLiteral("played"), e.played}};
}

void PodcastEpisodeModel::setRowsForTesting(const QList<EpisodeRowData> &rows)
{
    beginResetModel();
    m_rows = rows;
    endResetModel();
    emit countChanged();
}
