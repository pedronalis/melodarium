import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property string text: ""
    property bool removable: false

    signal removeRequested
    signal clicked

    implicitWidth: row.implicitWidth + Theme.marginM * 2
    implicitHeight: Theme.marginXL * 1.4
    radius: height / 2
    color: mouse.containsMouse ? Theme.mHover : Theme.mSurface
    border.width: Theme.borderS
    border.color: Theme.mOutline

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.marginXS

        Text {
            text: root.text
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeXS
            color: mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurface
        }
        Text {
            visible: root.removable
            text: Icons.get("close")
            font.family: Icons.fontFamily
            font.pointSize: Theme.fontSizeXXS
            color: mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurfaceVariant

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.marginXS
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeRequested()
            }
        }
    }
}
