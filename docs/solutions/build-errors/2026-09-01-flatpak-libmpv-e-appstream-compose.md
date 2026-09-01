---
title: Flatpak de libmpv headless precisa explicitar plain-gl e o host precisa do compose
category: build-errors
module: packaging
symptoms:
  - "gl enabled but no OpenGL video output could be found"
  - "AppStream Compose binary '/usr/libexec/appstreamcli-compose' was not found"
  - "state dir is not on the same filesystem as the target dir"
tags: [flatpak, flatpak-builder, libmpv, meson, appstream, fedora]
---

# O encadeamento da falha

O manifesto do Melodarium desabilita recursos automáticos do mpv para produzir uma biblioteca
de áudio enxuta:

```yaml
- -Dauto_features=disabled
- -Dcplayer=false
- -Dlibmpv=true
```

No mpv 0.41, porém, `gl` nasce habilitado e `plain-gl` nasce em `auto`. Desabilitar todos os
recursos automáticos remove justamente o backend descrito pelo próprio mpv como OpenGL sem
código de plataforma para libmpv. Como Wayland e X11 também ficam desligados, o Meson não acha
nenhuma saída que satisfaça `gl` e aborta.

# Correção e regressão

O módulo `libmpv` precisa declarar explicitamente:

```yaml
- -Dplain-gl=enabled
```

`tools/check-package.sh` lê o manifesto e falha com
`FLATPAK_LIBMPV_PLAIN_GL_MISSING` quando o contrato some. O ciclo RED/GREEN foi observado antes
da nova construção completa.

# Dependências do host

`flatpak-builder` sozinho não fecha a construção no Fedora. A etapa final chama
`appstreamcli compose`, cujo complemento mora no pacote `appstream-compose`. A combinação usada
foi:

```bash
sudo dnf install flatpak-builder appstream-compose
flatpak install --user flathub org.kde.Sdk//6.9
```

Ter apenas `org.kde.Platform//6.9` não substitui o SDK. Da mesma forma, extrair somente o RPM do
builder em `/tmp` não resolve o compose, porque o `appstreamcli` procura o complemento no caminho
fixo `/usr/libexec/appstreamcli-compose`.

# Comando reproduzível

Quando o alvo está em `/tmp` e o repo está em outro filesystem lógico para o builder, coloque
também o estado em `/tmp`:

```bash
flatpak-builder --user --force-clean \
  --state-dir=/tmp/melodarium-flatpak-builder-state \
  /tmp/melodarium-flatpak-build \
  packaging/io.github.pedronalis.melodarium.yml
```

Depois, execute `quiet-run bash tools/check-package.sh`. Validar o XML com `appstreamcli
validate` é necessário, mas não substitui a prova de `appstreamcli compose` feita pela construção
real.

# O que não funcionou

- Usar o diretório de estado padrão no repo com alvo em `/tmp`: o builder recusou os filesystems
  diferentes antes de compilar.
- Confiar só em `flatpak-builder --show-manifest`: prova a estrutura do YAML, não configura os
  módulos nem compõe AppStream.
- Extrair apenas o RPM do builder localmente: permitiu chegar mais longe, mas deixou ausente o
  complemento de composição do host.
