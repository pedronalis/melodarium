---
slug: podcast-vazio
feature: melodia-capa-manda
status: aprovado
depende-de: [moldura-capa]
decisao-humana: sim
spec: design/Podcast.dc.html e design/SemMusica.dc.html (telas 4 e 5 aprovadas em 2026-08-27)
---

# Plano: podcast-vazio

**Goal:** Fechar as duas telas que faltam da moldura nova: o podcast, com o que muda num
player de fala (velocidade e pular 30 s), e o estado "nada tocando", que em vez de uma capa
cinza vazia oferece continuar de onde parou, embaralhar tudo, ou atacar as nunca ouvidas.

**Arquitetura:** `PodcastPane.qml` (hoje stub) embrulha o `PodcastSection.qml` que já existe
— ele já traz shows, episódios, downloads e "continuar ouvindo", e não vai ser reescrito;
o que muda é que os controles de reprodução saem dele (agora vivem no painel) e entram os de
fala. `EmptyPane.qml` é novo. Retomar do minuto exato exige guardar a posição da faixa, que o
banco ainda não faz: entra como migração 5 e um método no `PlayStatsRecorder`.

**Constraints globais:** Qt 6.10.3 / QML. A posição só é gravada a cada 5 s de reprodução e
ao pausar — gravar a cada tick do `positionChanged` bateria no SQLite dezenas de vezes por
segundo.

## Arquivos

- Criar: `src/EmptyPane.qml` (era stub) · `src/SpeedControl.qml`
- Modificar: `src/PodcastPane.qml` (era stub) · `src/PodcastSection.qml` (tirar transporte) ·
  `src/database.cpp` (migração 5) · `src/playstatsrecorder.h` · `src/playstatsrecorder.cpp` ·
  `src/librarybrowser.h` · `src/librarybrowser.cpp` (`lastPlayed`) · `src/Main.qml` · `CMakeLists.txt`
- Modificar: `tests/tst_library.cpp` · Testar: `tests/tst_library.cpp`

## Interfaces

- **Consome:**
  - Contrato da fatia `moldura-capa`: o `StackLayout` de `Main.qml` tem índice 1 =
    `PodcastPane`, índice 2 = `EmptyPane`; `Main.qml` expõe `property string section`.
  - `PodcastLibrary` (já existe): `shows()`, `continueListening(int limit)`,
    `playEpisode(int)`, `savePosition(int episodeId, int positionMs)`,
    `markPlayed(int, bool)`, `downloadEpisode(int)`, `episodeForPath(QString)`.
  - `AudioEngine`: `speed` (property), `setSpeed(double)`, `seek(double)`, `position`,
    `loadPlaylist(QStringList, int)`, `play()`.
  - `LibraryBrowser.clauseNeverPlayed()` e `LibraryBrowser.clauseForAll()` (já existem).
  - `TrackListModel.loadFromQuery(clause, bindings)` e `allPaths()`.
- **Produz:**
  - `Q_INVOKABLE void PlayStatsRecorder::savePosition(const QString &path, int positionMs)`
  - `Q_INVOKABLE QVariantMap LibraryBrowser::lastPlayed()` — chaves `path`, `title`,
    `artist`, `positionMs` (int), `albumId` (int). Mapa vazio se nada foi tocado ainda.
  - `SpeedControl.qml`: `property real speed`, `signal speedPicked(real value)`.
  - `EmptyPane.qml`: `signal playRequested(string mode)` — `mode` ∈ `"resume"`,
    `"shuffle"`, `"never"`.

## Tasks

### Task 1: Migração 5 — a posição de onde a faixa parou

- [ ] Em `src/database.cpp`, acrescentar ao fim da lista `migrations()` (sem `#` dentro do
      literal cru — `docs/solutions/build-errors/2026-08-27-moc-raw-string-url-vazio.md`):

```cpp
        QStringLiteral(R"SQL(
ALTER TABLE track_stats ADD COLUMN last_position_ms INTEGER NOT NULL DEFAULT 0;
)SQL"),
```

- [ ] Em `tests/tst_library.cpp`, acrescentar e declarar em `private slots:`:

```cpp
void TestLibrary::migration5AddsLastPosition()
{
    QTemporaryDir dir;
    const QString dbPath = dir.filePath(QStringLiteral("m5.db"));
    QVERIFY(Database::openConnection(QStringLiteral("m5"), dbPath));
    QSqlDatabase db = QSqlDatabase::database(QStringLiteral("m5"));
    QVERIFY(Database::migrate(db));

    QSqlQuery v(db);
    QVERIFY(v.exec(QStringLiteral("PRAGMA user_version")));
    QVERIFY(v.next());
    QCOMPARE(v.value(0).toInt(), 5);

    QSqlQuery c(db);
    QVERIFY(c.exec(QStringLiteral("SELECT COUNT(*) FROM pragma_table_info('track_stats') "
                                  "WHERE name = 'last_position_ms'")));
    QVERIFY(c.next());
    QCOMPARE(c.value(0).toInt(), 1);
    QSqlDatabase::removeDatabase(QStringLiteral("m5"));
}
```

