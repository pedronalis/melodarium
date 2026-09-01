#include <QtTest>

#include <QBuffer>
#include <QFile>
#include <QSignalSpy>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "database.h"
#include "portabilityservice.h"

namespace {

QByteArray namespacedFixture()
{
    return QByteArrayLiteral("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                             "<op:opml xmlns:op=\"urn:opml\" version=\"2.0\"><op:body>\n"
                             "<op:outline text=\"Existing\" xmlUrl=\"https://existing.test/feed.xml\"/>\n"
                             "<op:outline text=\"Novo Áudio\" xmlUrl=\"https://new.test/feed.xml\"/>\n"
                             "<op:outline text=\"Repetido\" xmlUrl=\"https://new.test/feed.xml\"/>\n"
                             "<op:outline text=\"Inválido\" xmlUrl=\"ftp://invalid.test/feed.xml\"/>\n"
                             "<op:outline text=\"Sem URL\"/>\n"
                             "</op:body></op:opml>");
}

} // namespace

class TstPortability : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"),
                                         QLatin1String(Database::kUiConnection));
        m_db.setDatabaseName(QStringLiteral(":memory:"));
        QVERIFY(m_db.open());
        QSqlQuery q(m_db);
        QVERIFY(q.exec(QStringLiteral(
            "CREATE TABLE podcast_shows (id INTEGER PRIMARY KEY, title TEXT, feed_url TEXT UNIQUE)")));
        QVERIFY(q.exec(QStringLiteral(
            "INSERT INTO podcast_shows (title,feed_url) VALUES "
            "('Existing','https://existing.test/feed.xml')")));
        QVERIFY(m_dir.isValid());
    }

    void cleanupTestCase()
    {
        m_db.close();
        m_db = {};
        QSqlDatabase::removeDatabase(QLatin1String(Database::kUiConnection));
    }

    void parserHandlesNamespacesDuplicatesAndInvalidUrls()
    {
        QBuffer input;
        input.setData(namespacedFixture());
        QVERIFY(input.open(QIODevice::ReadOnly));

        const Portability::OpmlParseResult parsed = Portability::parseOpml(&input);
        QVERIFY2(parsed.error.isEmpty(), qPrintable(parsed.error));
        QCOMPARE(parsed.subscriptions.size(), 2);
        QCOMPARE(parsed.subscriptions.at(1).title, QStringLiteral("Novo Áudio"));
        QCOMPARE(parsed.duplicateCount, 1);
        QCOMPARE(parsed.invalidCount, 2);
    }

    void malformedXmlIsAtomic()
    {
        QBuffer input;
        input.setData("<opml><body><outline xmlUrl='https://ok.test/feed.xml'></body>");
        QVERIFY(input.open(QIODevice::ReadOnly));

        const Portability::OpmlParseResult parsed = Portability::parseOpml(&input);
        QVERIFY(!parsed.error.isEmpty());
        QVERIFY(parsed.subscriptions.isEmpty());
    }

    void opmlRoundTripIsUtf8AndDeterministic()
    {
        QList<Portability::OpmlSubscription> source = {
            {QStringLiteral("Zeta"), QUrl(QStringLiteral("https://z.test/feed.xml"))},
            {QStringLiteral("Áudio Aberto"), QUrl(QStringLiteral("https://a.test/feed.xml"))},
        };
        QBuffer output;
        QVERIFY(output.open(QIODevice::ReadWrite));
        QString error;
        QVERIFY2(Portability::writeOpml(&output, source, &error), qPrintable(error));
        QVERIFY(output.data().contains(QString::fromUtf8("Áudio Aberto").toUtf8()));

        output.seek(0);
        const Portability::OpmlParseResult parsed = Portability::parseOpml(&output);
        QVERIFY2(parsed.error.isEmpty(), qPrintable(parsed.error));
        QCOMPARE(parsed.subscriptions.size(), 2);
        QCOMPARE(parsed.subscriptions.at(0).title, QStringLiteral("Áudio Aberto"));
        QCOMPARE(parsed.subscriptions.at(1).title, QStringLiteral("Zeta"));
    }

    void importReturnsSummaryAndRequestsOnlyNewSubscriptions()
    {
        const QString path = m_dir.filePath(QStringLiteral("subscriptions.opml"));
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(file.write(namespacedFixture()), namespacedFixture().size());
        file.close();

        PortabilityService service;
        QSignalSpy requested(&service, &PortabilityService::subscriptionRequested);
        const QVariantMap summary = service.importOpml(QUrl::fromLocalFile(path));
        QCOMPARE(summary.value(QStringLiteral("imported")).toInt(), 1);
        QCOMPARE(summary.value(QStringLiteral("duplicates")).toInt(), 2);
        QCOMPARE(summary.value(QStringLiteral("failed")).toInt(), 2);
        QCOMPARE(summary.value(QStringLiteral("error")).toString(), QString());
        QCOMPARE(requested.count(), 1);
        QCOMPARE(requested.first().first().toUrl(),
                 QUrl(QStringLiteral("https://new.test/feed.xml")));
    }

private:
    QSqlDatabase m_db;
    QTemporaryDir m_dir;
};

QTEST_MAIN(TstPortability)
#include "tst_portability.moc"
