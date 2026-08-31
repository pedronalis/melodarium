---
slug: contexto-colecoes
feature: identidade-abas
status: em-execucao
depende-de: [contexto-podcast]
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Coleções contextuais Implementation Plan

> **Para execução agentic:** executar inline com TDD depois de `contexto-podcast`; a fatia só
> fecha depois de o Pedro ver lista e coleção aberta no app real.

**Goal:** fazer Coleções parecer um ambiente de curadoria, usando a coluna esquerda para a arte,
identidade e ações da coleção em vez de manter o player musical grande fora de contexto.

**Architecture:** `CollectionContextPanel` ocupa o terceiro slot do host contextual criado pela
fatia anterior. `Main.qml` mantém apenas o id da coleção aberta; o painel consulta a lista
agregada já fornecida por `CollectionManager::collections()` e emite ações, enquanto
`CollectionsPane` continua dono dos diálogos e da lista de faixas. O áudio ativo permanece no
`GlobalMiniPlayer` e nunca é recarregado pela troca de aba.

**Tech Stack:** Qt 6.10, Qt Quick/QML, Qt Quick Layouts, SQLite, CTest, Bash e Pillow.

## Global Constraints

- Reutilizar `CollectionManager.collections()`; não criar consulta, tabela ou cache novo.
- O mosaico usa no máximo as quatro capas já agregadas por coleção e resolve cada uma via
  `CoverCache.coverUrlForTrack(path, albumId)`.
- Sem coleção aberta, o painel mostra resumo da curadoria; com coleção aberta, mostra arte,
  nome, quantidade, duração, tocar e embaralhar.
- As ações do painel contextual atravessam sinais e chegam aos mesmos handlers que já tocam a
  coleção no cabeçalho; não duplicar lógica de `AudioEngine.loadPlaylist`.
- Fechar ou apagar a coleção limpa o contexto imediatamente; renomear ou alterar faixas atualiza
  nome, contagem, duração e mosaico pelo sinal `collectionsChanged`.
- O player grande continua exclusivo da Biblioteca e de episódio ativo em Podcast; Coleções
  sempre usa mini-player quando houver áudio.
- Cores vêm de `Theme`, dimensões de `Theme.uiScale`, e nomes recebidos do usuário têm
  `elide: Text.ElideRight` e largura limitada.
- Rodar build, piso de testes, suíte, órfãos, layout, fidelidade e gate contextual via
  `quiet-run` antes do commit final.

## File Map

- Create: `src/CollectionContextPanel.qml` — mosaico e resumo/ações da curadoria.
- Modify: `src/CollectionsPane.qml` — expor entrada controlada para criação e manter sinais do
  contexto sincronizados com os diálogos existentes.
- Modify: `src/Main.qml` — estado da coleção aberta e terceiro slot contextual.
- Modify: `CMakeLists.txt` — registrar o componente.
- Modify: `tools/check-contextual-ui.sh` — acrescentar estados de Coleções e comparação entre as
  três identidades.
- Create: `docs/telas/15-contexto-colecoes.png`, `docs/telas/16-contexto-colecao-aberta.png` —
  evidência de visão geral e coleção selecionada.

---

### Task 1: Painel contextual e ações de Coleções

**Files:**
- Create: `src/CollectionContextPanel.qml`
- Modify: `src/CollectionsPane.qml`
- Modify: `src/Main.qml`
- Modify: `CMakeLists.txt`
- Modify: `tools/check-contextual-ui.sh`
- Modify: `docs/plans/2026-08-31-contexto-colecoes.md`

**Interfaces:**
- Consumes: mapas de `CollectionManager.collections()` com `id`, `name`, `count`, `totalMs` e
  `covers`; `CoverCache.revision`; handlers atuais de `CollectionsPane.playRequested(bool)`.
- Produces: `CollectionContextPanel.selectedCollectionId`, sinais `openRequested(int,string)`,
  `playRequested(bool)` e `createRequested()`; medição `context=collections mini=<on|off>`.

- [x] **Step 1: estender o gate e provar RED**

  Acrescentar ao `tools/check-contextual-ui.sh`:

  ```text
  --pane collections sem arquivo        -> context=collections mini=off
  --pane collections --play-track <wav> -> context=collections mini=on
  ```

  Comparar os recortes da coluna esquerda e exigir diferença em pelo menos 2% dos pixels entre
  Biblioteca, Podcast e Coleções. Rodar `quiet-run bash tools/check-contextual-ui.sh` e confirmar
  falha porque o slot ainda não contém `CollectionContextPanel`.

