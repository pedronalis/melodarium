#include <QtTest/QtTest>
#include <QBuffer>

#include "podcastfeedfetcher.h"

// The XML fixtures below are escaped string literals, NOT R"(raw strings)", and that is not a
// style choice. moc 6.10.3 mis-lexes a raw string that contains "//" after an inner quote —
// exactly what every enclosure URL looks like — and silently emits an EMPTY .moc file. The
// build then fails at link time with "undefined reference to vtable", pointing nowhere near
// the real cause. Measured on this machine, 2026-08-27.

class TstFeedParser : public QObject
{
    Q_OBJECT

private:
    static bool parseString(const QByteArray &xml, ParsedChannel *channel,
                            QList<ParsedEpisode> *episodes, QString *error = nullptr)
    {
        QBuffer buffer;
        buffer.setData(xml);
        buffer.open(QIODevice::ReadOnly);
        QString err;
        const bool ok = PodcastFeedFetcher::parse(&buffer, channel, episodes, &err);
        if (error)
            *error = err;
        return ok;
    }

private slots:
    void parsesAWellFormedFeed()
    {
        const QByteArray xml =
            "<?xml version=\"1.0\"?>\n"
            "<rss version=\"2.0\" xmlns:itunes=\"http://www.itunes.com/dtds/podcast-1.0.dtd\">\n"
            "<channel>\n"
            "  <title>Programa Bom</title>\n"
            "  <itunes:image href=\"https://ex.com/capa.jpg\"/>\n"
            "  <item>\n"
            "    <title>Episódio Um</title>\n"
            "    <guid isPermaLink=\"false\">ep-001</guid>\n"
            "    <pubDate>Mon, 06 Sep 2021 04:00:00 -0000</pubDate>\n"
            "    <enclosure url=\"https://ex.com/1.mp3\" length=\"12345\" type=\"audio/mpeg\"/>\n"
            "    <itunes:duration>30:34</itunes:duration>\n"
            "  </item>\n"
            "</channel></rss>";

        ParsedChannel channel;
        QList<ParsedEpisode> episodes;
        QVERIFY(parseString(xml, &channel, &episodes));
        QCOMPARE(channel.title, QStringLiteral("Programa Bom"));
        QCOMPARE(channel.imageUrl.toString(), QStringLiteral("https://ex.com/capa.jpg"));
        QCOMPARE(episodes.size(), 1);
        QCOMPARE(episodes.first().guid, QStringLiteral("ep-001"));
        QCOMPARE(episodes.first().title, QStringLiteral("Episódio Um"));
        QCOMPARE(episodes.first().durationSeconds, 30 * 60 + 34);
        QVERIFY(episodes.first().publishedAt.isValid());
    }

    void durationAcceptsAllThreeShapes()
    {
        QCOMPARE(PodcastFeedFetcher::parseItunesDuration(QStringLiteral("1834")), 1834);
        QCOMPARE(PodcastFeedFetcher::parseItunesDuration(QStringLiteral("30:34")), 1834);
        QCOMPARE(PodcastFeedFetcher::parseItunesDuration(QStringLiteral("1:30:34")), 5434);
        QCOMPARE(PodcastFeedFetcher::parseItunesDuration(QString()), 0);
    }

    void malformedPubDateFallsBackInsteadOfFailing()
    {
        const QDateTime fallback = QDateTime::fromSecsSinceEpoch(1000);
        // ISO instead of RFC822 — invalid for the RFC parser, still recoverable.
        QVERIFY(PodcastFeedFetcher::parsePubDate(QStringLiteral("2021-09-06"), fallback).isValid());
        // Pure garbage falls back to the time of fetch rather than losing the episode.
        QCOMPARE(PodcastFeedFetcher::parsePubDate(QStringLiteral("ontem à noite"), fallback),
                 fallback);
        // Single-digit day and hour are still valid RFC822.
        QVERIFY(PodcastFeedFetcher::parsePubDate(QStringLiteral("Mon, 6 Sep 2021 4:00:00 GMT"),
                                                 fallback)
                    .isValid());
    }

