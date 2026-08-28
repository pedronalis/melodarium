---
slug: biblioteca-densa
feature: melodia-capa-manda
status: concluido
depende-de: [moldura-capa, like-faixas]
decisao-humana: nao
spec: design/Biblioteca.dc.html (tela 2 aprovada em 2026-08-27)
---

# Plano: biblioteca-densa

**Goal:** Encher o miolo da biblioteca: uma linha só de filtros (nada de duas fileiras de
chips), lista de faixas com o coração de curtir em cada linha, e o filtro "Curtidas" ao lado
dos eixos de navegação.

**Arquitetura:** `LibraryPane.qml` (hoje um stub da fatia `moldura-capa`) vira o miolo de
verdade: cabeçalho com contagem, `FilterChips` numa linha, e a `ListView` de `TrackRow` que
já existe hoje em `Main.qml` — movida para cá, não reescrita. Os quatro eixos automáticos
(recentes, mais tocadas, esquecidas, nunca ouvi) recolhem num único chip com menu, porque
nove chips não cabem numa linha de ~650px.

**Constraints globais:** Qt 6.10.3 / QML, tokens do `Theme`. A linha de filtros NUNCA quebra
em duas: `Layout.fillWidth` no espaçador, nunca `flex-wrap`.

## Arquivos

- Criar: `src/FilterChips.qml`
- Modificar: `src/LibraryPane.qml` (era stub) · `src/TrackRow.qml` (coração) ·
  `src/Main.qml` (mover a lista para o pane) · `CMakeLists.txt`
- Testar: `tests/tst_librarybrowser.cpp` (o filtro de curtidas já é coberto pela fatia
  `like-faixas`; aqui a verificação é de QML, feita pelo gate)

## Interfaces

- **Consome** (verbatim, das fatias anteriores):
  - `Q_INVOKABLE bool LibraryBrowser::toggleLike(int trackId)`
  - `Q_INVOKABLE QString LibraryBrowser::clauseForLiked()`
  - `Q_INVOKABLE int LibraryBrowser::likedCount()`
  - sinal `void LibraryBrowser::likedChanged(int trackId, bool liked)`
  - papel `liked` (bool) do `TrackListModel`
  - `Main.qml` expõe `property string section` e o `StackLayout` cujo índice 0 é este pane.
- **Produz:**
  - `FilterChips.qml`: `property string current` (`"all"`, `"artists"`, `"albums"`,
    `"genres"`, `"tags"`, `"liked"`, `"recent"`, `"most"`, `"forgotten"`, `"never"`),
    `property int likedCount`, `signal chosen(string key)`.
  - `LibraryPane.qml`: `property alias model`, `property string filter`,
    `signal trackActivated(int index)`, `signal collectRequested(int trackId)`,
    `signal groupChosen(string key)` e `function reload()`.
  - `TrackRow.qml` ganha `property bool liked: false` e `signal likeToggled()`.

## Tasks

### Task 1: O coração na linha da faixa

- [x] Em `src/TrackRow.qml`, acrescentar às propriedades do topo (junto de
      `property bool showCollectButton: false`):

```qml
    property bool liked: false

    signal likeToggled
```

- [x] No `RowLayout` interno, inserir o botão IMEDIATAMENTE ANTES do `SourceBadge`:

```qml
            // Sempre presente, nunca só no hover: um coração que aparece ao passar o mouse é
            // um coração que o usuário não sabe que existe. Apagado quando não curtida.
            IconButton {
                icon: "heart"
                size: Theme.fontSizeS
                accent: root.liked
                opacity: root.liked ? 1.0 : (mouse.containsMouse ? 0.6 : 0.25)
                onClicked: root.likeToggled()

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }
            }
```

- [x] verificação mecânica da task: `grep -c 'signal likeToggled' src/TrackRow.qml` → `1` e
      `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/TrackRow.qml
git commit -m "feat(ui): heart on every track row"
```

### Task 2: `FilterChips.qml` — os filtros em uma linha só

- [x] Criar `src/FilterChips.qml`:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodarium.App

