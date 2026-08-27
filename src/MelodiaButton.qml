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
        color: root.outlined
               ? (mouse.containsMouse ? Theme.mHover : "transparent")
               : (mouse.containsMouse ? Theme.mHover : Theme.mPrimary)
        border.width: root.outlined ? Theme.borderS : 0
        border.color: Theme.mOutline

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeM
            font.weight: Theme.fontWeightSemiBold
            color: mouse.containsMouse
                   ? Theme.mOnHover
                   : (root.outlined ? Theme.mOnSurface : Theme.mOnPrimary)

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
