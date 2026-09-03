---
slug: github-publico
feature: melodarium
status: em-execucao
depende-de: [ci-e-distribuicao]
decisao-humana: sim
spec: pedido do Pedro em 2026-09-02 para preparar e disponibilizar o repositório publicamente
---

# Lançamento público no GitHub Implementation Plan

> **Para execução agentic:** executar inline nesta sessão, preservar as mudanças locais já
> existentes e usar este arquivo como ledger. Cada task fecha com prova própria e com o checkbox
> atualizado no mesmo commit do seu trabalho.

**Goal:** transformar o repositório público do Melodarium numa vitrine bilíngue, instalável,
auditável e visualmente memorável, com capturas produzidas pelo aplicativo real.

**Architecture:** a apresentação pública será uma camada versionada sobre o produto existente:
um capturador determinístico monta dados e mídia sintéticos em XDG temporário, o binário Qt/QML
real gera a galeria e uma composição visual usa essas capturas no hero. Documentação em inglês e
pt-BR, arquivos de comunidade, metadados do GitHub e um fluxo de release apontam para a mesma
realidade verificada pelo build, CTest e gates visuais do projeto.

**Tech Stack:** Markdown, GitHub Actions/Issue Forms, Bash, ImageMagick, ffmpeg, SQLite, Qt 6/QML,
libmpv, CMake/Ninja, Flatpak e GitHub CLI.

## Global Constraints

- Não incluir nem reverter as mudanças locais já presentes em `src/audioengine.*`,
  `tests/CMakeLists.txt`, `tests/tst_audioengine.cpp`, `tools/check-track-click.sh` e a solução
  correspondente; os commits desta fatia devem adicionar somente arquivos de lançamento.
- Nenhuma captura pode ler biblioteca, configuração, cache ou banco reais. Todo run usa
  `mktemp -d`, XDG isolado, áudio gerado por `ffmpeg` e capas originais geradas localmente.
- “Captura real” significa pixels salvos por `Main.qml` via `grabToImage` no binário compilado;
  mockups de `design/*.dc.html` não entram na galeria pública.
- README e contribuição têm versões completas em inglês e pt-BR, ligadas por seletor no topo.
- Não afirmar “open source” nem criar licença até Pedro escolher explicitamente GPL-3.0, MIT ou
  proprietário/source-available. A publicação da release depende dessa decisão humana.
- O estado público real do GitHub deve substituir a informação antiga de que o repo é privado.
- Nunca abrir PR. O destino final autorizado é `main`, após todos os gates e uma revisão do diff.
- Build e testes passam por `quiet-run`; CTest precisa descobrir pelo menos 25 alvos antes de a
  execução verde contar como evidência.
- Antes de qualquer commit, executar `gitnexus detect_changes`; alterações de símbolos de código
  exigiriam `impact` prévio, mas esta fatia não deve tocar funções, classes ou métodos do produto.

## File Map

- Create: `tools/capture-readme-gallery.sh` — gera mídia/dados descartáveis e captura os estados
  públicos do aplicativo real.
- Create: `tools/check-public-release.sh` — falha se documentação, idiomas, imagens, licença,
  metadados ou padrões óbvios de segredo estiverem ausentes/inconsistentes.
