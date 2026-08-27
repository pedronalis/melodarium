# handoff — melodia

**Atualizado:** 2026-08-27 · **Branch:** `main` · **Último commit:** `22ffff4`

## Onde está

Lote de **9 planos de fatia aprovado** em `docs/plans/`, todos com `status: aprovado`.
**Zero código de aplicação ainda** — o repo tem só o spec, os planos e o research.

Ordem de execução pelo grafo `depende-de:`:

```
esqueleto-build
   ├─ motor-audio ──────┐
   └─ scan-biblioteca ──┴─ tocador-ui ─ navegacao-biblioteca
                                            ├─ colecoes-tags ─ download-youtube
                                            └─ podcast-local ─ feed-rss
```

`motor-audio` e `scan-biblioteca` rodam em paralelo; `colecoes-tags` e `podcast-local` também.

Três fatias têm `decisao-humana: sim` e precisam do Pedro olhando a tela para serem dadas por
concluídas: **esqueleto-build** (a janela abre com a cara certa), **tocador-ui** (o som sai
clicando numa faixa), **colecoes-tags** (a mesma faixa em duas coleções, com um clique).

## Em voo

**Tipo 1 — run headless · fatias 4-6** (`tocador-ui` → `navegacao-biblioteca` → `colecoes-tags`,
18 tasks) · despachado 2026-08-27 14:45 · cwd do run:
`/home/pedro/dev/active/.melodia-worktrees/fatias-4-6` (branch `exec/fatias-4-6`, saída de `main`)
· estimado ~150-200k tok novos / ~20-40 min / teto 260 turnos.

conferir: RUN_GATE ausente = verde · `.run_gate_count` presente = FAIL (ver `RESUMO_RUN.md`/transcript)
· RUN_GATE presente sem count = em voo

Duas dessas fatias têm `decisao-humana: sim` e foram para o headless mesmo assim, por decisão do
Pedro ("despacha o restante e deixa trabalhar"): a conferência na tela (som saindo ao clicar numa
faixa; a mesma faixa em duas coleções) fica pendente para a colheita.

O run das fatias 1-3 foi colhido: **PASSOU** — e integrado em `main` (fast-forward, 20 commits).
A janela recebeu o OK visual do Pedro em 27/08, com um ajuste: a tela era um card com moldura
dentro da janela; virou superfície única (`970904d`).

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

## Próximo passo

**Ação humana pendente:** rodar `./build/appmelodia` numa sessão gráfica e confirmar que a
janela abre com a cara certa (`esqueleto-build` tem `decisao-humana: sim`; o run não tinha tela).

Depois: fatia `tocador-ui` — as fatias 2 e 3 de que ela depende já estão prontas. Ela também
pede o seu olho na tela.

Os 19 commits estão na branch `exec/fatias-1-3`, **não integrada em `main`** — o merge é decisão
sua. `RESUMO_RUN.md` na raiz lista 8 divergências que o run corrigiu, entre elas um bug de perda
de dados (arquivo movido sumia da biblioteca) e uma armadilha nova do Qt 6.10.3: `#` dentro de
literal cru (`R"SQL(...)"`) faz o gerador de código produzir arquivo VAZIO, sem erro — vale para
as 6 fatias restantes, que usam esse formato no SQL.

**Atualize o `status:` no frontmatter ao executar — o plano é o ledger.**
Os `- [ ]` das tasks são a outra metade: trocar por `- [x]` no mesmo commit do trabalho.

## Ambiente já preparado

Instalado nesta máquina: `qt6-qtbase-devel`, `qt6-qtdeclarative-devel`, `mpv-devel`,
`taglib-devel`, `mpvqt-devel`. Mais Qt 6.10.3, cmake 3.31, ninja, gcc 15.3.1, mpv 0.40,
taglib 1.13.1, sqlite 3.53 (FTS5 ativo), yt-dlp, fonte Inter.

## Armadilhas medidas ao vivo (já dentro dos planos — não redescobrir)

- `qt_add_qml_module` **não** honra `pragma Singleton`. Sem
  `set_source_files_properties(X.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)` o qmldir registra
  o arquivo como tipo comum e todo acesso resolve `undefined` — sem erro de compilação nem de
  runtime.
- `mpv_create()` falha sob locale `pt_BR.UTF-8`. `std::setlocale(LC_NUMERIC, "C")` antes dele.
- O Fedora instala `/usr/share/qt6/qtlogging.ini` com `*.debug=false` e manda o resto para o
  journald: `qDebug`/`console.log` somem. Religar com
  `QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1`.
- `target_include_directories(appmelodia PRIVATE src)` é obrigatório: sem ele o build morre
  numa cascata de ~15 erros de template que não apontam a causa.
- Há **dois `yt-dlp`**: o do PATH é o do Homebrew (2026.01.31), o do Fedora é `/usr/bin/yt-dlp`
  (2026.08.19).

## Estacionamento

- [ ] 2026-08-27 · Publicar o repo no GitHub (spec pede "aberto, sem instalador nem suporte") —
      fora dos planos de propósito: é ação manual, não código. Fazer quando o app existir.
- [ ] 2026-08-27 · Nome definitivo do projeto: "melodia" é provisório, o spec manda passar no
      `/batiza`. Trocar antes de publicar custa menos que depois.
- [ ] 2026-08-27 · Bit-perfect real depende do grafo do PipeWire (`default.clock.rate`), não só
      das opções do mpv. O plano documenta o limite; medir de verdade exige um FLAC 96 kHz e uma
      sonda no ponto ALSA.
