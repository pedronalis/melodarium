---
title: Texto sem elide estoura o RowLayout, e o gate de layout dá verde no estouro
category: ui
module: LibraryPane.qml · tools/check-layout.sh
symptoms:
  - "o miolo inteiro aparece deslocado para a direita, cortado pela borda da janela"
  - "durações e o último chip saem cortados só quando um álbum está aberto"
  - "check-layout.sh passa com 11 medidas ok e a tela está visivelmente quebrada"
  - "a largura medida do vão dos chips CRESCE quando o conteúdo não cabe"
tags: [qml, qtquick-layouts, rowlayout, elide, gate, medicao]
---

## O sintoma

A fatia `colecoes-alcance` acrescentou ao cabeçalho da biblioteca o nome do artista e um botão
"+ Coleção", na mesma linha do título. Com a lista "Todas" aberta a tela ficava perfeita. Com um
**álbum** aberto — título longo, mais o artista, mais a contagem, mais o botão — o miolo inteiro
aparecia empurrado para a direita: a linha de chips terminava fora da janela, as durações das
faixas saíam cortadas.

`bash tools/check-layout.sh` passou **verde**, com as 11 medidas ok.

## A causa

Duas coisas, e a segunda é a que importa para o futuro.

**1. `Text` sem `elide` não encolhe.** Num `RowLayout`, um item cujo mínimo efetivo é a largura
implícita não cede espaço: quando a soma dos filhos passa da largura disponível, o layout não
comprime — ele **transborda**, e o excesso vaza para fora do pai. O título em corpo XL não tinha
`elide` nem teto de largura.

**2. O gate afere uma RELAÇÃO, e o estouro satisfaz a relação.** A linha do gate é

    chips (largura pedida pela fileira de filtros)  <=  chipsvao (largura disponível)

e `chipsvao` é lido do próprio layout que estourou. Medido no caso quebrado:

| estado                      | chips | chipsvao | gate   |
| --------------------------- | ----- | -------- | ------ |
| lista "Todas"               | 542   | 604      | ok     |
| **álbum aberto (quebrado)** | 542   | **648**  | **ok** |
| álbum aberto (corrigido)    | 542   | 604      | ok     |

Quando o conteúdo estoura, o vão medido **cresce** — e a comparação continua verdadeira. O gate
não mede a janela: mede o layout contra ele mesmo. Some a isso que ele nunca abria um álbum, e o
defeito ficava invisível dos dois lados.

## A correção

Empilhar o cabeçalho em duas linhas, que é como o desenho aprovado (`design/Main.dc.html:79-82`)
sempre o mostrou: o nome em cima; artista, contagem e duração embaixo. O título ganhou
`Layout.fillWidth: true` + `elide: Text.ElideRight`; o artista, `Layout.maximumWidth` proporcional
e `elide`. Confirmado a 1100 px e a 720 px: `chipsvao` volta a 604 / 364 com álbum aberto, e o
botão continua inteiro na janela mínima.

## A regra que fica

- **Todo `Text` que recebe dado do usuário dentro de um `RowLayout` precisa de `elide` e de um
  teto de largura.** Nome de álbum, de artista e de coleção não têm tamanho máximo.
- **Uma medida derivada do layout medido não serve de gate contra estouro.** Ou o gate compara
  com a largura da JANELA (que não infla), ou ele precisa de outro sinal.
- **Gate de layout tem de abrir os estados densos.** Este só media a lista aberta no estado mais
  vazio; a bandeira `--open-album <id>` existe por causa disto.

## O que NÃO funcionou

- **Confiar no verde do `check-layout.sh`.** Ele passou nas 11 medidas com a tela quebrada. Foi a
  FOTO que denunciou, não o gate — de novo, como no "+21" da lição
  `2026-08-28-chamada-de-metodo-nao-cria-dependencia-qml.md`.
- **Supor que o `StackLayout` prendia o filho.** A largura do painel estava certa
  (`libraryPane.width = 652`, medido por instrumentação); quem transbordava era o conteúdo
  DENTRO dele. Investigar pelo pai custou duas medições inúteis.
- **Pôr `elide` só no título, mantendo a linha única.** A conta continuava estourando na soma
  artista + contagem + botão; o teto teria de ser tão apertado que o título viraria reticências
  em nome de salvar uma linha de layout — e brigando com o desenho, que já resolvia isso.
