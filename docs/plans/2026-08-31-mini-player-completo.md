---
slug: mini-player-completo
feature: identidade-abas
status: em-execucao
depende-de: [contexto-podcast, contexto-colecoes]
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Mini-player completo e velocidade nativa Implementation Plan

> **Para execução agentic:** executar inline com TDD. O menu de velocidade precisa ser aberto
> e acionado num backend de janela real; `grabToImage` e a leitura da propriedade não bastam.

**Goal:** transformar a barra global em um player equilibrado de três zonas, com transporte,
progresso, fila e volume completos, e oferecer em episódios um seletor nativo de velocidade.

**Architecture:** `GlobalMiniPlayer.qml` continua sendo o único transporte global fora do
contexto do player grande, mas passa a distribuir metadata, transporte/progresso e utilidades
em três zonas de largura igual para manter o play no centro da janela. `SpeedControl.qml`
continua compartilhado com `NowPlayingPanel`, mas seu menu solicita `Popup.Native`; no Linux do
projeto, o tema de plataforma GTK renderiza os `MenuItem`s pelas APIs nativas e o Qt conserva
fallback de janela se o backend não oferecer menu nativo.

**Tech Stack:** Qt 6.10.3, Qt Quick/QML, Qt Quick Controls, libmpv, CTest, Bash, Xvfb, xdotool,
ImageMagick e Pillow.

## Global Constraints

- Não alterar fila, sessão, banco, MPRIS ou semântica de reprodução do `AudioEngine`.
- Música mostra aleatório, anterior, play/pause, próxima e repetição; episódio mostra velocidade,
  voltar 30 s, play/pause e avançar 30 s.
- O progresso fica abaixo do transporte, com tempo atual e duração total, e aceita seek por clique.
- A zona direita expõe fila, mudo e volume; em 720 px o slider pode recolher, mas os botões e a
  zona de metadata não podem transbordar.
- O centro geométrico do transporte deve coincidir com o centro do mini-player, não com o espaço
  que sobrou entre metadata e volume.
- `SpeedControl` usa `Menu { popupType: Popup.Native }`, itens marcáveis e as velocidades
  `0,75×`, `1×`, `1,25×`, `1,5×`, `1,75×` e `2×`; não desenhar popup QML próprio.
- O mesmo seletor nativo continua funcionando no `NowPlayingPanel` de Podcast.
- Cores saem de `Theme`, todas as dimensões passam por `Theme.uiScale` e metadata recebida do
  usuário usa `elide` com largura limitada.
- Rodar sempre por `quiet-run`; antes do commit final executar build, piso de testes, suíte,
  órfãos, layout, fidelidade e gate contextual.

## File Map

- Modify: `src/GlobalMiniPlayer.qml` — layout em três zonas, transporte, seek, fila e volume.
- Modify: `src/SpeedControl.qml` — menu nativo, opções marcáveis e API de abertura para gate.
- Modify: `src/Main.qml` — ligar fila, abrir o menu no modo de medição e publicar geometria/estado.
- Modify: `tools/check-contextual-ui.sh` — RED/GREEN de música, episódio, 720 px e gesto nativo.
- Create: `docs/telas/17-mini-player-completo.png` — estado musical a 1100×700.
- Create: `docs/telas/18-mini-player-podcast-velocidade.png` — episódio com menu nativo aberto.
- Modify: `docs/plans/2026-08-31-mini-player-completo.md` — ledger da fatia.

---

### Task 1: Contrato visual e de interação do mini-player

**Files:**
- Modify: `tools/check-contextual-ui.sh`
- Modify: `docs/plans/2026-08-31-mini-player-completo.md`

**Interfaces:**
- Consumes: `MEDIDA`, `--pane`, `--play-track`, `--play-episode`, `--open-speed-menu`, Xvfb e
  `xdotool`.
- Produces: exigências `minilayout=fit`, `minicenter=fit`, `minimode=music|podcast`,
  `speedmenu=native|na` e `speed=1.50` depois de escolher a opção nativa.

- [x] **Step 1: escrever o gate vermelho dos três estados**

  Estender o caso musical em Coleções para exigir layout dentro da barra e transporte centrado
  em 1100 e 720 px. Semear `podcast_shows`/`podcast_episodes` no banco isolado, apontar o episódio
  para o WAV do fixture e exigir em Coleções um mini-player de Podcast com menu nativo preferido.

