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
};

QTEST_MAIN(TstAudioEngine)
#include "tst_audioengine.moc"
