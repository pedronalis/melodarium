#include <QtTest/QtTest>
#include <QElapsedTimer>
#include <QProcess>
#include <QSettings>
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
    QString m_longTone;

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
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, m_dir.path());
        QSettings().clear();
        m_toneA = makeTone(m_dir.filePath(QStringLiteral("a.flac")), 440, 1.0);
        m_toneB = makeTone(m_dir.filePath(QStringLiteral("b.flac")), 660, 1.0);
        m_longTone = makeTone(m_dir.filePath(QStringLiteral("long.flac")), 550, 8.0);
        if (m_toneA.isEmpty() || m_toneB.isEmpty() || m_longTone.isEmpty())
            QSKIP("ffmpeg unavailable: cannot generate audio fixtures");
    }

    void init()
    {
        // Every test gets an isolated playback session. Persistence is tested inside a
        // single test by constructing two engines against this same temporary QSettings.
        QSettings().clear();
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

    void podcastSpeedDoesNotLeakIntoMusicAndSurvivesRestart()
    {
        {
            AudioEngine engine(nullptr, /*headlessAo=*/true);
            QVERIFY(engine.isAvailable());

            // rememberSession=false is the existing podcast load contract. Podcast position
            // belongs to PodcastLibrary and must not replace the saved music queue.
            engine.loadPlaylist({m_toneA}, 0, false);
            engine.setSpeed(1.5);
            QCOMPARE(engine.speed(), 1.5);

            engine.loadPlaylist({m_toneB}, 0, true);
            QCOMPARE(engine.speed(), 1.0);

            engine.loadPlaylist({m_toneA}, 0, false);
            QCOMPARE(engine.speed(), 1.5);
        }

        AudioEngine restored(nullptr, /*headlessAo=*/true);
        QVERIFY(restored.isAvailable());
        restored.loadPlaylist({m_toneA}, 0, false);
        QCOMPARE(restored.speed(), 1.5);
    }

    void volumeSurvivesEngineRestart()
    {
        {
            AudioEngine engine(nullptr, /*headlessAo=*/true);
            QVERIFY(engine.isAvailable());
            engine.setVolume(37.0);
            QCOMPARE(engine.volume(), 37.0);
        }

        AudioEngine restored(nullptr, /*headlessAo=*/true);
        QVERIFY(restored.isAvailable());
        QCOMPARE(restored.volume(), 37.0);
    }

    void audioQualityPreferencesArePersisted()
    {
        AudioEngine engine(nullptr, /*headlessAo=*/true);
        QVERIFY(engine.isAvailable());

        engine.setReplayGainMode(QStringLiteral("album"));
        engine.setGaplessAggressive(true);
        engine.setExclusiveOutput(true);

        QSettings settings;
        settings.sync();
        QCOMPARE(settings.value(QStringLiteral("audio/replayGainMode")).toString(),
                 QStringLiteral("album"));
        QCOMPARE(settings.value(QStringLiteral("audio/gaplessAggressive")).toBool(), true);
        QCOMPARE(settings.value(QStringLiteral("audio/exclusiveOutput")).toBool(), true);
    }

    void sleepTimerCanBeCancelledAndExpiresCleanly()
    {
        AudioEngine engine(nullptr, true);
        QVERIFY(engine.isAvailable());
        engine.loadPlaylist({m_longTone}, 0);
        QTRY_VERIFY_WITH_TIMEOUT(engine.playing(), 5000);

        engine.startSleepTimer(2);
        QCOMPARE(engine.sleepActive(), true);
        QCOMPARE(engine.sleepRemainingSeconds(), 2);
        QTRY_VERIFY_WITH_TIMEOUT(engine.sleepRemainingSeconds() <= 1, 2000);
        engine.cancelSleepTimer();
        QCOMPARE(engine.sleepActive(), false);
        QCOMPARE(engine.sleepRemainingSeconds(), 0);
        QTest::qWait(1200);
        QVERIFY(engine.playing());

        engine.startSleepTimer(1);
        QTRY_VERIFY_WITH_TIMEOUT(!engine.sleepActive(), 3000);
        QTRY_VERIFY_WITH_TIMEOUT(!engine.playing(), 3000);
        QCOMPARE(engine.sleepRemainingSeconds(), 0);
    }

    void stopAfterCurrentFiresOnceOnEof()
    {
        AudioEngine engine(nullptr, true);
        QVERIFY(engine.isAvailable());
        engine.loadPlaylist({m_toneA, m_longTone}, 0);
        QTRY_COMPARE_WITH_TIMEOUT(engine.currentFile(), m_toneA, 5000);

        QSignalSpy finishedSpy(&engine, &AudioEngine::trackFinished);
        QSignalSpy stopAfterSpy(&engine, &AudioEngine::stopAfterCurrentChanged);
        engine.setStopAfterCurrent(true);
        QCOMPARE(engine.stopAfterCurrent(), true);
        QTRY_VERIFY_WITH_TIMEOUT(!engine.stopAfterCurrent(), 5000);
        QTRY_VERIFY_WITH_TIMEOUT(!engine.playing(), 5000);
        QCOMPARE(finishedSpy.count(), 1);
        QCOMPARE(stopAfterSpy.count(), 2);
        QTest::qWait(1200);
        QCOMPARE(finishedSpy.count(), 1);
        QCOMPARE(stopAfterSpy.count(), 2);
    }

    void stopAfterCurrentSurvivesAManualTrackChange()
    {
        AudioEngine engine(nullptr, true);
        QVERIFY(engine.isAvailable());
        engine.loadPlaylist({m_longTone, m_toneA}, 0);
        QTRY_COMPARE_WITH_TIMEOUT(engine.currentFile(), m_longTone, 5000);

        engine.setStopAfterCurrent(true);
        engine.next();
        QTRY_COMPARE_WITH_TIMEOUT(engine.currentFile(), m_toneA, 5000);
        QCOMPARE(engine.stopAfterCurrent(), true);
        QTRY_VERIFY_WITH_TIMEOUT(!engine.stopAfterCurrent(), 5000);
        QTRY_VERIFY_WITH_TIMEOUT(!engine.playing(), 5000);
    }

    void sleepStateDoesNotSurviveEngineRestart()
    {
        {
            AudioEngine engine(nullptr, true);
            QVERIFY(engine.isAvailable());
            engine.startSleepTimer(60);
            engine.setStopAfterCurrent(true);
            QCOMPARE(engine.sleepActive(), true);
            QCOMPARE(engine.stopAfterCurrent(), true);
        }

        AudioEngine restored(nullptr, true);
        QCOMPARE(restored.sleepActive(), false);
        QCOMPARE(restored.sleepRemainingSeconds(), 0);
        QCOMPARE(restored.stopAfterCurrent(), false);
    }

    // A ordem de reprodução existia só dentro do mpv e numa variável de QML que ninguém
    // lia. Sem isto não há como desenhar "o que vem a seguir".
    void queueMirrorsWhatWasLoaded()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        QCOMPARE(engine.queue().size(), 0);
        QCOMPARE(engine.queueCount(), 0);

        QSignalSpy spy(&engine, &AudioEngine::queueChanged);
        engine.loadPlaylist({m_toneA, m_toneB}, 0);

        QCOMPARE(engine.queue(), QStringList({m_toneA, m_toneB}));
        QCOMPARE(engine.queueCount(), 2);
        QCOMPARE(spy.count(), 1);
    }

    void playlistMovePlanPreservesDuplicateOccurrences()
    {
        const QStringList current = {
            QStringLiteral("a"), QStringLiteral("b"), QStringLiteral("a"),
            QStringLiteral("c"), QStringLiteral("b"), QStringLiteral("a")};
        const QStringList target = {
            QStringLiteral("b"), QStringLiteral("a"), QStringLiteral("b"),
            QStringLiteral("a"), QStringLiteral("a"), QStringLiteral("c")};

        const auto plan = AudioQueue::planMoves(current, target);
        QVERIFY(plan.has_value());

        QStringList transformed = current;
        for (const auto &move : *plan)
            transformed.move(move.first, move.second);
        QCOMPARE(transformed, target);
        QVERIFY(plan->size() <= current.size());

        QVERIFY(!AudioQueue::planMoves(current, {QStringLiteral("a")}).has_value());
    }

    void loadsHundredsOfDuplicateEntriesAsOneScalablePlaylist()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        QStringList files;
        files.reserve(500);
        for (int i = 0; i < 500; ++i)
            files.append(i % 2 == 0 ? m_toneA : m_toneB);

        QElapsedTimer timer;
        timer.start();
        engine.loadPlaylist(files, 317);
        const qint64 loadMs = timer.elapsed();
        engine.pause();

        QCOMPARE(engine.queue(), files);
        QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 317, 5000);
        QTRY_COMPARE_WITH_TIMEOUT(engine.currentFile(), files.at(317), 5000);
        QVERIFY2(loadMs < 2000,
                 qPrintable(QStringLiteral("500-entry load took %1 ms").arg(loadMs)));
        qInfo().noquote() << QStringLiteral("AUDIO_PERF load500_ms=%1").arg(loadMs);
    }

    void shufflesHundredsOfDuplicatesWithoutRestartingTheCurrentTrack()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        QStringList files = {m_longTone};
        files.reserve(500);
        for (int i = 1; i < 500; ++i)
            files.append(i % 2 == 0 ? m_toneA : m_toneB);

        engine.loadPlaylist(files, 0);
        engine.play();
        QTRY_VERIFY_WITH_TIMEOUT(engine.position() > 2.0, 10000);
        const QString current = engine.currentFile();
        const double positionBefore = engine.position();

        QElapsedTimer timer;
        timer.start();
        int attempts = 0;
        do {
            engine.setShuffle(false);
            engine.setShuffle(true);
        } while (engine.queue().at(1) == files.at(1) && ++attempts < 30);
        const qint64 shuffleMs = timer.elapsed();

        QVERIFY2(engine.queue().at(1) != files.at(1),
                 "thirty shuffles never changed the next duplicate occurrence");
        QCOMPARE(engine.currentFile(), current);
        QVERIFY2(engine.position() >= positionBefore,
                 qPrintable(QStringLiteral("current track restarted: %1 -> %2")
                            .arg(positionBefore).arg(engine.position())));
        QCOMPARE(engine.queue().count(m_toneA), files.count(m_toneA));
        QCOMPARE(engine.queue().count(m_toneB), files.count(m_toneB));

        const QString expectedNext = engine.queue().at(1);
        engine.pause();
        engine.next();
        QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 1, 5000);
        QTRY_COMPARE_WITH_TIMEOUT(engine.currentFile(), expectedNext, 5000);
        QVERIFY2(shuffleMs < 2000,
                 qPrintable(QStringLiteral("500-entry shuffle took %1 ms").arg(shuffleMs)));
        qInfo().noquote() << QStringLiteral("AUDIO_PERF shuffle500_ms=%1").arg(shuffleMs);
    }

    // Pôr no fim não pode reiniciar o que toca: é o gesto de "depois dessa, essa".
    void appendGrowsTheQueueWithoutReplacingIt()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        engine.loadPlaylist({m_toneA}, 0);
        QSignalSpy spy(&engine, &AudioEngine::queueChanged);
        engine.appendToQueue(m_toneB);

        QCOMPARE(engine.queue(), QStringList({m_toneA, m_toneB}));
        QCOMPARE(spy.count(), 1);
    }

    void playNextInsertsOneDuplicateOccurrenceWithoutRestarting()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        engine.loadPlaylist({m_longTone, m_toneA, m_toneB, m_toneA}, 0);
        QTRY_VERIFY_WITH_TIMEOUT(engine.position() > 1.0, 10000);
        const double positionBefore = engine.position();

        QVERIFY(engine.playNext(m_toneA));
        QCOMPARE(engine.queue(),
                 QStringList({m_longTone, m_toneA, m_toneA, m_toneB, m_toneA}));
        QCOMPARE(engine.currentFile(), m_longTone);
        QCOMPARE(engine.playlistPos(), 0);
        QVERIFY(engine.position() >= positionBefore);
    }

    void removeQueueItemTargetsOneDuplicateAndPreservesCurrentTrack()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        engine.loadPlaylist({m_toneA, m_longTone, m_toneA, m_toneB, m_toneA}, 1);
        QTRY_VERIFY_WITH_TIMEOUT(engine.position() > 1.0, 10000);
        const double positionBefore = engine.position();

        QVERIFY(engine.removeQueueItem(2));
        QCOMPARE(engine.queue(), QStringList({m_toneA, m_longTone, m_toneB, m_toneA}));
        QVERIFY(engine.removeQueueItem(0));
        QCOMPARE(engine.queue(), QStringList({m_longTone, m_toneB, m_toneA}));
        QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 0, 5000);
        QCOMPARE(engine.currentFile(), m_longTone);
        QVERIFY(engine.position() >= positionBefore);
        QVERIFY(!engine.removeQueueItem(0));
        QCOMPARE(engine.queue(), QStringList({m_longTone, m_toneB, m_toneA}));
    }

    void moveQueueItemKeepsTheCurrentOccurrenceAndPosition()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        engine.loadPlaylist({m_toneA, m_longTone, m_toneA, m_toneB, m_toneA}, 1);
        QTRY_VERIFY_WITH_TIMEOUT(engine.position() > 1.0, 10000);
        const double positionBefore = engine.position();

        QVERIFY(engine.moveQueueItem(3, 2));
        QCOMPARE(engine.queue(),
                 QStringList({m_toneA, m_longTone, m_toneB, m_toneA, m_toneA}));
        QVERIFY(engine.moveQueueItem(0, 4));
        QCOMPARE(engine.queue(),
                 QStringList({m_longTone, m_toneB, m_toneA, m_toneA, m_toneA}));
        QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 0, 5000);
        QCOMPARE(engine.currentFile(), m_longTone);
        QVERIFY(engine.position() >= positionBefore);
        QVERIFY(!engine.moveQueueItem(-1, 2));

        engine.pause();
        engine.next();
        QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 1, 5000);
        QTRY_COMPARE_WITH_TIMEOUT(engine.currentFile(), m_toneB, 5000);
    }

    void clearUpcomingKeepsOnlyTheCurrentOccurrence()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        engine.loadPlaylist({m_toneA, m_longTone, m_toneA, m_toneB, m_toneA}, 1);
        QTRY_VERIFY_WITH_TIMEOUT(engine.position() > 1.0, 10000);
        const double positionBefore = engine.position();

        QVERIFY(engine.clearUpcoming());
        QCOMPARE(engine.queue(), QStringList({m_longTone}));
        QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 0, 5000);
        QCOMPARE(engine.currentFile(), m_longTone);
        QVERIFY(engine.position() >= positionBefore);
    }

    void duplicateQueueEditsSurviveShuffleUndo()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        engine.loadPlaylist({m_longTone, m_toneA, m_toneB, m_toneA}, 0);
        QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 0, 5000);
        QTRY_COMPARE_WITH_TIMEOUT(engine.currentFile(), m_longTone, 5000);
        engine.pause();
        engine.setShuffle(true);

        QVERIFY(engine.playNext(m_toneA));
        const int uniqueEntry = engine.queue().indexOf(m_toneB);
        QVERIFY(uniqueEntry > 0);
        QVERIFY(engine.removeQueueItem(uniqueEntry));
        engine.setShuffle(false);

        QCOMPARE(engine.queue(),
                 QStringList({m_longTone, m_toneA, m_toneA, m_toneA}));
        QCOMPARE(engine.playlistPos(), 0);
        QCOMPARE(engine.currentFile(), m_longTone);
    }

    // A tirinha da tela pede "os próximos quatro": o que toca não entra, e pedir mais do
    // que existe devolve o que existe em vez de estourar.
    void upcomingSkipsTheCurrentAndClampsToWhatExists()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        engine.loadPlaylist({m_toneA, m_toneB}, 0);
        QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 0, 5000);

        QCOMPARE(engine.upcoming(4), QStringList({m_toneB}));
        QCOMPARE(engine.upcoming(0), QStringList());
    }

    // "Continue where you left off" means the whole ordered queue and its current entry,
    // not a one-track reconstruction derived from play statistics.
    void savedQueueAndCurrentIndexSurviveEngineRestart()
    {
        const QStringList expected = {m_toneA, m_longTone, m_toneB};
        {
            AudioEngine engine(nullptr, true);
            QVERIFY(engine.isAvailable());
            engine.loadPlaylist(expected, 1);
            QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 1, 5000);
            engine.pause();
        }

        AudioEngine restored(nullptr, true);
        QCOMPARE(restored.savedQueue(), expected);
        QCOMPARE(restored.savedQueueIndex(), 1);
        QCOMPARE(restored.savedCurrentFile(), m_longTone);
    }

    // Music resumes at 0:00 even if the previous engine had already reached the end of the
    // current track. Only podcasts retain a timestamp.
    void restoringSavedQueueStartsTheCurrentTrackFromTheBeginning()
    {
        {
            AudioEngine engine(nullptr, true);
            QVERIFY(engine.isAvailable());
            engine.loadPlaylist({m_toneA, m_longTone, m_toneB}, 1);
            QTRY_COMPARE_WITH_TIMEOUT(engine.currentFile(), m_longTone, 5000);
            engine.seek(6.0);
            QTRY_VERIFY_WITH_TIMEOUT(engine.position() > 5.0, 5000);
            engine.pause();
        }

        AudioEngine restored(nullptr, true);
        QVERIFY(restored.isAvailable());
        QVERIFY(restored.restoreSavedQueue());
        restored.play();
        QTRY_COMPARE_WITH_TIMEOUT(restored.currentFile(), m_longTone, 5000);
        QTRY_COMPARE_WITH_TIMEOUT(restored.playlistPos(), 1, 5000);
        restored.pause();
        QVERIFY2(restored.position() < 1.0,
                 qPrintable(QStringLiteral("restored at %1 s instead of 0:00")
                            .arg(restored.position())));
        QCOMPARE(restored.queue(), QStringList({m_toneA, m_longTone, m_toneB}));
    }

    // A file may disappear between sessions. Restoring must keep every valid entry and move
    // the current index to the same surviving track instead of feeding a dead path to mpv.
    void restoringSavedQueueDropsMissingFiles()
    {
        const QString removed = m_dir.filePath(QStringLiteral("removed-session.flac"));
        QVERIFY(QFile::copy(m_toneA, removed));
        {
            AudioEngine engine(nullptr, true);
            QVERIFY(engine.isAvailable());
            engine.loadPlaylist({removed, m_longTone, m_toneB}, 1);
            QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 1, 5000);
            engine.pause();
        }
        QVERIFY(QFile::remove(removed));

        AudioEngine restored(nullptr, true);
        restored.pause();
        QVERIFY(restored.restoreSavedQueue());
        QCOMPARE(restored.queue(), QStringList({m_longTone, m_toneB}));
        QTRY_COMPARE_WITH_TIMEOUT(restored.playlistPos(), 0, 5000);
        QTRY_COMPARE_WITH_TIMEOUT(restored.currentFile(), m_longTone, 5000);
    }

    // Três posições, não duas: repetir a fila e repetir a faixa são propriedades
    // diferentes no mpv, e um booleano só não conseguiria expressar as duas.
    void repeatCyclesThroughThreePositions()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        QCOMPARE(engine.repeatMode(), AudioEngine::RepeatOff);

        QSignalSpy spy(&engine, &AudioEngine::repeatModeChanged);
        engine.cycleRepeat();
        QCOMPARE(engine.repeatMode(), AudioEngine::RepeatAll);
        engine.cycleRepeat();
        QCOMPARE(engine.repeatMode(), AudioEngine::RepeatOne);
        engine.cycleRepeat();
        QCOMPARE(engine.repeatMode(), AudioEngine::RepeatOff);
        QCOMPARE(spy.count(), 3);
    }

    // O aleatório age sobre a FILA, não sobre a biblioteca — e desligar volta à ordem
    // original, que é o que faltava no aleatório da tela de boas-vindas.
    void shuffleReordersTheQueueAndCanBeUndone()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        const QStringList original = {m_toneA, m_toneB};
        engine.loadPlaylist(original, 0);
        QCOMPARE(engine.shuffle(), false);

        QSignalSpy spy(&engine, &AudioEngine::shuffleChanged);
        engine.setShuffle(true);
        QCOMPARE(engine.shuffle(), true);
        QCOMPARE(spy.count(), 1);
        // A fila continua com as mesmas entradas, em qualquer ordem.
        QCOMPARE(engine.queue().size(), 2);
        QVERIFY(engine.queue().contains(m_toneA));
        QVERIFY(engine.queue().contains(m_toneB));

        engine.setShuffle(false);
        QCOMPARE(engine.shuffle(), false);
        QCOMPARE(engine.queue(), original);
    }

    // Carregar uma fila nova zera o aleatório: a ordem guardada era da fila anterior, e
    // restaurar sobre a nova devolveria faixas que não estão mais lá.
    void loadingANewPlaylistClearsShuffle()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        engine.loadPlaylist({m_toneA, m_toneB}, 0);
        engine.setShuffle(true);
        engine.loadPlaylist({m_toneB}, 0);
        QCOMPARE(engine.shuffle(), false);
    }

    // Mexer na ORDEM da fila não pode mexer na MÚSICA: quem aperta aleatório no meio de uma
    // faixa quer o resto da fila embaralhado, não a faixa de volta ao início.
    void shuffleDoesNotRestartWhatIsPlaying()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        // Um tom longo de propósito: com os fixtures de 1 s a faixa acabaria sozinha
        // durante a espera e o teste falharia por outro motivo.
        const QString longo = makeTone(m_dir.filePath(QStringLiteral("longo.flac")), 440, 8.0);
        if (longo.isEmpty())
            QSKIP("ffmpeg unavailable");

        engine.loadPlaylist({longo, m_toneA, m_toneB}, 0);
        engine.play();
        // Esperar bem além do que a folga do teste vai correr: se a faixa reiniciar, os
        // 800 ms seguintes não a trazem nem perto daqui, e a diferença fica gritante.
        QTRY_VERIFY_WITH_TIMEOUT(engine.position() > 3.0, 15000);
        const QString tocando = engine.currentFile();
        const double antes = engine.position();

        engine.setShuffle(true);
        QTest::qWait(800);

        QCOMPARE(engine.currentFile(), tocando);
        QVERIFY2(engine.position() >= antes,
                 qPrintable(QStringLiteral("a faixa voltou ao início: %1 s -> %2 s")
                            .arg(antes).arg(engine.position())));
    }

    // Embaralhar tem de mexer na fila do mpv, não só no espelho que a tela lê. Sem este
    // teste, um reordenador que não fizesse nada passaria em todos os outros: a fila
    // mostraria uma ordem e o som seguiria outra — e ninguém veria até tocar.
    void shuffleReordersWhatMpvPlaysNext()
    {
        AudioEngine engine(nullptr, true);
        if (!engine.isAvailable())
            QSKIP("mpv unavailable");

        QStringList original = {m_toneA, m_toneB};
        for (int i = 0; i < 3; ++i) {
            const QString extra = makeTone(
                m_dir.filePath(QStringLiteral("extra%1.flac").arg(i)), 500 + i * 90, 1.0);
            if (extra.isEmpty())
                QSKIP("ffmpeg unavailable");
            original.append(extra);
        }

        engine.loadPlaylist(original, 0);
        engine.play();
        QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 0, 10000);

        // Insistir até a SEGUNDA entrada mudar. Sem isso o teste poderia comparar a fila
        // nova com uma posição que por acaso não se mexeu, e passaria sem provar nada.
        int tentativas = 0;
        do {
            engine.setShuffle(false);
            engine.setShuffle(true);
        } while (engine.queue().at(1) == original.at(1) && ++tentativas < 30);
        QVERIFY2(engine.queue().at(1) != original.at(1),
                 "trinta embaralhamentos e a segunda entrada nunca mudou");

        const QString esperado = engine.queue().at(1);

        // PAUSAR antes de pular é o que torna este teste honesto: tocando, a fila de tons
        // de 1 s anda sozinha e passa por TODOS os arquivos, então esperar pelo esperado
        // acabaria dando certo mesmo com o reordenador desligado (medido).
        engine.pause();
        engine.next();
        QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 1, 5000);
        QCOMPARE(engine.currentFile(), esperado);
    }

    // "Tocar tudo em ordem aleatória" (a tela de boas-vindas) carrega a fila e SÓ ENTÃO liga
    // o modo — nesse instante o mpv já começou a carregar a primeira entrada da ordem
    // antiga. Se ele ficar nela, a fila nova só é ouvida a partir dali: o convite promete
    // tudo e entrega um pedaço, sempre começando pela mesma faixa.
    void shuffleFromAStandstillStartsAtTheTopOfTheNewOrder()
    {
        // Fila LONGA de propósito. Com cinco entradas o defeito não aparece: reordenar é
        // rápido demais e o mpv ainda não começou a primeira faixa. Com vinte e poucas — o
        // tamanho de uma biblioteca de verdade — ele já começou, e sai andando junto com a
        // entrada que carregou. Foi assim que o defeito apareceu no app (pos=24 de 27).
        QStringList original = {m_toneA, m_toneB};
        for (int i = 0; i < 24; ++i) {
            const QString extra = makeTone(
                m_dir.filePath(QStringLiteral("parado%1.flac").arg(i)), 300 + i * 30, 1.0);
            if (extra.isEmpty())
                QSKIP("ffmpeg unavailable");
            original.append(extra);
        }

        // Motor novo a cada tentativa: o que se testa é o instante em que nada tocou ainda,
        // e esse instante não volta depois que a fila anda.
        for (int tentativa = 0; tentativa < 30; ++tentativa) {
            AudioEngine engine(nullptr, true);
            if (!engine.isAvailable())
                QSKIP("mpv unavailable");

            engine.loadPlaylist(original, 0);
            engine.setShuffle(true);
            if (engine.queue().at(0) == original.at(0))
                continue; // ordem por acaso igual no começo: não distinguiria nada

            // Pausado, senão a fila de tons de 1 s anda sozinha e passa pelo esperado.
            engine.pause();
            const QString esperado = engine.queue().at(0);
            QTRY_COMPARE_WITH_TIMEOUT(engine.playlistPos(), 0, 5000);
            // Esperar também pelo arquivo: escrever playlist-pos manda o mpv carregar, e
            // comparar no instante seguinte é comparar antes de ele ter carregado. Pausado,
            // esperar é seguro — a fila não anda sozinha para passar pelo esperado.
            QTRY_COMPARE_WITH_TIMEOUT(engine.currentFile(), esperado, 5000);
            return;
        }
        QFAIL("trinta embaralhamentos e a primeira entrada nunca mudou");
    }
};

QTEST_MAIN(TstAudioEngine)
#include "tst_audioengine.moc"