    void itemWithoutEnclosureIsSkipped()
    {
        const QByteArray xml =
            "<?xml version=\"1.0\"?>\n"
            "<rss version=\"2.0\"><channel><title>P</title>\n"
            "  <item><title>Só um aviso</title><guid>a1</guid></item>\n"
            "  <item><title>Com áudio</title><guid>a2</guid>\n"
            "    <enclosure url=\"https://ex.com/2.mp3\" type=\"audio/mpeg\"/></item>\n"
            "</channel></rss>";

        ParsedChannel channel;
        QList<ParsedEpisode> episodes;
        QVERIFY(parseString(xml, &channel, &episodes));
        QCOMPARE(episodes.size(), 1);
        QCOMPARE(episodes.first().guid, QStringLiteral("a2"));
    }

    void missingGuidGetsAStableSyntheticIdentity()
    {
        const QByteArray xml =
            "<?xml version=\"1.0\"?>\n"
            "<rss version=\"2.0\"><channel><title>P</title>\n"
            "  <item><title>Reprise</title>\n"
            "    <pubDate>Mon, 06 Sep 2021 04:00:00 -0000</pubDate>\n"
            "    <enclosure url=\"https://ex.com/x.mp3\" type=\"audio/mpeg\"/></item>\n"
            "</channel></rss>";

        ParsedChannel c1, c2;
        QList<ParsedEpisode> e1, e2;
        QVERIFY(parseString(xml, &c1, &e1));
        QVERIFY(parseString(xml, &c2, &e2));
        QCOMPARE(e1.size(), 1);
        QVERIFY(!e1.first().guid.isEmpty());
        // Same feed parsed twice must yield the same identity, or every check re-inserts it.
        QCOMPARE(e1.first().guid, e2.first().guid);
    }

    void missingEnclosureLengthIsZeroNotAnError()
    {
        const QByteArray xml =
            "<?xml version=\"1.0\"?>\n"
            "<rss version=\"2.0\"><channel><title>P</title>\n"
            "  <item><title>T</title><guid>g</guid>\n"
            "    <enclosure url=\"https://ex.com/y.mp3\" type=\"audio/mpeg\"/></item>\n"
            "</channel></rss>";

        ParsedChannel channel;
        QList<ParsedEpisode> episodes;
        QVERIFY(parseString(xml, &channel, &episodes));
        QCOMPARE(episodes.first().enclosureLength, 0);
    }

    void contentEncodedWinsOverDescription()
    {
        const QByteArray xml =
            "<?xml version=\"1.0\"?>\n"
            "<rss version=\"2.0\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\">\n"
            "<channel><title>P</title>\n"
            "  <item><title>T</title><guid>g</guid>\n"
            "    <description>curta</description>\n"
            "    <content:encoded>versão completa</content:encoded>\n"
            "    <enclosure url=\"https://ex.com/z.mp3\" type=\"audio/mpeg\"/></item>\n"
            "</channel></rss>";

        ParsedChannel channel;
        QList<ParsedEpisode> episodes;
        QVERIFY(parseString(xml, &channel, &episodes));
        QCOMPARE(episodes.first().description, QStringLiteral("versão completa"));
    }

    void brokenXmlReportsAnErrorInsteadOfCrashing()
    {
        ParsedChannel channel;
        QList<ParsedEpisode> episodes;
        QString error;
        QVERIFY(!parseString("<rss><channel><item>sem fechar", &channel, &episodes, &error));
        QVERIFY(!error.isEmpty());
    }

    void largeFeedParsesWithoutBlowingUp()
    {
        QByteArray xml =
            "<?xml version=\"1.0\"?><rss version=\"2.0\"><channel><title>P</title>";
        for (int i = 0; i < 500; ++i) {
            xml += QStringLiteral("<item><title>E%1</title><guid>g%1</guid>"
                                  "<enclosure url=\"https://ex.com/%1.mp3\" type=\"audio/mpeg\"/>"
                                  "</item>")
                       .arg(i)
                       .toUtf8();
        }
        xml += "</channel></rss>";

        ParsedChannel channel;
        QList<ParsedEpisode> episodes;
        QVERIFY(parseString(xml, &channel, &episodes));
        QCOMPARE(episodes.size(), 500);
    }
};

QTEST_MAIN(TstFeedParser)
#include "tst_feedparser.moc"
