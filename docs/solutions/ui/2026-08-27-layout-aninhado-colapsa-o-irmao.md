---
title: Layout aninhado colapsa o irmão — fillWidth default é true para layouts
category: ui
module: Main.qml
symptoms:
  - "painel principal aparece com 2 px de largura, só a borda visível"
  - "coluna lateral ocupa a tela inteira mesmo com Layout.preferredWidth definido"
  - "conteúdo ancorado dentro do painel some sem erro nenhum"
tags: [qml, qtquick-layouts, rowlayout, columnlayout, fillwidth]
---

## O sintoma

A tela tinha três colunas — barra lateral (220), lista de faixas (o resto) e coluna da fila (300).
O que apareceu foi: barra lateral certa, **lista com 2 px** (só a borda arredondada, como uma
linha vertical) e a coluna da fila com 834 px de uma janela de 1100. Nenhum aviso, nenhum erro de
QML, testes todos verdes — layout não é coberto por teste unitário.

## A causa

Em Qt Quick Layouts, `Layout.fillWidth` **tem default diferente conforme o tipo do filho**:

> The default is `false` for non-layout items, and `true` for layouts.

A coluna da direita era um `ColumnLayout` dentro de um `RowLayout`. Como layout, ela nasceu com
`fillWidth: true`; o `Layout.preferredWidth: 300` é só uma preferência, não um teto. Aí dois
irmãos disputavam o espaço extra — o `Rectangle` da lista (`fillWidth: true`, `implicitWidth 0`)
e a coluna (`fillWidth` implícito, `implicitWidth 300`) — e a distribuição foi toda para quem
tinha largura implícita maior.

## O conserto

```qml
ColumnLayout {
    Layout.fillWidth: false      // <- o default de layout aninhado é true
    Layout.maximumWidth: 340
    Layout.preferredWidth: 300
}
```

E o cinto de segurança no painel que não pode sumir:

```qml
Rectangle {
    Layout.fillWidth: true
    Layout.minimumWidth: 360     // um implicitWidth de 0 não se defende sozinho
}
```

## Como diagnosticar em 2 minutos

Não teorize sobre o algoritmo de distribuição — **meça**. Um `Timer` temporário imprimindo as
larguras dá a resposta na primeira execução:

```qml
Timer {
    running: true; interval: 900
    onTriggered: console.log("MEDIDA meio=" + midPanel.width
        + " meioImplicit=" + midPanel.implicitWidth
        + " dir=" + rightCol.width + " dirImplicit=" + rightCol.implicitWidth)
}
```

```bash
QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
  QT_QPA_PLATFORM=offscreen timeout 6 ./build/melodarium 2>&1 | grep -a MEDIDA
```

O `offscreen` serve: o layout é calculado do mesmo jeito sem tela, então isso roda em qualquer
sessão, inclusive dentro de um run headless.

## O que NÃO funcionou

- **Ler o QML procurando o erro.** O código parece certo — `preferredWidth: 300` está lá, e o
  default invisível é justamente o que não está escrito.
- **Culpar o `StackLayout` que envolve o `RowLayout`.** Ele repassa a largura inteira; não tinha
  nada a ver.
- **Achar que era falta de conteúdo.** A biblioteca estava vazia, o que mascarou o problema como
  "tela feia" em vez de "painel colapsado" — a lista vazia e a lista de 2 px parecem a mesma
  coisa num print.
- **Confiar na suíte.** 9 baterias verdes com o painel principal invisível. Teste de unidade não
  vê geometria; para isso, a captura de tela é o único juiz.
