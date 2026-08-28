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
