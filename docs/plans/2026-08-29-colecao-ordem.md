---
slug: colecao-ordem
feature: colecao-playlist
status: aprovado
depende-de: [colecao-cartao]
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: colecao-ordem

**Goal:** Arrastar uma faixa para outro lugar dentro da coleção aberta, e a ordem ficar
gravada — a última coisa que separa a coleção de uma playlist de verdade.
**Arquitetura:** O motor já faz tudo: `collection_tracks.position` existe, a consulta da
coleção já ordena por ela (`clauseForCollection`), e `moveTrackInCollection` grava. Falta só
o gesto. Cada linha da coleção aberta ganha uma alça (`drag.target`), e ao soltar o QML
chama `moveTrackInCollection` e recarrega o modelo — o banco é a fonte da ordem, nunca o
índice visual.
**Constraints globais:** o arrastar existe SÓ dentro de uma coleção aberta (`root.openId > 0`).
Na biblioteca a ordem é da consulta, não do usuário, e uma alça lá prometeria o que o banco
não guarda.

**Por que `depende-de: colecao-cartao`:** mesmo arquivo (`src/CollectionsPane.qml`), e esta
fatia mexe no delegate das FAIXAS enquanto a anterior mexe no das COLEÇÕES — rodar as duas em
paralelo conflita no mesmo arquivo, não na API.

## Arquivos

- Modificar: `src/CollectionsPane.qml` · `src/TrackRow.qml` · `src/Main.qml`
- Criar: nenhum
- Testar: `tests/tst_collections.cpp` (o motor, já existente) + `docs/telas/12-colecao-ordem.png`

## Interfaces

- Consome: `CollectionManager.moveTrackInCollection(collectionId: int, trackId: int, newIndex: int) -> bool`
  — já existente, `newIndex` é a posição de destino contando de 0.
- Consome: `signal trackRemoved(int trackId)` de `CollectionsPane` — o `Main.qml` já o liga a
  um recarregamento do modelo da coleção; esta fatia reusa esse mesmo caminho de recarga.
- Produz: `property bool draggable` em `src/TrackRow.qml` (default `false`) — quando `true`, a
  linha mostra a alça de arrastar à esquerda do número. Nenhuma outra fatia deste lote a usa.
- Produz: `signal trackMoved(int trackId, int newIndex)` em `CollectionsPane.qml`, consumido
  só pelo `Main.qml`.

## Tasks

### Task 1: A alça na linha, só quando a linha pode ser arrastada

- [x] Em `src/TrackRow.qml`, declarar a propriedade junto das outras, logo depois de
      `property bool alternate: false`:

```qml
    // Arrastar só faz sentido onde a ordem é do usuário: dentro de uma coleção. Na biblioteca
    // a ordem vem da consulta, e uma alça lá prometeria uma gravação que não existe.
    property bool draggable: false
```

- [x] No mesmo arquivo, dentro do `RowLayout`, ANTES do `Item` que contém o número da faixa,
      inserir a alça:

```qml
            // Seis pontos: o desenho universal de "isto se arrasta". Some sem hover para não
            // competir com o número na lista em repouso.
            Text {
                Layout.preferredWidth: root.draggable ? Math.round(12 * Theme.uiScale) : 0
                visible: root.draggable
                opacity: mouse.containsMouse ? 0.9 : 0.25
                text: "⠿"
                font.pixelSize: Theme.fontSizeM
                color: Theme.cMuted

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }
            }
```

- [x] verificação mecânica da task:
      `grep -c "property bool draggable" src/TrackRow.qml` → `1`
- [x] commit:

```bash
git add src/TrackRow.qml
git commit -m "feat(collections): track row grows a drag handle, off by default"
```

### Task 2: Arrastar e soltar dentro da coleção aberta

- [x] Em `src/CollectionsPane.qml`, declarar o sinal junto dos outros:

```qml
    signal trackMoved(int trackId, int newIndex)
```

- [x] No `delegate: TrackRow { id: faixa … }` da `ListView` `tracks`, acrescentar as
      propriedades e o corpo de arrasto (o `TrackRow` já é um `Item`, então ele mesmo é o alvo):

```qml
                draggable: true

                // A linha arrastada sobe para cima das outras e segue o dedo; o índice de
                // destino sai da altura da própria linha, que é fixa.
                z: dragArea.drag.active ? 2 : 0

                Drag.active: dragArea.drag.active
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                MouseArea {
                    id: dragArea
                    width: Math.round(20 * Theme.uiScale)
                    height: parent.height
                    anchors.left: parent.left
                    cursorShape: Qt.OpenHandCursor
                    drag.target: faixa
                    drag.axis: Drag.YAxis

                    onReleased: {
                        if (!drag.active)
                            return
                        // Quantas linhas o dedo andou, arredondando para a linha mais próxima.
                        const passo = faixa.height + tracks.spacing
                        const deslocou = Math.round(faixa.y / passo) - faixa.index
                        const destino = Math.max(0, Math.min(tracks.count - 1,
                                                             faixa.index + deslocou))
                        // Devolver a linha ao lugar ANTES de recarregar: o modelo vai
                        // repintar, e uma linha com y deslocado herdaria o deslocamento.
                        faixa.y = faixa.index * passo
                        if (destino !== faixa.index)
                            root.trackMoved(faixa.model.trackId, destino)
                    }
                }
```