RowLayout {
    id: root

    property string current: "all"
    property int likedCount: 0

    signal chosen(string key)

    spacing: Theme.marginXS

    readonly property var eixos: [
        { key: "all",     label: qsTr("Todas") },
        { key: "artists", label: qsTr("Artistas") },
        { key: "albums",  label: qsTr("Álbuns") },
        { key: "genres",  label: qsTr("Gêneros") },
        { key: "tags",    label: qsTr("Tags") }
    ]

    readonly property var automaticas: [
        { key: "recent",    label: qsTr("Recentes") },
        { key: "most",      label: qsTr("Mais tocadas") },
        { key: "forgotten", label: qsTr("Esquecidas") },
        { key: "never",     label: qsTr("Nunca ouvi") }
    ]

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property bool selected: false
        property string glyph: ""

        signal clicked

        implicitWidth: chipRow.implicitWidth + Theme.marginL * 2
        implicitHeight: 26
        radius: Theme.iRadiusS
        color: chip.selected ? Theme.mSurfaceVariant
                             : (chipArea.containsMouse ? Theme.mSurfaceVariant : "transparent")
        border.width: chip.selected ? 0 : Theme.borderS
        border.color: Theme.mSurfaceVariant

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.marginXS

            Text {
                visible: chip.glyph !== ""
                text: chip.glyph
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeXS
                color: chip.selected ? Theme.mOnSurface : Theme.mOnSurfaceVariant
            }
            Text {
                text: chip.label
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                font.weight: chip.selected ? Theme.fontWeightSemiBold : Theme.fontWeightRegular
                color: chip.selected ? Theme.mOnSurface : Theme.mOnSurfaceVariant
            }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    Repeater {
        model: root.eixos

        Chip {
            required property var modelData
            label: modelData.label
            selected: root.current === modelData.key
            onClicked: root.chosen(modelData.key)
        }
    }

    Chip {
        label: root.likedCount > 0 ? qsTr("Curtidas") + " · " + root.likedCount : qsTr("Curtidas")
        glyph: Icons.get("heart")
        selected: root.current === "liked"
        onClicked: root.chosen("liked")
    }

    Item { Layout.fillWidth: true }

    Chip {
        id: autoChip
        label: qsTr("Automáticas")
        glyph: Icons.get("chevron-right")
        selected: ["recent", "most", "forgotten", "never"].indexOf(root.current) >= 0
        onClicked: autoMenu.popup(autoChip, 0, autoChip.height + Theme.marginXS)
    }

    Menu {
        id: autoMenu

        Repeater {
            model: root.automaticas

            MenuItem {
                required property var modelData
                text: modelData.label
                onTriggered: root.chosen(modelData.key)
            }
        }
    }
}
```

- [x] Registrar em `CMakeLists.txt`, na lista `QML_FILES`: `src/FilterChips.qml`
- [x] verificação mecânica da task: `cmake --build build` → exit 0 e
      `grep -c 'signal chosen' src/FilterChips.qml` → `1`
- [x] commit:

```bash
git add src/FilterChips.qml CMakeLists.txt
git commit -m "feat(ui): single-line filter row with a menu for the automatic lists"
```

### Task 3: `LibraryPane.qml` — o miolo de verdade

- [x] Substituir o conteúdo inteiro do stub `src/LibraryPane.qml` por:

```qml
import QtQuick
import QtQuick.Layouts
import Melodarium.App

Rectangle {
    id: root

    property alias model: list.model
    property string filter: "all"

    signal groupChosen(string key)
    signal trackActivated(int index)
    signal collectRequested(int trackId)

    color: Theme.mSurfaceVariant
    radius: Theme.radiusM
    border.width: Theme.borderS
    border.color: Theme.mOutline
    clip: true

    function reload() {
        chips.likedCount = LibraryBrowser.likedCount()
    }

    Component.onCompleted: root.reload()

    Connections {
        target: LibraryBrowser
        function onLikedChanged(id, liked) { root.reload() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginL
        spacing: Theme.marginM

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Text {
                text: qsTr("Biblioteca")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }
            Text {
                text: list.count + qsTr(" faixas")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOutline
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: Database.scanning
                text: qsTr("varrendo…")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }
            IconButton {
                icon: "history"
                size: Theme.fontSizeL
                enabled: Database.libraryPath !== "" && !Database.scanning
                onClicked: Database.startScan()
            }
        }

        FilterChips {
            id: chips
            Layout.fillWidth: true
            current: root.filter
            onChosen: function (key) { root.groupChosen(key) }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cacheBuffer: 400
            boundsBehavior: Flickable.StopAtBounds

            delegate: TrackRow {
                required property var model
                required property int index

                width: ListView.view.width
                title: model.title
                artist: model.artist
                album: model.album
                durationMs: model.durationMs
                coverUrl: model.coverUrl
                isCurrent: model.isCurrent
                trackId: model.trackId
                liked: model.liked
                showCollectButton: true
                sourceKind: model.sourceKind

                // Sinal, nunca root.parent.algumaCoisa(): o pane não pode saber quem é o pai.
                onActivated: root.trackActivated(index)
                onLikeToggled: LibraryBrowser.toggleLike(model.trackId)
                onCollectRequested: root.collectRequested(model.trackId)
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0 && !Database.scanning
                text: qsTr("nada nesta lista")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurfaceVariant
            }
        }
    }
}
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/LibraryPane.qml
git commit -m "feat(ui): the library pane, filters and list in one place"
```

### Task 4: Ligar o pane ao roteamento de `Main.qml`

- [x] Em `src/Main.qml`, acrescentar ao `clauseFor(section, id)` existente o caso do filtro
      novo, antes do `default:`:

```qml
        case "liked":      return { clause: LibraryBrowser.clauseForLiked(), bindings: [] }
```

- [x] Substituir o filho `LibraryPane { }` do `StackLayout` por:

```qml
            LibraryPane {
                id: libraryPane
                model: trackModel
                filter: root.libraryFilter
                onGroupChosen: function (key) {
                    root.libraryFilter = key
                    root.showSection(key === "liked" ? "liked" : key, 0)
                }
                onTrackActivated: function (index) { root.activateTrack(index) }
                onCollectRequested: function (trackId) { root.collectTrack(trackId) }
            }
