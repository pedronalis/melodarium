---
slug: perf-render-fila
feature: melodarium
status: em-execucao
depende-de: [perf-listas-capas]
decisao-humana: sim
spec: docs/plans/research/2026-08-29-perf-medicoes.md
---

# Renderização e fila leves Implementation Plan

> **Para execução agentic:** executar inline com TDD; movimento e áudio exigem prova real.

**Goal:** zerar renderização quando o halo não pode ser visto, evitar redecodificação contínua
no resize e retirar o crescimento quadrático da fila sem reiniciar a faixa ou perder gapless.

**Architecture:** atividade visual passa a depender de reprodução e exposição da janela;
`RoundedImage` mantém a textura corrente durante resize e agenda uma atualização exata ao fim;
playlist e shuffle usam operações em lote ou plano de movimentos pré-computado, mantendo a
playlist interna do mpv como autoridade sonora.

**Tech Stack:** Qt Quick Scene Graph, QML Animator, `QQuickPaintedItem`, libmpv e Qt Test.

## Constraints globais

- Halo em reprodução visível mantém cores, amplitude e suavidade aprovadas.
- Pausar ou ocultar congela o halo; não o apaga.
- `loadfile replace` não pode ser usado para reordenar uma fila tocando.
- Gapless, ReplayGain e posição corrente não podem regredir.

## Mapa de arquivos

- `src/AmbientGlow.qml`, `src/NowPlayingPanel.qml`, `src/Main.qml`: atividade do halo.
- `src/CoverShadow.qml`, `src/RoundedCover.qml`, `src/NowPlayingPanel.qml`: uma sombra exata,
  compartilhada e estabilizada fora do crossfade.
- `src/gradientblock.*`, `tests/tst_gradientblock.cpp`: manter o raster pronto durante resize e
  reconstruir tamanho/raio exatos no fim.
- `src/roundedimage.*`, `tests/tst_roundedimage.cpp`: debounce de decode no resize.
- `src/audioengine.*`, `tests/tst_audioengine.cpp`: carga e reorder escaláveis.
- `docs/solutions/perf/`: medição final e decisões que sobreviverão à sessão.

## Tasks

### Task 1: Halo ativo somente quando visível e tocando

- [x] Acrescentar `active` ao `AmbientGlow` e uma prova de execução no harness de medição.
- [x] Ver a prova falhar; condicionar a animação a `active && !Theme.reduzirMovimento`, mantendo
  o último frame quando inativa.
- [x] Passar `AudioEngine.playing` e exposição da janela desde o painel; medir parado, pausado,
  oculto e tocando por 20 s.
- [x] Comparar screenshot tocando, marcar e commitar com
  `perf(render): suspend the halo when it cannot animate`.

### Task 2: Raster e decode estáveis durante resize

- [x] Perfilar a rajada horizontal e identificar `qt_image_boxblur` em 4/4 amostras do thread
  da interface; congelar screenshots de referência em 1100×700 e 1800×1300.
- [x] Criar `tools/check-resize-shadow.sh`, ver o gate falhar e compartilhar uma única sombra
  exata fora das duas capas do crossfade, com debounce dos parâmetros rasterizados.
- [x] Criar `tst_gradientblock`, ver a rajada de geometria+raio falhar e manter o degradê pronto
  escalado até reconstruir o raster exato no fim.
- [x] Ampliar `tst_roundedimage`, ver o teste falhar e manter a arte carregada até fazer um
  único decode exato depois da rajada.
- [x] Exercitar resize real em Wayland e comparar screenshots antes/depois; marcar e commitar
  com `perf(covers): debounce artwork decoding during resize`.

### Task 3: Carga e shuffle escaláveis

- [x] Criar teste puro para filas com caminhos duplicados e teste de integração com centenas de
  entradas; registrar duração e provar que a faixa corrente não reinicia.
- [x] Trocar carga inicial por uma única playlist M3U temporária validada pelo mpv ou por lote
  equivalente; manter `appendToQueue()` sem autoplay.
- [x] Pré-computar movimentos do shuffle sem `QStringList::indexOf` repetido, preservando cada
  ocorrência duplicada e usando apenas `playlist-move` durante reprodução.
- [x] Rodar todos os testes de áudio com zero skips, medir fila grande, marcar a task e commitar
  com `perf(audio): scale playlist loading and reordering`.

### Task 4: Gate final e lição durável

- [x] Rodar build, contagem de testes, `ctest`, órfãos, layout e fidelidade.
- [x] Medir startup frio/quente, CPU parado/pausado/tocando, PSS e frame time de scroll com o
  mesmo banco e geometria das medições de 29/08.
- [x] Registrar números, comandos, decisões e limites em `docs/solutions/perf/` e commitar
  apenas os arquivos da task.
- [ ] Após Pedro validar o halo em reprodução na tela, concluir a fatia pelo `planos-lote.py`.
