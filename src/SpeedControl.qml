import QtQuick
import QtQuick.Controls
import Melodarium.App

// Speech speed stays a discreet pill while its options share the application's menu surface.
Rectangle {
    id: root

    property real speed: 1.0

    signal speedPicked(real value)

    readonly property bool nativeMenuPreferred: menu.popupType === Popup.Native
    readonly property int optionCount: menu.count

    implicitWidth: label.implicitWidth + Theme.marginL * 2
    implicitHeight: Math.round(26 * Theme.uiScale)
    radius: Theme.iRadiusS
    color: area.containsMouse ? Theme.cRaised : "transparent"
    border.width: Theme.borderS
    border.color: Theme.cLine

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
    }

    function formatSpeed(v) {
        // 1x, 1.5x, 1.25x — nunca 1.00x.
        return String(Math.round(v * 100) / 100) + "x"
    }

    function openMenu() {
        menu.popup(root, 0, root.height + Theme.marginXS)
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.formatSpeed(root.speed)
        font.family: Theme.fontFamilyFixed
        font.pixelSize: Theme.fontSizeS
        color: Math.abs(root.speed - 1.0) < 0.01 ? Theme.cMuted : Theme.cTitle
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openMenu()
    }

    MelodariumMenu {
        id: menu
        title: qsTr("Velocidade")

        MelodariumMenuItem {
            text: root.formatSpeed(0.75)
            checkable: true
            checked: Math.abs(root.speed - 0.75) < 0.01
            onTriggered: root.speedPicked(0.75)
        }
        MelodariumMenuItem {
            text: root.formatSpeed(1.0)
            checkable: true
            checked: Math.abs(root.speed - 1.0) < 0.01
            onTriggered: root.speedPicked(1.0)
        }
        MelodariumMenuItem {
            text: root.formatSpeed(1.25)
            checkable: true
            checked: Math.abs(root.speed - 1.25) < 0.01
            onTriggered: root.speedPicked(1.25)
        }
        MelodariumMenuItem {
            text: root.formatSpeed(1.5)
            checkable: true
            checked: Math.abs(root.speed - 1.5) < 0.01
            onTriggered: root.speedPicked(1.5)
        }
        MelodariumMenuItem {
            text: root.formatSpeed(1.75)
            checkable: true
            checked: Math.abs(root.speed - 1.75) < 0.01
            onTriggered: root.speedPicked(1.75)
        }
        MelodariumMenuItem {
            text: root.formatSpeed(2.0)
            checkable: true
            checked: Math.abs(root.speed - 2.0) < 0.01
            onTriggered: root.speedPicked(2.0)
        }
    }
}
