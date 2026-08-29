---
title: A alça de arrastar e a área que arrasta ficaram em coordenadas diferentes
category: ui
module: TrackRow.qml, CollectionsPane.qml
symptoms:
  - "o desenho de arrastar aparece na linha mas o arrasto quase nunca pega"
  - "o cursor de mão só muda num pedaço da alça, e à esquerda dela num vão vazio"
  - "MouseArea ancorada em parent.left não coincide com o primeiro filho do RowLayout"
tags: [qml, drag, rowlayout, margem, geometria, gate]
---

## O problema

A alça de arrastar (`⠿`) foi declarada como primeiro filho do `RowLayout` do `TrackRow`, e a
`MouseArea` que faz o arrasto foi ancorada em `parent.left` do delegate com 20 px de largura.
Parecem o mesmo lugar. Não são.

O `TrackRow` empilha duas margens antes do conteúdo: o `Rectangle` interno tem
`anchors.leftMargin: Theme.marginXS` (4) e o `RowLayout` dentro dele tem
`anchors.leftMargin: Theme.marginL` (13). A alça, portanto, começa em **17 px** e termina em
**29**. A `MouseArea` cobria **0 a 20**: três pixels de sobreposição, dezessete pixels de
gesto num vão onde não há desenho nenhum, e nove pixels de alça desenhada que não arrastam.

Nada disso reprova. O QML compila, o `ctest` fica verde, o detector de órfãos fica verde (a
`MouseArea` existe e o método é chamado), o gate de layout fica verde (a moldura não mudou) e
o de fidelidade também (a cor não mudou). A foto do gate mostra as alças no lugar certo — ela
fotografa o DESENHO da alça, não a área que responde ao dedo.

## A causa

`anchors.left: parent.left` num delegate de `ListView` mede a partir da borda do delegate. O
primeiro filho de um `RowLayout` mede a partir da borda do layout, que já está deslocada pela
soma das margens de todos os contêineres entre os dois. Quando o alvo do gesto e o desenho do
gesto são declarados em sistemas de coordenadas diferentes, eles só coincidem por acidente.

## A correção

Somar as margens antes de escolher o número, e deixar a conta escrita no código:

```qml
MouseArea {
    id: dragArea
    // 34 e não 20: a alça desenhada começa em 17 px (a margem do Rectangle do TrackRow mais
    // a do RowLayout) e termina em 29. Para em 34, antes do número da faixa (42).
    width: Math.round(34 * Theme.uiScale)
    anchors.left: parent.left
    drag.target: faixa
    drag.axis: Drag.YAxis
}
```

## O que NÃO funcionou

- **Confiar na foto do gate.** Ela prova que a alça está desenhada, e é exatamente isso que
  ela prova. Área de toque não tem cor, então nenhum gate que mede pixel a alcança.
- **Mover a alça para fora do `RowLayout`, ancorada no zero.** Faria a coordenada bater, mas o
  `TrackRow` é o mesmo componente da biblioteca inteira: uma fatia de coleção passaria a mexer
  no espaçamento da lista principal.
- **Chutar "um pouco mais largo".** O limite superior também é duro: o número da faixa começa
  em 42 px, e uma área que chega lá rouba o clique de ativação da faixa. O intervalo útil é
  17–42, e é preciso medi-lo, não estimá-lo.

## Como isto teria sido pego antes

O gesto precisa rodar uma vez, de ponta a ponta, dentro do próprio app. Foi o que a bandeira
`--move-last-to-top` passou a fazer: emite o mesmo sinal que a alça emite, e o resultado é
lido no banco (`1,2,3,4,5,6` → `6,1,2,3,4,5`) e na tela (a faixa 6 aparece na linha 1). Uma
bandeira de medição por gesto novo é mais barata que um gesto que nunca rodou.
