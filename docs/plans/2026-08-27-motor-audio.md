---
slug: motor-audio
feature: melodia
status: aprovado
depende-de: [esqueleto-build]
decisao-humana: nao
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: motor-audio

**Goal:** Um motor de áudio C++ sobre libmpv que toca arquivos locais com qualidade máxima —
FLAC 24bit/96-192 kHz sem conversão, sem silêncio entre faixas de álbum contínuo, ReplayGain
respeitado — exposto ao QML como singleton e testável sem tela e sem som audível.

**Arquitetura:** `AudioEngine` fala com o **libmpv direto pela C API** (`mpv/client.h`), não
pelo wrapper `mpvqt`. Decisão do research: `mpvqt` é a lib de vídeo do Haruna (`MpvAbstractItem`
herda `QQuickFramebufferObject` e inclui `<mpv/render_gl.h>` incondicionalmente), troca tipagem
forte por `QVariant`, e não tem pacote pronto para Windows. A fila de reprodução é a **playlist
interna do mpv** — é a única forma de o gapless funcionar, porque é o mpv que decide manter o
dispositivo de áudio aberto entre uma entrada e a próxima.

**Constraints globais:** libmpv API cliente 2.5 (mpv 0.40.0). O motor não depende de
`Qt6::Quick` — só `Qt6::Core` e `Qt6::Qml` — para poder ser testado headless.

**Requisito duro (spec §Requisito duro: qualidade de áudio):** "FLAC e alta resolução tocados
sem conversão no caminho", "Sem silêncio entre faixas de álbuns contínuos", "Sem o sistema
operacional remixar ou reamostrar o sinal", "ReplayGain respeitado quando o arquivo tiver".

**Research:** `docs/plans/research/2026-08-27-audio-engine.md` (o esqueleto lá foi compilado e
executado de verdade, tocando duas faixas em sequência).

## Arquivos

- Criar: `src/audioengine.h` · `src/audioengine.cpp`
- Criar: `tests/tst_audioengine.cpp`
- Modificar: `CMakeLists.txt` (fontes, `pkg_check_modules` do mpv) · `tests/CMakeLists.txt`
- Testar: `tests/tst_audioengine.cpp`

## Interfaces

- **Consome:** o alvo CMake `appmelodia` e o módulo QML `Melodia.App` (fatia `esqueleto-build`).
  Nada mais — este motor não conhece banco, biblioteca nem UI.
- **Produz** — singleton C++ `AudioEngine` (`QML_ELEMENT` + `QML_SINGLETON`, header
  `src/audioengine.h`), consumido pelas fatias `tocador-ui`, `navegacao-biblioteca` e
  `podcast-local` com estas assinaturas exatas:

```cpp
// Properties (all with NOTIFY):
double  position() const;        // seconds into the current track
double  duration() const;        // seconds, 0 when unknown
bool    playing() const;         // true when not paused and a file is loaded
double  volume() const;          // 0..100
Q_INVOKABLE void setVolume(double v);
QString currentFile() const;     // absolute path of the entry now playing, empty when idle
int     playlistPos() const;     // index into the playlist, -1 when idle
double  speed() const;           // 1.0 = normal; podcast slice drives this
Q_INVOKABLE void setSpeed(double s);   // clamped to [0.25, 4.0]

// Q_INVOKABLE:
void play();
void pause();
void togglePause();
void stop();                     // clears the playlist and goes idle
void seek(double seconds);       // absolute position, not relative
void next();
void previous();
void loadPlaylist(const QStringList &files, int startIndex = 0);
void setGaplessAggressive(bool on);   // false = mpv "weak" (default), true = "yes"
void setReplayGainMode(const QString &mode);  // "no" | "track" | "album"
void setExclusiveOutput(bool on);     // audio-exclusive; silences the rest of the system

// Signals:
void positionChanged(); void durationChanged(); void playingChanged();
void volumeChanged(); void currentFileChanged(); void playlistPosChanged();
void speedChanged();
void trackFinished(const QString &path);   // emitted on EOF of an entry — the stats
                                           // counter in `navegacao-biblioteca` listens here
void playbackError(const QString &path, const QString &message);
void engineUnavailable(const QString &message);  // mpv could not initialise at all
```

## Tasks

### Task 1: Ligar o libmpv ao build

