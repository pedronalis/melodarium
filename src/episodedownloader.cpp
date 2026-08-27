#include "episodedownloader.h"

#include <QDir>
#include <QFile>
#include <QNetworkReply>
#include <QNetworkRequest>

#include <chrono>

EpisodeDownloader::EpisodeDownloader(QObject *parent)
    : QObject(parent), m_nam(new QNetworkAccessManager(this))
{
}

void EpisodeDownloader::sweepOrphanParts(const QString &downloadDir)
{
    // A .part with no matching "in progress" row is leftover from a crash. Deleting it at
    // startup keeps the folder from silently growing.
    QDir dir(downloadDir);
    const QStringList parts = dir.entryList({QStringLiteral("*.part")}, QDir::Files);
    for (const QString &p : parts)
        QFile::remove(dir.absoluteFilePath(p));
}

void EpisodeDownloader::start(int episodeId, const QUrl &url, const QString &destPath)
{
    m_episodeId = episodeId;
    m_destPath = destPath;
    m_partPath = destPath + QStringLiteral(".part");

    QDir().mkpath(QFileInfo(destPath).absolutePath());

    m_resumeFrom = 0;
    QFileInfo partInfo(m_partPath);
    if (partInfo.exists() && partInfo.size() > 0)
        m_resumeFrom = partInfo.size();

    m_file = new QFile(m_partPath, this);
    if (!m_file->open(m_resumeFrom > 0 ? QIODevice::Append : QIODevice::WriteOnly)) {
        emit failed(episodeId, QStringLiteral("cannot write to the downloads folder"));
        return;
    }

    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setTransferTimeout(std::chrono::milliseconds(30000));
    if (m_resumeFrom > 0)
        req.setRawHeader("Range", "bytes=" + QByteArray::number(m_resumeFrom) + "-");

    m_reply = m_nam->get(req);

    connect(m_reply, &QNetworkReply::readyRead, this, [this]() {
        if (m_file && m_file->isOpen())
            m_file->write(m_reply->readAll());
    });

    connect(m_reply, &QNetworkReply::downloadProgress, this,
            [this](qint64 received, qint64 total) {
                emit progress(m_episodeId, m_resumeFrom + received,
                              total > 0 ? m_resumeFrom + total : -1);
            });

    connect(m_reply, &QNetworkReply::finished, this, [this]() {
        const int status =
            m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QNetworkReply::NetworkError error = m_reply->error();
        m_reply->deleteLater();
        m_reply = nullptr;

        if (m_file) {
            m_file->close();
        }

        if (error != QNetworkReply::NoError) {
            // Keep the .part on disk: the next attempt resumes from where it stopped.
            emit failed(m_episodeId, QStringLiteral("download interrupted"));
            return;
        }

        // Asked for a byte range but got the whole file back: what we appended is garbage.
        // A server that ignores Range answers 200 with the complete body, and appending that
        // to a half-finished .part produces a file that plays as noise halfway through.
        if (m_resumeFrom > 0 && status != 206) {
            QFile::remove(m_partPath);
            emit failed(m_episodeId,
                        QStringLiteral("server ignored the resume request; will restart"));
            return;
        }

        QFile::remove(m_destPath); // rename fails if the destination already exists
        if (!QFile::rename(m_partPath, m_destPath)) {
            emit failed(m_episodeId, QStringLiteral("could not finalise the downloaded file"));
            return;
        }
        emit finished(m_episodeId, m_destPath);
    });
}

void EpisodeDownloader::cancel()
{
    if (m_reply)
        m_reply->abort(); // the .part stays, so cancelling is not the same as losing progress
}
