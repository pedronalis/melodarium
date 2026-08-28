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
    property real fallbackIconSize: Theme.fontSizeXXXL
    property color fallbackIconColor: Theme.cLine
    // A capa grande do painel é a única que projeta sombra (design/Main.dc.html).
    property bool shadow: false

    readonly property bool ready: img.ready

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

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: !root.ready
        // O desenho não põe retângulo cinza no lugar da capa que falta: põe um degradê, que é
        // o que faz o quadrado vazio parecer arte e não buraco.
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(root.placeholderColor, 1.9) }
            GradientStop { position: 0.45; color: Qt.lighter(root.placeholderColor, 1.35) }
            GradientStop { position: 1.0; color: root.placeholderColor }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.get(root.fallbackIcon)
            font.family: Icons.fontFamily
            font.pixelSize: root.fallbackIconSize
            color: root.fallbackIconColor
        }
    }

    RoundedImage {
        id: img
        anchors.fill: parent
        source: root.source
        radius: root.radius
    }
}
