# Research — Motor de áudio: libmpv direto vs mpvqt 1.0.1

Verificado contra `/usr/include/mpv/client.h` (`MPV_CLIENT_API_VERSION` = `MPV_MAKE_VERSION(2,5)`),
`/usr/include/MpvQt/*.h` (mpvqt-1.0.1-3.fc43, pacote KDE/Haruna), `man mpv` (mpv v0.40.0) e
`pkg-config --cflags/--libs mpv`. **O esqueleto da seção 6 foi compilado e RODADO de verdade**
neste Fedora 43 (g++ 15.3.1, Qt 6.10.3) — não é código hipotético; evidência na seção 9.

## 1. Recomendação: libmpv direto (C API), não mpvqt

**Use `mpv/client.h` na unha.** Três razões, na ordem em que pesaram:

1. **mpvqt é uma lib de vídeo com um wrapper de controle solto dentro.** `MpvAbstractItem`
   (o motivo do pacote existir) herda `QQuickFramebufferObject` e inclui
   `<mpv/render_gl.h>` incondicionalmente (`/usr/include/MpvQt/mpvabstractitem.h:14-15`) —
   é a integração de render OpenGL do Haruna, 100% inútil para áudio puro. O único pedaço
   audio-only-friendly é `MpvController` (thin wrapper QObject), mas ele também inclui
   `<mpv/render_gl.h>` sem usar (`mpvcontroller.h:18`) e não temos o `.cpp` (só o header —
   pacote `-devel` não traz fonte), então o comportamento interno de threading é opaco.
2. **`MpvController` troca tipagem forte por `QVariant`/`mpv_node` em tudo** — `getProperty`,
   `setProperty`, `command` passam por conversão genérica. Para `time-pos`/`duration`
   (double) e `pause` (flag) isso é indireção sem ganho; a C API já devolve o tipo exato via
   `mpv_observe_property(..., MPV_FORMAT_DOUBLE)`.
3. **Windows**: libmpv tem builds oficiais prontos (DLL + headers, projeto shinchiro/mpv-player-windows)
   documentados e usados por dezenas de players. mpvqt é ecossistema KDE (Craft/`invent.kde.org`,
   sem pacote pronto fora do Linux) — mais uma dependência de build a manter só para ganhar
   uma indireção de tipos que não precisamos. NÃO VERIFICADO em máquina Windows real (sem
   acesso); afirmação baseada na documentação pública dos dois projetos.

O ganho real de escrever contra a C API: você (aprendendo C++) enxerga o ciclo de vida
completo — criar handle, setar opção, inicializar, tratar erro, observar propriedade, destruir —
em vez de herdar um QObject cuja implementação você não pode ler.

## 2. Qualidade de áudio — as opções exatas

Todas confirmadas em `man mpv` (v0.40.0) e/ou `mpv --list-options`. Setar via
`mpv_set_option_string()` **antes** de `mpv_initialize()`.

