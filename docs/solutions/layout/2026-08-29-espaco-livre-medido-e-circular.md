---
title: Peça que se esconde quando não cabe não pode medir o espaço que ela mesma ocupa
category: layout
module: src/NowPlayingPanel.qml
symptoms:
  - "buraco do tamanho do componente no pé da coluna, no lugar do componente"
  - "QML NextUpCard: Binding loop detected for property \"espacoLivre\""
  - "peça transborda a margem de baixo do painel"
tags: [qml, layout, columnlayout, binding-loop, painel]
---

# O que aconteceu

O painel da capa tem uma coluna cheia: capa, título, progresso, transporte, volume, etiquetas.
Duas peças diferentes já tentaram ocupar o pé dela (a lista "a seguir na fila", depois o cartão
"próximo a tocar"), e as duas nasceram com a mesma conta:

```qml
readonly property int espacoLivre: sobra.height + peca.height   // ← circular
visible: espacoLivre >= peca.alturaCheia + Theme.marginXL
```

A intenção era boa — somar o vazio com o que a peça já ocupa dá um total constante. Mas
`peca.height` sai do layout, e o layout sai de `visible`: o Qt detecta o ciclo, corta uma das
ligações e **o resultado na tela é um retângulo vazio do tamanho da peça**, com o resto da
coluna espremido. Nada falha, nada avisa: o gate de layout mede a moldura e passa verde.

# O que fazer

Decidir por uma grandeza que o layout não produz — a altura da coluna, que vem do `anchors.fill`
e não do conteúdo:

```qml
readonly property int capaComCartao: Math.min(root.coverSide,
                                              col.height - reservaAbaixoDaCapa - custoDoCartao)
readonly property bool cabeCartao: proxima.temProximo && capaComCartao >= 340
```

E a reserva do resto da coluna tem de ser **medida**, não estimada. O app já imprime a soma real
com `--measure`; foi assim que apareceu que o resto pedia 309 px e não os 330 que estavam
escritos, e que a conta antiga usava `root.height` (a janela) em vez de `col.height` (a coluna) —
as margens, 48 px, escondiam o erro de 20. Contra a altura certa, o erro vira peça transbordando.

Para medir: `console.log` de `col.implicitHeight - capaRect.height` dentro do bloco `--measure`,
rodando em várias alturas (`--measure-height 700 900 1086 1440`). A soma dividida pela escala dá
o mesmo número em todas — é esse o valor da reserva.

# O que NÃO funcionou

- **Somar `sobra.height + peca.height` para obter um total constante.** É a armadilha descrita
  acima. O total É constante, mas a leitura de `peca.height` fecha o ciclo.
- **Encolher a peça a zero em vez de escondê-la** (para o espaçamento do layout não sumir junto).
  Resolve a instabilidade do espaçamento, não o ciclo — `height` continua vindo do layout.
- **Histerese** (limiar mais folgado para entrar do que para sair). Exige que o limiar dependa do
  estado atual, que é a mesma circularidade com outro nome.
- **Estimar a reserva "com folga" para não transbordar.** Na janela nominal a folga faz a capa
  encolher e o gate de layout falha (`painel = 392`); na janela alta a falta de folga faz a peça
  transbordar. A janela entre os dois erros tem 3 px — não há número seguro por chute.
