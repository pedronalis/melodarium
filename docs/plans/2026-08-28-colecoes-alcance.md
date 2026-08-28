---
slug: colecoes-alcance
feature: melodia-religa
status: concluido
depende-de: [colecoes-tela]
decisao-humana: nao
spec: docs/auditoria-completude.md (achados 16,17,22,23) · design/Main.dc.html:78-88
---

# Plano: colecoes-alcance

**Goal:** Tirar da coleção o atrito que faz sistema de organização ser abandonado em três
semanas. Depois desta fatia: um álbum inteiro entra numa coleção com **um** clique (hoje
custa doze); a busca encontra coleções pelo nome; e uma faixa sai da coleção pela própria
linha.

**Arquitetura:** Três consertos que compartilham a mesma fronteira C++↔QML, em tasks
separadas por lado:

1. **Lote.** `CollectionManager` ganha `addTracksToCollection(int, const QVariantList&)`,
   que grava **uma transação só**. Doze `INSERT` autocommit em fila são doze fsync; e um
   `addTrackToCollection` chamado num laço de QML emitiria `collectionsChanged` doze vezes,
   o que faria o painel de coleções se recarregar a cada faixa.
2. **Busca.** `searchGrouped` ganha um quinto tipo, `"collection"`. O overlay já desenha
   qualquer tipo que receba — só precisa saber o glifo, o rótulo do grupo e para onde
   levar.
3. **Cabeçalho.** O botão "+ Coleção" e o nome do artista moram na mesma linha do desenho
   (`design/Main.dc.html:78-88`), então saem juntos.

**Decisão do Pedro (2026-08-28), registrada porque contraria a letra do spec:** o spec diz
que "o gesto manual é um só: jogar uma faixa numa coleção" (§Como fica organizado), e o
desenho aprovado tem o botão de álbum inteiro. O Pedro escolheu o desenho. A leitura que
concilia as duas: o spec queria evitar **campo que ninguém preenche duas vezes igual**, não
evitar atalho para o gesto que ele já aprova.

**Constraints globais:** Qt 6.10.3, C++20, SQLite via QtSql. `kPositionStep = 1000` já
existe em `src/collectionmanager.h` e é a régua da posição manual — o lote continua a
respeitá-la. **PERIGO:** `#` dentro de literal cru (`R"SQL(...)"`) gera arquivo VAZIO no
Qt 6.10.3, sem erro nenhum — use `QStringLiteral` para todo SQL, como o resto do arquivo já
faz.

## Arquivos

- Modificar: `src/collectionmanager.h` · `src/collectionmanager.cpp`
- Modificar: `src/librarybrowser.cpp` · `src/SearchOverlay.qml`
- Modificar: `src/LibraryPane.qml` · `src/CollectionsPane.qml` · `src/Main.qml`
- Modificar: `tests/tst_collections.cpp` · `tests/tst_librarybrowser.cpp`
- Criar: nenhum · Testar: `tests/tst_collections.cpp` · `tests/tst_librarybrowser.cpp`

## Interfaces

- Consome: `CollectionManager::collections()`, `addTrackToCollection(int, int)`,
  `removeTrackFromCollection(int, int)`, `kPositionStep` (existentes).
- Consome: `CollectionsPane.trackRemoved(int trackId)` e `CollectionsPane.openId`
  (produzidos pela fatia `colecoes-tela`).
- Consome: `TrackListModel::allPaths() -> QStringList` e
  `trackAt(int row) -> QVariantMap` com a chave `"trackId"` (existentes).
