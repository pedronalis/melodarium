import QtQuick
import QtQuick.Layouts
import Melodia.App

// Same visual grammar as TrackRow, with one deliberate swap: podcast has no cover per
// episode, so the artwork slot carries the listening progress instead. Podcast is the one
// place where "where did I stop" matters more than "what does it look like".
Item {
    id: root

    property string title: ""
    property int durationMs: 0
    property int positionMs: 0
    property bool played: false
    property bool isCurrent: false
    property int episodeId: 0
    property double publishedAt: 0

    readonly property real progress: durationMs > 0
                                     ? Math.min(1.0, positionMs / durationMs)
                                     : 0.0

    signal activated
    signal playedToggled

    implicitHeight: Theme.marginXL * 3

    function formatRemaining(total, done) {
        const left = Math.max(0, Math.floor((total - done) / 1000))
        if (total <= 0)
            return "--:--"
        const minutes = Math.floor(left / 60)
        const seconds = left % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    function formatDate(secs) {
        if (secs <= 0)
            return ""
        return new Date(secs * 1000).toLocaleDateString(Qt.locale(), Locale.ShortFormat)
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

            // Progress ring stand-in: a filled arc would need Shapes, and a bar reads the
            // same at this size.
            Rectangle {
                Layout.preferredWidth: root.height - Theme.marginS * 2
                Layout.preferredHeight: root.height - Theme.marginS * 2
                radius: Theme.radiusXXS
                color: Theme.mSurface
                clip: true

                Text {
                    anchors.centerIn: parent
                    text: Icons.get(root.played ? "heart" : "playlist")
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeM
                    color: root.played ? Theme.mPrimary : Theme.mOnSurfaceVariant
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Theme.borderM
                    color: Theme.mSurface

                    Rectangle {
                        height: parent.height
                        width: parent.width * root.progress
                        color: Theme.mPrimary
                    }
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
                    color: mouse.containsMouse
                           ? Theme.mOnHover
                           : (root.isCurrent ? Theme.mPrimary
                                             : (root.played ? Theme.mOnSurfaceVariant
                                                            : Theme.mOnSurface))
                }
                Text {
                    Layout.fillWidth: true
                    text: root.progress > 0 && !root.played
                          ? qsTr("faltam %1").arg(root.formatRemaining(root.durationMs,
                                                                      root.positionMs))
                          : root.formatDate(root.publishedAt)
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurfaceVariant
                }
            }

            // Marking played by hand is the podcast equivalent of the collection plus: the
            // one gesture the app cannot infer.
            IconButton {
                icon: "heart"
                size: Theme.fontSizeS
                accent: root.played
                opacity: root.played || mouse.containsMouse ? 1.0 : 0.45
                onClicked: root.playedToggled()

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }
            }

            Text {
                text: root.formatRemaining(root.durationMs, 0)
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeS
                color: mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurfaceVariant
            }
        }
    }
}
