---
slug: contexto-podcast
feature: identidade-abas
status: em-execucao
depende-de: []
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Podcast contextual e reprodução global Implementation Plan

> **Para execução agentic:** executar inline com TDD; a fatia só fecha depois de o Pedro ver
> Biblioteca e Podcast lado a lado e confirmar que já não parecem a mesma tela.

**Goal:** separar o contexto que o usuário explora do áudio que continua tocando, mantendo o
player grande na Biblioteca, dando ao Podcast um painel próprio e preservando reprodução global
num mini-player quando uma música toca fora da Biblioteca.

**Architecture:** `Main.qml` passa a ter um host de contexto à esquerda do pane principal. O
mesmo `NowPlayingPanel` ocupa esse host na Biblioteca e quando um episódio está tocando dentro de
Podcast; sem episódio, `PodcastContextPanel` apresenta programa selecionado ou “Continuar
ouvindo”. `GlobalMiniPlayer` ocupa o rodapé da área de conteúdo somente quando o áudio ativo não
está representado pelo painel contextual visível.

**Tech Stack:** Qt 6.10, Qt Quick/QML, Qt Quick Layouts, C++20, SQLite, Qt Test, CTest, Bash e
Pillow para comparação das capturas offscreen.

## Global Constraints

- A reprodução continua global: trocar de aba nunca pausa, recarrega ou substitui a fila.
- Biblioteca preserva o `NowPlayingPanel` completo, sua capa, halo, fila e transporte atuais.
- Podcast com episódio ativo usa transporte de fala (velocidade e saltos de 30 s); Podcast com
  música ativa mantém contexto de podcast e mostra a música apenas no mini-player.
- O mini-player não aparece sem arquivo ativo nem duplica um `NowPlayingPanel` que já representa
  o áudio atual.
- Cores novas usam somente os papéis de `Theme`; medidas passam por `Theme.uiScale`.
- A janela permanece uma superfície única, sem card externo em volta do conteúdo.
- Todo componente novo entra em `qt_add_qml_module`, ganha instanciação real e passa por
  `tools/check-orfaos.sh`.
- Build e testes sempre rodam via `quiet-run`; `ctest -N` precisa descobrir pelo menos os 21
  alvos da linha de base e o novo `tst_contextual_ui`.
- A fatia roda `check-layout.sh` e `check-fidelidade.sh`; alterações de coordenada no segundo
  exigem reamostragem da captura, não ajuste por tentativa.
- Não alterar caminhos de dados, fila persistida, qualidade do áudio, MPRIS ou banco do usuário.

## File Map

- Modify: `src/podcastlibrary.cpp`, `tests/tst_podcast.cpp` — completar o contrato de
  `continueListening()` com identidade e capa do programa.
- Create: `src/GlobalMiniPlayer.qml` — transporte compacto global, com semântica própria para
  música e episódio.
- Create: `src/PodcastContextPanel.qml` — capa do programa, contagens e cartão de retomada.
- Modify: `src/PodcastPane.qml` — transformar a escolha de programa em estado controlado pelo
  shell, sem duplicar fonte de verdade.
- Modify: `src/Main.qml` — host contextual, regra de visibilidade do mini-player e medições dos
  estados de contexto.
- Modify: `CMakeLists.txt` — registrar os dois componentes QML.
- Create: `tools/check-contextual-ui.sh` — provar por execução os estados de contexto e a
  diferença visual entre Biblioteca e Podcast.
- Modify: `tests/CMakeLists.txt` — registrar `tst_contextual_ui` com timeout explícito.
- Create: `docs/telas/13-contexto-podcast.png`, `docs/telas/14-mini-player-global.png` —
  evidência visual reproduzível da fatia.

---

### Task 1: Dar identidade visual a “Continuar ouvindo”

**Files:**
- Modify: `tests/tst_podcast.cpp`
- Modify: `src/podcastlibrary.cpp`
- Modify: `docs/plans/2026-08-31-contexto-podcast.md`

**Interfaces:**
- Consumes: `podcast_shows.{id,title,cover_path}` e episódios iniciados retornados pelo filtro
  atual de `PodcastScope`.
- Produces: cada mapa de `PodcastLibrary::continueListening(int)` contém `showId` e `coverPath`,
  além das chaves já existentes (`id`, `title`, `showTitle`, `positionMs`, `durationMs`,
  `progress`, `path`).

- [x] **Step 1: escrever o teste vermelho do contrato**

  Em `continueListeningShowsOnlyStartedAndUnfinished()`, criar um programa com `cover_path`
  conhecido e exigir `showId == 1` e `coverPath == "/covers/programa.jpg"` no episódio
  retornado, preservando as asserções atuais de filtro e progresso.