- [x] Acrescentar a `CMakeLists.txt`, logo após `find_package(Qt6 ...)`:

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
```

- [x] Acrescentar `src/audioengine.h` e `src/audioengine.cpp` à lista de
      `qt_add_executable(appmelodia ...)` **e** ao bloco `SOURCES` de `qt_add_qml_module`.
- [x] Acrescentar `PkgConfig::MPV` ao `target_link_libraries(appmelodia PRIVATE ...)` e
      `Qt6::Qml` à lista de componentes do `find_package(Qt6 ...)`.
- [x] verificação mecânica da task: `pkg-config --exists mpv && echo OK` → `OK`
      (nota: `pkg-config --modversion mpv` devolve `2.5.0` — é a versão da **API cliente**,
      não a do programa mpv 0.40.0; não use essa string para inferir quais funções existem)
- [x] commit:

```bash
git add CMakeLists.txt
git commit -m "build(audio): link libmpv through pkg-config"
```

### Task 2: AudioEngine — header

- [ ] Criar `src/audioengine.h`:

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQmlIntegration/qqmlintegration.h>

struct mpv_handle;
struct mpv_event;

class AudioEngine : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(int playlistPos READ playlistPos NOTIFY playlistPosChanged)
    Q_PROPERTY(double speed READ speed WRITE setSpeed NOTIFY speedChanged)

public:
    // headlessAo = true forces --ao=null: never opens a real device, for automated tests.
    explicit AudioEngine(QObject *parent = nullptr, bool headlessAo = false);
    ~AudioEngine() override;

    double position() const { return m_position; }
    double duration() const { return m_duration; }
    bool playing() const { return m_playing; }
    double volume() const { return m_volume; }
    QString currentFile() const { return m_currentFile; }
    int playlistPos() const { return m_playlistPos; }
    double speed() const { return m_speed; }

    // Q_INVOKABLE and not just a Q_PROPERTY WRITE: the podcast slice calls
    // AudioEngine.setSpeed(x) as a function. A bare WRITE method is invisible to QML.
    Q_INVOKABLE void setVolume(double v);
    Q_INVOKABLE void setSpeed(double s);

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(double seconds);
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void loadPlaylist(const QStringList &files, int startIndex = 0);
    Q_INVOKABLE void setGaplessAggressive(bool on);
    Q_INVOKABLE void setReplayGainMode(const QString &mode);
    Q_INVOKABLE void setExclusiveOutput(bool on);

    bool isAvailable() const { return m_mpv != nullptr; }

signals:
    void positionChanged();
    void durationChanged();
    void playingChanged();
    void volumeChanged();
    void currentFileChanged();
    void playlistPosChanged();
    void speedChanged();
    void trackFinished(const QString &path);
    void playbackError(const QString &path, const QString &message);
    void engineUnavailable(const QString &message);

private slots:
    void onMpvEvents();

private:
    static void wakeup(void *ctx);
    void handleEvent(mpv_event *event);
    void setOptionString(const char *name, const char *value);
    void setPropertyString(const char *name, const char *value);
    void command(const QStringList &args);

    mpv_handle *m_mpv = nullptr;
    double m_position = 0.0;
    double m_duration = 0.0;
    bool m_playing = false;
    double m_volume = 100.0;
    QString m_currentFile;
    int m_playlistPos = -1;
    double m_speed = 1.0;
};
```

- [ ] verificação mecânica da task: o header compila isolado —
      `g++ -fsyntax-only -std=c++20 $(pkg-config --cflags Qt6Core Qt6Qml Qt6QmlIntegration mpv) -x c++ src/audioengine.h`
      → exit 0
- [ ] commit:

```bash
git add src/audioengine.h
git commit -m "feat(audio): declare AudioEngine interface over libmpv"
```

### Task 3: AudioEngine — implementação

Duas coisas nesta task não são negociáveis e ambas foram comprovadas ao vivo no research:

1. `std::setlocale(LC_NUMERIC, "C")` **antes** de `mpv_create()`. O sistema do Pedro é
   `pt_BR.UTF-8` (vírgula decimal) e sem isso o `mpv_create()` falha — exigência documentada
   em `client.h:147-149`, e o sintoma não aponta para a causa.
2. O wakeup callback roda em thread do mpv e **não pode tocar QObject nem chamar `mpv_*`** —
   ele só agenda `onMpvEvents` na thread do Qt via `Qt::QueuedConnection`.

`audio-samplerate` e `audio-format` ficam **sem setar**: é isso que faz o FLAC de alta
resolução chegar ao dispositivo sem conversão. Setar qualquer valor força o `swresample` a
converter tudo.