- Produz:
  - `CollectionManager::addTracksToCollection(int collectionId, const QVariantList &trackIds) -> int`
    — `Q_INVOKABLE`. Grava todos numa transação; devolve **quantos foram efetivamente
    inseridos** (faixa já presente na coleção não conta e não é erro). Emite
    `collectionsChanged()` **uma vez**, e só se inseriu ao menos uma. Consumido por
    `src/LibraryPane.qml` via `src/Main.qml`.
  - `LibraryBrowser::searchGrouped` passa a devolver também linhas com
    `kind == "collection"`, no formato já existente
    `{kind, id, title, subtitle, path}` — `subtitle` = `"N faixas"`, `path` = `""`.
    Consumido por `src/SearchOverlay.qml`.
  - `SearchOverlay.collectionChosen(int collectionId, string title)` — sinal novo.
    Consumido por `src/Main.qml`.
  - `TrackListModel::allTrackIds() -> QVariantList` — `Q_INVOKABLE`. Os ids das linhas
    carregadas, na ordem da lista. Consumido por `src/LibraryPane.qml`.
  - `LibraryPane.collectAllRequested()` — sinal novo, emitido pelo botão "+ Coleção" do
    cabeçalho. Consumido por `src/Main.qml`.

## Tasks

### Task 1: Uma transação para o álbum inteiro

- [x] Escrever o teste que falha, em `tests/tst_collections.cpp`, dentro de
      `private slots:`:

```cpp
    // Doze faixas numa coleção não podem custar doze transações nem doze sinais: o painel
    // de coleções escuta collectionsChanged e se recarregaria a cada faixa.
    void addTracksInBulkInsertsOnceAndSignalsOnce()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Pra codar"));
        QVERIFY(id > 0);

        QSignalSpy spy(&cm, &CollectionManager::collectionsChanged);
        const int inseridos = cm.addTracksToCollection(id, QVariantList{1, 2});
        QCOMPARE(inseridos, 2);
        QCOMPARE(spy.count(), 1);

        const QVariantList cols = cm.collections();
        QCOMPARE(cols.size(), 1);
        QCOMPARE(cols.first().toMap().value(QStringLiteral("count")).toInt(), 2);
    }

    // Repetir o mesmo álbum não pode duplicar nem explodir: a chave primária já barra, e o
    // usuário tem de ver "0 novas" em vez de um erro.
    void addTracksInBulkIsIdempotentAndKeepsOrder()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Madrugada"));
        QCOMPARE(cm.addTracksToCollection(id, QVariantList{1, 2}), 2);

        QSignalSpy spy(&cm, &CollectionManager::collectionsChanged);
        QCOMPARE(cm.addTracksToCollection(id, QVariantList{1, 2}), 0);
        QCOMPARE(spy.count(), 0);

        QCOMPARE(cm.collections().first().toMap().value(QStringLiteral("count")).toInt(), 2);
    }
```

- [x] Rodar e confirmar que falha pelo motivo certo:
      `cmake --build build --target tst_collections` → erro de compilação
      `no member named 'addTracksToCollection'`
- [x] Declarar em `src/collectionmanager.h`, logo depois de
      `Q_INVOKABLE bool addTrackToCollection(int collectionId, int trackId);`:

```cpp
    // Um álbum de doze faixas custava doze idas ao menu. Uma transação, um sinal; devolve
    // quantas ENTRARAM (as que já estavam não contam e não são erro).
    Q_INVOKABLE int addTracksToCollection(int collectionId, const QVariantList &trackIds);
```

- [x] Implementar em `src/collectionmanager.cpp`, depois de
      `bool CollectionManager::addTrackToCollection(...)`:

