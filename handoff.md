# Handoff — melodia

> Atualizado: 2026-08-27 15:54 · branch: `main` · via /fecho · contexto: ~27% consumido

## Estado

- **As 9 fatias estão concluídas e integradas em `main`.** Suíte de 9 alvos, 100% passando na
  `main` depois do último merge. O código do lote acabou.
- O app sobe com tudo: abas Música/Podcast, busca, barra lateral (coleções, artistas, álbuns,
  gêneros, tags, listas automáticas), fila, editor de tags, barra de transporte, assinatura de
  feed RSS e download do YouTube.
- A janela tem o **OK visual do Pedro** (fatia 1), com o ajuste da moldura (`970904d`).
- **Faltam os dois gates humanos** — som ao clicar numa faixa (fatia 4) e a mesma faixa em duas
  coleções (fatia 6). Nenhum foi conferido: os runs são cegos e não há pasta de música apontada.
  Há MP3s em `/media/Backup HD/Torrents/` para o teste.
- Worktrees de execução removidos; as branches `exec/fatias-*` continuam no repo, já mergeadas.

## Alvo

- **Frente:** melodia — player de música local com a estética do Noctalia
- **Plano-fonte:** `docs/specs/2026-08-27-player-musica-podcast.md` — decomposto no lote de
  9 planos de fatia em `docs/plans/` (**9/9 concluídas**)
- **PRONTA quando:** as 9 fatias com `status: concluido` **e** os três gates humanos confirmados
  na tela: a janela com a cara certa (✓ 27/08), o som saindo ao clicar numa faixa, a mesma faixa
  em duas coleções com um clique
- **Restante:** só os dois gates humanos das fatias 4 e 6 — nenhum código pendente

## Fila da sessão

1. **[S]** Os dois gates humanos, que fecham a frente: apontar uma pasta de música (há MP3s em
   `/media/Backup HD/Torrents/`), clicar numa faixa e ouvir; depois jogar a mesma faixa em duas
   coleções · done: som saindo e a faixa nas duas coleções · `./build/appmelodia`
2. **[S]** Passar o nome pelo `/batiza` antes de publicar — "melodia" é provisório e o spec manda
   (item do Estacionamento, agora que o app existe) · done: nome decidido e registrado
3. **[M]** Publicar o repo no GitHub, como o spec pede ("aberto, sem instalador nem suporte") ·
   done: `git remote -v` com o remoto e `git push` feito

## Estacionamento (derivas)

- [ ] 2026-08-27 · Publicar o repo no GitHub (spec pede "aberto, sem instalador nem suporte") —
      fora dos planos de propósito: é ação manual, não código. Fazer quando o app existir.
- [ ] 2026-08-27 · Nome definitivo do projeto: "melodia" é provisório, o spec manda passar no
      `/batiza`. Trocar antes de publicar custa menos que depois.
- [ ] 2026-08-27 · Bit-perfect real depende do grafo do PipeWire (`default.clock.rate`), não só
      das opções do mpv. O plano documenta o limite; medir de verdade exige um FLAC 96 kHz e uma
      sonda no ponto ALSA.
- [ ] 2026-08-27 · Sobrou um `melodia.db` de 0 byte em `~/.local/share/melodia/` (o banco de
      verdade é `~/.local/share/melodia/melodia/melodia.db`). Sem efeito observável, origem não
      identificada — os testes usam pasta temporária. Apagar se não voltar.

## Em voo

**Tipo 1 — run headless · redesenho, fatias 3-5** (`biblioteca-densa` → `busca-overlay` →
`podcast-vazio`, 15 tasks + a task do `--measure`) · despachado **2026-08-27 19:30** · cwd:
`/home/pedro/dev/active/.melodia-worktrees/redesign-3-5` (branch `exec/redesign-3-5`)
· estimado ~900k-1,1M tok novos / ~45-60 min / teto 300 turnos · gate de 19 linhas
· **vigia armado**.

conferir: RUN_GATE ausente = verde · `.run_gate_count` presente = FAIL (ver `RESUMO_RUN.md`/transcript)
· RUN_GATE presente sem count = em voo

**O Pedro dispensou os gates humanos intermediários** (27/08, verbatim: "Despacha e me traz
pronto, é isso que eu quero"). A conferência visual passou a ser MINHA: rodar o app numa tela
virtual (`Xvfb :99` + `import -window root`, validado nesta sessão — não mexe nos workspaces
dele), comparar com as telas de `design/*.dc.html`, corrigir o que estiver diferente, e só
então entregar. As fatias `moldura-capa` e `podcast-vazio` continuam com `decisao-humana: sim`
no frontmatter, mas o gate é meu até ele pedir o contrário.

O run das fatias 1-2 foi colhido: **PASSOU** — 15 commits, integrado em `main`.

## Verificação

- `cmake -B build -G Ninja && cmake --build build` → exit 0 · 2026-08-27 15:54 (na `main`, pós-merge)
- `ctest --test-dir build --output-on-failure` → `100% tests passed, 0 tests failed out of 9` ·
  2026-08-27 15:54
- Os três runs do lote fecharam verdes; nenhum gate ficou armado no disco.

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

## Perigos

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
- [ ] 2026-08-27 · **`target_include_directories(appmelodia PRIVATE src)` é obrigatório** — sem
      ele o build morre numa cascata de ~15 erros de template que não apontam a causa.
- [ ] 2026-08-27 · **Há dois `yt-dlp`** — o do PATH é o do Homebrew (2026.01.31), o do Fedora é
      `/usr/bin/yt-dlp` (2026.08.19).
- [ ] 2026-08-27 · **A tela é uma superfície só** (decisão do Pedro, `970904d`) — retângulo com
      margem + borda + canto arredondado preenchendo a janela inteira lê como card flutuando
      dentro de outra tela. Painel interno de conteúdo com borda continua ok.
- [ ] 2026-08-27 · **`pkill -f 'build/appmelodia'` mata o próprio comando** que o executa (a
      string casa com a linha de comando do shell, exit 144). Usar `pkill -x appmelodia`.

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
