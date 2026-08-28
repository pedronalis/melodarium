---
slug: busca-overlay
feature: melodia-capa-manda
status: concluido
depende-de: [moldura-capa]
decisao-humana: nao
spec: design/Busca.dc.html (tela 3 aprovada em 2026-08-27)
---

# Plano: busca-overlay

**Goal:** A busca vira um painel que abre por cima de qualquer tela — pela lupa da barra de
ícones ou por atalho de teclado — e procura tudo de uma vez: faixa, álbum, artista e episódio
de podcast na mesma lista, tocando com Enter sem tirar a mão do teclado.

**Arquitetura:** `SearchOverlay.qml` é um `Popup` modal do QtQuick.Controls sobre a janela
inteira. Os resultados vêm de uma chamada só (`LibraryBrowser::searchGrouped`) que faz quatro
consultas e devolve uma lista achatada com um campo `kind` por item — o QML não monta SQL nem
decide ordem. A busca de faixas reusa o FTS5 que já existe (`clauseForSearch` +
`toFtsPrefixQuery`); artista, álbum e episódio usam LIKE, que basta para os volumes deste app.

**Constraints globais:** Qt 6.10.3 / QML + QtQuick.Controls. Nenhuma consulta roda a cada
tecla digitada: `Timer` de 180 ms segura o texto antes de ir ao banco.

## Arquivos

- Criar: `src/SearchOverlay.qml`
- Modificar: `src/librarybrowser.h` · `src/librarybrowser.cpp` (`searchGrouped`) ·
  `src/Main.qml` (instanciar o overlay e ligar a lupa) · `CMakeLists.txt`
- Modificar: `tests/tst_librarybrowser.cpp` · Testar: `tests/tst_librarybrowser.cpp`

## Interfaces

- **Consome:**
  - `Main.qml` chama `searchOverlay.open()` na seção `"search"` do `IconRail`
    (contrato declarado pela fatia `moldura-capa`).
  - `Q_INVOKABLE QString LibraryBrowser::clauseForSearch(const QString &text)` e
    `Q_INVOKABLE QVariantList LibraryBrowser::bindingsForSearch(const QString &text)` — já
    existem; a busca de faixas passa por eles.
  - `AudioEngine.loadPlaylist(const QStringList &files, int startIndex)` e `AudioEngine.play()`.
  - `PodcastLibrary.playEpisode(int episodeId)`.
- **Produz:**
  - `Q_INVOKABLE QVariantList LibraryBrowser::searchGrouped(const QString &text, int limitPerKind = 4)`
    — cada item é um `QVariantMap` com as chaves: `kind` (QString: `"track"`, `"album"`,
    `"artist"`, `"episode"`), `id` (int), `title` (QString), `subtitle` (QString),
    `path` (QString — vazio para álbum e artista). Ordem: todas as faixas, depois álbuns,
    depois artistas, depois episódios.
  - `SearchOverlay.qml`: `function open()`, `function close()`, `property bool opened`.

## Tasks

### Task 1: `searchGrouped` no LibraryBrowser

- [x] Em `src/librarybrowser.h`, junto dos outros `Q_INVOKABLE`:

```cpp
    Q_INVOKABLE QVariantList searchGrouped(const QString &text, int limitPerKind = 4);
```

- [x] Em `src/librarybrowser.cpp`, acrescentar ao fim:

```cpp
QVariantList LibraryBrowser::searchGrouped(const QString &text, int limitPerKind)
{
    QVariantList out;
    const QString trimmed = text.trimmed();
    if (trimmed.isEmpty())
        return out;

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    const QString like = QStringLiteral("%") + trimmed + QStringLiteral("%");

    auto append = [&out](const QString &kind, int id, const QString &title,
                         const QString &subtitle, const QString &path) {
        QVariantMap row;
        row.insert(QStringLiteral("kind"), kind);
        row.insert(QStringLiteral("id"), id);
        row.insert(QStringLiteral("title"), title);
        row.insert(QStringLiteral("subtitle"), subtitle);
        row.insert(QStringLiteral("path"), path);
        out.append(row);
    };

    // Faixas — pelo FTS5 que a fatia de navegação já montou.
    QSqlQuery tq(db);
    tq.prepare(QStringLiteral(
        "SELECT t.id, IFNULL(t.title,''), IFNULL(ar.name,''), IFNULL(al.title,''), t.path "
        "FROM tracks t "
        "LEFT JOIN artists ar ON ar.id = t.artist_id "
        "LEFT JOIN albums al ON al.id = t.album_id "
        "WHERE t.removed_at IS NULL AND t.id IN "
        "(SELECT rowid FROM tracks_fts WHERE tracks_fts MATCH ?) LIMIT ?"));
    tq.addBindValue(toFtsPrefixQuery(trimmed));
    tq.addBindValue(limitPerKind);
    if (tq.exec()) {
        while (tq.next()) {
            const QString sub = tq.value(2).toString()
                                + (tq.value(3).toString().isEmpty()
                                       ? QString()
                                       : QStringLiteral(" · ") + tq.value(3).toString());
            append(QStringLiteral("track"), tq.value(0).toInt(), tq.value(1).toString(), sub,
                   tq.value(4).toString());
        }
    }

    QSqlQuery alq(db);
    alq.prepare(QStringLiteral(
        "SELECT al.id, al.title, IFNULL(ar.name,''), COUNT(t.id) "
        "FROM albums al "
        "LEFT JOIN artists ar ON ar.id = al.album_artist_id "
        "JOIN tracks t ON t.album_id = al.id AND t.removed_at IS NULL "
        "WHERE al.title LIKE ? GROUP BY al.id ORDER BY al.title COLLATE NOCASE LIMIT ?"));
    alq.addBindValue(like);
    alq.addBindValue(limitPerKind);
    if (alq.exec()) {
        while (alq.next()) {
            append(QStringLiteral("album"), alq.value(0).toInt(), alq.value(1).toString(),
                   alq.value(2).toString() + QStringLiteral(" · ")
                       + QString::number(alq.value(3).toInt()) + QStringLiteral(" faixas"),
                   QString());
        }
    }

    QSqlQuery arq(db);
    arq.prepare(QStringLiteral(
        "SELECT ar.id, ar.name, COUNT(t.id) "
        "FROM artists ar JOIN tracks t ON t.artist_id = ar.id AND t.removed_at IS NULL "
        "WHERE ar.name LIKE ? GROUP BY ar.id ORDER BY ar.name COLLATE NOCASE LIMIT ?"));
    arq.addBindValue(like);
    arq.addBindValue(limitPerKind);
    if (arq.exec()) {
        while (arq.next()) {
            append(QStringLiteral("artist"), arq.value(0).toInt(), arq.value(1).toString(),
                   QString::number(arq.value(2).toInt()) + QStringLiteral(" faixas"), QString());
        }
    }

    QSqlQuery eq(db);
    eq.prepare(QStringLiteral(
        "SELECT e.id, e.title, IFNULL(s.title,''), IFNULL(e.local_path,'') "
        "FROM podcast_episodes e "
        "LEFT JOIN podcast_shows s ON s.id = e.show_id "
        "WHERE e.title LIKE ? ORDER BY e.published_at DESC LIMIT ?"));
    eq.addBindValue(like);
    eq.addBindValue(limitPerKind);
    if (eq.exec()) {
        while (eq.next()) {
            append(QStringLiteral("episode"), eq.value(0).toInt(), eq.value(1).toString(),
                   eq.value(2).toString(), eq.value(3).toString());
        }
    }

    return out;
}
```

      Se o nome da coluna do arquivo local do episódio na sua migração não for `local_path`,
      use o nome real — confira com
      `grep -n "CREATE TABLE podcast_episodes" -A 14 src/database.cpp` ANTES de compilar.

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/librarybrowser.h src/librarybrowser.cpp
git commit -m "feat(library): one grouped search across tracks, albums, artists and episodes"
```

### Task 2: Teste da busca agrupada

- [x] Em `tests/tst_librarybrowser.cpp`, acrescentar e declarar em `private slots:`:

```cpp
void TestLibraryBrowser::searchGroupedReturnsKindsAndRespectsLimit()
{
    LibraryBrowser browser;
    QCOMPARE(browser.searchGrouped(QString()).size(), 0);
    QCOMPARE(browser.searchGrouped(QStringLiteral("   ")).size(), 0);

    const QVariantList hits = browser.searchGrouped(seededArtistName(), 4);
    QVERIFY(!hits.isEmpty());

    QSet<QString> kinds;
    for (const QVariant &v : hits) {
        const QVariantMap m = v.toMap();
        QVERIFY(m.contains(QStringLiteral("kind")));
        QVERIFY(m.contains(QStringLiteral("title")));
        QVERIFY(m.contains(QStringLiteral("path")));
        kinds.insert(m.value(QStringLiteral("kind")).toString());
    }
    QVERIFY(kinds.contains(QStringLiteral("artist")));

    // O limite é POR TIPO, não do total.
    int artistas = 0;
    for (const QVariant &v : hits) {
        if (v.toMap().value(QStringLiteral("kind")).toString() == QLatin1String("artist"))
            ++artistas;
    }
    QVERIFY(artistas <= 4);
}
```

      `seededArtistName()` é um helper novo: devolve o nome do artista que a fixture semeia.
      Acrescente-o ao lado dos outros helpers da fixture.

- [x] verificação mecânica da task: `./build/tests/tst_librarybrowser` → exit 0
- [x] commit:

```bash
git add tests/tst_librarybrowser.cpp
git commit -m "test(library): grouped search shape, empty input and per-kind limit"
```

### Task 3: `SearchOverlay.qml`

- [x] Criar `src/SearchOverlay.qml`:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodarium.App

Popup {
    id: root

    property bool opened: visible
    property var hits: []
    property int highlighted: 0

    signal trackChosen(string path)
    signal episodeChosen(int episodeId)

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: 660
    height: 520
    anchors.centerIn: Overlay.overlay
    padding: 0

    background: Rectangle {
        color: Theme.mSurfaceVariant
        radius: Theme.radiusL
        border.width: Theme.borderS
        border.color: Theme.mOutline
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.62)
    }

    onOpened: {
        input.text = ""
        root.hits = []
        root.highlighted = 0
        input.forceActiveFocus()
    }

    // Nenhuma consulta por tecla: o banco só é tocado quando a digitação para.
    Timer {
        id: debounce
        interval: 180
        onTriggered: {
            root.hits = LibraryBrowser.searchGrouped(input.text, 4)
            root.highlighted = 0
        }
    }

    function activate(index) {
        if (index < 0 || index >= root.hits.length)
            return
        const hit = root.hits[index]
        if (hit.kind === "track" && hit.path !== "") {
            root.trackChosen(hit.path)
            root.close()
        } else if (hit.kind === "episode") {
            root.episodeChosen(hit.id)
            root.close()
        }
        // álbum e artista ainda não navegam: a fatia que liga o filtro cuida disso.
    }

    function glyphFor(kind) {
        if (kind === "album") return Icons.get("disc")
        if (kind === "artist") return Icons.get("microphone")
        if (kind === "episode") return Icons.get("microphone")
        return Icons.get("music")
    }

    function labelFor(kind) {
        if (kind === "album") return qsTr("Álbum")
        if (kind === "artist") return qsTr("Artista")
        if (kind === "episode") return qsTr("Episódio")
        return qsTr("Faixa")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.marginL
            spacing: Theme.marginM

            Text {
                text: Icons.get("search")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeL
                color: Theme.mOnSurfaceVariant
            }

            TextInput {
                id: input
                Layout.fillWidth: true
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXL
                color: Theme.mOnSurface
                selectByMouse: true
                onTextChanged: debounce.restart()

                Keys.onDownPressed: root.highlighted = Math.min(root.highlighted + 1, root.hits.length - 1)
                Keys.onUpPressed: root.highlighted = Math.max(root.highlighted - 1, 0)
                Keys.onReturnPressed: root.activate(root.highlighted)
                Keys.onEnterPressed: root.activate(root.highlighted)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: qsTr("buscar faixa, álbum, artista, episódio…")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeM
                    color: Theme.mOutline
                }
            }

            Text {
                text: root.hits.length + qsTr(" resultados")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOutline
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.borderS
            color: Theme.mOutline
        }

        ListView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Theme.marginS
            clip: true
            model: root.hits
            currentIndex: root.highlighted
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: hitRow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 46
                radius: Theme.radiusS
                color: root.highlighted === hitRow.index ? Theme.mSurface : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginM
                    anchors.rightMargin: Theme.marginM
                    spacing: Theme.marginM

                    Text {
                        text: root.glyphFor(hitRow.modelData.kind)
                        font.family: Icons.fontFamily
                        font.pointSize: Theme.fontSizeL
                        color: Theme.mOnSurfaceVariant
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: hitRow.modelData.title
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeM
                            color: Theme.mOnSurface
                        }
                        Text {
                            Layout.fillWidth: true
                            text: hitRow.modelData.subtitle
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeS
                            color: Theme.mOnSurfaceVariant
                        }
                    }

                    Text {
                        text: root.labelFor(hitRow.modelData.kind)
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeXS
                        color: Theme.mOutline
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.highlighted = hitRow.index
                    onClicked: root.activate(hitRow.index)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.borderS
            color: Theme.mOutline
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.marginM
            spacing: Theme.marginL

            Text {
                text: qsTr("↑↓ navegar   ↵ tocar   esc fechar")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOutline
            }
            Item { Layout.fillWidth: true }
        }
    }
}
```

