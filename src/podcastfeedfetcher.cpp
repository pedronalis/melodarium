#include "podcastfeedfetcher.h"

#include <QCryptographicHash>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QXmlStreamReader>

#include <chrono>

// Parsed with QXmlStreamReader, deliberately NOT with QDomDocument: a DOM holds the entire
// feed in memory at once and 500-episode feeds are ordinary. The incremental reader touches
// one element at a time, so a huge feed costs the same as a small one. If QDomDocument ever
// shows up in this file, the memory profile of a feed check changed with it.

int PodcastFeedFetcher::parseItunesDuration(const QString &raw)
{
    if (raw.trimmed().isEmpty())
        return 0;
    // Three shapes in the wild: "1834", "30:34", "1:30:34".
    const QStringList parts = raw.trimmed().split(QLatin1Char(':'));
    int seconds = 0;
    for (const QString &p : parts)
        seconds = seconds * 60 + p.toInt();
    return seconds;
}

QDateTime PodcastFeedFetcher::parsePubDate(const QString &raw, const QDateTime &fallback)
{
    // Qt::RFC2822Date also tolerates the older RFC850/RFC1036 shapes during parsing.
    QDateTime dt = QDateTime::fromString(raw.trimmed(), Qt::RFC2822Date);
    if (!dt.isValid())
        dt = QDateTime::fromString(raw.trimmed(), Qt::ISODate);
    return dt.isValid() ? dt : fallback;
}

bool PodcastFeedFetcher::parse(QIODevice *device, ParsedChannel *channelOut,
                               QList<ParsedEpisode> *episodesOut, QString *errorOut)
{
    QXmlStreamReader xml(device);

    ParsedChannel channel;
    QList<ParsedEpisode> episodes;

    bool inItem = false;
    ParsedEpisode current;
    const QDateTime fetchTime = QDateTime::currentDateTime();

    while (!xml.atEnd()) {
        const auto token = xml.readNext();

        if (token == QXmlStreamReader::StartElement) {
            const QString name = xml.qualifiedName().toString();

            if (name == QLatin1String("item")) {
                inItem = true;
                current = ParsedEpisode();
                continue;
            }

            if (inItem) {
                if (name == QLatin1String("title")) {
                    current.title = xml.readElementText().trimmed();
                } else if (name == QLatin1String("guid")) {
                    current.guid = xml.readElementText().trimmed();
                } else if (name == QLatin1String("pubDate")) {
                    current.publishedAt = parsePubDate(xml.readElementText(), fetchTime);
                } else if (name == QLatin1String("enclosure")) {
                    const auto attrs = xml.attributes();
                    current.enclosureUrl = QUrl(attrs.value(QLatin1String("url")).toString());
                    // The declared length is frequently 0 or missing: it is an estimate for
                    // the progress bar, never a buffer size.
                    current.enclosureLength =
                        attrs.value(QLatin1String("length")).toString().toLongLong();
                } else if (name == QLatin1String("itunes:duration")) {
                    current.durationSeconds = parseItunesDuration(xml.readElementText());
                } else if (name == QLatin1String("description")
                           && current.description.isEmpty()) {
                    current.description = xml.readElementText();
                } else if (name == QLatin1String("content:encoded")) {
                    current.description = xml.readElementText(); // richer, wins over description
                }
            } else {
                if (name == QLatin1String("title") && channel.title.isEmpty()) {
                    channel.title = xml.readElementText().trimmed();
                } else if (name == QLatin1String("itunes:image")) {
                    channel.imageUrl =
                        QUrl(xml.attributes().value(QLatin1String("href")).toString());
                } else if (name == QLatin1String("itunes:author")) {
                    channel.author = xml.readElementText().trimmed();
                } else if (name == QLatin1String("url") && channel.imageUrl.isEmpty()) {
                    channel.imageUrl = QUrl(xml.readElementText().trimmed());
                }
            }
        } else if (token == QXmlStreamReader::EndElement
                   && xml.qualifiedName() == QLatin1String("item")) {
            inItem = false;
            if (current.enclosureUrl.isEmpty())
                continue; // no audio: a text-only item is not a playable episode

            if (current.guid.isEmpty()) {
                // Never fall back to the title alone — reruns and "best of" repeat titles.
                const QByteArray seed = current.enclosureUrl.toString().toUtf8()
                                        + current.publishedAt.toString(Qt::ISODate).toUtf8();
                current.guid = QString::fromLatin1(
                    QCryptographicHash::hash(seed, QCryptographicHash::Sha1).toHex());
            }
            episodes.append(current);
        }
    }

    if (xml.hasError()) {
        if (errorOut)
            *errorOut = xml.errorString();
        return false;
    }

    if (channelOut)
        *channelOut = channel;
    if (episodesOut)
        *episodesOut = episodes;
    return true;
}

PodcastFeedFetcher::PodcastFeedFetcher(QObject *parent)
    : QObject(parent), m_nam(new QNetworkAccessManager(this))
{
    // The signals carry the parsed structs, so the metatypes have to exist before the first
    // queued connection is made.
    qRegisterMetaType<ParsedEpisode>("ParsedEpisode");
    qRegisterMetaType<ParsedChannel>("ParsedChannel");
    qRegisterMetaType<QList<ParsedEpisode>>("QList<ParsedEpisode>");
}

void PodcastFeedFetcher::fetch(const QUrl &feedUrl, const QByteArray &etag,
                               const QByteArray &lastModified)
{
    QNetworkRequest req(feedUrl);
    // QNetworkAccessManager does not follow redirects on its own; "no less safe" allows
    // http->http and https->https but blocks an https->http downgrade.
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setTransferTimeout(std::chrono::milliseconds(15000));
    if (!etag.isEmpty())
        req.setRawHeader("If-None-Match", etag);
    if (!lastModified.isEmpty())
        req.setRawHeader("If-Modified-Since", lastModified);

    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        const int status =
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 304) {
            emit notModified(); // server says nothing changed: nothing to parse
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            emit fetchFailed(reply->errorString()); // offline, DNS, TLS, timeout: all land here
            return;
        }

        ParsedChannel channel;
        QList<ParsedEpisode> episodes;
        QString error;
        if (!parse(reply, &channel, &episodes, &error)) {
            emit fetchFailed(error);
            return;
        }
        emit feedParsed(channel, episodes, reply->rawHeader("ETag"),
                        reply->rawHeader("Last-Modified"));
    });
}
