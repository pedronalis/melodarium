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

    // Sem o corte, as molduras que compõem a luz saem do painel e passam a se ver COMO
    // molduras: um retângulo arredondado gigante desenhado por cima do rail e da lista.
    // Medido nas duas versões em 2026-08-29. A luz termina onde o painel termina — é uma
    // janela iluminada, e a moldura dela é a borda da coluna.
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
