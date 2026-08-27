import QtQuick
import QtQuick.Layouts
import Melodia.App

RowLayout {
    id: root

    property string url: ""
    property string title: ""
    property real received: 0
    property real total: -1

    signal cancelRequested

    readonly property bool sizeKnown: total > 0

    spacing: Theme.marginS

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.marginXXS

        Text {
            Layout.fillWidth: true
            text: root.title !== "" ? root.title : root.url
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeS
            color: Theme.mOnSurface
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderL
            radius: height / 2
            color: Theme.mSurface

            // The server does not always declare a size. When it does not, the bar shows a
            // steady sliver instead of a fake percentage — an invented number is worse than
            // an honest "baixando…".
            Rectangle {
                height: parent.height
                radius: parent.radius
                color: Theme.mPrimary
                width: root.sizeKnown
                       ? parent.width * Math.min(1.0, root.received / root.total)
                       : parent.width * 0.15
            }
        }
    }

    Text {
        text: root.sizeKnown
              ? Math.round(root.received / root.total * 100) + "%"
              : qsTr("baixando…")
        font.family: Theme.fontFamilyFixed
        font.pointSize: Theme.fontSizeXS
        color: Theme.mOnSurfaceVariant
    }

    IconButton {
        icon: "close"
        size: Theme.fontSizeS
        onClicked: root.cancelRequested()
    }
}
