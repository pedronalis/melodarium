import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property string coverUrl: ""

    implicitHeight: Theme.marginXL * 5
    color: Theme.mSurfaceVariant
    border.width: Theme.borderS
    border.color: Theme.mOutline
    radius: Theme.radiusM

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00"
        const total = Math.floor(seconds)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginM
        spacing: Theme.marginXS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Rectangle {
                Layout.preferredWidth: Theme.marginXL * 2.5
                Layout.preferredHeight: Theme.marginXL * 2.5
                radius: Theme.radiusXS
                color: Theme.mSurface
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.coverUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: root.coverUrl !== ""
                    sourceSize.width: 128
                    sourceSize.height: 128
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: AudioEngine.currentFile === ""
                          ? qsTr("nada tocando")
                          : trackTitleFromPath(AudioEngine.currentFile)
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeL
                    font.weight: Theme.fontWeightSemiBold
                    color: Theme.mOnSurface

                    function trackTitleFromPath(p) {
                        const parts = p.split("/")
                        return parts[parts.length - 1]
                    }
                }
            }

            IconButton {
                icon: "skip-back"
                enabled: AudioEngine.currentFile !== ""
                onClicked: AudioEngine.previous()
            }
            IconButton {
                icon: AudioEngine.playing ? "pause" : "play"
                accent: true
                size: Theme.fontSizeXXL
                enabled: AudioEngine.currentFile !== ""
                onClicked: AudioEngine.togglePause()
            }
            IconButton {
                icon: "skip-forward"
                enabled: AudioEngine.currentFile !== ""
                onClicked: AudioEngine.next()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS

            Text {
                text: root.formatTime(AudioEngine.position)
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOnSurfaceVariant
            }

            Item {
                id: track
                Layout.fillWidth: true
                implicitHeight: Theme.marginM

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Theme.borderL
                    radius: height / 2
                    color: Theme.mSurface
                    border.width: Theme.borderS
                    border.color: Qt.alpha(Theme.mOutline, 0.5)

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: Theme.mPrimary
                        width: AudioEngine.duration > 0
                               ? parent.width * (AudioEngine.position / AudioEngine.duration)
                               : 0
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: AudioEngine.duration > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: function (mouse) {
                        AudioEngine.seek(AudioEngine.duration * (mouse.x / width))
                    }
                }
            }

            Text {
                text: root.formatTime(AudioEngine.duration)
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOnSurfaceVariant
            }

            IconButton {
                icon: AudioEngine.volume <= 0 ? "volume-off"
                                              : (AudioEngine.volume < 50 ? "volume-low" : "volume")
                size: Theme.fontSizeL
                onClicked: AudioEngine.volume = AudioEngine.volume > 0 ? 0 : 100
            }
        }
    }
}
