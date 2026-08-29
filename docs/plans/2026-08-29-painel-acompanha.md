---
slug: painel-acompanha
feature: melodarium-anima
status: aprovado
depende-de: [movimento-interruptor, cor-dominante]
decisao-humana: sim
spec: docs/plans/research/2026-08-29-anima-varredura.md
---

# Plano: painel-acompanha

**Goal:** O painel deixa de ser uma vitrine estática e passa a acompanhar a música. Duas coisas
no mesmo momento — a troca de faixa: um halo com a cor da capa atrás da arte, e a arte e os
metadados cruzando em vez de saltarem. É a maior alavanca do lote e o momento que mais acontece
sem o usuário pedir.

**Arquitetura:** O halo é um componente novo, `AmbientGlow.qml`, feito de molduras arredondadas
empilhadas — o mesmo truque que a sombra da capa já usa em `RoundedCover.qml:37`, e pelo mesmo
motivo: desfoque de verdade é shader, shader some no adaptador de software, e leva a capa
junto. O cross-fade da capa usa duas camadas de `RoundedCover` alternando, com a troca disparada
pelo `ready` da camada de trás (e um relógio de segurança para a capa que não existe).

**Constraints globais:** O halo é filho do painel e recorta nele (`clip: true`) — a capa ocupa
quase toda a largura da coluna, e sem o corte a luz do álbum invadia a lista. O halo desliga sob
`Theme.medindo`: a cor dele vem do acervo de quem roda, e o gate de fidelidade mede um ponto
fixo a 16 px da capa com tolerância de 3 níveis por canal (§ Restrições, artefato de research).

> **Sobre os números de linha:** valem para o repo em 2026-08-29. Se as fatias anteriores
> já mexeram no arquivo, a âncora de verdade é o **bloco citado**, não o número.

## Arquivos

- Criar: `src/AmbientGlow.qml`
- Modificar: `src/RoundedCover.qml` · `src/NowPlayingPanel.qml` · `CMakeLists.txt`
- Testar: `tools/check-orfaos.sh`, `tools/check-fidelidade.sh`, `tools/check-layout.sh`

## Interfaces

- Consome:
  - `Theme.reduzirMovimento : bool`, `Theme.medindo : bool`, `Theme.animationFast : int`,
    `Theme.animationNormal : int`, `Theme.animationSlowest : int`, `Theme.easingType : int`
    (fatia `movimento-interruptor`).
  - `RoundedImage.dominantColor : color` — opaca, ou alpha 0 quando não há cor
    (fatia `cor-dominante`).
- Produz:
  - `AmbientGlow.qml` — componente com as propriedades `cor : color`, `capaX : int`,
    `capaY : int`, `capaLado : int`, `raioBase : int`, `alcance : real`.
  - `RoundedCover.dominantColor : color` — repasse do `RoundedImage` interno.
  - `NowPlayingPanel.diag` ganha o sufixo ` halo=on` ou ` halo=off`. É a porta de saída
    mecânica que prova que o halo sai da foto do gate.

## Tasks

### Task 1: O componente do halo

- [x] Criar `src/AmbientGlow.qml`:

