---
slug: moldura-capa
feature: melodia-capa-manda
status: em-execucao
depende-de: [like-faixas]
decisao-humana: sim
spec: design/Main.dc.html (tela 1 aprovada em 2026-08-27)
---

# Plano: moldura-capa

**Goal:** Trocar a moldura da janela pela direção aprovada: barra de ícones estreita à
esquerda, painel do que está tocando (capa de 340px, título grande, controles) no meio-esquerda,
e um miolo trocável à direita. É a fatia que muda a cara do app; as outras preenchem o miolo.

**Arquitetura:** `Main.qml` deixa de ser `ColumnLayout{topo; conteúdo; PlayerBar}` e passa a
ser `RowLayout{IconRail; NowPlayingPanel; StackLayout}`. A barra de transporte inferior
(`PlayerBar.qml`) é aposentada — seus controles vivem no painel agora. O painel lê o
`AudioEngine` direto, como o `PlayerBar` fazia; nada de estado novo.

**Constraints globais:** Qt 6.10.3 / QML. Tokens do `Theme` singleton, nenhuma cor literal.
Janela mínima continua 720×480 — abaixo de 900px de largura o painel encolhe a capa em vez de
espremer o miolo (a lista é o que não pode colapsar: `docs/solutions/ui/2026-08-27-layout-aninhado-colapsa-o-irmao.md`).

## Arquivos

- Criar: `src/IconRail.qml` · `src/NowPlayingPanel.qml`
- Modificar: `src/Main.qml` (reescrita da moldura) · `CMakeLists.txt` (QML_FILES)
- Modificar: `src/librarybrowser.h` · `src/librarybrowser.cpp` (`trackForPath`)
- Apagar: `src/PlayerBar.qml`
- Modificar: `tests/tst_librarybrowser.cpp` · Testar: `tests/tst_librarybrowser.cpp`

## Interfaces

- **Consome:** a coluna `liked_at` e o `Q_INVOKABLE bool LibraryBrowser::toggleLike(int trackId)`
  da fatia `like-faixas` — o `trackForPath` desta fatia LÊ `t.liked_at`, então ela não roda
  antes da migração 4.
  `AudioEngine` (singleton QML) — `position`, `duration`, `playing`, `volume`,
  `currentFile`, `speed` (propriedades) e `play()`, `pause()`, `togglePause()`, `seek(double
seconds)`, `next()`, `previous()`, `setVolume(double)`, `setSpeed(double)`.
  `CoverCache.coverUrlForTrack(path, albumId)`. `TagEditor.qml` (`property int trackId`).
- **Produz** — as fatias `biblioteca-densa`, `busca-overlay` e `podcast-vazio` consomem verbatim:
  - `IconRail.qml`: `property string current` (valores: `"library"`, `"albums"`, `"tags"`,
    `"podcast"`, `"search"`), `signal chosen(string section)`.
  - `NowPlayingPanel.qml`: `property int trackId` (0 = nada tocando),
    `property bool compact` (true encolhe a capa para 200px), `signal likeRequested(int trackId)`.
  - `Main.qml`: `property string section` (mesma lista do `IconRail.current`) e
    `function showSection(section, id)` — o miolo é escolhido por essa propriedade.
  - Slot do miolo: o `StackLayout` de `Main.qml` tem os filhos NESTA ORDEM —
    índice 0 `LibraryPane`, 1 `PodcastPane`, 2 `EmptyPane`. Fatias que criam esses componentes
    devem entregá-los com esse nome de arquivo (`LibraryPane.qml`, `PodcastPane.qml`,
    `EmptyPane.qml`).
  - `Q_INVOKABLE QVariantMap LibraryBrowser::trackForPath(const QString &path)` — chaves
    `id` (int), `title`, `artist`, `album` (QString), `albumId` (int), `year` (int),
    `codec` (QString), `sampleRate` (int), `bitsPerSample` (int), `liked` (bool).
    Mapa vazio quando o path não está na biblioteca (arquivo de podcast, por exemplo).

## Tasks

### Task 1: `trackForPath` — do arquivo tocando para os dados da faixa

- [x] Em `src/librarybrowser.h`, acrescentar junto dos outros `Q_INVOKABLE`:

```cpp
    Q_INVOKABLE QVariantMap trackForPath(const QString &path);
```

      e `#include <QVariantMap>` no topo, se ainda não estiver.

- [x] Em `src/librarybrowser.cpp`, acrescentar ao fim:

```cpp
QVariantMap LibraryBrowser::trackForPath(const QString &path)
{
    QVariantMap out;
    if (path.isEmpty())
        return out;

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "SELECT t.id, IFNULL(t.title,''), IFNULL(ar.name,''), IFNULL(al.title,''), "
        "IFNULL(t.album_id,0), IFNULL(t.year,0), IFNULL(t.codec,''), "
        "IFNULL(t.sample_rate,0), IFNULL(t.bits_per_sample,0), t.liked_at IS NOT NULL "
        "FROM tracks t "
        "LEFT JOIN artists ar ON ar.id = t.artist_id "
        "LEFT JOIN albums al ON al.id = t.album_id "
        "WHERE t.path = ?"));
    q.addBindValue(path);
    if (!q.exec() || !q.next())
        return out;

    out.insert(QStringLiteral("id"), q.value(0).toInt());
    out.insert(QStringLiteral("title"), q.value(1).toString());
    out.insert(QStringLiteral("artist"), q.value(2).toString());
    out.insert(QStringLiteral("album"), q.value(3).toString());
    out.insert(QStringLiteral("albumId"), q.value(4).toInt());
    out.insert(QStringLiteral("year"), q.value(5).toInt());
    out.insert(QStringLiteral("codec"), q.value(6).toString());
    out.insert(QStringLiteral("sampleRate"), q.value(7).toInt());
    out.insert(QStringLiteral("bitsPerSample"), q.value(8).toInt());
    out.insert(QStringLiteral("liked"), q.value(9).toBool());
    return out;
}
```

- [x] Em `tests/tst_librarybrowser.cpp`, acrescentar o slot e declará-lo em `private slots:`:

```cpp
void TestLibraryBrowser::trackForPathReturnsFieldsOrEmpty()
{
    LibraryBrowser browser;
    const QVariantMap none = browser.trackForPath(QStringLiteral("/nao/existe.flac"));
    QVERIFY(none.isEmpty());

    const QString path = firstTrackPath();      // helper já existente na fixture
    const QVariantMap m = browser.trackForPath(path);
    QVERIFY(!m.isEmpty());
    QCOMPARE(m.value(QStringLiteral("id")).toInt(), firstTrackId());
    QVERIFY(m.contains(QStringLiteral("codec")));
    QCOMPARE(m.value(QStringLiteral("liked")).toBool(), false);
}
```

      Se a fixture não tiver `firstTrackPath()`, acrescente-o ao lado de `firstTrackId()`,
      devolvendo o `path` da mesma faixa.

- [x] verificação mecânica da task: `cmake --build build && ./build/tests/tst_librarybrowser` → exit 0
- [x] commit:

```bash
git add src/librarybrowser.h src/librarybrowser.cpp tests/tst_librarybrowser.cpp
git commit -m "feat(library): look up the playing track by its file path"
```

### Task 2: `IconRail.qml` — a barra de ícones

- [x] Criar `src/IconRail.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property string current: "library"

    signal chosen(string section)

    implicitWidth: 56
    color: "transparent"

    Rectangle {
        anchors.right: parent.right
        width: Theme.borderS
        height: parent.height
        color: Theme.mSurfaceVariant
    }

    readonly property var items: [
        { key: "library", icon: "list",     tip: qsTr("Biblioteca") },
        { key: "albums",  icon: "disc",     tip: qsTr("Álbuns") },
        { key: "tags",    icon: "tags",     tip: qsTr("Tags") },
        { key: "podcast", icon: "microphone", tip: qsTr("Podcast") },
        { key: "search",  icon: "search",   tip: qsTr("Buscar") }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.marginXL
        spacing: Theme.marginS

        Repeater {
            model: root.items

            Rectangle {
                id: cell

                required property var modelData

                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Theme.iRadiusS
                color: root.current === cell.modelData.key
                       ? Theme.mSurfaceVariant
                       : (area.containsMouse ? Theme.mSurfaceVariant : "transparent")
                opacity: root.current === cell.modelData.key || area.containsMouse ? 1.0 : 0.85

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.get(cell.modelData.icon)
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeL
                    color: root.current === cell.modelData.key ? Theme.mTertiary : Theme.mOnSurfaceVariant
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chosen(cell.modelData.key)
                }
            }
        }
    }
}
```

- [x] verificação mecânica da task: `grep -c 'signal chosen' src/IconRail.qml` → `1`
- [x] commit:

```bash
git add src/IconRail.qml
git commit -m "feat(ui): icon rail replaces the wide sidebar"
```

### Task 3: `NowPlayingPanel.qml` — a capa manda

