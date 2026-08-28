---
slug: clique-responde
feature: melodia-religa
status: aprovado
depende-de: []
decisao-humana: sim
spec: docs/auditoria-completude.md (achados 1,2,3,4,7,8,9) · design/Main.dc.html
---

# Plano: clique-responde

**Goal:** Acabar com o "eu clico e o app ignora". Depois desta fatia, todo controle visível
na tela ou faz o que promete, ou não está mais lá. Resolve por inteiro duas das quatro
queixas do Pedro (o coração que não preenche; a lateral que não navega).

**Arquitetura:** Três consertos independentes que compartilham a mesma causa — algo foi
construído e ficou sem fio:

1. **O coração.** `LibraryBrowser::likedChanged` já é emitido; ninguém traduz isso em
   `dataChanged` na linha. O modelo ganha `applyLiked(int, bool)`, que altera a linha em
   memória e emite `dataChanged` só do `LikedRole` — repintar a lista inteira a cada like
   é o que se está evitando. Mais o glifo sólido `heart-filled`, que **já está embarcado**
   na fonte (verificado em 2026-08-28: U+F67C existe em
   `assets/fonts/noctalia-tabler-icons.ttf`) e nunca foi listado no mapa de ícones.
2. **A lateral vira MODO, não eixo.** Decisão do Pedro em 2026-08-28: a tira de ícones
   escolhe o modo (Biblioteca · Podcast · Buscar; Coleções entra na fatia `colecoes-tela`)
   e a fileira de chips escolhe o eixo dentro da biblioteca. `albums` e `tags` **saem** da
   tira — eles já funcionam nos chips, e ter a mesma palavra nos dois lugares foi
   exatamente o que produziu a queixa. Isso conserta os achados 1, 2 e 3 **removendo**
   código, não adicionando.
3. **A etiqueta e o volume.** `TagEditor.tagChosen` existe e o painel não o repassa (perdido
   no commit `202b7bb`); o volume existia na barra antiga e não migrou no `738acd3`.

**Constraints globais:** Qt 6.10.3, C++20, QML. Todo tamanho novo passa por `Theme.uiScale`
(perigo registrado no handoff: número fixo vira interface microscópica em tela grande).
Nada de `pause()` direto — o transporte usa `togglePause()`. **Aleatório e repetir ficam na
tela** e continuam inertes nesta fatia: decisão do Pedro em 2026-08-28 foi ligá-los de
verdade na fatia `shuffle-repeat`, não removê-los agora.

## Arquivos

- Modificar: `src/tracklistmodel.h` · `src/tracklistmodel.cpp` · `src/LibraryPane.qml`
- Modificar: `src/Icons.qml` · `src/TrackRow.qml` · `src/NowPlayingPanel.qml`
- Modificar: `src/IconRail.qml` · `src/Main.qml`
- Modificar: `tests/tst_tracklistmodel.cpp`
- Criar: nenhum · Testar: `tests/tst_tracklistmodel.cpp`

## Interfaces

- Consome: `LibraryBrowser::likedChanged(int trackId, bool liked)` (sinal existente,
  `src/librarybrowser.h:57`) · `LibraryBrowser::toggleLike(int trackId) -> bool` ·
  `AudioEngine::setVolume(double v)` (clamp 0..100, `src/audioengine.h:40`) ·
  `AudioEngine::volume` (Q_PROPERTY double, READ/WRITE/NOTIFY) ·
  `CollectionManager::clauseForTag(const QString &) -> QString` e
  `bindingsForTag(const QString &) -> QVariantList`.
- Produz:
  - `TrackListModel::applyLiked(int trackId, bool liked)` — `Q_INVOKABLE void`. Procura a
    linha pelo id, atualiza `m_rows[i].liked` e emite
    `dataChanged(index(i), index(i), {LikedRole})`. Não faz nada se o id não estiver na
    lista carregada. Consumido por `src/LibraryPane.qml`.
  - `Icons.get("heart-filled")` — glifo `""`, o coração sólido. Consumido por
    `src/TrackRow.qml` e `src/NowPlayingPanel.qml`.
  - `NowPlayingPanel.tagChosen(string name)` — sinal novo do painel, repassa o
    `tagChosen` do `TagEditor` interno. Consumido por `src/Main.qml`.
  - `IconRail.items` passa a ser exatamente
    `[{key:"library"}, {key:"podcast"}, {key:"search"}]`. A fatia `colecoes-tela` insere
    `{key:"collections"}` como PRIMEIRO item, e a fatia `ajustes` acrescenta
    `{key:"settings"}` no pé.