```qml
import QtQuick
import Melodarium.App

// O halo que a capa projeta no painel — o "ambient mode" do YouTube, feito do jeito que este
// app pode fazer.
//
// Por que não é um desfoque de verdade: borrar imagem no QML é MultiEffect, e MultiEffect é
// shader. No adaptador de software (que é como o app é fotografado, e como ele roda numa
// máquina sem GPU) o shader não desenha NADA e leva a capa junto — a mesma lição que fez a
// sombra da capa ser empilhada em vez de borrada
// (docs/solutions/ui/2026-08-28-a-tela-passava-nos-gates-e-nao-era-o-desenho.md). O halo
// repete o truque dela: molduras arredondadas cada vez maiores, translúcidas, na cor da capa.
//
// Ele é filho do PAINEL, não da capa, e recorta nele: as molduras precisam passar da arte
// para a luz cair, e passar da arte significa passar do painel pelos lados — a capa ocupa
// 340 dos 392 px da coluna. O corte acontece onde a moldura externa já está quase
// transparente, então não se vê; sem ele, a luz do álbum invadia a lista ao lado.
Item {
    id: root

    clip: true

    // A cor que a capa "é". A última cor válida FICA: apagar o halo é trabalho da opacidade
    // de quem instancia, nunca desta cor. Interpolar uma cor até o transparente passa por
    // preto, e preto crescendo num painel escuro lê como sombra — o oposto do efeito.
    property color cor: Theme.cCoverMid

    // Onde a capa está, em coordenadas do painel. Não sai de mapToItem: o mapeamento não é
    // reativo, e a capa muda de tamanho com a altura da janela.
    property int capaX: 0
    property int capaY: 0
    property int capaLado: 0

    property int raioBase: Theme.radiusM

    // Quanto o halo passa da capa, em fração do lado dela. 0,35 numa capa de 340 dá 119 px de
    // luz — o bastante para a arte parecer apoiada em algo, sem virar uma mancha.
    property real alcance: 0.35

    // Menos molduras e o degradê vira degrau visível; mais e só o custo muda.
    readonly property int camadas: 14

    // A troca de faixa troca a cor, e ela cruza devagar de propósito: é fundo, ninguém espera
    // por ele, e uma luz ambiente que muda em 150 ms lê como lâmpada piscando.
    Behavior on cor {
        ColorAnimation { duration: Theme.animationSlowest; easing.type: Theme.easingType }
    }

    Repeater {
        model: root.camadas

        Rectangle {
            required property int index

            // A camada 0 é a mais externa; a última encosta na capa. Assim a luz fica mais
            // densa junto da arte e se dissolve para fora, que é como luz se comporta.
            readonly property real avanco: (root.camadas - index) / root.camadas
            readonly property real folga: root.capaLado * root.alcance * avanco

            x: root.capaX - folga
            y: root.capaY - folga
            width: root.capaLado + folga * 2
            height: root.capaLado + folga * 2
            radius: root.raioBase + folga
            color: root.cor
            // 14 camadas a 0,030 empilham para ~0,35 junto da arte. Mais do que isso e o halo
            // compete com a capa; menos e ele some dentro do degradê do painel.
            opacity: 0.030
        }
    }
}
```

- [x] Registrar `src/AmbientGlow.qml` na lista `QML_FILES` do
      `qt_add_qml_module(melodarium ...)` em `CMakeLists.txt`, junto das outras telas:

```cmake
        src/AmbientGlow.qml
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/AmbientGlow.qml CMakeLists.txt
git commit -m "feat(panel): stacked-frame ambient glow component (no shader)"
```

### Task 2: A capa repassa a própria cor

- [x] Em `src/RoundedCover.qml`, logo abaixo de `readonly property bool ready: img.ready`
      (hoje na **linha 32**), acrescentar:

```qml
    // A cor que esta arte "é", para quem quiser pintar luz com ela. Transparente (alpha 0)
    // enquanto não há capa carregada, ou quando a capa não tem cor a dar — capa em escala de
    // cinza, quase preta, quase branca.
    readonly property alias dominantColor: img.dominantColor
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] verificação mecânica da task: `grep -c 'dominantColor' src/RoundedCover.qml` → `1`
- [x] commit:

```bash
git add src/RoundedCover.qml
git commit -m "feat(cover): pass the artwork's dominant color through RoundedCover"
```

### Task 3: Duas capas cruzando no lugar de uma trocando

- [ ] Em `src/NowPlayingPanel.qml`, acrescentar ao bloco de propriedades do `root` (logo
      depois de `readonly property bool hasTrack:`, hoje na linha 58):

```qml
    // O endereço da arte do que está tocando, num lugar só: as duas camadas da capa e o halo
    // leem daqui, e antes disso a mesma expressão de três linhas vivia dentro do RoundedCover.
    readonly property url fonteDaCapa:
        root.episodeMode
        ? (root.episodeInfo.coverPath !== undefined && root.episodeInfo.coverPath !== ""
           ? "file://" + root.episodeInfo.coverPath : "")
        : (root.info.albumId !== undefined
           ? CoverCache.coverUrlForTrack(AudioEngine.currentFile, root.info.albumId) : "")

    // Qual das duas camadas está na frente. A troca NÃO acontece no instante em que a faixa
    // muda: a camada de trás recebe a arte nova e as duas só trocam de lugar quando ela
    // terminou de carregar. Sem essa espera, o cruzamento mostraria o bloco cinza do
    // placeholder no meio do caminho — remédio pior que a doença.
    property bool capaAnaFrente: true

    readonly property var capaDaFrente: root.capaAnaFrente ? capaA : capaB
    readonly property var capaDeTras: root.capaAnaFrente ? capaB : capaA

    onFonteDaCapaChanged: {
        root.capaDeTras.source = root.fonteDaCapa
        // Uma faixa sem capa nenhuma nunca fica "pronta": o relógio garante que a troca
        // acontece de qualquer jeito, e o placeholder cruza como cruzaria uma arte.
        trocaDeCapa.restart()
    }

    Timer {
        id: trocaDeCapa
        interval: 350
        onTriggered: root.capaAnaFrente = !root.capaAnaFrente
    }
```

- [ ] Em `src/NowPlayingPanel.qml`, substituir o bloco `RoundedCover { id: capaVazia ... }`
      inteiro (hoje das **linhas 228 a 257**, do `RoundedCover {` até o `}` que fecha o
      `source:`) por duas camadas.
      O componente `Capa` local evita repetir onze propriedades idênticas duas vezes:

```qml
            // Duas capas, não uma. A arte trocava no mesmo quadro em que a faixa trocava, e
            // 340x340 px mudando de golpe é a coisa mais brusca que este painel faz. Com duas
            // camadas a nova sobe enquanto a velha desce, e nenhum quadro fica vazio — que é
            // o que aconteceria fazendo a mesma capa piscar.
            component Capa: RoundedCover {
                anchors.fill: parent
                radius: Theme.radiusM
                // A única capa do app que projeta sombra: é ela que descola a arte do painel.
                shadow: true
                placeholderColor: Theme.cRaised
                placeholderTop: root.episodeMode ? Theme.cCoverTopPod : Theme.cCoverTop
                placeholderMid: root.episodeMode ? Theme.cCoverMidPod : Theme.cCoverMid
                // Sem faixa quem desenha o ícone é a coluna de baixo, no tamanho pequeno do
                // desenho; aqui ele sairia grande e duplicado.
                fallbackIcon: !root.hasTrack ? ""
                                             : (root.episodeMode ? "microphone" : "music")
                // 64 px num bloco de 340 no desenho — proporção, não medida fixa, porque a
                // capa encolhe junto com a janela.
                fallbackIconSize: Math.round(capaRect.lado * 64 / 340)
                fallbackIconColor: root.episodeMode ? Theme.cCoverIconPod : Theme.cCoverIcon

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationNormal
                        easing.type: Theme.easingType
                    }
                }
            }

            Capa {
                id: capaA
                opacity: root.capaAnaFrente ? 1 : 0
                z: root.capaAnaFrente ? 1 : 0
                onReadyChanged: {
                    if (capaA.ready && !root.capaAnaFrente && trocaDeCapa.running) {
                        trocaDeCapa.stop()
                        root.capaAnaFrente = true
                    }
                }
            }

            Capa {
                id: capaB
                opacity: root.capaAnaFrente ? 0 : 1
                z: root.capaAnaFrente ? 0 : 1
                onReadyChanged: {
                    if (capaB.ready && root.capaAnaFrente && trocaDeCapa.running) {
                        trocaDeCapa.stop()
                        root.capaAnaFrente = false
                    }
                }
            }