- [ ] verificação mecânica da task: `cmake --build build && ./build/tests/tst_library` → exit 0
- [ ] commit:

```bash
git add src/database.cpp tests/tst_library.cpp
git commit -m "feat(library): migration 5 remembers where a track stopped"
```

### Task 2: Gravar e ler a posição

- [ ] Em `src/playstatsrecorder.h`, acrescentar ao bloco público:

```cpp
    Q_INVOKABLE void savePosition(const QString &path, int positionMs);
```

- [ ] Em `src/playstatsrecorder.cpp`, acrescentar (siga o padrão de conexão dos métodos
      vizinhos — `QSqlDatabase::database(QLatin1String(Database::kUiConnection))`):

```cpp
void PlayStatsRecorder::savePosition(const QString &path, int positionMs)
{
    if (path.isEmpty() || positionMs < 0)
        return;

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "UPDATE track_stats SET last_position_ms = ? "
        "WHERE track_id = (SELECT id FROM tracks WHERE path = ?)"));
    q.addBindValue(positionMs);
    q.addBindValue(path);
    q.exec();
}
```

- [ ] Em `src/librarybrowser.h`, acrescentar `Q_INVOKABLE QVariantMap lastPlayed();` e, em
      `src/librarybrowser.cpp`:

```cpp
QVariantMap LibraryBrowser::lastPlayed()
{
    QVariantMap out;
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral(
            "SELECT t.path, IFNULL(t.title,''), IFNULL(ar.name,''), "
            "IFNULL(ts.last_position_ms,0), IFNULL(t.album_id,0) "
            "FROM track_stats ts "
            "JOIN tracks t ON t.id = ts.track_id AND t.removed_at IS NULL "
            "LEFT JOIN artists ar ON ar.id = t.artist_id "
            "WHERE ts.last_played_at IS NOT NULL "
            "ORDER BY ts.last_played_at DESC LIMIT 1"))
        || !q.next())
        return out;

    out.insert(QStringLiteral("path"), q.value(0).toString());
    out.insert(QStringLiteral("title"), q.value(1).toString());
    out.insert(QStringLiteral("artist"), q.value(2).toString());
    out.insert(QStringLiteral("positionMs"), q.value(3).toInt());
    out.insert(QStringLiteral("albumId"), q.value(4).toInt());
    return out;
}
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0 e
      `grep -c "savePosition" src/playstatsrecorder.cpp` → `1`
- [ ] commit:

```bash
git add src/playstatsrecorder.h src/playstatsrecorder.cpp src/librarybrowser.h src/librarybrowser.cpp
git commit -m "feat(library): save and read the position a track stopped at"
```

### Task 3: `SpeedControl.qml` e o podcast na moldura nova

- [ ] Criar `src/SpeedControl.qml`:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property real speed: 1.0

    signal speedPicked(real value)

    readonly property var opcoes: [0.8, 1.0, 1.25, 1.5, 1.75, 2.0]

    implicitWidth: label.implicitWidth + Theme.marginL * 2
    implicitHeight: 26
    radius: Theme.iRadiusS
    color: area.containsMouse ? Theme.mSurfaceVariant : "transparent"
    border.width: Theme.borderS
    border.color: Theme.mSurfaceVariant

    Text {
        id: label
        anchors.centerIn: parent
        text: root.speed.toFixed(root.speed === Math.floor(root.speed) ? 0 : 2)
              .replace(".00", "") + "x"
        font.family: Theme.fontFamilyFixed
        font.pointSize: Theme.fontSizeS
        color: Theme.mOnSurface
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.popup(root, 0, root.height + Theme.marginXS)
    }

    Menu {
        id: menu

        Repeater {
            model: root.opcoes

            MenuItem {
                required property real modelData
                text: modelData + "x"
                onTriggered: root.speedPicked(modelData)
            }
        }
    }
}
```

