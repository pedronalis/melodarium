import QtQuick
import Melodarium.App

// A luz que a capa joga no painel — o "ambient mode" do YouTube, feito do jeito que este app
// pode fazer.
//
// Por que não é a capa desfocada: borrar imagem no QML é MultiEffect, e MultiEffect é shader.
// No adaptador de software (que é como o app é fotografado, e como ele roda numa máquina sem
// GPU) o shader não desenha NADA e leva a capa junto
// (docs/solutions/ui/2026-08-28-a-tela-passava-nos-gates-e-nao-era-o-desenho.md).
//
// A PRIMEIRA tentativa empilhou catorze molduras translúcidas, como a sombra da capa fazia. Não
// funciona para luz: cada moldura tem borda dura, e catorze bordas duras são uma ESCADA, não um
// degradê — foi a reclamação do Pedro em 29/08, "está com muitas camadas, não está smooth".
//
// Isto aqui é degradê de verdade: `Canvas` com `createRadialGradient`, que por baixo é QPainter
// — o mesmo caminho que o placeholder diagonal da capa já usa, e o único que sobrevive ao
// adaptador de software. Um Canvas por foco de luz, cada um com a cor de um pedaço da arte.
//
// A deriva não repinta nada: o Canvas de cada foco é pintado UMA vez por troca de faixa, e o
// que se move é a posição do item. Mover é transformação de cena; repintar seria varrer meio
// milhão de pixels sessenta vezes por segundo para um fundo que ninguém está olhando.
Item {
    id: root

    // Sem o corte, os focos saem do painel e a luz do álbum invade o trilho de ícones e a
    // lista. A luz termina onde o painel termina — é uma janela iluminada, e a moldura dela é
    // a borda da coluna. Medido nas duas versões em 2026-08-29.
    clip: true

    // Os focos da capa: `[{ color, x, y, weight }]`, vindos de `RoundedCover.palette`. Lista
    // vazia = arte sem cor = nenhuma luz, que é melhor do que uma mancha cinza.
    property var focos: []

    // Onde a capa está, em coordenadas do painel. Não sai de mapToItem: o mapeamento não é
    // reativo, e a capa muda de tamanho com a altura da janela.
    property int capaX: 0
    property int capaY: 0
    property int capaLado: 0

    // O raio de cada foco, em fração do lado da capa. Grande de propósito: luz que termina
    // perto da arte vira contorno, e contorno é justamente o que a versão de camadas parecia.
    property real alcance: 0.85

    // O pico de opacidade no centro de um foco de peso 1. Em 0,35 (a primeira versão) a luz
    // competia com a própria capa; aqui ela levanta o fundo do painel sem disputar com a arte.
    property real intensidade: 0.18

    // Quanto cada foco passeia, em pixels. Um oitavo de segundo de olhar não pega o movimento;
    // meio minuto de música, sim.
    readonly property real amplitude: Math.round(14 * Theme.uiScale)

    Repeater {
        model: root.focos

        Canvas {
            id: foco

            required property var modelData
            required property int index

            readonly property real raio: Math.max(1, root.capaLado * root.alcance)
            // NÃO é `readonly`, e a diferença não é estilo: um `Behavior` numa propriedade
            // só de leitura faz o tipo inteiro deixar de carregar, EM SILÊNCIO — sem erro no
            // stderr, o app apenas sai com código 255. Mesma família da armadilha do `opened`
            // no Popup (src/SearchOverlay.qml). O binding abaixo continua sendo a fonte da
            // cor; o Behavior só intercepta a travessia.
            property color cor: foco.modelData.color
            readonly property real forca: root.intensidade * foco.modelData.weight

            // A fase de cada foco corre num período próprio e começa deslocada: em fase, os
            // quatro andariam como um bloco só e o olho leria a luz inteira balançando. Fora
            // de fase, o que se vê é a cor mudando de lugar devagar.
            property real fase: index * 1.7

            width: foco.raio * 2
            height: foco.raio * 2

            x: root.capaX + foco.modelData.x * root.capaLado - foco.raio
               + Math.cos(foco.fase) * root.amplitude
            y: root.capaY + foco.modelData.y * root.capaLado - foco.raio
               + Math.sin(foco.fase * 0.7) * root.amplitude

            // Um período por foco, todos longos e nenhum múltiplo do outro: períodos que se
            // dividem voltam a coincidir e a luz inteira pulsa junto de tempos em tempos.
            NumberAnimation on fase {
                running: !Theme.reduzirMovimento
                loops: Animation.Infinite
                from: foco.index * 1.7
                to: foco.index * 1.7 + 2 * Math.PI
                duration: 23000 + foco.index * 4700
            }

            onCorChanged: foco.requestPaint()
            onForcaChanged: foco.requestPaint()
            onRaioChanged: foco.requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                const g = ctx.createRadialGradient(foco.raio, foco.raio, 0,
                                                   foco.raio, foco.raio, foco.raio)
                // Quatro paradas, e não duas: uma reta de opaco a transparente deixa o miolo
                // chapado e a borda visível. A curva concentra a luz no centro e faz a cauda
                // morrer devagar, que é como luz cai.
                g.addColorStop(0.00, Qt.rgba(foco.cor.r, foco.cor.g, foco.cor.b, foco.forca))
                g.addColorStop(0.35, Qt.rgba(foco.cor.r, foco.cor.g, foco.cor.b, foco.forca * 0.45))
                g.addColorStop(0.70, Qt.rgba(foco.cor.r, foco.cor.g, foco.cor.b, foco.forca * 0.12))
                g.addColorStop(1.00, Qt.rgba(foco.cor.r, foco.cor.g, foco.cor.b, 0))

                ctx.fillStyle = g
                ctx.fillRect(0, 0, foco.width, foco.height)
            }

            // A troca de faixa troca a cor de cada foco, e ela cruza devagar: é fundo, ninguém
            // espera por ele, e uma luz de ambiente que muda em 150 ms lê como lâmpada
            // piscando. O Canvas repinta a cada passo da travessia — 750 ms de repaint por
            // troca de música é barato; 60 quadros por segundo para sempre não seria.
            Behavior on cor {
                ColorAnimation { duration: Theme.animationSlowest; easing.type: Theme.easingType }
            }
        }
    }
}
