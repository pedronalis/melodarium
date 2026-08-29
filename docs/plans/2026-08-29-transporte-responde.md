---
slug: transporte-responde
feature: melodarium-anima
status: aprovado
depende-de: [movimento-interruptor, painel-acompanha]
decisao-humana: sim
spec: docs/plans/research/2026-08-29-anima-varredura.md
---

# Plano: transporte-responde

**Goal:** Os dois controles que o usuário mais aperta passam a confirmar que foram ouvidos: o
botão de play/pause responde ao dedo, e a barra de volume desliza em vez de teleportar. Aqui a
regra é **contenção** — play/pause é o gesto mais repetido do app, e animação demais faz um
botão frequente parecer lento.

**Arquitetura:** O press feedback é `scale` ligada ao `pressed` do `MouseArea`, com `Behavior`
de 75 ms. A troca de glifo (play↔pause, som→baixo→mudo) vira cross-fade de dois `Text`
sobrepostos — no botão de play direto, e no `IconButton`, que é a peça compartilhada por vinte
lugares e onde a troca de desenho no mesmo `Text` sempre piscou.

**Constraints globais:** A barra de progresso da faixa **não entra**: é dado que o usuário lê e
que já se move sozinho (§ Rejeitados, artefato de research). Nenhuma duração aqui passa de
150 ms.

**Depende de `painel-acompanha` por conflito de edição, não por dado:** as duas fatias editam
`src/NowPlayingPanel.qml`, em regiões diferentes. Soltá-las em paralelo garante conflito.

> **Sobre os números de linha:** valem para o repo em 2026-08-29. Se as fatias anteriores
> já mexeram no arquivo, a âncora de verdade é o **bloco citado**, não o número.

## Arquivos

- Modificar: `src/IconButton.qml` · `src/NowPlayingPanel.qml`
- Criar: nenhum · Testar: `tools/check-fidelidade.sh`, `tools/check-layout.sh`

## Interfaces

- Consome: `Theme.animationFaster : int`, `Theme.animationFast : int`,
  `Theme.easingType : int` (fatia `movimento-interruptor`).
- Produz:
  - `IconButton.glifoAnaFrente : bool`, `IconButton.glifoA : string`,
    `IconButton.glifoB : string` — o par de glifos que cruza. Internas ao componente; a
    fatia `coracao-comemora` acrescenta `function comemorar()` a este mesmo arquivo.
  - `IconButton.corDoGlifo : color` — a cor de repouso do glifo, num lugar só.

## Tasks

### Task 1: O IconButton troca de desenho cruzando, não piscando

- [x] Substituir o conteúdo inteiro de `src/IconButton.qml` por:

```qml
import QtQuick
import Melodarium.App

Item {
    id: root

    property string icon: ""
    property real size: Theme.fontSizeXL
    property bool accent: false
    property string tooltip: ""
    // O desenho não pinta todos os ícones com o mesmo tom: os do transporte principal são
    // mais claros que aleatório e repetir, que ficam um degrau atrás. Quem chama escolhe.
    property color baseColor: Theme.cSecondary

    signal clicked

    // 1,8x e não 2x: com a tipografia em pixels o dobro do glifo virava uma área de toque de
    // 38 px por botão, e a fileira do transporte passava a ser mais larga do que o painel que
    // a contém — o tempo total da faixa saía cortado pela borda.
    implicitWidth: Math.round(size * 1.8)
    implicitHeight: Math.round(size * 1.8)
    opacity: enabled ? 1.0 : 0.4

    // A cor de repouso do glifo, num lugar só: os dois Text abaixo a leem, e escrita duas
    // vezes ela derraparia na primeira edição.
    readonly property color corDoGlifo: mouse.containsMouse && root.enabled
                                        ? Theme.cTitle
                                        : (root.accent ? Theme.cAccent : root.baseColor)

    // Trocar de desenho no lugar: dois glifos sobrepostos, o novo entrando enquanto o velho
    // sai. Um Text só trocando `text` pisca o desenho novo sem passar por lugar nenhum — dá
    // para ver no botão de volume (som → baixo → mudo) e no de repetir, que trocam de glifo
    // sem mudar de posição nem de tamanho, e por isso a troca seca aparece como um susto.
    property bool glifoAnaFrente: true
    property string glifoA: ""
    property string glifoB: ""

    onIconChanged: {
        if (root.glifoAnaFrente)
            root.glifoB = root.icon
        else
            root.glifoA = root.icon
        root.glifoAnaFrente = !root.glifoAnaFrente
    }

    // Os dois iguais na partida: `icon` costuma ser um binding que assenta em mais de um
    // passo, e sem isto o botão nasceria cruzando de um glifo vazio para o certo.
    Component.onCompleted: {
        root.glifoA = root.icon
        root.glifoB = root.icon
        root.glifoAnaFrente = true
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        // O realce do desenho é a pílula escura, não um disco claro: com mHover (quase branco)
        // o hover apagava o próprio ícone que ele deveria destacar.
        color: mouse.containsMouse && root.enabled ? Theme.cPill : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.get(root.glifoA)
            font.family: Icons.fontFamily
            font.pixelSize: root.size
            color: root.corDoGlifo
            opacity: root.glifoAnaFrente ? 1 : 0

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animationFaster; easing.type: Theme.easingType }
            }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.get(root.glifoB)
            font.family: Icons.fontFamily
            font.pixelSize: root.size
            color: root.corDoGlifo
            opacity: root.glifoAnaFrente ? 0 : 1

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animationFaster; easing.type: Theme.easingType }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] verificação mecânica da task: `bash tools/check-fidelidade.sh` → exit 0. O ponto
      `trilho: ícone escolhido` mede o vão liso ACIMA do glifo do trilho — se ele reprovar,
      os dois `Text` deixaram de ficar sobrepostos e o botão mudou de tamanho.
- [x] verificação mecânica da task: `bash tools/check-layout.sh` → exit 0. `IconButton` é a
      peça de vinte lugares e a fileira do transporte já estourou o painel uma vez por causa
      da medida dela: este gate é o que prova que `implicitWidth` não mudou.
- [x] commit:

```bash
git add src/IconButton.qml
git commit -m "feat(icons): cross-fade the glyph instead of swapping it in place"
```

### Task 2: O botão de play responde ao dedo

- [x] Em `src/NowPlayingPanel.qml`, substituir o `Rectangle` do botão de play inteiro (hoje
      das **linhas 442 a 461**, o de `radius: Math.round(26 * Theme.uiScale)`) por:

```qml
            Rectangle {
                id: botaoPlay

                Layout.preferredWidth: Math.round(52 * Theme.uiScale)
                Layout.preferredHeight: Math.round(52 * Theme.uiScale)
                radius: Math.round(26 * Theme.uiScale)
                color: Theme.cTitle

                // É o botão mais apertado do app, e por isso a animação aqui é quase
                // imperceptível de propósito: um gesto repetido dezenas de vezes por dia com
                // transição longa deixa de parecer rápido. Encolher 6% em 75 ms confirma o
                // toque sem cobrar tempo por ele.
                scale: playArea.pressed ? 0.94 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animationFaster
                        easing.type: Theme.easingType
                    }
                }

                // Os dois glifos sobrepostos: um Text só trocando de texto põe o desenho novo
                // no lugar do velho sem passar por lugar nenhum, e é o único lugar da tela
                // onde isso acontece a cada pausa.
                Text {
                    anchors.centerIn: parent
                    text: Icons.get("play")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeXL
                    color: Theme.cBase
                    opacity: AudioEngine.playing && root.hasTrack ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animationFaster
                            easing.type: Theme.easingType
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.get("pause")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeXL
                    color: Theme.cBase
                    opacity: AudioEngine.playing && root.hasTrack ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animationFaster
                            easing.type: Theme.easingType
                        }
                    }
                }

                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioEngine.togglePause()
                }
            }
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] verificação mecânica da task: `bash tools/check-layout.sh` → exit 0 (o botão continua
      52x52 e a fileira do transporte continua cabendo no painel)