## Tasks

### Task 1: O modelo aprende a atualizar uma curtida sozinho

- [x] Escrever o teste que falha, em `tests/tst_tracklistmodel.cpp`, dentro de
      `private slots:`, depois de `totalDurationSumsTheLoadedRows()`:

```cpp
    // O coração da lista não reagia ao clique: o banco gravava, o modelo não avisava
    // ninguém, e a linha só mudava quando a lista inteira era recarregada. dataChanged
    // com UM papel é o que evita repintar 1.200 linhas por causa de uma.
    void applyLikedTouchesOnlyTheRowAndTheRole()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        QCOMPARE(model.data(model.index(0), TrackListModel::LikedRole).toBool(), false);

        QSignalSpy spy(&model, &QAbstractItemModel::dataChanged);
        model.applyLiked(1, true);

        QCOMPARE(model.data(model.index(0), TrackListModel::LikedRole).toBool(), true);
        QCOMPARE(spy.count(), 1);
        const QList<QVariant> args = spy.takeFirst();
        QCOMPARE(args.at(0).toModelIndex().row(), 0);
        QCOMPARE(args.at(1).toModelIndex().row(), 0);
        const QList<int> roles = args.at(2).value<QList<int>>();
        QCOMPARE(roles.size(), 1);
        QCOMPARE(roles.first(), int(TrackListModel::LikedRole));
    }

    // Curtir uma faixa que não está na lista aberta (por exemplo, curtida pela busca) não
    // pode emitir sinal nenhum: um índice inválido num dataChanged derruba a ListView.
    void applyLikedIgnoresIdsOutsideTheLoadedList()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        QSignalSpy spy(&model, &QAbstractItemModel::dataChanged);
        model.applyLiked(999, true);
        QCOMPARE(spy.count(), 0);
    }
```

- [x] Rodar e confirmar que falha pelo motivo certo:
      `cmake --build build --target tst_tracklistmodel` → erro de compilação
      `no member named 'applyLiked' in 'TrackListModel'`
- [x] Declarar em `src/tracklistmodel.h`, logo depois de
      `Q_INVOKABLE QVariantMap trackAt(int row) const;`:

```cpp
    // Curtir é um clique numa linha, não um motivo para recarregar a lista: isto altera a
    // linha em memória e avisa a ListView de UM papel de UMA linha.
    Q_INVOKABLE void applyLiked(int trackId, bool liked);
```

- [x] Implementar em `src/tracklistmodel.cpp`, depois de `QVariantMap TrackListModel::trackAt`:

```cpp
void TrackListModel::applyLiked(int trackId, bool liked)
{
    for (int i = 0; i < m_rows.size(); ++i) {
        if (m_rows[i].id != trackId)
            continue;
        if (m_rows[i].liked == liked)
            return;
        m_rows[i].liked = liked;
        emit dataChanged(index(i), index(i), {LikedRole});
        return;
    }
}
```

- [x] verificação mecânica da task:
      `quiet-run ctest --test-dir build -R tst_tracklistmodel --output-on-failure`
      → `100% tests passed`
- [x] commit:

```bash
git add src/tracklistmodel.h src/tracklistmodel.cpp tests/tst_tracklistmodel.cpp docs/plans/2026-08-28-clique-responde.md
git commit -m "feat(library): update one liked row in place instead of reloading the list"
```

### Task 2: A lista escuta e o coração reage na hora

- [x] Em `src/LibraryPane.qml`, substituir o bloco `Connections` que hoje só chama
      `root.reload()` (o que atualiza apenas o contador dos chips):

