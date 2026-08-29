---
title: O efeito existia, respondia, e não pintava um pixel
category: ui
module: NowPlayingPanel.qml, AmbientGlow.qml, Main.qml
symptoms:
  - "efeito visual novo compila, o campo de diagnóstico diz `on`, e a tela não muda"
  - "`z: -1` num filho que deveria ficar atrás do conteúdo e na frente do fundo"
  - "nenhum gate reprova, porque o gate desliga justamente esse efeito"
  - "não existe comando capaz de fotografar o efeito aceso"
tags: [qml, z-order, gate, captura, ambient-glow]
---

O halo do painel foi escrito, ligado, e o app passou a imprimir `halo=on` na linha de medição.
A tela continuou exatamente igual — **idêntica em todos os canais**, medida pixel a pixel com o
efeito ligado e desligado.

## A causa

`z: -1`.

No Qt Quick, `z` não ordena só entre irmãos. Um filho com **z negativo é desenhado ANTES do
conteúdo do próprio pai** — atrás dele. O pai aqui é o painel, e o painel pinta um degradê
**opaco** de cima a baixo. O halo estava lá, atualizando, animando: debaixo de uma superfície
sem transparência nenhuma.

A correção é não ter `z`. A ordem de declaração já resolve: declarado antes da coluna, o halo
é desenhado antes dela — atrás da capa e na frente do degradê, que é o único lugar em que ele
precisa estar.

```qml
// ERRADO: some atrás do degradê do próprio painel
AmbientGlow { anchors.fill: parent; z: -1 }

// CERTO: declarado antes da coluna, sem z
AmbientGlow { anchors.fill: parent }
ColumnLayout { id: col }
```

## Por que nenhum gate pegou

Porque o gate **desliga o efeito de propósito**. A cor do halo vem da capa que estiver tocando
na máquina de quem roda; o gate de fidelidade mede 15 pontos fixos com 3 níveis de tolerância
por canal, e um deles fica a 16 px da capa. Ou o halo sai da foto, ou o gate passa a medir
sorte.

O resultado é uma armadilha nova: **o único efeito que o gate não olha é o que mais precisa de
prova**, e ele fica verde tanto funcionando quanto morto.

Pior: tocar uma faixa por linha de comando também só acontecia sob `--measure`. Então não havia
NENHUMA forma de o app produzir a imagem que provaria o efeito. A saída foi separar as duas
fotos com uma chave: `--com-halo` mantém o efeito aceso sob medição. A foto que MEDE continua
sem halo; a foto que MOSTRA passa a ter.

**Regra que fica:** efeito que um gate desliga precisa nascer com a chave que o acende para a
foto — senão ele não tem como ser provado, nem hoje nem daqui a seis meses.

## A prova certa

Comparação numérica entre duas capturas da mesma tela, uma com o efeito e outra sem:

```
16 px à esquerda da capa   com=(30,41,51)   sem=(20,20,20)
longe, no miolo            com=(21,21,21)   sem=(21,21,21)
```

A segunda linha importa tanto quanto a primeira: ela prova que o efeito tem alcance, e não que
a tela inteira mudou de cor.

## O que NÃO funcionou

- **Acreditar no campo de diagnóstico.** `halo=on` só diz que a propriedade calculou `true`.
  Não diz que alguma coisa foi pintada. Campo de estado não é prova de pixel.
- **Confiar no comentário do plano.** O plano dizia, com todas as letras, que `z: -1` põe o
  item "atrás de todo o conteúdo e ainda por cima do degradê do painel". É o contrário.
- **Olhar a captura e achar que estava sutil.** A imagem reduzida deixa qualquer luz fraca
  parecer presente. Só a leitura de pixel resolveu — e ela custou dois comandos.
- **Tirar o corte (`clip`) para a luz não bater na borda.** Sem o corte as molduras que
  compõem a luz saem do painel e passam a se ver COMO molduras: um retângulo arredondado
  gigante por cima do rail e da lista. Fotografado, comparado, descartado. A luz termina onde
  o painel termina.
