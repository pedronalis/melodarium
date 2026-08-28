---
slug: fila-tirinha
feature: melodia-religa
status: aprovado
depende-de: [fila-motor, clique-responde]
decisao-humana: sim
spec: design/Main.dc.html:141-152 · design/Busca.dc.html:330 · docs/auditoria-completude.md (achados 13,14,15)
---

# Plano: fila-tirinha

**Goal:** A queixa nº 2 do Pedro, literal: "ia ter uma fila ali embaixo com a capinha dos
discos, ia ter mais informação". Está no desenho aprovado, no pé da coluna do meio, e nunca
foi construída. Depois desta fatia o app mostra o que vem a seguir, diz quantas faltam, e
deixa pôr um resultado da busca no fim da fila sem interromper o que toca.

**Arquitetura:** Um componente novo, `QueueStrip.qml`, ancorado no pé do miolo — **na coluna
do meio**, não no painel da capa, que é onde o desenho o coloca
(`design/Main.dc.html:141-152`: rótulo "A seguir na fila", quatro quadrados de 62 px e um
"+2"). Ele lê `AudioEngine.upcoming(4)` e `AudioEngine.queueCount`, e resolve cada capa por
`CoverCache.coverUrlForTrack(path, 0)`.

**Sobre o segundo argumento de `coverUrlForTrack`:** ele é `Q_UNUSED` na implementação — a
capa é resolvida pelo caminho do arquivo, e o `albumId` sobrou de uma versão anterior. A
tirinha passa `0` e **não** vai atrás do id do álbum, que exigiria uma consulta por
quadradinho. Isso está registrado aqui porque um implementer de contexto zero olharia a
assinatura e iria buscar o id.

O `QueuePanel.qml` — a lista textual de nomes de arquivo, órfã desde o redesenho e que nunca
foi a tirinha do desenho — é **apagado** nesta fatia.

**Constraints globais:** Qt 6.10.3, QML. Todo tamanho por `Theme.uiScale`. A tirinha não
pode roubar altura da lista: ela é `visible` só quando há próximos, e some inteira quando a
fila acaba.

## Arquivos

- Criar: `src/QueueStrip.qml`
- Modificar: `src/LibraryPane.qml` · `src/SearchOverlay.qml` · `src/Main.qml` ·
  `CMakeLists.txt`
- Apagar: `src/QueuePanel.qml`
- Criar: nenhum teste novo (fatia de tela) · Testar: `tests/tst_audioengine.cpp` (existente,
  tem de continuar passando)

## Interfaces

- Consome: `AudioEngine.upcoming(int limit) -> QStringList` ·
  `AudioEngine.queueCount` (int) · `AudioEngine.queue` (QStringList) ·
  `AudioEngine.playlistPos` (int) · sinal `queueChanged()` — todos produzidos pela fatia
  `fila-motor`.
- Consome: `AudioEngine.appendToQueue(const QString &file)` (fatia `fila-motor`).
- Consome: `CoverCache.coverUrlForTrack(string trackPath, int albumId) -> string` —
  devolve `"file:///…"` ou `""`. O `albumId` é ignorado pela implementação; passe `0`.
- Consome: `LibraryPane` com o cabeçalho já existente (fatia `clique-responde`).
- Produz:
  - `QueueStrip.qml` — `property int lookahead: 4`, `signal entryActivated(int queueIndex)`.
    Consumido por `src/LibraryPane.qml`.
  - `LibraryPane.queueActivated(int queueIndex)` — sinal novo, repassa o da tirinha.
    Consumido por `src/Main.qml`.
  - `SearchOverlay.trackQueued(string path)` — sinal novo, emitido com Shift+Enter sobre um
    resultado de faixa ou episódio. Consumido por `src/Main.qml`.

## Tasks

### Task 1: A tirinha de capas

- [x] Criar `src/QueueStrip.qml`:

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodia.App

