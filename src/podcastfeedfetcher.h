#pragma once

#include <QByteArray>
#include <QDateTime>
#include <QIODevice>
#include <QList>
#include <QMetaType>
#include <QNetworkAccessManager>
#include <QObject>
#include <QString>
#include <QUrl>

struct ParsedEpisode {
    QString guid;          // <guid>, or hash(enclosureUrl + pubDate) when absent
    QString title;
    QUrl    enclosureUrl;
    qint64  enclosureLength = 0;   // server-declared bytes; 0 or absent is common
    int     durationSeconds = 0;
    QDateTime publishedAt;
    QString description;
};

struct ParsedChannel {
    QString title;
    QUrl    imageUrl;
    QString author;
};

Q_DECLARE_METATYPE(ParsedEpisode)
Q_DECLARE_METATYPE(ParsedChannel)

class PodcastFeedFetcher : public QObject
{
    Q_OBJECT

public:
    explicit PodcastFeedFetcher(QObject *parent = nullptr);

    void fetch(const QUrl &feedUrl, const QByteArray &etag, const QByteArray &lastModified);

    // Pure function, no network: the whole parser is testable from a byte array.
    static bool parse(QIODevice *device, ParsedChannel *channelOut,
                      QList<ParsedEpisode> *episodesOut, QString *errorOut);
    static int parseItunesDuration(const QString &raw);   // "1834" | "30:34" | "1:30:34"
    static QDateTime parsePubDate(const QString &raw, const QDateTime &fallback);

signals:
    void feedParsed(const ParsedChannel &channel, const QList<ParsedEpisode> &episodes,
                    const QByteArray &etag, const QByteArray &lastModified);
    void notModified();
    void fetchFailed(const QString &reason);

private:
    QNetworkAccessManager *m_nam = nullptr;
};
