# Gate final de renderização e fila — 2026-09-01

## Problema fechado

A fatia precisava provar em conjunto que o halo deixa de animar quando não pode ser visto, que
a carga/reordenação de filas grandes não reinicia a faixa e que essas mudanças não compraram
uma regressão de startup, memória ou scroll. A prova precisava repetir a geometria de
2560×1440 usada em 29/08 sem abrir nem escrever no banco, configuração ou cache reais.

## Harness reproduzível

`tools/measure-perf-final.sh` abre o banco real com `sqlite3 -readonly`, faz um backup consistente
para um XDG temporário e executa o binário sempre contra essa cópia. O processo medido usa áudio
nulo e o PID lido em `/proc` é o PID direto do `melodarium`, não o de um subshell.

Comando final, no compositor usado pela medição histórica:

```bash
quiet-run env MELODARIUM_PERF_PLATFORM=wayland \
  bash tools/measure-perf-final.sh ./build/melodarium
```

Para repetir apenas um estado durante investigação:

```bash
quiet-run env MELODARIUM_PERF_PLATFORM=wayland \
  MELODARIUM_PERF_STATE_ONLY=stopped \
  bash tools/measure-perf-final.sh ./build/melodarium
```

O probe QML `--measure-scroll` move o `ListView` real da biblioteca por 3,5 s e coleta
`FrameAnimation.frameTime`. O probe do halo espera `AudioEngine.currentFile` e o estado de pause
observado pelo mpv antes de começar; timers absolutos davam falso “pausado” em render lento.

## Contexto e resultados

- Fedora 43, Qt 6.10.3, libmpv 0.40, Wayland/Hyprland.
- Geometria solicitada: 2560×1440, igual à série de 29/08.
- Fonte: snapshot somente leitura da base real, hoje com 247 faixas ativas.
- CPU: soma de `utime+stime` de `/proc/<pid>/stat`; nesta máquina, 100 ticks equivalem a um
  núcleo por segundo. Janela de 20 s após 5 s de aquecimento.
- PSS: `Pss` de `/proc/<pid>/smaps_rollup` após o aquecimento.

| Medida | Resultado |
|---|---:|
| Startup frio de processo, 5 amostras | 1318, 1292, 1259, 1280, 1257 ms; mediana **1280 ms** |
| Startup quente de processo, 5 amostras | 1273, 1263, 1274, 1233, 1255 ms; mediana **1263 ms** |
| CPU parada, 3 amostras | 9,90; 0,80; 0,05 ticks/s; mediana **0,80 ticks/s** |
| PSS parada, 3 amostras | 239907; 236233; 236674 kB; mediana **236674 kB** |
| CPU pausada | **1,65 ticks/s**, PSS 262796 kB |
| CPU tocando com halo | **7,85 ticks/s**, PSS 262083 kB |
| Scroll real, 217 quadros | média **16,193 ms**, p95 **16,783 ms**, máximo 56,643 ms |
| Distância percorrida no scroll | 8693 px |

Provas de estado do halo na mesma execução:

```text
HALO_ACTIVITY state=stopped active=off frame=retained delta=0.000
HALO_ACTIVITY state=paused  active=off frame=retained delta=0.000
HALO_ACTIVITY state=playing active=on  frame=retained delta=0.822
```

A primeira amostra parada, 9,90 ticks/s, foi mantida no registro. Duas repetições deram 0,80 e
0,05; por isso a comparação usa a mediana das três, em vez de apagar o outlier. O p95 de scroll
fica praticamente no orçamento de 16,67 ms de 60 Hz; o máximo isolado continua visível no dado.

## Decisões que devem sobreviver à sessão

1. Benchmark visual comparável roda no Wayland real. `QT_QPA_PLATFORM=offscreen` usa o
   rasterizador de software e nesta geometria produziu p95 de 146,984 ms, portanto serve para
   gates determinísticos de pixel, não para decidir performance de frame.
2. Prova de pause espera o estado observado. Em 2560×1440, pausar 1300 ms após o startup podia
   acontecer antes do carregamento e o mpv começava a faixa depois, invalidando a medição.
3. CPU/PSS exigem o PID direto do binário. Função Bash em background pode deixar `$!` apontando
   para o subshell e criar uma corrida quando ele termina.
4. “Frio” aqui significa processo e XDG novos. Não há `drop_caches`, porque isso exigiria root e
   afetaria o sistema inteiro; o cache de páginas do kernel permanece aquecido.
5. O benchmark nunca usa os caminhos reais para escrita. Banco, configuração e cache são
   clonados para `mktemp` e removidos no fim.

## Limites honestos

O arquivo real medido em 29/08 tinha 27 faixas e não foi preservado como fixture imutável. O
mesmo caminho de banco contém 247 faixas em 01/09. A geometria e a máquina são as mesmas, mas a
carga de dados não é idêntica; números de startup, PSS e scroll não devem ser apresentados como
comparação A/B estrita com a série antiga. A medição de PSS pausada/tocando tem uma amostra por
estado; a parada foi repetida porque a primeira observação foi discrepante.

## Gates da fatia

Executados após a implementação:

```text
cmake -B build -G Ninja                         exit 0
cmake --build build                             exit 0
ctest -N                                       26 testes (piso >= 26)
ctest --test-dir build --output-on-failure      26/26, 0 falhas, 88,16 s
bash tools/check-halo-activity.sh               exit 0, quatro estados corretos
bash tools/check-orfaos.sh                      exit 0, zero órfãos
bash tools/check-layout.sh                      exit 0
bash tools/check-fidelidade.sh                  exit 0
```

A aprovação visual humana continua pendente; ela não é inferida desses números.