`gapless-audio` nasce em `weak` (o default do mpv), não em `yes`. Motivo: `yes` mantém o
dispositivo aberto com os parâmetros da primeira faixa e **resampleia as seguintes** se o
formato mudar — o oposto do requisito de qualidade. Em `weak` o gapless acontece entre faixas
de parâmetros idênticos (que é exatamente o caso de um álbum contínuo) e nunca há resample
escondido. `setGaplessAggressive(true)` liga o `yes` para quem sabe o que está fazendo.

- [ ] Criar `src/audioengine.cpp`:

```cpp
#include "audioengine.h"

#include <QMetaObject>
#include <clocale>
#include <mpv/client.h>

namespace {
enum PropertyId : uint64_t {
    PROP_TIME_POS = 1,
    PROP_DURATION = 2,
    PROP_PAUSE = 3,
    PROP_PATH = 4,
    PROP_PLAYLIST_POS = 5,
    PROP_SPEED = 6,
};
} // namespace

AudioEngine::AudioEngine(QObject *parent, bool headlessAo)
    : QObject(parent)
{
    // MANDATORY before mpv_create(): libmpv requires LC_NUMERIC="C". Under pt_BR.UTF-8
    // (decimal comma) mpv_create() fails and the symptom does not point at the cause.
    std::setlocale(LC_NUMERIC, "C");

    m_mpv = mpv_create();
    if (!m_mpv) {
        emit engineUnavailable(QStringLiteral("mpv_create failed"));
        return;
    }

    setOptionString("video", "no");
    setOptionString("vo", "null");
    setOptionString("audio-display", "no");
    if (headlessAo)
        setOptionString("ao", "null");

    // Quality contract (spec: no conversion in the path).
    // audio-samplerate and audio-format are deliberately NOT set: any value forces
    // swresample to convert everything to it.
    setOptionString("gapless-audio", "weak");
    setOptionString("replaygain", "no");
    setOptionString("replaygain-clip", "no");
    setOptionString("hr-seek", "yes");
    setOptionString("keep-open", "no");

    const int status = mpv_initialize(m_mpv);
    if (status < 0) {
        emit engineUnavailable(QString::fromUtf8(mpv_error_string(status)));
        mpv_destroy(m_mpv);
        m_mpv = nullptr;
        return;
    }

    mpv_observe_property(m_mpv, PROP_TIME_POS, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, PROP_DURATION, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, PROP_PAUSE, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, PROP_PATH, "path", MPV_FORMAT_STRING);
    mpv_observe_property(m_mpv, PROP_PLAYLIST_POS, "playlist-pos", MPV_FORMAT_INT64);
    mpv_observe_property(m_mpv, PROP_SPEED, "speed", MPV_FORMAT_DOUBLE);
    mpv_set_wakeup_callback(m_mpv, &AudioEngine::wakeup, this);
}

AudioEngine::~AudioEngine()
{
    if (m_mpv) {
        mpv_set_wakeup_callback(m_mpv, nullptr, nullptr); // stop waking us before tearing down
        mpv_terminate_destroy(m_mpv);
        m_mpv = nullptr;
    }
}

void AudioEngine::setOptionString(const char *name, const char *value)
{
    if (m_mpv)
        mpv_set_option_string(m_mpv, name, value);
}

void AudioEngine::setPropertyString(const char *name, const char *value)
{
    if (m_mpv)
        mpv_set_property_string(m_mpv, name, value);
}

void AudioEngine::command(const QStringList &args)
{
    if (!m_mpv)
        return;
    QList<QByteArray> owned;
    owned.reserve(args.size());
    for (const QString &a : args)
        owned.append(a.toUtf8());

    QVarLengthArray<const char *, 8> argv;
    for (const QByteArray &b : owned)
        argv.append(b.constData());
    argv.append(nullptr);

    mpv_command(m_mpv, argv.data());
}

void AudioEngine::play()
{
    if (!m_mpv)
        return;
    int flag = 0;
    mpv_set_property(m_mpv, "pause", MPV_FORMAT_FLAG, &flag);
}

void AudioEngine::pause()
{
    if (!m_mpv)
        return;
    int flag = 1;
    mpv_set_property(m_mpv, "pause", MPV_FORMAT_FLAG, &flag);
}

void AudioEngine::togglePause()
{
    m_playing ? pause() : play();
}

void AudioEngine::stop()
{
    command({QStringLiteral("stop")});
}

void AudioEngine::seek(double seconds)
{
    command({QStringLiteral("seek"), QString::number(seconds), QStringLiteral("absolute")});
}

void AudioEngine::next()
{
    command({QStringLiteral("playlist-next"), QStringLiteral("weak")});
}

void AudioEngine::previous()
{
    command({QStringLiteral("playlist-prev"), QStringLiteral("weak")});
}

void AudioEngine::loadPlaylist(const QStringList &files, int startIndex)
{
    if (!m_mpv || files.isEmpty())
        return;
    for (int i = 0; i < files.size(); ++i) {
        // "replace" on the first entry clears whatever was queued; "append" keeps the
        // playlist internal to mpv, which is what preserves gapless between entries.
        const QString mode = (i == 0) ? QStringLiteral("replace") : QStringLiteral("append");
        command({QStringLiteral("loadfile"), files.at(i), mode});
    }
    if (startIndex > 0 && startIndex < files.size())
        setPropertyString("playlist-pos", QByteArray::number(startIndex).constData());
}

void AudioEngine::setVolume(double v)
{
    if (qFuzzyCompare(m_volume, v) || !m_mpv)
        return;
    m_volume = qBound(0.0, v, 100.0);
    mpv_set_property(m_mpv, "volume", MPV_FORMAT_DOUBLE, &m_volume);
    emit volumeChanged();
}

void AudioEngine::setSpeed(double s)
{
    const double clamped = qBound(0.25, s, 4.0);
    if (qFuzzyCompare(m_speed, clamped) || !m_mpv)
        return;
    m_speed = clamped;
    mpv_set_property(m_mpv, "speed", MPV_FORMAT_DOUBLE, &m_speed);
    emit speedChanged();
}

void AudioEngine::setGaplessAggressive(bool on)
{
    // "yes" keeps the device open across entries but resamples tracks whose format differs
    // from the first one. "weak" (default) only goes gapless when the format matches.
    setPropertyString("gapless-audio", on ? "yes" : "weak");
}

void AudioEngine::setReplayGainMode(const QString &mode)
{
    const QByteArray value = (mode == QStringLiteral("track") || mode == QStringLiteral("album"))
                                 ? mode.toUtf8()
                                 : QByteArrayLiteral("no");
    setPropertyString("replaygain", value.constData());
}

void AudioEngine::setExclusiveOutput(bool on)
{
    // Exclusive mode silences every other application on the system while a file is loaded.
    setPropertyString("audio-exclusive", on ? "yes" : "no");
}

void AudioEngine::wakeup(void *ctx)
{
    // Runs on an mpv thread. Must not touch QObject state nor call any mpv_* function:
    // it may only schedule work back on the Qt thread.
    QMetaObject::invokeMethod(static_cast<AudioEngine *>(ctx), "onMpvEvents",
                              Qt::QueuedConnection);
}

void AudioEngine::onMpvEvents()
{
    if (!m_mpv)
        return;
    while (true) {
        mpv_event *event = mpv_wait_event(m_mpv, 0); // timeout 0: drain, never block
        if (event->event_id == MPV_EVENT_NONE)
            break;
        handleEvent(event);
    }
}

void AudioEngine::handleEvent(mpv_event *event)
{
    switch (event->event_id) {
    case MPV_EVENT_PROPERTY_CHANGE: {
        auto *prop = static_cast<mpv_event_property *>(event->data);
        if (!prop->data)
            break;
        switch (event->reply_userdata) {
        case PROP_TIME_POS:
            m_position = *static_cast<double *>(prop->data);
            emit positionChanged();
            break;
        case PROP_DURATION:
            m_duration = *static_cast<double *>(prop->data);
            emit durationChanged();
            break;
        case PROP_PAUSE:
            m_playing = (*static_cast<int *>(prop->data)) == 0;
            emit playingChanged();
            break;
        case PROP_PATH: {
            const char *p = *static_cast<char **>(prop->data);
            m_currentFile = p ? QString::fromUtf8(p) : QString();
            emit currentFileChanged();
            break;
        }
        case PROP_PLAYLIST_POS:
            m_playlistPos = static_cast<int>(*static_cast<int64_t *>(prop->data));
            emit playlistPosChanged();
            break;
        case PROP_SPEED:
            m_speed = *static_cast<double *>(prop->data);
            emit speedChanged();
            break;
        default:
            break;
        }
        break;
    }
    case MPV_EVENT_END_FILE: {
        auto *ef = static_cast<mpv_event_end_file *>(event->data);
        if (ef->reason == MPV_END_FILE_REASON_ERROR) {
            emit playbackError(m_currentFile, QString::fromUtf8(mpv_error_string(ef->error)));
        } else if (ef->reason == MPV_END_FILE_REASON_EOF) {
            emit trackFinished(m_currentFile);
        }
        break;
    }
    case MPV_EVENT_IDLE:
        m_playlistPos = -1;
        m_currentFile.clear();
        emit playlistPosChanged();
        emit currentFileChanged();
        break;
    case MPV_EVENT_SHUTDOWN:
        m_mpv = nullptr;
        break;
    default:
        break;
    }
}
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/audioengine.cpp CMakeLists.txt
git commit -m "feat(audio): implement libmpv playback engine with gapless-safe defaults"
```

