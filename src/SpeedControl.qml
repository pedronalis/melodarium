import QtQuick
import QtQuick.Controls
import Melodia.App

// A velocidade de fala como o desenho do podcast mostra: uma pílula discreta com o valor
// atual, e um menu com os passos. Seis botões lado a lado não caberiam no transporte.
Rectangle {
    id: root

    property real speed: 1.0

    signal speedPicked(real value)

    readonly property var opcoes: [0.8, 1.0, 1.25, 1.5, 1.75, 2.0]

    implicitWidth: label.implicitWidth + Theme.marginL * 2
    implicitHeight: Math.round(26 * Theme.uiScale)
    radius: Theme.iRadiusS
    color: area.containsMouse ? Theme.mSurfaceVariant : "transparent"
    border.width: Theme.borderS
    border.color: Theme.mSurfaceVariant

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
    }

    function formatSpeed(v) {
        // 1x, 1.5x, 1.25x — nunca 1.00x.
        return String(Math.round(v * 100) / 100) + "x"
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.formatSpeed(root.speed)
        font.family: Theme.fontFamilyFixed
        font.pointSize: Theme.fontSizeS
        color: Math.abs(root.speed - 1.0) < 0.01 ? Theme.mOnSurfaceVariant : Theme.mOnSurface
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.popup(root, 0, root.height + Theme.marginXS)
    }

    Menu {
        id: menu

        Repeater {
            model: root.opcoes

            MenuItem {
                required property real modelData
                text: root.formatSpeed(modelData)
                onTriggered: root.speedPicked(modelData)
            }
        }
    }
}