```cpp
int CollectionManager::addTracksToCollection(int collectionId, const QVariantList &trackIds)
{
    if (collectionId <= 0 || trackIds.isEmpty())
        return 0;

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));

    QSqlQuery posQ(db);
    posQ.prepare(QStringLiteral(
        "SELECT IFNULL(MAX(position), 0) FROM collection_tracks WHERE collection_id = ?"));
    posQ.addBindValue(collectionId);
    int position = (posQ.exec() && posQ.next()) ? posQ.value(0).toInt() : 0;

    // Uma transação só: doze INSERT em autocommit são doze fsync, e uma falha no meio
    // deixaria meia coleção gravada.
    db.transaction();

    QSqlQuery ins(db);
    ins.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO collection_tracks (collection_id, track_id, position, added_at) "
        "VALUES (?, ?, ?, CAST(strftime('%s','now') AS INTEGER))"));

    int inseridos = 0;
    for (const QVariant &raw : trackIds) {
        const int trackId = raw.toInt();
        if (trackId <= 0)
            continue;
        position += kPositionStep;
        ins.bindValue(0, collectionId);
        ins.bindValue(1, trackId);
        ins.bindValue(2, position);
        if (ins.exec() && ins.numRowsAffected() > 0)
            ++inseridos;
        else
            position -= kPositionStep; // não gastar a faixa de posição com quem não entrou
    }

    if (!db.commit()) {
        db.rollback();
        return 0;
    }

    if (inseridos > 0)
        emit collectionsChanged();
    return inseridos;
}
```

- [x] verificação mecânica da task:
      `quiet-run ctest --test-dir build -R tst_collections --output-on-failure`
      → `100% tests passed`
- [x] commit:

```bash
git add src/collectionmanager.h src/collectionmanager.cpp tests/tst_collections.cpp docs/plans/2026-08-28-colecoes-alcance.md
git commit -m "feat(collections): add a whole list in one transaction and one signal"
```

### Task 2: A busca encontra coleções

- [x] Escrever o teste que falha, em `tests/tst_librarybrowser.cpp`, dentro de
      `private slots:`:

```cpp
    // Uma coleção que não aparece na busca é uma coleção que só existe para quem lembra
    // onde ela está.
    void searchAlsoFindsCollections()
    {
        exec(QStringLiteral(
            "INSERT INTO collections (id, name, created_at) VALUES (7, 'Pra codar', 1000)"));
        exec(QStringLiteral(
            "INSERT INTO collection_tracks (collection_id, track_id, position, added_at) "
            "VALUES (7, 1, 1000, 1000)"));

        LibraryBrowser browser;
        const QVariantList hits = browser.searchGrouped(QStringLiteral("codar"), 4);

        int achadas = 0;
        for (const QVariant &raw : hits) {
            const QVariantMap row = raw.toMap();
            if (row.value(QStringLiteral("kind")).toString() != QLatin1String("collection"))
                continue;
            ++achadas;
            QCOMPARE(row.value(QStringLiteral("id")).toInt(), 7);
            QCOMPARE(row.value(QStringLiteral("title")).toString(), QStringLiteral("Pra codar"));
            QVERIFY(row.value(QStringLiteral("subtitle")).toString().contains(QStringLiteral("1")));
        }
        QCOMPARE(achadas, 1);
    }
```

- [x] Rodar e confirmar que falha pelo motivo certo:
      `quiet-run ctest --test-dir build -R tst_librarybrowser --output-on-failure` →
      `Compared values are not the same … Actual (achadas): 0`
- [x] Em `src/librarybrowser.cpp`, dentro de `LibraryBrowser::searchGrouped`, inserir este
      bloco **depois** da consulta de artistas (`arq`) e **antes** da de episódios (`eq`),
      para que a ordem dos grupos na tela fique faixas → álbuns → artistas → coleções →
      episódios:

```cpp
    QSqlQuery cq(db);
    cq.prepare(QStringLiteral(
        "SELECT c.id, c.name, COUNT(ct.track_id) "
        "FROM collections c "
        "LEFT JOIN collection_tracks ct ON ct.collection_id = c.id "
        "WHERE c.name LIKE ? GROUP BY c.id ORDER BY c.name COLLATE NOCASE LIMIT ?"));
    cq.addBindValue(like);
    cq.addBindValue(limitPerKind);
    if (cq.exec()) {
        while (cq.next()) {
            append(QStringLiteral("collection"), cq.value(0).toInt(), cq.value(1).toString(),
                   plural(cq.value(2).toInt(), QStringLiteral("faixa"),
                          QStringLiteral("faixas")),
                   QString());
        }
    }
```

