---
slug: movimento-interruptor
feature: melodarium-anima
status: aprovado
depende-de: []
decisao-humana: nao
spec: docs/plans/research/2026-08-29-anima-varredura.md
---

# Plano: movimento-interruptor

**Goal:** Um interruptor único que zera toda duração de animação do app, e um segundo que
desliga efeito ambiental indeterminístico. Sem ele, as cinco fatias seguintes quebram o gate
de fidelidade — que fotografa a tela num instante fixo e mede 15 pontos de cor.

**Arquitetura:** Os tokens de duração que já existem em `Theme.qml` deixam de ser constantes e
passam a valer `0` quando `Theme.reduzirMovimento`. Como todo `Behavior` do app já os consome,
o interruptor pega o app inteiro sem tocar em nenhum componente. `Theme.medindo` é separado de
propósito: desligar movimento é preferência de quem usa; desligar o halo é exigência do gate.

**Constraints globais:** Qt 6, QML puro nesta fatia (nenhuma linha de C++). `Theme` é
`pragma Singleton` — propriedade gravável segue o padrão de `uiScale`, escrita por `Main.qml`.

> **Sobre os números de linha:** valem para o repo em 2026-08-29. Se as fatias anteriores
> já mexeram no arquivo, a âncora de verdade é o **bloco citado**, não o número.

## Arquivos

- Modificar: `src/Theme.qml` · `src/Main.qml`
- Criar: nenhum · Testar: `tools/check-fidelidade.sh`, `tools/check-layout.sh`

## Interfaces

- Consome: nada (fatia folha).
- Produz, todas em `Theme` (singleton `Melodarium.App`):
  - `Theme.reduzirMovimento : bool` — gravável, default `false`. Ligada, TODA duração abaixo
    vale `0`.
  - `Theme.medindo : bool` — gravável, default `false`. Ligada só sob `--measure`. Desliga
    efeito cuja cor venha do acervo. Consumida por `painel-acompanha`.
  - `Theme.animationFaster : int` — `0` ou `75`
  - `Theme.animationFast : int` — `0` ou `150`
  - `Theme.animationNormal : int` — `0` ou `300`
  - `Theme.animationSlow : int` — `0` ou `450`
  - `Theme.animationSlowest : int` — `0` ou `750`
  - `Theme.animationPop : int` — `0` ou `120` (subida do pulo; consumida por `coracao-comemora`)
  - `Theme.animationPopBack : int` — `0` ou `140` (volta do pulo)
  - `Theme.popEscala : real` — `1.3` (fator do pulo)
  - `Theme.popOvershoot : real` — `2.5` (folga do `Easing.OutBack`)
  - `Theme.animationStagger : int` — `0` ou `60` (passo da entrada escalonada; consumida por
    `vazio-recebe`)
  - `Theme.easingType : int` — `Easing.OutCubic` (já existia, inalterada)
- Produz em `Main.qml`: a linha `MEDIDA` do modo `--measure` ganha o sufixo
  ` movimento=off` ou ` movimento=on`. É a porta de saída mecânica do campo.

## Tasks

### Task 1: Os tokens de duração passam pelo interruptor

- [x] Substituir o bloco `// --- Motion ---` no fim de `src/Theme.qml` por:

```qml
    // --- Motion ---
    // O interruptor. Ligado, toda duração abaixo vale 0: o app continua igual, só sem
    // transição. Existe por dois motivos que apontam para o mesmo lugar — a foto do gate de
    // fidelidade é tirada num instante fixo e pegaria qualquer animação pela metade, e
    // "movimento reduzido" é o que quem se incomoda com tela que se mexe precisa poder pedir.
    property bool reduzirMovimento: false

    // Ligado SÓ por `--measure`, e separado do de cima de propósito: ele não desliga
    // movimento, desliga efeito cuja cor vem do acervo de quem roda. O halo do painel tem a
    // cor da capa que está tocando, e o gate mede 15 pontos fixos com tolerância de 3 níveis
    // por canal — um deles a 16 px da capa. Ou o halo sai da foto, ou o gate mede sorte.
    property bool medindo: false

    readonly property int animationFaster: theme.reduzirMovimento ? 0 : 75
    readonly property int animationFast: theme.reduzirMovimento ? 0 : 150
    readonly property int animationNormal: theme.reduzirMovimento ? 0 : 300
    readonly property int animationSlow: theme.reduzirMovimento ? 0 : 450
    readonly property int animationSlowest: theme.reduzirMovimento ? 0 : 750
    readonly property int easingType: Easing.OutCubic

    // O pulo do coração tem forma própria e não é transição: sobe rápido passando do alvo
    // (OutBack devolve o excesso) e desce um pouco mais devagar. Separado dos tokens acima
    // porque reaproveitar `animationFast` nos dois lados apagaria justamente a diferença
    // entre confirmar um gesto e comemorar um.
    readonly property int animationPop: theme.reduzirMovimento ? 0 : 120
    readonly property int animationPopBack: theme.reduzirMovimento ? 0 : 140
    readonly property real popEscala: 1.3
    readonly property real popOvershoot: 2.5

    // O passo entre um item e o próximo numa entrada escalonada. Um consumidor só, a tela
    // vazia: ela é rara e ninguém a espera para fazer outra coisa. Numa lista de mil linhas o
    // mesmo efeito é a definição de animação que atrapalha, e o token existir aqui não é
    // convite para usá-lo lá.
    readonly property int animationStagger: theme.reduzirMovimento ? 0 : 60
```

