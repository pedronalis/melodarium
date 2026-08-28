---
title: Interface desenhada para 1100x700 vira microscópica numa janela de 2540x1384
category: ui
module: Theme.qml
symptoms:
  - "o app abre em tela cheia e tudo fica minúsculo no canto"
  - "texto pequeno demais para ler à distância normal"
  - "colunas cortadas ('Brick City ...') com metade da tela vazia ao lado"
tags: [qml, escala, dpi, layout, theme]
---

## O problema

Todo tamanho do app — fonte em pontos, margem, raio, largura da barra de ícones, lado da capa,
altura da linha da lista — nasceu de um desenho feito para uma janela de 1100×700. Numa janela
de 2540×1384 (tela cheia num monitor 2560×1440) esses mesmos números continuam corretos e a
interface fica **perdida**: o painel ocupa 15% da largura, o texto de 11pt vira um risco, e a
lista se espalha por uma faixa fina no meio de um oceano de fundo.

O Pedro descreveu como "uma escala microscópica". Nenhum teste pegou: as medidas estavam todas
exatamente como o plano mandava.

## O conserto: um fator único no tema

O `Theme` já era a fonte de todo tamanho, então bastou torná-lo elástico:

```qml
// Theme.qml
property real uiScale: 1.0

readonly property real fontSizeM: 11 * uiScale
readonly property int  marginL:   Math.round(13 * uiScale)
readonly property int  railWidth: Math.round(56 * uiScale)
readonly property int  panelCover: Math.round(340 * uiScale)
```

```qml
// Main.qml — o fator sai da janela real, preso entre 1 e 1,7
readonly property real escalaDaJanela:
    Math.max(1.0, Math.min(1.7, Math.min(root.width / 1100, root.height / 700)))

onEscalaDaJanelaChanged: Theme.uiScale = root.escalaDaJanela
```

O teto de 1,7 existe para o texto não virar cartaz numa tela 4K; o piso de 1 impede que uma
janela menor que o desenho encolha a fonte a ponto de sumir.

## O que quebra junto, e passa despercebido

Escalar a fonte sem escalar o resto produz um segundo defeito **pior que o primeiro**:

- **Altura de linha fixa** (`implicitHeight: 38`) → título e artista se sobrepõem, ilegível.
  Toda altura de controle precisa do mesmo fator.
- **Largura de coluna fixa** (`Layout.preferredWidth: 132`) → o texto cresce, a coluna não, e
  o nome do álbum trunca em "Brick City ..." mesmo com metade da tela vazia. Para colunas de
  conteúdo variável, `fillWidth` + `maximumWidth` escalado funciona melhor que largura fixa.

Grep que encontra os pendentes:

```bash
grep -rn "implicitHeight: [0-9]\|Layout.preferredWidth: [0-9]" src/*.qml | grep -v uiScale
```

## O que NÃO funcionou

- **Confiar no high-DPI do Qt.** O monitor tem `scale 1` no Hyprland e 109 DPI — não é HiDPI.
  O Qt não tem por que escalar nada; o problema é de proporção do desenho, não de densidade.
- **Achar que era bug de layout.** As medidas estavam certas: rail 56, painel 392, capa
  340×340, tudo conferido pelo `tools/check-layout.sh`. Um layout pode passar em todas as
  medidas e ainda estar errado para o tamanho da janela em que vive.
- **Olhar só no tamanho de desenvolvimento.** Em 1100×700 nunca houve problema nenhum. O
  defeito só existe onde o app realmente roda — daí valer rodar em tela virtual nos tamanhos
  reais do usuário (`Xvfb` + `-geometry 2540x1384`) antes de dizer que está pronto.
