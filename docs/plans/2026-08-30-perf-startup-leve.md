---
slug: perf-startup-leve
feature: melodarium
status: em-execucao
depende-de: []
decisao-humana: nao
spec: docs/plans/research/2026-08-29-perf-medicoes.md
---

# Startup leve Implementation Plan

> **Para execução agentic:** execução inline nesta sessão, com `test-driven-development`,
> `systematic-debugging`, `qt-qml-visual-verification` e `verification-before-completion`.

**Goal:** retirar do startup processos bloqueantes, varreduras de pasta prematuras e páginas
secundárias invisíveis, sem mudar pixels nem o momento em que uma ação pedida pelo usuário fica
disponível.

**Architecture:** o startup mantém apenas a biblioteca ou o estado vazio necessário para o
primeiro frame. Processos externos passam a responder por sinais; `FolderBrowser` só toca o
filesystem quando o seletor abre; páginas e ajustes secundários são criados por `Loader` na
primeira visita e preservados até o fim da sessão.

**Tech Stack:** Qt 6.10, QML, `QProcess`, `QAbstractListModel`, CMake/Ninja e Qt Test.

## Constraints globais

- Não alterar qualidade de áudio, capas, paleta, geometria ou animação.
- Não remover `migrarDoNomeAntigo()` nem mudar caminhos de dados.
- Cada teste novo precisa ser visto falhando antes da implementação.
- Sempre construir antes do `ctest`; nenhum `QSKIP` conta como prova.
- Componente QML modificado precisa passar por `check-orfaos.sh`, `check-layout.sh` e
  `check-fidelidade.sh`.
- Alterações locais preexistentes em `AGENTS.md`, `CLAUDE.md` e `.claude/` não entram nos commits.

---

## Mapa de arquivos

- `src/ytdlpdownloader.h/.cpp`: ciclo de vida do probe externo e propriedades mostradas na UI.
- `tests/tst_ytdlp.cpp`: prova de retorno não bloqueante e resultado assíncrono do probe.
- `src/folderbrowser.h/.cpp`: modelo de diretórios e início explícito da primeira enumeração.
- `tests/tst_folderbrowser.cpp`: contrato de construção sem I/O e carregamento sob demanda.
- `src/FolderPickerDialog.qml`: chama a inicialização do modelo quando o popup realmente abre.
- `src/Main.qml`: loaders das páginas secundárias, ajustes e seletor usado apenas por gates.

## Tasks

### Task 1: Probe assíncrono do yt-dlp

**Files:**
- Modify: `tests/tst_ytdlp.cpp`
- Modify: `src/ytdlpdownloader.h`
- Modify: `src/ytdlpdownloader.cpp`

**Interfaces:**
- Consumes: `YtDlpDownloader::probe()`, `available`, `toolVersion`, `availabilityChanged()`.
- Produces: `probe()` retorna sem esperar pelo processo; no máximo um probe fica ativo; o sinal
  entrega sucesso, ausência, erro ou timeout de cinco segundos.

- [x] **Step 1: escrever o teste vermelho `probeReturnsBeforeTheToolFinishes`**
  Criar um executável temporário `yt-dlp` que espera um segundo e imprime `test-version`,
  antepor seu diretório ao `PATH`, chamar `probe()` e exigir retorno abaixo de 100 ms.
- [x] **Step 2: comprovar o vermelho**
  Rodar `quiet-run cmake --build build` e
  `quiet-run ./build/tests/tst_ytdlp probeReturnsBeforeTheToolFinishes -v1`.
  Esperado: falha no limite de tempo com a implementação bloqueante atual.
- [x] **Step 3: implementar o ciclo assíncrono mínimo**
  Manter um `QProcess` filho no downloader, conectar `finished`/`errorOccurred`, aplicar timeout
  por `QTimer` e publicar o resultado uma única vez por execução.
- [x] **Step 4: comprovar o verde**
  Repetir o teste por nome; esperado: `1 passed, 0 failed, 0 skipped` para essa função.
- [x] **Step 5: checkpoint**
  Marcar esta task no plano e commitar apenas plano, teste e `ytdlpdownloader.*` com
  `perf(startup): make yt-dlp probe asynchronous`.

### Task 2: FolderBrowser sem varredura no construtor

**Files:**
- Modify: `tests/tst_folderbrowser.cpp`
- Modify: `src/folderbrowser.h`
- Modify: `src/folderbrowser.cpp`
- Modify: `src/FolderPickerDialog.qml`

