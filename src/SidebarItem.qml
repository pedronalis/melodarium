import QtQuick
import QtQuick.Layouts
import Melodia.App

Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool selected: false
    property int badge: 0

    signal clicked

    implicitHeight: Theme.marginXL * 2
    implicitWidth: 200

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.marginXXS
        radius: Theme.radiusXS
        color: root.selected ? Theme.mPrimary
                             : (mouse.containsMouse ? Theme.mHover : "transparent")

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.marginM
            anchors.rightMargin: Theme.marginM
            spacing: Theme.marginS

            Text {
                text: Icons.get(root.icon)
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeM
                color: root.selected ? Theme.mOnPrimary
                                     : (mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurface)
            }
            Text {
                Layout.fillWidth: true
                text: root.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                font.weight: root.selected ? Theme.fontWeightSemiBold : Theme.fontWeightMedium
                color: root.selected ? Theme.mOnPrimary
                                     : (mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurface)
            }
            Text {
                visible: root.badge > 0
                text: root.badge
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: root.selected ? Theme.mOnPrimary : Theme.mOnSurfaceVariant
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