| Requisito                           | Opção               | Valor recomendado                                                                                                      | Trade-off                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ----------------------------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| FLAC 24bit/96-192kHz sem conversão  | `audio-samplerate`  | não setar (default `0` = segue o arquivo)                                                                              | Setar um valor fixo força `swresample` a converter TUDO pra essa taxa — o oposto do que você quer.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| idem (formato de amostra)           | `audio-format`      | não setar (default vazio = segue o decoder)                                                                            | Forçar um formato específico também insere conversão.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Gapless entre faixas de álbum       | `gapless-audio`     | `yes` (não o default `weak`)                                                                                           | `yes` abre o dispositivo com os parâmetros do 1º arquivo e mantém aberto — se as faixas seguintes tiverem sample rate/formato diferente, elas são resampleadas pra bater com a 1ª. É o preço do gapless "forte": só é seguro para faixas de um MESMO álbum (mesmo encode). `weak` (default) reabre o dispositivo quando o formato muda — gapless só entre faixas com parâmetros idênticos, mas nunca resampleia às escondidas. **Decisão de produto:** `weak` é o default mais seguro para bibliotecas heterogêneas; oferecer `yes` como opção "gapless agressivo" quando o usuário sabe que é um álbum contínuo. |
| Impedir o SO/PipeWire de reamostrar | `audio-exclusive`   | `no` por default, opção visível `yes`                                                                                  | Ver §2.1 — é o item mais delicado.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ReplayGain track/album              | `replaygain`        | `no` (default) → opção do usuário: `no`/`track`/`album`                                                                | `album` cai pra `track` se a tag de álbum não existir.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ReplayGain sem estourar (clipping)  | `replaygain-clip`   | `no` (default)                                                                                                         | Manter `no`: mpv reduz o ganho pra não estourar; `yes` permite clipping se o preamp for alto.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Preamp do ReplayGain                | `replaygain-preamp` | `0` (default), slider -15..+15 dB visível                                                                              | —                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Seek preciso (não só por keyframe)  | `hr-seek`           | `yes` (mpv default já é `default`, que já faz seek preciso na maioria dos casos)                                       | Áudio não tem o custo de decodificar vídeo pro seek preciso; pode deixar sempre ligado sem custo perceptível.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| AO no Fedora/PipeWire               | `ao`                | não setar (mpv detecta `pipewire` primeiro; confirmado por `mpv --ao=help` → `pipewire, pulse, alsa, jack, null, pcm`) | Se quiser, expor um seletor manual de AO nas configurações avançadas.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |

### 2.1 `audio-exclusive` e o PipeWire — o ponto que exige cautela

`man mpv` (`--audio-exclusive`): _"Enable exclusive output mode. In this mode, the system is
usually locked out, and only mpv will be able to output audio. This only works for some
audio outputs, such as wasapi, coreaudio, **pipewire** and audiounit."_ Ou seja, funciona
com o `ao=pipewire` do Fedora 43.

O trade-off é literal: com `audio-exclusive=yes` **nenhum outro app toca som** enquanto o
melodia estiver com um arquivo carregado (notificação do Slack, vídeo do navegador, etc.
ficam mudos). Isso NÃO deve ser o default — vira uma opção "modo bit-perfect exclusivo" nas
configurações avançadas, com o aviso explícito de que silencia o resto do sistema.

