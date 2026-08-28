---
slug: colecoes-tela
feature: melodia-religa
status: aprovado
depende-de: [clique-responde]
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md §Como fica organizado · docs/auditoria-completude.md (achados 4,5,22)
---

# Plano: colecoes-tela

**Goal:** Devolver ao produto o seu diferencial nº 1. Hoje dá para criar uma coleção e jogar
faixas nela, e **não dá para abri-la** — o dado entra no banco e some da vista. Esta fatia
dá às coleções um modo próprio na tira de ícones, uma tela que as lista e as abre, a
gerência inteira (renomear, apagar, tirar faixa) e, de brinde, devolve o único lugar do app
onde se cola um link do YouTube.

**Arquitetura:** A tira de ícones já é o seletor de MODO (fatia `clique-responde`). Coleções
entra como **primeiro** item dela, honrando o spec ("Coleções ← o diferencial, no topo").

O miolo ganha um quarto painel, `CollectionsPane.qml`, com dois estados no mesmo componente:

- **nenhuma aberta** → lista as coleções (nome + contagem), com o botão de criar;
- **uma aberta** → lista as faixas dela com `TrackRow` (a mesma peça da biblioteca, para a
  linha não ter duas aparências), cabeçalho com o nome, e as ações da coleção.

O painel **não monta SQL**: pede `CollectionManager.clauseForCollection(id)` +
`bindingsForCollection(id)` e entrega ao `TrackListModel` que o `Main.qml` já possui — o
mesmo caminho que artistas e álbuns usam. `CollectionsSection.qml` e `Sidebar.qml`, órfãos
desde o commit `ec45204`, são **apagados**: o novo painel os substitui, e arquivo morto no
disco é justamente o que produziu este lote (lição
`docs/solutions/ui/2026-08-28-redesenho-deixa-funcionalidade-orfa.md`).

**Constraints globais:** Qt 6.10.3, QML. Todo tamanho passa por `Theme.uiScale`.

**PERIGO — vale a fatia inteira:** nenhum `Popup` novo pode redeclarar uma propriedade que o
tipo base já tem (`opened`, `visible`, `width`, `height`, `contentItem`, `background`). No
Qt 6.10 isso derruba o tipo QML inteiro **em silêncio** — o build sai 0, o app sobe, e o
componente simplesmente não existe. Um `Popup` só é construído na primeira abertura, então
nem rodar o app pega. Lição completa em
`docs/solutions/ui/2026-08-27-popup-final-property-nao-carrega.md`. Para "está aberto", use
`visible`.

## Arquivos

- Criar: `src/CollectionsPane.qml` · `src/ConfirmDialog.qml`
- Modificar: `src/NewCollectionDialog.qml` (ganha modo renomear) · `src/IconRail.qml`
- Modificar: `src/Main.qml` · `CMakeLists.txt`
- Apagar: `src/Sidebar.qml` · `src/SidebarItem.qml` · `src/CollectionsSection.qml`
- Criar: nenhum teste novo (a fatia é de tela; `tests/tst_collections.cpp` já cobre o motor)
- Testar: `tests/tst_collections.cpp` (existente, tem de continuar passando)

## Interfaces

- Consome: `CollectionManager::collections() -> QVariantList` de
  `{id:int, name:string, count:int}` · `createCollection(const QString&) -> int` (0 em
  nome duplicado) · `renameCollection(int, const QString&) -> bool` ·
  `deleteCollection(int) -> bool` · `removeTrackFromCollection(int, int) -> bool` ·
  `clauseForCollection(int) -> QString` · `bindingsForCollection(int) -> QVariantList` ·
  sinal `collectionsChanged()`. Todas já existem em `src/collectionmanager.h`.
- Consome: `AddFromLinkDialog` — `property int collectionId` e `open()` ·
  `DownloadProgressRow` — `property string url`, `property real received`,
  `property real total`, `signal cancelRequested`.
- Consome: `IconRail.items` com `[{key:"library"},{key:"podcast"},{key:"search"}]`
  (produzida pela fatia `clique-responde`).