```

- [x] Acrescentar às propriedades de `Main.qml`: `property string libraryFilter: "all"`
- [x] Acrescentar a `Main.qml` as duas funções que o delegate chama:

```qml
    function activateTrack(index) {
        queuePaths = trackModel.allPaths()
        AudioEngine.loadPlaylist(queuePaths, index)
        AudioEngine.play()
    }

    function collectTrack(trackId) {
        root.selectedTrackId = trackId
        collectMenu.trackId = trackId
        collectMenu.options = CollectionManager.collections()
        collectMenu.popup()
    }
```

      (`queuePaths` substitui o antigo `queue.paths` do `QueuePanel`, que saiu da tela nesta
      direção; declare `property var queuePaths: []` junto das outras propriedades.)

- [x] verificação mecânica da task:
      `cmake --build build && test "$(QT_QPA_PLATFORM=offscreen timeout 8 ./build/melodarium 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError')" -eq 0` → exit 0
- [x] commit:

```bash
git add src/Main.qml
git commit -m "feat(ui): route the library filters through the pane"
```

### Task 5: A linha de filtros cabe mesmo?

- [x] Medir, não olhar: acrescentar temporariamente ao `FilterChips`:

```qml
    Timer {
        running: true; interval: 900
        onTriggered: console.log("MEDIDA chips=" + root.implicitWidth + " disponivel=" + root.width)
    }
```

- [x] Rodar:
      `QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 6 ./build/melodarium 2>&1 | grep -a MEDIDA`
      → `chips` tem de ser ≤ `disponivel`. Se estourar, encolha `Theme.marginL` para
      `Theme.marginM` no padding do `Chip` e meça de novo; NÃO deixe quebrar em duas linhas.
- [x] Remover o `Timer`.
- [x] verificação mecânica da task: `test "$(grep -c 'MEDIDA' src/FilterChips.qml)" -eq 0` → exit 0
- [x] commit:

```bash
git add src/FilterChips.qml
git commit -m "fix(ui): keep the filter row on one line"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `test "$(QT_QPA_PLATFORM=offscreen timeout 8 ./build/melodarium 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError')" -eq 0` → exit 0
- `grep -q "clauseForLiked" src/Main.qml` → exit 0
- `grep -q "property bool liked" src/TrackRow.qml` → exit 0
- `test "$(grep -c 'flex-wrap\|Flow' src/FilterChips.qml)" -eq 0` → exit 0

## Fora de escopo

- A busca: é overlay, fatia `busca-overlay`.
- Ordenar a lista por coluna (clicar no cabeçalho) — a direção aprovada não tem cabeçalho de
  coluna; se você quiser isso depois, é fatia nova.
- Arrastar faixa para dentro de coleção: o botão `+` existente continua sendo o gesto.

## Divergências entre o plano e o desenho (2026-08-27, execução)

Onde os dois discordaram, a aparência seguiu `design/Biblioteca.dc.html` e a API seguiu o
plano — regra do run.

- **`TrackRow` virou tabular.** O plano só acrescentava o coração à linha existente; o desenho
  mostra colunas fixas (número · título/artista · álbum · coração · duração), sem miniatura de
  capa por linha e com zebra a cada duas linhas. A linha caiu de 54 px para 38 px, que é o que
  torna a lista "densa". A API (`title`, `artist`, `album`, `durationMs`, `coverUrl`,
  `isCurrent`, `trackId`, `showCollectButton`, `sourceKind`, `activated`, `collectRequested`)
  ficou intacta; entraram `liked`, `likeToggled`, `position` e `alternate`.
- **O miolo não tem moldura.** No desenho ele é o próprio fundo da janela; o stub era um
  `Rectangle` com borda. Uma caixa em volta da lista só roubaria largura.
- **A barra de busca entrou no miolo.** Está no desenho da biblioteca e não estava no plano.
  Ela não busca: abre o overlay da fatia `busca-overlay` (mesma coisa que `Ctrl+K`).
- **A lista de grupos entrou no pane.** Sem ela, clicar em "Artistas" mostrava uma tela
  parada: o `Main.qml` já calculava os grupos e ninguém os desenhava.
- **Chips recolhem em janela estreita.** Em 720 px os sete chips pedem 532 px e só há 364.
  Em vez de espremer o texto (ou embrulhar em duas linhas, reprovado), "Gêneros" e "Tags"
  entram no menu e "Curtidas" fica só com o coração. Medido pelo gate nas duas larguras.
- **O contador de curtidas saiu de dentro do chip.** No desenho o chip "Curtidas" não carrega
  número; ele virou um número solto ao lado, no mesmo tom do resto dos metadados.
- **`TrackListModel.totalDurationMs`** foi acrescentado (não estava no plano) porque o
  cabeçalho do desenho anuncia "1.204 faixas · 3 d 11 h".