- Create: `docs/assets/screenshots/*.png` — galeria real, determinística e sem dados pessoais.
- Create: `docs/assets/melodarium-hero.png` — hero 1280×640 construído a partir da galeria real.
- Create: `docs/brand/github-visual-philosophy.md` — fonte estética da composição pública.
- Modify: `README.md`; create: `README.pt-BR.md` — landing pages completas em inglês e pt-BR.
- Create: `CONTRIBUTING.md`, `CONTRIBUTING.pt-BR.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  `CHANGELOG.md` — contrato público de colaboração, segurança, convivência e versão inicial.
- Create: `.github/ISSUE_TEMPLATE/{bug_report.yml,feature_request.yml,config.yml}`,
  `.github/PULL_REQUEST_TEMPLATE.md`, `.github/release.yml`, `.github/dependabot.yml` — entrada e
  manutenção da comunidade.
- Modify: `.github/workflows/ci.yml`; create: `.github/workflows/release.yml` — gate da superfície
  pública e pacote Flatpak anexado a tags `v*`.
- Create after Pedro's decision: `LICENSE`; modify:
  `data/io.github.pedronalis.melodarium.metainfo.xml` — direitos coerentes em arquivo e AppStream.
- Modify: `AGENTS.md`, `CLAUDE.md`, `handoff.md` — estado público e evidência do lançamento.

---

### Task 1: Auditoria e contrato do lançamento

**Files:**
- Create: `tools/check-public-release.sh`
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/plans/2026-09-02-github-publico.md`

**Interfaces:**
- Consumes: árvore rastreada pelo Git, `gh repo view`, `git grep`, ImageMagick e os metadados
  AppStream existentes.
- Produces: um gate único com mensagens `PUBLIC_RELEASE_*`, reutilizado localmente e pela CI.

- [x] **Step 1: Escrever a validação vermelha**

  Criar o gate exigindo os dois READMEs, arquivos de comunidade, licença coerente, cinco PNGs
  1100×700 não uniformes, hero 1280×640, seletor de idioma recíproco, nenhuma URL de badge fora
  de `pedronalis/melodarium` e nenhuma credencial de padrões GitHub/OpenAI/AWS/Slack na árvore.

- [x] **Step 2: Provar a falha inicial**

  Run: `quiet-run bash tools/check-public-release.sh`

  Expected: `PUBLIC_RELEASE_MISSING` para os artefatos ainda ausentes, sem falso verde.

- [x] **Step 3: Ligar o gate à CI**

  Adicionar `run_logged public-release bash tools/check-public-release.sh` depois dos gates de
  pacote e antes de `git diff --check`.

- [x] **Step 4: Verificar a mecânica do gate**

  Run: `bash -n tools/check-public-release.sh && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"`

  Expected: shell sintaticamente válido e workflow parseável.

- [x] **Step 5: Commitar o checkpoint**

  Stage apenas os três arquivos desta task e commitar com
  `ci: gate the public repository surface`.

---

### Task 2: Galeria real, reproduzível e segura

**Files:**
- Create: `tools/capture-readme-gallery.sh`
- Create: `docs/assets/screenshots/now-playing.png`
- Create: `docs/assets/screenshots/library.png`
- Create: `docs/assets/screenshots/collections.png`
- Create: `docs/assets/screenshots/podcasts.png`
- Create: `docs/assets/screenshots/search.png`
- Modify: `docs/plans/2026-09-02-github-publico.md`

**Interfaces:**
- Consumes: `./build/melodarium`, flags `--measure`, `--shot`, `--pane`, `--play-queue`,
  `--open-collection`, `--play-episode` e `--search-text`; esquema SQLite migrado pelo próprio
  aplicativo.
- Produces: cinco PNGs 1100×700 capturados pelo QML real, com catálogo fictício e arte original.

- [ ] **Step 1: Escrever o capturador com autovalidação vermelha**

  O script deve recusar binário ausente, dependências ausentes, erro QML, captura vazia, dimensão
  diferente de 1100×700 ou imagem quase uniforme. Deve criar FLACs curtos, quatro capas originais,
  artistas/álbuns/faixas, tags, coleções e episódios somente sob um XDG temporário.

- [ ] **Step 2: Provar que a validação detecta ausência de artefato**

  Run: `quiet-run env MELODARIUM_GALLERY_VERIFY_ONLY=1 bash tools/capture-readme-gallery.sh`

  Expected: falha nomeando os PNGs ausentes.

- [ ] **Step 3: Gerar as capturas pelo binário real**

  Run: `quiet-run bash tools/capture-readme-gallery.sh ./build/melodarium`

  Expected: cinco linhas `GALLERY_CAPTURE_OK`, nenhuma leitura de XDG real e nenhum erro QML.

