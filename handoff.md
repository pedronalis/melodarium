# Handoff — melodarium

> Atualizado: 2026-08-29 13:29 · branch: `main` · via /fecho · contexto: ~67% consumido

## Estado

- **A coleção virou playlist.** Toca inteira (com embaralhar), a linha da lista virou cartão
  com mosaico de capas e "N faixas · tempo", toca sem abrir, e a faixa se arrasta para outro
  lugar com a ordem gravada em `collection_tracks.position`. Lote de 4 fatias planejado,
  despachado headless, colhido verde e integrado em `main` (`b7a4fe7`).
- **A fila ganhou tela.** "N na fila" e o "+N" da tirinha abrem a fila inteira por cima, no
  mesmo formato do overlay de busca; um clique pula para qualquer faixa. Tirar da fila e
  reordenar continuam de fora — o motor não tem esses verbos.
- **A barra perdeu o botão morto.** A nota musical do topo tinha o tamanho e a cor dos ícones
  apagados que SÃO botões, e não clicava. O Pedro perguntou para que servia, que é a prova do
  defeito. Saiu; os cinco elementos restantes clicam.
- **O canvas de telas virou o app de hoje:** 18 quadros interativos (biblioteca, coleções,
  podcast, busca, fila, ajustes, os 4 estados vazios, as 4 caixas), em
  <https://claude.ai/code/artifact/c1b9607c-b0ba-4055-a5f5-5bcf47f7fdf1>.
- **Duas peças saíram da reserva do detector de órfãos:** `moveTrackInCollection` (ganhou a
  alça de arrastar) e `ingestDownloadedFile` (era falso positivo — fecha dentro do C++).
  Restam quatro esperando tela.

## Alvo

- **Frente:** melodarium — player de música local com a estética do Noctalia
- **Plano-fonte:** `docs/specs/2026-08-27-player-musica-podcast.md` — 9 fatias do produto +
  5 do redesenho `melodia-capa-manda`, todas `concluido` (14/14)
- **PRONTA quando:** as fatias concluídas **e** o Pedro ouvindo o som sair ao clicar numa faixa
- **Restante:** só o julgamento do Pedro na tela dele. O app foi aberto na tela dele em
  29/08 13:2x com as coleções já como playlist; falta ele clicar e dizer. Nenhum código
  pendente do plano-fonte.
- **Correção de rumo (Pedro, 2026-08-28):** "Despacha e me traz pronto, é isso que eu
  quero" — gates de conferência visual passaram a ser meus, não dele.
- **Correção de rumo (Pedro, 2026-08-28, tarde):** "o visual ainda está feio, não está fiel as
  cores do artifact desenhado, não está com degrades, não está com as capas com bordas
  arredondadas, o badge de criar tag está diferente" — gate de geometria passa verde com a
  paleta inteira errada; desde então todo redesenho roda `tools/check-fidelidade.sh`.
- **Correção de rumo (Pedro, 2026-08-29):** "as coleções cara, esqueceu? Isso era core do app,
  eu poder mostrar as coleções como se fossem playlists se não não faz sentido ter a tela
  coleções" — a tela existia e listava faixas, mas nenhum dos cinco botões do cabeçalho TOCAVA.
  Virou o lote `colecao-playlist`, concluído no mesmo dia.

## Fila da sessão

1. **[S · IMPASSE · bloqueado em ação humana]** O app está ABERTO na tela dele desde 29/08
   13:2x. Falta o minuto dele, e nomeando: clicar numa faixa e dizer se sai som; abrir
   Coleções, criar uma pelo `+`, jogar faixas nela pelo `+` da linha da biblioteca, e dizer se
   a playlist é o que ele queria. — 4ª fila desde 2026-08-27. · done: ele responde
2. **[S · 4ª desde 2026-08-27]** Ouvir e aprovar a tela — **bloqueado pelo vagão 1** ·
   done: o Pedro confirma o som e o visual
3. **[S · 2ª desde 2026-08-28]** Abrir o repo ao público, como o spec pede — nada trava mais ·
   done: `gh repo view --json visibility` diz `PUBLIC`

## Estacionamento (derivas)

- [ ] 2026-08-30 · DERIVA: portão de cor instável — `check-fidelidade.sh` reprova 1 em 5 com
  "a capa está quadrada" sem nada mudar; a foto sai antes de a capa terminar de arredondar.

