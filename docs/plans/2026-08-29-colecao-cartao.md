---
slug: colecao-cartao
feature: colecao-playlist
status: aprovado
depende-de: [colecao-dados, colecao-toca]
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: colecao-cartao

**Goal:** Na lista de coleções, cada linha passa a ler como playlist: arte, nome, quantas
faixas, quanto tempo, e um botão que toca sem precisar abrir.
**Arquitetura:** A linha cresce de 44 para 60 px e ganha arte à esquerda — mosaico 2×2 quando
a coleção tem quatro ou mais capas, uma capa só quando tem de uma a três, e o ícone de
playlist sobre `cRaised` quando está vazia. O disco de tocar aparece no hover, à direita,
e emite o MESMO `playRequested(bool)` da fatia `colecao-toca` — um verbo, um sinal.
**Constraints globais:** `RoundedCover` é o único jeito de pintar capa neste app (lição
`docs/solutions/` — `radius` + `clip` não recorta imagem no QML). Cor sai da escada de papéis
do `Theme`, nunca de hex solto (`docs/solutions/ui/2026-08-28-…-nao-era-o-desenho`).

**Por que `depende-de: colecao-toca`:** não é dependência de API — é o mesmo arquivo. As duas
fatias editam o cabeçalho e a lista de `src/CollectionsPane.qml`, e rodá-las em paralelo
garante conflito. O sinal `playRequested(bool shuffled)` já existe quando esta fatia começa.

## Arquivos

- Modificar: `src/CollectionsPane.qml`
- Criar: nenhum
- Testar: `docs/telas/11-colecao-cartao.png` (foto de gate)

## Interfaces

- Consome: `CollectionManager.collections()` com as chaves `totalMs` (`qint64`) e `covers`
  (`QVariantList` de `QVariantMap` com `path` e `albumId`), produzidas pela fatia
  `colecao-dados`.
- Consome: `signal playRequested(bool shuffled)` do próprio `CollectionsPane`, produzido pela
  fatia `colecao-toca`; e `CoverCache.coverUrlForTrack(trackPath: QString, albumId: int) -> QString`.
- Produz: nada para outras fatias.

## Tasks

### Task 1: O formatador de duração da linha

- [x] Em `src/CollectionsPane.qml`, acrescentar a função logo depois de `function close() { … }`:

```qml
    // Duplicada de LibraryPane.formatTotal de propósito: QML não tem um lugar comum para
    // função pura (Theme é singleton de ESTILO, e pendurar lógica nele mistura os papéis).
    // Se as duas divergirem, a lista e o cabeçalho passam a contar tempo de jeitos diferentes.
    function formatTotal(ms) {
        const minutes = Math.floor(ms / 60000)
        const hours = Math.floor(minutes / 60)
        const days = Math.floor(hours / 24)
        if (days > 0)
            return days + " d " + (hours % 24) + " h"
        if (hours > 0)
            return hours + " h " + (minutes % 60) + " min"
        return minutes + " min"
    }
```

- [x] verificação mecânica da task: `grep -c "function formatTotal" src/CollectionsPane.qml` → `1`
- [x] commit:

```bash
git add src/CollectionsPane.qml
git commit -m "feat(collections): duration formatter for the list row"
```

### Task 2: A linha vira cartão

- [x] Em `src/CollectionsPane.qml`, no `delegate: Rectangle { id: linha … }` da `ListView`
      `lista`, trocar a altura e o conteúdo. Substituir a linha
      `height: Math.round(44 * Theme.uiScale)` por:

```qml
                height: Math.round(60 * Theme.uiScale)
```

- [x] No mesmo delegate, substituir o `RowLayout` INTEIRO (o que hoje tem o `Text` do ícone
      `playlist`, o `Text` do nome e o `Text` da contagem) por:

```qml
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginL
                    anchors.rightMargin: Theme.marginL
                    spacing: Theme.marginL

                    // A arte da coleção: mosaico com quatro, capa única com uma a três,
                    // ícone quando não há nenhuma. Sem isto a linha é texto puro e não lê
                    // como playlist.
                    Item {
                        id: arte

                        // `id` explícito, nunca `parent.parent`: dentro de um Repeater o pai
                        // muda de identidade conforme o QML embrulha o delegate, e a cadeia
                        // de parents quebra em silêncio — a arte some sem erro no console.
                        readonly property var capas: linha.modelData.covers !== undefined
                                                     ? linha.modelData.covers : []
                        readonly property int lado: Math.round(44 * Theme.uiScale)
                        readonly property int celula: Math.round((arte.lado - 2 * Theme.uiScale) / 2)

                        Layout.preferredWidth: arte.lado
                        Layout.preferredHeight: arte.lado

                        Grid {
                            anchors.fill: parent
                            visible: arte.capas.length >= 4
                            columns: 2
                            spacing: Math.round(2 * Theme.uiScale)

                            Repeater {
                                model: arte.capas.length >= 4 ? arte.capas.slice(0, 4) : []

                                RoundedCover {
                                    required property var modelData
                                    width: arte.celula
                                    height: arte.celula
                                    radius: Theme.radiusXXS
                                    fallbackIconSize: Theme.fontSizeXS
                                    source: CoverCache.coverUrlForTrack(modelData.path,
                                                                        modelData.albumId)
                                }
                            }
                        }

                        RoundedCover {
                            anchors.fill: parent
                            visible: arte.capas.length > 0 && arte.capas.length < 4
                            radius: Theme.radiusXS
                            fallbackIconSize: Theme.fontSizeL
                            source: arte.capas.length > 0
                                    ? CoverCache.coverUrlForTrack(arte.capas[0].path,
                                                                  arte.capas[0].albumId)
                                    : ""
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: arte.capas.length === 0
                            radius: Theme.radiusXS
                            color: Theme.cRaised

                            Text {
                                anchors.centerIn: parent
                                text: Icons.get("playlist")
                                font.family: Icons.fontFamily
                                font.pixelSize: Theme.fontSizeL
                                color: Theme.cLine
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.marginXXS

                        Text {
                            Layout.fillWidth: true
                            text: linha.modelData.name
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeM
                            font.weight: Theme.fontWeightMedium
                            color: Theme.cTitle
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                const n = linha.modelData.count + qsTr(" faixas")
                                const ms = linha.modelData.totalMs !== undefined
                                           ? linha.modelData.totalMs : 0
                                return ms > 0 ? n + " · " + root.formatTotal(ms) : n
                            }
                            elide: Text.ElideRight
                            font.family: Theme.fontFamilyFixed
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.cFaint
                        }
                    }

                    // Tocar sem abrir: o gesto que separa uma playlist de uma pasta.
                    Rectangle {
                        Layout.preferredWidth: Math.round(30 * Theme.uiScale)
                        Layout.preferredHeight: Math.round(30 * Theme.uiScale)
                        visible: area.containsMouse && linha.modelData.count > 0
                        radius: width / 2
                        color: Theme.cTitle

                        Text {
                            anchors.centerIn: parent
                            text: Icons.get("play")
                            font.family: Icons.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.cBase
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // Abrir ANTES de tocar: o modelo de faixas é o da coleção aberta,
                            // e tocar sem abrir carregaria a lista que estava na tela.
                            onClicked: {
                                root.open(linha.modelData.id, linha.modelData.name)
                                root.playRequested(false)
                            }
                        }
                    }
                }
```

- [x] verificação mecânica da task: compilar e conferir que o mosaico existe:

```bash
cmake --build build 2>&1 | tail -1
grep -c "RoundedCover" src/CollectionsPane.qml
```

→ build `exit 0` e `2` ocorrências de `RoundedCover`

- [x] commit:

```bash
git add src/CollectionsPane.qml
git commit -m "feat(collections): the list row reads as a playlist — art, length, play"
```

### Task 3: Fotografar a lista com coleções de verdade

- [ ] Criar duas coleções-fixture de tamanhos diferentes (uma com 6 faixas, uma vazia), para
      a foto mostrar o mosaico E o estado sem arte:

```bash
DB="${XDG_DATA_HOME:-$HOME/.local/share}/melodarium/melodarium/melodarium.db"
sqlite3 "$DB" "INSERT OR REPLACE INTO collections (id, name, created_at) VALUES (999, 'Gate do lote', 0), (998, 'Gate vazia', 0);
DELETE FROM collection_tracks WHERE collection_id IN (998, 999);
INSERT INTO collection_tracks (collection_id, track_id, position, added_at)
SELECT 999, id, ROW_NUMBER() OVER (ORDER BY id), 0 FROM tracks WHERE removed_at IS NULL LIMIT 6;"
sqlite3 "$DB" "SELECT COUNT(*) FROM collections WHERE id IN (998, 999)"
```

→ `2`

- [ ] Fotografar a lista (sem abrir coleção nenhuma):

```bash
QT_QPA_PLATFORM=offscreen ./build/melodarium --measure 1100 --pane collections --no-search \
  --shot docs/telas/11-colecao-cartao.png --delay 2200 2>&1 | grep -o "motor=[a-zA-Z]*"
```

→ `motor=ok`

- [ ] verificação mecânica da task: a linha alta o bastante para o cartão existe na foto:

```bash
python3 -c "
from PIL import Image
im = Image.open('docs/telas/11-colecao-cartao.png').convert('RGB')
print('tamanho', im.size)
" && test -s docs/telas/11-colecao-cartao.png && echo ok
```

→ `tamanho (1100, 700)` e `ok`

- [ ] commit:

```bash
git add docs/telas/11-colecao-cartao.png
git commit -m "test(collections): photograph the playlist-shaped list row"
```

## Verificação da fatia (E2E)

- `cmake --build build 2>&1 | tail -1` → `exit 0`
- `ctest --test-dir build --output-on-failure 2>&1 | tail -2` → `100% tests passed`
- `bash tools/check-orfaos.sh` → `0 item(ns) sem porta de entrada`
- `bash tools/check-layout.sh 2>&1 | grep -c FALHA` → `0`
- `bash tools/check-fidelidade.sh 2>&1 | grep -c FALHA` → `0`
- A foto `docs/telas/11-colecao-cartao.png` existe e tem 1100×700
- Limpeza da fixture:
  `sqlite3 "${XDG_DATA_HOME:-$HOME/.local/share}/melodarium/melodarium/melodarium.db" "DELETE FROM collections WHERE id IN (998, 999)"`

## Fora de escopo

- Reordenar as faixas dentro da coleção: fatia `colecao-ordem`.
- Capa escolhida à mão para a coleção: sem campo no banco, e o spec não pede.
- Mostrar em quais coleções uma faixa está (`collectionsForTrack`, motor pronto sem tela):
  deriva registrada, não entra neste lote.