- [x] verificação mecânica da task:
      `quiet-run ctest --test-dir build -R tst_librarybrowser --output-on-failure`
      → `100% tests passed`
- [x] commit:

```bash
git add src/librarybrowser.cpp tests/tst_librarybrowser.cpp docs/plans/2026-08-28-colecoes-alcance.md
git commit -m "feat(search): collections are a fifth kind of result"
```

### Task 3: O overlay sabe abrir uma coleção

- [x] Em `src/SearchOverlay.qml`, declarar o sinal junto dos outros quatro (linhas 23-26):

```qml
    signal collectionChosen(int collectionId, string title)
```

- [x] No mesmo arquivo, na função `glyphFor(kind)`, acrescentar o caso antes do `return`
      final:

```qml
        if (kind === "collection")
            return Icons.get("playlist")
```

- [x] Na função `groupLabelFor(kind)`, acrescentar o caso antes do `return` final:

```qml
        if (kind === "collection")
            return qsTr("Coleções")
```

- [x] Na função `activate(index)`, acrescentar o despacho junto dos outros tipos:

```qml
        if (hit.kind === "collection") {
            root.collectionChosen(hit.id, hit.title)
            root.close()
            return
        }
```

- [x] Em `src/Main.qml`, no `SearchOverlay { id: searchOverlay … }`, acrescentar o handler:

```qml
        onCollectionChosen: function (collectionId, title) {
            root.section = "collections"
            collectionsPane.open(collectionId, title)
        }
```

- [x] verificação mecânica da task:
      `grep -c 'collection' src/SearchOverlay.qml` → `4`
- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/SearchOverlay.qml src/Main.qml docs/plans/2026-08-28-colecoes-alcance.md
git commit -m "feat(search): opening a collection hit opens the collection"
```

### Task 4: O modelo devolve os ids que a lista tem na tela

- [x] Declarar em `src/tracklistmodel.h`, logo depois de
      `Q_INVOKABLE QStringList allPaths() const;`:

```cpp
    // O botão "+ Coleção" do cabeçalho joga a lista que está na tela numa coleção — e o que
    // a coleção guarda é id, não caminho.
    Q_INVOKABLE QVariantList allTrackIds() const;
```

- [x] Implementar em `src/tracklistmodel.cpp`, depois de `QStringList TrackListModel::allPaths`:

```cpp
QVariantList TrackListModel::allTrackIds() const
{
    QVariantList out;
    out.reserve(m_rows.size());
    for (const TrackRow &r : m_rows)
        out.append(r.id);
    return out;
}
```

- [x] verificação mecânica da task:
      `quiet-run cmake --build build` → exit 0
- [x] verificação mecânica da task:
      `grep -c 'allTrackIds' src/tracklistmodel.h src/tracklistmodel.cpp` →
      `src/tracklistmodel.h:1`, `src/tracklistmodel.cpp:1`
- [x] commit:

```bash
git add src/tracklistmodel.h src/tracklistmodel.cpp docs/plans/2026-08-28-colecoes-alcance.md
git commit -m "feat(library): expose the ids of the rows currently listed"
```

### Task 5: O cabeçalho ganha o artista e o botão de álbum inteiro

- [x] Em `src/LibraryPane.qml`, declarar as duas novidades junto das outras propriedades do
      topo, depois de `property string groupTitle: ""`:

```qml
    // O desenho põe "Ólafur Arnalds · 8 faixas · 35 min" no cabeçalho: sem o artista, dois
    // álbuns homônimos de artistas diferentes ficam indistinguíveis (design/Main.dc.html:82).
    property string groupSubtitle: ""
```

- [x] No mesmo arquivo, declarar o sinal junto dos outros seis:

```qml
    signal collectAllRequested
