<div align="center">
  <img src="docs/assets/melodarium-hero.png" alt="Melodarium — player local de música e podcast rodando no Linux" width="100%">

  <h1>Melodarium</h1>

  <p><a href="README.md">English</a> · <strong>Português (Brasil)</strong></p>

  <p>
    <img alt="Qt 6.5+" src="https://img.shields.io/badge/Qt-6.5%2B-41CD52?logo=qt&logoColor=white">
    <img alt="Linux" src="https://img.shields.io/badge/plataforma-Linux-FCC624?logo=linux&logoColor=111111">
    <a href="LICENSE"><img alt="Licença: GPL-3.0-only" src="https://img.shields.io/badge/licen%C3%A7a-GPL--3.0--only-a78bfa"></a>
    <img alt="Preview" src="https://img.shields.io/badge/status-preview-c084fc">
  </p>

  <p><strong>Um player local-first de música e podcasts para Linux, focado em privacidade.</strong><br>
  Navegue pela sua biblioteca, acompanhe podcasts RSS e reproduza tudo pelo libmpv.</p>

  <p><a href="https://github.com/pedronalis/melodarium/releases/latest"><strong>Última release</strong></a> · <a href="#veja-o-app-rodando">Capturas de tela</a> · <a href="#começo-rápido-no-fedora">Compile do código-fonte</a> · <a href="#flatpak">Flatpak</a></p>
</div>

> [!IMPORTANT]
> O Melodarium é um preview inicial para Linux, desenvolvido e verificado no Fedora 43 com
> Wayland/Hyprland. O projeto é software livre sob `GPL-3.0-only`; espere mudanças incompatíveis
> enquanto a primeira versão estável ainda toma forma.

## Melodarium em resumo

| | |
|---|---|
| Ideal para | Bibliotecas pessoais de música local e podcasts RSS |
| Plataforma | Linux; Fedora 43 com Wayland é o ambiente de referência, com fallback X11 |
| Áudio | Reprodução pelo libmpv sem taxa ou formato de amostra forçado pelo aplicativo |
| Armazenamento | Catálogo SQLite local; sem conta, biblioteca na nuvem ou telemetria |
| Tecnologias | Qt 6, QML, C++20, libmpv e TagLib |
| Distribuição | Compilação do código-fonte e bundle Flatpak x86_64 em preview |
| Licença | Software livre e de código aberto sob `GPL-3.0-only` |

## Por que Melodarium: uma biblioteca, não um feed

O Melodarium é para quem ainda guarda arquivos de música, valoriza o contexto de um álbum e quer
ouvir podcasts sem transformar o próprio histórico em dataset de terceiros. Ele varre pastas
locais, mantém o catálogo em SQLite e entrega a reprodução ao libmpv. Não há conta, biblioteca na
nuvem ou telemetria.

### Principais recursos

- Navegue por todas as faixas ou atravesse artistas, álbuns, gêneros, tags e visões inteligentes.
- Reproduza arquivos lossless sem forçar taxa ou formato de amostra.
- Monte coleções ordenadas, edite a fila ao vivo e retome a sessão musical anterior.
- Assine podcasts RSS, baixe episódios e retome cada um sem misturar seu estado com o da música.
- Busque faixas, álbuns, artistas, coleções, programas e episódios num único overlay pelo teclado.
- Controle pelo desktop com MPRIS, teclas de mídia e a paleta do Noctalia quando disponível.
- Faça backup e restaure o catálogo por um bundle versionado e verificado por hashes.

## Veja o app rodando

| Tocando agora | Coleções |
|:--:|:--:|
| <img src="docs/assets/screenshots/now-playing.png" alt="Melodarium tocando Night Bloom na visão de álbum" width="100%"> | <img src="docs/assets/screenshots/collections.png" alt="Coleção ordenada com o mini-player global" width="100%"> |

