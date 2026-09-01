---
slug: fila-timer-e-entrada
feature: melodarium
status: em-execucao
depende-de: [confiabilidade-playback-banco, perf-render-fila]
decisao-humana: sim
spec: docs/plans/2026-09-01-fila-timer-e-entrada.md
---

# Fila editável, timer e entrada por arrastar Implementation Plan

> **Para execução agentic:** executar inline com TDD e testes reais de libmpv/DropArea.

**Goal:** permitir organizar a reprodução corrente, programar parada e importar mídia por
arrastar/soltar sem reiniciar a faixa ativa.

**Architecture:** `AudioEngine` mantém uma identidade por ocorrência da fila e aplica operações
mpv incrementais. O timer vive no motor para sobreviver a trocas de tela. Um `DropRouter` puro
classifica URLs/arquivos/pastas e o QML apenas apresenta confirmação e feedback.

**Tech Stack:** C++20, libmpv client API, Qt Core/Qml/Quick, QTimer e Qt Test.

## Global Constraints

- Remover/mover itens não reinicia a faixa corrente e preserva duplicatas corretamente.
- Limpar fila mantém a faixa tocando como única entrada até ela terminar ou o usuário parar.
- “Parar após esta” dispara exatamente uma vez no EOF; timer é cancelável e mostra restante.
- Drop de pasta respeita formatos do scanner; URL de feed, mídia e YouTube seguem fluxos já
  existentes e nunca iniciam download sem confirmação.

## File Map

- Modify: `src/audioengine.h`, `src/audioengine.cpp`, `tests/tst_audioengine.cpp` — operações/timer.
- Modify: `src/QueueOverlay.qml`, `src/QueueStrip.qml`, `src/NextUpCard.qml`, `src/Main.qml` — UI.
- Create: `src/droprouter.h`, `src/droprouter.cpp`, `tests/tst_droprouter.cpp` — classificação.
- Create: `src/DropOverlay.qml`, `tools/check-queue-editing.sh`, `tools/check-drop.sh` — interação.
- Modify: `CMakeLists.txt`, `tests/CMakeLists.txt`, `src/Icons.qml` — registro/ícones.

---

### Task 1: Operações incrementais de fila

- [x] Escrever testes RED com duplicatas para `playNext(path)`, `removeQueueItem(index)`,
  `moveQueueItem(from,to)` e `clearUpcoming()`, verificando fila, índice, arquivo e posição.
- [x] Implementar usando `playlist-insert`, `playlist-remove` e `playlist-move`; atualizar espelho,
  sessão e shuffle original de forma atômica.
- [x] Rodar teste de centenas de entradas e gate real; commitar com
  `feat(queue): edit playback order without restarting`.

### Task 2: Fila operável na tela

- [ ] Criar gate RED para “tocar a seguir”, remover, mover por botões/teclado e limpar restantes.
- [ ] Implementar ações no overlay, estados de foco/Accessible e confirmação somente para limpar.
- [ ] Rodar órfãos, interação, layout e fidelidade; commitar com
  `feat(queue): expose complete queue controls`.

### Task 3: Sleep timer e parar após atual

- [ ] Escrever testes RED com relógio curto para cancelamento, expiração, EOF único e troca de faixa.
- [ ] Expor `sleepRemainingSeconds`, `sleepActive`, `stopAfterCurrent` e métodos de configuração;
  persistir apenas `stopAfterCurrent` durante a sessão, nunca timer absoluto entre processos.
- [ ] Adicionar menu ao player/mini-player e provar ações; commitar com
  `feat(playback): add sleep timer and stop-after-current`.

### Task 4: Drag and drop

- [ ] Escrever matriz RED para arquivo suportado/não suportado, pasta, feed HTTP(S), link YouTube e
  URL local; rejeitar esquemas perigosos ou desconhecidos.
- [ ] Implementar `DropRouter`, `DropArea` na janela e overlay que mostra a ação antes do drop;
  encaminhar pasta ao scan, feed à assinatura, YouTube ao diálogo e arquivos à fila.
- [ ] Rodar testes/gate real e commitar com `feat(import): route dropped media and links`.

### Task 5: Gate humano

- [ ] Pedro reordena uma fila tocando, agenda/cancela timer e solta arquivo/pasta/feed na janela.
- [ ] Rodar suíte e gates QML completos, `gitnexus detect-changes`, concluir o plano e ledger.
