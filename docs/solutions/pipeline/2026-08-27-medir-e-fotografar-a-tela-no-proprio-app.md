---
title: Medir e fotografar a tela pelo próprio app (--measure e --shot)
category: pipeline
module: Main.qml, tools/check-layout.sh
symptoms:
  - "fidelidade ao desenho vira opinião: 'parece certo' contra 'está cortado'"
  - "layout quebra em janela estreita e ninguém percebe até o usuário abrir"
  - "run headless não consegue comparar a tela com o desenho aprovado"
tags: [qml, qt, offscreen, gate, layout, screenshot, grabToImage]
---

## O problema

O desenho aprovado (`design/*.dc.html`) traz medidas exatas — barra 56, painel 392, capa
quadrada, overlay 660x520. Um run headless não tem olho: ou alguém descreve a tela em prosa,
ou o layout só é conferido quando já está errado na frente do usuário.

## O que funciona

Duas opções de linha de comando no próprio app, ativas só quando pedidas:

- `--measure [largura]` — monta a tela, imprime **uma** linha e sai:

  ```
  MEDIDA rail=56 painel=392 miolo=652 capa=340x340 janela=1100x700 chips=530 chipsvao=604 busca=660x520 motor=ok
  ```

  A largura como argumento é o que permite medir **na janela mínima** também, que é onde o
  layout quebra. Foi assim que apareceu que a linha de filtros pedia 532 px num vão de 364.

- `--shot <arquivo.png>` — `root.contentItem.grabToImage(...)` + `saveToFile`. Funciona sob
  `QT_QPA_PLATFORM=offscreen`, sem compositor, e o PNG pode ser lido direto pelo agente.

`tools/check-layout.sh` roda as duas passadas (nominal e mínima) e falha se qualquer medida
sair do desenho — layout torto vira erro de gate, não relato de usuário.

Para fotografar estados que dependem de dados, dá para redirecionar o banco inteiro sem tocar
no do usuário:

```bash
XDG_DATA_HOME=/tmp/md/data XDG_CONFIG_HOME=/tmp/md/cfg ./build/appmelodia --measure 1100 --shot /tmp/tela.png
```

O app cria e migra o banco no primeiro arranque; depois é só semear com `sqlite3`. Somando
`--pane`, `--play-track` e `--play-episode`, cada tela do desenho vira uma foto reproduzível.

## Armadilhas

- `console.log` só aparece com `QT_LOGGING_RULES="*.debug=true"` e `QT_FORCE_STDERR_LOGGING=1`.
- O `StackLayout` só dá largura ao filho visível: no modo de medição, force o painel que você
  quer medir, senão o que está no banco da máquina muda o resultado do gate.
- Abrir arquivo no mpv leva mais que montar a tela — daí `--delay`.
- Sem placa de som (offscreen), `MELODIA_NULL_AO=1` faz o mpv usar `ao=null`; sem isso nada
  toca e a foto sai com "nada tocando".

## O que NÃO funcionou

- `grim`/compositor: o run headless não tem sessão gráfica; a captura tem de sair de dentro
  do app.
- Medir só na janela nominal: a quebra estava na mínima.
- Confiar no `implicitWidth` de um `RowLayout` aninhado como se ele encolhesse — ele
  **transborda** o pai em silêncio, e só a comparação `chips` × `chipsvao` mostra isso.
