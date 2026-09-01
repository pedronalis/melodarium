#include <QtTest>

#include <QBuffer>
#include <QFile>
#include <QSignalSpy>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSettings>
#include <QTemporaryDir>
#include <QUuid>

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

bool writeDatabaseValue(const QString &path, const QString &value)
{
    QFile::remove(path);
    const QString connection = QStringLiteral("bundle-write-")
                               + QUuid::createUuid().toString(QUuid::WithoutBraces);
    bool ok = false;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connection);
        db.setDatabaseName(path);
        if (db.open()) {
            QSqlQuery q(db);
            ok = q.exec(QStringLiteral("CREATE TABLE state (value TEXT)"));
            if (ok) {
                q.prepare(QStringLiteral("INSERT INTO state (value) VALUES (?)"));
                q.addBindValue(value);
                ok = q.exec();
            }
        }
        db.close();
    }
    QSqlDatabase::removeDatabase(connection);
    return ok;
}

QString readDatabaseValue(const QString &path)
{
    const QString connection = QStringLiteral("bundle-read-")
                               + QUuid::createUuid().toString(QUuid::WithoutBraces);
    QString value;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connection);
        db.setDatabaseName(path);
        if (db.open()) {
            QSqlQuery q(db);
            if (q.exec(QStringLiteral("SELECT value FROM state")) && q.next())
                value = q.value(0).toString();
        }
        db.close();
    }
    QSqlDatabase::removeDatabase(connection);
    return value;
}

void writeSettingValue(const QString &path, const QString &value)
{
    QSettings settings(path, QSettings::IniFormat);
    settings.clear();
    settings.setValue(QStringLiteral("fixture/value"), value);
    settings.sync();
}

