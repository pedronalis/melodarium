# Medições — o app queimava um núcleo parado (29/08/2026)

Branch `exec/perf-redesenho`. Todas as medições feitas na máquina do Pedro (i9-10900k,
RTX 3080 Ti, NVIDIA 580.178.04, Fedora 43, Hyprland 0.56.2, Wayland, Qt 6.10.3, mpv/libmpv
0.40.0), na sessão gráfica real — não em offscreen.

## Como cada número foi tirado

- **Consumo**: `utime + stime` do `/proc/<pid>/stat` (campos 14 e 15) antes e depois, dividido
  pelos segundos. Um "tick" = 1/100 s de CPU; **100 ticks/s = um núcleo inteiro**.
- **PID**: sempre `pgrep -x melodarium` (ou `-x mpv`). `pgrep -f` casa com o próprio shell do
  comando e devolve o PID errado.
- **Por thread**: mesmo cálculo em `/proc/<pid>/task/*/stat`, que é o que separou o culpado do
  resto do app.
- **Tamanho da janela**: lido do compositor (`hyprctl clients -j`) DEPOIS de medir, e anotado
  em toda linha. Onde diz `2560x1440`, a janela foi levada a tela cheia
  (`hyprctl dispatch 'hl.dsp.window.fullscreen()'`); onde diz `1264x1384`, ela caiu no
  ladrilho ao lado de outra janela.
- **Quadros por segundo**: contagem das linhas `syncAndRender` com `QSG_RENDER_TIMING=1` e
  `QT_LOGGING_TO_CONSOLE=1` (sem esta segunda variável a saída do Qt vai para o journal e o
  arquivo de log fica vazio).
- Warmup padrão: 15 s antes de começar a contar (nas primeiras medições foi 6–10 s, e isso
  contaminou T2 — ver a nota no fim).

**Gatilho.** As linhas marcadas `clipboard: PNG 11,7 MiB` foram medidas com uma imagem grande
na área de transferência. Essa é a condição que faz o defeito aparecer; sem ela, o mesmo
binário mede zero. Ver `docs/solutions/perf/2026-08-29-redesenho-continuo.md`.

## A tabela