- [x] verificação mecânica da task: `grep -c "drag.target: faixa" src/CollectionsPane.qml` → `1`
- [x] commit:

```bash
git add src/CollectionsPane.qml
git commit -m "feat(collections): drag a track to a new place inside the collection"
```

### Task 3: Gravar a ordem e recarregar do banco

- [x] Em `src/Main.qml`, no bloco `CollectionsPane { id: collectionsPane … }`, acrescentar:

```qml
                onTrackMoved: function (trackId, newIndex) {
                    if (!CollectionManager.moveTrackInCollection(collectionsPane.openId,
                                                                 trackId, newIndex))
                        return
                    // Recarregar do banco, nunca reordenar a lista na mão: o banco é a fonte
                    // da ordem, e uma lista remendada mentiria até a próxima troca de painel.
                    const q = root.clauseFor("collection", collectionsPane.openId)
                    trackModel.loadFromQuery(q.clause, q.bindings)
                }
```

- [x] verificação mecânica da task:
      `cmake --build build 2>&1 | tail -1 && grep -c "onTrackMoved" src/Main.qml`
      → build `exit 0` e `1`
- [x] commit:

```bash
git add src/Main.qml
git commit -m "feat(collections): persist the dragged order and reload from the database"
```

### Task 4: Provar que a ordem sobrevive, pelo motor e pela foto

- [ ] Acrescentar a `tests/tst_collections.cpp` o teste que fixa a semântica de `newIndex`
      (a tela depende dela: destino contando de 0):

```cpp
    void movingATrackRewritesThePositionsFromZero()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Ordem manual"));
        QVERIFY(id > 0);
        QVERIFY(cm.addTrackToCollection(id, 1));
        QVERIFY(cm.addTrackToCollection(id, 2));
        QVERIFY(cm.addTrackToCollection(id, 3));

        // A terceira vai para o começo: 3, 1, 2.
        QVERIFY(cm.moveTrackInCollection(id, 3, 0));

        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        QSqlQuery q(db);
        QVERIFY(q.exec(QStringLiteral("SELECT track_id FROM collection_tracks "
                                      "WHERE collection_id = %1 ORDER BY position")
                           .arg(id)));
        QList<int> ordem;
        while (q.next())
            ordem.append(q.value(0).toInt());
        QCOMPARE(ordem, (QList<int>{3, 1, 2}));
    }
```

- [ ] Rodar o teste: `ctest --test-dir build -R tst_collections --output-on-failure 2>&1 | tail -3`
      → `100% tests passed`
- [ ] Fotografar a coleção aberta com as alças visíveis:

```bash
DB="${XDG_DATA_HOME:-$HOME/.local/share}/melodarium/melodarium/melodarium.db"
sqlite3 "$DB" "INSERT OR REPLACE INTO collections (id, name, created_at) VALUES (999, 'Gate do lote', 0);
DELETE FROM collection_tracks WHERE collection_id = 999;
INSERT INTO collection_tracks (collection_id, track_id, position, added_at)
SELECT 999, id, ROW_NUMBER() OVER (ORDER BY id), 0 FROM tracks WHERE removed_at IS NULL LIMIT 6;"
QT_QPA_PLATFORM=offscreen ./build/melodarium --measure 1100 --pane collections \
  --open-collection 999 --no-search --shot docs/telas/12-colecao-ordem.png --delay 2200 2>&1 \
  | grep -o "motor=[a-zA-Z]*"
```

→ `motor=ok`

- [ ] verificação mecânica da task: `test -s docs/telas/12-colecao-ordem.png && echo ok` → `ok`
- [ ] commit:

```bash
git add tests/tst_collections.cpp docs/telas/12-colecao-ordem.png
git commit -m "test(collections): manual order survives the move, and the handles are on screen"
```

## Verificação da fatia (E2E)

- `cmake --build build 2>&1 | tail -1` → `exit 0`
- `ctest --test-dir build --output-on-failure 2>&1 | tail -2` → `100% tests passed`
- `bash tools/check-orfaos.sh` → `0 item(ns) sem porta de entrada` E a saída NÃO lista mais
  `moveTrackInCollection` em "reserva declarada":
  `bash tools/check-orfaos.sh 2>&1 | grep -c moveTrackInCollection` → `0`
- `bash tools/check-layout.sh 2>&1 | grep -c FALHA` → `0`
- `bash tools/check-fidelidade.sh 2>&1 | grep -c FALHA` → `0`
- A alça não vazou para a biblioteca: `grep -c "draggable: true" src/LibraryPane.qml` → `0`
- Limpeza da fixture:
  `sqlite3 "${XDG_DATA_HOME:-$HOME/.local/share}/melodarium/melodarium/melodarium.db" "DELETE FROM collections WHERE id = 999"`

## Fora de escopo

- Arrastar faixa de uma coleção para OUTRA: exige alvo de soltura fora da lista e uma decisão
  de produto (move ou copia?) que o spec não tem.
- Reordenar a fila de reprodução (`QueueOverlay`): o motor não tem verbo para isso — foi
  registrado como limite na fatia da fila, em 2026-08-28.
- Arrastar na biblioteca: a ordem lá é da consulta, não do usuário.
