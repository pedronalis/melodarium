---
title: A foto de gate não clica — para conferir clique de verdade, Xvfb sem --measure
category: pipeline
module: tools/, src/Main.qml
symptoms:
  - "a captura sai 100% preta e o log do app está vazio"
  - "xdotool não encontra janela nenhuma do melodarium"
  - "a tela nova compila, passa nos gates e ninguém sabe se o botão que a abre funciona"
tags: [screenshot, xvfb, xdotool, gate, qml]
---

## O que aconteceu

Uma tela nova (o explorador de pastas) nasce fechada atrás de um botão dentro de outro
diálogo. As duas perguntas são diferentes e precisam de ferramentas diferentes:

1. **"A tela está pintada com as cores certas?"** → foto de gate: `--shot` + a flag que abre
   a tela (`--open-settings`, `--open-folder-picker`). Roda em `QT_QPA_PLATFORM=offscreen`,
   é barata e entra no `check-fidelidade.sh`.
2. **"O botão que abre essa tela funciona, e o que se faz lá dentro chega no motor?"** → só
   clicando: `Xvfb` + `QT_QPA_PLATFORM=xcb` + `xdotool`.

O tropeço: a segunda foi tentada com `--measure` na linha de comando. **`--measure` imprime as
medidas e ENCERRA o app** — a janela nunca existiu, `import -window root` fotografou a tela
vazia do Xvfb (um retângulo preto) e o `xdotool search` não achou janela alguma. Nenhum erro
em lugar nenhum: um app que saiu com sucesso não tem o que reclamar.

## A receita que funciona

```bash
Xvfb :99 -screen 0 1400x900x24 &
# sem --measure: o app precisa CONTINUAR vivo para receber clique
XDG_DATA_HOME=/tmp/algo DISPLAY=:99 QT_QPA_PLATFORM=xcb ./build/melodarium &
sleep 5
DISPLAY=:99 xdotool mousemove 28 665 click 1     # a engrenagem
DISPLAY=:99 xdotool type --delay 20 "/media/SSD" # digitar num campo focado
DISPLAY=:99 xdotool key Return
DISPLAY=:99 import -window root /tmp/foto.png
```

`XDG_DATA_HOME` não é opcional quando o gesto testado **escreve**: confirmar uma pasta nova
dispara a varredura e reescreve a biblioteca de quem está na máquina. Com o banco isolado, o
mesmo gesto vira evidência limpa — `sqlite3 <db> "select count(*) from tracks"` respondeu 27.

## O que NÃO funcionou

- **`--measure` junto com o clique**: o app sai antes de haver janela. Foto preta, log vazio,
  nenhuma mensagem de erro.
- **`--open-settings` sem `--measure`**: as flags de abrir tela vivem DENTRO do bloco de
  medição do `Main.qml`; sem `--measure` elas não rodam. Fora do modo medição, chegue na tela
  clicando, como um usuário faria.
- **Confiar no build verde**: `qmlcachegen` compila QML com referência a `id` inexistente sem
  reclamar. Quem pega isso antes de rodar é o `qmllint-qt6 -I build/qml -I build src/*.qml` —
  e ele merece um canário (um arquivo com erro proposital) para provar que está mesmo
  analisando, senão "nenhuma saída" se lê como "tudo certo" quando é "não analisei nada".
