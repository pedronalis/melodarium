---
title: Um núcleo queimado com o app parado — era a thread de área de transferência do libmpv, não a tela
category: perf
module: audioengine.cpp
symptoms:
  - "o app parado, sem música, consome ~99 ticks/s de CPU (um núcleo inteiro)"
  - "QSG_RENDER_TIMING mostra perWindowFrameDelta=16 e frame rendered in 0-1ms"
  - "QSG_VISUALIZE=changes não colore área nenhuma: nada muda e mesmo assim parece redesenhar"
  - "o consumo aparece e some sozinho, e não muda com o tamanho da janela"
  - "o mesmo consumo aparece em commits anteriores a qualquer animação"
tags: [mpv, libmpv, wayland, clipboard, cpu, qtquick, scenegraph, hyprland]
---

## O sintoma

O melodarium aberto e parado — sem música, sem ninguém mexendo — queimava **~99 ticks/s**, ou
seja, um núcleo inteiro. O `QSG_RENDER_TIMING` mostrava quadros de 16 em 16 ms (60 fps), e o
`QSG_VISUALIZE=changes` não pintava nada: a leitura óbvia era "a cena redesenha sessenta vezes
por segundo sem nada mudar".

**Essa leitura estava errada.** O renderizador não era o pagador.

## O que era

O `AudioEngine` cria uma instância de **libmpv**. O libmpv 0.40 sobe uma
`clipboard_thread` mesmo num player sem vídeo e sem janela, e o backend Wayland dessa thread
entra em laço apertado de `ppoll` quando existe um **dado grande na área de transferência** —
uma captura de tela, uma imagem colada. Bug conhecido, mpv issue
[#16139](https://github.com/mpv-player/mpv/issues/16139), aberto contra a 0.40.0.

O perfil de consumo denunciava a natureza do gasto antes de a pilha ser lida: `user=484
sys=1511` — três quartos em kernel. Renderizar não gasta assim; um `ppoll` que volta na hora,
sim.

Prova por bissecção, tudo no mesmo minuto, com o mesmo PNG de 11,7 MiB na área de
transferência (`MEDICOES.md`, linhas P1–P4 e X1–X2):

| o que rodou | ticks/s |
|---|---|
| `mpv --idle --vo=null --ao=null` (sem janela, sem som) | **99,7** |
| o mesmo com `--clipboard-backends=wayland` | **99,5** |
| o mesmo com `--clipboard-backends=vo` | **0,0** |
| o mesmo com `--clipboard-backends=` (nenhum) | **0,0** |

E a mesma coisa nos dois lados do conserto, com o gatilho armado: app sem o conserto **99,8
ticks/s**; app com o conserto **0,0 ticks/s em 30 s**.

## O conserto

Uma linha em `src/audioengine.cpp`, antes do `mpv_initialize`:

```cpp
setOptionString("clipboard-backends", "");
```

Um tocador de música não lê nem escreve a área de transferência. Lista vazia mata a thread e a
conexão Wayland que ela abria. Nomes de opção desconhecidos são ignorados pelo libmpv, então
uma libmpv mais velha, sem essa opção, continua funcionando.

## E o redesenho de 60 fps, existia?

Não com o app parado. Medido depois, com `QT_LOGGING_TO_CONSOLE=1 QSG_RENDER_TIMING=1`:

- app parado: **2 quadros em 20 s**;
- app com o halo da capa aceso (`--halo-teste`): **1206 quadros em 20 s**, isto é 60 fps de
  verdade — e custam **4,9 ticks/s**, cinco por cento de um núcleo.

Ou seja: os 60 fps que o briefing viu eram do halo (ou de uma transição em curso), e nunca
foram a conta de um núcleo. O halo animado é caro por escolha de projeto, não por defeito —
com `--sem-animacao` cai a 0,0.

De quebra: no laço `threaded` o mesmo halo custa 10,3 ticks/s (o dobro, porque o laço segue os
165 Hz do monitor em vez dos 60 do temporizador do laço `basic`), e trocar para Vulkan não
muda nada (5,0 contra 4,9).

## O que NÃO funcionou

- **Culpar o laço de renderização.** `QSG_INFO=1` confirma `basic render loop` + `sg animation
  driver` + `QRhi backend OpenGL`, e havia relato de o `basic` desenhar por temporizador sem
  vsync. Verdade sobre o laço, irrelevante aqui: com o conserto, `basic` e `threaded` medem
  **0,0** com o app parado.
- **Culpar o backend gráfico.** `QSG_RHI_BACKEND=vulkan` abre 32 descritores de GPU contra
  zero e não muda um tick.
- **Amostrar a pilha com `eu-stack` e olhar só o frame de cima.** As 21 threads apareciam
  100% em `__syscall_cancel_arch`, o que fazia parecer que ninguém estava trabalhando. O frame
  de cima de um `ppoll` em laço apertado é indistinguível do de um `ppoll` que dorme — o que
  separa os dois é o `stime`, não a pilha.
- **`pgrep -f "build/melodarium"`.** Casa com o próprio shell do comando e devolve o PID
  errado; já produziu três medições falsas de "0 ticks/s". Sempre `pgrep -x melodarium`.
- **`setsid` para lançar o processo medido.** Ele forka, `$!` vira o PID do pai que morre na
  hora, e o número é reciclado por outro processo — a primeira leva de pilhas veio de um
  processo Lua que nada tinha a ver com o app.
- **Comparar medições de tamanhos de janela diferentes.** O Hyprland ladrilha, e a mesma linha
  de comando abre a 1264x1384 ou a 2560x1440 conforme o que já estiver na área de trabalho.
  Aqui isso não escondeu o defeito (ele não depende de área), mas foi o que quase o escondeu:
  áreas muito diferentes davam o MESMO número, e era esse empate que apontava para fora do
  renderizador.
- **Medir com warmup curto.** Com 8 s de warmup o app "consome 22 ticks/s"; com 15 s, 0,0. Os
  22 eram a carga inicial da lista e das capas, não repouso.
- **Procurar o gatilho na área de transferência por tentativa.** Texto curto: 0,0. Área
  vazia: 0,0. Trocar de dono: 0,0. Só **dado grande** dispara — e foi o issue do mpv que
  disse qual era a variável, não a busca às cegas.
- **Achar que o defeito tinha sumido.** Entre uma leva de medições e outra o número caiu
  sozinho de 99 para 0 e ficou assim por quinze minutos, o que quase virou "não reproduz". O
  que mudou foi o conteúdo da área de transferência do sistema, não o app.

## Como reproduzir em trinta segundos

```bash
mpv --idle=yes --video=no --vo=null --ao=null --no-terminal &   # some com ele depois
pid=$(pgrep -x mpv)
awk '{print $14+$15}' /proc/$pid/stat                # ~0
wl-copy --type image/png < uma-imagem-de-varios-MB.png
sleep 10; awk '{print $14+$15}' /proc/$pid/stat      # +1000 ticks: um núcleo
```