- [x] **Step 2: criar o painel em dois estados**

  Em visão geral, compor um mosaico de até quatro capas coletadas das coleções visíveis, título
  “Sua curadoria”, totais de coleções/faixas e botão “Nova coleção”. Com coleção aberta, usar
  somente suas capas, mostrar nome, `N faixas · duração`, botão circular de tocar e botão de
  embaralhar. Com zero capas, usar o placeholder de playlist em `Theme.cRaised`.

- [x] **Step 3: ligar o painel ao pane sem duplicar comandos**

  Manter `selectedCollectionId` em `Main.qml`. Atualizá-lo em `onCollectionOpened`, zerá-lo em
  `onCloseRequested` e após exclusão. `openRequested` chama
  `collectionsLoader.item.open(id,name)`; `playRequested` chama o sinal já consumido pelo
  handler do `Main`; `createRequested` chama função pública `openCreateDialog()` em
  `CollectionsPane`, que abre o `NewCollectionDialog` já existente.

- [x] **Step 4: registrar, compilar e provar GREEN**

  Adicionar `src/CollectionContextPanel.qml` ao módulo, então rodar:

  `quiet-run cmake --build build && quiet-run bash tools/check-contextual-ui.sh && quiet-run bash tools/check-orfaos.sh && quiet-run bash tools/check-layout.sh && quiet-run bash tools/check-fidelidade.sh`

  Expected: cinco combinações de contexto/mini passam, as três colunas diferem visualmente e
  nenhum componente ou invocável novo fica órfão.

- [x] **Step 5: marcar a task e commitar**

  Marcar os passos no mesmo commit e executar:

  ```bash
  git add src/CollectionContextPanel.qml src/CollectionsPane.qml src/Main.qml CMakeLists.txt \
    tools/check-contextual-ui.sh docs/plans/2026-08-31-contexto-colecoes.md
  git commit -m "feat(collections): add a contextual curation surface"
  ```

### Task 2: Evidência visual e regressão cruzada

**Files:**
- Create: `docs/telas/15-contexto-colecoes.png`
- Create: `docs/telas/16-contexto-colecao-aberta.png`
- Modify: `docs/plans/2026-08-31-contexto-colecoes.md`

**Interfaces:**
- Consumes: banco temporário com coleção de quatro faixas e as flags `--pane collections`,
  `--open-collection`, `--play-track` e `--shot`.
- Produces: capturas reproduzíveis da visão geral e da coleção aberta, sem tocar no banco do
  usuário.

- [ ] **Step 1: criar fixture isolada e fotografar**

  Criar quatro WAVs temporários, importar ao banco isolado pela inicialização normal do app,
  inserir uma coleção `Gate contextual` e seus vínculos por SQLite, então salvar as duas
  capturas de 1100×700 em `docs/telas/`.

- [ ] **Step 2: inspecionar os estados densos**

  Conferir que mosaico, nome longo, contagem e duração cabem a 1100×700 e 720×700; confirmar que
  o mini-player permanece separado do contexto e que tocar/embaralhar continuam disponíveis no
  painel central e no contextual.

- [ ] **Step 3: rodar verificação fresca completa**

  Run: `quiet-run cmake -B build -G Ninja && quiet-run cmake --build build && quiet-run ctest --test-dir build -N && quiet-run ctest --test-dir build --output-on-failure && quiet-run bash tools/check-contextual-ui.sh && quiet-run bash tools/check-orfaos.sh && quiet-run bash tools/check-layout.sh && quiet-run bash tools/check-fidelidade.sh`

  Expected: pelo menos 22 testes descobertos, zero falhas, zero órfãos e todas as sondas de
  geometria/cor verdes.

- [ ] **Step 4: revisar impacto e commitar evidência**

  Rodar `gitnexus detect_changes` contra `main`, marcar a task e executar:

  ```bash
  git add docs/telas/15-contexto-colecoes.png docs/telas/16-contexto-colecao-aberta.png \
    docs/plans/2026-08-31-contexto-colecoes.md
  git commit -m "test(ui): capture the collection contextual states"
  ```

## Gate humano

- [ ] Pedro vê Biblioteca, visão geral de Coleções e coleção aberta no app real, testa uma ação
  de tocar e confirma a individualidade da aba. Só então executar
  `python3 ~/.claude/scripts/planos-lote.py set-status docs/plans/2026-08-31-contexto-colecoes.md concluido`.
