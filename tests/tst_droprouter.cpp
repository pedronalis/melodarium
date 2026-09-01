#include <QtTest/QtTest>

#include <QFile>
#include <QTemporaryDir>

#include "droprouter.h"

class TstDropRouter : public QObject
{
    Q_OBJECT

private slots:
    void supportedLocalOccurrencesAreQueued()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString flac = dir.filePath(QStringLiteral("one.FLAC"));
        const QString opus = dir.filePath(QStringLiteral("two.opus"));
        QVERIFY(QFile(flac).open(QIODevice::WriteOnly));
        QVERIFY(QFile(opus).open(QIODevice::WriteOnly));

        const auto decision = DropRouting::classify(
            {QUrl::fromLocalFile(flac), QUrl::fromLocalFile(opus),
             QUrl::fromLocalFile(flac)});
        QCOMPARE(decision.action, DropRouting::Action::QueueFiles);
        QCOMPARE(decision.paths, QStringList({flac, opus, flac}));
    }

    void unsupportedOrMixedLocalFilesAreRejected()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString audio = dir.filePath(QStringLiteral("track.mp3"));
        const QString text = dir.filePath(QStringLiteral("notes.txt"));
        QVERIFY(QFile(audio).open(QIODevice::WriteOnly));
        QVERIFY(QFile(text).open(QIODevice::WriteOnly));

        QCOMPARE(DropRouting::classify({QUrl::fromLocalFile(text)}).action,
                 DropRouting::Action::Reject);
        QCOMPARE(DropRouting::classify(
                     {QUrl::fromLocalFile(audio), QUrl::fromLocalFile(text)}).action,
                 DropRouting::Action::Reject);
        QCOMPARE(DropRouting::classify(
                     {QUrl::fromLocalFile(dir.filePath(QStringLiteral("missing.flac")))}).action,
                 DropRouting::Action::Reject);
    }

    void oneDirectoryRoutesToTheLibraryScanner()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());

        const auto decision = DropRouting::classify({QUrl::fromLocalFile(dir.path())});
        QCOMPARE(decision.action, DropRouting::Action::ScanFolder);
        QCOMPARE(decision.paths, QStringList({dir.path()}));
        QCOMPARE(DropRouting::classify(
                     {QUrl::fromLocalFile(dir.path()), QUrl::fromLocalFile(dir.path())}).action,
                 DropRouting::Action::Reject);
    }

    void httpUrlsSeparateMediaFeedsAndYoutube()
    {
        QCOMPARE(DropRouting::classify(
                     {QUrl(QStringLiteral("https://cdn.example.test/episode.ogg?token=1"))}).action,
                 DropRouting::Action::QueueStream);
        QCOMPARE(DropRouting::classify(
                     {QUrl(QStringLiteral("https://example.test/show/feed.xml"))}).action,
                 DropRouting::Action::SubscribeFeed);
        QCOMPARE(DropRouting::classify(
                     {QUrl(QStringLiteral("https://example.test/podcast"))}).action,
                 DropRouting::Action::SubscribeFeed);
        QCOMPARE(DropRouting::classify(
                     {QUrl(QStringLiteral("https://youtu.be/abc123"))}).action,
                 DropRouting::Action::ConfirmYoutube);
        QCOMPARE(DropRouting::classify(
                     {QUrl(QStringLiteral("https://www.youtube.com/watch?v=abc123"))}).action,
                 DropRouting::Action::ConfirmYoutube);
        QVERIFY(DropRouting::classify(
                    {QUrl(QStringLiteral("https://youtube.com.evil.test/watch?v=abc"))}).action
                != DropRouting::Action::ConfirmYoutube);
    }

    void unsafeUnknownAndAmbiguousUrlsAreRejected()
    {
        const QStringList urls = {
            QStringLiteral("javascript:alert(1)"), QStringLiteral("data:audio/mp3;base64,AAAA"),
            QStringLiteral("ftp://example.test/song.flac"), QStringLiteral("relative.flac")};
        for (const QString &url : urls)
            QCOMPARE(DropRouting::classify({QUrl(url)}).action, DropRouting::Action::Reject);

        QCOMPARE(DropRouting::classify(
                     {QUrl(QStringLiteral("https://example.test/feed.xml")),
                      QUrl(QStringLiteral("https://example.test/other.xml"))}).action,
                 DropRouting::Action::Reject);
        QCOMPARE(DropRouting::classify({}).action, DropRouting::Action::Reject);
    }

    void qmlFacingMapUsesStableActionNames()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString audio = dir.filePath(QStringLiteral("track.wav"));
        QVERIFY(QFile(audio).open(QIODevice::WriteOnly));

        DropRouter router;
        const QVariantMap result = router.classify(
            {QVariant::fromValue(QUrl::fromLocalFile(audio))});
        QCOMPARE(result.value(QStringLiteral("action")).toString(),
                 QStringLiteral("queue-files"));
        QCOMPARE(result.value(QStringLiteral("accepted")).toBool(), true);
        QCOMPARE(result.value(QStringLiteral("paths")).toStringList(), QStringList({audio}));
    }
};

QTEST_MAIN(TstDropRouter)
#include "tst_droprouter.moc"
