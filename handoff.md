# Handoff — melodarium

> Atualizado: 2026-08-28 16:35 · branch: `main` · via /fecho · contexto: ~47% consumido

## Estado

- **A tela voltou a ser o desenho aprovado.** O Pedro abriu e reprovou: cor fora, sem degradê,
  capa de canto vivo, badge de tag errado. Causa raiz: o app consumia as 16 chaves do tema do
  sistema, e o desenho usa **14 cinzas com papéis distintos** — quatro fundos de estado
  colapsavam num só. `Theme` ganhou a escada por PAPEL; 10 pontos de cor batem no hex.
- **Capa arredondada existe de verdade.** `radius` + `clip` NÃO recorta imagem no QML: a
  moldura estava no código e a arte por cima seguia quadrada, em todas as capas. `RoundedImage`
  (QQuickPaintedItem) resolve num caminho que sobrevive ao adaptador de software — `MultiEffect`
  não sobrevive, e some a capa inteira.
- **O projeto se chama `melodarium`** (escolhido pelo Pedro no /batiza). Repo, pasta, binário,
  módulo QML, textos e documentos renomeados. `~/dev/active/melodarium`, `./build/melodarium`.
- **A migração de dados foi a parte perigosa e está verificada:** banco, capas e preferências
  mudam de endereço com o nome, e o app abriria limpo como se nunca tivesse sido usado.
  27 faixas, 4 álbuns, 17 capas e a pasta de música atravessaram.
- **O som sai — medido, não suposto.** Num canal de áudio isolado, o app entrega 13× o nível do
  silêncio, com a forma do arquivo. Falta só o ouvido do Pedro.

## Alvo

- **Frente:** melodarium — player de música local com a estética do Noctalia
- **Plano-fonte:** `docs/specs/2026-08-27-player-musica-podcast.md` — 9 fatias do produto +
  5 do redesenho `melodia-capa-manda`, todas `concluido` (14/14)
- **PRONTA quando:** as fatias concluídas **e** o Pedro ouvindo o som sair ao clicar numa faixa
- **Restante:** só o julgamento do Pedro na tela dele — o som já foi medido saindo (13× o
  ruído) e a cor conferida contra o desenho (10/10 pontos). Nenhum código pendente.
- **Correção de rumo (Pedro, 2026-08-28):** "Despacha e me traz pronto, é isso que eu
  quero" — gates de conferência visual passaram a ser meus, não dele.
- **Correção de rumo (Pedro, 2026-08-28, tarde):** "o visual ainda está feio, não está fiel as
  cores do artifact desenhado, não está com degrades, não está com as capas com bordas
  arredondadas, o badge de criar tag está diferente" — gate de geometria passa verde com a
  paleta inteira errada; desde então todo redesenho roda `tools/check-fidelidade.sh`.

## Fila da sessão

1. **[S · IMPASSE · bloqueado em ação humana]** O que falta é um minuto do Pedro, e nomeando:
   rodar `./build/melodarium`, clicar numa faixa, e dizer se sai som e se a tela agora é o
   desenho. Eu já medi as duas coisas por instrumento; o que falta é julgamento, que não tem
   como ser meu. — 3ª fila desde 2026-08-27. · done: ele responde
2. **[S · 3ª desde 2026-08-27]** Ouvir e aprovar a tela — **bloqueado pelo vagão 1** ·
   done: o Pedro confirma o som e o visual
3. **[S]** Abrir o repo ao público, como o spec pede — nada trava mais, o nome saiu do /batiza ·
   done: `gh repo view --json visibility` diz `PUBLIC`

## Estacionamento (derivas)

- [x] 2026-08-28 · Nome definitivo do projeto — RESOLVIDO: **melodarium**, escolhido pelo Pedro
      no `/batiza`. O anterior era "melodia" (genérico, 930 repos no GitHub); "melodarium" tem
      namespace virgem em GitHub, npm, PyPI, crates e Homebrew. Código, dados, documentos, repo
      e pasta renomeados no mesmo dia. Era o último item entre o repo fechado e o aberto que o
      spec pede.
- [ ] 2026-08-27 · Bit-perfect real depende do grafo do PipeWire (`default.clock.rate`), não só
      das opções do mpv. O plano documenta o limite; medir de verdade exige um FLAC 96 kHz e uma
      sonda no ponto ALSA.
- [x] 2026-08-28 · O `melodia.db` de 0 byte solto em `~/.local/share/melodia/` — APAGADO. A
      renomeação isolou o arquivo (a migração levou só a pasta interna, que era a de verdade), e
      aí ficou claro que era lixo: 0 byte, do nome que não existe mais. A origem segue não
      identificada; se um `melodarium.db` de 0 byte reaparecer solto em
      `~/.local/share/melodarium/`, a causa é viva e vale investigar.

## Em voo

Nada em voo. O lote `melodia-religa` (7 fatias) foi **colhido e calibrado em 2026-08-28** —
desfecho na `## Calibração de custo`. O worktree `~/dev/active/melodia-religa-run` continua no
disco (branch `exec/melodia-religa`, já integrada em `main`); o vínculo dele com o repo foi
reparado depois da renomeação da pasta, e ele pode ser removido quando o Pedro quiser.

Seis peças de motor prontas seguem em **reserva declarada**, impressas pelo `check-orfaos.sh` a
cada execução: desinscrever de podcast, "continuar ouvindo", reordenar dentro de uma coleção,
entre outras. Esperam decisão sobre merecerem tela.

- 2026-08-28 · /despacha run headless · lote `melodia-religa` (7 fatias) · modelo Opus 5 ·
  estimado n/d · real **~850k tok novos (~63,90M com releitura, inflação 75×) / ~0,56 h /
  336 turnos** · **PASSOU** — 7 fatias `concluido`, integradas em `main`. Lição: o run de lote
  custou **6,2× os tokens novos** do run de fatias 1-3 (138k) para 2,3× o número de turnos —
  fatia que RELIGA código existente lê muito mais do que fatia que escreve do zero.

## Verificação

- `ctest --test-dir build --output-on-failure` → `100% tests passed, 0 out of 9` · 2026-08-28 16:35
- `bash tools/check-layout.sh` → 11 medidas ok · 2026-08-28 16:35
- `bash tools/check-orfaos.sh` → `0 item(ns) sem porta de entrada`, mais 6 em reserva
  declarada · 2026-08-28 16:35
- `bash tools/check-fidelidade.sh` → 10 pontos de cor ok contra o desenho · 2026-08-28 16:35
- erros de QML em tela virtual, nas 6 telas → 0 · 2026-08-28 16:35
- `./build/melodarium --scan` → acha a pasta e reporta `0 novas` contra o banco migrado · 2026-08-28
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
