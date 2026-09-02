---
title: Popup.Native ignora a estética QML da aplicação
category: ui
module: MelodariumMenu.qml, SpeedControl.qml, tools/check-contextual-ui.sh
symptoms:
  - "dropdown branco dentro de uma aplicação escura"
  - "background e delegate QML não alteram a aparência do menu"
  - "menu embutido não recebe as teclas do xdotool em Xvfb"
tags: [qml, menu, popup, tema, xvfb, teclado]
---

# `Popup.Native` ignora a estética QML da aplicação

## O problema

O Melodarium misturava sete instâncias de `Menu` do Qt. Velocidade e timer pediam
`popupType: Popup.Native` explicitamente; os demais herdavam o backend e a pintura do estilo da
plataforma. Em uma interface preta e cinza, o resultado observável era um retângulo branco do
sistema, com tipografia e estados sem relação com o restante do app.

Estilizar somente `background` ou `delegate` não resolve `Popup.Native`: nesse modo o Qt entrega o
menu ao sistema operacional, que não renderiza a árvore QML definida pela aplicação.

## A solução

Os três papéis foram centralizados:

- `MelodariumMenu` herda `T.Menu`, força `Popup.Item` e pinta a superfície com `Theme.cRaised`;
- `MelodariumMenuItem` herda `T.MenuItem`, preserva teclado, foco, estado desabilitado e
  checkmark, usando `Theme.cPill` no item destacado;
- `MelodariumMenuSeparator` herda `T.MenuSeparator` e usa `Theme.cLine`.

Todos os consumidores usam esses três tipos. O gate contextual procura `Menu`, `MenuItem` e
`MenuSeparator` crus em qualquer QML fora dos componentes-base e falha se encontrar um. A captura
do menu de velocidade também falha quando encontra mais de 5.000 pixels quase brancos, cobrindo o
modo de regressão que o grep sozinho não enxerga.

## A armadilha do teclado no Xvfb

O menu nativo cria uma janela própria e normalmente recebe foco do Xvfb. `Popup.Item` vive dentro
da janela principal; sem window manager, `xdotool key` pode continuar enviando teclas à raiz e o
menu parece inerte. Antes da sequência `Home`, `Down` e `Return`, o gate precisa focar a janela
explicitamente:

```bash
app_window=$(xdotool search --onlyvisible --name Melodarium | head -1)
xdotool windowfocus "$app_window"
```

Isso é uma necessidade do harness. No uso real, o clique que abre o menu já deixa a janela do app
com foco.

## O que não funcionou

- Manter `Popup.Native` esperando que `Theme` alterasse a superfície do sistema.
- Validar apenas que o menu abriu: o popup branco também abre e responde ao teclado.
- Enviar teclas para o display Xvfb sem focar a janela depois de migrar para `Popup.Item`.
- Usar um glifo chamado `check` sem confirmar sua presença em `Icons`; o indicador ocupava espaço,
  mas desenhava uma string vazia. O componente usa o caractere tipográfico `✓`.