### Task 4: Teste headless de reprodução

Usa `ao=null`: nunca abre PipeWire/ALSA, roda sem placa de som e sem tela. As fixtures são
geradas pelo próprio teste com ffmpeg — dois FLACs curtos de parâmetros idênticos, que é a
condição em que o gapless `weak` de fato emenda.

- [ ] Acrescentar a `tests/CMakeLists.txt`:

```cmake
qt_add_executable(tst_audioengine
    tst_audioengine.cpp
    ../src/audioengine.h
    ../src/audioengine.cpp
)
target_include_directories(tst_audioengine PRIVATE ../src)
target_link_libraries(tst_audioengine PRIVATE Qt6::Core Qt6::Test Qt6::Qml PkgConfig::MPV)

add_test(NAME tst_audioengine COMMAND tst_audioengine)
set_tests_properties(tst_audioengine PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen" TIMEOUT 60)
```

- [ ] Criar `tests/tst_audioengine.cpp`:

```cpp
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
```

- [ ] verificação mecânica da task:
      `cmake --build build && ctest --test-dir build -R tst_audioengine --output-on-failure`
      → `100% tests passed`
- [ ] commit:

```bash
git add tests/tst_audioengine.cpp tests/CMakeLists.txt
git commit -m "test(audio): headless playback, auto-advance and speed clamping"
```

