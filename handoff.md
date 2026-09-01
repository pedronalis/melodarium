# Handoff — melodarium

> Atualizado: 2026-09-01 · branch: `wip/2026-08-31-ui-contextual-fecho` · lote longo colhido

## Estado

- O lote mecânico dos planos de performance, refresh/background, erros/acessibilidade,
  fila/timer/drop, podcast/portabilidade e CI/distribuição está implementado e commitado.
- HEAD de entrada desta colheita: `e6dc9b4` (`docs: record batch verification and blockers`).
- `docs/plans/2026-09-01-ci-e-distribuicao.md` está `concluido`: construção Flatpak limpa e
  RUN_GATE 17/17 passaram.
- `docs/plans/2026-09-01-refresh-e-trabalho-background.md` está `concluido`. Os planos com
  `decisao-humana: sim` continuam `em-execucao`, com checkboxes visuais intactos.
- Repo continua privado. Não houve push, PR, release, publicação ou mudança de visibilidade.
- Dados/config/cache reais do Melodarium não foram alterados; provas destrutivas usaram XDG/tmp.
  Com autorização, o SDK KDE 6.9 entrou no Flatpak do usuário e sete pacotes de build oficiais
  foram instalados no Fedora.

## Commits do lote

- Performance/refresh: `20ef673`, `47f8619`, `e2e0893`, `30c26b4`, `fdd06a4`, `cebc6d0`,
  `b200bd5`.
- Erros/acessibilidade/QML: `8fd3469`, `a8c70c4`, `7174817`, `2cb736d`.
- Fila/timer/entrada: `5d700aa`, `7ccd607`, `11349af`, `10aadf4`.
- Podcast/portabilidade: `3b4b11a`, `db21194`, `2e9d537`, `113d8f2`.
- Distribuição/CI/docs: `269e404`, `40dca7a`, `31fc283`, `42b46b4`, `e6dc9b4` e o commit de
  fechamento Flatpak desta colheita.

## Arquivos e decisões centrais

- Motor/dados: `src/audioengine.{h,cpp}`, `src/database.{h,cpp}`, `src/librarywatcher.{h,cpp}`,
  `src/libraryscanner.cpp`, `src/podcastlibrary.{h,cpp}`, `src/portabilityservice.{h,cpp}`,
  `src/droprouter.{h,cpp}` e `src/folderbrowser.cpp`.
- UI: fila editável, `SleepControl.qml`, `DropOverlay.qml`, avisos, acessibilidade, preferências,
  políticas de podcast, OPML/M3U e `BackupRestoreDialog.qml`; cores continuam vindo de `Theme` e
  dimensões continuam respeitando `Theme.uiScale`.
- Testes/gates: 35 alvos em `tests/`; novos gates de piso, fila, drop, portabilidade, pacote,
  acessibilidade e avisos em `tools/`; gates visuais existentes preservados.
- Empacotamento: QTP0004 explícito, GNU install layout, desktop/AppStream/ícone, manifesto
  `packaging/io.github.pedronalis.melodarium.yml` e CI Fedora em `.github/workflows/ci.yml`.
- O manifesto fixa KDE/Qt 6.9, libass, libplacebo, libmpv 0.41.0 e TagLib 2.3.1. O módulo mpv
  explicita `plain-gl` para sobreviver a `auto_features=disabled`; o gate de pacote protege esse
  contrato. Metadados do projeto permanecem `LicenseRef-proprietary`; `metadata_license` do
  AppStream é `FSFAP`, como o validador oficial exige para o próprio XML.
- O Flatpak atual não empacota `yt-dlp`; downloads dependentes desse executável ficam limitados.
  RSS e URLs de mídia direta continuam cobertos pela rede do sandbox.
- `migrarDoNomeAntigo()` foi preservado. Migrações publicadas não foram reescritas.

## Verificação final

- Build limpo: `quiet-run cmake -B build -G Ninja` PASS; `quiet-run cmake --build build` PASS,
  279 passos. Build anterior preservado em `/tmp/melodarium-build-backup.NIJf3B/build`.
- Piso: `tools/check-test-floor.sh 25` PASS, `Total Tests: 35`.
- CTest limpo: 35/35 PASS, 0 falhas, 118,63 s.
- Fedora 43 descartável: configuração/build PASS, 35/35 PASS (121,85 s), qmllint e todos os
  gates determinísticos PASS. O snapshot veio de `git archive`, então o `git diff --check` foi
  validado no worktree real.
- Flatpak limpo: `flatpak-builder --user --force-clean` PASS; os quatro módulos externos e o app
  compilaram, AppStream compôs e desktop/ícone/metainfo foram exportados.
- RUN_GATE 17/17 PASS depois da correção: configure, build, piso 35/25, CTest 35/35 em 121 s,
  `all_qmllint`, contextual, órfãos, layout, fidelidade, list reuse, acessibilidade, notices,
  queue editing, drop, portabilidade, pacote e `git diff --check`.

## Gates humanos ainda abertos

- `2026-08-30-perf-render-fila`: Pedro valida o halo em reprodução na tela.
- `2026-09-01-erros-acessibilidade-preferencias`: percurso só por teclado, avisos, contraste e
  movimento reduzido.
- `2026-09-01-fila-timer-e-entrada`: reordenar fila tocando, timer e drops reais.
- `2026-09-01-podcast-e-portabilidade`: OPML, M3U e backup/restore sobre XDG descartável.
- Também continuam abertos os gates visuais anteriores de `contexto-podcast`,
  `contexto-colecoes` e `mini-player-completo`.

## Próxima ação única

- Abrir o app para Pedro validar na tela o halo em reprodução; isso fecha o gate humano mais
  antigo, `2026-08-30-perf-render-fila`, antes dos demais percursos manuais.

## Perigos

- Não remover `migrarDoNomeAntigo()` de `main.cpp`; ele ainda protege dados criados sob o nome
  antigo `melodia`.
- Nunca usar `pkill -f 'build/melodarium'`: ele casa com o próprio shell e pode matar trabalho
  alheio. Fechar janela pelo PID exato.
- Sempre compilar antes do `ctest` e exigir o piso; `ctest` pode sair 0 com `Total Tests: 0`.
- Todo redesenho QML precisa passar contextual, órfãos, layout e fidelidade; geometria verde não
  prova cor correta.
- Cores de tela vêm de `Theme` pelos nomes de papel (`cRowAlt`, `cPill`, `cTitle`, …), e toda
  dimensão visual deve respeitar `Theme.uiScale`.
- Não copiar/restaurar o banco real à mão; usar o bundle verificado e XDG temporário em provas.
