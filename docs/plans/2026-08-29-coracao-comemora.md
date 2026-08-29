---
slug: coracao-comemora
feature: melodarium-anima
status: aprovado
depende-de: [movimento-interruptor, transporte-responde]
decisao-humana: sim
spec: docs/plans/research/2026-08-29-anima-varredura.md
---

# Plano: coracao-comemora

**Goal:** Curtir é o único gesto manual do produto inteiro e hoje ele não responde nada além de
trocar o desenho do ícone. O coração passa a pular ao acender — nos dois lugares onde ele
existe, a linha da lista e o painel.

**Arquitetura:** Um `SequentialAnimation` de dois passos sobre `scale`: sobe a 1,3 em 120 ms com
`Easing.OutBack` (que passa do alvo e devolve o excesso) e volta a 1,0 em 140 ms com
`Easing.OutCubic`. Na lista o alvo é o próprio `Text` do coração; no painel, o `IconButton`
inteiro, que ganha uma função `comemorar()` chamada de fora.

**Constraints globais:** A animação é **assimétrica de propósito** — só ao curtir, nunca ao
descurtir: tirar não se comemora. E o disparo sai do **clique**, nunca do estado: a `ListView`
recicla o delegate ao rolar, e uma faixa já curtida entrando na tela dispararia um
`likedChanged` — a lista inteira pulando durante a rolagem.

**Depende de `transporte-responde` por conflito de edição, não por dado:** as duas fatias
editam `src/IconButton.qml` e `src/NowPlayingPanel.qml`.

> **Sobre os números de linha:** valem para o repo em 2026-08-29. Se as fatias anteriores
> já mexeram no arquivo, a âncora de verdade é o **bloco citado**, não o número.

## Arquivos

- Modificar: `src/TrackRow.qml` · `src/IconButton.qml` · `src/NowPlayingPanel.qml`
- Criar: nenhum · Testar: `tools/check-fidelidade.sh`, `tools/check-layout.sh`

## Interfaces

- Consome: `Theme.animationPop : int`, `Theme.animationPopBack : int`,
  `Theme.popEscala : real`, `Theme.popOvershoot : real` (fatia `movimento-interruptor`);
  a estrutura de `src/IconButton.qml` já reescrita pela fatia `transporte-responde`.
- Produz: `IconButton.comemorar() : void` — dispara o pulo do botão inteiro. Sem argumentos,
  sem retorno. Chamada só pelo botão de curtir do painel.

## Tasks

### Task 1: O coração da lista pula ao acender

- [x] Em `src/TrackRow.qml`, substituir o `Item` do coração inteiro (hoje das
      **linhas 179 a 205**, o de `Layout.preferredWidth: Math.round(16 * Theme.uiScale)`)
      pelo bloco abaixo — que inclui os dois comentários de cima, hoje nas linhas 177-178:

```qml
            // Curtir mora na linha, não num menu: o coração apagado é discreto o bastante
            // para não competir com o título, e presente o bastante para ser achado sem hover.
            Item {
                Layout.preferredWidth: Math.round(16 * Theme.uiScale)
                Layout.fillHeight: true

                Text {
                    id: heart

                    anchors.centerIn: parent
                    text: root.liked ? Icons.get("heart-filled") : Icons.get("heart")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: root.liked ? Theme.cStrong : Theme.cGhost
                    opacity: root.liked ? 1.0 : (heartArea.containsMouse ? 0.9 : 0.45)

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                    }

                    // Sobe passando do alvo e volta: OutBack devolve o excesso, e é esse
                    // excesso que separa "confirmei seu clique" de "comemorei com você".
                    SequentialAnimation {
                        id: puloDoCoracao

                        NumberAnimation {
                            target: heart
                            property: "scale"
                            to: Theme.popEscala
                            duration: Theme.animationPop
                            easing.type: Easing.OutBack
                            easing.overshoot: Theme.popOvershoot
                        }
                        NumberAnimation {
                            target: heart
                            property: "scale"
                            to: 1.0
                            duration: Theme.animationPopBack
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: heartArea
                    anchors.fill: parent
                    anchors.margins: -Theme.marginXS
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // `root.liked` ainda é o valor ANTIGO aqui: se era falso, este clique
                        // vai curtir, e é só aí que se comemora. E o disparo sai do clique,
                        // nunca de `onLikedChanged`: a ListView recicla o delegate ao rolar, e
                        // uma faixa já curtida entrando na tela faria a lista inteira pular.
                        if (!root.liked)
                            puloDoCoracao.restart()
                        root.likeToggled()
                    }
                }
            }
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] verificação mecânica da task — o disparo veio do clique, não do estado:
      `grep -c 'onLikedChanged' src/TrackRow.qml` → `0`
- [x] verificação mecânica da task — a assimetria existe:
      `grep -c 'if (!root.liked)' src/TrackRow.qml` → `1`
- [x] commit:

```bash
git add src/TrackRow.qml
git commit -m "feat(list): the heart pops when it lights up, never when it goes out"
```

### Task 2: O IconButton aprende a comemorar

- [ ] Em `src/IconButton.qml`, acrescentar logo depois do bloco `Component.onCompleted`:

```qml
    // O pulo, pedido de fora. Quem sabe que houve comemoração é quem tratou o clique, e não
    // o botão: `accent` também muda ao ligar o aleatório e ao ligar o repetir, e nem um nem
    // outro comemora. Um botão que pulasse sozinho a cada mudança de `accent` transformaria
    // a fileira inteira do transporte numa festa.
    function comemorar() { puloDoBotao.restart() }

    SequentialAnimation {
        id: puloDoBotao

        NumberAnimation {
            target: root
            property: "scale"
            to: Theme.popEscala
            duration: Theme.animationPop
            easing.type: Easing.OutBack
            easing.overshoot: Theme.popOvershoot
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1.0
            duration: Theme.animationPopBack
            easing.type: Easing.OutCubic
        }
    }
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] verificação mecânica da task: `bash tools/check-layout.sh` → exit 0 (`scale` é
      transformação e não muda `implicitWidth`: a fileira do transporte tem que medir igual)
- [ ] commit:

```bash
git add src/IconButton.qml
git commit -m "feat(icons): comemorar() pops the whole button on demand"
```

### Task 3: O coração do painel usa a comemoração

- [ ] Em `src/NowPlayingPanel.qml`, substituir o `IconButton` do coração (hoje nas
      **linhas 326 a 332**, o de `icon: root.info.liked === true ? "heart-filled" : "heart"`)
      por:

```qml
            IconButton {
                id: botaoCurtir

                visible: root.trackId > 0 && !root.episodeMode
                icon: root.info.liked === true ? "heart-filled" : "heart"
                size: Theme.fontSizeXL
                accent: root.info.liked === true
                onClicked: {
                    // O estado ainda é o antigo aqui: comemorar só quando o clique vai
                    // CURTIR. Descurtir troca o desenho e mais nada.
                    if (root.info.liked !== true)
                        botaoCurtir.comemorar()
                    root.likeRequested(root.trackId)
                }
            }
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] verificação mecânica da task — a assimetria existe também no painel:
      `grep -c 'if (root.info.liked !== true)' src/NowPlayingPanel.qml` → `1`
- [ ] commit:

```bash
git add src/NowPlayingPanel.qml
git commit -m "feat(panel): the like button pops when it lights up"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → exit 0
- `ctest --test-dir build -N | awk '/Total Tests:/ {print $3}'` → `11` (piso de contagem)
- `bash tools/check-orfaos.sh` → exit 0
- `bash tools/check-fidelidade.sh` → exit 0
- `bash tools/check-layout.sh` → exit 0
- `grep -c 'onLikedChanged' src/TrackRow.qml` → `0`
- **Decisão humana (esta fatia não fecha sem o Pedro ver na tela):** curtir e descurtir a
  mesma faixa umas cinco vezes, na lista e no painel, e julgar o pulo. Se ele parecer
  exagerado, os números a mexer são `Theme.popEscala` (1,3) e `Theme.popOvershoot` (2,5), nos
  dois lugares de uma vez. Rolar uma lista com faixas curtidas: nenhum coração pode pular
  durante a rolagem — se pular, o disparo escorregou para o estado.

## Fora de escopo

- **Partículas, coração subindo, confete.** Nada disso sobrevive à segunda semana de uso, e
  neste app significaria pintar por cima de uma lista densa que o usuário está lendo.
- **Comemorar ao guardar numa coleção** (o botão `+`). Guardar abre um menu — a resposta ao
  clique é o menu abrindo, e um pulo antes dele seria ruído duplicado.
- **Som ao curtir.** O app é um player: qualquer som de interface disputa com a música.