| # | Cenário | Comando | Janela | Clipboard | Resultado |
|---|---------|---------|--------|-----------|-----------|
| M1 | App parado, sem música | `./build/melodarium` | 1264x1384 | PNG grande | **99,2 ticks/s** |
| M2 | QML mínimo (um `Rectangle`), mesmo ambiente | `/usr/lib64/qt6/bin/qml /tmp/perf-run/minimo.qml` | 1264x1384 | PNG grande | **0,1 ticks/s** |
| T1 | M1 medido por thread | `./build/melodarium` | 1264x1384 | PNG grande | 99,8 numa thread só (`user=484 sys=1511`); principal 0,3 |
| T1b | Repetição de T1 | `./build/melodarium` | 1264x1384 | PNG grande | 99,7 na mesma thread (`user=496 sys=1498`) |
| Q1 | Quem é a thread quente | `eu-stack -p <pid>` | 1264x1384 | PNG grande | `ppoll` ← `mp_poll` ← `clipboard_thread` (libmpv) |
| Q2 | Q1 repetido 12 vezes | `eu-stack -p <pid>` ×12 | 1264x1384 | PNG grande | 12/12 amostras na mesma pilha |
| P1 | libmpv sozinho, sem janela, sem som | `mpv --idle=yes --video=no --vo=null --ao=null --no-terminal` | sem janela | PNG grande | **99,7 ticks/s** |
| P2 | P1 sem nenhum backend de clipboard | `mpv --clipboard-backends= --idle=yes --video=no --vo=null --ao=null --no-terminal` | sem janela | PNG grande | **0,0 ticks/s** |
| P3 | P1 só com o backend Wayland | `mpv --clipboard-backends=wayland --idle=yes …` | sem janela | PNG grande | **99,5 ticks/s** |
| P4 | P1 só com o backend `vo` | `mpv --clipboard-backends=vo --idle=yes …` | sem janela | PNG grande | **0,0 ticks/s** |
| R1–R3 | P1, três vezes, depois que o Chrome tomou a área de transferência | igual a P1 | sem janela | texto | 0,0 · 0,0 · 0,0 |
| S1 | P1 durante 64 s, em 8 janelas de 8 s | igual a P1 | sem janela | texto | 0,0 nas oito |
| C1 | P1 com texto curto na área de transferência | `wl-copy 'teste-melodarium'` antes | sem janela | texto | 0,0 ticks/s |
| C2 | P1 com a área de transferência vazia | `wl-copy --clear` antes | sem janela | vazio | 0,0 ticks/s |
| W1–W3 | App parado, três vezes, com o gatilho desarmado | `./build/melodarium` | 1264x1384 | texto | 0,0 · 0,0 · 0,0 |
| F1 | App parado, tela cheia, gatilho desarmado | `./build/melodarium` | 2560x1440 | texto | 0,0 ticks/s |
| F2 | F1 com transições desligadas | `./build/melodarium --sem-animacao` | 2560x1440 | texto | 0,0 ticks/s |
| **X1** | **libmpv sozinho, antes e depois de copiar um PNG de 11,7 MiB** | `mpv --idle=yes …` + `wl-copy --type image/png < grande.png` | sem janela | texto → PNG grande | **0 → 99,0 ticks/s** |
| X2 | X1 sem backend de clipboard | `mpv --clipboard-backends= --idle=yes …` | sem janela | texto → PNG grande | **0 → 0,0 ticks/s** |
| X3 | App **sem** o conserto, gatilho armado | `./build/melodarium` | 1264x1384 | PNG grande | **99,8 ticks/s** |
| **Y1** | **App COM o conserto, mesmo gatilho armado** | `./build/melodarium` | 2560x1440 | PNG grande | **0,0 ticks/s em 30 s** |
| Z1 | App com o halo aceso (a luz da capa) | `./build/melodarium --halo-teste` | 2560x1440 | PNG grande | 4,9 ticks/s |
| Z2 | Z1 com as animações desligadas | `./build/melodarium --halo-teste --sem-animacao` | 2560x1440 | PNG grande | 0,0 ticks/s |
| G1 | App parado no laço `threaded` | `QSG_RENDER_LOOP=threaded ./build/melodarium` | 2560x1440 | PNG grande | 0,0 ticks/s |
| G2 | Halo aceso no laço `threaded` | `QSG_RENDER_LOOP=threaded ./build/melodarium --halo-teste` | 2560x1440 | PNG grande | 10,3 ticks/s (`QSGRenderThread` = 6,5) |
| G3 | Halo aceso com Vulkan | `QSG_RHI_BACKEND=vulkan ./build/melodarium --halo-teste` | 2560x1440 | PNG grande | 5,0 ticks/s |
| N1 | Quadros desenhados com o app parado | `QT_LOGGING_TO_CONSOLE=1 QSG_RENDER_TIMING=1 ./build/melodarium` | 2560x1440 | PNG grande | **2 quadros em 20 s** |
| N2 | Quadros desenhados com o halo aceso | idem + `--halo-teste` | 2560x1440 | PNG grande | **1206 quadros em 20 s = 60 fps** |
| N3 | Laço e backend escolhidos pelo Qt | `QSG_INFO=1` | 2560x1440 | — | `basic render loop`, `sg animation driver`, `QRhi backend OpenGL` |

## Duas medições que enganam, e por quê

- **T2 = 22,3 ticks/s** (app com o conserto, warmup de 8 s). Não é consumo em repouso: é a
  carga inicial (lista, capas, banco) ainda em andamento. Com 15 s de warmup o mesmo binário
  mede 0,0 (Y1, F1, G1). **Toda medição de repouso precisa de warmup ≥ 15 s.**
- **M1 a 1264x1384 = 99,2 e o briefing a 2540x1384 = ~99.** Áreas de tela bem diferentes com o
  mesmo número: o custo não vinha de pintar pixel nenhum. Foi essa igualdade que apontou para
  fora do renderizador.
