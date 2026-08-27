# Handoff — melodia

> Atualizado: 2026-08-27 14:46 · branch: `main` · via /fecho · contexto: ~15% consumido

## Estado

- As três primeiras fatias (esqueleto, motor de áudio, varredura da biblioteca) estão prontas,
  testadas e **integradas em `main`** (fast-forward de 20 commits).
- A janela recebeu o **OK visual do Pedro**, com um ajuste: a tela era um card com moldura dentro
  da janela e virou superfície única (`970904d`). O gate humano da fatia 1 está fechado.
- A paleta lida é a real do usuário (`~/.config/noctalia/colors.json`), não o fallback de fábrica
  — conferido pelas cores na captura: cinza sobre preto, não o azul/amarelo do padrão.
- **Run das fatias 4-6 em voo** (tocador → navegação → coleções), num worktree isolado.
- Suíte: 3 alvos, 20 casos, 100% passando em 2026-08-27 14:46.

## Alvo

- **Frente:** melodia — player de música local com a estética do Noctalia
- **Plano-fonte:** `docs/plans/` — lote de 9 fatias (3/9 concluídas, 3 em execução, 3 aprovadas)
- **PRONTA quando:** as 9 fatias com `status: concluido` **e** os três gates humanos confirmados
  na tela: a janela com a cara certa (✓ 27/08), o som saindo ao clicar numa faixa, a mesma faixa
  em duas coleções com um clique
- **Restante:** 6 fatias — `tocador-ui`, `navegacao-biblioteca`, `colecoes-tags` (no run em voo);
  `podcast-local`, `download-youtube`, `feed-rss` (aprovadas, não despachadas)

## Fila da sessão

1. **[S]** Colher o run das fatias 4-6 e integrar `exec/fatias-4-6` em `main` se vier verde ·
   done: `ls /home/pedro/dev/active/.melodia-worktrees/fatias-4-6/RUN_GATE` → ausente = passou
2. **[S]** Os dois gates humanos que o run deixa pendentes: clicar numa faixa e sair som; a mesma
   faixa em duas coleções — **bloqueado pelo vagão 1** · done: `./build/appmelodia` numa sessão
   gráfica, com uma pasta de música apontada
3. **[M]** Despachar as 3 fatias finais (`podcast-local` → `feed-rss`, e `download-youtube`) ·
   done: `RUN_GATE` armado no cwd do run novo e sessão headless viva

## Estacionamento (derivas)

- [ ] 2026-08-27 · Publicar o repo no GitHub (spec pede "aberto, sem instalador nem suporte") —
      fora dos planos de propósito: é ação manual, não código. Fazer quando o app existir.
- [ ] 2026-08-27 · Nome definitivo do projeto: "melodia" é provisório, o spec manda passar no
      `/batiza`. Trocar antes de publicar custa menos que depois.
- [ ] 2026-08-27 · Bit-perfect real depende do grafo do PipeWire (`default.clock.rate`), não só
      das opções do mpv. O plano documenta o limite; medir de verdade exige um FLAC 96 kHz e uma
      sonda no ponto ALSA.

## Em voo

**Tipo 1 — run headless · fatias 4-6** (`tocador-ui` → `navegacao-biblioteca` → `colecoes-tags`,
18 tasks) · despachado **2026-08-27 14:45** · cwd do run:
`/home/pedro/dev/active/.melodia-worktrees/fatias-4-6` (branch `exec/fatias-4-6`, saída de `main`)
· estimado ~150-200k tok novos / ~20-40 min / teto 260 turnos · gate de 9 linhas, com piso de
6 alvos de teste.

conferir: RUN_GATE ausente = verde · `.run_gate_count` presente = FAIL (ver `RESUMO_RUN.md`/transcript)
· RUN_GATE presente sem count = em voo

Duas dessas fatias têm `decisao-humana: sim` e foram para o headless mesmo assim, por decisão do
Pedro ("despacha o restante e deixa trabalhar"): a conferência na tela fica pendente para a
colheita (é o vagão 2 da fila).

## Verificação

- `cmake -B build -G Ninja && cmake --build build` → exit 0 · 2026-08-27 14:36
- `ctest --test-dir build --output-on-failure` → `100% tests passed, 0 tests failed out of 3` ·
  2026-08-27 14:46
- Gate do run em voo: 9 linhas em `.melodia-worktrees/fatias-4-6/RUN_GATE`

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
   └─ scan-biblioteca ✓ ─┴─ tocador-ui ─ navegacao-biblioteca
                                            ├─ colecoes-tags ─ download-youtube
                                            └─ podcast-local ─ feed-rss
```