- Produz:
  - `CollectionsPane.qml` — `property alias model` (o `TrackListModel`),
    `property int openId`, `property string openName`;
    sinais `collectionOpened(int id, string name)`, `closeRequested()`,
    `trackActivated(int index)`, `trackRemoved(int trackId)`.
    Consumido por `src/Main.qml`. A fatia `colecoes-alcance` acrescenta o botão
    "+ Coleção" ao cabeçalho do **LibraryPane**, não a este painel.
  - `NewCollectionDialog` ganha `property int renameId: 0` e
    `signal renamed(int id, string name)`. Com `renameId > 0` o diálogo renomeia em vez de
    criar; o sinal `created(int, string)` existente **não muda de assinatura**.
  - `ConfirmDialog.qml` — `property string message`, `property string confirmLabel`,
    `signal confirmed()`. Reusado pela fatia `ajustes`.
  - `IconRail.items` passa a começar por `{ key: "collections", icon: "playlist" }`.

## Tasks

### Task 1: O diálogo de nome aprende a renomear

- [x] Em `src/NewCollectionDialog.qml`, acrescentar as duas linhas de estado logo depois de
      `signal created(int id, string name)`:

```qml
    // Com renameId > 0 o mesmo diálogo renomeia em vez de criar. Uma caixa de texto com
    // um botão é a mesma caixa nos dois casos; duplicá-la só duplicaria o bug.
    property int renameId: 0
    property string initialText: ""

    signal renamed(int id, string name)
```

- [x] No mesmo arquivo, substituir o `onOpened` para que o campo já venha preenchido ao
      renomear:

```qml
    onOpened: {
        nameInput.text = root.initialText
        warning.text = ""
        nameInput.forceActiveFocus()
        nameInput.selectAll()
    }
```

- [x] Trocar o texto do título para acompanhar o modo (o `Text` cujo `text` é hoje
      `qsTr("Nova coleção")`):

```qml
        Text {
            text: root.renameId > 0 ? qsTr("Renomear coleção") : qsTr("Nova coleção")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeL
            font.weight: Theme.fontWeightSemiBold
            color: Theme.mOnSurface
        }
```

- [x] Substituir o `MelodiaButton { id: confirm … }` inteiro:

```qml
            MelodiaButton {
                id: confirm
                text: root.renameId > 0 ? qsTr("Renomear") : qsTr("Criar")
                onClicked: {
                    if (root.renameId > 0) {
                        if (CollectionManager.renameCollection(root.renameId, nameInput.text)) {
                            root.renamed(root.renameId, nameInput.text)
                            root.close()
                        } else {
                            warning.text = qsTr("Já existe uma coleção com esse nome.")
                        }
                        return
                    }
                    const id = CollectionManager.createCollection(nameInput.text)
                    if (id > 0) {
                        root.created(id, nameInput.text)
                        root.close()
                    } else {
                        warning.text = qsTr("Já existe uma coleção com esse nome.")
                    }
                }
            }
```

- [x] verificação mecânica da task:
      `grep -c 'renameId' src/NewCollectionDialog.qml` → `5`
- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/NewCollectionDialog.qml docs/plans/2026-08-28-colecoes-tela.md
git commit -m "feat(ui): the collection name dialog also renames"
```

### Task 2: Uma confirmação para o que não tem volta

- [x] Criar `src/ConfirmDialog.qml`. **Não redeclarar `opened`, `visible`, `width` nem
      `height`** — ver o PERIGO no topo deste plano:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodia.App

// Apagar uma coleção não tem desfazer. Um Popup pequeno é a diferença entre um clique
// errado custar um segundo e custar a organização inteira de uma noite.
Popup {
    id: root

    property string message: ""
    property string confirmLabel: qsTr("Apagar")

    signal confirmed

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.marginL
    width: Math.round(360 * Theme.uiScale)

    background: Rectangle {
        color: Theme.mSurfaceVariant
        radius: Theme.radiusM
        border.width: Theme.borderS
        border.color: Theme.mOutline
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.marginL

        Text {
            Layout.fillWidth: true
            text: root.message
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeM
            color: Theme.mOnSurface
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS
            Item { Layout.fillWidth: true }
            MelodiaButton {
                text: qsTr("Cancelar")
                outlined: true
                onClicked: root.close()
            }
            MelodiaButton {
                text: root.confirmLabel
                onClicked: {
                    root.confirmed()
                    root.close()
                }
            }
        }
    }
}
```

- [x] Registrar em `CMakeLists.txt`, na lista `QML_FILES`, logo depois de
      `src/NewCollectionDialog.qml`:

```cmake
        src/ConfirmDialog.qml
```

- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/ConfirmDialog.qml CMakeLists.txt docs/plans/2026-08-28-colecoes-tela.md
git commit -m "feat(ui): a confirmation popup for what cannot be undone"
```

### Task 3: O painel das coleções

- [x] Criar `src/CollectionsPane.qml`:

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodia.App

// O diferencial nº 1 do produto, de volta à tela. Dois estados no mesmo painel: a lista das
// coleções, e as faixas de UMA coleção aberta. A linha de faixa é o mesmo TrackRow da
// biblioteca de propósito — uma faixa não pode ter duas aparências no mesmo app.
Item {
    id: root

    property alias model: tracks.model
    property int openId: 0
    property string openName: ""

    signal collectionOpened(int id, string name)
    signal closeRequested
    signal trackActivated(int index)
    signal trackRemoved(int trackId)

    property var items: []
    // url -> { received, total }. O download é por link, não por linha: guardar isso dentro
    // de um delegate que a rolagem recicla perderia o progresso ao rolar.
    property var activeDownloads: ({})

    function refresh() {
        root.items = CollectionManager.collections()
    }

    function open(id, name) {
        root.openId = id
        root.openName = name
        root.collectionOpened(id, name)
    }

    function close() {
        root.openId = 0
        root.openName = ""
        root.closeRequested()
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: CollectionManager
        function onCollectionsChanged() { root.refresh() }
    }

    Connections {
        target: YtDlpDownloader
        function onProgress(url, downloaded, total) {
            const next = root.activeDownloads
            next[url] = { received: downloaded, total: total }
            root.activeDownloads = next
        }
        function onFinished(url, trackId) {
            const next = root.activeDownloads
            delete next[url]
            root.activeDownloads = next
            root.refresh()
        }
        function onFailed(url, reason) {
            const next = root.activeDownloads
            delete next[url]
            root.activeDownloads = next
            aviso.text = reason
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginXL + Theme.marginS
        anchors.bottomMargin: Theme.marginXL
        spacing: Theme.marginL

        // --- Cabeçalho: o nome do lugar, e o que dá para fazer nele ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId > 0
                icon: "chevron-left"
                size: Theme.fontSizeS
                tooltip: qsTr("todas as coleções")
                onClicked: root.close()
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.openId > 0 ? root.openName : qsTr("Coleções")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.openId > 0
                      ? tracks.count + qsTr(" faixas")
                      : root.items.length + qsTr(" coleções")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeS
                color: Theme.mOutline
            }

            Item { Layout.fillWidth: true }

            // Baixar só faz sentido com uma coleção aberta: o arquivo tem de cair em algum
            // lugar, e o lugar é a coleção que o usuário está olhando.
            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId > 0
                icon: "download"
                size: Theme.fontSizeS
                tooltip: qsTr("colar link do YouTube")
                onClicked: {
                    linkDialog.collectionId = root.openId
                    linkDialog.open()
                }
            }

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId > 0
                icon: "history"
                size: Theme.fontSizeS
                tooltip: qsTr("renomear")
                onClicked: {
                    nomeDialog.renameId = root.openId
                    nomeDialog.initialText = root.openName
                    nomeDialog.open()
                }
            }

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId > 0
                icon: "close"
                size: Theme.fontSizeS
                tooltip: qsTr("apagar coleção")
                onClicked: {
                    apagar.message = qsTr("Apagar \"%1\"? As faixas continuam na biblioteca.")
                                     .arg(root.openName)
                    apagar.open()
                }
            }

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId === 0
                icon: "plus"
                size: Theme.fontSizeS
                tooltip: qsTr("nova coleção")
                onClicked: {
                    nomeDialog.renameId = 0
                    nomeDialog.initialText = ""
                    nomeDialog.open()
                }
            }
        }

        Repeater {
            model: Object.keys(root.activeDownloads)

            DownloadProgressRow {
                required property var modelData
                Layout.fillWidth: true
                url: modelData
                received: root.activeDownloads[modelData].received
                total: root.activeDownloads[modelData].total
                onCancelRequested: YtDlpDownloader.cancel(modelData)
            }
        }

        Text {
            id: aviso
            Layout.fillWidth: true
            visible: aviso.text !== ""
            text: ""
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeXS
            color: Theme.mError
        }

        // --- A lista das coleções ---
        ListView {
            id: lista
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.openId === 0
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            model: root.items

            delegate: Rectangle {
                id: linha

                required property var modelData
                required property int index

                width: ListView.view.width
                height: Math.round(44 * Theme.uiScale)
                radius: Theme.radiusXS
                color: area.containsMouse
                       ? Theme.mHover
                       : (linha.index % 2 === 1
                          ? Qt.rgba(Theme.mSurfaceVariant.r, Theme.mSurfaceVariant.g,
                                    Theme.mSurfaceVariant.b, 0.45)
                          : "transparent")

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginL
                    anchors.rightMargin: Theme.marginL
                    spacing: Theme.marginL

                    Text {
                        text: Icons.get("playlist")
                        font.family: Icons.fontFamily
                        font.pointSize: Theme.fontSizeM
                        color: area.containsMouse ? Theme.mOnHover : Theme.mTertiary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: linha.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeM
                        color: area.containsMouse ? Theme.mOnHover : Theme.mOnSurface
                    }

                    Text {
                        text: linha.modelData.count + qsTr(" faixas")
                        font.family: Theme.fontFamilyFixed
                        font.pointSize: Theme.fontSizeS
                        color: area.containsMouse ? Theme.mOnHover : Theme.mOutline
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.open(linha.modelData.id, linha.modelData.name)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: lista.count === 0
                width: parent.width * 0.7
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Nenhuma coleção ainda.\nCrie uma e jogue faixas dentro pelo + da lista.")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurfaceVariant
            }
        }

        // --- As faixas da coleção aberta ---
        ListView {
            id: tracks
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.openId > 0
            clip: true
            spacing: 1
            cacheBuffer: 400
            boundsBehavior: Flickable.StopAtBounds

            delegate: TrackRow {
                id: faixa

                required property var model
                required property int index

                width: ListView.view.width
                position: faixa.index + 1
                alternate: faixa.index % 2 === 1
                title: faixa.model.title
                artist: faixa.model.artist
                album: faixa.model.album
                durationMs: faixa.model.durationMs
                coverUrl: faixa.model.coverUrl
                isCurrent: faixa.model.isCurrent
                trackId: faixa.model.trackId
                liked: faixa.model.liked
                sourceKind: faixa.model.sourceKind
                // Dentro de uma coleção o gesto útil não é "pôr numa coleção": é tirar
                // desta. O + da biblioteca daria uma segunda porta para o mesmo lugar.
                showCollectButton: false

                onActivated: root.trackActivated(faixa.index)
                onLikeToggled: LibraryBrowser.toggleLike(faixa.model.trackId)
            }

            Text {
                anchors.centerIn: parent
                visible: tracks.count === 0
                text: qsTr("coleção vazia — jogue faixas nela pelo + da biblioteca")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurfaceVariant
            }
        }
    }

    NewCollectionDialog {
        id: nomeDialog
        onCreated: function (id, name) { root.open(id, name) }
        onRenamed: function (id, name) { root.openName = name; root.refresh() }
    }

    ConfirmDialog {
        id: apagar
        onConfirmed: {
            CollectionManager.deleteCollection(root.openId)
            root.close()
        }
    }

    AddFromLinkDialog {
        id: linkDialog
    }
}
```

