---
slug: menus-da-aplicacao
feature: melodarium
status: em-execucao
depende-de: [tocador-ui]
decisao-humana: sim
spec: docs/plans/2026-09-02-menus-da-aplicacao.md
---

# Menus da aplicação — Implementation Plan

**Goal:** fazer todos os dropdowns do Melodarium usarem a mesma superfície escura, tipografia,
contraste e estados de interação da aplicação, sem perder teclado, checkmarks ou conteúdo
dinâmico.

**Architecture:** criar três controles QML reutilizáveis — `MelodariumMenu`,
`MelodariumMenuItem` e `MelodariumMenuSeparator` — sobre os controles acessíveis do Qt Quick,
forçando renderização dentro da cena com `Popup.Item`. Os sete menus existentes passam a usar
esses controles; um gate estático impede que novos `Menu`, `MenuItem` ou `MenuSeparator` crus
voltem a introduzir a aparência do sistema.

**Tech Stack:** Qt 6/QML, Qt Quick Controls, CMake, Bash, Xvfb, xdotool, ImageMagick e Pillow.

## Restrições

- Usar somente papéis de cor e medidas de `Theme`; nenhum hexadecimal novo nos componentes.
- Preservar navegação por teclado, foco, itens desabilitados, checkmarks e menus dinâmicos.
- Não alterar ações, modelos ou sinais atuais dos menus.
- Não tocar nas mudanças paralelas de `audioengine`, `tests/CMakeLists.txt`, no gate de clique ou
  na nota técnica ainda não commitada.
- Executar build e testes por `quiet-run`, exigir o piso de alvos e rodar os gates contextual,
  órfãos, layout e fidelidade.
- A fatia só fecha depois de Pedro ver pelo menos o menu automático e o menu de velocidade.

## Mapa de arquivos

- `src/MelodariumMenu.qml`: superfície, borda, raio, espaçamento e backend `Popup.Item` comuns.
- `src/MelodariumMenuItem.qml`: texto, hover, foco, estado desabilitado e indicador marcado.
- `src/MelodariumMenuSeparator.qml`: divisor temático usado pelo timer.
- `CMakeLists.txt`: registra os três tipos no módulo `Melodarium.App`.
- `src/FilterChips.qml`: menu automático da biblioteca.
- `src/Main.qml`: menu de adicionar faixa ou lista a uma coleção.
- `src/PodcastPane.qml`: menus OPML e filtro por programa.
- `src/PodcastContextPanel.qml`: menu de retenção de downloads.
- `src/SpeedControl.qml`: menu marcável de velocidade, sem `Popup.Native`.
- `src/SleepControl.qml`: menu do timer com divisor e item marcável.
- `tools/check-contextual-ui.sh`: gate estático global, interação por teclado e rejeição da
  grande superfície branca do menu de sistema.
- `docs/solutions/ui/2026-09-02-popup-native-ignora-estetica-da-aplicacao.md`: registra a
  fronteira entre menu do sistema e menu pintado pelo app.

## Task 1: Unificar e verificar todos os dropdowns

- [x] Alterar primeiro `tools/check-contextual-ui.sh` para exigir `speedmenu=qml`, rejeitar
  controles de menu crus fora dos três componentes e reprovar uma captura com mais de 5.000
  pixels quase brancos; rodar o gate e observar RED com os menus atuais.
- [x] Criar e registrar os três controles temáticos usando `Theme.cRaised`, `Theme.cPill`,
  `Theme.cLine`, `Theme.cTitle`, `Theme.cMuted`, `Theme.uiScale` e `Popup.Item`.
- [x] Migrar os sete `Menu`, todos os `MenuItem` e o `MenuSeparator` existentes sem alterar seus
  modelos, callbacks ou chamadas a `popup()`.
- [x] Construir e rodar o gate contextual até GREEN, incluindo a seleção de `1.5x` pelo teclado.
- [x] Rodar `all_qmllint`, `check-orfaos.sh`, `check-layout.sh`, `check-fidelidade.sh`, piso de
  testes, suíte CTest completa e `git diff --check`.
- [x] Rodar `gitnexus detect_changes`, marcar a task e criar um commit atômico somente com os
  componentes, consumidores, gate e este ledger.

## Task 2: Aprovação visual do Pedro

- [ ] Mostrar capturas reais dos menus automático e de velocidade, confirmando superfície,
  hover/checkmark, espaçamento, contraste e coerência com a tela.
- [ ] Após aprovação explícita, marcar a fatia como `concluido` no mesmo commit do checkbox.

## Verificação

```bash
quiet-run cmake -B build -G Ninja
quiet-run cmake --build build
quiet-run bash tools/check-test-floor.sh 25
quiet-run ctest --test-dir build --output-on-failure
quiet-run cmake --build build --target all_qmllint
quiet-run bash tools/check-contextual-ui.sh
quiet-run bash tools/check-orfaos.sh
quiet-run bash tools/check-layout.sh
quiet-run bash tools/check-fidelidade.sh
quiet-run git diff --check
```