```

- [x] Substituir o `RowLayout` do cabeçalho (o que começa com o `Text` do `groupTitle`)
      acrescentando o subtítulo e o botão. O botão vem **antes** do de reler a pasta:

```qml
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.groupTitle !== "" ? root.groupTitle : qsTr("Biblioteca")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                visible: root.groupSubtitle !== "" && !root.showingGroups
                text: root.groupSubtitle
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.showingGroups
                      ? root.groups.length + qsTr(" itens")
                      : root.withThousands(list.count) + qsTr(" faixas")
                        + (list.model !== null && list.model.totalDurationMs > 0
                           ? " · " + root.formatTotal(list.model.totalDurationMs) : "")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeS
                color: Theme.mOutline
            }

            Item { Layout.fillWidth: true }

            Text {
                Layout.alignment: Qt.AlignBaseline
                visible: root.scanning
                text: qsTr("varrendo…")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }

            // Doze faixas numa coleção custavam doze idas ao menu da linha. Este botão joga
            // a lista inteira que está na tela de uma vez (design/Main.dc.html:84-87).
            Rectangle {
                Layout.preferredHeight: Math.round(24 * Theme.uiScale)
                Layout.preferredWidth: rotuloColecao.implicitWidth + Theme.marginM * 2
                visible: !root.showingGroups && list.count > 0
                radius: Theme.iRadiusS
                color: coletarArea.containsMouse ? Theme.mSurfaceVariant : "transparent"
                border.width: Theme.borderS
                border.color: Theme.mSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                Row {
                    id: rotuloColecao
                    anchors.centerIn: parent
                    spacing: Theme.marginS

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.get("plus")
                        font.family: Icons.fontFamily
                        font.pointSize: Theme.fontSizeXS
                        color: Theme.mOnSurfaceVariant
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Coleção")
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeS
                        color: Theme.mOnSurfaceVariant
                    }
                }

                MouseArea {
                    id: coletarArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.collectAllRequested()
                }
            }

            // Reler a pasta é raro, então o botão é discreto: só o ícone, sem rótulo.
            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                icon: "history"
                size: Theme.fontSizeS
                opacity: 0.55
                tooltip: qsTr("reler a pasta")
                enabled: Database.libraryPath !== "" && !root.scanning
                onClicked: Database.startScan()
            }
        }
```

- [x] verificação mecânica da task:
      `grep -c 'collectAllRequested\|groupSubtitle' src/LibraryPane.qml` → `4`
- [x] verificação mecânica da task:
      `bash tools/check-layout.sh` → 11 medidas ok (o cabeçalho cresceu: se a linha de
      chips estourar a largura mínima, o gate falha aqui e não na tela do Pedro)
- [x] commit:

```bash
git add src/LibraryPane.qml docs/plans/2026-08-28-colecoes-alcance.md
git commit -m "feat(ui): album header shows the artist and collects the whole list"
```

### Task 6: O menu de coleção atende a lista inteira

- [x] Em `src/Main.qml`, o menu de coleções precisa saber se está atendendo uma faixa ou a
      lista inteira. Substituir a função `collectTrack` e acrescentar a irmã:

```qml
    function collectTrack(trackId) {
        root.selectedTrackId = trackId
        collectMenu.trackId = trackId
        collectMenu.emLote = false
        collectMenu.options = CollectionManager.collections()
        collectMenu.popup()
    }

    // O mesmo menu, servindo a lista inteira que está na tela.
    function collectAll() {
        collectMenu.trackId = 0
        collectMenu.emLote = true
        collectMenu.options = CollectionManager.collections()
        collectMenu.popup()
    }