```qml
    Connections {
        target: LibraryBrowser
        function onLikedChanged(id, liked) {
            root.reload()
            // O contador do chip já se atualizava; a LINHA não. Sem esta chamada o
            // coração só muda quando a lista inteira é recarregada por outro motivo.
            if (list.model !== null)
                list.model.applyLiked(id, liked)
        }
    }
```

- [x] verificação mecânica da task:
      `grep -c 'applyLiked' src/LibraryPane.qml` → `1`
- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/LibraryPane.qml docs/plans/2026-08-28-clique-responde.md
git commit -m "fix(ui): repaint the liked heart the moment the row is toggled"
```

### Task 3: O coração cheio, que já estava embarcado

- [x] Em `src/Icons.qml`, acrescentar a entrada logo depois da linha `"heart": ""…`
      (o glifo sólido existe na fonte em U+F67C — conferido com fontTools em 2026-08-28):

```qml
        "heart-filled": "",
```

- [x] Em `src/TrackRow.qml`, no `Text { id: heart … }`, trocar a linha do `text:` para que
      curtido e não curtido sejam FORMAS diferentes, como no desenho aprovado, e não só
      cores diferentes:

```qml
                    text: root.liked ? Icons.get("heart-filled") : Icons.get("heart")
```

- [x] Em `src/NowPlayingPanel.qml`, o `IconButton` do coração (o que tem
      `accent: root.info.liked === true`) passa a trocar de glifo também:

```qml
            IconButton {
                visible: root.trackId > 0 && !root.episodeMode
                icon: root.info.liked === true ? "heart-filled" : "heart"
                size: Theme.fontSizeXL
                accent: root.info.liked === true
                onClicked: root.likeRequested(root.trackId)
            }
```

- [x] verificação mecânica da task:
      `grep -c 'heart-filled' src/Icons.qml src/TrackRow.qml src/NowPlayingPanel.qml`
      → `src/Icons.qml:1`, `src/TrackRow.qml:1`, `src/NowPlayingPanel.qml:2`
- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/Icons.qml src/TrackRow.qml src/NowPlayingPanel.qml docs/plans/2026-08-28-clique-responde.md
git commit -m "feat(ui): a liked heart is solid, not merely tinted"
```

### Task 4: A tira de ícones vira MODO — Álbuns e Tags saem dela

- [x] Em `src/IconRail.qml`, substituir a lista `items` inteira. Os chips acima da lista
      já entregam Álbuns e Tags e funcionam; repetir as mesmas palavras aqui, sem navegar,
      foi a queixa nº 1 do Pedro:

```qml
    // A tira escolhe o MODO da tela; a fileira de chips do miolo escolhe o EIXO dentro da
    // biblioteca. Álbuns e Tags viviam aqui SEM navegar, repetindo palavras que os chips já
    // entregam — decisão do Pedro em 2026-08-28: saem daqui. A fatia colecoes-tela insere
    // "collections" como PRIMEIRO item; a fatia ajustes acrescenta "settings" no pé.
    readonly property var items: [
        { key: "library", icon: "list",       tip: qsTr("Biblioteca") },
        { key: "podcast", icon: "microphone", tip: qsTr("Podcast") },
        { key: "search",  icon: "search",     tip: qsTr("Buscar") }
    ]
```

- [x] Em `src/Main.qml`, na função `showPane`, tornar explícito que voltar para a
      biblioteca recarrega a lista que estava aberta — hoje o clique em "Biblioteca" não
      faz nada quando já se está nela:

```qml
    // The rail picks the pane. Search is not a pane: it is an overlay over whatever is on
    // screen, so the rail opens it and leaves the pane where it was.
    function showPane(name) {
        if (name === "search") {
            searchOverlay.open()
            return
        }
        // Voltar para a biblioteca releva a lista que estava aberta: sem isto, sair do
        // podcast e voltar mostrava a lista velha, e clicar em "Biblioteca" já estando
        // nela não fazia absolutamente nada.
        if (name === "library" && root.section === "library")
            root.reloadCurrent()
        root.section = name
    }
```

- [x] verificação mecânica da task:
      `grep -cE '"(albums|tags)"' src/IconRail.qml` → `0`