- [x] commit:

```bash
git add src/NowPlayingPanel.qml
git commit -m "feat(transport): press feedback and cross-faded glyph on the play button"
```

### Task 3: A barra de volume desliza

- [ ] Em `src/NowPlayingPanel.qml`, no `Rectangle` interno do `trilhoVolume` (hoje na
      **linha 558**, o de `width: parent.width * (AudioEngine.volume / 100)`), acrescentar o `Behavior`.
      O bloco passa a ser:

```qml
                Rectangle {
                    width: parent.width * (AudioEngine.volume / 100)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.cMuted

                    // Clicar no trilho leva o volume de um lugar a outro sem passar pelo meio.
                    // Deslizar diz que foi a MESMA barra que mudou, e não uma barra nova
                    // aparecendo no lugar da anterior.
                    //
                    // Só o volume: a barra de progresso da faixa já se move sozinha, e um
                    // Behavior nela faria o tempo mentir e brigar com cada arrasto de seek.
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animationFast
                            easing.type: Theme.easingType
                        }
                    }
                }
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] verificação mecânica da task — a barra de progresso NÃO ganhou Behavior:
      `awk '/id: percorrido/,/^                }/' src/NowPlayingPanel.qml | grep -c 'Behavior'` → `0`
- [ ] commit:

```bash
git add src/NowPlayingPanel.qml
git commit -m "feat(transport): volume bar slides to its new value"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → exit 0
- `ctest --test-dir build -N | awk '/Total Tests:/ {print $3}'` → `11` (piso de contagem)
- `bash tools/check-orfaos.sh` → exit 0
- `bash tools/check-fidelidade.sh` → exit 0
- `bash tools/check-layout.sh` → exit 0
- `awk '/id: percorrido/,/^                }/' src/NowPlayingPanel.qml | grep -c 'Behavior'` → `0`
- **Decisão humana (esta fatia não fecha sem o Pedro ver na tela):** apertar play/pause umas
  dez vezes seguidas e julgar se os 75 ms de encolhida ainda deixam o botão parecer
  instantâneo — se parecer lento, o número a mexer é o `scale: 0.94`, não a duração. Depois
  clicar no trilho de volume de ponta a ponta e julgar os 150 ms.

## Fora de escopo

- **Arrastar o volume.** Hoje o trilho só aceita clique (`onClicked`), e é assim desde que
  foi desenhado. Se um dia ganhar arrasto, o `Behavior on width` precisa ser desligado
  durante o arrasto (`enabled: !arrastando`) ou a barra fica borrachuda sob o dedo.
- **Animar a barra de progresso da faixa.** Rejeitado no artefato de research.
- **`ToolTip` de verdade** para a propriedade `tooltip` do `IconButton`, que oito lugares
  preenchem e nada renderiza. É bug achado na varredura, não animação — fatia própria.
- **Press feedback nos outros botões do transporte** (anterior, próxima, aleatório, repetir).
  Eles já têm a pílula de hover; acrescentar escala a todos faria a fileira inteira pular a
  cada clique.
