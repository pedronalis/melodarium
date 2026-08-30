---
title: Resize fluido sem baixar a qualidade — conservar o raster pronto até a geometria estabilizar
category: perf
module: NowPlayingPanel.qml
symptoms:
  - "arrastar a borda horizontal da janela atrasa a atualização da interface"
  - "qt_image_boxblur aparece em todas as amostras da thread da interface durante o resize"
  - "a capa, a sombra e o placeholder são reconstruídos a cada passo intermediário"
tags: [qtquick, qml, resize, canvas, blur, image, wayland, performance]
---

## O sintoma

Numa janela alta, arrastar a borda horizontal muda `Theme.uiScale`. Cada passo intermediário
recriava trabalho raster caro no thread da interface: duas sombras idênticas da capa, o dither
do placeholder e, com arte presente, o decode da imagem na nova resolução.

Na reprodução isolada de 70 mudanças de largura entre 1100 e 1800 px, mantendo 1300 px de
altura e 30 ms entre eventos, o processo consumia **425 ticks de CPU**. Em quatro amostras com
`eu-stack`, quatro pararam em `qt_image_boxblur`/`qt_image_convolute_filter` chamado pelo
`Canvas` da sombra.

## A regra que resolveu

Durante uma rajada de geometria, a imagem completa que já está na tela continua sendo a fonte
visual. Ela pode ser escalada pelo scene graph, com filtragem suave, enquanto um timer de 120
ms é reiniciado. Quando o tamanho para de mudar, acontece **uma** reconstrução exata na medida
final.

Isso foi aplicado em três pontos:

- `CoverShadow.qml` mantém uma única sombra compartilhada fora das duas capas do crossfade e
  só rasteriza novamente quando blur, deslocamento, raio e tamanho estabilizam;
- `GradientBlock` conserva o dither pronto durante a rajada e refaz tamanho e máscara exatos
  no fim;
- `RoundedImage` conserva a arte decodificada e pede uma resolução exata uma única vez no fim.

A qualidade final não foi reduzida: blur, deslocamento, raio, dither e decode continuam usando
as fórmulas e a resolução originais. O debounce muda somente **quando** o trabalho ocorre, não
o resultado em repouso.

## Evidência

- A mesma rajada no backend XCB caiu de **425 para 228 ticks** (menos 46%).
- Em Wayland/Hyprland, o binário final atravessou 70 resizes direcionados e terminou com a
  geometria correta; a rajada consumiu 53 ticks.
- Depois da mudança, as amostras da thread da interface não passam mais pelo box blur nem pela
  reconstrução do gradiente durante o arraste.
- Screenshots frescos em 1100×700 e 1800×1300 diferem da referência somente dentro do
  placeholder aleatório, por no máximo **2/255 por canal**. Fora do retângulo da capa — sombra
  incluída — não há pixel diferente.
- `tst_gradientblock`, `tst_roundedimage` e `check-resize-shadow.sh` fixam o comportamento; o
  último também fixa em texto as equações visuais originais da sombra.

## Armadilhas

- Debounce sem conservar o raster pronto faz o componente sumir ou mostrar uma área vazia.
- Debounce no primeiro carregamento atrasa a primeira pintura. Só uma geometria que já tem
  imagem completa pode esperar.
- Normalizar os parâmetros da sombra por outra escala altera o desenho. A sombra compartilhada
  deve conservar as equações antigas, inclusive o fator interno baseado em 340 px.
- Dois `Canvas` visualmente sobrepostos continuam pagando dois box blurs, mesmo quando o de trás
  está coberto. O efeito comum pertence ao contêiner do crossfade, não a cada face.
