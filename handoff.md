# Handoff — melodarium

> Atualizado: 2026-09-01 · branch: `wip/2026-08-31-ui-contextual-fecho` · lote longo inline

## Estado

- O lote mecânico dos planos de performance, refresh/background, erros/acessibilidade,
  fila/timer/drop e podcast/portabilidade está implementado e commitado.
- HEAD antes deste handoff: `42b46b4` (`docs: document installation data and controls`).
- `docs/plans/2026-09-01-ci-e-distribuicao.md` está `travado`: 16/17 linhas do RUN_GATE passam;
  falta apenas o builder/SDK Flatpak externo para a prova `flatpak-builder --force-clean`.
- `docs/plans/2026-09-01-refresh-e-trabalho-background.md` está `concluido`. Os planos com
  `decisao-humana: sim` continuam `em-execucao`, com checkboxes visuais intactos.
- Repo continua privado. Não houve push, PR, release, publicação ou mudança de visibilidade.
- Dados/config/cache reais do usuário não foram alterados; provas destrutivas usaram XDG/tmp.

## Commits do lote

- Performance/refresh: `20ef673`, `47f8619`, `e2e0893`, `30c26b4`, `fdd06a4`, `cebc6d0`,
  `b200bd5`.
- Erros/acessibilidade/QML: `8fd3469`, `a8c70c4`, `7174817`, `2cb736d`.
- Fila/timer/entrada: `5d700aa`, `7ccd607`, `11349af`, `10aadf4`.
- Podcast/portabilidade: `3b4b11a`, `db21194`, `2e9d537`, `113d8f2`.
- Distribuição/CI/docs: `269e404`, `40dca7a`, `31fc283`, `42b46b4`.

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
- O manifesto fixa KDE/Qt 6.9, libass, libplacebo, libmpv 0.41.0 e TagLib 2.3.1. Metadados do
  projeto permanecem `LicenseRef-proprietary`; `metadata_license` do AppStream é `FSFAP`, como o
  validador oficial exige para o próprio XML.
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
- RUN_GATE PASS: configure, build, piso, CTest, `all_qmllint`, contextual, órfãos, layout,
  fidelidade, list reuse, acessibilidade, notices, queue editing, drop, portabilidade e
  `git diff --check`.
- RUN_GATE FAIL: `tools/check-package.sh` termina em `FLATPAK_BUILDER_MISSING`; antes disso passam
  install tree, desktop/AppStream/ícone, manifesto YAML e `melodarium --scan` com XDG isolado.
- GitNexus `detect_changes` foi executado antes de cada commit; os últimos commits tiveram risco
  baixo e zero fluxos afetados.

## Gates humanos ainda abertos

- `2026-08-30-perf-render-fila`: Pedro valida o halo em reprodução na tela.
- `2026-09-01-erros-acessibilidade-preferencias`: percurso só por teclado, avisos, contraste e
  movimento reduzido.
- `2026-09-01-fila-timer-e-entrada`: reordenar fila tocando, timer e drops reais.
- `2026-09-01-podcast-e-portabilidade`: OPML, M3U e backup/restore sobre XDG descartável.
- Também continuam abertos os gates visuais anteriores de `contexto-podcast`,
  `contexto-colecoes` e `mini-player-completo`.

## Próxima ação única

- Com autorização para instalar dependências Flatpak, instalar `flatpak-builder` e
  `org.kde.Sdk//6.9`, rodar:
  `flatpak-builder --force-clean /tmp/melodarium-flatpak-build packaging/io.github.pedronalis.melodarium.yml`;
  depois repetir `tools/check-package.sh`, atualizar o plano de CI e concluir a fatia.

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