| Podcasts | Busca |
|:--:|:--:|
| <img src="docs/assets/screenshots/podcasts.png" alt="Episódios de podcast e painel para continuar ouvindo" width="100%"> | <img src="docs/assets/screenshots/search.png" alt="Busca pelo teclado entre músicas, coleções e podcasts" width="100%"> |

Essas imagens não são mockups do design. Cada uma foi salva pelo aplicativo QML atual usando
catálogo descartável, áudio FLAC gerado e capas sintéticas originais.

## Começo rápido no Fedora

O Melodarium hoje mira Linux. O Fedora 43 é o ambiente de referência; outras distribuições podem
funcionar quando oferecem Qt 6.5+, libmpv e os pacotes de desenvolvimento do TagLib.

```bash
sudo dnf install cmake ninja-build gcc-c++ \
  qt6-qtbase-devel qt6-qtdeclarative-devel \
  mpv-devel taglib-devel \
  rsms-inter-fonts jetbrains-mono-fonts

git clone https://github.com/pedronalis/melodarium.git
cd melodarium
cmake -S . -B build -G Ninja
cmake --build build
./build/melodarium
```

Instale para o usuário atual com:

```bash
cmake --install build --prefix "$HOME/.local"
```

Isso instala o executável, a entrada do menu, os metadados AppStream e o ícone Freedesktop.

## Flatpak

