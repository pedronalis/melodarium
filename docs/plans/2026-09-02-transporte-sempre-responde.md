---
slug: transporte-sempre-responde
feature: melodarium
status: concluido
depende-de: [motor-audio]
decisao-humana: nao
spec: docs/plans/2026-09-02-transporte-sempre-responde.md
---

# Transporte sempre responde — Implementation Plan

**Goal:** fazer anterior e próxima executarem uma troca observável em qualquer posição da fila,
inclusive no primeiro item, no último item e em filas unitárias.

**Architecture:** manter a fila no `AudioEngine` como fonte da ordem e trocar o comando `weak`,
que o mpv define como inerte nas bordas, por seleção circular explícita do índice. O QML e o MPRIS
continuam chamando a mesma API pública.

**Tech Stack:** C++20, Qt 6 Core/Qml, libmpv, Qt Test e CTest.

## Restrições

- Preservar a semântica de repetição e shuffle já existente.
- Não recarregar a fila nem reconstruir a playlist para trocar de faixa.
- Provar o comportamento contra libmpv real, com áudio headless.
- Clicar nos controles reais do mini-player sobre XDG temporário.
- Rodar todo build/teste por `quiet-run` e exigir o piso de testes.

## Task 1: Tornar o transporte circular e verificável

- [x] Acrescentar regressões para próxima no fim, anterior no começo e ida/volta manual.
- [x] Rodar o alvo atual e observar RED especificamente nas duas bordas.
- [x] Implementar a menor mudança em `AudioEngine::next` e `AudioEngine::previous`.
- [x] Rodar o alvo até GREEN e a suíte completa com piso de descoberta.
- [x] Rodar clique real, gates de órfãos/QML, `git diff --check` e `gitnexus detect_changes`.
- [x] Registrar a lição durável, concluir o plano e commitar código, testes e ledger juntos.

## Verificação

```bash
quiet-run cmake -B build -G Ninja
quiet-run cmake --build build
quiet-run tools/check-test-floor.sh 25
quiet-run ctest --test-dir build --output-on-failure
quiet-run bash tools/check-transport-controls.sh
quiet-run bash tools/check-orfaos.sh
quiet-run cmake --build build --target all_qmllint
quiet-run git diff --check
```