QString readSettingValue(const QString &path)
{
    return QSettings(path, QSettings::IniFormat)
        .value(QStringLiteral("fixture/value")).toString();
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
            "CREATE TABLE collections (id INTEGER PRIMARY KEY, name TEXT)")));
        QVERIFY(q.exec(QStringLiteral(
            "CREATE TABLE tracks (id INTEGER PRIMARY KEY, path TEXT, removed_at INTEGER)")));
        QVERIFY(q.exec(QStringLiteral(
            "CREATE TABLE collection_tracks (collection_id INTEGER, track_id INTEGER, position INTEGER)")));
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

    void m3uKeepsManualOrderUnicodeAndSkipsDuplicatesAndMissingTracks()
    {
        const QString first = m_dir.filePath(QStringLiteral("01-Coração.flac"));
        const QString second = m_dir.filePath(QStringLiteral("02-Noite.opus"));
        for (const QString &path : {first, second}) {
            QFile file(path);
            QVERIFY(file.open(QIODevice::WriteOnly));
            QCOMPARE(file.write("fixture"), 7);
        }
        const QString missing = m_dir.filePath(QStringLiteral("03-ausente.mp3"));

        QBuffer output;
        QVERIFY(output.open(QIODevice::WriteOnly));
        const Portability::M3uWriteResult result =
            Portability::writeM3u(&output, {second, first, first, missing});
        QVERIFY2(result.error.isEmpty(), qPrintable(result.error));
        QCOMPARE(result.written, 2);
        QCOMPARE(result.skipped, 2);
        QCOMPARE(QString::fromUtf8(output.data()),
                 QStringLiteral("#EXTM3U\n%1\n%2\n").arg(second, first));
    }

    void collectionM3uUsesDatabasePositionAndAtomicFile()
    {
        const QString first = m_dir.filePath(QStringLiteral("manual-Coração.flac"));
        const QString second = m_dir.filePath(QStringLiteral("manual-Noite.opus"));
        for (const QString &path : {first, second}) {
            QFile file(path);
            QVERIFY(file.open(QIODevice::WriteOnly));
            QCOMPARE(file.write("fixture"), 7);
        }
        const QString missing = m_dir.filePath(QStringLiteral("manual-ausente.mp3"));

        QSqlQuery q(m_db);
        QVERIFY(q.exec(QStringLiteral("INSERT INTO collections (id,name) VALUES (7,'Manual')")));
        q.prepare(QStringLiteral("INSERT INTO tracks (id,path) VALUES (?,?)"));
        const QList<QPair<int, QString>> tracks = {{71, first}, {72, second}, {73, missing}};
        for (const auto &[id, path] : tracks) {
            q.bindValue(0, id);
            q.bindValue(1, path);
            QVERIFY(q.exec());
        }
        QVERIFY(q.exec(QStringLiteral(
            "INSERT INTO collection_tracks (collection_id,track_id,position) VALUES "
            "(7,71,2000),(7,72,1000),(7,73,3000)")));

        const QString destination = m_dir.filePath(QStringLiteral("manual.m3u"));
        PortabilityService service;
        const QVariantMap result =
            service.exportCollectionM3u(7, QUrl::fromLocalFile(destination));
        QCOMPARE(result.value(QStringLiteral("error")).toString(), QString());
        QCOMPARE(result.value(QStringLiteral("exported")).toInt(), 2);
        QCOMPARE(result.value(QStringLiteral("skipped")).toInt(), 1);
        QFile exported(destination);
        QVERIFY(exported.open(QIODevice::ReadOnly));
        QCOMPARE(QString::fromUtf8(exported.readAll()),
                 QStringLiteral("#EXTM3U\n%1\n%2\n").arg(second, first));
    }

    void backupRestoreRoundTripsDatabaseAndSettings()
    {
        const QString dbPath = m_dir.filePath(QStringLiteral("roundtrip.db"));
        const QString settingsPath = m_dir.filePath(QStringLiteral("roundtrip.ini"));
        const QString bundlePath = m_dir.filePath(QStringLiteral("roundtrip.melodarium-backup"));
        QVERIFY(writeDatabaseValue(dbPath, QStringLiteral("backup")));
        writeSettingValue(settingsPath, QStringLiteral("backup"));

        const Portability::BundleResult created =
            Portability::createBundle(bundlePath, dbPath, settingsPath);
        QVERIFY2(created.ok, qPrintable(created.error));
        QVERIFY(writeDatabaseValue(dbPath, QStringLiteral("current")));
        writeSettingValue(settingsPath, QStringLiteral("current"));

        const Portability::BundleResult restored =
            Portability::restoreBundle(bundlePath, dbPath, settingsPath);
        QVERIFY2(restored.ok, qPrintable(restored.error));
        QVERIFY(restored.restartRequired);
        QVERIFY(QFileInfo::exists(restored.rollbackBundlePath));
        QCOMPARE(readDatabaseValue(dbPath), QStringLiteral("backup"));
        QCOMPARE(readSettingValue(settingsPath), QStringLiteral("backup"));
    }

    void restoreRejectsInvalidHashBeforeMutation()
    {
        const QString dbPath = m_dir.filePath(QStringLiteral("hash.db"));
        const QString settingsPath = m_dir.filePath(QStringLiteral("hash.ini"));
        const QString bundlePath = m_dir.filePath(QStringLiteral("hash.melodarium-backup"));
        QVERIFY(writeDatabaseValue(dbPath, QStringLiteral("backup")));
        writeSettingValue(settingsPath, QStringLiteral("backup"));
        QVERIFY(Portability::createBundle(bundlePath, dbPath, settingsPath).ok);
        QVERIFY(writeDatabaseValue(dbPath, QStringLiteral("current")));
        writeSettingValue(settingsPath, QStringLiteral("current"));

        QFile bundle(bundlePath);
        QVERIFY(bundle.open(QIODevice::ReadWrite));
        QVERIFY(bundle.seek(bundle.size() - 1));
        const char original = bundle.read(1).at(0);
        QVERIFY(bundle.seek(bundle.size() - 1));
        QCOMPARE(bundle.write(QByteArray(1, original ^ 0x01)), 1);
        bundle.close();

        const Portability::BundleResult result =
            Portability::restoreBundle(bundlePath, dbPath, settingsPath);
        QVERIFY(!result.ok);
        QVERIFY(result.error.contains(QStringLiteral("hash"), Qt::CaseInsensitive));
        QCOMPARE(readDatabaseValue(dbPath), QStringLiteral("current"));
        QCOMPARE(readSettingValue(settingsPath), QStringLiteral("current"));
    }

    void restoreRejectsTruncatedAndFutureBundles()
    {
        const QString dbPath = m_dir.filePath(QStringLiteral("reject.db"));
        const QString settingsPath = m_dir.filePath(QStringLiteral("reject.ini"));
        const QString originalPath = m_dir.filePath(QStringLiteral("reject.melodarium-backup"));
        QVERIFY(writeDatabaseValue(dbPath, QStringLiteral("backup")));
        writeSettingValue(settingsPath, QStringLiteral("backup"));
        QVERIFY(Portability::createBundle(originalPath, dbPath, settingsPath).ok);

        QFile original(originalPath);
        QVERIFY(original.open(QIODevice::ReadOnly));
        const QByteArray bytes = original.readAll();
        original.close();

        const QString truncatedPath = m_dir.filePath(QStringLiteral("truncated.backup"));
        QFile truncated(truncatedPath);
        QVERIFY(truncated.open(QIODevice::WriteOnly));
        QCOMPARE(truncated.write(bytes.left(bytes.size() - 9)), bytes.size() - 9);
        truncated.close();
        QVERIFY(writeDatabaseValue(dbPath, QStringLiteral("current")));
        writeSettingValue(settingsPath, QStringLiteral("current"));
        QVERIFY(!Portability::restoreBundle(truncatedPath, dbPath, settingsPath).ok);
        QCOMPARE(readDatabaseValue(dbPath), QStringLiteral("current"));

        QByteArray futureBytes = bytes;
        const QByteArray versionOne = QByteArrayLiteral("\"version\":1");
        const int versionOffset = futureBytes.indexOf(versionOne);
        QVERIFY(versionOffset >= 0);
        futureBytes[versionOffset + versionOne.size() - 1] = '9';
        const QString futurePath = m_dir.filePath(QStringLiteral("future.backup"));
        QFile future(futurePath);
        QVERIFY(future.open(QIODevice::WriteOnly));
        QCOMPARE(future.write(futureBytes), futureBytes.size());
        future.close();
        const Portability::BundleResult futureResult =
            Portability::restoreBundle(futurePath, dbPath, settingsPath);
        QVERIFY(!futureResult.ok);
        QVERIFY(futureResult.error.contains(QStringLiteral("versão"), Qt::CaseInsensitive));
        QCOMPARE(readDatabaseValue(dbPath), QStringLiteral("current"));
        QCOMPARE(readSettingValue(settingsPath), QStringLiteral("current"));
    }

    void restoreRollsBackWhenSecondSwapFails()
    {
        const QString dbPath = m_dir.filePath(QStringLiteral("rollback.db"));
        const QString settingsPath = m_dir.filePath(QStringLiteral("rollback.ini"));
        const QString bundlePath = m_dir.filePath(QStringLiteral("rollback.melodarium-backup"));
        QVERIFY(writeDatabaseValue(dbPath, QStringLiteral("backup")));
        writeSettingValue(settingsPath, QStringLiteral("backup"));
        QVERIFY(Portability::createBundle(bundlePath, dbPath, settingsPath).ok);
        QVERIFY(writeDatabaseValue(dbPath, QStringLiteral("current")));
        writeSettingValue(settingsPath, QStringLiteral("current"));

        const Portability::BundleResult result =
            Portability::restoreBundle(bundlePath, dbPath, settingsPath, true);
        QVERIFY(!result.ok);
        QVERIFY(QFileInfo::exists(result.rollbackBundlePath));
        QCOMPARE(readDatabaseValue(dbPath), QStringLiteral("current"));
        QCOMPARE(readSettingValue(settingsPath), QStringLiteral("current"));
    }

private:
    QSqlDatabase m_db;
    QTemporaryDir m_dir;
};

QTEST_MAIN(TstPortability)
#include "tst_portability.moc"
