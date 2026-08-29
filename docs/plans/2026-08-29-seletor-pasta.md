---
slug: seletor-pasta
feature: seletor-pasta
status: concluido
depende-de: []
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: seletor-pasta

**Goal:** Escolher pasta deixa de abrir o diálogo do sistema (portal GTK no Wayland, com a cara
de outro programa) e passa a abrir um explorador do próprio melodarium, com a paleta do app e
com os HDs montados numa coluna de locais.

**Arquitetura:** Um modelo em C++ (`FolderBrowser`, `QAbstractListModel`) lista as SUBPASTAS do
caminho atual e expõe três listas prontas para a tela: `crumbs` (o caminho fatiado em pedaços
clicáveis), `places` (Home, Música, Downloads) e `volumes` (os pontos de montagem reais, via
`QStorageInfo`, com o lixo de pseudo-sistema-de-arquivos filtrado). A contagem de músicas por
subpasta NÃO roda na thread da interface: um `QtConcurrent::run` por geração devolve os números
depois, porque a pasta que motivou a feature mora num HD externo e uma leitura fria de 200
diretórios congelaria a janela no meio do clique. A tela (`FolderPickerDialog.qml`) é um `Popup`
igual aos outros diálogos do app e é instanciada nos TRÊS lugares que hoje pedem pasta.

**Constraints globais:** cor sai da escada de papéis do `Theme` (`cRowAlt`, `cPill`, `cTitle`,
…), nunca de hex solto nem das 16 chaves do tema do sistema
(`docs/solutions/ui/2026-08-28-a-tela-passava-nos-gates-e-nao-era-o-desenho.md`). Todo tamanho
passa por `Theme.uiScale` (`docs/solutions/ui/2026-08-28-interface-microscopica-em-tela-grande.md`).
Ler propriedade sem usar o valor não cria dependência em QML
(`docs/solutions/ui/2026-08-28-chamada-de-metodo-nao-cria-dependencia-qml.md`): a lista de
subpastas é um modelo de verdade, não uma função chamada uma vez.

**Decisões do Pedro (2026-08-29):** substituir nos três lugares · barra lateral de locais e
discos · com campo de caminho colável, contagem de músicas por pasta, botão de pastas ocultas
e criação de pasta nova.

## Arquivos

- Criar: `src/folderbrowser.h`, `src/folderbrowser.cpp`, `src/FolderPickerDialog.qml`,
  `tests/tst_folderbrowser.cpp`
- Modificar: `src/libraryscanner.h`, `src/libraryscanner.cpp` (a lista de extensões de áudio
  vira pública, para não existir uma segunda lista divergindo em silêncio), `src/Icons.qml`,
  `src/SettingsDialog.qml`, `src/EmptyPane.qml`, `src/PodcastPane.qml`, `src/Main.qml`,
  `CMakeLists.txt`, `tests/CMakeLists.txt`, `tools/check-fidelidade.sh`
- Testar: `ctest` (`tst_folderbrowser`), `tools/check-orfaos.sh`, `tools/check-fidelidade.sh`,
  foto em `docs/telas/`

## Interfaces

- Produz para o QML: `FolderBrowser` (`QML_ELEMENT`, instanciável, um por diálogo) com
  `path`, `showHidden`, `parentPath`, `readable`, `crumbs`, `places`, `volumes`,
  os papéis `name`/`path`/`audioCount`/`readable`, e
  `enter(int)`, `goUp()`, `refresh()`, `createFolder(string) -> bool`,
  `resolveInput(string) -> string`.
- Produz para as telas: `FolderPickerDialog` com `title`, `startPath`, `signal folderChosen(string)`
  e `function abrirEm(string)`.
- Consome: `LibraryScanner::audioSuffixes()`.

## Tasks

### Task 1: A lista de extensões de áudio deixa de ser privada do scanner

- [x] Em `src/libraryscanner.h`, declarar `static const QStringList &audioSuffixes();`
- [x] Em `src/libraryscanner.cpp`, tirar a função do namespace anônimo e qualificá-la

### Task 2: O modelo `FolderBrowser`

- [x] `src/folderbrowser.h` / `src/folderbrowser.cpp`
- [x] Volumes por `QStorageInfo`, com blacklist de pseudo-FS e de pontos de montagem de sistema
- [x] Contagem de áudio assíncrona, com geração para descartar resultado velho

### Task 3: Testes do modelo

- [x] `tests/tst_folderbrowser.cpp` + alvo em `tests/CMakeLists.txt`

### Task 4: A tela

- [x] Glifos novos em `src/Icons.qml`
- [x] `src/FolderPickerDialog.qml` com barra lateral, migalhas, lista, rodapé e teclado

### Task 5: Os três lugares que pedem pasta

- [x] `src/SettingsDialog.qml`, `src/EmptyPane.qml`, `src/PodcastPane.qml` — `FolderDialog` sai
- [x] `import QtQuick.Dialogs` sai dos três; `Qt6::QuickDialogs2` sai do `CMakeLists.txt`

### Task 6: Portões

- [x] `--open-folder-picker` em `src/Main.qml`, foto em `docs/telas/`
- [x] Pontos de cor da tela nova em `tools/check-fidelidade.sh`
- [x] `ctest`, `check-orfaos.sh`, `check-fidelidade.sh` verdes

## Decisão humana

**Aprovada na tela pelo Pedro em 2026-08-29**, com o seletor aberto no app compilado — o
frontmatter pede `decisao-humana: sim`, e a foto do gate não fecha esse item: quem clica é ele.