// "A seguir na fila": o rótulo, quatro capas pequenas e o quadradinho "+N" com quantas
// faltam (design/Main.dc.html:141-152). Mora no pé da coluna do meio, não no painel da
// capa — no desenho ele é o pé da LISTA.
Item {
    id: root

    property int lookahead: 4

    signal entryActivated(int queueIndex)

    // Some inteira quando não há próximos: uma tirinha vazia rouba altura da lista, que é o
    // ponto da tela.
    readonly property var proximos: AudioEngine.upcoming(root.lookahead)
    readonly property int restantes: Math.max(0, AudioEngine.queueCount
                                                 - (AudioEngine.playlistPos < 0
                                                    ? 0 : AudioEngine.playlistPos + 1)
                                                 - root.proximos.length)

    visible: root.proximos.length > 0
    implicitHeight: root.visible ? coluna.implicitHeight : 0

    ColumnLayout {
        id: coluna
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.marginS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS

            Text {
                text: qsTr("A seguir na fila")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXS
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurfaceVariant
            }
            Text {
                text: AudioEngine.queueCount + qsTr(" na fila")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOutline
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS

            Repeater {
                model: root.proximos

                Rectangle {
                    id: quadro

                    required property string modelData
                    required property int index

                    readonly property int lado: Math.round(62 * Theme.uiScale)

                    Layout.preferredWidth: quadro.lado
                    Layout.preferredHeight: quadro.lado
                    radius: Theme.radiusXS
                    color: Theme.mSurfaceVariant
                    clip: true
                    border.width: capaArea.containsMouse ? Theme.borderS : 0
                    border.color: Theme.mTertiary

                    Image {
                        id: capa
                        anchors.fill: parent
                        // O segundo argumento é ignorado pela implementação (a capa sai do
                        // caminho do arquivo). Passar 0 evita uma consulta por quadradinho.
                        source: CoverCache.coverUrlForTrack(quadro.modelData, 0)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: capa.status === Image.Ready
                        sourceSize.width: quadro.lado
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: capa.status !== Image.Ready
                        text: Icons.get("music")
                        font.family: Icons.fontFamily
                        font.pointSize: Theme.fontSizeL
                        color: Theme.mOutline
                    }

                    MouseArea {
                        id: capaArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // O índice na fila, não na tirinha: a tirinha começa depois do que
                        // está tocando.
                        onClicked: root.entryActivated(AudioEngine.playlistPos + 1 + quadro.index)
                    }
                }
            }

            // "+2": quantas faltam além das que couberam na tirinha.
            Rectangle {
                readonly property int lado: Math.round(62 * Theme.uiScale)

                Layout.preferredWidth: lado
                Layout.preferredHeight: lado
                visible: root.restantes > 0
                radius: Theme.radiusXS
                color: "transparent"
                border.width: Theme.borderS
                border.color: Theme.mSurfaceVariant

                Text {
                    anchors.centerIn: parent
                    text: "+" + root.restantes
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeS
                    color: Theme.mOnSurfaceVariant
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
```

- [x] Registrar em `CMakeLists.txt`, na lista `QML_FILES`, depois de `src/LibraryPane.qml`:

```cmake
        src/QueueStrip.qml
```

- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/QueueStrip.qml CMakeLists.txt docs/plans/2026-08-28-fila-tirinha.md
git commit -m "feat(ui): the up-next strip with covers and a +N tile"
```

### Task 2: A tirinha ganha o pé da lista

- [ ] Em `src/LibraryPane.qml`, declarar o sinal junto dos outros:

```qml
    signal queueActivated(int queueIndex)
```

- [ ] No mesmo arquivo, acrescentar a tirinha como **último filho** do `ColumnLayout`
      principal, depois do `ListView { id: groupList … }`:

```qml
        // O pé da lista, como no desenho: a fila mora aqui, não no painel da capa.
        QueueStrip {
            Layout.fillWidth: true
            onEntryActivated: function (queueIndex) { root.queueActivated(queueIndex) }
        }
```

- [ ] Em `src/Main.qml`, no `LibraryPane { id: libraryPane … }`, ligar o pulo na fila:

```qml
                onQueueActivated: function (queueIndex) {
                    AudioEngine.loadPlaylist(AudioEngine.queue, queueIndex)
                    AudioEngine.play()
                }
```

- [ ] verificação mecânica da task:
      `grep -c 'QueueStrip\|queueActivated' src/LibraryPane.qml` → `3`
- [ ] verificação mecânica da task:
      `bash tools/check-layout.sh` → 11 medidas ok (a tirinha não pode empurrar o layout;
      ela some quando a fila está vazia, que é o caso do gate)
- [ ] commit:

```bash
git add src/LibraryPane.qml src/Main.qml docs/plans/2026-08-28-fila-tirinha.md
git commit -m "feat(ui): the up-next strip sits at the foot of the library list"
```

### Task 3: Shift+Enter põe o resultado da busca na fila

- [ ] Em `src/SearchOverlay.qml`, declarar o sinal junto dos outros:

```qml
    signal trackQueued(string path)
```

- [ ] No mesmo arquivo, acrescentar a função que enfileira sem fechar o overlay — quem
      está montando uma fila quer montar várias de seguida:

```qml
    // Pôr na fila não fecha a busca: quem enfileira quer enfileirar mais de uma.
    function queueAt(index) {
        const hit = root.hitAt(index)
        if (hit === null || hit.path === undefined || hit.path === "")
            return
        root.trackQueued(hit.path)
    }
```

- [ ] No mesmo arquivo, junto de `Keys.onReturnPressed` e `Keys.onEnterPressed` do
      `TextInput` (linhas 193-194), acrescentar o atalho. `event.modifiers` é o que
      distingue os dois gestos na mesma tecla:

```qml
                Keys.onReturnPressed: function (event) {
                    if (event.modifiers & Qt.ShiftModifier)
                        root.queueAt(root.highlighted)
                    else
                        root.activate(root.highlighted)
                }
                Keys.onEnterPressed: function (event) {
                    if (event.modifiers & Qt.ShiftModifier)
                        root.queueAt(root.highlighted)
                    else
                        root.activate(root.highlighted)
                }
```

- [ ] No mesmo arquivo, se ainda não existir uma função `hitAt(index)` que devolva o
      resultado destacado (a `activate(index)` já resolve isso internamente), extraí-la para
      as duas usarem a mesma travessia — declarar antes de `activate`:

```qml
    // A mesma travessia que activate() faz: o índice da tela vira o resultado da busca.
    function hitAt(index) {
        const linhas = root.buildRows(root.hits)
        if (index < 0 || index >= linhas.length)
            return null
        const linha = linhas[index]
        return linha.hit !== undefined ? linha.hit : null
    }
```

- [ ] Em `src/Main.qml`, no `SearchOverlay { id: searchOverlay … }`, ligar o sinal:

```qml
        onTrackQueued: function (path) { AudioEngine.appendToQueue(path) }
```

- [ ] Em `src/SearchOverlay.qml`, o rodapé de atalhos precisa anunciar o gesto novo — o
      desenho o lista (`design/Busca.dc.html:330`). Localizar o `Row`/`RowLayout` do rodapé
      que já mostra os atalhos e acrescentar:

```qml
            Text {
                text: "⇧↵ pôr na fila"
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOutline
            }
```

- [ ] verificação mecânica da task:
      `grep -c 'trackQueued\|ShiftModifier' src/SearchOverlay.qml` → `4`
- [ ] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/SearchOverlay.qml src/Main.qml docs/plans/2026-08-28-fila-tirinha.md
git commit -m "feat(search): shift+enter queues a hit without interrupting playback"
```

### Task 4: Apagar a lista de fila que nunca foi a tirinha

- [ ] Confirmar que continua sem consumidor antes de apagar:

```bash
grep -lE '(^|[^A-Za-z])QueuePanel[[:space:]]*\{' src/*.qml
```

- [ ] O comando acima tem de sair **vazio**. Só então:

```bash
git rm src/QueuePanel.qml
sed -i '/src\/QueuePanel\.qml/d' CMakeLists.txt
```

- [ ] verificação mecânica da task:
      `grep -c 'QueuePanel' CMakeLists.txt` → `0`
- [ ] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [ ] commit:

```bash
git add -A src CMakeLists.txt docs/plans/2026-08-28-fila-tirinha.md
git commit -m "chore(ui): delete the orphaned textual queue list"
```

## Verificação da fatia (E2E)

- `quiet-run cmake --build build` → exit 0
- `quiet-run ctest --test-dir build --output-on-failure` → `100% tests passed` com
  `Total Tests: 9` ou mais
- `bash tools/check-layout.sh` → 11 medidas ok
- `grep -c 'QueuePanel' CMakeLists.txt` → `0`
- `ls src/QueuePanel.qml 2>&1 | grep -c 'No such file'` → `1`
- A tirinha só aparece com fila; a prova precisa de uma faixa tocando:
  `./build/appmelodia --measure --pane library --play-track "$(ls ~/Música/**/*.mp3 2>/dev/null | head -1)" --delay 2500 --shot /tmp/melodia-fila.png --no-search`
  → imprime `SHOT /tmp/melodia-fila.png`
- `QT_QPA_PLATFORM=offscreen QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 ./build/appmelodia --measure --pane library --search-text "a" 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError|TypeError|unavailable|Cannot override|Cannot assign'`
  → `0`
- `bash tools/check-orfaos.sh` → não lista mais `QueuePanel`, `appendToQueue` nem
  `upcoming`

## Fora de escopo

- Arrastar para reordenar a fila. O motor não tem a operação (fatia `fila-motor` a deixou
  explicitamente de fora).
- Tirar uma entrada da fila pela tirinha.
- A coluna "Fila" lateral de `design/HierarquiaContraste.dc.html:197-212`: é um desenho
  alternativo, e o Pedro aprovou o de `Main.dc.html`. Reabrir isso é decisão de produto, não
  de execução.
- Tirinha na tela de podcast: um episódio não tem "a seguir" que faça sentido — o podcast
  quer retomar posição, não embaralhar.
