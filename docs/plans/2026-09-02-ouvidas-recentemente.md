---
slug: ouvidas-recentemente
feature: melodarium
status: concluido
depende-de: [navegacao-biblioteca]
decisao-humana: nao
spec: docs/plans/2026-09-02-ouvidas-recentemente.md
---

# Ouvidas recentemente — Implementation Plan

**Goal:** oferecer uma lista automática local das faixas já ouvidas, ordenada pela reprodução
mais recente, sem criar uma nova tela ou acrescentar informação visual às linhas.

**Architecture:** expor no `LibraryBrowser` uma cláusula SQL apoiada em
`track_stats.last_played_at`, consumida pela rota genérica de filtros do `Main.qml`. O item entra
no menu existente de coleções automáticas e continua usando `TrackListModel`, `LibraryPane` e
`TrackRow` sem layout próprio.

**Tech Stack:** C++20, Qt 6 Core/Sql/Qml, Qt Quick Controls, Qt Test e CTest.

## Restrições

- Manter todo o histórico no banco local existente; não criar migração nem telemetria.
- Exibir cada faixa no máximo uma vez e excluir faixas nunca reproduzidas ou removidas.
- Ordenar por `track_stats.last_played_at DESC` e limitar pela capacidade já adotada nas listas
  automáticas.
- Reaproveitar a lista e o menu existentes, sem nova aba, painel, metadado de linha ou cor.
- Preservar as mudanças paralelas atualmente presentes em `audioengine` e em seus testes.
- Rodar build/testes somente por `quiet-run`, provar o piso de descoberta e executar os gates
  QML relevantes.

## Mapa de arquivos

- `src/librarybrowser.h`: declara a nova consulta invocável pelo QML.
- `src/librarybrowser.cpp`: define seleção, exclusão e ordenação das faixas ouvidas.
- `tests/tst_librarybrowser.cpp`: prova o contrato da consulta com o banco real de teste.
- `src/FilterChips.qml`: acrescenta a entrada no menu automático existente.
- `src/Main.qml`: traduz a chave do filtro para título e consulta.

## Task 1: Ligar a lista automática de ouvidas recentemente

- [x] Escrever os testes `recentlyPlayedExcludesNeverPlayedTracks` e
  `recentlyPlayedUsesLastPlaybackOrder`, compilá-los e observar RED pela ausência de
  `LibraryBrowser::clauseRecentlyPlayed()`.
- [x] Implementar `clauseRecentlyPlayed()` com `last_played_at IS NOT NULL`, ordenação decrescente
  e `kAutoListLimit`; recompilar e observar os dois testes em GREEN.
- [x] Adicionar a chave `recentlyPlayed` ao menu `automaticas`, ao estado selecionado, a
  `filterTitles` e ao `clauseFor()` do shell QML.
- [x] Construir o app, provar a contagem de testes e rodar a suíte completa sem falhas.
- [x] Rodar `all_qmllint`, `check-orfaos.sh`, `check-fidelidade.sh`, uma captura isolada da lista
  e `git diff --check`; conferir que o item é alcançável e usa a lista atual.
- [x] Rodar `gitnexus detect_changes`, marcar esta task e a fatia como concluídas e criar um
  commit atômico contendo somente os arquivos da feature e o ledger.

## Verificação

```bash
quiet-run cmake -B build -G Ninja
quiet-run cmake --build build
quiet-run bash tools/check-test-floor.sh 25
quiet-run ctest --test-dir build --output-on-failure
quiet-run cmake --build build --target all_qmllint
quiet-run bash tools/check-orfaos.sh
quiet-run bash tools/check-fidelidade.sh
quiet-run git diff --check
```