### Task 5: Registrar as opções de qualidade no README [sem-código]

O que o app pode e o que não pode garantir precisa estar escrito — prometer bit-perfect que
depende da config do PipeWire do usuário seria mentira.

- [ ] Acrescentar ao `README.md` uma seção "Qualidade de áudio" registrando:
      que `audio-samplerate`/`audio-format` não são setados de propósito (é isso que evita
      conversão); que `gapless-audio` fica em `weak` por padrão e `yes` resampleia faixas de
      formato diferente; que `audio-exclusive` silencia todo o resto do sistema e por isso
      não é padrão; e o limite honesto — mesmo com modo exclusivo, se o grafo do PipeWire
      estiver fixo em 48 kHz (`default.clock.rate` no `pipewire.conf`), quem reamostra pode
      ser o próprio PipeWire, e isso é configuração do sistema, não do melodia.
- [ ] verificação mecânica da task: `grep -c "audio-exclusive" README.md` → `1` ou mais
- [ ] commit:

```bash
git add README.md
git commit -m "docs(audio): document quality options and the PipeWire caveat"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build -R tst_audioengine --output-on-failure` → `100% tests passed`
- `ctest --test-dir build --output-on-failure` → `100% tests passed` (não quebrou a fatia 1)
- `grep -c "setlocale(LC_NUMERIC" src/audioengine.cpp` → `1`
- `grep -c 'audio-samplerate\|audio-format' src/audioengine.cpp` → `0`
  (as duas opções têm de continuar **não setadas** — este check é o guarda do requisito de
  qualidade; se alguém as adicionar, o FLAC de alta resolução passa a ser convertido)

## Fora de escopo

- Qualquer interface gráfica de player (fatia `tocador-ui`).
- Ler metadados do arquivo — quem lê tags é o TagLib na fatia `scan-biblioteca`. O que o mpv
  reporta em `media-title` não é usado como fonte de metadados da biblioteca.
- Persistir volume, velocidade ou modo de ReplayGain entre sessões — nasce junto com a tela
  de configurações, na fatia `navegacao-biblioteca`.
- Equalizador, efeitos e visualizações: o spec os exclui por contrariarem o requisito de
  qualidade.
- Saída para dispositivo específico (seletor de AO) — o mpv detecta o PipeWire sozinho.
