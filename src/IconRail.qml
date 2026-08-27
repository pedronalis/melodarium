import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property string current: "library"

    signal chosen(string section)

    implicitWidth: 56
    color: "transparent"

    Rectangle {
        anchors.right: parent.right
        width: Theme.borderS
        height: parent.height
        color: Theme.mSurfaceVariant
    }

    readonly property var items: [
        { key: "library", icon: "list",     tip: qsTr("Biblioteca") },
        { key: "albums",  icon: "disc",     tip: qsTr("Álbuns") },
        { key: "tags",    icon: "tags",     tip: qsTr("Tags") },
        { key: "podcast", icon: "microphone", tip: qsTr("Podcast") },
        { key: "search",  icon: "search",   tip: qsTr("Buscar") }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.marginXL
        spacing: Theme.marginS

        Repeater {
            model: root.items

            Rectangle {
                id: cell

                required property var modelData

                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Theme.iRadiusS
                color: root.current === cell.modelData.key
                       ? Theme.mSurfaceVariant
                       : (area.containsMouse ? Theme.mSurfaceVariant : "transparent")
                opacity: root.current === cell.modelData.key || area.containsMouse ? 1.0 : 0.85

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.get(cell.modelData.icon)
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeL
                    color: root.current === cell.modelData.key ? Theme.mTertiary : Theme.mOnSurfaceVariant
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chosen(cell.modelData.key)
                }
            }
        }
    }
}
