---
slug: ci-e-distribuicao
feature: melodarium
status: em-execucao
depende-de: [erros-acessibilidade-preferencias, fila-timer-e-entrada, podcast-e-portabilidade]
decisao-humana: nao
spec: docs/plans/2026-09-01-ci-e-distribuicao.md
---

# CI e distribuição Implementation Plan

> **Para execução agentic:** executar inline; não publicar release, não abrir PR e não mudar a
> visibilidade do repositório.

**Goal:** transformar o build local em pacote instalável e fazer regressões falharem no GitHub.

**Architecture:** CMake passa a declarar política QML e install layout GNU. Metadados Freedesktop
e manifesto Flatpak consomem o mesmo executável/recursos. CI Fedora reproduz build, piso de testes,
suíte, lint e gates determinísticos; artefatos são anexados ao job, sem publicar release.

**Tech Stack:** CMake/Ninja, Qt 6, GitHub Actions, Fedora container, Flatpak Builder, AppStream.

## Global Constraints

- Repo permanece privado; workflow não faz push, PR, release nem upload externo além do artifact
  privado do próprio run.
- Até decisão de licença do Pedro, metadados usam `LicenseRef-proprietary`; nenhum texto afirma
  que o projeto é open source.
- Fontes Inter/JetBrains Mono precisam ser dependência documentada ou recurso empacotado; não
  depender silenciosamente da máquina do desenvolvedor.
- CI exige piso de testes, não apenas exit 0 do CTest.

## File Map

- Modify: `CMakeLists.txt`, `tests/CMakeLists.txt` — QTP0004, install e targets de qualidade.
- Create: `data/io.github.pedronalis.melodarium.desktop`,
  `data/io.github.pedronalis.melodarium.metainfo.xml`,
  `data/icons/hicolor/scalable/apps/io.github.pedronalis.melodarium.svg` — integração desktop.
- Create: `packaging/io.github.pedronalis.melodarium.yml` — Flatpak local.
- Create: `.github/workflows/ci.yml`, `tools/check-test-floor.sh`, `tools/check-package.sh` — CI.
- Modify: `README.md` — dependências completas, instalação, testes, Flatpak e limites.

---

### Task 1: CMake e metadados instaláveis

- [x] Criar gate RED que executa `cmake --install` em prefixo temporário e exige binário, desktop,
  AppStream e ícone nos caminhos GNU corretos.
- [x] Definir QTP0004 explicitamente, `GNUInstallDirs`, install rules e IDs consistentes; validar
  desktop/AppStream com as ferramentas oficiais.
- [x] Rodar build/test/gate e commitar com `build: add freedesktop install metadata`.

### Task 2: Flatpak reproduzível

- [x] Criar manifesto com runtime KDE/Qt compatível, módulos libmpv/taglib e permissões mínimas
  para áudio, Wayland/X11 fallback, D-Bus MPRIS, rede e portal de arquivos.
- [ ] Rodar `flatpak-builder --force-clean` em diretório temporário e `tools/check-package.sh`
  para abrir `--scan` sob XDG isolado; registrar limitações do yt-dlp externo.
- [x] Commitar com `build(flatpak): package the local player`.

### Task 3: CI com pisos honestos

- [x] Criar workflow Fedora que instala dependências, configura, compila, exige `Total Tests >= 22`,
  roda CTest, `all_qmllint`, órfãos e gates headless determinísticos.
- [x] Adicionar cache apenas de downloads/build seguro; anexar logs/capturas quando um gate falhar.
- [x] Validar YAML localmente e executar os mesmos comandos em container; commitar com
  `ci: enforce build tests lint and ui gates`.

### Task 4: Documentação e gate final do lote

- [ ] Corrigir dependências Fedora (`mpv-libs-devel`, `taglib-devel`, DBus/playerctl e fontes),
  documentar install/Flatpak, dados/backup e controles novos.
- [ ] Rodar build limpo, piso, suíte, lint, todos os gates e validação de pacote.
- [ ] Rodar `gitnexus detect-changes`, concluir plano; não publicar nem mudar visibilidade.

## Diagnóstico Flatpak local — 2026-09-01

- `flatpak-builder --force-clean /tmp/melodarium-flatpak-build ...` não inicia porque o host não
  tem `flatpak-builder`; também faltam `org.kde.Sdk//6.9` e `org.flatpak.Builder`.
- O runtime já instalado `org.kde.Platform//6.9` foi inspecionado sem alteração. O manifesto fixa
  libass, libplacebo, libmpv 0.41.0 e TagLib 2.3.1 por tag e commit.
- `tools/check-package.sh` instala em prefixo temporário, valida desktop/AppStream/ícone, valida o
  contrato YAML e executa `melodarium --scan` com todos os XDG isolados. Essas etapas passam; o
  gate termina vermelho de propósito ao constatar a ausência do builder/SDK.
- O Flatpak não empacota `yt-dlp`: RSS e URLs de mídia diretas continuam suportadas, mas downloads
  que dependam do executável externo ficam indisponíveis dentro do sandbox até ele ser empacotado.