**Limite honesto do que dá pra garantir por opção do mpv:** o PipeWire tem seu próprio grafo
com uma taxa de clock (`default.clock.rate` / `default.clock.allowed-rates` em
`pipewire.conf`); mesmo com `audio-exclusive=yes`, se o grafo do PipeWire estiver fixo em
48kHz e o FLAC for 96kHz, quem resampleia pode ser o próprio PipeWire antes de chegar ao
dispositivo, dependendo de como o driver ALSA por trás negocia. Isso é configuração de
**sistema**, fora do código do melodia — NÃO VERIFICADO nesta pesquisa (exigiria testar com
um FLAC 96kHz real e um analisador de taxa no ponto ALSA, fora do escopo de "motor de
áudio"). Documentar essa dependência no manual/troubleshooting do usuário é mais honesto
que prometer bit-perfect garantido só pela opção do mpv.

## 3. Loop de eventos: wakeup callback + fila drenada na thread do Qt

Regra dura do header (`client.h:1730-1760`, comentário de `mpv_set_wakeup_callback`):
_"the callback will be called from foreign threads (...) You are not allowed to call any
client API functions inside of the callback."_ — o callback só pode **acordar** outra
thread; ele não pode tocar `QObject`, emitir sinal, nem chamar `mpv_*` de volta.

Padrão (testado, ver §9): o callback estático empurra uma chamada enfileirada de volta pro
`AudioEngine`, que já está na thread do Qt (a `QCoreApplication`/`QGuiApplication` thread):

```cpp
// Roda em thread do mpv. NÃO toca QObject, só agenda.
void AudioEngine::wakeup(void *ctx)
{
    AudioEngine *self = static_cast<AudioEngine *>(ctx);
    QMetaObject::invokeMethod(self, "onMpvEvents", Qt::QueuedConnection);
}

// Roda na thread do Qt, chamado pelo loop de eventos do Qt via a fila acima.
void AudioEngine::onMpvEvents()
{
    while (true) {
        mpv_event *event = mpv_wait_event(m_mpv, 0); // timeout 0 = não bloqueia, só drena
        if (event->event_id == MPV_EVENT_NONE)
            break;
        handleEvent(event);
    }
}
```

Zero polling: `mpv_wait_event(ctx, 0)` só é chamado quando o wakeup dispara (ou quando um
evento anterior ainda deixou a fila não-vazia — por isso o `while(true)` drena até
`MPV_EVENT_NONE`, conforme o próprio header recomenda: _"call mpv_wait_event() with no
timeout until MPV_EVENT_NONE is reached"_). `QMetaObject::invokeMethod` com
`Qt::QueuedConnection` é a travessia segura de thread — vira um evento postado na fila da
thread onde `self` mora, processado pelo loop do Qt normalmente.

## 4. Fila/playlist: usar a playlist INTERNA do mpv, não gerenciar em C++

Comando confirmado (`man mpv`, seção `loadfile`):

```cpp
const char *args[] = {"loadfile", path.constData(), "replace", nullptr};  // 1ª faixa
mpv_command(m_mpv, args);
const char *args2[] = {"loadfile", path2.constData(), "append-play", nullptr}; // seguintes
mpv_command(m_mpv, args2);
```

**Por quê:** `gapless-audio` (seção 2) só funciona na troca INTERNA de entrada de playlist do
mpv — é o próprio mpv que decide manter o dispositivo de áudio aberto entre uma entrada e a
próxima. Se o C++ gerenciar a fila por fora (parar o handle, trocar arquivo, tocar de novo),
cada troca vira um `mpv_command("loadfile", ..., "replace")` do zero e o gapless se perde —
mpv não tem contexto de "isso é uma sequência", vê dois `mpv_initialize`/loads desconexos.

Isso amarra a fatia de biblioteca: o C++ só precisa **alimentar a playlist do mpv** (via
`loadfile ... append`/`append-play`, ou `playlist-clear` + reconstrução) e observar
`playlist-pos`/`media-title`/`path` pra saber o que está tocando agora — a ordem de
reprodução em si (próxima faixa, shuffle, repeat) tanto pode vir dos comandos
`playlist-next`/`playlist-prev`/`playlist-shuffle` do mpv quanto ser pré-computada pelo C++
antes de popular a playlist (mais fácil de testar e de casar com "coleções" do domínio
melodia). Confirmado rodando (§9): duas faixas em sequência tocaram sem intervenção do
código entre uma e outra.

## 5. Estado observável para a UI

Via `mpv_observe_property(mpv_handle*, uint64_t reply_userdata, const char *name, mpv_format format)`
— dispara `MPV_EVENT_PROPERTY_CHANGE` com um `mpv_event_property*` em `event->data`
(`client.h:1390-1414`: struct tem `name`, `format`, `data`).

| Propriedade                          | `mpv_format`                                                  | Tipo em `mpv_event_property.data` | Fonte                                                                                                                   |
| ------------------------------------ | ------------------------------------------------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `time-pos`                           | `MPV_FORMAT_DOUBLE`                                           | `double*`                         | `man mpv` "time-pos (RW)"                                                                                               |
| `duration`                           | `MPV_FORMAT_DOUBLE`                                           | `double*`                         | `man mpv` "duration"                                                                                                    |
| `pause`                              | `MPV_FORMAT_FLAG`                                             | `int*` (0/1)                      | `man mpv` "pause (RW)"                                                                                                  |
| `eof-reached`                        | `MPV_FORMAT_FLAG`                                             | `int*`                            | `man mpv` "eof-reached" — só é útil de fato com `keep-open=yes`, senão a próxima faixa carrega antes de você ler o flag |
| `idle-active`                        | `MPV_FORMAT_FLAG`                                             | `int*`                            | `man mpv` "idle-active" — playlist acabou e não há próximo arquivo                                                      |
| `metadata`                           | `MPV_FORMAT_NODE_MAP`                                         | `mpv_node*` (mapa tag→valor)      | `man mpv` "metadata"                                                                                                    |
| `media-title`                        | `MPV_FORMAT_STRING`                                           | `char**`                          | `man mpv` "media-title"                                                                                                 |
| `audio-params/samplerate`, `/format` | sub-propriedades de `audio-params`, formatos `INT64`/`STRING` | —                                 | `man mpv` "audio-params"                                                                                                |

`MPV_EVENT_END_FILE` (não é property change, é evento próprio) carrega
`mpv_event_end_file*` com `reason` (`mpv_end_file_reason`: `EOF=0, STOP=2, QUIT=3, ERROR=4,
REDIRECT=5`) — é como você detecta erro de decodificação sem polling
(`client.h:1461-1494`).

## 6. `AudioEngine : public QObject` — header + implementação

Compilado e rodado de verdade (§9). `pause`/`play`/`toggle` usam `mpv_set_property` direto
na propriedade `pause` (RW) em vez do comando `cycle pause` — é síncrono, tipado, sem passar
por parsing de string de comando.

**AudioEngine.h**

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQmlIntegration/qqmlintegration.h> // NÃO <QtQml/qqmlregistration.h> — ver §7 nota moc

struct mpv_handle;
struct mpv_event;

class AudioEngine : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)

public:
    // headlessAo=true força --ao=null (teste automatizado, nunca abre dispositivo real).
    explicit AudioEngine(QObject *parent = nullptr, bool headlessAo = false);
    ~AudioEngine() override;

    double position() const { return m_position; }
    double duration() const { return m_duration; }
    bool playing() const { return m_playing; }
    double volume() const { return m_volume; }
    QString currentFile() const { return m_currentFile; }
    void setVolume(double v);

public slots:
    void play();
    void pause();
    void togglePause();
    void seek(double seconds);
    void next();
    void previous();
    void loadPlaylist(const QStringList &files);

signals:
    void positionChanged();
    void durationChanged();
    void playingChanged();
    void volumeChanged();
    void currentFileChanged();
    void mpvInitError(const QString &message);

private slots:
    void onMpvEvents();

private:
    static void wakeup(void *ctx);
    void handleEvent(mpv_event *event);
    void setOption(const char *name, const char *value);

    mpv_handle *m_mpv = nullptr;
    double m_position = 0.0;
    double m_duration = 0.0;
    bool m_playing = false;
    double m_volume = 100.0;
    QString m_currentFile;
};
```

**AudioEngine.cpp** (trechos essenciais; o teste real em §9 tem o arquivo completo)

```cpp
#include "AudioEngine.h"
#include <mpv/client.h>
#include <clocale>

