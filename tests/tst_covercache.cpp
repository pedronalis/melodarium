#include <QtTest/QtTest>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QImage>
#include <QSignalSpy>
#include <QTemporaryDir>

#include "covercache.h"

class TstCoverCache : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;

    void createTrackWithSiblingCover(const QString &folder, const QColor &color, QString *out)
    {
        const QString directory = m_dir.filePath(folder);
        QVERIFY(QDir().mkpath(directory));
        const QString track = directory + QStringLiteral("/track.mp3");
        QFile audio(track);
        QVERIFY(audio.open(QIODevice::WriteOnly));
        audio.write("not audio; the sibling artwork is the fixture");
        audio.close();

        QImage cover(48, 48, QImage::Format_RGB32);
        cover.fill(color);
        QVERIFY(cover.save(directory + QStringLiteral("/cover.png")));
        *out = track;
    }

    void waitForCover(CoverCache &cache, const QString &track, int previousSignals,
                      QSignalSpy &revisionSpy, QString *out)
    {
        QTRY_VERIFY_WITH_TIMEOUT(revisionSpy.count() > previousSignals, 5000);
        const QString result = cache.coverUrlForTrack(track, 1);
        QVERIFY2(!result.isEmpty(), "cover resolution completed without a URL");
        *out = result;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        qputenv("XDG_CACHE_HOME", m_dir.filePath(QStringLiteral("cache")).toUtf8());
    }

    void resolutionReturnsBeforeFilesystemWorkCompletes()
    {
        QString track;
        createTrackWithSiblingCover(QStringLiteral("async"), Qt::red, &track);
        CoverCache cache;
        QSignalSpy revisionSpy(&cache, SIGNAL(revisionChanged()));

        QElapsedTimer elapsed;
        elapsed.start();
        const QString immediate = cache.coverUrlForTrack(track, 1);

        QVERIFY(immediate.isEmpty());
        QVERIFY(revisionSpy.isValid());
        QVERIFY2(elapsed.elapsed() < 50, "cover lookup blocked the caller");
        QString resolved;
        waitForCover(cache, track, 0, revisionSpy, &resolved);
        QVERIFY(!resolved.isEmpty());
    }

    void identicalArtworkSharesOneBlob()
    {
        QString first;
        QString second;
        createTrackWithSiblingCover(QStringLiteral("same-a"), Qt::green, &first);
        createTrackWithSiblingCover(QStringLiteral("same-b"), Qt::green, &second);
        CoverCache cache;
        QSignalSpy revisionSpy(&cache, SIGNAL(revisionChanged()));
        QVERIFY(revisionSpy.isValid());

        QVERIFY(cache.coverUrlForTrack(first, 2).isEmpty());
        QVERIFY(cache.coverUrlForTrack(second, 2).isEmpty());
        QString firstUrl;
        QString secondUrl;
        waitForCover(cache, first, 0, revisionSpy, &firstUrl);
        waitForCover(cache, second, 1, revisionSpy, &secondUrl);
        QCOMPARE(firstUrl, secondUrl);
    }

    void differentArtworkKeepsItsOwnBlob()
    {
        QString first;
        QString second;
        createTrackWithSiblingCover(QStringLiteral("unique-a"), Qt::blue, &first);
        createTrackWithSiblingCover(QStringLiteral("unique-b"), Qt::yellow, &second);
        CoverCache cache;
        QSignalSpy revisionSpy(&cache, SIGNAL(revisionChanged()));
        QVERIFY(revisionSpy.isValid());

        QVERIFY(cache.coverUrlForTrack(first, 3).isEmpty());
        QVERIFY(cache.coverUrlForTrack(second, 3).isEmpty());
        QString firstUrl;
        QString secondUrl;
        waitForCover(cache, first, 0, revisionSpy, &firstUrl);
        waitForCover(cache, second, 1, revisionSpy, &secondUrl);
        QVERIFY(firstUrl != secondUrl);
    }

    void missingArtworkIsNegativeCached()
    {
        const QString directory = m_dir.filePath(QStringLiteral("missing"));
        QVERIFY(QDir().mkpath(directory));
        const QString track = directory + QStringLiteral("/track.mp3");
        QFile audio(track);
        QVERIFY(audio.open(QIODevice::WriteOnly));
        audio.write("no tags and no sibling cover");
        audio.close();

        CoverCache cache;
        QSignalSpy revisionSpy(&cache, SIGNAL(revisionChanged()));
        QVERIFY(revisionSpy.isValid());
        QVERIFY(cache.coverUrlForTrack(track, 4).isEmpty());
        QTRY_COMPARE_WITH_TIMEOUT(revisionSpy.count(), 1, 5000);
        QVERIFY(cache.coverUrlForTrack(track, 4).isEmpty());
        QTest::qWait(100);
        QCOMPARE(revisionSpy.count(), 1);
    }
};

QTEST_MAIN(TstCoverCache)
#include "tst_covercache.moc"
