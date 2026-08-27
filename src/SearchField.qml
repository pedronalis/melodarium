import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property alias text: input.text

    signal searchChanged(string text)

    implicitHeight: Theme.marginXL * 2
    radius: Theme.iRadiusS
    color: Theme.mSurface
    border.width: Theme.borderS
    border.color: input.activeFocus ? Theme.mPrimary : Theme.mOutline

    Behavior on border.color {
        ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginM
        anchors.rightMargin: Theme.marginS
        spacing: Theme.marginS

        Text {
            text: Icons.get("search")
            font.family: Icons.fontFamily
            font.pointSize: Theme.fontSizeM
            color: Theme.mOnSurfaceVariant
        }

        TextInput {
            id: input
            Layout.fillWidth: true
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeM
            color: Theme.mOnSurface
            selectionColor: Theme.mPrimary
            selectedTextColor: Theme.mOnPrimary
            clip: true

            // Debounce: searching on every keystroke re-runs FTS5 for each letter typed.
            onTextChanged: debounce.restart()

            Timer {
                id: debounce
                interval: 180
                onTriggered: root.searchChanged(input.text)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === "" && !input.activeFocus
                text: qsTr("buscar…")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurfaceVariant
            }
        }

        IconButton {
            icon: "close"
            size: Theme.fontSizeS
            visible: input.text !== ""
            onClicked: {
                input.text = ""
                root.searchChanged("")
            }
        }
    }
}
