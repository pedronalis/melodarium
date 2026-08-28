---
slug: fila-motor
feature: melodia-religa
status: aprovado
depende-de: []
decisao-humana: nao
spec: docs/auditoria-completude.md (achados 13,14,15) · design/Main.dc.html:141-152
---

# Plano: fila-motor

**Goal:** Dar ao app uma fila de verdade — consultável, com posição conhecida e que aceita
receber uma faixa no fim sem interromper o que toca. Sem tela nenhuma: esta fatia é o motor
que as fatias `fila-tirinha` e `shuffle-repeat` consomem.

**Arquitetura:** Hoje a ordem de reprodução existe em dois lugares desencontrados: dentro do
mpv (que a conhece de verdade) e numa variável de QML (`root.queuePaths`) que é escrita e
nunca lida. Nenhum dos dois é consultável por um componente de tela.

O `AudioEngine` passa a ser a fonte única: guarda `m_queue` espelhando exatamente o que
mandou ao mpv, expõe como `Q_PROPERTY QStringList queue`, e emite `queueChanged()` a cada
alteração. `appendToQueue` usa `loadfile <file> append`, que é o mesmo verbo que o
`loadPlaylist` já usa para as entradas de índice ≥ 1 — a fila continua **interna ao mpv**,
que é o que preserva o gapless entre faixas.

**Por que espelhar em C++ em vez de ler do mpv:** ler `playlist/N/filename` é uma consulta
por entrada, assíncrona, e a tirinha de capas precisaria de quatro delas por repintura. O
espelho custa uma `QStringList`.

**Constraints globais:** Qt 6.10.3, C++20, libmpv. **PERIGO:** `std::setlocale(LC_NUMERIC,
"C")` antes de `mpv_create()` é obrigatório e já está no construtor — não mexer nessa ordem.
Nenhuma opção nova de `sample-rate` ou formato de amostra pode entrar no construtor: o
contrato de qualidade do spec proíbe conversão no caminho, e o próprio arquivo tem um
comentário explicando por que esses nomes não aparecem nele.

## Arquivos

- Modificar: `src/audioengine.h` · `src/audioengine.cpp`
- Modificar: `tests/tst_audioengine.cpp`
- Criar: nenhum · Testar: `tests/tst_audioengine.cpp`

## Interfaces

- Consome: nada de outra fatia (folha).
- Produz, todos em `src/audioengine.h`:
  - `Q_PROPERTY(QStringList queue READ queue NOTIFY queueChanged)` — os caminhos na ordem
    em que serão tocados. Vazia quando nada foi carregado.
  - `Q_PROPERTY(int queueCount READ queueCount NOTIFY queueChanged)` — `queue().size()`.
  - `Q_INVOKABLE void appendToQueue(const QString &file)` — põe no fim sem interromper o
    que toca. Se a fila estiver vazia, carrega e **não** começa a tocar (o app só toca
    quando alguém pede — regra já vigente em `Main.qml`).
  - `Q_INVOKABLE QStringList upcoming(int limit) const` — os próximos `limit` caminhos
    depois de `playlistPos`, sem incluir o que toca. Lista vazia quando não há próximos.
  - `signals: void queueChanged();`
  - `AudioEngine::playlistPos` (já existente) continua sendo o índice do que toca.

  Consumido por `src/QueueStrip.qml` e `src/Main.qml` (fatia `fila-tirinha`) e por
  `src/audioengine.cpp` (fatia `shuffle-repeat`).

## Tasks

### Task 1: A fila vira estado consultável do motor

- [x] Escrever o teste que falha, em `tests/tst_audioengine.cpp`, dentro de
      `private slots:`:

```cpp
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
```

- [x] Rodar e confirmar que falha pelo motivo certo:
      `cmake --build build --target tst_audioengine` → erro de compilação
      `no member named 'queue' in 'AudioEngine'`
- [x] Declarar em `src/audioengine.h`. Junto das outras `Q_PROPERTY`, depois da linha do
      `speed`:

```cpp
    Q_PROPERTY(QStringList queue READ queue NOTIFY queueChanged)
    Q_PROPERTY(int queueCount READ queueCount NOTIFY queueChanged)
```

- [x] No mesmo arquivo, junto dos outros getters inline, depois de
      `double speed() const { return m_speed; }`:

```cpp
    QStringList queue() const { return m_queue; }
    int queueCount() const { return m_queue.size(); }
```

- [x] No mesmo arquivo, junto dos `Q_INVOKABLE`, depois de
      `Q_INVOKABLE void loadPlaylist(const QStringList &files, int startIndex = 0);`:

```cpp
    // Pôr no fim sem interromper o que toca. Com a fila vazia, carrega e NÃO começa a
    // tocar: o app só toca quando alguém pede.
    Q_INVOKABLE void appendToQueue(const QString &file);
    // Os próximos `limit` caminhos, sem incluir o que toca — é o que a tirinha desenha.
    Q_INVOKABLE QStringList upcoming(int limit) const;
```