- [x] Registrar em `CMakeLists.txt`, na lista `QML_FILES`, depois de `src/LibraryPane.qml`:

```cmake
        src/CollectionsPane.qml
```

- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/CollectionsPane.qml CMakeLists.txt docs/plans/2026-08-28-colecoes-tela.md
git commit -m "feat(ui): a pane that lists, opens and manages collections"
```

### Task 4: A tira ganha o primeiro ícone e o miolo ganha o quarto painel

- [x] Em `src/IconRail.qml`, inserir coleções como **primeiro** item da lista `items`
      (o spec põe coleções no topo; a fatia `clique-responde` deixou a lista com três):

```qml
    readonly property var items: [
        { key: "collections", icon: "playlist",   tip: qsTr("Coleções") },
        { key: "library",     icon: "list",       tip: qsTr("Biblioteca") },
        { key: "podcast",     icon: "microphone", tip: qsTr("Podcast") },
        { key: "search",      icon: "search",     tip: qsTr("Buscar") }
    ]
```

- [x] Em `src/Main.qml`, no `StackLayout { id: pane … }`, trocar o `currentIndex` para
      conhecer o painel novo:

```qml
            currentIndex: root.measuring
                          ? (root.measurePane === "podcast"
                             ? 1 : (root.measurePane === "empty"
                                    ? 2 : (root.measurePane === "collections" ? 3 : 0)))
                          : (root.section === "podcast"
                             ? 1
                             : (root.section === "collections"
                                ? 3
                                : (Database.libraryPath === "" ? 2 : 0)))
