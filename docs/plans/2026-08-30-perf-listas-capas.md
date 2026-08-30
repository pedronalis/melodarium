---
slug: perf-listas-capas
feature: melodarium
status: em-execucao
depende-de: [perf-startup-leve]
decisao-humana: sim
spec: docs/plans/research/2026-08-29-perf-medicoes.md
---

# Listas e capas leves Implementation Plan

> **Para execução agentic:** executar inline com TDD e fechar somente após comparação visual.

**Goal:** remover I/O invisível dos delegates, reciclar linhas longas e calcular paleta apenas
para a capa principal, preservando exatamente as capas, cantos, cores e placeholders atuais.

**Architecture:** o modelo de faixas entrega apenas dados realmente desenhados; listas usam o
pool nativo do `ListView`; `RoundedImage` separa pintura de análise cromática, que passa a ser
opt-in e feita uma vez por imagem. A evolução assíncrona do cache fica atrás da mesma API QML e
publica revisão quando um arquivo fica pronto.

**Tech Stack:** Qt Quick, `QAbstractListModel`, `QQuickPaintedItem`, Qt Concurrent e Qt Test.

## Constraints globais

- Nenhuma redução de resolução, compressão adicional ou troca de imagem.
- Uma faixa pode ter arte própria diferente do restante do álbum; deduplicação nunca pode
  sobrescrever essa exceção.
- Delegates reciclados devem zerar hover, press, drag e animações temporárias.
- A foto final precisa passar pelos gates de cor e por inspeção humana.

## Mapa de arquivos

- `src/tracklistmodel.*`, `tests/tst_tracklistmodel.cpp`: papéis e atualização incremental.
- `src/*.qml`: `ListView.reuseItems` e limpeza de estado transitório.
- `src/dominantcolor.*`, `src/roundedimage.*`, `src/RoundedCover.qml`,
  `src/NowPlayingPanel.qml`: análise cromática única e opt-in.
- `src/covercache.*`, `tests/tst_covercache.cpp`, `tests/CMakeLists.txt`: extração fora da GUI e
  cache por conteúdo/álbum com fallback por faixa.

## Tasks

### Task 1: Retirar o papel morto e atualizar só duas linhas

- [x] Testar que `roleNames()` não contém `coverUrl` e que trocar `currentPath` emite
  `dataChanged` somente para a linha anterior e a nova.
- [x] Ver os testes falharem, remover `CoverUrlRole` e manter um índice `path → row` reconstruído
  após cada reset do modelo.
- [x] Remover `TrackRow.coverUrl` e os bindings mortos de biblioteca e coleção.
- [x] Rodar `tst_tracklistmodel`, build e órfãos; marcar e commitar com
  `perf(library): remove hidden cover work from track rows`.

### Task 2: Reciclar todos os delegates extensos

- [x] Criar `tools/check-list-reuse.sh` exigindo `reuseItems: true` nas oito `ListView` atuais;
  confirmar vermelho antes da mudança.
- [x] Ativar reciclagem e implementar `ListView.onPooled`/`onReused` apenas onde o delegate tem
  animação ou estado que não deriva integralmente do modelo.
- [x] Exercitar scroll e abertura de fila em banco temporário, depois rodar layout, órfãos e
  fidelidade; marcar e commitar com `perf(qml): recycle long-list delegates`.

### Task 3: Paleta única e opt-in

- [x] Acrescentar `tests/tst_roundedimage.cpp` provando que o opt-in devolve a mesma cor
  dominante e os mesmos spots das APIs atuais.
- [x] Implementar uma única redução 48×48 compartilhada; `RoundedImage.analyzeColors` fica
  `false` por padrão e impede qualquer análise quando desligada.
- [x] Propagar `analyzeColors` por `RoundedCover` e ligá-lo somente nas duas capas do painel
  principal que participam do crossfade.
- [x] Rodar testes, screenshot com halo e fidelidade; marcar e commitar com
  `perf(covers): analyze colors only for the main artwork`.

### Task 4: Cache assíncrono sem duplicação destrutiva

- [x] Criar teste com duas faixas do mesmo álbum e mesma arte, uma faixa com arte exclusiva e
  uma faixa sem arte; provar deduplicação, preservação da exceção e negative cache.
- [x] Mover extração para worker, publicar `revision` no singleton e fazer bindings QML usarem
  essa revisão para atualizar quando o arquivo ficar pronto.
- [x] Armazenar blobs por hash de conteúdo e manter chave de resolução por faixa; migrar
  de forma preguiçosa sem apagar o cache antigo antes de confirmar o novo arquivo.
- [x] Rodar testes, cache frio e gates automatizados; commitar com
  `perf(covers): resolve artwork off the UI thread`.
- [ ] Pedro confirma na tela biblioteca, fila, coleção e painel; então marcar a task e concluir
  a fatia pelo `planos-lote.py`.