- [ ] 2026-08-27 · Bit-perfect real depende do grafo do PipeWire (`default.clock.rate`), não só
      das opções do mpv. O plano documenta o limite; medir de verdade exige um FLAC 96 kHz e uma
      sonda no ponto ALSA.
- [ ] 2026-08-29 · **REABERTO — o banco fantasma voltou, e a causa é viva.** O item de 28/08
      previu exatamente isto: apagamos o `melodia.db` de 0 byte e escrevemos que, se um
      `melodarium.db` de 0 byte reaparecesse solto em `~/.local/share/melodarium/`, valeria
      investigar. Reapareceu. Medido em 29/08 durante a `/planeja`:
      `~/.local/share/melodarium/melodarium.db` = **0 bytes**, enquanto o banco de verdade é
      `~/.local/share/melodarium/melodarium/melodarium.db` = 188 KB (16 tabelas, com dados).
      O de dentro é o do `QStandardPaths::AppDataLocation` (`<org>/<app>`); o de fora é criado
      por ALGUÉM que monta o caminho sem a pasta da organização, abre e não escreve. Suspeito
      principal: um caminho de banco montado à mão fora de `Database::caminhoDoBanco`
      (`src/database.cpp:265`). Risco real: o dia em que esse caminho for usado para ESCREVER,
      o app abre vazio como se nunca tivesse sido usado.
      DERIVA da sessão de 29/08 — estacionado, não investigado.
      Registrado também em `docs/solutions/dados/2026-08-28-renomear-o-app-muda-todo-caminho-de-dados.md`
      (adendo 29/08), porque a forma errada do caminho já custou tempo ao escrever planos.
- [ ] 2026-08-29 · Dois worktrees de run no disco, ambos já integrados em `main`:
      `~/dev/active/melodia-religa-run` (`exec/melodia-religa`) e
      `~/dev/active/melodarium-colecao-run` (`exec/colecao-playlist`). Removíveis com
      `git worktree remove` quando o Pedro quiser — o segundo guarda `RESUMO_RUN.md` e
      `DECISOES_RUN.md`, que ficam fora do git por exclusão do próprio repo.

## Em voo

Nada em voo. Os dois runs de 2026-08-29 foram colhidos:

- **`melodarium-anima`** (6 fatias de animação) — portão verde, integrado em `main`.
- **`perf-redesenho`** (o núcleo queimado com o app parado) — portão verde, integrado em
  `main`. A causa não era a tela: era a vigia de área de transferência do libmpv, que entra
  em laço quando há algo grande copiado. Lição em
  `docs/solutions/perf/2026-08-29-redesenho-continuo.md`.

Quatro peças de motor seguem em **reserva declarada**, impressas pelo `check-orfaos.sh` a cada
execução: `collectionsForTrack`, `continueListening`, `setGaplessAggressive` e `unsubscribe`.
Esperam decisão sobre merecerem tela.

## Verificação

> Todos rodados DEPOIS do merge `b7a4fe7` — merge limpo não prova integração correta.

- `ctest --test-dir build --output-on-failure` → `100% tests passed, 0 failed out of 9` · 2026-08-29 13:0x
- `bash tools/check-layout.sh` → 0 falhas (janela de 1100 e de 720) · 2026-08-29 13:0x
- `bash tools/check-orfaos.sh` → `0 item(ns) sem porta de entrada`, 4 em reserva · 2026-08-29 13:0x
- `bash tools/check-fidelidade.sh` → 10 pontos de cor ok · 2026-08-29 13:0x
  (a sonda do trilho mudou de (16,108) para (28,63): sem a marca, a fileira subiu 38 px)
- áudio real na saída, em canal isolado → pico 0,173 / RMS 0,026 contra 0,009 / 0,002 de
  silêncio · 2026-08-28

## Calibração de custo

> Só APPEND — histórico estimado-vs-real que o /retoma grava ao colher e o /despacha lê para estimar.