enum PropertyId : uint64_t { PROP_TIME_POS = 1, PROP_DURATION = 2, PROP_PAUSE = 3, PROP_MEDIA_TITLE = 4 };

AudioEngine::AudioEngine(QObject *parent, bool headlessAo) : QObject(parent)
{
    // OBRIGATÓRIO antes de mpv_create(): locale pt_BR (vírgula decimal) faz
    // mpv_create() falhar (client.h:147-149, comprovado na §9 — ver gotcha).
    std::setlocale(LC_NUMERIC, "C");

    m_mpv = mpv_create();
    if (!m_mpv) { emit mpvInitError(QStringLiteral("mpv_create failed")); return; }

    setOption("audio-display", "no");   // sem faixa de vídeo pra capa de álbum
    setOption("vo", "null");
    setOption("video", "no");
    if (headlessAo) setOption("ao", "null");
    setOption("gapless-audio", "yes");
    setOption("replaygain", "track");
    setOption("replaygain-clip", "no");
    setOption("hr-seek", "yes");
    // audio-samplerate / audio-format: NÃO setar (ver §2)

    int status = mpv_initialize(m_mpv);
    if (status < 0) {
        emit mpvInitError(QString::fromUtf8(mpv_error_string(status)));
        mpv_destroy(m_mpv);
        m_mpv = nullptr;
        return;
    }

    mpv_observe_property(m_mpv, PROP_TIME_POS, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, PROP_DURATION, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, PROP_PAUSE, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, PROP_MEDIA_TITLE, "media-title", MPV_FORMAT_STRING);
    mpv_set_wakeup_callback(m_mpv, &AudioEngine::wakeup, this);
}