```

- [x] Em `src/Main.qml`, acrescentar o painel como **quarto** filho do `StackLayout`, depois
      do `EmptyPane`:

```qml
            CollectionsPane {
                id: collectionsPane
                model: trackModel
                onCollectionOpened: function (id, name) {
                    root.currentSection = "collection"
                    root.currentId = id
                    const q = root.clauseFor("collection", id)
                    trackModel.loadFromQuery(q.clause, q.bindings)
                }
                onCloseRequested: {
                    // Sair de uma coleção devolve a lista inteira ao modelo: o painel da
                    // biblioteca compartilha este modelo e não pode herdar o filtro.
                    root.currentSection = "all"
                    root.currentId = 0
                    root.showSection("all", 0)
                }
                onTrackActivated: function (index) { root.activateTrack(index) }
            }
```

- [x] verificação mecânica da task:
      `grep -c 'collections' src/IconRail.qml src/Main.qml` →
      `src/IconRail.qml:1`, `src/Main.qml:3`
- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/IconRail.qml src/Main.qml docs/plans/2026-08-28-colecoes-tela.md
git commit -m "feat(ui): collections get the top slot of the rail and a pane of their own"
```

### Task 5: Apagar o que o redesenho abandonou

- [ ] Confirmar que os três arquivos continuam sem nenhum consumidor vivo antes de apagar
      (o painel novo os substituiu):

```bash
grep -lE '(^|[^A-Za-z])(Sidebar|SidebarItem|CollectionsSection)[[:space:]]*\{' src/*.qml \
  | grep -vE 'src/(Sidebar|SidebarItem|CollectionsSection)\.qml'
```

- [ ] O comando acima tem de sair **vazio**. Só então, apagar os arquivos e desregistrá-los:

```bash
git rm src/Sidebar.qml src/SidebarItem.qml src/CollectionsSection.qml
sed -i '/src\/Sidebar\.qml/d;/src\/SidebarItem\.qml/d;/src\/CollectionsSection\.qml/d' CMakeLists.txt
```

- [ ] verificação mecânica da task:
      `grep -cE 'Sidebar|CollectionsSection' CMakeLists.txt` → `0`
- [ ] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [ ] commit:

```bash
git add -A src CMakeLists.txt docs/plans/2026-08-28-colecoes-tela.md
git commit -m "chore(ui): delete the sidebar the redesign left orphaned"
```

## Verificação da fatia (E2E)

- `quiet-run cmake --build build` → exit 0
- `quiet-run ctest --test-dir build --output-on-failure` → `100% tests passed` com
  `Total Tests: 9` ou mais
- `bash tools/check-layout.sh` → 11 medidas ok
- `grep -cE 'Sidebar|CollectionsSection' CMakeLists.txt` → `0`
- `ls src/Sidebar.qml src/CollectionsSection.qml 2>&1 | grep -c 'No such file'` → `2`
- Os popups têm de ser abertos para provar que existem — um `Popup` que redeclara uma
  propriedade FINAL só falha na primeira abertura, com o build verde:
  `QT_QPA_PLATFORM=offscreen QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 ./build/appmelodia --measure --pane collections --no-search 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError|TypeError|unavailable|Cannot override|Cannot assign'`
  → `0`
- `./build/appmelodia --measure --pane collections --shot /tmp/melodia-colecoes.png --no-search`
  → imprime `SHOT /tmp/melodia-colecoes.png`
- `bash tools/check-orfaos.sh` → não lista mais `Sidebar`, `SidebarItem`,
  `CollectionsSection`, `renameCollection`, `deleteCollection`, `clauseForCollection`,
  `bindingsForCollection`, `downloadDirectory`

## Fora de escopo

- Tirar uma faixa da coleção pela linha: o sinal `trackRemoved` está declarado e a chamada a
  `removeTrackFromCollection` fica para a fatia `colecoes-alcance`, junto com o gesto em
  lote. Declarar o sinal aqui e usá-lo lá é o contrato entre as duas.
- Reordenar faixas dentro da coleção (`moveTrackInCollection`): o motor existe, arrastar
  linha é trabalho de outra fatia e ninguém pediu ainda.
- Coleções na busca e o botão "+ Coleção" do cabeçalho da biblioteca: fatia
  `colecoes-alcance`.
- Capa da coleção (mosaico das quatro primeiras): não está em nenhum desenho aprovado.
