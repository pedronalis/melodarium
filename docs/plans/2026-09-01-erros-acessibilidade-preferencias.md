---
slug: erros-acessibilidade-preferencias
feature: melodarium
status: em-execucao
depende-de: [confiabilidade-playback-banco]
decisao-humana: sim
spec: docs/plans/2026-09-01-erros-acessibilidade-preferencias.md
---

# Erros, acessibilidade e preferências Implementation Plan

> **Para execução agentic:** executar inline com TDD e gate Qt/QML completo; só fechar após Pedro
> validar contraste, foco e movimento na tela real.

**Goal:** tornar falhas acionáveis e o player operável por teclado/leitor de tela, com redução de
movimento e alto contraste persistidos.

**Architecture:** `Main.qml` agrega eventos de backend em uma fila de avisos; um banner acessível
mostra erro/progresso e ações. Controles reutilizáveis ganham semântica e foco primeiro, telas
herdam o padrão, e `Theme` deriva cores/movimento de preferências persistidas.

**Tech Stack:** Qt Quick/QML, Qt Quick Controls, Accessible attached properties, QSettings,
Qt Test e scripts de interação/captura.

## Global Constraints

- Texto normal mantém contraste mínimo 4.5:1; texto grande/ícones essenciais, 3:1.
- Movimento reduzido desliga animações contínuas e encurta transições sem remover feedback.
- Erros de banco, scan, playback, feed e download nunca ficam apenas em console/journald.
- Cores usam papéis de `Theme`; dimensões usam `Theme.uiScale`.

## File Map

- Create: `src/NoticeCenter.qml`, `src/StatusBanner.qml` — fila, severidade e ações.
- Modify: `src/Main.qml` — conexões de erro/progresso e shortcuts globais.
- Modify: `src/IconButton.qml`, `src/MelodariumButton.qml`, `src/TrackRow.qml`,
  `src/EpisodeRow.qml`, `src/IconRail.qml`, `src/QueueOverlay.qml` — foco/semântica.
- Modify: `src/SettingsDialog.qml`, `src/Theme.qml`, `src/AmbientGlow.qml` — preferências visuais.
- Modify: demais QML apontados por `all_qmllint` — qualificações e propriedades do Loader.
- Create: `tools/check-accessibility.sh`, `tools/check-notices.sh` — gates estáticos/runtime.
- Modify: `CMakeLists.txt`, `tests/CMakeLists.txt`, `tools/check-fidelidade.sh` — registro.

---

### Task 1: Avisos e progresso visíveis

- [x] Criar gate RED que injeta `scanFailed`, `playbackError`, `feedCheckFailed` e
  `downloadFailed`, exigindo mensagem, origem, ação de fechar/tentar novamente e progresso do scan.
- [x] Implementar fila limitada e deduplicada, `StatusBanner` com `Accessible.role/status`, foco
  quando erro fatal e Connections para todos os sinais de backend.
- [x] Rodar gate e suíte; commitar com `feat(ui): surface backend errors and progress`.

### Task 2: Teclado e semântica acessível

- [x] Criar gate RED que enumera controles interativos sem `Accessible.name`, exercita Tab,
  Espaço/Enter, Escape, Ctrl+K e teclas de mídia sem mouse.
- [x] Corrigir componentes base e depois consumidores: role/name/description, `activeFocusOnTab`,
  estados de foco visíveis e teclas equivalentes a cada MouseArea.
- [x] Rodar o gate em offscreen e a superfície real Wayland; commitar com
  `feat(a11y): make playback surfaces keyboard accessible`.

### Task 3: Contraste, alto contraste e movimento reduzido

- [ ] Criar medição RED das combinações texto/fundo e prova de persistência das duas preferências.
- [ ] Ajustar `cFaint`, `cDim`, `cMuted` onde representam texto; criar papéis decorativos separados
  quando baixo contraste for intencional; persistir `ui/reduceMotion` e `ui/highContrast`.
- [ ] Condicionar halo/transições/animators à preferência, atualizar capturas e rodar fidelidade.
- [ ] Commmitar com `feat(a11y): add contrast and reduced motion preferences`.

### Task 4: Limpar o contrato QML

- [ ] Capturar a lista atual de 34 warnings de `all_qmllint` e transformar o piso em zero warnings.
- [ ] Qualificar 22 acessos, tipar/guardar os 11 `Loader.item` e resolver o posicionamento restante
  sem suprimir diagnósticos globalmente.
- [ ] Fortalecer `check-orfaos.sh` para distinguir métodos homônimos por tipo e remover reservas
  somente quando as respectivas UIs existirem.
- [ ] Rodar lint, órfãos, contextual, layout e fidelidade; commitar com
  `chore(qml): enforce warning-free reachable interfaces`.

### Task 5: Gate humano

- [ ] Pedro percorre Biblioteca, Podcast, Coleções, Fila e Preferências apenas por teclado, lê os
  avisos, compara contraste normal/alto e confirma movimento reduzido.
- [ ] Rodar `gitnexus detect-changes`, concluir o plano e commitar o ledger.