- [ ] **Step 4: Inspecionar visualmente a galeria**

  Montar contact sheet em `/tmp`, abrir as cinco imagens e conferir legibilidade, variedade de
  estados, ausência de caminhos pessoais e coerência com a UI atual.

- [ ] **Step 5: Commitar o checkpoint**

  Stage apenas o script, os cinco PNGs e este ledger; commitar com
  `docs: capture the real application gallery`.

---

### Task 3: Identidade visual do GitHub

**Files:**
- Create: `docs/brand/github-visual-philosophy.md`
- Create: `docs/assets/melodarium-hero.png`
- Modify: `docs/plans/2026-09-02-github-publico.md`

**Interfaces:**
- Consumes: as capturas reais da Task 2, o ícone Freedesktop e fontes locais licenciadas.
- Produces: manifesto visual e hero 1280×640 adequado ao topo do README e ao social preview.

- [ ] **Step 1: Registrar a filosofia visual**

  Definir uma estética “arquivo noturno”: espaço preto, escada de cinzas, ritmo de waveform e
  pequenos acentos espectrais; texto mínimo, sem imitar artista ou marca externa.

- [ ] **Step 2: Compor o hero com material real**

  Usar uma captura principal e duas secundárias, recortadas sem deformação, com profundidade
  discreta; limitar texto a `MELODARIUM`, `LOCAL MUSIC · PODCASTS · YOUR FILES` e `Qt · QML · mpv`.

- [ ] **Step 3: Refinar e verificar pixels**

  Run: `identify -format '%wx%h' docs/assets/melodarium-hero.png`

  Expected: `1280x640`; inspeção visual confirma margens, nitidez e ausência de sobreposição.

- [ ] **Step 4: Commitar o checkpoint**

  Stage apenas filosofia, hero e ledger; commitar com `docs: give Melodarium a public visual identity`.

---

### Task 4: Documentação bilíngue e contrato de comunidade

**Files:**
- Modify: `README.md`
- Create: `README.pt-BR.md`
- Create: `CONTRIBUTING.md`
- Create: `CONTRIBUTING.pt-BR.md`
- Create: `SECURITY.md`
- Create: `CODE_OF_CONDUCT.md`
- Create: `CHANGELOG.md`
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Create: `.github/ISSUE_TEMPLATE/feature_request.yml`
- Create: `.github/ISSUE_TEMPLATE/config.yml`
- Create: `.github/PULL_REQUEST_TEMPLATE.md`
- Create: `.github/release.yml`
- Create: `.github/dependabot.yml`
- Modify: `docs/plans/2026-09-02-github-publico.md`

**Interfaces:**
- Consumes: hero/galeria, comandos reais de CMake/Flatpak, 35 testes atuais e limites conhecidos
  de Fedora/Wayland/yt-dlp.
- Produces: jornada pública completa em ambos os idiomas, templates acionáveis e changelog 0.1.0.

- [ ] **Step 1: Escrever README em inglês**

  Abrir com hero, seletor de idioma, proposta local-first, galeria e quick start; depois cobrir
  recursos, instalação Fedora, Flatpak local, arquitetura, dados/privacidade, testes, limitações,
  contribuição, segurança, roadmap e créditos sem prometer suporte inexistente.

- [ ] **Step 2: Escrever a versão pt-BR com paridade estrutural**

  Traduzir a mesma informação de forma natural, preservando comandos e identificadores técnicos.

- [ ] **Step 3: Criar arquivos de comunidade**

  Documentar ambiente, padrão de commit, gates, envio responsável de vulnerabilidade, convivência
  e release notes; issue forms e PR template devem aceitar inglês ou português explicitamente.

- [ ] **Step 4: Validar links, YAML e paridade**

  Run: `quiet-run bash tools/check-public-release.sh`

  Expected: apenas o bloqueio de licença pode permanecer, identificado como
  `PUBLIC_RELEASE_LICENSE_PENDING`.

