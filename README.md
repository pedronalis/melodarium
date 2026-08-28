# melodarium

Player local de música e podcast em Qt6/QML, com a estética do
[Noctalia](https://github.com/noctalia-dev/noctalia-shell): paleta lida do `colors.json` do
usuário, tipografia Inter e ícones Tabler. Roda igual sem o Noctalia instalado — toda cor tem
fallback embutido.

## Dependências

Fedora:

```bash
sudo dnf install cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel
```

## Build

```bash
cmake -B build -G Ninja
cmake --build build
./build/melodarium
```

## Testes

```bash
ctest --test-dir build --output-on-failure
```

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
