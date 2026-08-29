---
slug: vazio-recebe
feature: melodarium-anima
status: aprovado
depende-de: [movimento-interruptor]
decisao-humana: sim
spec: docs/plans/research/2026-08-29-anima-varredura.md
---

# Plano: vazio-recebe

**Goal:** A tela "nada tocando" é o único lugar do app onde encanto é permitido — é rara,
emocional e ninguém está esperando por ela para fazer outra coisa. As três saídas que ela
oferece entram escalonadas em vez de aparecerem chapadas.

**Arquitetura:** O componente local `Atalho`, dentro de `EmptyPane.qml`, ganha uma propriedade
`ordem` e uma animação de entrada disparada no `Component.onCompleted` dele mesmo — assim os
três usos só declaram o número da vez. A entrada é `opacity` 0→1 com 10 px de subida, em 200 ms,
com 60 ms entre um e o próximo.

**Constraints globais:** É o item mais dispensável do lote e o de menor alavancagem — se algum
número aqui incomodar, a resposta certa é cortar a fatia, não afinar. `EmptyPane` é instanciado
em **dois** lugares (o miolo e o painel sem faixa): a animação roda nos dois.

> **Sobre os números de linha:** valem para o repo em 2026-08-29. Se as fatias anteriores
> já mexeram no arquivo, a âncora de verdade é o **bloco citado**, não o número.

## Arquivos

- Modificar: `src/EmptyPane.qml`
- Criar: nenhum · Testar: `tools/check-fidelidade.sh`, `tools/check-layout.sh`

## Interfaces

- Consome: `Theme.animationStagger : int`, `Theme.animationFast : int`,
  `Theme.easingType : int` (fatia `movimento-interruptor`). `Theme.uiScale : real` já existe
  no repo e não vem deste lote.
- Produz: `Atalho.ordem : int` — propriedade do componente local de `EmptyPane.qml`, número
  da vez na entrada escalonada (0 entra primeiro). Não sai deste arquivo.

## Tasks

### Task 1: O Atalho sabe entrar

- [x] Em `src/EmptyPane.qml`, dentro de `component Atalho: Rectangle`, acrescentar logo
      depois da propriedade `property bool vazio: false` (hoje na **linha 66**):

```qml
        // O número da vez na entrada. Zero entra primeiro; cada passo seguinte espera mais um
        // `animationStagger`. É a única entrada escalonada do app inteiro, e é de propósito:
        // esta tela é rara e ninguém está esperando por ela para fazer outra coisa. Numa
        // lista de mil linhas o mesmo efeito seria a definição de animação que atrapalha.
        property int ordem: 0
```

- [x] Ainda em `component Atalho: Rectangle`, acrescentar logo depois do bloco
      `Behavior on color { ... }` do próprio `Atalho` (hoje nas **linhas 79-81**, não o da
      linha 184):

```qml
        transform: Translate { id: deslocDoAtalho }

        SequentialAnimation {
            id: entradaDoAtalho

            PauseAnimation { duration: Theme.animationStagger * atalho.ordem }

            ParallelAnimation {
                NumberAnimation {
                    target: atalho
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: Theme.animationFast
                    easing.type: Theme.easingType
                }
                NumberAnimation {
                    target: deslocDoAtalho
                    property: "y"
                    from: Math.round(10 * Theme.uiScale)
                    to: 0
                    duration: Theme.animationFast
                    easing.type: Theme.easingType
                }
            }
        }

        // `from`/`to` explícitos nas duas animações acima: com o interruptor de movimento
        // ligado a duração é 0 e elas saltam direto para o estado final, em vez de deixarem
        // o atalho preso invisível — que é exatamente como uma animação de entrada apaga uma
        // tela quando alguém a desliga pela metade.
        Component.onCompleted: entradaDoAtalho.start()
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] verificação mecânica da task: `grep -c 'deslocDoAtalho' src/EmptyPane.qml` → `2`
- [x] commit:

```bash
git add src/EmptyPane.qml
git commit -m "feat(empty): staggered entrance for the three shortcuts"
```

### Task 2: Os três atalhos declaram a vez

- [ ] Em `src/EmptyPane.qml`, no `ColumnLayout` das outras duas saídas (hoje a partir da
      **linha 266**), acrescentar `ordem:` aos três `Atalho`. O bloco passa a ser:

```qml
        // --- As outras duas saídas ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS

            Atalho {
                Layout.fillWidth: true
                ordem: 0
                visible: root.temBiblioteca
                glyph: Icons.get("shuffle")
                label: qsTr("Tocar tudo em ordem aleatória")
                onClicked: root.playRequested("shuffle")
            }
            Atalho {
                Layout.fillWidth: true
                ordem: 1
                visible: root.temBiblioteca
                vazio: root.neverCount === 0
                glyph: Icons.get("star")
                label: qsTr("Nunca ouvi")
                badge: String(root.neverCount)
                onClicked: root.playRequested("never")
            }
            Atalho {
                Layout.fillWidth: true
                ordem: 2
                visible: root.temBiblioteca
                vazio: root.forgottenCount === 0
                glyph: Icons.get("history")
                label: qsTr("Esquecidas")
                badge: String(root.forgottenCount)
                onClicked: root.playRequested("forgotten")
            }
        }
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] verificação mecânica da task: `grep -c 'ordem:' src/EmptyPane.qml` → `3`
- [ ] verificação mecânica da task — a foto da tela vazia continua fiel ao desenho, o que só
      acontece se os três atalhos estiverem em `opacity: 1` quando ela é tirada:
      `bash tools/check-fidelidade.sh` → exit 0
- [ ] commit:

```bash
git add src/EmptyPane.qml
git commit -m "feat(empty): declare the entrance order of the three shortcuts"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → exit 0
- `ctest --test-dir build -N | awk '/Total Tests:/ {print $3}'` → `11` (piso de contagem)
- `bash tools/check-orfaos.sh` → exit 0
- `bash tools/check-fidelidade.sh` → exit 0 (o ponto `fundo da janela (vazia)` e o
  `painel: topo (vazia)` saem da foto `--pane empty`: se a entrada prender os atalhos
  invisíveis, é aqui que aparece)
- `bash tools/check-layout.sh` → exit 0
- **Decisão humana (esta fatia não fecha sem o Pedro ver na tela):** abrir o app sem nada
  tocando e olhar a entrada. Se a escada de 60 ms parecer lenta ou boba, o número é
  `Theme.animationStagger`; se a fatia inteira parecer desnecessária, ela é a mais barata de
  reverter do lote — um `git revert` dos dois commits e nada mais depende dela.

## Fora de escopo

- **Animar o cartão "continuar de onde parou"** (o bloco `temRetomar`, acima dos três
  atalhos). Ele já é o item mais destacado da tela; entrar animado junto faria a tela inteira
  se montar diante do usuário em vez de estar lá.
- **Animar o estado vazio da lista** ("nada nesta lista", "nenhuma pasta escolhida"). Aparece
  ao trocar de filtro, que é gesto de dezenas por dia — rejeitado no artefato de research.
- **Entrada escalonada em qualquer lista.** Rejeitada explicitamente: até 1.200 linhas.