- [x] **Step 2: provar RED**

  Run: `quiet-run cmake --build build && quiet-run bash tools/check-contextual-ui.sh`

  Expected: falha porque `MEDIDA` ainda não publica `minilayout`, `minicenter`, `minimode` nem
  `speedmenu`, e `GlobalMiniPlayer` ainda não instancia `SpeedControl`.

- [x] **Step 3: acrescentar o gesto nativo vermelho**

  Iniciar o app com banco isolado em `Xvfb`, `QT_QPA_PLATFORM=xcb` e
  `QT_QPA_PLATFORMTHEME=gnome`; abrir o episódio no mini-player com `--open-speed-menu`, enviar
  `Home`, três `Down` e `Return` via `xdotool`, e exigir `speed=1.50` na linha `MEDIDA`.

- [x] **Step 4: marcar a task no mesmo commit do gate**

  O gate permanece vermelho até a Task 2; não commitar a quebra isoladamente.

### Task 2: Player de três zonas e velocidade nativa

**Files:**
- Modify: `src/GlobalMiniPlayer.qml`
- Modify: `src/SpeedControl.qml`
- Modify: `src/Main.qml`
- Modify: `tools/check-contextual-ui.sh`
- Modify: `docs/plans/2026-08-31-mini-player-completo.md`

**Interfaces:**
- Consumes: `AudioEngine.position`, `duration`, `playing`, `volume`, `speed`, `shuffle`,
  `repeatMode`, `seek`, `setVolume`, `setSpeed`, `setShuffle`, `cycleRepeat`, `previous`, `next`
  e o `QueueOverlay` existente.
- Produces: `GlobalMiniPlayer.queueOpenRequested()`, `layoutFits`, `transportCentered`,
  `transportKind`, `nativeSpeedMenu`; `SpeedControl.openMenu()` e `nativeMenuPreferred`.

- [x] **Step 1: tornar o seletor de velocidade nativo**

  Definir `popupType: Popup.Native`; trocar o `Repeater` por seis `MenuItem`s simples,
  `checkable` e com `checked` ligado a `speed`. Expor somente `openMenu()`, contagem e preferência
  nativa necessárias ao gate, preservando `speedPicked(real)` para ambos os players.

- [x] **Step 2: reconstruir o mini-player em três zonas iguais**

  Usar altura-base de 82 px. Zona esquerda: capa de 52 px, título e artista. Zona central:
  transporte musical ou de fala e, abaixo, tempos + trilho interativo. Zona direita: fila,
  mudo e slider de volume; recolher apenas o slider no modo estreito. Manter todas as zonas com
  `Layout.fillWidth` e mesmo `Layout.preferredWidth` para centralização geométrica.

- [x] **Step 3: ligar ações e instrumentação sem duplicar lógica**

  `queueOpenRequested` abre o `QueueOverlay` existente em `Main.qml`. Publicar medidas reais das
  bordas dos filhos e do centro do transporte; abrir o menu de velocidade por um Timer dedicado
  quando `--open-speed-menu` estiver presente, depois de o episódio ser carregado.

- [x] **Step 4: provar GREEN e regressão**

  Run: `quiet-run cmake --build build && quiet-run bash tools/check-contextual-ui.sh && quiet-run bash tools/check-orfaos.sh && quiet-run bash tools/check-layout.sh && quiet-run bash tools/check-fidelidade.sh`

  Expected: música e Podcast cabem em 1100/720, transporte fica centrado, o gesto escolhe
  `1,5×`, nenhum componente fica órfão e os gates anteriores permanecem verdes.

- [x] **Step 5: revisar impacto e commitar**

  Rodar `gitnexus detect_changes` contra `main`, marcar as tasks 1 e 2 e executar:

  ```bash
  git add src/GlobalMiniPlayer.qml src/SpeedControl.qml src/Main.qml \
    tools/check-contextual-ui.sh docs/plans/2026-08-31-mini-player-completo.md
  git commit -m "feat(player): complete the global playback bar"
  ```

### Task 3: Evidência visual e gate humano

**Files:**
- Create: `docs/telas/17-mini-player-completo.png`
- Create: `docs/telas/18-mini-player-podcast-velocidade.png`
- Modify: `docs/plans/2026-08-31-mini-player-completo.md`

**Interfaces:**
- Consumes: fixture isolado da Task 1, `--shot`, captura externa do Xvfb e o app real no
  workspace 10.
- Produces: duas capturas reproduzíveis e a versão nova aberta para avaliação do Pedro.

