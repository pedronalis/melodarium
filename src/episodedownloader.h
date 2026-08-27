#pragma once

#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QString>
#include <QUrl>

class EpisodeDownloader : public QObject
{
    Q_OBJECT

public:
    explicit EpisodeDownloader(QObject *parent = nullptr);

    void start(int episodeId, const QUrl &url, const QString &destPath);
    void cancel();

    static void sweepOrphanParts(const QString &downloadDir); // called at startup

signals:
    void progress(int episodeId, qint64 received, qint64 total);
    void finished(int episodeId, const QString &localPath);
    void failed(int episodeId, const QString &reason);

private:
    QNetworkAccessManager *m_nam = nullptr;
    QNetworkReply *m_reply = nullptr;
    QFile *m_file = nullptr;
    int m_episodeId = 0;
    qint64 m_resumeFrom = 0;
    QString m_destPath;
    QString m_partPath;
};