- [ ] **Step 5: Commitar o checkpoint**

  Stage apenas documentação/comunidade e ledger; commitar com
  `docs: launch the bilingual GitHub experience`.

---

### Task 5: Licença, release e automação de distribuição

**Files:**
- Create: `LICENSE`
- Modify: `data/io.github.pedronalis.melodarium.metainfo.xml`
- Create: `.github/workflows/release.yml`
- Modify: `README.md`
- Modify: `README.pt-BR.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/plans/2026-09-02-github-publico.md`

**Interfaces:**
- Consumes: decisão explícita de Pedro, manifesto Flatpak validado e tag SemVer `v0.1.0`.
- Produces: direitos coerentes, workflow que constrói um bundle `.flatpak` e checksum SHA-256,
  e uma GitHub Release com notas bilíngues.

- [ ] **Step 1: Aplicar a decisão de licença**

  Usar exatamente GPL-3.0, MIT ou texto proprietário/source-available escolhido por Pedro;
  atualizar `project_license`, badges e linguagem dos READMEs sem alterar licenças de terceiros.

- [ ] **Step 2: Criar workflow de tag**

  Em tags `v*`, instalar KDE SDK 6.9, construir o manifesto limpo, exportar repositório Flatpak,
  gerar `melodarium-<tag>-x86_64.flatpak` + `.sha256` e anexar ambos à release com `gh`.

- [ ] **Step 3: Validar workflow e contrato legal**

  Run: `quiet-run bash tools/check-public-release.sh && appstreamcli validate --pedantic data/io.github.pedronalis.melodarium.metainfo.xml`

  Expected: gate completo e AppStream sem erro.

- [ ] **Step 4: Commitar o checkpoint**

  Stage apenas arquivos legais/release e ledger; commitar com
  `build: publish verifiable Flatpak releases`.

---

### Task 6: Gate final e disponibilização

**Files:**
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `handoff.md`
- Modify: `docs/plans/2026-09-02-github-publico.md`

**Interfaces:**
- Consumes: todas as tasks anteriores, branch atual, `origin/main`, GitHub CLI autenticado e
  repositório já público.
- Produces: `main` público atualizado, metadados de descoberta, Discussions e release `v0.1.0`.

- [ ] **Step 1: Verificar o produto em worktree limpo**

  Run: `quiet-run cmake -B build -G Ninja && quiet-run cmake --build build`

  Run: `quiet-run bash tools/check-test-floor.sh 25 && quiet-run ctest --test-dir build --output-on-failure`

  Run: `quiet-run cmake --build build --target all_qmllint && quiet-run bash tools/check-orfaos.sh && quiet-run bash tools/check-fidelidade.sh && quiet-run bash tools/check-public-release.sh`

  Expected: build verde, pelo menos 25 testes descobertos, todos passando e todos os gates verdes.

- [ ] **Step 2: Revisar escopo com Git e GitNexus**

  Run: `git diff --check && git status --short && git log --oneline origin/main..HEAD`

  Run: `gitnexus detect_changes(scope=compare, base_ref=main)`

  Expected: somente lançamento/documentação além dos commits já existentes; nenhum símbolo de
  produto afetado por esta fatia.

- [ ] **Step 3: Atualizar estado e commit final**

  Corrigir o fato antigo “repo privado”, registrar evidências no handoff, marcar todas as tasks e
  executar `planos-lote.py set-status ... concluido`; commitar com
  `docs: record the public launch`.

- [ ] **Step 4: Publicar sem PR**

  Confirmar que `origin/main` é ancestral de `HEAD`; atualizar `main`, fazer push direto, definir
  descrição/tópicos/homepage e habilitar Discussions. Criar e enviar a tag anotada `v0.1.0`.

- [ ] **Step 5: Observar o GitHub**

  Aguardar CI e release workflow; confirmar run verde, release pública, bundle e checksum
  baixáveis, README/hero renderizados e metadados retornados por `gh repo view`.