**Interfaces:**
- Produces: `bool loaded() const` e `Q_INVOKABLE void ensureLoaded()`; `setPath()` e `refresh()`
  continuam carregando imediatamente quando chamados explicitamente.

- [x] **Step 1: escrever o teste vermelho `constructionDefersDirectoryEnumeration`**
  Exigir `!loaded()` e modelo vazio logo após construir; após `ensureLoaded()`, exigir `loaded()`.
- [x] **Step 2: comprovar o vermelho**
  Construir e rodar a função por nome; esperado: falha porque o construtor enumera `$HOME`.
- [x] **Step 3: implementar o carregamento explícito**
  Preservar o caminho inicial como home, retirar `refresh()` do construtor, marcar o modelo como
  carregado em `refresh()` e chamar `ensureLoaded()` em `FolderPickerDialog.onOpened`.
- [x] **Step 4: comprovar o verde e a navegação existente**
  Rodar todo `tst_folderbrowser`; esperado: todos passam sem skips.
- [x] **Step 5: checkpoint**
  Marcar esta task e commitar com `perf(startup): defer folder enumeration until picker opens`.

### Task 3: Diálogos de topo sob demanda

**Files:**
- Modify: `src/Main.qml`

**Interfaces:**
- Produces: `openSettings()` e `openMeasureFolderPicker(path)` criam loaders síncronos na
  primeira chamada e abrem o mesmo componente no mesmo evento.

- [ ] **Step 1: criar uma validação vermelha estrutural**
  Rodar um `rg` que exige `SettingsDialog` e o seletor de gate dentro de `Loader` e confirmar que
  a árvore atual reprova; registrar o comando no fim desta task.
- [ ] **Step 2: implementar os loaders**
  Trocar as instâncias de topo por loaders inativos; manter `onLibraryPathPicked`; adaptar o rail
  e as flags `--open-settings`/`--open-folder-picker` às funções de abertura.
- [ ] **Step 3: provar os dois caminhos reais**
  Rodar `--measure --open-settings --no-search` e
  `--measure --open-folder-picker / --no-search`, exigindo zero erros QML e uma linha `MEDIDA`.
- [ ] **Step 4: rodar os gates visuais do repo**
  `quiet-run bash tools/check-orfaos.sh`, `quiet-run bash tools/check-layout.sh` e
  `quiet-run bash tools/check-fidelidade.sh` devem sair 0.
- [ ] **Step 5: checkpoint**
  Marcar esta task e commitar com `perf(startup): instantiate top-level dialogs on demand`.

### Task 4: Páginas secundárias sob demanda

**Files:**
- Modify: `src/Main.qml`

**Interfaces:**
- Produces: loaders persistentes para `PodcastPane`, `EmptyPane` e `CollectionsPane`; as funções
  de navegação garantem a criação antes de chamar métodos no item carregado.

- [ ] **Step 1: registrar a validação vermelha**
  Confirmar que as três páginas aparecem como filhos diretos do `StackLayout` atual.
- [ ] **Step 2: implementar loaders persistentes**
  A biblioteca continua direta; cada página secundária é ativada antes de mudar `section` ou
  pela flag de medição correspondente. Ajustar acessos a `CollectionsPane` para `loader.item`.
- [ ] **Step 3: provar navegação e harness**
  Rodar `--measure --pane library|podcast|empty|collections --no-search`; cada execução deve
  produzir `MEDIDA` sem `ReferenceError`, `TypeError`, `unavailable` ou `Cannot assign`.
- [ ] **Step 4: gates completos da fatia**
  Configurar, construir, confirmar `ctest -N` com pelo menos 11 testes, rodar `ctest`, órfãos,
  layout e fidelidade.
- [ ] **Step 5: checkpoint e status**
  Marcar a task, mudar o frontmatter para `concluido` pelo `planos-lote.py` e commitar com
  `perf(startup): lazy-load secondary panes`.

## Verificação final da fatia

```bash
quiet-run cmake -B build -G Ninja
quiet-run cmake --build build
quiet-run ctest --test-dir build -N
quiet-run ctest --test-dir build --output-on-failure
quiet-run bash tools/check-orfaos.sh
quiet-run bash tools/check-layout.sh
quiet-run bash tools/check-fidelidade.sh
```