- 2026-08-27 · /despacha run headless · fatias 1-3 (`esqueleto-build` → `motor-audio` →
  `scan-biblioteca`, 16 tasks, C++/Qt6 do zero) · modelo Opus 5 · estimado ~500-900k tok novos
  / 30-60 min · real **~138k tok novos (~22,6M com releitura, inflação 164×) / ~0,24 h /
  186 turnos** · Δ tokens **−78%**, Δ tempo **−77%** · **PASSOU** — 19 commits, gate 12/12,
  suíte 3 alvos / 20 casos. Três lições:
  **(1) Terceiro ponto seguido de superestimativa de tempo** (−40% em 24/08, −60% em 27/08 de
  manhã, −77% aqui): dividir o palpite por 3, não por 2. E os tokens despencaram porque plano
  com código pronto executa barato — o agente cola e verifica, não projeta.
  **(2) O piso de contagem de testes no gate se pagou ao vivo:** `ctest` sai 0 com
  `Total Tests: 0`. Sem a linha `-ge 3`, o gate lia verde num repo sem um único teste.
  **(3) 186 turnos contra teto de 220 — margem de 15%.** Três fatias por run foi o limite.
- 2026-08-27 · cadeia `/planeja` (5 agentes Sonnet de research + escrita solo Opus dos 9 planos)
  · estimado ~5x / ~50-60 min · real **~705k tok de subagente / ~18 min de research** + a sessão
  de escrita · **VERDE** — 9 planos, lint 0 violações. O research verificado contra os headers
  instalados pagou: 4 armadilhas achadas rodando código (singleton QML silencioso, locale do
  mpv, log do Qt no Fedora, dois yt-dlp) que teriam travado a execução.

- 2026-08-27 · /despacha run headless · fatias 4-6 (`tocador-ui` → `navegacao-biblioteca` →
  `colecoes-tags`, 18 tasks, UI QML + consultas SQL sobre as interfaces das fatias 1-3) · modelo
  Opus 5 · estimado ~150-200k tok novos / 20-40 min · real **~684k tok novos (~33,6M com
  releitura, inflação 49×) / ~0,45 h / 184 turnos** · Δ tokens **+242%**, Δ tempo **dentro da
  faixa** · **PASSOU** — 21 commits, 6/6 alvos de teste. Lição:
  **task não é unidade de custo — dependência é.** As fatias 1-3 (16 tasks, folhas, sem consumir
  interface de ninguém) custaram 138k novos; estas 18 tasks custaram **5×** isso, porque cada uma
  lê o código das anteriores antes de escrever. Ao estimar, contar quantas interfaces alheias a
  fatia consome, não quantas tasks ela tem. O tempo, esse, bateu: ~27 min contra 20-40 previstos.

- 2026-08-27 · /despacha run headless · fatias 7-9 (`podcast-local` → `feed-rss` →
  `download-youtube`, 16 tasks, consumindo `CollectionManager`/`Database`/`AudioEngine`) · modelo
  Opus 5 · estimado ~600-700k tok novos / 25-35 min · real **~872k tok novos (~45,3M com
  releitura, inflação 52×) / ~0,50 h / 228 turnos** · Δ tokens **+30%**, Δ tempo **dentro da
  faixa** · **PASSOU** — 19 commits, 9/9 alvos de teste. Duas lições:
  **(1) A régua da dependência funcionou.** Estimar por "quantas interfaces alheias a fatia
  consome" (lição do run 4-6) errou 30%, contra 242% da estimativa por número de tasks.
  **(2) 228 turnos contra teto de 260 — margem de 12%.** Três fatias consumidoras é o teto real
  de um run; a quarta não caberia.

- 2026-08-27 · /despacha run headless · redesenho fatias 1-2 (`like-faixas` → `moldura-capa`,
  11 tasks) · modelo Opus 5 · estimado ~500-600k tok novos / 30-40 min · real **~497k tok novos
  (~20,95M com releitura, inflação 42×) / ~0,23 h / 140 turnos** · Δ tokens **−1%**, Δ tempo
  **−60%** · **PASSOU** — 15 commits. Lição: **a régua da dependência acertou de novo** — três
  estimativas seguidas por "quantas interfaces alheias a fatia consome" (+30%, −1%) contra
  +242% da estimativa por número de tasks. Está calibrada; use.

- 2026-08-27 · /despacha run headless · redesenho fatias 3-5 (`biblioteca-densa` →
  `busca-overlay` → `podcast-vazio`, 15 tasks + o `--measure`) · modelo Opus 5 · estimado
  ~900k-1,1M tok novos / 45-60 min · real **~1,18M tok novos (~81,7M com releitura, inflação
  69×) / ~0,77 h / 292 turnos** · Δ tokens **+18%**, Δ tempo **dentro da faixa** · **PASSOU**
  — 9 commits. Duas lições:
  **(1) 292 turnos com teto de 300 — margem de 3%.** Três fatias de UI com fidelidade a
  desenho é o teto real de um run; a quarta não caberia.
  **(2) Fidelidade visual vira gate quando o app sabe se medir.** A task do `--measure` +
  `tools/check-layout.sh` custou pouco e transformou "ficou parecido?" em quatro comparações
  numéricas que o portão cobra sozinho.

