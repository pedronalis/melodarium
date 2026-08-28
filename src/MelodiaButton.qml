import QtQuick
import Melodia.App

Item {
    id: root

    property string text: ""
    property bool outlined: false

    signal clicked

    implicitWidth: label.implicitWidth + Theme.marginXL * 2
    implicitHeight: label.implicitHeight + Theme.marginM * 2
    opacity: enabled ? 1.0 : 0.5

    Rectangle {
        anchors.fill: parent
        radius: Theme.iRadiusS
        // O desenho não tem botão sólido claro em lugar nenhum — o único disco claro da tela é
        // o de tocar. Com fundo de acento, "Trocar", "Reler a pasta" e os dois interruptores de
        // qualidade ficavam mais claros que o título da faixa e puxavam o olho para o canto
        // errado; um deles, desligado, ainda lia como ligado.
        // Preenchido e contornado precisam continuar sendo dois estados VISÍVEIS: é esse par
        // que diz ligado/desligado nos dois interruptores de qualidade de áudio.
        color: root.outlined
               ? (mouse.containsMouse ? Theme.cPill : "transparent")
               : (mouse.containsMouse ? Theme.cPill : Theme.cLine)
        border.width: root.outlined ? Theme.borderS : 0
        border.color: Theme.cLine

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.weight: Theme.fontWeightMedium
            color: mouse.containsMouse
                   ? Theme.cTitle
                   : (root.outlined ? Theme.cMuted : Theme.cTitle)

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