- [ ] Substituir o conteúdo do stub `src/PodcastPane.qml` por:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property bool episodePlaying: false
    property string currentPath: ""

    color: Theme.mSurfaceVariant
    radius: Theme.radiusM
    border.width: Theme.borderS
    border.color: Theme.mOutline
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginL
        spacing: Theme.marginM

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Text {
                text: qsTr("Podcast")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }
            Item { Layout.fillWidth: true }

            // Só faz sentido enquanto é um episódio que está tocando, não um álbum.
            SpeedControl {
                visible: root.episodePlaying
                speed: AudioEngine.speed
                onSpeedPicked: function (v) { AudioEngine.setSpeed(v) }
            }
            IconButton {
                visible: root.episodePlaying
                icon: "history"
                size: Theme.fontSizeL
                tooltip: qsTr("voltar 30 s")
                onClicked: AudioEngine.seek(Math.max(0, AudioEngine.position - 30))
            }
            IconButton {
                visible: root.episodePlaying
                icon: "chevron-right"
                size: Theme.fontSizeL
                tooltip: qsTr("avançar 30 s")
                onClicked: AudioEngine.seek(AudioEngine.position + 30)
            }
        }

        PodcastSection {
            Layout.fillWidth: true
            Layout.fillHeight: true
            episodePlaying: root.episodePlaying
            currentPath: root.currentPath
        }
    }
}
```

- [ ] Em `src/PodcastSection.qml`, REMOVER os três `IconButton` de transporte (as linhas
      119-133 do arquivo atual, o bloco de play/pause/velocidade que ficava no cabeçalho da
      seção): eles agora vivem no painel e no `PodcastPane`. Não mexa em mais nada do arquivo.
- [ ] Registrar `src/SpeedControl.qml` em `QML_FILES` no `CMakeLists.txt`.
- [ ] verificação mecânica da task:
      `cmake --build build && test "$(QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError')" -eq 0` → exit 0
- [ ] commit:

```bash
git add src/SpeedControl.qml src/PodcastPane.qml src/PodcastSection.qml CMakeLists.txt
git commit -m "feat(ui): podcast pane with speed and 30-second jumps"
```

### Task 4: `EmptyPane.qml` — o convite no lugar do vazio

- [ ] Substituir o conteúdo do stub `src/EmptyPane.qml` por:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property var resumeInfo: ({})
    property int neverCount: 0

    signal playRequested(string mode)

    color: Theme.mSurfaceVariant
    radius: Theme.radiusM
    border.width: Theme.borderS
    border.color: Theme.mOutline
    clip: true

    function refresh() {
        root.resumeInfo = LibraryBrowser.lastPlayed()
        root.neverCount = LibraryBrowser.neverPlayedCount()
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Database
        function onScanFinished(added, updated, removed) { root.refresh() }
    }

    component Atalho: Rectangle {
        id: atalho

        property string glyph: ""
        property string label: ""
        property string badge: ""

        signal clicked

        Layout.fillWidth: true
        implicitHeight: 40
        radius: Theme.radiusS
        color: atalhoArea.containsMouse ? Theme.mSurface : "transparent"
        border.width: Theme.borderS
        border.color: Theme.mSurface

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.marginM
            anchors.rightMargin: Theme.marginM
            spacing: Theme.marginM

            Text {
                text: atalho.glyph
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeL
                color: Theme.mOnSurfaceVariant
            }
            Text {
                Layout.fillWidth: true
                text: atalho.label
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurface
            }
            Text {
                visible: atalho.badge !== ""
                text: atalho.badge
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOutline
            }
        }

        MouseArea {
            id: atalhoArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: atalho.clicked()
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.marginXL * 2, 420)
        spacing: Theme.marginL

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Icons.get("music")
            font.family: Icons.fontFamily
            font.pointSize: Theme.fontSizeXXXL
            color: Theme.mOutline
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Nada tocando")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeL
            color: Theme.mOnSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS

            Atalho {
                visible: root.resumeInfo.path !== undefined
                glyph: Icons.get("play")
                label: root.resumeInfo.title !== undefined
                       ? qsTr("Continuar: ") + root.resumeInfo.title : ""
                badge: root.resumeInfo.positionMs > 0
                       ? Math.floor(root.resumeInfo.positionMs / 60000) + ":"
                         + ("0" + Math.floor((root.resumeInfo.positionMs % 60000) / 1000)).slice(-2)
                       : ""
                onClicked: root.playRequested("resume")
            }
            Atalho {
                glyph: Icons.get("shuffle")
                label: qsTr("Tocar tudo em ordem aleatória")
                onClicked: root.playRequested("shuffle")
            }
            Atalho {
                glyph: Icons.get("heart")
                label: qsTr("Nunca ouvi")
                badge: root.neverCount > 0 ? String(root.neverCount) : ""
                onClicked: root.playRequested("never")
            }
        }
    }
}
```

- [ ] Acrescentar o contador que o pane usa — em `src/librarybrowser.h`,
      `Q_INVOKABLE int neverPlayedCount();` e em `src/librarybrowser.cpp`:

```cpp
int LibraryBrowser::neverPlayedCount()
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral(
            "SELECT COUNT(*) FROM tracks t "
            "LEFT JOIN track_stats ts ON ts.track_id = t.id "
            "WHERE t.removed_at IS NULL AND IFNULL(ts.play_count, 0) = 0"))
        || !q.next())
        return 0;
    return q.value(0).toInt();
}
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0 e
      `grep -c 'signal playRequested' src/EmptyPane.qml` → `1`
- [ ] commit:

```bash
git add src/EmptyPane.qml src/librarybrowser.h src/librarybrowser.cpp
git commit -m "feat(ui): the empty state invites instead of showing a blank cover"
```

### Task 5: Ligar os dois panes ao `Main.qml`

- [ ] Em `src/Main.qml`, substituir os filhos stub do `StackLayout` por:

```qml
            PodcastPane {
                episodePlaying: root.currentEpisodeId > 0
                currentPath: AudioEngine.currentFile
            }

            EmptyPane {
                onPlayRequested: function (mode) { root.startFromEmpty(mode) }
            }
```

- [ ] Acrescentar a função a `Main.qml`:

```qml
    function startFromEmpty(mode) {
        if (mode === "resume") {
            const info = LibraryBrowser.lastPlayed()
            if (info.path === undefined)
                return
            AudioEngine.loadPlaylist([info.path], 0)
            AudioEngine.play()
            if (info.positionMs > 0)
                AudioEngine.seek(info.positionMs / 1000)
            return
        }

        trackModel.loadFromQuery(mode === "never" ? LibraryBrowser.clauseNeverPlayed()
                                                  : LibraryBrowser.clauseForAll(), [])
        let paths = trackModel.allPaths()
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
        root.queuePaths = paths
        AudioEngine.loadPlaylist(paths, 0)
        AudioEngine.play()
    }
```

- [ ] Gravar a posição da faixa enquanto ela toca — acrescentar a `Main.qml`:

```qml
    // Cinco segundos: escrever a cada positionChanged bateria no SQLite dezenas de vezes
    // por segundo, e a diferença é imperceptível ao retomar.
    Timer {
        running: AudioEngine.playing && root.currentEpisodeId === 0
        interval: 5000
        repeat: true
        onTriggered: PlayStatsRecorder.savePosition(AudioEngine.currentFile,
                                                    Math.floor(AudioEngine.position * 1000))
    }

    Connections {
        target: AudioEngine
        function onPlayingChanged() {
            if (!AudioEngine.playing && root.currentEpisodeId === 0)
                PlayStatsRecorder.savePosition(AudioEngine.currentFile,
                                               Math.floor(AudioEngine.position * 1000))
        }
    }
```

- [ ] verificação mecânica da task:
      `cmake --build build && test "$(QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError')" -eq 0` → exit 0
- [ ] commit:

```bash
git add src/Main.qml
git commit -m "feat(ui): wire podcast and empty panes, remember playback position"
```

### Task 6: Teste da posição salva

- [ ] Em `tests/tst_library.cpp`, acrescentar e declarar em `private slots:`:

```cpp
void TestLibrary::savePositionRoundTrips()
{
    // A fixture deste arquivo já cria banco temporário com faixas e track_stats.
    PlayStatsRecorder rec;
    LibraryBrowser browser;

    const QString path = seededTrackPath();     // helper da fixture
    rec.recordPlay(path);
    rec.savePosition(path, 107000);

    const QVariantMap last = browser.lastPlayed();
    QCOMPARE(last.value(QStringLiteral("path")).toString(), path);
    QCOMPARE(last.value(QStringLiteral("positionMs")).toInt(), 107000);

    // Caminho que não existe não pode explodir nem escrever nada.
    rec.savePosition(QStringLiteral("/nao/existe.flac"), 5000);
    QCOMPARE(browser.lastPlayed().value(QStringLiteral("path")).toString(), path);
}
```

- [ ] verificação mecânica da task: `./build/tests/tst_library` → exit 0 e
      `./build/tests/tst_library -functions | grep -c savePositionRoundTrips` → `1`
- [ ] commit:

```bash
git add tests/tst_library.cpp
git commit -m "test(library): playback position round-trips and ignores unknown paths"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `test "$(QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError')" -eq 0` → exit 0
- `grep -q "last_position_ms" src/database.cpp` → exit 0
- `grep -q "neverPlayedCount" src/librarybrowser.h` → exit 0
- `grep -q "SpeedControl" CMakeLists.txt` → exit 0
- **Decisão humana:** o Pedro abre o app sem nada tocando e confirma que os três atalhos
  aparecem e funcionam; depois abre um episódio e confirma velocidade e os pulos de 30 s.

## Fora de escopo

- Retomar automaticamente ao abrir o app: o atalho é explícito, por decisão de produto — o
  app não começa a tocar sozinho.
- Sincronizar posição entre faixa e episódio: o podcast já tem `savePosition` próprio, com
  semântica diferente (por episódio, não por arquivo).
- Fila visível nesta direção: ela saiu da tela; a única pista é a ordem tocando. Trazer uma
  gaveta de fila é fatia nova.
