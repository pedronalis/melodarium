---
slug: perf-render-fila
feature: melodarium
status: aprovado
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
- `src/roundedimage.*`, `tests/tst_roundedimage.cpp`: debounce de decode no resize.
- `src/audioengine.*`, `tests/tst_audioengine.cpp`: carga e reorder escaláveis.
- `docs/solutions/perf/`: medição final e decisões que sobreviverão à sessão.

## Tasks

### Task 1: Halo ativo somente quando visível e tocando

- [ ] Acrescentar `active` ao `AmbientGlow` e uma prova de execução no harness de medição.
- [ ] Ver a prova falhar; condicionar a animação a `active && !Theme.reduzirMovimento`, mantendo
  o último frame quando inativa.
- [ ] Passar `AudioEngine.playing` e exposição da janela desde o painel; medir parado, pausado,
  oculto e tocando por 20 s.
- [ ] Comparar screenshot tocando, marcar e commitar com
  `perf(render): suspend the halo when it cannot animate`.

### Task 2: Decode estável durante resize

- [ ] Criar teste de `RoundedImage` que conte uma única atualização após uma rajada de mudanças
  de geometria e nenhuma perda do pixmap enquanto o timer está pendente.
- [ ] Implementar debounce curto para upgrades de resolução, mantendo escala da imagem atual e
  fazendo decode final na dimensão exata.
- [ ] Exercitar resize real em Wayland e comparar screenshots antes/depois; marcar e commitar
  com `perf(covers): debounce artwork decoding during resize`.

### Task 3: Carga e shuffle escaláveis

- [ ] Criar teste puro para filas com caminhos duplicados e teste de integração com centenas de
  entradas; registrar duração e provar que a faixa corrente não reinicia.
- [ ] Trocar carga inicial por uma única playlist M3U temporária validada pelo mpv ou por lote
  equivalente; manter `appendToQueue()` sem autoplay.
- [ ] Pré-computar movimentos do shuffle sem `QStringList::indexOf` repetido, preservando cada
  ocorrência duplicada e usando apenas `playlist-move` durante reprodução.
- [ ] Rodar todos os testes de áudio com zero skips, medir fila grande, marcar a task e commitar
  com `perf(audio): scale playlist loading and reordering`.

### Task 4: Gate final e lição durável

- [ ] Rodar build, contagem de testes, `ctest`, órfãos, layout e fidelidade.
- [ ] Medir startup frio/quente, CPU parado/pausado/tocando, PSS e frame time de scroll com o
  mesmo banco e geometria das medições de 29/08.
- [ ] Registrar números, comandos, decisões e limites em `docs/solutions/perf/`, concluir a
  fatia pelo `planos-lote.py` e commitar apenas os arquivos da task.

