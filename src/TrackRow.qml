import QtQuick
import QtQuick.Layouts
import Melodia.App

Item {
    id: root

    property string title: ""
    property string artist: ""
    property string album: ""
    property int durationMs: 0
    property string coverUrl: ""
    property bool isCurrent: false
    property int trackId: 0
    property bool showCollectButton: false
    // "local_file" or "youtube". The badge is how the spec's honest limit reaches the eye:
    // compressed audio lives next to the real files without passing for one.
    property string sourceKind: "local_file"

    signal activated
    signal collectRequested

    implicitHeight: Theme.marginXL * 3

    function formatDuration(ms) {
        if (ms <= 0)
            return "--:--"
        const total = Math.floor(ms / 1000)
        const minutes = Math.floor(total / 60)
        const seconds = total % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginS
        anchors.rightMargin: Theme.marginS
        radius: Theme.radiusXS
        color: mouse.containsMouse ? Theme.mHover
                                   : (root.isCurrent ? Theme.mSurfaceVariant : "transparent")

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        // Declared before the row content on purpose: the collect button sits inside the
        // RowLayout and has to receive its own clicks, which a MouseArea stacked on top
        // of it would swallow.
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.marginM
            anchors.rightMargin: Theme.marginM
            spacing: Theme.marginM

            Rectangle {
                Layout.preferredWidth: root.height - Theme.marginS * 2
                Layout.preferredHeight: root.height - Theme.marginS * 2
                radius: Theme.radiusXXS
                color: Theme.mSurface
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.coverUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: root.coverUrl !== ""
                    sourceSize.width: 96
                    sourceSize.height: 96
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.coverUrl === ""
                    text: Icons.get("music")
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeM
                    color: Theme.mOnSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeM
                    font.weight: Theme.fontWeightMedium
                    color: mouse.containsMouse ? Theme.mOnHover
                                               : (root.isCurrent ? Theme.mPrimary : Theme.mOnSurface)
                }
                Text {
                    Layout.fillWidth: true
                    text: root.artist + (root.album !== "" ? " — " + root.album : "")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurfaceVariant
                }
            }

            // The one manual gesture of the whole product. Always visible when enabled —
            // a control that only appears on hover is a control the user never finds.
            IconButton {
                icon: "plus"
                size: Theme.fontSizeS
                visible: root.showCollectButton
                opacity: mouse.containsMouse ? 1.0 : 0.45
                onClicked: root.collectRequested()

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }
            }

            SourceBadge {
                kind: root.sourceKind
            }

            Text {
                text: root.formatDuration(root.durationMs)
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeS
                color: mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurfaceVariant
            }
        }
    }
}