- [x] No mesmo arquivo, junto dos sinais, depois de `void speedChanged();`:

```cpp
    void queueChanged();
```

- [x] No mesmo arquivo, junto dos membros privados, depois de `double m_speed = 1.0;`:

```cpp
    // Espelho do que foi mandado ao mpv. Ler playlist/N/filename seria uma consulta por
    // entrada a cada repintura da tirinha de capas.
    QStringList m_queue;
```

- [x] Em `src/audioengine.cpp`, substituir `loadPlaylist` inteiro para manter o espelho:

```cpp
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

    m_queue = files;
    emit queueChanged();
}
```

- [x] No mesmo arquivo, acrescentar as duas funções novas logo depois de `loadPlaylist`:

```cpp
void AudioEngine::appendToQueue(const QString &file)
{
    if (!m_mpv || file.isEmpty())
        return;
    // "append" e não "append-play": pôr no fim é um gesto de organizar a fila, não de
    // mandar tocar. Quem quiser tocar chama play().
    command({QStringLiteral("loadfile"), file, QStringLiteral("append")});
    m_queue.append(file);
    emit queueChanged();
}

QStringList AudioEngine::upcoming(int limit) const
{
    if (limit <= 0 || m_queue.isEmpty())
        return {};
    const int first = m_playlistPos < 0 ? 0 : m_playlistPos + 1;
    if (first >= m_queue.size())
        return {};
    return m_queue.mid(first, limit);
}
```

- [x] verificação mecânica da task:
      `quiet-run ctest --test-dir build -R tst_audioengine --output-on-failure`
      → `100% tests passed`
- [x] verificação mecânica da task — o contrato de qualidade continua intacto:
      `grep -cE 'audio-samplerate|audio-format|af=' src/audioengine.cpp` → `0`
- [x] commit:

```bash
git add src/audioengine.h src/audioengine.cpp tests/tst_audioengine.cpp docs/plans/2026-08-28-fila-motor.md
git commit -m "feat(audio): the queue becomes readable state with append and lookahead"
```

### Task 2: A tela para de guardar uma fila que ninguém lê

- [ ] Em `src/Main.qml`, apagar a propriedade `queuePaths` — ela era escrita em três
      lugares e lida em nenhum. Remover a declaração:

```qml
    // The order the engine is playing, kept here because the queue drawer left this design.
    property var queuePaths: []
```

- [ ] No mesmo arquivo, em `activateTrack`, tirar a escrita morta:

```qml
    function activateTrack(index) {
        AudioEngine.loadPlaylist(trackModel.allPaths(), index)
        AudioEngine.play()
    }
```

- [ ] No mesmo arquivo, em `startFromEmpty`, tirar a outra escrita morta — a linha
      `root.queuePaths = paths` some, e `AudioEngine.loadPlaylist(paths, 0)` fica:

```qml
        if (paths.length === 0)
            return
        if (mode === "shuffle") {
            // Fisher-Yates: sortear índice a cada passo, não ordenar por número aleatório.
            for (let i = paths.length - 1; i > 0; --i) {
                const j = Math.floor(Math.random() * (i + 1))
                const tmp = paths[i]
                paths[i] = paths[j]
                paths[j] = tmp
            }
        }
        AudioEngine.loadPlaylist(paths, 0)
        AudioEngine.play()
```

- [ ] verificação mecânica da task:
      `grep -c 'queuePaths' src/Main.qml` → `0`
- [ ] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/Main.qml docs/plans/2026-08-28-fila-motor.md
git commit -m "chore(ui): drop the write-only queue variable now that the engine owns it"
```

## Verificação da fatia (E2E)

- `quiet-run cmake --build build` → exit 0
- `quiet-run ctest --test-dir build --output-on-failure` → `100% tests passed` com
  `Total Tests: 9` ou mais
- `grep -c 'queueChanged' src/audioengine.h` → `3`
- `grep -c 'queuePaths' src/Main.qml` → `0`
- `grep -cE 'audio-samplerate|audio-format|af=' src/audioengine.cpp` → `0`
  (o contrato de qualidade do spec: nenhuma conversão no caminho)
- `bash tools/check-orfaos.sh` → lista `appendToQueue` e `upcoming` como ainda sem
  chamador, o que é **esperado**: a tela deles é a fatia `fila-tirinha`

## Fora de escopo

- Reordenar a fila (mover uma entrada de lugar): ninguém pediu, e `playlist-move` do mpv
  quebraria o espelho sem uma segunda passada de sincronização.
- Tirar uma entrada da fila.
- Persistir a fila entre execuções do app.
- Aleatório e repetir sobre esta fila: fatia `shuffle-repeat`, que consome
  `queue()`/`queueCount()` daqui.
