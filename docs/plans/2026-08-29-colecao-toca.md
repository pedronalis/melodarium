---
slug: colecao-toca
feature: colecao-playlist
status: aprovado
depende-de: []
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: colecao-toca

**Goal:** A coleção aberta ganha o gesto que faz dela uma playlist — tocar tudo e tocar
embaralhado, num clique.
**Arquitetura:** O `CollectionsPane` não conhece o motor (nenhum pane conhece): ele emite
`playRequested(bool shuffled)` e o `Main.qml` traduz isso em `AudioEngine.loadPlaylist`.
O disco claro de tocar é o mesmo do transporte (`Theme.cTitle`, círculo) — a tela já tem
UM disco claro e ele significa "tocar"; um segundo com outra cara criaria dois vocabulários.
**Constraints globais:** spec §Organização, verbatim: "Coleções por contexto ('Pra codar',
'Madrugada')" — o diferencial nº 1. Nenhuma faixa toca sozinha: o app só toca quando alguém
pede (regra já vigente em `startFromEmpty`).

## Arquivos

- Modificar: `src/CollectionsPane.qml` · `src/Main.qml`
- Criar: nenhum
- Testar: `docs/telas/10-colecao-toca.png` (foto de gate) + linha `MEDIDA` do próprio app

## Interfaces

- Consome: `AudioEngine.loadPlaylist(files: QStringList, startIndex: int)`,
  `AudioEngine.setShuffle(on: bool)`, `AudioEngine.play()` — já existentes.
  `TrackListModel.allPaths() -> QStringList` — já existente, é o modelo que o
  `CollectionsPane` recebe via `property alias model: tracks.model`.
- Produz: `signal playRequested(bool shuffled)` em `CollectionsPane.qml`. O `Main.qml` é o
  único consumidor. A fatia `colecao-cartao` emitirá ESTA MESMA assinatura a partir da linha
  da lista, então o nome e o parâmetro não podem mudar depois.
- Produz: `--play-open-collection` — flag de medição booleana em `Main.qml`, que dispara o
  mesmo caminho do botão depois de `--open-collection <id>`.
- Produz: `fila=<n>` na linha `MEDIDA` impressa por `--measure`, onde `<n>` é
  `AudioEngine.queueCount`. As fatias seguintes leem esta chave para provar que um gesto
  carregou a fila.

## Tasks

### Task 1: O disco de tocar e o embaralhar no cabeçalho da coleção

- [x] Em `src/CollectionsPane.qml`, declarar o sinal junto dos outros (logo abaixo de
      `signal trackRemoved(int trackId)`):

```qml
    // A coleção é uma playlist: playlist se toca inteira. Sem isto o único jeito de ouvir
    // "Pra codar" era abrir e clicar numa faixa, o que é navegar, não tocar.
    signal playRequested(bool shuffled)
```

- [x] No mesmo arquivo, dentro do `RowLayout` do cabeçalho, IMEDIATAMENTE depois do bloco
      `Text` que mostra a contagem (`text: root.openId > 0 ? tracks.count + qsTr(" faixas") …`)
      e ANTES do `Item { Layout.fillWidth: true }`, inserir:

```qml
            // O único disco claro da tela significa "tocar" — é o mesmo do transporte.
            Rectangle {
                Layout.leftMargin: Theme.marginS
                Layout.preferredWidth: Math.round(30 * Theme.uiScale)
                Layout.preferredHeight: Math.round(30 * Theme.uiScale)
                visible: root.openId > 0 && tracks.count > 0
                radius: width / 2
                color: tocarArea.containsMouse ? Theme.cStrong : Theme.cTitle

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.get("play")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.cBase
                }

                MouseArea {
                    id: tocarArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.playRequested(false)
                }
            }

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId > 0 && tracks.count > 0
                icon: "shuffle"
                size: Theme.fontSizeS
                tooltip: qsTr("tocar embaralhado")
                onClicked: root.playRequested(true)
            }
```

- [x] verificação mecânica da task:
      `grep -c "playRequested" src/CollectionsPane.qml` → `3`
- [x] commit:

```bash
git add src/CollectionsPane.qml
git commit -m "feat(collections): play and shuffle the whole collection from its header"
```

### Task 2: A ligação no Main e a flag que prova o gesto

- [ ] Em `src/Main.qml`, no bloco `CollectionsPane { id: collectionsPane … }`, acrescentar o
      handler logo abaixo de `onTrackActivated: function (index) { root.activateTrack(index) }`:

```qml
                onPlayRequested: function (shuffled) {
                    // O modelo é o da coleção aberta: allPaths() já devolve as faixas dela na
                    // ordem manual (clauseForCollection ordena por collection_tracks.position).
                    const paths = trackModel.allPaths()
                    if (paths.length === 0)
                        return
                    AudioEngine.loadPlaylist(paths, 0)
                    // Depois do loadPlaylist, como em startFromEmpty: ligar o modo antes de a
                    // fila existir deixa o botão do painel aceso sobre uma fila vazia.
                    AudioEngine.setShuffle(shuffled)
                    AudioEngine.play()
                }
```

- [ ] Ainda em `src/Main.qml`, declarar a flag de medição junto das outras, imediatamente
      abaixo do bloco de `measureQueueOverlay`:

```qml
    // `--play-open-collection`: dispara o botão de tocar da coleção que `--open-collection`
    // abriu. Sem ele, o gesto só poderia ser provado por alguém clicando.
    readonly property bool measurePlayCollection:
        Qt.application.arguments.indexOf("--play-open-collection") >= 0
```

- [ ] No `Loader` de medição, dentro do primeiro `Timer` e logo depois do bloco
      `if (root.measureCollection > 0) collectionsPane.openById(root.measureCollection)`,
      acrescentar:

```qml
                    if (root.measurePlayCollection)
                        collectionsPane.playRequested(false)
```

- [ ] Na linha `MEDIDA` do segundo `Timer`, acrescentar a fila logo depois de `busca=`:

```qml
                            + " fila=" + AudioEngine.queueCount
```

- [ ] verificação mecânica da task: compilar e ver a chave nova na linha de medida:

```bash
cmake --build build 2>&1 | tail -1
QT_QPA_PLATFORM=offscreen ./build/melodarium --measure 1100 --no-search --play-queue --delay 1800 2>&1 | grep -o "fila=[0-9]*"
```

→ imprime `fila=` com número maior que zero (a biblioteca inteira entrou na fila).

- [ ] commit:

```bash
git add src/Main.qml
git commit -m "feat(collections): wire collection playback and expose queue size to --measure"
```

### Task 3: Provar com uma coleção de verdade e fotografar

- [ ] Criar a coleção-fixture no banco do app (NÃO existe nenhuma coleção hoje — verificado em
      2026-08-29 —, então o gate precisa criar a sua):

```bash
DB="${XDG_DATA_HOME:-$HOME/.local/share}/melodarium/melodarium/melodarium.db"
sqlite3 "$DB" "INSERT OR REPLACE INTO collections (id, name, created_at) VALUES (999, 'Gate do lote', 0);
DELETE FROM collection_tracks WHERE collection_id = 999;
INSERT INTO collection_tracks (collection_id, track_id, position, added_at)
SELECT 999, id, ROW_NUMBER() OVER (ORDER BY id), 0 FROM tracks WHERE removed_at IS NULL LIMIT 6;"
sqlite3 "$DB" "SELECT COUNT(*) FROM collection_tracks WHERE collection_id = 999"
```

→ `6`

- [ ] Rodar o gesto e ler a fila:

```bash
QT_QPA_PLATFORM=offscreen ./build/melodarium --measure 1100 --pane collections \
  --open-collection 999 --play-open-collection --no-search \
  --shot docs/telas/10-colecao-toca.png --delay 2400 2>&1 | grep -o "fila=[0-9]*"
```

→ `fila=6` (as seis faixas da coleção entraram na fila pelo botão, não pela lista)

- [ ] verificação mecânica da task: `test -s docs/telas/10-colecao-toca.png && echo ok` → `ok`
- [ ] commit:

```bash
git add docs/telas/10-colecao-toca.png
git commit -m "test(collections): photograph the collection playing from its own button"
```

## Verificação da fatia (E2E)

- `cmake --build build 2>&1 | tail -1` → `exit 0`
- `ctest --test-dir build --output-on-failure 2>&1 | grep -c "tests passed"` → `1`
- `bash tools/check-orfaos.sh` → termina com `0 item(ns) sem porta de entrada`
- `bash tools/check-layout.sh 2>&1 | grep -c FALHA` → `0`
- `bash tools/check-fidelidade.sh 2>&1 | grep -c FALHA` → `0`
- Gesto: o comando da Task 3 imprime `fila=6`
- Limpeza da fixture:
  `sqlite3 "${XDG_DATA_HOME:-$HOME/.local/share}/melodarium/melodarium/melodarium.db" "DELETE FROM collections WHERE id = 999"`

## Fora de escopo

- Tocar a coleção a partir da LISTA (sem abrir): é a fatia `colecao-cartao`, que reusa o
  mesmo sinal `playRequested(bool)`.
- Mosaico de capas e duração total: fatias `colecao-dados` e `colecao-cartao`.
- Reordenar as faixas: fatia `colecao-ordem`.
- Coleção de podcast: cortada no spec ("Podcast não tem coleção nem tag").
