---
title: Player local precisa publicar MPRIS para existir no desktop
category: integracao
module: src/mprisservice.*, Noctalia, Hyprland
symptoms:
  - "Play/Pause, Next e Previous do teclado não controlam o app"
  - "o app não aparece no reprodutor de mídia do Noctalia"
tags: [mpris, dbus, noctalia, hyprland, media-keys, qt6]
---

## O que aconteceu

O Melodarium tinha todos os verbos de reprodução no `AudioEngine`, mas eles existiam apenas
dentro do processo e do QML. Isso não torna um player visível ao desktop.

Nesta máquina, os binds XF86 do Hyprland chamam:

```text
~/.config/hypr/scripts/noctalia-ipc.sh call media playPause|next|previous
```

O `MediaService.qml` do Noctalia enumera exclusivamente `Quickshell.Services.Mpris`, descarta
players sem `CanPlay` e encaminha os verbos ao objeto MPRIS escolhido. Antes da correção:

```text
$ playerctl -l
firefox.instance_1_147880

$ busctl --user list | grep org.mpris.MediaPlayer2.melodarium
# nenhuma saída
```

Por isso os dois sintomas eram a mesma falha de fronteira: o teclado chegava ao Noctalia, mas
o Noctalia não tinha um objeto D-Bus do Melodarium para descobrir ou controlar.

## Contrato implementado

`MprisService` registra `org.mpris.MediaPlayer2.melodarium` no session bus e exporta o objeto
`/org/mpris/MediaPlayer2` com as interfaces Root e Player do MPRIS 2.2.

- Play, Pause, PlayPause, Stop, Next, Previous, Seek e SetPosition delegam ao `AudioEngine`.
- Uma sessão salva conta como `CanPlay`; o primeiro Play restaura fila + índice e começa em
  `0:00`, mantendo o contrato de retomada de música.
- PlaybackStatus, LoopStatus, Rate, Shuffle, Volume e capacidades refletem os sinais do motor.
- Metadata usa `mpris:trackid`, título, artista, álbum, URL, duração e a capa assíncrona do
  `CoverCache`.
- `Position` usa microssegundos e não emite `PropertiesChanged` durante a progressão normal,
  conforme a especificação.
- O serviço é compilado apenas quando `Qt6::DBus` existe no backend Unix. Falha de barramento ou
  nome já ocupado não impede o app de abrir nem de tocar pela UI.

Referências: [MPRIS Player](https://specifications.freedesktop.org/mpris/latest/Player_Interface.html),
[MPRIS Root](https://specifications.freedesktop.org/mpris/latest/Media_Player.html) e
[Qt D-Bus](https://doc.qt.io/qt-6/qtdbus-index.html).

## Gate que prova a fronteira

`tools/check-mpris.sh` cria duas faixas reais, grava uma fila em QSettings isolado e inicia o
binário dentro de `dbus-run-session`. O mesmo teste:

1. espera o nome MPRIS;
2. introspecta as duas interfaces;
3. exige Identity, CanControl e CanPlay;
4. manda Play e espera Playing;
5. manda Pause e espera Paused;
6. manda Next e exige mudança de título.

Ele foi visto em RED por 10,45 s com “serviço não apareceu” e em GREEN por 0,93 s depois da
implementação. No barramento real, o IPC do Noctalia pausou, retomou e avançou de “Break Of
Dawn” para “Fantasy”; a captura mostrou o cartão Melodarium com capa e metadata.

## Diagnóstico rápido para a próxima vez

```bash
playerctl -l
busctl --user list --no-legend | grep '^org.mpris.MediaPlayer2'
gdbus introspect --session \
  --dest org.mpris.MediaPlayer2.melodarium \
  --object-path /org/mpris/MediaPlayer2
playerctl -p melodarium status
playerctl -p melodarium metadata
```

Se o nome não existe, o defeito está no registro QtDBus ou na vida do objeto. Se existe mas o
Noctalia não lista, conferir `CanPlay` e `~/.config/noctalia/settings.json` → `mprisBlacklist`.
Se lista e o teclado não controla, conferir primeiro os binds XF86 e o IPC do Noctalia — não
alterar o motor antes de localizar em qual fronteira o verbo parou.