- [x] **Step 2: provar RED**

  Run: `quiet-run cmake --build build && quiet-run ./build/tests/tst_podcast continueListeningShowsOnlyStartedAndUnfinished`

  Expected: falha de comparação porque as duas chaves ainda não existem; o binário do teste é
  reconstruído antes da execução.

- [x] **Step 3: ampliar a consulta sem nova ida ao banco**

  Acrescentar `s.id` e `IFNULL(s.cover_path,'')` ao `SELECT` já unido a `podcast_shows` e
  publicar as chaves `showId` e `coverPath` no `QVariantMap`. Manter ordenação, limite e escopo
  ativo exatamente como estão.

- [x] **Step 4: provar GREEN e regressão**

  Run: `quiet-run cmake --build build && quiet-run ./build/tests/tst_podcast continueListeningShowsOnlyStartedAndUnfinished && quiet-run ctest --test-dir build -R 'tst_podcast|tst_librarybrowser' --output-on-failure`

  Expected: o caso específico e os dois alvos passam sem skips.

- [x] **Step 5: marcar a task e commitar**

  Marcar estes cinco passos no mesmo commit e executar:

  ```bash
  git add src/podcastlibrary.cpp tests/tst_podcast.cpp docs/plans/2026-08-31-contexto-podcast.md
  git commit -m "feat(podcast): expose show identity for listening progress"
  ```

### Task 2: Shell contextual, mini-player e painel de Podcast

**Files:**
- Create: `src/GlobalMiniPlayer.qml`
- Create: `src/PodcastContextPanel.qml`
- Create: `tools/check-contextual-ui.sh`
- Modify: `src/PodcastPane.qml`
- Modify: `src/Main.qml`
- Modify: `CMakeLists.txt`
- Modify: `tests/CMakeLists.txt`
- Modify: `docs/plans/2026-08-31-contexto-podcast.md`

**Interfaces:**
- Consumes: `AudioEngine` (`currentFile`, `playing`, `position`, `duration`, `togglePause`,
  `previous`, `next`, `seek`), `LibraryBrowser.trackForPath`, `PodcastLibrary.episodeForPath`,
  `PodcastLibrary.shows()` e `PodcastLibrary.continueListening(1)`.
- Produces: `GlobalMiniPlayer.episodeMode`; `PodcastContextPanel.selectedShowId` e sinal
  `showRequested(int)`; `PodcastPane.showFilter` controlado pelo shell e sinal
  `showRequested(int)`; medição `context=<player|podcast|collections>` e `mini=<on|off>`.

- [x] **Step 1: escrever e registrar o gate vermelho**

  Criar `tools/check-contextual-ui.sh` para gerar um WAV temporário, iniciar o app com dados e
  configurações isolados e exigir estas linhas de execução:

  ```text
  --pane library --play-track <wav>      -> context=player  mini=off
  --pane podcast --play-track <wav>      -> context=podcast mini=on
  --pane podcast sem arquivo             -> context=podcast mini=off
  ```

  O script também salva as capturas de Biblioteca e Podcast, recorta a coluna contextual e
  exige diferença em pelo menos 2% dos pixels; ruído QML (`ReferenceError`, `TypeError`, tipo
  indisponível ou binding loop) reprova. Registrar como `tst_contextual_ui` em
  `tests/CMakeLists.txt`.

- [x] **Step 2: provar RED**

  Run: `quiet-run cmake -B build -G Ninja && quiet-run cmake --build build && quiet-run ctest --test-dir build -N -R tst_contextual_ui && quiet-run ctest --test-dir build -R tst_contextual_ui --output-on-failure`

  Expected: um alvo é descoberto e falha porque `MEDIDA` ainda não publica `context`/`mini` e
  as duas abas ainda compartilham o mesmo painel.

- [x] **Step 3: implementar o mini-player global**

  Criar um rodapé de altura escalada entre 60 e 68 px com capa de 42 px, título, subtítulo,
  barra de progresso e três controles. Em música, os controles laterais chamam
  `previous()`/`next()`; em episódio, chamam `seek(position - 30)`/`seek(position + 30)` e
  mostram tooltips correspondentes. Resolver metadata e capa no mesmo padrão do
  `NowPlayingPanel`, reagindo a `AudioEngine.currentFileChanged` e `CoverCache.revision`.

- [x] **Step 4: implementar o painel contextual de Podcast**

  O painel usa a mesma largura e o mesmo degradê do player. Com `selectedShowId > 0`, mostra
  capa, título, total e não ouvidos do programa; com “Todos”, prioriza o primeiro item de
  `continueListening(1)`, com progresso e botão que chama `PodcastLibrary.playEpisode(id)`.
  Sem retomada, mostra o conjunto de programas e uma chamada discreta para escolher um feed no
  menu central. A capa usa `RoundedCover`, placeholder quente e `Theme.uiScale`.