AudioEngine::~AudioEngine()
{
    if (m_mpv) {
        mpv_set_wakeup_callback(m_mpv, nullptr, nullptr); // para de acordar antes de destruir
        mpv_terminate_destroy(m_mpv); // bloqueia até o player realmente desligar
        m_mpv = nullptr;
    }
}

void AudioEngine::setOption(const char *name, const char *value) { mpv_set_option_string(m_mpv, name, value); }

void AudioEngine::play()  { int f = 0; mpv_set_property(m_mpv, "pause", MPV_FORMAT_FLAG, &f); }
void AudioEngine::pause() { int f = 1; mpv_set_property(m_mpv, "pause", MPV_FORMAT_FLAG, &f); }
void AudioEngine::togglePause() { m_playing ? pause() : play(); }

void AudioEngine::loadPlaylist(const QStringList &files)
{
    if (!m_mpv || files.isEmpty()) return;
    for (int i = 0; i < files.size(); ++i) {
        QByteArray path = files.at(i).toUtf8();
        const char *mode = (i == 0) ? "replace" : "append";
        const char *args[] = {"loadfile", path.constData(), mode, nullptr};
        mpv_command(m_mpv, args);
    }
}

void AudioEngine::wakeup(void *ctx)
{
    QMetaObject::invokeMethod(static_cast<AudioEngine *>(ctx), "onMpvEvents", Qt::QueuedConnection);
}

void AudioEngine::onMpvEvents()
{
    if (!m_mpv) return;
    while (true) {
        mpv_event *event = mpv_wait_event(m_mpv, 0);
        if (event->event_id == MPV_EVENT_NONE) break;
        handleEvent(event);
    }
}

void AudioEngine::handleEvent(mpv_event *event)
{
    switch (event->event_id) {
    case MPV_EVENT_PROPERTY_CHANGE: {
        auto *prop = static_cast<mpv_event_property *>(event->data);
        if (event->reply_userdata == PROP_TIME_POS && prop->format == MPV_FORMAT_DOUBLE) {
            m_position = *static_cast<double *>(prop->data); emit positionChanged();
        } else if (event->reply_userdata == PROP_PAUSE && prop->format == MPV_FORMAT_FLAG) {
            m_playing = (*static_cast<int *>(prop->data)) == 0; emit playingChanged();
        }
        // duration / media-title: mesmo padrão, omitido por espaço
        break;
    }
    case MPV_EVENT_END_FILE: {
        auto *ef = static_cast<mpv_event_end_file *>(event->data);
        if (ef->reason == MPV_END_FILE_REASON_ERROR)
            qWarning() << "mpv playback error:" << mpv_error_string(ef->error);
        break;
    }
    case MPV_EVENT_SHUTDOWN: m_mpv = nullptr; break;
    default: break;
    }
}
```

`seek`/`next`/`previous` seguem o mesmo padrão de `loadPlaylist` (montar `const char*
args[]` e chamar `mpv_command`) — omitidos aqui, presentes no arquivo testado.

## 7. Build: CMake + gotcha do `moc`

```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Qml)
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
target_link_libraries(melodia PRIVATE Qt6::Core Qt6::Qml PkgConfig::MPV)
```

Não existe `mpv.pc` com `Requires:` estranho, então `pkg_check_modules(... mpv)` basta —
sem CMake config próprio do libmpv (ao contrário do mpvqt, que só existe via
`find_package(MpvQt)`).

**Gotcha real, pego rodando o `moc` manualmente fora do CMake (§9):** as flags de
`pkg-config --cflags mpv` incluem `-pthread`. Se você passar essas flags pro `moc` (em vez
de só pro compilador), o `moc` interpreta `-pthread` como a SUA PRÓPRIA flag `-p<path>`
("ignora esse prefixo de path ao gerar o `#include`") com argumento `thread` — e o arquivo
`moc_AudioEngine.cpp` gerado vira `#include "thread/AudioEngine.h"`, que não existe.
`qt_add_qml_module`/`qt_wrap_cpp` do CMake não expõem essa colisão porque não repassam as
flags de bibliotecas C para o `moc`, só as de include do próprio alvo Qt — mas se algum dia
você (ou um plano futuro) invocar `moc` manual num script, é isso que vai quebrar. Regra:
`moc` só recebe flags que digam respeito a resolver `#include`s do Qt no header, nunca as
`--cflags` de uma lib C qualquer.