- 2026-08-29 · /despacha run headless · lote `colecao-playlist` (4 fatias, 11 tasks, QML + C++
  sobre código existente, planos com o código pronto nos steps) · modelo Opus 5 · estimado
  ~250k tok novos / ~25 min · real **~447k tok novos / ~0,97 h / 434 eventos** · Δ tokens
  **+79%**, Δ tempo **+132%** · **PASSOU** — 20 commits, portão 18/18, integrado em `main`.
  Lição, e ela inverte o viés registrado até aqui: **subestimei**. As três calibrações
  anteriores superestimaram tempo (−40%, −60%, −77%) e a regra virada era "dividir o palpite
  por 3" — aplicá-la a um lote com **decisões de gosto** (3 das 4 fatias `decisao-humana: sim`)
  errou para baixo em mais de duas vezes. O que consome não é o número de tasks: é o run parar
  para julgar contra a referência, medir o resultado e refotografar. **Fatia que decide custa o
  dobro de fatia que só executa.**

## Perigos

- [ ] 2026-08-28 · **Renomear o app move a casa inteira do usuário** — todo caminho de dados no
      Qt sai do `applicationName`: banco, capas e preferências trocam de endereço e o app abre
      limpo, sem erro, como se nunca tivesse sido usado. `migrarDoNomeAntigo()` em `main.cpp`
      cobre os três; **não remova**. E o log do Qt aqui vai para o journald: sem
      `QT_FORCE_STDERR_LOGGING=1` você depura no escuro achando que a função nem foi chamada.
      Lição em `docs/solutions/dados/2026-08-28-renomear-o-app-muda-todo-caminho-de-dados.md`.
- [ ] 2026-08-27 · **`qt_add_qml_module` não honra `pragma Singleton`** — sem
      `set_source_files_properties(X.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)` todo acesso
      resolve `undefined`, sem erro de compilação nem de runtime.
- [ ] 2026-08-27 · **Qt 6.10.3: `#` dentro de literal cru (`R"SQL(...)"`) gera arquivo VAZIO** —
      sem erro nenhum. Mordeu nas fatias 1-3; as 6 restantes usam esse formato no SQL.
- [ ] 2026-08-27 · **`mpv_create()` falha sob locale `pt_BR.UTF-8`** — `std::setlocale(LC_NUMERIC, "C")`
      antes dele.
- [ ] 2026-08-27 · **O Fedora silencia `qDebug`/`console.log`** (`/usr/share/qt6/qtlogging.ini`
      manda tudo para o journald). Religar com `QT_LOGGING_RULES="*.debug=true"
QT_FORCE_STDERR_LOGGING=1` — mas o log fica enorme (845 KB num único start).
- [ ] 2026-08-27 · **`target_include_directories(melodarium PRIVATE src)` é obrigatório** — sem
      ele o build morre numa cascata de ~15 erros de template que não apontam a causa.
- [ ] 2026-08-27 · **Há dois `yt-dlp`** — o do PATH é o do Homebrew (2026.01.31), o do Fedora é
      `/usr/bin/yt-dlp` (2026.08.19).
- [ ] 2026-08-27 · **A tela é uma superfície só** (decisão do Pedro, `970904d`) — retângulo com
      margem + borda + canto arredondado preenchendo a janela inteira lê como card flutuando
      dentro de outra tela. Painel interno de conteúdo com borda continua ok.
- [ ] 2026-08-28 · **`pkill -f 'build/melodarium'` mata o próprio comando** que o executa (a
      string casa com a linha de comando do shell, exit 144). Usar `pkill -x melodarium`.
      Confirmado vivo em 2026-08-28: a sessão caiu nele de novo, e levou junto uma tarefa de
      background de OUTRA sessão. O aviso existia e não foi lido — ele só é consultado quando
      o vagão 1 encosta no assunto, e naquele momento o vagão 1 era a tela.

