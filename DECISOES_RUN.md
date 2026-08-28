# Decisões do run — leva 1 (clique-responde · fila-motor)

Sessão headless autônoma, branch `exec/melodia-religa`, 2026-08-28.
Cada item registra a decisão tomada, a alternativa descartada e o custo de estar errada.

## 1. `grep -c 'heart-filled' src/NowPlayingPanel.qml` esperava 2, dá 1

**Contexto.** A Task 3 do plano `clique-responde` manda a verificação mecânica
`grep -c 'heart-filled' src/Icons.qml src/TrackRow.qml src/NowPlayingPanel.qml` →
`src/NowPlayingPanel.qml:2`. O próprio bloco de código que o plano prescreve para esse
arquivo tem `heart-filled` numa única linha (`icon: root.info.liked === true ?
"heart-filled" : "heart"`), e `grep -c` conta LINHAS casadas, não ocorrências.

**Decisão.** O código do plano foi colado exatamente como escrito; a expectativa numérica
do plano é que está errada. O valor correto é 1. Aceito 1 como verde.

**Alternativa descartada.** Inventar uma segunda referência a `heart-filled` no arquivo só
para satisfazer o número — isso seria escrever código para agradar um grep.

**Custo de estar errada.** Nenhum funcional: o comportamento pedido (curtido = forma sólida,
não só cor) está entregue nos dois lugares que o desenho exige (a linha da lista e o painel).
O portão do objetivo do run cobra `grep -c 'heart-filled' src/Icons.qml` → 1, que passa.

## 2. O trilho de volume mantém `implicitHeight: 3` fixo, sem `Theme.uiScale`

**Contexto.** O perigo nº 8 do repositório manda todo tamanho NOVO de interface passar por
`Theme.uiScale`. O bloco de volume que a Task 6 prescreve traz `implicitHeight: 3` literal.

**Decisão.** Fica literal. O trilho da barra de progresso, logo acima no mesmo painel
(`Rectangle { id: track }`), já é `implicitHeight: 3` — o padrão vigente do app. Escalar só
o trilho de volume poria dois trilhos de espessuras diferentes um debaixo do outro na
mesma coluna.

**Alternativa descartada.** Trocar por `Math.round(3 * Theme.uiScale)`. Isso resolveria o
perigo nº 8 pela metade e criaria uma incoerência visível.

**Custo de estar errada.** Numa tela muito grande os dois trilhos ficam finos JUNTOS, que é
o defeito que o app já tem hoje e que se conserta numa passada só, nos dois, quando alguém
decidir a espessura certa. Nenhum trilho fica mais fino que o outro por causa desta fatia.