- [x] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [x] commit:

```bash
git add src/IconRail.qml src/Main.qml docs/plans/2026-08-28-clique-responde.md
git commit -m "fix(ui): the rail picks the mode, the chips pick the axis — no more twin menus"
```

### Task 5: Clicar numa etiqueta filtra a biblioteca

- [ ] Em `src/NowPlayingPanel.qml`, declarar o sinal junto dos outros dois, logo depois de
      `signal playRequested(string mode)`:

```qml
    // O TagEditor emite tagChosen desde sempre; o painel nunca repassou, e o clique na
    // etiqueta morria aqui dentro (regressão do commit 202b7bb).
    signal tagChosen(string name)
```

- [ ] No mesmo arquivo, no `TagEditor { id: tagEd … }`, ligar o repasse:

```qml
        TagEditor {
            id: tagEd
            Layout.fillWidth: true
            visible: root.hasTrack && root.trackId > 0 && !root.episodeMode
            trackId: root.trackId
            onTagChosen: function (name) { root.tagChosen(name) }
        }
```

- [ ] Em `src/Main.qml`, no `NowPlayingPanel { id: nowPlaying … }`, acrescentar o handler
      junto dos outros dois:

```qml
            onTagChosen: function (name) { root.showTag(name) }
```

- [ ] Em `src/Main.qml`, `showTag` precisa levar a tela junto: chegar numa etiqueta a
      partir do painel é chegar de fora da lista de grupos, e hoje a função troca o
      conteúdo sem trocar o modo nem acender o chip:

```qml
    // Tags are picked by name, not by id, so they do not go through showSection().
    function showTag(name) {
        root.section = "library"
        root.libraryFilter = "tags"
        root.currentSection = "tags"
        root.currentId = 0
        trackModel.loadFromQuery(CollectionManager.clauseForTag(name),
                                 CollectionManager.bindingsForTag(name))
        root.groupsTitle = name
        root.showingGroups = false
    }
```

- [ ] verificação mecânica da task:
      `grep -c 'onTagChosen' src/NowPlayingPanel.qml src/Main.qml` →
      `src/NowPlayingPanel.qml:1`, `src/Main.qml:1`
- [ ] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/NowPlayingPanel.qml src/Main.qml docs/plans/2026-08-28-clique-responde.md
git commit -m "fix(ui): clicking a tag under the cover filters the library by it"
```

### Task 6: O volume volta para a fileira de controles

- [ ] Em `src/NowPlayingPanel.qml`, declarar o estado do mudo junto das outras propriedades
      do topo, logo depois de `property var episodeInfo: ({})`:

```qml
    // O motor não tem mudo: o botão antigo alternava entre 0 e 100 e perdia o valor que o
    // usuário tinha escolhido. Guardar o volume anterior é o que faz o mudo ser reversível.
    property real volumeAntesDoMudo: 100
    readonly property bool mudo: AudioEngine.volume <= 0
```

- [ ] No mesmo arquivo, dentro do `RowLayout` dos controles (o que tem
      `Layout.alignment: Qt.AlignHCenter` e `visible: root.hasTrack`), acrescentar o
      controle de volume **como último filho**, depois do `Rectangle` do rótulo "30s":

```qml
            // O volume saiu da tela quando a barra de transporte foi aposentada e nunca
            // migrou para cá. Sem ele o único volume do app é o do sistema.
            RowLayout {
                spacing: Theme.marginS

                IconButton {
                    icon: root.mudo ? "volume-off"
                                    : (AudioEngine.volume < 50 ? "volume-low" : "volume")
                    size: Theme.fontSizeL
                    tooltip: root.mudo ? qsTr("com som") : qsTr("mudo")
                    onClicked: {
                        if (root.mudo) {
                            AudioEngine.setVolume(root.volumeAntesDoMudo)
                        } else {
                            root.volumeAntesDoMudo = AudioEngine.volume
                            AudioEngine.setVolume(0)
                        }
                    }
                }

                Rectangle {
                    id: trilhoVolume
                    Layout.preferredWidth: Math.round(72 * Theme.uiScale)
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: 3
                    radius: Theme.radiusXXS
                    color: Theme.mSurfaceVariant

                    Rectangle {
                        width: parent.width * (AudioEngine.volume / 100)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.mOnSurfaceVariant
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.marginS
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function (mouse) {
                            AudioEngine.setVolume(
                                Math.max(0, Math.min(100, 100 * mouse.x / trilhoVolume.width)))
                        }
                    }
                }
            }