```

- [x] No mesmo arquivo, no `Menu { id: collectMenu … }`, acrescentar a propriedade e trocar
      o que o item do menu faz:

```qml
    Menu {
        id: collectMenu

        property int trackId: 0
        property var options: []
        // Com emLote, o alvo não é uma faixa: é tudo que a lista está mostrando.
        property bool emLote: false

        Instantiator {
            model: collectMenu.options
            delegate: MenuItem {
                required property var modelData
                text: modelData.name
                onTriggered: {
                    if (collectMenu.emLote)
                        CollectionManager.addTracksToCollection(modelData.id,
                                                                trackModel.allTrackIds())
                    else
                        CollectionManager.addTrackToCollection(modelData.id,
                                                                collectMenu.trackId)
                }
            }
            onObjectAdded: function (index, object) { collectMenu.insertItem(index, object) }
            onObjectRemoved: function (index, object) { collectMenu.removeItem(object) }
        }

        MenuItem {
            text: qsTr("Nova coleção…")
            onTriggered: {
                newCollectionForTrack.pendingTrackId = collectMenu.trackId
                newCollectionForTrack.pendingLote = collectMenu.emLote
                newCollectionForTrack.renameId = 0
                newCollectionForTrack.initialText = ""
                newCollectionForTrack.open()
            }
        }
    }
```

- [x] No mesmo arquivo, o diálogo de criação precisa honrar o lote:

```qml
    NewCollectionDialog {
        id: newCollectionForTrack

        property int pendingTrackId: 0
        property bool pendingLote: false

        onCreated: function (id, name) {
            if (newCollectionForTrack.pendingLote)
                CollectionManager.addTracksToCollection(id, trackModel.allTrackIds())
            else if (newCollectionForTrack.pendingTrackId > 0)
                CollectionManager.addTrackToCollection(id, newCollectionForTrack.pendingTrackId)
            newCollectionForTrack.pendingTrackId = 0
            newCollectionForTrack.pendingLote = false
        }
    }
```

- [x] No `LibraryPane { id: libraryPane … }` do mesmo arquivo, ligar o sinal novo e o
      subtítulo (o nome do artista do álbum aberto):

```qml
                onCollectAllRequested: root.collectAll()
                groupSubtitle: root.groupSubtitle
```

- [x] Declarar a propriedade que alimenta o subtítulo, junto das outras do topo de
      `Main.qml`, depois de `property string groupsTitle: ""`:

```qml
    // O artista do álbum aberto, para o cabeçalho. Vazio em qualquer outra lista.
    property string groupSubtitle: ""
```

- [x] O artista já vem junto do grupo: `LibraryBrowser.albums()` devolve
      `{id, name, count, subtitle}`, com `subtitle` = nome do artista do álbum (verificado
      em `src/librarybrowser.cpp`, função `runLookup`). Basta carregá-lo junto do nome em
      vez de consultar de novo. Substituir `openGroup` inteiro:

```qml
    // Opening a group keeps its name on screen: the list is no longer "Biblioteca".
    function openGroup(section, id) {
        let name = ""
        let subtitle = ""
        for (let i = 0; i < root.groups.length; ++i) {
            if (root.groups[i].id === id) {
                name = root.groups[i].name
                // O artista já veio na consulta que montou a lista de grupos: buscá-lo de
                // novo seria uma segunda varredura da tabela de álbuns por clique.
                subtitle = root.groups[i].subtitle !== undefined
                           ? root.groups[i].subtitle : ""
                break
            }
        }
        root.groupSubtitle = section === "albums" ? subtitle : ""
        root.openNamedGroup(section, id, name)
    }
```

- [x] `openNamedGroup` é o outro caminho de entrada (a busca) e não tem o subtítulo em mãos.
      Ele **não** pode limpar o que `openGroup` acabou de escrever, então a limpeza é
      condicional. Acrescentar como primeira linha do corpo de `openNamedGroup`:

```qml
        // Chegando pela busca não há grupo carregado de onde tirar o artista; chegando pela
        // lista de grupos, openGroup já escreveu o subtítulo uma linha antes.
        if (section !== "albums")
            root.groupSubtitle = ""
