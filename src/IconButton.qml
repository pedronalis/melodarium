import QtQuick
import Melodia.App

Item {
    id: root

    property string icon: ""
    property real size: Theme.fontSizeXL
    property bool accent: false
    property string tooltip: ""

    signal clicked

    implicitWidth: size * 2
    implicitHeight: size * 2
    opacity: enabled ? 1.0 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouse.containsMouse && root.enabled ? Theme.mHover : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.get(root.icon)
            font.family: Icons.fontFamily
            font.pointSize: root.size
            color: mouse.containsMouse && root.enabled
                   ? Theme.mOnHover
                   : (root.accent ? Theme.mPrimary : Theme.mOnSurface)

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
