#include <QtTest/QtTest>
#include <QProcess>
#include <QSignalSpy>
#include <QTemporaryDir>

#include "audioengine.h"

class TstAudioEngine : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;
    QString m_toneA;
    QString m_toneB;

    // Generates a short FLAC with ffmpeg. Returns an empty string when ffmpeg is absent.
    static QString makeTone(const QString &path, int hz, double seconds)
    {
        QProcess p;
        p.start(QStringLiteral("ffmpeg"),
                {QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"),
                 QStringLiteral("error"), QStringLiteral("-f"), QStringLiteral("lavfi"),
                 QStringLiteral("-i"),
                 QStringLiteral("sine=%1:d=%2").arg(hz).arg(seconds),
                 QStringLiteral("-y"), path});
        if (!p.waitForStarted(3000))
            return {};
        p.waitForFinished(15000);
        return (p.exitCode() == 0 && QFile::exists(path)) ? path : QString();
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        m_toneA = makeTone(m_dir.filePath(QStringLiteral("a.flac")), 440, 1.0);
        m_toneB = makeTone(m_dir.filePath(QStringLiteral("b.flac")), 660, 1.0);
        if (m_toneA.isEmpty() || m_toneB.isEmpty())
            QSKIP("ffmpeg unavailable: cannot generate audio fixtures");
    }

    void engineInitialises()
    {
        AudioEngine engine(nullptr, /*headlessAo=*/true);
        QVERIFY2(engine.isAvailable(), "mpv_create/mpv_initialize failed — check LC_NUMERIC");
    }

    void playsAndReportsDuration()
    {
        AudioEngine engine(nullptr, /*headlessAo=*/true);
        QVERIFY(engine.isAvailable());

        QSignalSpy durationSpy(&engine, &AudioEngine::durationChanged);
        QSignalSpy positionSpy(&engine, &AudioEngine::positionChanged);

        engine.loadPlaylist({m_toneA});
        QVERIFY2(durationSpy.wait(10000), "duration never reported");
        QVERIFY(engine.duration() > 0.5);
        QVERIFY2(positionSpy.wait(10000), "position never advanced");
    }

    void advancesToNextEntryOnItsOwn()
    {
        AudioEngine engine(nullptr, /*headlessAo=*/true);
        QVERIFY(engine.isAvailable());

        QSignalSpy fileSpy(&engine, &AudioEngine::currentFileChanged);
        engine.loadPlaylist({m_toneA, m_toneB});

        // The second entry must start with no C++ call in between: that is what proves the
        // playlist is internal to mpv, the precondition for gapless.
        QTRY_VERIFY_WITH_TIMEOUT(engine.currentFile().endsWith(QStringLiteral("b.flac")), 20000);
        QVERIFY(fileSpy.count() >= 2);
    }

    void pauseTogglesPlayingState()
    {
        AudioEngine engine(nullptr, /*headlessAo=*/true);
        QVERIFY(engine.isAvailable());
        engine.loadPlaylist({m_toneA});
        QTRY_VERIFY_WITH_TIMEOUT(engine.playing(), 10000);
        engine.pause();
        QTRY_VERIFY_WITH_TIMEOUT(!engine.playing(), 5000);
        engine.play();
        QTRY_VERIFY_WITH_TIMEOUT(engine.playing(), 5000);
    }

    void speedIsClamped()
    {
        AudioEngine engine(nullptr, /*headlessAo=*/true);
        QVERIFY(engine.isAvailable());
        engine.setSpeed(99.0);
        QCOMPARE(engine.speed(), 4.0);
        engine.setSpeed(0.01);
        QCOMPARE(engine.speed(), 0.25);
    }
};

QTEST_MAIN(TstAudioEngine)
#include "tst_audioengine.moc"
