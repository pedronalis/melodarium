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
            text: Icons.get(root.icon)
            font.family: Icons.fontFamily
            font.pixelSize: root.size
            color: mouse.containsMouse && root.enabled
                   ? Theme.cTitle
                   : (root.accent ? Theme.cAccent : root.baseColor)

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
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