- [x] verificação mecânica da task:
      `grep -c 'reduzirMovimento' src/Theme.qml` → `9`
- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/Theme.qml
git commit -m "feat(theme): single switch that zeroes every animation duration"
```

### Task 2: A janela liga o interruptor

- [ ] Em `src/Main.qml`, logo abaixo da declaração `readonly property bool measuring:`
      (hoje na linha 14), acrescentar:

```qml
    // `--sem-animacao`: desliga toda transição sem precisar de tela de ajustes. `--measure`
    // liga junto de qualquer jeito — a foto do gate é tirada num instante fixo e pegaria a
    // animação pela metade, reprovando por movimento em vez de por cor errada.
    readonly property bool semAnimacao:
        root.measuring || Qt.application.arguments.indexOf("--sem-animacao") >= 0
```

- [ ] Em `src/Main.qml`, dentro de `Component.onCompleted` (hoje na linha 611), logo
      DEPOIS da linha `Theme.uiScale = root.escalaDaJanela`, acrescentar:

```qml
        Theme.reduzirMovimento = root.semAnimacao
        Theme.medindo = root.measuring
```

- [ ] Em `src/Main.qml`, no `console.log("MEDIDA rail=" ...)`, acrescentar antes da linha
      `+ " motor=" + ...` o campo novo:

```qml
                            + " movimento=" + (Theme.reduzirMovimento ? "off" : "on")
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] verificação mecânica da task:
      `QT_QPA_PLATFORM=offscreen ./build/melodarium --measure 1100 --no-search --delay 900 2>&1 | grep -c 'movimento=off'` → `1`
- [ ] commit:

```bash
git add src/Main.qml
git commit -m "feat(window): --sem-animacao flag and measure-mode motion kill switch"
```

### Task 3: Confirmar que os dois gates de tela continuam verdes

- [ ] Rodar os dois portões que todo redesenho de tela precisa passar:

```bash
bash tools/check-orfaos.sh
bash tools/check-fidelidade.sh
bash tools/check-layout.sh
```

- [ ] verificação mecânica da task: os três saem `exit 0`. Nada mudou de aparência nesta
      fatia — se algum reprovar, o interruptor mudou cor ou geometria e é bug, não ajuste.
- [ ] commit: nada a commitar se os gates passaram (a task é portão, não mudança).

## Verificação da fatia (E2E)

- `cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → exit 0
- `ctest --test-dir build -N | awk '/Total Tests:/ {print $3}'` → `10` (piso de contagem: `ctest` sai 0 com
  `Total Tests: 0`, e um gate sem piso lê verde num build sem teste nenhum)
- `QT_QPA_PLATFORM=offscreen ./build/melodarium --measure 1100 --no-search --delay 900 2>&1 | grep -c 'movimento=off'` → `1`
- `QT_QPA_PLATFORM=offscreen ./build/melodarium --measure 1100 --sem-animacao --no-search --delay 900 2>&1 | grep -c 'movimento=off'` → `1`
- `bash tools/check-fidelidade.sh` → exit 0
- `bash tools/check-layout.sh` → exit 0
- `bash tools/check-orfaos.sh` → exit 0

## Fora de escopo

- **Persistir a preferência** (`Settings { category: "ui" }`) e o interruptor no
  `SettingsDialog`. Vira fatia própria se o Pedro quiser a chave na tela; o argumento de
  linha de comando já entrega o que as outras cinco fatias precisam.
- **Ler o "prefers-reduced-motion" do sistema.** Qt não expõe isso por API portátil, e
  descobrir por D-Bus no Wayland é outra fatia.
- Qualquer animação nova: esta fatia só constrói o interruptor.
