---
slug: shuffle-repeat
feature: melodia-religa
status: concluido
depende-de: [fila-motor]
decisao-humana: sim
spec: docs/auditoria-completude.md (achados 10,11,12) · design/Main.dc.html
---

# Plano: shuffle-repeat

**Goal:** Os dois botões param de mentir. Hoje aleatório e repetir estão ao lado do play,
acendem no hover, têm cursor de mãozinha — e o clique não faz absolutamente nada. Decisão do
Pedro em 2026-08-28: **ligar de verdade**, não remover.

**Arquitetura:** Os dois modos passam a ser estado do motor, não da tela, porque quem os
aplica é o mpv:

- **Repetir** é a propriedade `loop-playlist` do mpv, em três posições: `"no"` (nada) →
  `"inf"` (a fila inteira) → uma faixa. A terceira posição usa `loop-file=inf`, que é
  propriedade separada — as duas não são o mesmo botão do mpv, e é por isso que o
  `AudioEngine` expõe um enum de três valores em vez de dois booleanos soltos.
- **Aleatório** embaralha a **fila corrente**, não a biblioteca inteira. Hoje o único
  aleatório do app (o da tela de boas-vindas) embaralha as 27 faixas todas, uma vez, sem
  como desligar — e some da tela no instante em que a música começa. Ligar o aleatório
  reembaralha o que está na fila a partir da posição seguinte, preservando o que toca;
  desligar restaura a ordem original, que o motor guarda.

Os dois ganham **estado visível**: hoje, mesmo se funcionassem, não haveria como saber se
estão ativos. `IconButton` já tem `accent`, que é o que o resto do app usa para "ligado".

**Constraints globais:** Qt 6.10.3, C++20, libmpv. A ordem original da fila é guardada em
`m_queueOriginal` — sem ela, desligar o aleatório não tem para onde voltar. Nenhuma opção de
conversão de áudio entra no construtor (contrato de qualidade do spec).

## Arquivos

- Modificar: `src/audioengine.h` · `src/audioengine.cpp`
- Modificar: `src/NowPlayingPanel.qml` · `src/EmptyPane.qml` · `src/Main.qml`
- Modificar: `tests/tst_audioengine.cpp`
- Criar: nenhum · Testar: `tests/tst_audioengine.cpp`

## Interfaces

- Consome: `AudioEngine::queue()`, `queueCount()`, `m_queue`, `queueChanged()`,
  `playlistPos()` — produzidos pela fatia `fila-motor`.
- Consome: `IconButton` com `property bool accent` (existente, `src/IconButton.qml:9`).
- Produz, em `src/audioengine.h`:
  - `enum RepeatMode { RepeatOff, RepeatAll, RepeatOne }`, exposto com `Q_ENUM` — em QML,
    `AudioEngine.RepeatOff`, `AudioEngine.RepeatAll`, `AudioEngine.RepeatOne`.
  - `Q_PROPERTY(RepeatMode repeatMode READ repeatMode NOTIFY repeatModeChanged)`
  - `Q_PROPERTY(bool shuffle READ shuffle NOTIFY shuffleChanged)`
  - `Q_INVOKABLE void cycleRepeat()` — avança `Off → All → One → Off`.
  - `Q_INVOKABLE void setShuffle(bool on)` — embaralha a fila a partir da próxima entrada,
    ou restaura a ordem original.
  - `signals: void repeatModeChanged(); void shuffleChanged();`

  Consumidos por `src/NowPlayingPanel.qml`.

## Tasks

### Task 1: Repetir em três posições, no motor

- [x] Escrever o teste que falha, em `tests/tst_audioengine.cpp`, dentro de
      `private slots:`:

```cpp
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
```

- [x] Rodar e confirmar que falha pelo motivo certo:
      `cmake --build build --target tst_audioengine` → erro de compilação
      `no member named 'repeatMode' in 'AudioEngine'`
- [x] Declarar em `src/audioengine.h`, no bloco `public:` **antes** do construtor (um
      `Q_ENUM` precisa do tipo declarado antes de qualquer `Q_PROPERTY` que o use):

```cpp
    // Três posições porque o mpv tem duas propriedades distintas: loop-playlist (a fila) e
    // loop-file (a faixa). Um par de booleanos deixaria as duas ligadas ao mesmo tempo.
    enum RepeatMode { RepeatOff, RepeatAll, RepeatOne };
    Q_ENUM(RepeatMode)
```

- [x] No mesmo arquivo, junto das outras `Q_PROPERTY`:

```cpp
    Q_PROPERTY(RepeatMode repeatMode READ repeatMode NOTIFY repeatModeChanged)
```

- [x] No mesmo arquivo, junto dos getters inline:

```cpp
    RepeatMode repeatMode() const { return m_repeatMode; }
```

- [x] No mesmo arquivo, junto dos `Q_INVOKABLE`:

```cpp
    // Avança Off → All → One → Off. Um botão só, como no desenho.
    Q_INVOKABLE void cycleRepeat();
```

- [x] No mesmo arquivo, junto dos sinais:

```cpp
    void repeatModeChanged();
```

- [x] No mesmo arquivo, junto dos membros privados:

```cpp
    RepeatMode m_repeatMode = RepeatOff;
```

- [x] Implementar em `src/audioengine.cpp`, depois de `AudioEngine::upcoming`:

```cpp
void AudioEngine::cycleRepeat()
{
    switch (m_repeatMode) {
    case RepeatOff:  m_repeatMode = RepeatAll; break;
    case RepeatAll:  m_repeatMode = RepeatOne; break;
    case RepeatOne:  m_repeatMode = RepeatOff; break;
    }

    // As duas propriedades são escritas sempre, as duas: deixar a anterior ligada faria
    // "repetir a faixa" e "repetir a fila" valerem ao mesmo tempo.
    setPropertyString("loop-playlist", m_repeatMode == RepeatAll ? "inf" : "no");
    setPropertyString("loop-file", m_repeatMode == RepeatOne ? "inf" : "no");

    emit repeatModeChanged();
}
```

- [x] verificação mecânica da task:
      `quiet-run ctest --test-dir build -R tst_audioengine --output-on-failure`
      → `100% tests passed`
- [x] commit:

```bash
git add src/audioengine.h src/audioengine.cpp tests/tst_audioengine.cpp docs/plans/2026-08-28-shuffle-repeat.md
git commit -m "feat(audio): repeat in three positions, playlist and single file"
```

### Task 2: Aleatório sobre a fila corrente, reversível

- [x] Escrever o teste que falha, em `tests/tst_audioengine.cpp`:

```cpp
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
```

- [x] Declarar em `src/audioengine.h`, junto das `Q_PROPERTY`:

```cpp
    Q_PROPERTY(bool shuffle READ shuffle NOTIFY shuffleChanged)
```

- [x] No mesmo arquivo, junto dos getters inline:

```cpp
    bool shuffle() const { return m_shuffle; }
```

- [x] No mesmo arquivo, junto dos `Q_INVOKABLE`:

```cpp
    // Embaralha a fila a partir da PRÓXIMA entrada (o que toca não muda de lugar), ou
    // devolve a ordem original.
    Q_INVOKABLE void setShuffle(bool on);
```

- [x] No mesmo arquivo, junto dos sinais:

```cpp
    void shuffleChanged();
```

- [x] No mesmo arquivo, junto dos membros privados:

```cpp
    bool m_shuffle = false;
    // Sem isto, desligar o aleatório não tem para onde voltar.
    QStringList m_queueOriginal;
```

- [x] Implementar em `src/audioengine.cpp`, depois de `cycleRepeat`. Note o
      `#include <QRandomGenerator>` no topo do arquivo, junto dos outros includes:

```cpp
void AudioEngine::setShuffle(bool on)
{
    if (!m_mpv || m_shuffle == on)
        return;

    if (on) {
        m_queueOriginal = m_queue;
        const int atual = m_playlistPos < 0 ? -1 : m_playlistPos;
        // Fisher-Yates a partir da PRÓXIMA entrada: embaralhar o que já está tocando
        // faria o mpv recarregar o arquivo no meio da faixa.
        for (int i = m_queue.size() - 1; i > atual + 1; --i) {
            const int j = atual + 1
                          + int(QRandomGenerator::global()->bounded(i - atual));
            m_queue.swapItemsAt(i, j);
        }
    } else {
        if (m_queueOriginal.isEmpty())
            return;
        m_queue = m_queueOriginal;
        m_queueOriginal.clear();
    }

    m_shuffle = on;
    reloadQueueKeepingCurrent();
    emit shuffleChanged();
    emit queueChanged();
}

// Reescreve a playlist do mpv a partir de m_queue, mantendo tocando o mesmo arquivo.
void AudioEngine::reloadQueueKeepingCurrent()
{
    if (!m_mpv || m_queue.isEmpty())
        return;
    const QString tocando = m_currentFile;
    for (int i = 0; i < m_queue.size(); ++i) {
        const QString mode = (i == 0) ? QStringLiteral("replace") : QStringLiteral("append");
        command({QStringLiteral("loadfile"), m_queue.at(i), mode});
    }
    const int destino = tocando.isEmpty() ? 0 : int(m_queue.indexOf(tocando));
    if (destino > 0)
        setPropertyString("playlist-pos", QByteArray::number(destino).constData());
}
```

- [x] Declarar o auxiliar em `src/audioengine.h`, junto dos outros métodos privados
      (depois de `void command(const QStringList &args);`):

```cpp
    void reloadQueueKeepingCurrent();
```

- [x] Em `src/audioengine.cpp`, no fim de `loadPlaylist`, zerar o aleatório — a ordem
      guardada era da fila anterior. Substituir as duas últimas linhas da função por:

```cpp
    m_queue = files;
    // A ordem guardada era da fila que acabou de sair; restaurá-la sobre esta devolveria
    // faixas que não estão mais aqui.
    if (m_shuffle) {
        m_shuffle = false;
        emit shuffleChanged();
    }
    m_queueOriginal.clear();
    emit queueChanged();
```

