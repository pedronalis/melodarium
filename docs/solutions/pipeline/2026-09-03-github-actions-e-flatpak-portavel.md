---
title: Pipeline público em container e Flatpak portátil entre Fedora e Ubuntu
category: pipeline
module: GitHub Actions, Flatpak, testes Qt/QML
symptoms:
  - "checkout em container termina sem .git ou Git acusa dubious ownership"
  - "gate local passa, mas o release Ubuntu não encontra libplacebo"
  - "teste assíncrono passa localmente e flutua no runner hospedado"
  - "preflight do release usa ferramentas antes de instalá-las"
tags: [github-actions, flatpak, container, git, libdir, qt, qml, mpv, ci]
---

## O problema

O lançamento público da `v0.1.0` juntou três ambientes com contratos diferentes: Fedora em
container para a CI, Fedora local para desenvolvimento e Ubuntu 24.04 hospedado para o Flatpak.
Cada um ficou verde isoladamente em algum momento, mas os primeiros runs remotos revelaram
dependências implícitas:

- o container não tinha Git quando `actions/checkout` rodou e recebeu apenas um arquivo REST, sem
  `.git`;
- depois de instalar Git, o checkout existia, mas o dono do bind mount disparava `dubious
  ownership` quando os gates consultavam a árvore;
- o gate público do release chamava `rg`, Pillow e PyYAML antes da instalação;
- o `flatpak-builder` 1.4.2 do Ubuntu deixava libplacebo em `/app/lib64`, enquanto o ambiente de
  build do SDK procurava `pkg-config` e bibliotecas em `/app/lib`;
- timers absolutos de QML e a simples presença de `currentFile` não provavam que o mpv já estava
  pronto para animar ou aceitar seek.

O resultado era enganoso: a mesma árvore podia passar inteira localmente e falhar por ordem de
setup, propriedade do checkout, prefixo de biblioteca ou corrida assíncrona no runner.

## O que funciona

### Tornar o checkout verificável dentro do container

Instalar Git antes de `actions/checkout` impede o fallback para o arquivo REST. Logo após o
checkout, confiar somente no workspace resolvido pelo runner:

```yaml
- name: Trust checked-out repository
  run: git config --global --add safe.directory "$GITHUB_WORKSPACE"
```

O caminho exato é importante: não usar wildcard transforma a correção de ownership em liberação
global. O gate público deve exigir `.git` e executar uma consulta real, não apenas testar se o
diretório existe.

### Instalar o preflight antes de executá-lo

O release valida primeiro a relação tag/versão, instala `appstream`, `flatpak`,
`flatpak-builder`, `python3-pil`, `python3-yaml` e `ripgrep`, e só então roda
`tools/check-public-release.sh`. Assim uma falha do gate é uma falha do projeto, não ausência de
ferramenta no runner.

### Fixar o prefixo de biblioteca do Flatpak

No topo do manifesto:

```yaml
build-options:
  libdir: /app/lib
```

Esse contrato força Meson/CMake de todos os módulos a concordarem com o `PKG_CONFIG_PATH` e o
`LD_LIBRARY_PATH` do SDK. O gate de pacote precisa checar a chave para impedir regressão. A prova
forte é um build limpo na versão de `flatpak-builder` do runner, seguido por bundle, importação em
OSTree vazio e reexportação.

### Sincronizar testes pelo estado que eles realmente consomem

- Movimento QML: esperar `currentFile` e amostrar cada fase observável da barra/conteúdo, em vez
  de disparar três timers a partir da montagem da janela.
- Restore/seek do mpv: esperar `duration() > 0.0` antes do seek e usar timeout compatível com cold
  start hospedado. `currentFile` informa seleção, não readiness do demuxer.

Na execução final, o CI da tag passou 36/36 testes; o release construiu, assinou e publicou o
Flatpak. O asset baixado teve SHA-256
`914f0fbc2ca52e5220fa40ee4b43108fbfede5543e3a2caf71df5c312ffd10f6`, provenance SLSA ligada ao
commit `b31586c` e importação limpa em
`app/io.github.pedronalis.melodarium/x86_64/0.1.0`.

## O que NÃO funcionou

- **Confiar no sucesso do checkout sem Git instalado** — o fallback REST parece checkout, mas não
  preserva histórico nem `.git`.
- **Configurar safe.directory antes do checkout** — `actions/checkout` troca `HOME` durante a
  execução; a configuração não fica no contexto usado pelos passos seguintes.
- **Usar `/app/lib64` só porque a máquina é x86_64** — o contrato do SDK Flatpak continua apontando
  para `/app/lib`.
- **Instalar dependências depois do gate que precisa delas** — transforma preflight em loteria da
  imagem base.
- **Sincronizar mídia por tempo fixo ou `currentFile`** — em runner frio, o arquivo pode estar
  selecionado sem duration, seek ou frames QML estarem prontos.
- **Tratar `ctest` exit 0 como cobertura suficiente** — continuar exigindo piso explícito de alvos;
  `Total Tests: 0` também pode sair verde.

## Evidência remota

- CI da tag: <https://github.com/pedronalis/melodarium/actions/runs/33766580314>
- Release Flatpak: <https://github.com/pedronalis/melodarium/actions/runs/33766580177>
- Release pública: <https://github.com/pedronalis/melodarium/releases/tag/v0.1.0>