```

- [ ] verificação mecânica da task:
      `grep -c 'AudioEngine.setVolume' src/NowPlayingPanel.qml` → `3`
- [ ] verificação mecânica da task: `quiet-run cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/NowPlayingPanel.qml docs/plans/2026-08-28-clique-responde.md
git commit -m "feat(ui): bring volume and mute back into the transport row"
```

### Task 7: O detector de órfãos vira portão do repositório

- [ ] Criar `tools/check-orfaos.sh` com este conteúdo (é o detector já validado em
      2026-08-28, que achou as 24 lacunas; a lição está em
      `docs/solutions/ui/2026-08-28-redesenho-deixa-funcionalidade-orfa.md`):

```bash
#!/usr/bin/env bash
# Lista todo componente QML que nenhum outro QML instancia, e todo Q_INVOKABLE que nenhum
# QML chama. Foi a ausência deste portão que deixou um terço do app invisível com a suíte
# verde: um .qml órfão compila igual a um vivo, e teste de C++ não atravessa a tela.
#
# Sai 1 quando encontra órfão NOVO (fora da lista de exceções abaixo), 0 quando não.
set -u
cd "$(dirname "$0")/.." || exit 2

# Exceções conscientes. Singletons não são instanciados, são chamados (Icons.get(...)).
# Um invocável coberto por outro (pause/stop, cobertos por togglePause) também não é morto.
QML_OK="Main Theme Icons"
CPP_OK="pause stop trackAt episodeAt loadForShow isLiked recordSkip downloadDirectory"

falhas=0