```

- [x] verificação mecânica da task:
      `grep -c 'addTracksToCollection' src/Main.qml` → `2`
- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/Main.qml docs/plans/2026-08-28-colecoes-alcance.md
git commit -m "feat(ui): one click puts the whole open list into a collection"
```

### Task 7: Tirar uma faixa da coleção pela própria linha

- [x] Em `src/CollectionsPane.qml`, no `TrackRow` do `ListView { id: tracks … }`, ligar o
      gesto de sair da coleção ao botão que a biblioteca usa para entrar numa. Substituir as
      duas linhas `showCollectButton: false` e `onLikeToggled:` por:

```qml
                // Dentro de uma coleção o gesto útil é o inverso: o mesmo botão da linha
                // tira a faixa daqui em vez de pô-la em outro lugar.
                showCollectButton: true
                collectGlyph: "close"

                onActivated: root.trackActivated(faixa.index)
                onLikeToggled: LibraryBrowser.toggleLike(faixa.model.trackId)
                onCollectRequested: {
                    CollectionManager.removeTrackFromCollection(root.openId,
                                                                faixa.model.trackId)
                    root.trackRemoved(faixa.model.trackId)
                }
```

- [x] Em `src/TrackRow.qml`, o botão da linha precisa poder trocar de glifo — declarar a
      propriedade junto das outras, depois de `property bool showCollectButton: false`:

```qml
    // "plus" na biblioteca (pôr numa coleção), "close" dentro de uma coleção (tirar desta).
    property string collectGlyph: "plus"
```

- [x] No mesmo arquivo, o `IconButton` do `showCollectButton` passa a usar a propriedade:

```qml
                icon: root.collectGlyph
```

- [x] Em `src/Main.qml`, no `CollectionsPane { id: collectionsPane … }`, recarregar a lista
      quando uma faixa sai — sem isto a linha continua na tela depois de removida:

```qml
                onTrackRemoved: function (trackId) {
                    const q = root.clauseFor("collection", collectionsPane.openId)
                    trackModel.loadFromQuery(q.clause, q.bindings)
                }
```

- [x] verificação mecânica da task:
      `grep -c 'collectGlyph' src/TrackRow.qml src/CollectionsPane.qml` →
      `src/TrackRow.qml:2`, `src/CollectionsPane.qml:1`
- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/TrackRow.qml src/CollectionsPane.qml src/Main.qml docs/plans/2026-08-28-colecoes-alcance.md
git commit -m "feat(ui): remove a track from a collection from its own row"
```

## Verificação da fatia (E2E)

- `quiet-run cmake --build build` → exit 0
- `quiet-run ctest --test-dir build --output-on-failure` → `100% tests passed` com
  `Total Tests: 9` ou mais
- `bash tools/check-layout.sh` → 11 medidas ok (o cabeçalho cresceu; esta linha é o gate)
- `grep -c 'addTracksToCollection' src/collectionmanager.h` → `1`
- `QT_QPA_PLATFORM=offscreen QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 ./build/melodarium --measure --pane library --search-text "codar" 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError|TypeError|unavailable|Cannot override|Cannot assign'`
  → `0`
- `bash tools/check-orfaos.sh` → não lista mais `removeTrackFromCollection`,
  `collectionsForTrack`, `clauseForSearch`, `bindingsForSearch`

## Fora de escopo

- Reordenar faixas dentro da coleção arrastando (`moveTrackInCollection` continua sem
  chamador; segue listado pelo detector de órfãos de propósito).
- Selecionar um subconjunto de faixas: o botão joga a lista inteira que está na tela. Quem
  quiser metade filtra antes — é o que o eixo de álbum já faz.
- Desfazer o "+ Coleção" em lote. Tirar faixa a faixa pela linha é o caminho, e ele existe a
  partir desta fatia.
- Coleção dentro de coleção, ou coleção automática por regra. Fora do spec.