## 8. Teste headless

`AudioEngine(nullptr, /*headlessAo=*/true)` seta `ao=null` antes de `mpv_initialize` — nunca
abre PipeWire/ALSA, zero som audível, roda em CI sem placa de som. Fixture: qualquer `.wav`
pequeno serve (`/usr/share/sounds/alsa/Front_Center.wav` já existe em qualquer Fedora com
`alsa-utils`, ~137KB, ~1.4s — bom o bastante pra smoke test; para testar gapless real entre
duas faixas de propósito, gerar 2 FLACs curtos com `ffmpeg -f lavfi -i "sine=440:d=2"
out.flac`).

Comando de verificação (o que um plano de fatia deve rodar em terminal/CI):

```sh
./melodia_audioengine_smoketest /caminho/fixture1.wav /caminho/fixture2.wav
# sucesso = process sai 0 dentro de N segundos E os sinais duration/position/currentFile
# dispararam pelo menos uma vez cada (grep no stderr, ou um pequeno harness que conta
# emissões de sinal e faz exit(1) se algum ficou em zero).
```

## 9. Evidência de compilação e execução (não hipotético)

Rodado neste Fedora 43 (arquivos em
`/tmp/claude-1000/.../scratchpad/audioengine_test/`, não commitados):

```
$ g++ -std=c++20 -fPIC $(pkg-config --cflags Qt6Core Qt6Qml Qt6QmlIntegration mpv) \
      -c AudioEngine.cpp -o AudioEngine.o        # exit 0
$ /usr/lib64/qt6/libexec/moc AudioEngine.h -o moc_AudioEngine.cpp \
      $(pkg-config --cflags Qt6Core Qt6Qml Qt6QmlIntegration)   # SEM as flags do mpv — ver §7
$ g++ ... -c moc_AudioEngine.cpp -o moc_AudioEngine.o            # exit 0
$ g++ AudioEngine.o moc_AudioEngine.o main.o -o audioengine_test \
      $(pkg-config --libs Qt6Core Qt6Qml Qt6QmlIntegration mpv)  # link exit 0

$ ./audioengine_test /usr/share/sounds/alsa/Front_Center.wav /usr/share/sounds/alsa/Front_Left.wav
playing = 1
currentFile = Front_Center.wav
duration = 1.428021
position = 0.035690
... (mais eventos position) ...
currentFile = Front_Left.wav      # troca de faixa via playlist interna do mpv, sem
duration = 1.480042               # nenhuma chamada de C++ entre uma faixa e outra —
position = 0.004344               # confirma a decisão da seção 4.
```

**Gotcha extra pego ao vivo (não estava no plano original), útil pro dono do projeto:** com
o `LANG=pt_BR.UTF-8` do sistema do Pedro (vírgula como separador decimal), `mpv_create()`
falhava silenciosamente sem o `setlocale(LC_NUMERIC, "C")` — é exigência documentada no
próprio `client.h:147-149`, mas fácil de esquecer porque o sintoma (`mpv_create()` retorna
`NULL`, ou nesse caso a lib imprimiu um aviso e abortou o processo) não aponta pra causa.
Isso já está no `AudioEngine::AudioEngine()` do §6.

## Não verificado / risco aberto

- Comportamento fino do PipeWire (resample no grafo mesmo com `audio-exclusive=yes`) — só
  dá pra confirmar com hardware/arquivo 96kHz real e uma sonda no ponto ALSA (§2.1).
- Empacotamento exato do libmpv no Windows (nome do import lib gerado, se MinGW ou MSVC) —
  não há máquina Windows nesta pesquisa; só a existência dos builds oficiais foi confirmada
  por conhecimento de ecossistema, não testada aqui.
- `qDebug()`/`qWarning()` não imprimiram nada no ambiente sandboxed desta pesquisa (troquei
  por `fprintf(stderr, ...)` pra provar o teste) — provável regra de logging do sandbox, não
  necessariamente reproduz em terminal normal; vale conferir ao rodar o smoke test de
  verdade no plano de execução.