for f in src/*.qml; do
  n=$(basename "$f" .qml)
  case " $QML_OK " in *" $n "*) continue ;; esac
  outros=$(ls src/*.qml | grep -v "/${n}.qml$")
  if ! grep -qlE "(^|[^A-Za-z])${n}[[:space:]]*\{" $outros 2>/dev/null; then
    echo "ÓRFÃO QML: $n — existe no disco, nenhum outro QML o instancia"
    falhas=$((falhas + 1))
  fi
done

for m in $(grep -hoP 'Q_INVOKABLE.*?\b(\w+)\(' src/*.h | grep -oP '\w+(?=\()' | sort -u); do
  case " $CPP_OK " in *" $m "*) continue ;; esac
  if ! grep -q "\.$m(" src/*.qml; then
    echo "NUNCA CHAMADO: $m — motor pronto sem botão que chegue nele"
    falhas=$((falhas + 1))
  fi
done

echo "----------------------------------------"
echo "check-orfaos: $falhas item(ns) sem porta de entrada"
[ "$falhas" -eq 0 ]
```

- [ ] Tornar executável e registrar a contagem de partida (esta fatia NÃO zera a lista: as
      fatias seguintes é que religam coleções, fila e ajustes):

```bash
chmod +x tools/check-orfaos.sh
bash tools/check-orfaos.sh; echo "exit=$?"
```

- [ ] verificação mecânica da task: `bash tools/check-orfaos.sh | tail -1` →
      linha começando com `check-orfaos:` (a contagem cai a zero só ao fim do lote; aqui o
      que se exige é que o script RODE e liste)
- [ ] commit:

```bash
git add tools/check-orfaos.sh docs/plans/2026-08-28-clique-responde.md
git commit -m "test(tools): detect orphan QML and unreachable invokables"
```

### Task 8: Reabrir o ledger que mente [sem-código]

- [ ] Três planos antigos estão `status: concluido` e o que eles entregaram não está mais na
      tela — o ledger registra o dia da entrega, não o estado de hoje. Reabri-los é o que
      impede o próximo `/retoma` de ler "tudo pronto":

```bash
python3 ~/.claude/scripts/planos-lote.py set-status docs/plans/2026-08-27-colecoes-tags.md travado --dir docs/plans
python3 ~/.claude/scripts/planos-lote.py set-status docs/plans/2026-08-27-download-youtube.md travado --dir docs/plans
python3 ~/.claude/scripts/planos-lote.py set-status docs/plans/2026-08-27-moldura-capa.md travado --dir docs/plans
```

- [ ] Acrescentar ao **fim** de cada um dos três planos o diagnóstico que o estado `travado`
      exige, colando este bloco (com o slug da fatia que o repõe trocado em cada arquivo:
      `colecoes-tela` para os dois primeiros, `clique-responde` para `moldura-capa`):

```markdown
## Diagnóstico (2026-08-28)

Reaberto pela auditoria de completude: o redesenho `melodia-capa-manda` trocou o shell da
janela e o que esta fatia entregou perdeu a porta de entrada. O código continua no
repositório e continua compilando — o que sumiu foi o caminho até ele.

Reposto pela fatia `<slug-que-repoe>` do lote `melodia-religa`. Volta a `concluido` quando
`bash tools/check-orfaos.sh` não listar mais nada desta fatia.
```

- [ ] verificação mecânica da task:
      `grep -c 'status: travado' docs/plans/2026-08-27-colecoes-tags.md docs/plans/2026-08-27-download-youtube.md docs/plans/2026-08-27-moldura-capa.md`
      → `1` em cada um dos três
- [ ] verificação mecânica da task:
      `grep -c 'Diagnóstico (2026-08-28)' docs/plans/2026-08-27-*.md | grep -c ':1'` → `3`
- [ ] commit:

```bash
git add docs/plans/2026-08-27-colecoes-tags.md docs/plans/2026-08-27-download-youtube.md docs/plans/2026-08-27-moldura-capa.md docs/plans/2026-08-28-clique-responde.md
git commit -m "docs(plans): reopen the three slices the redesign silently unplugged"
```

## Verificação da fatia (E2E)

- `quiet-run cmake --build build` → exit 0
- `quiet-run ctest --test-dir build --output-on-failure` → `100% tests passed` com
  `Total Tests: 9` ou mais (piso obrigatório: `ctest` sai 0 com `Total Tests: 0`)
- `grep -lc 'status: travado' docs/plans/2026-08-27-*.md | wc -l` → `3`
- `bash tools/check-layout.sh` → 11 medidas ok (o layout não pode ter mexido)
- `grep -cE '"(albums|tags)"' src/IconRail.qml` → `0`
- `grep -c 'heart-filled' src/Icons.qml` → `1`
- `grep -c 'applyLiked' src/tracklistmodel.h src/LibraryPane.qml` →
  `src/tracklistmodel.h:1`, `src/LibraryPane.qml:1`
- `bash tools/check-orfaos.sh` → roda e imprime a contagem (exit ≠ 0 é esperado nesta
  fatia; as coleções e a fila só voltam nas fatias seguintes)
- `./build/appmelodia --measure --pane library --shot /tmp/melodia-onda1.png --no-search`
  → imprime uma linha `MEDIDA …` e `SHOT /tmp/melodia-onda1.png`

## Fora de escopo

- Aleatório e repetir: continuam na tela e continuam inertes. Ligá-los é a fatia
  `shuffle-repeat` — decisão do Pedro em 2026-08-28 foi não removê-los agora.
- Coleções na tira de ícones: a fatia `colecoes-tela` insere o item, junto com a tela que
  ele abre. Inserir o ícone aqui criaria mais um botão que não leva a lugar nenhum, que é
  exatamente o defeito que esta fatia existe para acabar.
- Rótulo ao passar o mouse nos ícones da tira: `IconButton` tem `tooltip` e não o desenha;
  é conserto de outra fatia, e a tira nem usa `IconButton`.
- Mudo de verdade no motor (`mute` do mpv): o mudo desta fatia é volume 0 com memória do
  valor anterior, que é o comportamento que o usuário percebe. Um `mute` real no
  `AudioEngine` só se paga junto com a tela de ajustes.