- [x] **Step 1: fotografar música e Podcast**

  Salvar a captura interna do estado musical em 1100×700. Para Podcast, capturar a janela raiz
  do Xvfb enquanto o menu nativo estiver aberto, antes de enviar a escolha de `1,5×`.

- [x] **Step 2: inspecionar as capturas em 1100 e 720 px**

  Conferir centro, hierarquia, elide, contraste, estados ativos, barra de progresso e ausência
  de colisão entre metadata, transporte e volume.

- [x] **Step 3: rodar verificação fresca completa**

  Run: `quiet-run cmake -B build -G Ninja && quiet-run cmake --build build && quiet-run ctest --test-dir build -N && quiet-run ctest --test-dir build --output-on-failure && quiet-run bash tools/check-contextual-ui.sh && quiet-run bash tools/check-orfaos.sh && quiet-run bash tools/check-layout.sh && quiet-run bash tools/check-fidelidade.sh`

  Expected: pelo menos 22 testes descobertos, zero falhas, zero órfãos e todos os gates verdes.

- [x] **Step 4: revisar impacto, commitar evidência e abrir no workspace 10**

  Rodar `gitnexus detect_changes` contra `main`, marcar a task, commitar as capturas e reiniciar
  somente a instância `melodarium` pelo mesmo procedimento gracioso já validado.

### Task 4: Entrada suave da aba e estado correto do volume

**Files:**
- Modify: `src/Main.qml`
- Modify: `src/GlobalMiniPlayer.qml`
- Modify: `tools/check-contextual-ui.sh`
- Modify: `docs/plans/2026-08-31-mini-player-completo.md`

**Interfaces:**
- Consumes: `Theme.animationNormal`, `Theme.easingType`, `Theme.reduzirMovimento`,
  `showGlobalMiniPlayer`, `effectiveSection` e `AudioEngine.volume`.
- Produces: host do mini-player com `revealProgress`, transição de entrada da aba por
  `sectionReveal`, linha `MOTION` com amostras de altura/opacidade e cor observável do ícone de
  volume nos estados ligado/mutado.

- [x] **Step 1: escrever os gates vermelhos de movimento e cor**

  Acrescentar `--measure-mini-motion`: iniciar em Biblioteca com música, trocar internamente
  para Podcast e Coleções, amostrar a altura do host antes, durante e depois dos 250 ms e exigir
  `0 < mid < target`. Amostrar também `sectionReveal` no meio e no fim. Fotografar o mini-player
  com volume 100 e com `--measure-volume 0`; no recorte `(955,635)-(990,670)`, exigir pico claro
  no estado ligado e somente cinza no mutado.

- [x] **Step 2: provar RED**

  Run: `quiet-run cmake --build build && quiet-run bash tools/check-contextual-ui.sh`

  Expected: falha porque `--measure-mini-motion` não publica `MOTION` e o ícone ligado ainda
  usa `Theme.cMuted` (máximo aproximado `#5d5d5d`) em vez de `Theme.cTitle`.

- [x] **Step 3: animar a entrada sem provocar salto de layout**

  Envolver `GlobalMiniPlayer` num host recortado cuja `Layout.preferredHeight` acompanha
  `revealProgress * implicitHeight`; ancorar a barra ao fundo do host, produzindo subida real
  enquanto a lista cede altura. Limitar `Theme.animationNormal` a 250 ms e usar
  `Theme.easingType`. Ao mudar `effectiveSection`, animar de `sectionReveal=0` para `1`, usando
  fade de `0,72→1` e `Translate.y` de `8*Theme.uiScale→0` no contexto e no pane central.

- [x] **Step 4: corrigir a semântica visual do volume**

  No botão de volume do mini-player, usar `Theme.cTitle` quando `AudioEngine.volume > 0` e
  `Theme.cMuted` quando estiver zerado. Preservar os glifos `volume`, `volume-low` e
  `volume-off`, o clique reversível e o hover atual.

- [x] **Step 5: provar GREEN, revisar impacto e commitar**

  Rodar build, gate contextual, órfãos, layout, fidelidade, suíte completa e
  `gitnexus detect_changes`. Marcar a task no mesmo commit:

  ```bash
  git add src/Main.qml src/GlobalMiniPlayer.qml tools/check-contextual-ui.sh \
    docs/plans/2026-08-31-mini-player-completo.md
  git commit -m "feat(ui): animate contextual player transitions"
  ```

## Gate humano

- [ ] Pedro testa música e episódio no app real, abre o menu de velocidade, escolhe outro valor
  e confirma a hierarquia do player. Só então fechar esta fatia e os dois planos contextuais.