Releases marcadas publicam um bundle Flatpak x86_64, checksum SHA-256 e atestado de proveniência
do GitHub na [página de Releases](https://github.com/pedronalis/melodarium/releases). Baixe o
bundle e o checksum no mesmo diretório e execute:

```bash
sha256sum -c melodarium-v0.1.0-x86_64.flatpak.sha256
flatpak install --user ./melodarium-v0.1.0-x86_64.flatpak
```

O repositório também inclui um manifesto Flatpak fixado sobre KDE/Qt 6.9 para builds locais:

```bash
flatpak install --user flathub org.kde.Sdk//6.9
flatpak-builder --user --force-clean /tmp/melodarium-flatpak-build \
  packaging/io.github.pedronalis.melodarium.yml
flatpak-builder --run /tmp/melodarium-flatpak-build \
  packaging/io.github.pedronalis.melodarium.yml melodarium
```

O sandbox recebe áudio, aceleração gráfica, rede para feeds/mídia de podcasts, Wayland com fallback
X11, MPRIS e leitura da pasta XDG de música. Pastas escolhidas fora dela usam a permissão persistente
do portal de documentos.

> [!NOTE]
> O Flatpak não empacota `yt-dlp`. RSS de podcasts e URLs diretas de mídia funcionam; downloads do
> YouTube que dependem de um `yt-dlp` externo ainda não ficam disponíveis dentro do sandbox.

## O que existe por dentro

| Área | Implementação |
|---|---|
| Interface | Componentes Qt Quick/QML, responsivos a partir de 720×700 |
| Reprodução | libmpv, fila persistente, aleatório/repetir, timer e ReplayGain |
| Biblioteca | Scanner TagLib, observação ao vivo da pasta, catálogo SQLite e busca textual |
| Capas | Cache assíncrono endereçado por conteúdo, com arte embutida ou vizinha ao arquivo |
| Podcasts | RSS/Atom, downloads, retomada por episódio e importação/exportação OPML |
| Desktop | Serviço MPRIS, teclas de mídia, `.desktop`, AppStream e ícone Freedesktop |
| Portabilidade | Exportação M3U e bundles `.melodarium-backup` validados |

A camada QML cuida da apresentação e da interação. Serviços C++ expõem singletons estreitos para
reprodução, dados, varredura, downloads, capas e portabilidade. O SQLite permanece local; o libmpv
controla o ciclo de áudio; a rede só entra nos recursos que dependem dela por natureza.

## Comportamento do áudio

O Melodarium não força taxa de saída nem formato de amostra. Um FLAC 24-bit/192 kHz chega ao libmpv
sem conversão imposta pelo aplicativo; o grafo de áudio do sistema ainda pode reamostrar. O gapless
nasce na política `weak` do mpv, preservando transições de álbuns com o mesmo formato sem reamostrar
silenciosamente quando o formato muda.

Saída exclusiva e gapless agressivo são preferências explícitas porque têm consequências no sistema
inteiro ou no caminho do sinal. ReplayGain nasce desligado e só age quando a faixa traz as tags. Áudio
do YouTube aparece marcado como comprimido e nunca é vendido como lossless.

## Dados locais e privacidade

Instalações nativas seguem os diretórios-base XDG:

- banco da biblioteca, podcasts e downloads: `$XDG_DATA_HOME/melodarium/melodarium/`;
- preferências: `$XDG_CONFIG_HOME/melodarium/melodarium.conf`;
- cache de capas: `$XDG_CACHE_HOME/melodarium/melodarium/covers/`.

Sem variáveis XDG explícitas, o Qt mapeia isso para `~/.local/share`, `~/.config` e `~/.cache`. No
Flatpak, os dados ficam sob `~/.var/app/io.github.pedronalis.melodarium/`. Uma migração na primeira
abertura preserva dados criados com o nome anterior do aplicativo, `melodia`.

Não copie manualmente um banco SQLite aberto. Use **Ajustes → Backup e restauração**; a restauração
confere versão do bundle, hashes, integridade SQLite e espaço livre antes de trocar os dados.

## Limites atuais

- O texto da interface ainda está em pt-BR; a documentação e o suporte comunitário do repositório
  estão disponíveis em inglês e português.
- Linux é a única plataforma testada. Wayland/Hyprland é o alvo principal; X11 é fallback suportado.
- Ainda não há listagem no Flathub. Os bundles de release têm checksum e atestado de proveniência
  do GitHub, mas não são assinados com uma chave duradoura do projeto.
- O suporte ao YouTube usa o `yt-dlp` já instalado no host nativo e nunca o distribui.

## Perguntas frequentes

### O Melodarium é um serviço de streaming ou cliente do Spotify?

Não. O Melodarium reproduz arquivos sob seu controle e acompanha feeds abertos de podcast em
RSS/Atom. Ele não exige conta e não fornece um catálogo de música na nuvem.

### O Melodarium funciona offline?

Músicas locais e episódios de podcast já baixados funcionam offline. A rede só é necessária para
atualizar feeds, baixar mídia remota ou usar recursos baseados numa URL externa.

### O Melodarium reproduz FLAC e áudio lossless?

Sim. O Melodarium delega a reprodução ao libmpv e não força taxa ou formato de amostra na saída. O
grafo de áudio do sistema operacional ainda pode reamostrar o sinal.

### Onde o Melodarium armazena seus dados?

O catálogo e os downloads permanecem nos diretórios XDG do usuário ou no diretório de dados
específico do Flatpak. Os caminhos exatos e o procedimento seguro de backup estão documentados em
[Dados locais e privacidade](#dados-locais-e-privacidade).

## Licença

O Melodarium é software livre sob a
[GNU General Public License v3.0 somente](LICENSE) (`GPL-3.0-only`). Ao contribuir, você concorda
em licenciar sua contribuição sob os mesmos termos.

## Créditos

- Direção visual inspirada pelo [Noctalia](https://github.com/noctalia-dev/noctalia-shell), sem
  depender dele para funcionar.
- Reprodução por [mpv/libmpv](https://mpv.io/) e metadados por
  [TagLib](https://taglib.org/).
- A fonte de ícones Tabler incluída usa licença MIT; o aviso está em
  [`assets/fonts/tabler-icons-license.txt`](assets/fonts/tabler-icons-license.txt).
- A interface usa Inter e os metadados técnicos usam JetBrains Mono quando instaladas.

<div align="center"><sub>Feito no Brasil para quem ainda é dono daquilo que ouve.</sub></div>
