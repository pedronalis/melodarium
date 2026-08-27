#pragma once

#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QtQmlIntegration/qqmlintegration.h>

class QProcess;

class YtDlpDownloader : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool available READ available NOTIFY availabilityChanged)
    Q_PROPERTY(QString toolVersion READ toolVersion NOTIFY availabilityChanged)

public:
    explicit YtDlpDownloader(QObject *parent = nullptr);

    bool available() const { return m_available; }
    QString toolVersion() const { return m_toolVersion; }

    Q_INVOKABLE void probe();                     // fills available/toolVersion
    Q_INVOKABLE void fetchInfo(const QUrl &url);  // metadata only, no download
    Q_INVOKABLE void download(const QUrl &url, int collectionId);
    Q_INVOKABLE void cancel(const QUrl &url);
    Q_INVOKABLE QString downloadDirectory() const; // AppDataLocation + "/youtube"

    static QStringList buildArguments(const QUrl &url, const QString &destDir,
                                      const QString &ffmpegLocation);
    static bool parseProgressLine(const QString &line, qint64 *downloaded, qint64 *total);
    static QString findFfmpeg();                  // "" when ffmpeg is on PATH already

signals:
    void availabilityChanged();
    void infoReady(const QUrl &url, const QString &title, const QString &channel,
                   int durationSeconds, const QString &thumbnailUrl);
    void infoFailed(const QUrl &url, const QString &reason);
    void progress(const QUrl &url, qint64 downloaded, qint64 total);
    void finished(const QUrl &url, int trackId);
    void failed(const QUrl &url, const QString &reason);

private:
    bool m_available = false;
    QString m_toolVersion;
    QHash<QString, QProcess *> m_jobs;
    QHash<QString, int> m_collectionForUrl;
    QHash<QString, QString> m_lastDestination;
};
