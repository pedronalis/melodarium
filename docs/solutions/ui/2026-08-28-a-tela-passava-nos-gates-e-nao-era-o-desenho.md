---
title: A tela passava em todos os gates e não era o desenho
category: ui
module: Theme.qml, RoundedImage, tools/check-fidelidade.sh
symptoms:
  - "capa de canto vivo apesar de `radius` estar no código"
  - "nenhum degradê na tela, embora o desenho tenha três"
  - "listra de zebra gritante, faixa tocando invisível"
  - "campo de texto no lugar de um chip pequeno"
  - "gates de layout, testes e órfãos todos verdes"
tags: [qml, cor, design-fidelity, gate, qquickpainteditem, multieffect, antialiasing]
---

O redesenho fechou 14 fatias com suíte verde, `check-layout` verde nas 11 medidas e
`check-orfaos` em zero. O Pedro abriu o app e disse: "o visual ainda está feio, não está fiel
às cores do artifact desenhado, não está com degradês, não está com as capas com bordas
arredondadas, o badge de criar tag está diferente."

Todas as quatro reclamações eram verdadeiras, e nenhuma tinha como falhar em nada que rodava.

## As três causas

**1. A paleta perdeu resolução.** O app consome as 16 chaves semânticas do tema do sistema
(Noctalia). O desenho usa **14 tons de cinza com papéis distintos**: `#151515` para a listra,
`#1c1c1c` para a linha tocando, `#191919` para o campo de busca, `#232323` para a pílula,
`#262626` para borda. Sem esses degraus, cada componente escolheu a chave "mais próxima" e os
quatro fundos de estado colapsaram no mesmo `mSurfaceVariant`. Não é um bug: é uma perda de
informação, e ela só aparece na tela.

**2. `radius` + `clip` não arredonda imagem no QML.** `radius` desenha o canto do `Rectangle`;
`clip: true` recorta os filhos pelo **retângulo** do item, não pelo raio. A moldura arredondada
existia no código e a imagem por cima dela seguia de canto vivo — em todas as capas do app.

**3. A tipografia estava 25% maior.** `font.pointSize: 11` vira ~14,7 px a 96 dpi; o desenho
manda 12 px na linha da lista. Toda a escada de texto nasceu em pontos contra um desenho medido
em pixels.

## O que NÃO funcionou

- **`MultiEffect` com `maskSource`** — a saída canônica do Qt 6 para máscara arredondada. Ela
  funciona na tela do usuário e **não desenha nada no adaptador de software**, que é como o app
  é fotografado (e como ele roda numa máquina sem GPU). A capa não ficou de canto vivo: sumiu
  inteira. Testado isolado com `qml` + `grabToImage`: a `Image` crua aparece, as duas variantes
  mascaradas ficam pretas.
- **`layer.enabled: true` na `Image` de origem** — a tentativa seguinte, pela suspeita de que
  faltasse textura. Mesmo resultado.
- **Confiar em `Window.color` para o fundo** — pinta o "clear color", que existe na tela e
  **não entra em captura nenhuma**. A foto saía com fundo preto onde o app mostra `#111111`, e
  isso falseava toda conferência feita sobre a foto.
- **Trocar `pointSize` por `pixelSize` sem olhar `IconButton`** — a área do botão era
  `size * 2`, com `size` em pontos. Em pixels, virou 38 px por botão e a fileira do transporte
  ficou mais larga que o painel: o tempo total da faixa saía cortado pela borda.

## O que funcionou

- **Escada de cinza com nomes de papel** em `Theme.qml` (`cRowAlt`, `cRowCurrent`, `cPill`,
  `cLine`, `cFaint`, `cDim`, `cMuted`, `cBody`, `cStrong`, `cTitle`, …). Quem escreve tela
  escolhe pela função, não pelo hex — é isso que impede a escada de colapsar de novo. As 16
  chaves do tema continuam existindo; só `mError`/`mOnError`/`mShadow` seguem vindo dele.
- **`RoundedImage`, um `QQuickPaintedItem`** que recorta com `QPainterPath` + `setClipPath`.
  QPainter desenha igual em GPU e em software. É a peça que fez a capa arredondar de verdade.
- **Sombra empilhada**: oito molduras translúcidas cada vez maiores, em vez de um desfoque —
  desfoque é shader, e shader é exatamente o que não sobrevive à captura.
- **`tools/check-fidelidade.sh`**: mede a COR da tela ponto a ponto contra os hex do desenho,
  com tolerância de 3 níveis por canal, e confere que o canto da capa não é arte. Pegou um
  defeito real na primeira execução (o fundo preto da tela vazia).

### O alvo de pintura também faz parte da máscara

Em 31/08, a máscara continuava correta, mas os arcos da arte real mostravam degraus. O
`RoundedImage` habilitava antialiasing e, ao mesmo tempo, forçava
`QQuickPaintedItem::FramebufferObject`. No Qt, FBO favorece pintura OpenGL contínua em troca
de qualidade de antialiasing; `Image` usa o rasterizador de alta qualidade e é também o alvo
indicado para itens redimensionados. O placeholder já seguia esse caminho.

A correção foi alinhar a arte real ao alvo `Image`, sem supersampling e sem shader. Isso não
reintroduz rasterização contínua: a capa só repinta quando a fonte muda ou quando o debounce
de resize termina; opacidade e crossfade continuam sendo composição da textura pronta. O
teste de `RoundedImage` agora trava as duas partes do contrato: alvo raster de alta qualidade
e presença de pixels com cobertura parcial nos quatro arcos. Testar apenas se o pixel do canto
é transparente prova o formato, mas não prova que a curva entre o canto e a borda é lisa.

## A lição que fica

`check-layout` mede a moldura e passa verde com a paleta inteira errada. **Um gate que só mede
geometria atesta que a tela tem o tamanho certo, nunca que ela é o desenho.** Redesenho agora
roda `bash tools/check-fidelidade.sh` junto com `check-orfaos`: um garante que a funcionalidade
não sumiu da tela, o outro que a tela ainda é a que foi aprovada.