- [x] Registrar `src/SearchOverlay.qml` em `QML_FILES` no `CMakeLists.txt`.
- [x] verificação mecânica da task: `cmake --build build` → exit 0 e
      `grep -c 'searchGrouped' src/SearchOverlay.qml` → `1`
- [x] commit:

```bash
git add src/SearchOverlay.qml CMakeLists.txt
git commit -m "feat(ui): search overlay across the whole library"
```

### Task 4: Ligar o overlay à lupa e ao teclado

- [x] Em `src/Main.qml`, instanciar o overlay como filho do `Window` (fora do `RowLayout`):

```qml
    SearchOverlay {
        id: searchOverlay
        onTrackChosen: function (path) {
            AudioEngine.loadPlaylist([path], 0)
            AudioEngine.play()
        }
        onEpisodeChosen: function (episodeId) { PodcastLibrary.playEpisode(episodeId) }
    }

    Shortcut {
        sequences: ["Ctrl+K", "Ctrl+F"]
        onActivated: searchOverlay.open()
    }
```

- [x] Em `showPane(name)`, substituir o `console.log` deixado pela fatia `moldura-capa` pela
      chamada real:

```qml
        if (name === "search") {
            searchOverlay.open()
            return
        }
```

- [x] verificação mecânica da task:
      `test "$(QT_QPA_PLATFORM=offscreen timeout 8 ./build/melodarium 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError')" -eq 0` → exit 0
      e `test "$(grep -c 'busca ainda não implementada' src/Main.qml)" -eq 0` → exit 0