- [x] **Step 5: tornar o filtro de programa um estado único**

  Em `PodcastPane.qml`, substituir atribuições internas a `showFilter` por
  `root.showRequested(id)`. Em `Main.qml`, manter `podcastShowId`, passá-lo ao pane e ao painel
  contextual e atualizar ambos no handler. Assim, selecionar pelo menu ou pelo contexto troca a
  mesma lista sem quebrar binding QML.

- [x] **Step 6: montar o host contextual no shell**

  Reorganizar a área à direita do `IconRail` como `ColumnLayout`: linha principal com
  `StackLayout` contextual + pane e, abaixo, `GlobalMiniPlayer`. O contexto efetivo é o pane de
  medição quando `--measure` está ativo, senão `root.section`. Regras exatas:

  ```text
  library                         -> NowPlayingPanel
  podcast + currentEpisodeId > 0 -> NowPlayingPanel em episodeMode
  podcast sem episódio ativo     -> PodcastContextPanel
  collections                    -> NowPlayingPanel até a próxima fatia ocupar o terceiro slot
  mini-player                    -> arquivo ativo e contexto atual não é NowPlayingPanel
  ```

  Preservar os handlers, a largura `implicitWidth`/`maximumWidth`, o mínimo do pane e a decisão
  de `LibraryPane.showQueueStrip` baseada no mesmo `NowPlayingPanel` vivo.

- [x] **Step 7: provar GREEN e alcance**

  Run: `quiet-run cmake --build build && quiet-run ctest --test-dir build -R tst_contextual_ui --output-on-failure && quiet-run bash tools/check-orfaos.sh && quiet-run bash tools/check-layout.sh && quiet-run bash tools/check-fidelidade.sh`

  Expected: gate contextual passa os três estados, zero órfãos novos, layout nominal/mínimo e
  quinze sondas de fidelidade permanecem verdes.

- [x] **Step 8: marcar a task e commitar**

  Marcar estes passos no mesmo commit e executar:

  ```bash
  git add src/GlobalMiniPlayer.qml src/PodcastContextPanel.qml src/PodcastPane.qml src/Main.qml \
    CMakeLists.txt tests/CMakeLists.txt tools/check-contextual-ui.sh \
    docs/plans/2026-08-31-contexto-podcast.md
  git commit -m "feat(ui): give podcasts a contextual playback surface"
  ```

### Task 3: Evidência visual do Podcast

**Files:**
- Create: `docs/telas/13-contexto-podcast.png`
- Create: `docs/telas/14-mini-player-global.png`
- Modify: `docs/plans/2026-08-31-contexto-podcast.md`

**Interfaces:**
- Consumes: `--measure`, `--pane podcast`, `--play-track`, `--shot` e banco isolado.
- Produces: duas capturas de 1100×700: Podcast sem áudio e Podcast com música preservada no
  mini-player.

- [x] **Step 1: fotografar os dois estados reproduzíveis**

  Usar o mesmo fixture isolado do gate para salvar as duas capturas em `docs/telas/`, com
  `--sem-animacao`, `--no-search` e `--delay 1800`.

- [x] **Step 2: inspecionar as imagens**

  Conferir visualmente que o painel de Podcast não contém “nada tocando” musical, que a capa e
  os textos não transbordam, e que o mini-player não encobre lista nem trilho.

- [x] **Step 3: rodar os gates completos da fatia**

  Run: `quiet-run cmake --build build && quiet-run ctest --test-dir build -N && quiet-run ctest --test-dir build --output-on-failure && quiet-run bash tools/check-contextual-ui.sh && quiet-run bash tools/check-orfaos.sh && quiet-run bash tools/check-layout.sh && quiet-run bash tools/check-fidelidade.sh`

  Expected: pelo menos 22 testes descobertos, zero falhas e zero órfãos novos.

- [x] **Step 4: revisar impacto e commitar evidência**

  Rodar `gitnexus detect_changes` contra `main`, marcar a task e executar:

  ```bash
  git add docs/telas/13-contexto-podcast.png docs/telas/14-mini-player-global.png \
    docs/plans/2026-08-31-contexto-podcast.md
  git commit -m "test(ui): capture the podcast contextual states"
  ```

## Gate humano

- [ ] Pedro vê Biblioteca e Podcast no app real e confirma que a troca de aba agora muda o
  ambiente sem esconder a reprodução. Só então executar
  `python3 ~/.claude/scripts/planos-lote.py set-status docs/plans/2026-08-31-contexto-podcast.md concluido`.
