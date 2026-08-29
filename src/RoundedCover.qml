import QtQuick
import Melodarium.App

// A capa do desenho tem canto arredondado — e no QML isso não sai de graça. `radius` desenha
// o canto do Rectangle, e `clip: true` recorta os filhos pelo RETÂNGULO do item, não pelo raio:
// a moldura arredondada ficava no código enquanto a imagem por cima dela seguia de canto vivo
// em todas as capas do app. Quem consertou foi a máscara: a imagem é pintada através de um
// retângulo arredondado, que é o que o navegador faz com `border-radius` numa `<img>`.
//
// Vale para as três medidas do desenho: 340 (painel), 62 (tirinha da fila) e as capinhas de
// lista. Sem capa, mostra o placeholder — que também é arredondado, senão o canto vivo só
// mudava de dono. Quem recorta é o RoundedImage (QPainter, em C++): a saída por shader some
// no adaptador de software, e com ela sumia a capa inteira.
Item {
    id: root

    property url source: ""
    property int radius: Theme.radiusM
    property string fallbackIcon: "music"
    property color placeholderColor: Theme.cRaised
    // Os dois tons de cima vêm do desenho (design/Main.dc.html:39), não de um clareamento
    // calculado: Qt.lighter multiplica o V do HSV, e partindo de #191919 ele chegava a
    // #2f2f2f onde o desenho manda #3a3a3a — o bloco nascia um terço mais fraco que o
    // aprovado, que é justamente o degradê que o olho registra nesta tela.
    property color placeholderTop: Theme.cCoverTop
    property color placeholderMid: Theme.cCoverMid
    property real fallbackIconSize: Theme.fontSizeXXXL
    property color fallbackIconColor: Theme.cCoverIcon
    // A capa grande do painel é a única que projeta sombra (design/Main.dc.html).
    property bool shadow: false

    readonly property bool ready: img.ready

    // A cor que esta arte "é", para quem quiser pintar luz com ela. Transparente (alpha 0)
    // enquanto não há capa carregada, ou quando a capa não tem cor a dar — capa em escala de
    // cinza, quase preta, quase branca.
    readonly property alias dominantColor: img.dominantColor

    // A sombra do desenho, empilhada em vez de borrada: um desfoque de verdade é shader, e
    // shader é justamente o que não sobrevive ao adaptador de software. Oito molduras cada vez
    // maiores e translúcidas dão a mesma queda de luz por baixo da arte.
    Repeater {
        model: root.shadow ? 8 : 0

        Rectangle {
            required property int index

            readonly property real avanco: (index + 1) / 8
            readonly property real folga: Theme.coverShadowBlur * avanco * 0.5

            x: -folga
            y: -folga + Theme.coverShadowY * avanco
            width: root.width + folga * 2
            height: root.height + folga * 2
            radius: root.radius + folga
            color: Theme.coverShadowColor
            opacity: 0.10
        }
    }

    // O desenho não põe retângulo cinza no lugar da capa que falta: põe um degradê, que é o
    // que faz o quadrado vazio parecer arte e não buraco. E o degradê dele é DIAGONAL
    // (`linear-gradient(145deg, …)`): a luz entra pelo canto de cima à esquerda e cai no de
    // baixo à direita. O `Gradient` do QML só sabe descer reto, e o placeholder vertical não
    // era o desenho — era a aproximação possível dentro do Rectangle.
    //
    // Quem dá o ângulo é este Canvas: por baixo ele é QPainter, o mesmo caminho do
    // RoundedImage, que é o único que sobrevive ao adaptador de software neste projeto (a
    // saída por shader some, e some junto a capa inteira).
    Canvas {
        id: placeholder

        anchors.fill: parent
        visible: !root.ready

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onPlaceholderTopChanged() { placeholder.requestPaint() }
            function onPlaceholderMidChanged() { placeholder.requestPaint() }
            function onPlaceholderColorChanged() { placeholder.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            // O ângulo do CSS conta a partir do "para cima" e cresce no sentido horário, e a
            // linha do degradê é centrada na caixa — por isso o vetor sai do centro para os
            // dois lados, e não de canto a canto: em 145° num quadrado ela mede 473 px numa
            // caixa de 340, e cortar isso nos cantos deslocaria as paradas de cor.
            const a = 145 * Math.PI / 180
            const dx = Math.sin(a)
            const dy = -Math.cos(a)
            const comprimento = Math.abs(width * dx) + Math.abs(height * dy)
            const cx = width / 2
            const cy = height / 2

            const g = ctx.createLinearGradient(cx - dx * comprimento / 2, cy - dy * comprimento / 2,
                                               cx + dx * comprimento / 2, cy + dy * comprimento / 2)
            g.addColorStop(0.0, root.placeholderTop)
            g.addColorStop(0.45, root.placeholderMid)
            g.addColorStop(1.0, root.placeholderColor)

            ctx.fillStyle = g
            ctx.beginPath()
            ctx.roundedRect(0, 0, width, height, root.radius, root.radius)
            ctx.fill()
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.ready && root.fallbackIcon !== ""
        text: Icons.get(root.fallbackIcon)
        font.family: Icons.fontFamily
        font.pixelSize: root.fallbackIconSize
        color: root.fallbackIconColor
    }

    RoundedImage {
        id: img
        anchors.fill: parent
        source: root.source
        radius: root.radius
    }
}
