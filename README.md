# melodarium

Player local de música e podcast em Qt6/QML, com a estética do
[Noctalia](https://github.com/noctalia-dev/noctalia-shell): paleta lida do `colors.json` do
usuário, tipografia Inter e ícones Tabler. Roda igual sem o Noctalia instalado — toda cor tem
fallback embutido.

## Dependências

No Fedora 43, o pacote de desenvolvimento atual do libmpv é `mpv-devel` (ele fornece o nome
virtual histórico `mpv-libs-devel`). Para compilar e executar:

```bash
sudo dnf install cmake ninja-build gcc-c++ \
  qt6-qtbase-devel qt6-qtdeclarative-devel \
  mpv-devel taglib-devel \
  rsms-inter-fonts jetbrains-mono-fonts
```

Inter é a fonte da interface e JetBrains Mono é usada para metadados técnicos. Há fallbacks, mas
instalar as duas preserva a geometria e a aparência verificadas pelos gates. Para a suíte e todos
os gates locais:

```bash
sudo dnf install ImageMagick appstream dbus-daemon desktop-file-utils \
  ffmpeg-free flac flatpak-builder playerctl python3-pillow python3-pyyaml \
  ripgrep sqlite xdotool xorg-x11-server-Xvfb
```

## Build

```bash
cmake -B build -G Ninja
cmake --build build
./build/melodarium
```

Instalação nativa em um prefixo do usuário:

```bash
cmake --install build --prefix "$HOME/.local"
```

Isso instala o binário, a entrada `.desktop`, os metadados AppStream e o ícone Freedesktop.

## Flatpak local

O manifesto usa KDE/Qt 6.9 e fixa libass, libplacebo, libmpv 0.41.0 e TagLib 2.3.1 por tag e
commit. Ele não instala nem publica nada por conta própria:

```bash
flatpak install --user flathub org.kde.Sdk//6.9
flatpak-builder --force-clean /tmp/melodarium-flatpak-build \
  packaging/io.github.pedronalis.melodarium.yml
flatpak-builder --run /tmp/melodarium-flatpak-build \
  packaging/io.github.pedronalis.melodarium.yml melodarium
```

O sandbox recebe áudio, Wayland com fallback X11, rede, MPRIS, aceleração gráfica e leitura da
pasta XDG de música; seleções fora dela dependem da permissão persistente do portal. O manifesto
não empacota `yt-dlp`: RSS e mídia direta funcionam, mas downloads que exigem o executável externo
ficam indisponíveis no Flatpak atual.

## Testes

```bash
bash tools/check-test-floor.sh 25
ctest --test-dir build --output-on-failure
cmake --build build --target all_qmllint
bash tools/check-orfaos.sh
bash tools/check-layout.sh
bash tools/check-fidelidade.sh
```

O workflow em `.github/workflows/ci.yml` reproduz o build em Fedora 43, exige pelo menos 25 testes
descobertos, roda 35 alvos CTest e os gates determinísticos. Em falha, anexa os logs do job; não
faz push, release nem publicação.

## Controles e recursos

- `Ctrl+K` ou `Ctrl+F` foca a busca; teclas Play/Pause, Próxima e Anterior do teclado seguem
  MPRIS. Os controles principais também respondem a Tab, Espaço, Enter e Escape.
- A fila permite tocar a seguir, remover, mover e limpar as próximas entradas sem reiniciar a
  faixa atual. O player e o mini-player oferecem timer de 15/30/60 minutos e “parar após esta”.
- Arrastar arquivo, pasta, feed ou URL sobre a janela mostra a ação antes de executar. Downloads e
  assinaturas continuam exigindo confirmação.
- Podcasts suportam cancelar download, desassinar mantendo ou apagando arquivos, auto-download
  opt-in e retenção por feed (`0` significa ilimitada).
- Preferências incluem ReplayGain, saída exclusiva, gapless agressivo, alto contraste e movimento
  reduzido. Erros de banco, scan, playback, feed e download aparecem na própria interface.

## Importação, exportação e backup

- Assinaturas de podcast entram e saem em OPML; duplicatas e entradas inválidas são resumidas.
- Coleções exportam M3U UTF-8 com caminhos absolutos na ordem manual. Faixas ausentes são ignoradas
  e contabilizadas.
- Preferências → Backup e restauração cria um `.melodarium-backup` versionado. Antes de restaurar,
  o app valida versão, hashes, integridade SQLite e espaço; preserva o estado atual em um bundle de
  retorno e pede reinício após a troca.

Não edite nem copie o banco aberto à mão. Para migração entre máquinas, use o bundle da interface.

## Dados locais

O app segue XDG. Na instalação nativa, os principais caminhos são:

- banco, podcasts e downloads: `$XDG_DATA_HOME/melodarium/melodarium/`;
- preferências: `$XDG_CONFIG_HOME/melodarium/melodarium.conf`;
- capas: `$XDG_CACHE_HOME/melodarium/melodarium/covers/`.

Quando as variáveis não existem, Qt usa `~/.local/share`, `~/.config` e `~/.cache`. No Flatpak,
essas bases ficam sob `~/.var/app/io.github.pedronalis.melodarium/`. Na primeira abertura, a
migração do nome antigo preserva biblioteca, capas, downloads e podcasts.

## Modo de desenvolvimento da tela

Recarrega o QML a cada salvamento, sem recompilar o C++:

```bash
MELODIA_DEV_QML=$PWD/src/Main.qml ./build/melodarium
```

Os tipos C++ continuam disponíveis porque estão linkados estaticamente no binário; só o texto
QML é relido do disco.

## Ver `qDebug` e `console.log`

O Fedora instala `/usr/share/qt6/qtlogging.ini` com `*.debug=false` e manda o resto para o
journald — sem as duas variáveis abaixo, todo log de debug some sem erro nenhum:

```bash
QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 ./build/melodarium
```

## Qualidade de áudio

O motor é o libmpv, e as opções abaixo existem para manter o sinal intacto do arquivo até a
placa. O que o melodarium garante e o que não depende dele:

- **Nenhuma conversão de taxa ou de formato de amostra é forçada.** As opções do mpv que
  fixariam taxa e formato ficam deliberadamente sem valor: basta setar qualquer uma delas
  para o `swresample` passar a converter *todas* as faixas para aquele valor. É isso que faz
  um FLAC 24 bit/192 kHz chegar ao dispositivo como está no arquivo.
- **`gapless-audio` fica em `weak`,** o padrão do mpv. Nesse modo o dispositivo continua
  aberto entre faixas de mesmo formato — o caso do álbum contínuo — e nunca há resample
  escondido. `setGaplessAggressive(true)` troca para `yes`, que mantém o dispositivo aberto
  também quando o formato muda e, para conseguir isso, **reamostra** as faixas seguintes.
  Por isso `yes` não é padrão.
- **`audio-exclusive` não é padrão.** Ligado (`setExclusiveOutput(true)`), o melodarium toma o
  dispositivo para si e **silencia todo o resto do sistema** enquanto houver arquivo
  carregado. É uma escolha do usuário, nunca um default.
- **Limite honesto:** mesmo em modo exclusivo, quem reamostra pode ser o PipeWire. Se o grafo
  estiver fixo numa taxa (`default.clock.rate` no `pipewire.conf`), a conversão acontece fora
  do melodarium, e nenhuma opção daqui a evita — é configuração do sistema.
- **ReplayGain** nasce desligado; `setReplayGainMode("track")` ou `"album"` liga, e só tem
  efeito quando o arquivo traz as tags.

## Baixar do YouTube

- **O melodarium não distribui o baixador.** Ele chama por processo o `yt-dlp` que já estiver
  instalado na sua máquina, e não faz nada se não houver nenhum — a tela diz isso em vez de
  falhar em silêncio. Instale pelo gerenciador de pacotes da sua distro.
- **O áudio do YouTube é comprimido** (Opus, ~160 kbps) e **nunca** será alta qualidade. Ele
  convive com os arquivos de verdade na mesma biblioteca, e a interface marca a origem com um
  selo "YouTube" na linha da faixa: o app não finge que as duas qualidades são a mesma coisa.
  Pela mesma razão o download pede `--audio-format best`, que **não** reencoda — converter para
  MP3 perderia qualidade uma segunda vez, de graça.
- **`--embed-thumbnail` exige `ffmpeg`.** Quando o `ffmpeg` não está no `PATH` herdado (o caso
  típico de um app aberto por atalho `.desktop`), o melodarium procura nos lugares usuais e passa
  `--ffmpeg-location` explicitamente.
- **Qual `yt-dlp` respondeu.** Esta máquina tem dois instalados — o do `PATH` é o do Homebrew
  (mais antigo) e o do sistema é o do Fedora, em `/usr/bin`. O melodarium usa o do `PATH`, que é o
  que o usuário espera, e **mostra a versão encontrada** na tela de adicionar link: no dia em
  que uma das duas quebrar, saber qual respondeu economiza a hora de depuração.

## Licenças de terceiros

A fonte de ícones Tabler (`assets/fonts/noctalia-tabler-icons.ttf`) é distribuída sob licença
MIT — o texto acompanha o arquivo em `assets/fonts/tabler-icons-license.txt`.