- [ ] 2026-08-28 · **Interface com tamanho fixo vira microscópica em tela grande** — todo
      número nasceu de um desenho de 1100×700. Mexeu em tamanho? passe por `Theme.uiScale`, e
      lembre que altura de linha e largura de coluna precisam do mesmo fator, senão o texto
      cresce e se atropela. Lição em `docs/solutions/ui/`.
- [ ] 2026-08-28 · **`grim` fotografa a REGIÃO da tela, não a janela** — com o app num
      workspace escondido, a captura traz a janela que estiver por cima. Para conferir sem
      mexer nos workspaces do Pedro: `Xvfb :99` + `QT_QPA_PLATFORM=xcb` + `import -window root`.
- [ ] 2026-08-28 · **Arquivo de áudio corrompido não entra na biblioteca e não avisa** — dois
      MP3 vieram truncados do download e a varredura simplesmente os ignorou. `ffprobe` no
      arquivo diz se é o arquivo ou o scanner.

- [ ] 2026-08-28 · **Chamada de método numa ligação QML não cria dependência** — e ler a
      propriedade sem USAR o valor também não (`void X` é eliminado). Componente nasce vazio e
      congela, com build verde e o gate de erros de QML passando. Lição em
      `docs/solutions/ui/2026-08-28-chamada-de-metodo-nao-cria-dependencia-qml.md`.
- [ ] 2026-08-28 · **`ctest` roda o binário que existe, não o código do disco** — depois de um
      teste que não compilou, ele devolve `100% tests passed` do executável anterior. Sempre
      `cmake --build build` antes, e conferir o teste novo com `-functions`. `QSKIP` também sai
      verde. Lição em `docs/solutions/test-failures/`.
- [ ] 2026-08-28 · **`loadfile … replace` REINICIA a faixa que está tocando** — medido: 3,0 s
      viravam 0,7 s. Para reordenar a fila sem interromper, `playlist-move` entrada por entrada.
- [ ] 2026-08-28 · **`cp` do `melodarium.db` copia um banco VAZIO** — o SQLite está em modo WAL e os
      dados vivem no `-wal`. Use `sqlite3 orig ".backup copia"`. Para fotografar com dados de
      teste sem tocar no banco do Pedro: `XDG_DATA_HOME=/tmp/algo`.

- [ ] 2026-08-29 · **O caminho do banco tem DOIS níveis (`<org>/<app>`)** — o real é
      `~/.local/share/melodarium/melodarium/melodarium.db`. Montado com um nível só, aponta
      para um arquivo de 0 byte e o `sqlite3` responde `no such table`, que se lê como "não há
      dados". Em script: `DB="${XDG_DATA_HOME:-$HOME/.local/share}/melodarium/melodarium/melodarium.db"`.
      Custou uma correção nos quatro planos do lote `colecao-playlist` antes do despacho.
- [ ] 2026-08-29 · **Área de toque não tem cor, e nenhum gate de pixel a enxerga** — a alça de
      arrastar nasceu 17 px longe da área que arrastava: o desenho na tela certa, o gesto
      pegando 3 dos 12 px. Os cinco gates verdes. Gesto novo exige prova de EXECUÇÃO (flag de
      medição que dispare o mesmo sinal do gesto), nunca só foto. Lição em
      `docs/solutions/ui/2026-08-29-alca-de-arrastar-fora-da-area-que-arrasta.md`.
- [ ] 2026-08-29 · **Coordenada de sonda de cor é solidária ao layout** — tirar a marca do topo
      do trilho subiu a fileira 38 px, e a sonda de `check-fidelidade.sh` passou a medir o fundo
      da janela. Mexeu em posição? remeça na foto (`--shot` + amostragem por coluna) antes de
      trocar o número no gate.

## Legado (arquivado)

**Ambiente já preparado nesta máquina:** `qt6-qtbase-devel`, `qt6-qtdeclarative-devel`,
`mpv-devel`, `taglib-devel`, `mpvqt-devel`. Mais Qt 6.10.3, cmake 3.31, ninja, gcc 15.3.1,
mpv 0.40, taglib 1.13.1, sqlite 3.53 (FTS5 ativo), yt-dlp, fonte Inter.

**Ordem de execução do lote** (grafo `depende-de:`):

```
esqueleto-build ✓
   ├─ motor-audio ✓ ─────┐
   └─ scan-biblioteca ✓ ─┴─ tocador-ui ✓ ─ navegacao-biblioteca ✓
                                              ├─ colecoes-tags ✓ ─ download-youtube
                                              └─ podcast-local ─ feed-rss
```