```

- [ ] Dar à camada da frente a arte inicial — sem isto o painel abre com as duas vazias,
      porque `onFonteDaCapaChanged` não roda para o valor de partida. Acrescentar ao
      `Component.onCompleted` do `root` (hoje na **linha 128**), que passa a ser:

```qml
    Component.onCompleted: {
        root.refresh()
        capaA.source = root.fonteDaCapa
    }
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] verificação mecânica da task: `bash tools/check-fidelidade.sh` → exit 0. O ponto
      `a capa está arredondada (o canto não é arte)` é o que prova que as duas camadas
      continuam recortando; se ele reprovar, o `radius` se perdeu na troca.
- [ ] commit:

```bash
git add src/NowPlayingPanel.qml
git commit -m "feat(panel): cross-fade the artwork instead of swapping it in one frame"
```

### Task 4: O halo atrás da capa

- [ ] Em `src/NowPlayingPanel.qml`, acrescentar ao bloco de propriedades do `root`, logo
      depois de `capaDeTras`:

```qml
    // A cor que o halo pinta. Guardada em vez de derivada: quando a faixa nova não tem cor a
    // dar (capa ausente, capa em escala de cinza) o halo apaga pela opacidade e a última cor
    // fica parada onde estava, em vez de desabar para preto no meio do caminho.
    property color corDoHalo: Theme.cCoverMid

    readonly property color corDaCapaAtual: root.capaDaFrente.dominantColor

    onCorDaCapaAtualChanged: {
        if (root.corDaCapaAtual.a > 0)
            root.corDoHalo = root.corDaCapaAtual
    }

    // O halo sai da foto do gate: a cor dele vem do acervo de quem roda, e o gate de
    // fidelidade mede 15 pontos fixos com 3 níveis de tolerância por canal — um deles a
    // 16 px da capa. Ou o halo sai da foto, ou o gate passa a medir sorte.
    readonly property bool mostrarHalo:
        !Theme.medindo && root.hasTrack && root.corDaCapaAtual.a > 0
```

- [ ] Acrescentar o halo como primeiro filho do `root`, ANTES do `ColumnLayout { id: col }`
      (hoje na **linha 154**). `z: -1` o põe atrás de todo o conteúdo e ainda por cima do degradê
      do painel, que é pintado pelo próprio `Rectangle`:

```qml
    AmbientGlow {
        anchors.fill: parent
        z: -1
        cor: root.corDoHalo
        // A capa é o primeiro item da coluna e está centrada nela: a posição sai da conta, e
        // não de mapToItem, porque mapeamento não é reativo e a capa muda de tamanho com a
        // altura da janela.
        capaX: Math.round((root.width - capaRect.lado) / 2)
        capaY: Theme.marginXL + Theme.marginS
        capaLado: capaRect.lado
        raioBase: Theme.radiusM
        opacity: root.mostrarHalo ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animationSlowest; easing.type: Theme.easingType }
        }
    }
```

- [ ] Acrescentar o campo à linha `diag` do `root` (hoje na **linha 84**), no fim da expressão:

```qml
                                   + " halo=" + (root.mostrarHalo ? "on" : "off")
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] verificação mecânica da task — o halo está desligado ao medir:
      `QT_QPA_PLATFORM=offscreen ./build/melodarium --measure 1100 --no-search --play-queue --delay 1800 2>&1 | grep -c 'halo=off'` → `1`
- [ ] verificação mecânica da task: `bash tools/check-orfaos.sh` → exit 0 (`AmbientGlow` tem
      quem o instancie)
- [ ] commit:

```bash
git add src/NowPlayingPanel.qml
git commit -m "feat(panel): ambient glow behind the cover, off while measuring"
```

### Task 5: Os metadados entram junto com a arte

- [ ] Em `src/NowPlayingPanel.qml`, dar `id: textos` ao `ColumnLayout` que contém título,
      artista e metadados (hoje na **linha 277**, o primeiro filho do `RowLayout` da linha
      272, aquele com `spacing: Theme.marginXXS`) e acrescentar a ele, logo abaixo de `spacing`:

```qml
                // Os metadados trocam junto com a capa. Sem isto eles saltavam enquanto a
                // arte cruzava, e o cruzamento ficava pela metade — a parte animada dizendo
                // "está mudando" e a parte de texto já mudada.
                transform: Translate { id: deslocDosTextos }

                SequentialAnimation {
                    id: entradaDosTextos

                    ParallelAnimation {
                        NumberAnimation {
                            target: textos
                            property: "opacity"
                            from: 0.0
                            to: 1.0
                            duration: Theme.animationFast
                            easing.type: Theme.easingType
                        }
                        NumberAnimation {
                            target: deslocDosTextos
                            property: "y"
                            from: Math.round(6 * Theme.uiScale)
                            to: 0
                            duration: Theme.animationFast
                            easing.type: Theme.easingType
                        }
                    }
                }
```

- [ ] Disparar a entrada na troca de faixa: no `Connections { target: AudioEngine }` do
      `root` (hoje na **linha 132**), o corpo passa a ser:

```qml
        function onCurrentFileChanged() {
            root.refresh()
            entradaDosTextos.restart()
        }
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] verificação mecânica da task: `bash tools/check-fidelidade.sh` → exit 0. A foto é
      tirada 1800 ms depois da carga e com `Theme.reduzirMovimento` ligado (duração 0): se
      este ponto reprovar, os textos ficaram presos em `opacity: 0`, que é o modo exato como
      uma animação de entrada apaga uma tela.
- [ ] commit:

```bash
git add src/NowPlayingPanel.qml
git commit -m "feat(panel): metadata fades in with the artwork on track change"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → exit 0
- `ctest --test-dir build -N | awk '/Total Tests:/ {print $3}'` → `11` (piso de contagem)
- `bash tools/check-orfaos.sh` → exit 0
- `bash tools/check-fidelidade.sh` → exit 0
- `bash tools/check-layout.sh` → exit 0
- `QT_QPA_PLATFORM=offscreen ./build/melodarium --measure 1100 --no-search --play-queue --delay 1800 2>&1 | grep -c 'halo=off'` → `1`
- **Decisão humana (esta fatia não fecha sem o Pedro ver na tela):** abrir o app, tocar uma
  faixa com capa colorida, depois pular para outra de cor bem diferente. O que ele precisa
  julgar: a luz atrás da arte está na intensidade certa (`alcance` 0.35, opacidade 0.030 por
  camada), e a troca de cor em 750 ms está no ritmo certo. Os dois números vivem em
  `src/AmbientGlow.qml` e são para ajustar na frente dele.

## Fora de escopo

- **Gate automático da COR do halo.** A cor vem do acervo de quem roda: um ponto de medição
  sobre ela mediria a capa que a máquina tem. A prova mecânica desta fatia é que o halo sai
  da foto (`halo=off`); a aparência dele é decisão humana, por isso `decisao-humana: sim`.
- **Halo de verdade por desfoque da imagem** (a "rota B" do artefato de research). Precisa de
  um `QQuickPaintedItem` novo que borre a `QImage`; ~2x o custo desta fatia, e a rota A
  entrega a maior parte da sensação. Fatia própria se o Pedro quiser depois.
- **Halo reagindo ao áudio.** Rejeitado no artefato de research: o mpv não entrega espectro
  sem trabalho pesado, e fundo que se mexe permanentemente é a primeira coisa que se desliga.
- **Cross-fade na tirinha da fila e nas capinhas de lista.** São 62 px e cinco de cada vez;
  o cruzamento ali é invisível e o custo, cinco vezes maior.
