#include "playstatsrecorder.h"

#include "database.h"

#include <QDateTime>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariant>

PlayStatsRecorder::PlayStatsRecorder(QObject *parent)
    : QObject(parent)
{
}

void PlayStatsRecorder::recordPlay(const QString &path)
{
    if (path.isEmpty())
        return;
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "UPDATE track_stats SET play_count = play_count + 1, last_played_at = ? "
        "WHERE track_id = (SELECT id FROM tracks WHERE path = ?)"));
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    q.addBindValue(path);
    if (q.exec() && q.numRowsAffected() > 0)
        emit statsChanged(path);
}

void PlayStatsRecorder::recordSkip(const QString &path)
{
    if (path.isEmpty())
        return;
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "UPDATE track_stats SET skip_count = skip_count + 1 "
        "WHERE track_id = (SELECT id FROM tracks WHERE path = ?)"));
    q.addBindValue(path);
    if (q.exec() && q.numRowsAffected() > 0)
        emit statsChanged(path);
}

void PlayStatsRecorder::savePosition(const QString &path, int positionMs)
{
    if (path.isEmpty() || positionMs < 0)
        return;

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "UPDATE track_stats SET last_position_ms = ? "
        "WHERE track_id = (SELECT id FROM tracks WHERE path = ?)"));
    q.addBindValue(positionMs);
    q.addBindValue(path);
    q.exec();
}