- [x] commit:

```bash
git add src/Main.qml
git commit -m "feat(ui): open search from the rail and from Ctrl+K"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `test "$(QT_QPA_PLATFORM=offscreen timeout 8 ./build/melodarium 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError')" -eq 0` → exit 0
- `grep -q "searchGrouped" src/librarybrowser.h` → exit 0
- `grep -q "Ctrl+K" src/Main.qml` → exit 0
- `test "$(grep -c 'busca ainda não implementada' src/Main.qml)" -eq 0` → exit 0

## Fora de escopo

- Navegar para álbum/artista ao escolher esses resultados: por ora eles aparecem e não abrem
  nada (o `activate()` ignora). Ligar isso exige decidir o que "abrir um álbum" faz no miolo,
  e essa decisão não está no desenho aprovado.
- Histórico de buscas recentes.
- Busca dentro do texto de tags — as tags já têm eixo próprio na barra de filtros.

## Divergências entre o plano e o desenho (2026-08-27, execução)

- **Resultados agrupados com cabeçalho.** O plano listava tudo corrido com um rótulo de tipo
  em cada linha; `design/Busca.dc.html` mostra grupos ("FAIXAS", "ÁLBUNS", "ARTISTAS",
  "EPISÓDIOS") com cabeçalho pequeno em caixa alta. O `searchGrouped` já devolvia os tipos em
  ordem, então o QML só intercala os cabeçalhos.
- **O painel não é centralizado.** O desenho o põe a 74 px do topo, com a tela escurecida
  (62 %) atrás — foi assim que ficou.
- **Álbum e artista abrem.** O plano os deixava explicitamente sem ação. Como a fatia
  `biblioteca-densa` acabou trazendo a lista de grupos para o pane, abrir um álbum passou a
  ter um destino óbvio: o overlay emite `albumChosen`/`artistChosen` com o título junto, e a
  biblioteca abre aquele grupo. Sem isso, dois dos quatro tipos de resultado seriam mortos.
- **`property bool opened` foi retirada.** No Qt 6.10 o `Popup` já tem uma propriedade FINAL
  com esse nome; redeclarar fazia o tipo inteiro não carregar, e o único sinal disso era uma
  linha `Cannot override FINAL property` no log do disk cache. O `tools/check-layout.sh`
  agora falha nessas mensagens, e o modo `--measure` abre o overlay de propósito — conteúdo
  de `Popup` só é construído na primeira abertura.
- **"⇧↵ pôr na fila" ficou de fora do rodapé.** O desenho mostra o atalho, mas não existe
  fila nesta direção (o `AudioEngine` não tem enfileirar) e um atalho que não faz nada é pior
  do que a ausência dele.
- **Subtítulos e plural.** Os subtítulos seguem o desenho (artista · álbum · duração para
  faixa; artista · ano · faixas para álbum; contagens para artista; programa · data · minutos
  para episódio), e contam em português: "1 álbum", não "1 álbuns".
