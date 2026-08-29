---
title: A janela saía em 16 bits, e a culpa parecia ser da paleta
category: ui
module: src/main.cpp, src/Theme.qml
symptoms:
  - o usuário vê tons esverdeados onde o tema define cinza neutro
  - conta-gotas na tela lê #101410 onde o QML pinta #151515
  - o degradê do painel não aparece; parece cor chapada com dois degraus duros
  - todos os gates de cor passam verdes enquanto a tela está errada
tags: [qt, qml, wayland, cor, rgb565, egl, gate-cego]
---

# O que era

A janela do app era entregue ao compositor em **RGB565** — 5 bits de vermelho, 6 de verde,
5 de azul — em vez de 8 bits por canal. O verde tem o dobro de degraus dos outros dois, então
todo cinza neutro do tema chegava à tela com **R igual a B e G acima**: `#151515` virava
`#101410`. A mesma quantização achatava a escada de cinzas: o degradê do painel, de 9 níveis,
colapsava em 3, porque `#1a1a1a` e `#191919` caem no mesmo degrau, e `#131313` e `#111111`
também.

A causa: `QSurfaceFormat` nasce com os tamanhos de canal em `-1` ("tanto faz"), e a regra de
desempate do `eglChooseConfig` prefere o menor buffer que atenda ao pedido. Sob NVIDIA +
Wayland, isso devolve uma config de 16 bits.

# O conserto

Em `src/main.cpp`, **antes** de construir o `QGuiApplication`:

```cpp
QSurfaceFormat fmt = QSurfaceFormat::defaultFormat();
fmt.setRedBufferSize(8);
fmt.setGreenBufferSize(8);
fmt.setBlueBufferSize(8);
fmt.setAlphaBufferSize(0);   // opaca de propósito: pedir alfa aciona o blur do compositor
QSurfaceFormat::setDefaultFormat(fmt);
```

Medido na janela real, mesmo compositor e mesma geometria: pixels não-neutros caem de
**33,41% para 0,15%**, pixels na grade 565 caem de **99,99% para 3,18%**, `#151515` chega
exato, e o degradê do painel volta de **3 para 10 níveis**. O formato do buffer, visto no
protocolo Wayland, passa de fourcc `RG16` (stride 2560) para `XR24` (stride 5056).

Diagnóstico em um comando:

```bash
WAYLAND_DEBUG=1 ./build/melodarium --measure 1264 --shot /dev/null --delay 1200 2>&1 \
  | grep -m1 create_immed
# 909199186 = "RG16" = RGB565  (defeito)  ·  875713112 = "XR24" = XRGB8888  (correto)
```

# O que NÃO funcionou

- **Suspeitar da paleta.** A paleta estava certa o tempo todo. Duas sessões foram gastas
  reescrevendo cores por causa de um sintoma que não vinha delas.
- **Suspeitar do filtro de luz azul da tela** (`hyprsunset -t 4200`). Desligar não mudou nada.
  A conta batia no papel — cinza sem azul é oliva — e mesmo assim era a causa errada.
- **Suspeitar da transparência de janela inativa** (`inactive_opacity 0.97`) e do blur.
  Medido com e sem foco: neutro nos dois.
- **Suspeitar do monitor ou do conta-gotas.** Um PNG de teste com `#151515` puro, aberto na
  mesma tela, mediu exato. O monitor e a ferramenta estavam certos.
- **Confiar no auto-retrato do app (`--shot`) e nos gates de cor.** É o erro estrutural desta
  lição: com `QT_QPA_PLATFORM=offscreen` o Qt usa o rasterizador de software, que é sempre 8
  bits. O gate mede o que o app *desenha*, nunca o que o compositor *recebe* — então ele marca
  10 de 10 pontos certos com a tela visivelmente errada. **Qualquer gate que fotografe o app
  por dentro é cego para profundidade de cor, formato de superfície e composição.** Só medir a
  janela real, por captura do compositor, separa os dois mundos.
- **Medir pontos avulsos da janela composta.** Deu neutro e quase enterrou a investigação: os
  pontos escolhidos calhavam de cair em cores que sobrevivem à quantização. O que resolveu foi
  medir a distribuição inteira e perguntar quantos pixels caem na grade 565 — 99,99% contra
  0,17% no resto do monitor não deixa dúvida.
