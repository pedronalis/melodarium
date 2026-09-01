import QtQuick
import Melodarium.App

Item {
    id: root

    property string text: ""
    property bool outlined: false

    signal clicked

    implicitWidth: label.implicitWidth + Theme.marginXL * 2
    implicitHeight: label.implicitHeight + Theme.marginM * 2
    opacity: enabled ? 1.0 : 0.5
    activeFocusOnTab: enabled && visible

    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.description: root.text
    Accessible.focusable: enabled && visible
    Accessible.onPressAction: if (root.enabled) root.clicked()

    Keys.onSpacePressed: function(event) {
        if (root.enabled)
            root.clicked()
        event.accepted = true
    }
    Keys.onReturnPressed: function(event) {
        if (root.enabled)
            root.clicked()
        event.accepted = true
    }
    Keys.onEnterPressed: function(event) {
        if (root.enabled)
            root.clicked()
        event.accepted = true
    }
    Keys.onTabPressed: function(event) {
        const next = root.nextItemInFocusChain(true)
        if (next)
            next.forceActiveFocus(Qt.TabFocusReason)
        event.accepted = true
    }
    Keys.onBacktabPressed: function(event) {
        const previous = root.nextItemInFocusChain(false)
        if (previous)
            previous.forceActiveFocus(Qt.BacktabFocusReason)
        event.accepted = true
    }

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
        border.width: root.activeFocus ? Theme.borderM : (root.outlined ? Theme.borderS : 0)
        border.color: root.activeFocus ? Theme.cAccent : Theme.cLine

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
