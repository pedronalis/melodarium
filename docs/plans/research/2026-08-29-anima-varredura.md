---
title: Varredura de oportunidades de animação
data: 2026-08-29
feature: melodarium-anima
---

# Varredura de animação — o que anima, o que não anima, e por quê

Artefato de research do lote `melodarium-anima`. É a autoridade dos **valores** (durações,
curvas, escalas) e da **lista de rejeitados**: quando um plano diz "§ Rejeitados", é aqui.

## Restrições do repo que decidem o que é possível

1. **Shader não existe neste app.** `docs/solutions/ui/2026-08-28-a-tela-passava-nos-gates-e-nao-era-o-desenho.md`:
   `MultiEffect` funciona na tela do usuário e **não desenha nada** no adaptador de software —
   e é assim que o app é fotografado e como ele roda numa máquina sem GPU. Não é degradação:
   a capa **some**. Todo efeito daqui sai de `Rectangle`, `Canvas` ou `QPainter`.
2. **A foto do gate é tirada num instante fixo.** `tools/check-fidelidade.sh` roda
   `--measure ... --delay 1800` e mede 15 pontos com tolerância de 3 níveis por canal.
   Qualquer animação de entrada pode ser fotografada no meio; qualquer efeito cuja cor venha
   do acervo de quem roda torna o gate indeterminístico. Por isso existe a fatia
   `movimento-interruptor`.
3. **O ponto `("painel: topo do degradê", "biblioteca", (70, 8), "#1a1a1a")` é vizinho da
   capa.** A capa começa em y=24. Um halo com alcance real cobre y=8. É por isso que o halo
   desliga sob `--measure` (`Theme.medindo`), e não por acaso.

## Vocabulário de movimento (fonte dos números)

| Papel | Token | ms | Curva |
| --- | --- | --- | --- |
| Cross-fade de glifo, press feedback | `animationFaster` | 75 | OutCubic |
| Hover, barra de volume, entrada de texto | `animationFast` | 150 | OutCubic |
| Cross-fade da capa | `animationNormal` | 300 | OutCubic |
| — | `animationSlow` | 450 | OutCubic |
| Cross-fade da cor do halo | `animationSlowest` | 750 | OutCubic |
| Pulo do coração (subida) | `animationPop` | 120 | OutBack, overshoot 2.5, até 1.3 |
| Pulo do coração (volta) | `animationPopBack` | 140 | OutCubic |

## As 6 aprovadas

| # | Onde | Hoje | Propósito | Frequência | Fatia |
| --- | --- | --- | --- | --- | --- |
| 1 | Fundo da capa no painel | Fundo fixo, capa sobre nada | Ambiente + suavizar troca | A cada faixa | `painel-acompanha` |
| 2 | Troca de faixa (capa + títulos) | Tudo salta de golpe | Evitar mudança brusca | A cada faixa | `painel-acompanha` |
| 3 | Coração (lista e painel) | Glifo troca instantâneo | Feedback | Ocasional | `coracao-comemora` |
| 4 | Botão play/pause | Sem resposta ao toque | Feedback | Dezenas/dia | `transporte-responde` |
| 5 | Barra e ícone de volume | Barra teleporta | Evitar mudança brusca | Ocasional | `transporte-responde` |
| 6 | Tela "nada tocando" | Aparece chapada | Encanto (tier raro) | Abertura | `vazio-recebe` |

## Rejeitados — e o motivo que os matou

- **Busca (Ctrl+K)** `SearchOverlay.qml` — abre pelo teclado, dezenas de vezes por dia.
  Animação transforma gesto instantâneo em espera. Raycast não anima de propósito.
- **Overlay da fila** `QueueOverlay.qml` — mesma gramática de painel flutuante que a busca
  (o comentário no topo do arquivo diz isso). Um animar e o outro não é duas regras.
- **Trocar de seção / de filtro** (trilho, chips, `StackLayout.currentIndex`) — navegação
  central, dezenas de vezes por dia.
- **Entrada escalonada das linhas da lista** — até 1.200 linhas, e a lista é o ponto da tela.
- **`NextUpCard` aparecendo/sumindo ao redimensionar** — a altura dele sai de uma conta que o
  próprio código avisa que "se morderia". Animá-la reabre o laço que o autor fechou à mão.
- **"varrendo…" piscando** — animação em laço para dizer o que as reticências já dizem.
- **Halo pulsando no ritmo** — o mpv não entrega espectro sem trabalho pesado, e fundo que se
  mexe permanentemente é a primeira coisa que se desliga.
- **Barra de progresso da faixa** — dado que o usuário lê, e que já se move sozinho.

## Achado colateral (fora do lote)

`IconButton.qml:10` declara `property string tooltip` que **oito lugares preenchem** e que
nenhum `ToolTip` renderiza — não existe `ToolTip` no app inteiro. Não é animação; fica
registrado para virar fatia própria se o Pedro quiser.