- [x] Criar `src/NowPlayingPanel.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property int trackId: 0
    property bool compact: false
    property var info: ({})

    signal likeRequested(int trackId)

    implicitWidth: 392
    color: Theme.mSurface

    // Um degradê muito sutil separa o painel do miolo sem precisar de borda.
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.mSurfaceVariant }
        GradientStop { position: 0.6; color: Theme.mSurface }
    }

    readonly property int coverSide: root.compact ? 200 : 340

    function refresh() {
        const path = AudioEngine.currentFile
        root.info = path === "" ? ({}) : LibraryBrowser.trackForPath(path)
        root.trackId = root.info.id !== undefined ? root.info.id : 0
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: AudioEngine
        function onCurrentFileChanged() { root.refresh() }
    }

    Connections {
        target: LibraryBrowser
        function onLikedChanged(id, liked) {
            if (id === root.trackId)
                root.refresh()
        }
    }

    function formatTime(seconds) {
        if (!(seconds > 0))
            return "0:00"
        const total = Math.floor(seconds)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginXL + Theme.marginS
        spacing: Theme.marginXL

        Rectangle {
            Layout.preferredWidth: root.coverSide
            Layout.preferredHeight: root.coverSide
            Layout.alignment: Qt.AlignHCenter
            radius: Theme.radiusM
            color: Theme.mSurfaceVariant
            clip: true

            Image {
                anchors.fill: parent
                source: root.info.albumId !== undefined
                        ? CoverCache.coverUrlForTrack(AudioEngine.currentFile, root.info.albumId)
                        : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                sourceSize.width: root.coverSide
            }

            Text {
                anchors.centerIn: parent
                visible: root.trackId === 0
                text: Icons.get("music")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeXXXL
                color: Theme.mOutline
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginL

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.marginXXS

                Text {
                    Layout.fillWidth: true
                    text: root.info.title !== undefined && root.info.title !== ""
                          ? root.info.title : qsTr("nada tocando")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeXXL
                    font.weight: Theme.fontWeightBold
                    color: Theme.mOnSurface
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.info.artist !== undefined && root.info.artist !== ""
                    text: root.info.artist !== undefined ? root.info.artist : ""
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeL
                    color: Theme.mOnSurfaceVariant
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.trackId > 0
                    text: [root.info.album, root.info.year > 0 ? root.info.year : "",
                           root.info.codec].filter(function (p) { return p !== "" && p !== undefined })
                                           .join(" · ")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: Theme.mOutline
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: root.trackId > 0
                icon: "heart"
                size: Theme.fontSizeXL
                accent: root.info.liked === true
                onClicked: root.likeRequested(root.trackId)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS

            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 3
                radius: Theme.radiusXXS
                color: Theme.mSurfaceVariant

                Rectangle {
                    width: AudioEngine.duration > 0
                           ? parent.width * (AudioEngine.position / AudioEngine.duration) : 0
                    height: parent.height
                    radius: parent.radius
                    color: Theme.mTertiary
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.marginS
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function (mouse) {
                        if (AudioEngine.duration > 0)
                            AudioEngine.seek(AudioEngine.duration * (mouse.x / track.width))
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.formatTime(AudioEngine.position)
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeXS
                    color: Theme.mOnSurfaceVariant
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.formatTime(AudioEngine.duration)
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeXS
                    color: Theme.mOnSurfaceVariant
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.marginXL

            IconButton { icon: "shuffle"; size: Theme.fontSizeL; onClicked: {} }
            IconButton { icon: "track-prev"; size: Theme.fontSizeXL; onClicked: AudioEngine.previous() }

            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: 26
                color: Theme.mTertiary

                Text {
                    anchors.centerIn: parent
                    text: AudioEngine.playing ? Icons.get("pause") : Icons.get("play")
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeXL
                    color: Theme.mOnTertiary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioEngine.togglePause()
                }
            }

            IconButton { icon: "track-next"; size: Theme.fontSizeXL; onClicked: AudioEngine.next() }
            IconButton { icon: "repeat"; size: Theme.fontSizeL; onClicked: {} }
        }

        TagEditor {
            Layout.fillWidth: true
            visible: root.trackId > 0
            trackId: root.trackId
        }

        Item { Layout.fillHeight: true }
    }
}
```

- [x] verificação mecânica da task: `grep -c 'signal likeRequested' src/NowPlayingPanel.qml` → `1`
- [x] commit:

```bash
git add src/NowPlayingPanel.qml
git commit -m "feat(ui): now-playing panel with the large cover and transport"
```

### Task 4: Registrar os componentes no build

- [ ] Em `CMakeLists.txt`, acrescentar à lista `QML_FILES` do `qt_add_qml_module`, em ordem
      alfabética junto dos existentes:

```cmake
        src/IconRail.qml
        src/NowPlayingPanel.qml
```

      e REMOVER a linha `src/PlayerBar.qml`.

- [ ] Apagar o arquivo: `git rm src/PlayerBar.qml`
- [ ] verificação mecânica da task:
      `cmake -B build -G Ninja && cmake --build build` → exit 0 e
      `test "$(grep -c 'PlayerBar' CMakeLists.txt)" -eq 0` → exit 0
- [ ] commit:

```bash
git add CMakeLists.txt
git commit -m "build(ui): register the rail and panel, retire the transport bar"
```

### Task 5: A moldura nova em `Main.qml`

- [ ] Substituir em `src/Main.qml` a raiz visual — o `ColumnLayout` que hoje contém
      `RowLayout` (topo), `StackLayout` e `PlayerBar` — por esta estrutura, PRESERVANDO todo o
      bloco de `property`, `function` e `Connections` que já existe acima dela (o roteamento
      de seções, o tratamento de `scanFinished`, `trackFinished` e `episodePlayRequested`
      continua valendo):

```qml
    property string section: "library"

    function showPane(name) {
        if (name === "search") {
            searchOverlay.open()
            return
        }
        root.section = name
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        IconRail {
            Layout.fillHeight: true
            current: root.section
            onChosen: function (name) { root.showPane(name) }
        }

        NowPlayingPanel {
            id: nowPlaying
            Layout.fillHeight: true
            Layout.preferredWidth: 392
            Layout.maximumWidth: 392
            Layout.fillWidth: false
            compact: root.width < 900
            onLikeRequested: function (id) { LibraryBrowser.toggleLike(id) }
        }

        StackLayout {
            id: pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            // A lista é o ponto da tela: nunca cede espaço ao painel.
            Layout.minimumWidth: 360
            currentIndex: root.section === "podcast" ? 1 : (AudioEngine.currentFile === "" && root.section === "library" && trackModel.count === 0 ? 2 : 0)

            LibraryPane { }
            PodcastPane { }
            EmptyPane { }
        }
    }
```

      **Enquanto as fatias `biblioteca-densa` e `podcast-vazio` não existirem**, os três
      componentes ainda não foram criados. Para esta fatia compilar e abrir sozinha, crie os
      três como stubs mínimos, no mesmo commit, e registre-os no `QML_FILES`:

```qml
// src/LibraryPane.qml — stub, substituído pela fatia biblioteca-densa
import QtQuick
import Melodia.App

Rectangle {
    color: Theme.mSurfaceVariant
    radius: Theme.radiusM
    border.width: Theme.borderS
    border.color: Theme.mOutline
}
```

      Repita o mesmo conteúdo em `src/PodcastPane.qml` e `src/EmptyPane.qml`, trocando só o
      comentário do topo. O `searchOverlay` citado em `showPane` é da fatia `busca-overlay`;
      até ela existir, troque a chamada por `console.log("busca ainda não implementada")`.

- [ ] verificação mecânica da task:
      `cmake --build build && QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec "is not a type|Unable to assign|ReferenceError"` → `0`
- [ ] commit:

```bash
git add src/Main.qml src/LibraryPane.qml src/PodcastPane.qml src/EmptyPane.qml CMakeLists.txt
git commit -m "feat(ui): rebuild the window around the now-playing panel"
```

### Task 6: A janela não pode espremer a lista

- [ ] Conferir com medição, não com o olho — o mesmo método que pegou o painel de 2px:
      acrescentar temporariamente a `Main.qml`, dentro do `RowLayout`:

```qml
        Timer {
            running: true; interval: 900
            onTriggered: console.log("MEDIDA rail=" + parent.children[0].width
                + " painel=" + nowPlaying.width + " miolo=" + pane.width
                + " janela=" + root.width)
        }
```

- [ ] Rodar e ler a medida:
      `QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 6 ./build/appmelodia 2>&1 | grep -a MEDIDA`
      → o miolo tem de ficar ≥ 360 (numa janela de 1100: rail 56 + painel 392 + miolo ~652).
- [ ] Remover o `Timer` depois de ler a medida.
- [ ] verificação mecânica da task:
      `test "$(grep -c 'MEDIDA' src/Main.qml)" -eq 0` → exit 0 e `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/Main.qml
git commit -m "fix(ui): keep the pane above its minimum width"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `test "$(QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError')" -eq 0` → exit 0
- `grep -q "trackForPath" src/librarybrowser.h` → exit 0
- `test "$(ls src/PlayerBar.qml 2>/dev/null | wc -l)" -eq 0` → exit 0
- **Decisão humana:** o Pedro abre `./build/appmelodia` numa sessão gráfica e confirma que a
  janela ficou como a tela 1 do canvas — capa grande à esquerda, ícones na lateral, miolo à
  direita. Sem esse OK a fatia não fecha.

## Fora de escopo

- O conteúdo dos três miolos (fatias `biblioteca-densa`, `podcast-vazio`) — aqui eles são stubs.
- Embaralhar e repetir: os botões existem e ficam inertes; ligar é fatia futura, e o
  `AudioEngine` ainda não expõe esses modos.
- Arrastar a divisa entre painel e miolo. Larguras fixas nesta fatia.
