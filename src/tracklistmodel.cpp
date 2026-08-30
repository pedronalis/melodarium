#include "tracklistmodel.h"

#include "database.h"

#include <QFileInfo>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariant>
#include <utility>

namespace {
constexpr const char *kSelect =
    "SELECT t.id, t.path, t.title, t.artist_id, t.album_id, t.duration_ms, t.track_no, "
    "t.year, t.codec, t.sample_rate, t.bits_per_sample, "
    "IFNULL(ar.name,''), IFNULL(al.title,''), "
    "IFNULL(t.source_kind,'local_file'), IFNULL(t.source_format_note,''), "
    "t.liked_at IS NOT NULL "
    "FROM tracks t "
    "LEFT JOIN artists ar ON ar.id = t.artist_id "
    "LEFT JOIN albums al ON al.id = t.album_id ";
} // namespace

TrackListModel::TrackListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int TrackListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant TrackListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};

    const TrackRow &r = m_rows.at(index.row());
    switch (role) {
    case IdRole:
        return r.id;
    case PathRole:
        return r.path;
    case TitleRole:
        // A file with no title tag still needs something readable in the list.
        return r.title.isEmpty() ? QFileInfo(r.path).completeBaseName() : r.title;
    case ArtistRole:
        return r.artist;
    case AlbumRole:
        return r.album;
    case DurationMsRole:
        return r.durationMs;
    case TrackNoRole:
        return r.trackNo;
    case YearRole:
        return r.year;
    case CodecRole:
        return r.codec;
    case SampleRateRole:
        return r.sampleRate;
    case BitsPerSampleRole:
        return r.bitsPerSample;
    case IsCurrentRole:
        return !m_currentPath.isEmpty() && m_currentPath == r.path;
    case SourceKindRole:
        return r.sourceKind;
    case SourceNoteRole:
        return r.sourceNote;
    case LikedRole:
        return r.liked;
    default:
        return {};
    }
}

QHash<int, QByteArray> TrackListModel::roleNames() const
{
    return {
        {IdRole, "trackId"},           {PathRole, "path"},
        {TitleRole, "title"},          {ArtistRole, "artist"},
        {AlbumRole, "album"},          {DurationMsRole, "durationMs"},
        {TrackNoRole, "trackNo"},      {YearRole, "year"},
        {CodecRole, "codec"},          {SampleRateRole, "sampleRate"},
        {BitsPerSampleRole, "bitsPerSample"},
        {IsCurrentRole, "isCurrent"}, {SourceKindRole, "sourceKind"},
        {SourceNoteRole, "sourceNote"}, {LikedRole, "liked"},
    };
}

void TrackListModel::setCurrentPath(const QString &path)
{
    if (m_currentPath == path)
        return;
    const int previousRow = m_rowForPath.value(m_currentPath, -1);
    const int currentRow = m_rowForPath.value(path, -1);
    m_currentPath = path;
    emit currentPathChanged();
    if (previousRow >= 0)
        emit dataChanged(index(previousRow), index(previousRow), {IsCurrentRole});
    if (currentRow >= 0 && currentRow != previousRow)
        emit dataChanged(index(currentRow), index(currentRow), {IsCurrentRole});
}

void TrackListModel::loadAllTracks()
{
    loadFromQuery(QStringLiteral("t.removed_at IS NULL"), {});
}

void TrackListModel::loadFromQuery(const QString &whereClause, const QVariantList &bindings)
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    // A clause that carries its own ORDER BY (the automatic lists do) keeps it: appending the
    // default ordering after it would be a syntax error.
    const bool clauseHasOrder = whereClause.contains(QStringLiteral("ORDER BY"));
    q.prepare(QLatin1String(kSelect) + QStringLiteral("WHERE ") + whereClause
              + (clauseHasOrder
                     ? QString()
                     : QStringLiteral(" ORDER BY IFNULL(al.title,''), t.disc_no, t.track_no, t.title")));
    for (const QVariant &b : bindings)
        q.addBindValue(b);

    QList<TrackRow> rows;
    if (q.exec()) {
        while (q.next()) {
            TrackRow r;
            r.id = q.value(0).toInt();
            r.path = q.value(1).toString();
            r.title = q.value(2).toString();
            r.albumId = q.value(4).toInt();
            r.durationMs = q.value(5).toInt();
            r.trackNo = q.value(6).toInt();
            r.year = q.value(7).toInt();
            r.codec = q.value(8).toString();
            r.sampleRate = q.value(9).toInt();
            r.bitsPerSample = q.value(10).toInt();
            r.artist = q.value(11).toString();
            r.album = q.value(12).toString();
            r.sourceKind = q.value(13).toString();
            r.sourceNote = q.value(14).toString();
            r.liked = q.value(15).toBool();
            rows.append(r);
        }
    }

    beginResetModel();
    m_rows = std::move(rows);
    rebuildPathIndex();
    recomputeTotalDuration();
    endResetModel();
    emit countChanged();
}

QStringList TrackListModel::allPaths() const
{
    QStringList paths;
    paths.reserve(m_rows.size());
    for (const TrackRow &r : m_rows)
        paths.append(r.path);
    return paths;
}

QVariantList TrackListModel::allTrackIds() const
{
    QVariantList out;
    out.reserve(m_rows.size());
    for (const TrackRow &r : m_rows)
        out.append(r.id);
    return out;
}

QVariantMap TrackListModel::trackAt(int row) const
{
    if (row < 0 || row >= m_rows.size())
        return {};
    const TrackRow &r = m_rows.at(row);
    return {{QStringLiteral("id"), r.id},
            {QStringLiteral("path"), r.path},
            {QStringLiteral("title"), r.title},
            {QStringLiteral("artist"), r.artist},
            {QStringLiteral("album"), r.album},
            {QStringLiteral("durationMs"), r.durationMs}};
}

void TrackListModel::applyLiked(int trackId, bool liked)
{
    for (int i = 0; i < m_rows.size(); ++i) {
        if (m_rows[i].id != trackId)
            continue;
        if (m_rows[i].liked == liked)
            return;
        m_rows[i].liked = liked;
        emit dataChanged(index(i), index(i), {LikedRole});
        return;
    }
}

void TrackListModel::setRowsForTesting(const QList<TrackRow> &rows)
{
    beginResetModel();
    m_rows = rows;
    rebuildPathIndex();
    recomputeTotalDuration();
    endResetModel();
    emit countChanged();
}

void TrackListModel::recomputeTotalDuration()
{
    qint64 total = 0;
    for (const TrackRow &row : std::as_const(m_rows))
        total += row.durationMs;
    m_totalDurationMs = total;
}

void TrackListModel::rebuildPathIndex()
{
    m_rowForPath.clear();
    m_rowForPath.reserve(m_rows.size());
    for (int row = 0; row < m_rows.size(); ++row)
        m_rowForPath.insert(m_rows.at(row).path, row);
}
