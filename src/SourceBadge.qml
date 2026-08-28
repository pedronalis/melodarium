import QtQuick
import Melodarium.App

Rectangle {
    id: root

    property string kind: "local_file"

    visible: kind === "youtube"
    implicitWidth: label.implicitWidth + Theme.marginS * 2
    implicitHeight: Theme.marginL
    radius: height / 2
    color: "transparent"
    border.width: Theme.borderS
    border.color: Theme.cLine

    Text {
        id: label
        anchors.centerIn: parent
        // The spec is explicit: the app must not pretend compressed audio is the same thing
        // as the lossless files next to it.
        text: qsTr("YouTube")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeXXS
        color: Theme.cMuted
    }
}
