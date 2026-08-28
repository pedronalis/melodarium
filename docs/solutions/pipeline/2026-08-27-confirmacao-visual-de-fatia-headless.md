---
title: Fechar gate `decisao-humana` mostrando a tela, não pedindo descrição
category: pipeline
module: fluxo-de-execucao
symptoms:
  - "fatia com decisao-humana: sim fica pendente sessões a fio"
  - "run headless não tem tela e não consegue provar que a janela abriu certa"
  - "Pedro precisa descrever em palavras o que está vendo"
tags: [hyprland, wayland, grim, qt, gate-humano, decisao-humana]
---

## O problema

Fatia com `decisao-humana: sim` não fecha por teste automatizado — alguém precisa olhar. O run
headless roda sob `QT_QPA_PLATFORM=offscreen`, prova que o app sobe sem erro de QML e para aí.
O gate então vira uma pendência que atravessa sessões, e quando o Pedro finalmente olha, o
feedback chega em prosa ("parece um card dentro de uma tela") que ainda precisa virar diagnóstico.

## O que funciona

A sessão interativa roda no mesmo Wayland do usuário e consegue **subir o app e capturar a
janela** — o gate humano vira um ciclo de dois minutos, com a imagem na conversa:

```bash
# 1. subir o app (background do harness, não bloqueia a sessão)
./build/melodarium > /tmp/app.log 2>&1        # run_in_background: true

# 2. achar a geometria da janela pelo compositor
hyprctl clients -j | python3 -c "
import json,sys
for c in json.load(sys.stdin):
    if c.get('class')=='melodarium':
        x,y=c['at']; w,h=c['size']; print(f'{x},{y} {w}x{h}')
"

# 3. capturar só a janela
grim -g "2570,46 1264x1384" janela.png
```

Depois é `Read` na imagem (o modelo enxerga) e `SendUserFile` para o Pedro comparar com a tela
real. O ciclo inteiro — capturar, ele apontar o defeito, corrigir, rebuildar, recapturar,
commitar — levou ~10 minutos em 27/08 e fechou o gate da fatia `esqueleto-build`.

**Confirmar a paleta sem depender do olho:** o fallback de fábrica é azul-escuro (`#070722`) com
amarelo (`#fff59b`); a paleta real do usuário é cinza sobre preto. A cor na captura já diz qual
das duas está ativa, sem ninguém precisar julgar.

## O que NÃO funcionou

- **`pkill -f 'build/melodarium'`** — a string casa com a linha de comando do próprio shell que
  executa o `pkill`, então o comando se mata (exit 144) e o resto do bloco nunca roda. Usar
  `pkill -x melodarium`.
- **`QT_LOGGING_RULES="*.debug=true"` para conferir o start** — gera 845 KB de log de plugin do
  Qt num único start, que estoura qualquer leitura direta. Só ligar quando o alvo for depurar
  QML de verdade, e sempre com `grep` na saída.
- **`hyprctl monitors -j` com a chave `at`** — monitor não tem `at` (isso é de cliente); as
  coordenadas são `x` e `y`.
- **Capturar antes da janela existir** — `grim` devolve imagem do que estiver lá. Consultar
  `hyprctl clients` primeiro serve de sincronização: se a janela não aparece na lista, o app
  ainda não subiu.

## Quando NÃO usar

Se a decisão humana é sobre **comportamento** (o som sai ao clicar? a fila avança sozinha?), a
captura não resolve — imagem não toca. Aí o gate continua sendo o Pedro na frente da máquina.