- [x] verificação mecânica da task:
      `quiet-run ctest --test-dir build -R tst_audioengine --output-on-failure`
      → `100% tests passed`
- [x] commit:

```bash
git add src/audioengine.h src/audioengine.cpp tests/tst_audioengine.cpp docs/plans/2026-08-28-shuffle-repeat.md
git commit -m "feat(audio): shuffle the current queue, reversibly"
```

### Task 3: Os dois botões passam a fazer e a mostrar

- [x] Em `src/NowPlayingPanel.qml`, substituir o `IconButton` do aleatório (o que hoje tem
      `onClicked: {}`) por:

```qml
            IconButton {
                visible: !root.episodeMode
                icon: "shuffle"
                size: Theme.fontSizeL
                // Sem estado visível, um botão ligado é indistinguível de um desligado.
                accent: AudioEngine.shuffle
                tooltip: AudioEngine.shuffle ? qsTr("aleatório ligado") : qsTr("aleatório")
                onClicked: AudioEngine.setShuffle(!AudioEngine.shuffle)
            }
```

- [x] No mesmo arquivo, substituir o `IconButton` do repetir (o outro `onClicked: {}`) por:

```qml
            IconButton {
                visible: !root.episodeMode
                icon: "repeat"
                size: Theme.fontSizeL
                accent: AudioEngine.repeatMode !== AudioEngine.RepeatOff
                // O terceiro estado precisa se distinguir do segundo por mais do que a cor:
                // um "1" sobreposto é o que diz "esta faixa" em vez de "a fila".
                tooltip: AudioEngine.repeatMode === AudioEngine.RepeatOne
                         ? qsTr("repetir esta faixa")
                         : (AudioEngine.repeatMode === AudioEngine.RepeatAll
                            ? qsTr("repetir a fila") : qsTr("repetir"))
                onClicked: AudioEngine.cycleRepeat()

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: Math.round(2 * Theme.uiScale)
                    visible: AudioEngine.repeatMode === AudioEngine.RepeatOne
                    text: "1"
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeXXS
                    font.weight: Theme.fontWeightBold
                    color: Theme.mPrimary
                }
            }
```

- [x] verificação mecânica da task:
      `grep -c 'onClicked: {}' src/NowPlayingPanel.qml` → `0`
- [x] verificação mecânica da task:
      `grep -c 'AudioEngine.setShuffle\|AudioEngine.cycleRepeat' src/NowPlayingPanel.qml` → `2`
- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/NowPlayingPanel.qml docs/plans/2026-08-28-shuffle-repeat.md
git commit -m "feat(ui): shuffle and repeat do what they show, and show what they do"
```

### Task 4: O aleatório da tela vazia passa a ligar o modo

- [x] Em `src/Main.qml`, a função `startFromEmpty` embaralhava a lista uma vez, sem estado.
      Agora ela liga o modo do motor, que fica visível e desligável. Substituir o bloco do
      `mode === "shuffle"`:

```qml
        if (paths.length === 0)
            return
        AudioEngine.loadPlaylist(paths, 0)
        // Antes daqui o embaralhamento era feito à mão e sumia da tela junto com o convite:
        // ligar o modo do motor deixa o botão do painel aceso e desligável.
        if (mode === "shuffle")
            AudioEngine.setShuffle(true)
        AudioEngine.play()
```

- [x] verificação mecânica da task:
      `grep -c 'Fisher-Yates' src/Main.qml` → `0`
- [x] verificação mecânica da task:
      `grep -c 'AudioEngine.setShuffle' src/Main.qml` → `1`
- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/Main.qml docs/plans/2026-08-28-shuffle-repeat.md
git commit -m "fix(ui): the welcome shuffle turns the mode on instead of scrambling once"
```

## Verificação da fatia (E2E)

- `quiet-run cmake --build build` → exit 0
- `quiet-run ctest --test-dir build --output-on-failure` → `100% tests passed` com
  `Total Tests: 9` ou mais
- `grep -c 'onClicked: {}' src/NowPlayingPanel.qml` → `0` (nenhum botão inerte sobra)
- `grep -cE 'audio-samplerate|audio-format|af=' src/audioengine.cpp` → `0`
- `bash tools/check-layout.sh` → 11 medidas ok
- `./build/melodarium --measure --pane library --play-track "$(ls ~/Música/**/*.mp3 2>/dev/null | head -1)" --delay 2500 --shot /tmp/melodarium-transporte.png --no-search`
  → imprime `SHOT /tmp/melodarium-transporte.png`
- `bash tools/check-orfaos.sh` → não lista `cycleRepeat` nem `setShuffle`

## Fora de escopo

- Lembrar aleatório e repetir entre execuções do app: sem tela de ajustes não há onde
  guardar preferência, e a fatia `ajustes` é quem abre esse lugar.
- Aleatório "inteligente" (evitar repetir artista seguido): o spec põe análise automática
  fora de escopo.
- Aleatório e repetir na tela de podcast: um episódio não quer nenhum dos dois — os botões
  já são invisíveis em `episodeMode` e continuam.
