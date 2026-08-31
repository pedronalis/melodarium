pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodarium.App

// A reprodução continua global sem roubar a identidade da aba aberta. Três zonas de largura
// igual deixam o transporte no centro geométrico da janela — metadata maior ou volume menor
// não empurram o play para um dos cantos.
Rectangle {
    id: root

    property bool episodeMode: false
    // The shell rises first; metadata and controls enter only after it has settled.
    property real contentReveal: 1
    property var trackInfo: ({})
    property var episodeInfo: ({})
    property real volumeBeforeMute: 100

    signal queueOpenRequested

    readonly property bool hasTrack: AudioEngine.currentFile !== ""
    readonly property bool muted: AudioEngine.volume <= 0
    readonly property bool compact: root.width < Math.round(820 * Theme.uiScale)
    readonly property double coverRevision: CoverCache.revision
    readonly property url coverSource: root.episodeMode
        ? (root.episodeInfo.coverPath !== undefined && root.episodeInfo.coverPath !== ""
           ? "file://" + root.episodeInfo.coverPath : "")
        : (root.coverRevision >= 0 && root.trackInfo.albumId !== undefined
           ? CoverCache.coverUrlForTrack(AudioEngine.currentFile, root.trackInfo.albumId) : "")
    readonly property string title: root.episodeMode
        ? (root.episodeInfo.title !== undefined ? root.episodeInfo.title : "")
        : (root.trackInfo.title !== undefined && root.trackInfo.title !== ""
           ? root.trackInfo.title : qsTr("áudio em reprodução"))
    readonly property string subtitle: root.episodeMode
        ? (root.episodeInfo.showTitle !== undefined ? root.episodeInfo.showTitle : qsTr("Podcast"))
        : (root.trackInfo.artist !== undefined ? root.trackInfo.artist : "")

    // Instrumentação da geometria real, usada pelo gate nas janelas nominal e mínima.
    readonly property bool layoutFits:
        leftZone.width >= cover.width + Theme.marginL + Math.round(76 * Theme.uiScale)
        && centerZone.width + 1 >= transportRow.implicitWidth
        && rightZone.width + 1 >= utilityRow.implicitWidth
    readonly property bool transportCentered:
        Math.abs(centerZone.parent.x + centerZone.x + centerZone.width / 2
                 - root.width / 2) <= 2
    readonly property string transportKind: root.episodeMode ? "podcast" : "music"
    readonly property bool nativeSpeedMenu:
        root.episodeMode && speedControl.nativeMenuPreferred

    implicitHeight: Math.round(82 * Theme.uiScale)
    color: Theme.cRaised

    function refresh() {
        const path = AudioEngine.currentFile
        root.trackInfo = path === "" ? ({}) : LibraryBrowser.trackForPath(path)
        root.episodeInfo = path === "" ? ({}) : PodcastLibrary.episodeForPath(path)
    }

    function formatTime(seconds) {
        if (!(seconds > 0))
            return "0:00"
        const total = Math.floor(seconds)
        const minutes = Math.floor(total / 60)
        const secs = total % 60
        return minutes + ":" + (secs < 10 ? "0" : "") + secs
    }

    function seekAt(mouseX, trackWidth) {
        if (AudioEngine.duration > 0 && trackWidth > 0)
            AudioEngine.seek(AudioEngine.duration * Math.max(0, Math.min(1, mouseX / trackWidth)))
    }

    function setVolumeAt(mouseX, trackWidth) {
        if (trackWidth > 0)
            AudioEngine.setVolume(100 * Math.max(0, Math.min(1, mouseX / trackWidth)))
    }

    function openSpeedMenu() {
        if (root.episodeMode)
            speedControl.openMenu()
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: AudioEngine
        function onCurrentFileChanged() { root.refresh() }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.borderS
        color: Theme.cLine
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginL
        anchors.rightMargin: Theme.marginL
        anchors.topMargin: Theme.marginS
        anchors.bottomMargin: Theme.marginS
        spacing: 0
        opacity: root.contentReveal
        enabled: root.contentReveal >= 0.99
        transform: Translate {
            y: (1 - root.contentReveal) * Math.round(6 * Theme.uiScale)
        }

        Item {
            id: leftZone
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Theme.marginL
                spacing: Theme.marginL

                RoundedCover {
                    id: cover
                    Layout.preferredWidth: Math.round(52 * Theme.uiScale)
                    Layout.preferredHeight: Math.round(52 * Theme.uiScale)
                    Layout.minimumWidth: Layout.preferredWidth
                    Layout.minimumHeight: Layout.preferredHeight
                    radius: Theme.radiusXS
                    source: root.coverSource
                    fallbackIcon: root.episodeMode ? "microphone" : "music"
                    fallbackIconSize: Theme.fontSizeXL
                    placeholderTop: root.episodeMode ? Theme.cCoverTopPod : Theme.cCoverTop
                    placeholderMid: root.episodeMode ? Theme.cCoverMidPod : Theme.cCoverMid
                    fallbackIconColor: root.episodeMode
                                       ? Theme.cCoverIconPod : Theme.cCoverIcon
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Theme.marginXXS

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeM
                        font.weight: Theme.fontWeightSemiBold
                        color: Theme.cTitle
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.subtitle
                        visible: text !== ""
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.cSecondary
                    }
                }
            }
        }

        Item {
            id: centerZone
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width, Math.round(430 * Theme.uiScale))
                spacing: Theme.marginXS

                RowLayout {
                    id: transportRow
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.marginM

                    SpeedControl {
                        id: speedControl
                        visible: root.episodeMode
                        speed: AudioEngine.speed
                        onSpeedPicked: function (value) { AudioEngine.setSpeed(value) }
                    }

                    IconButton {
                        visible: !root.episodeMode
                        icon: "shuffle"
                        size: Theme.fontSizeL
                        baseColor: Theme.cMuted
                        accent: AudioEngine.shuffle
                        tooltip: AudioEngine.shuffle
                                 ? qsTr("aleatório ligado") : qsTr("aleatório")
                        onClicked: AudioEngine.setShuffle(!AudioEngine.shuffle)
                    }

                    IconButton {
                        icon: root.episodeMode ? "skip-back" : "track-prev"
                        size: Theme.fontSizeL
                        tooltip: root.episodeMode ? qsTr("voltar 30 s") : qsTr("faixa anterior")
                        onClicked: {
                            if (root.episodeMode)
                                AudioEngine.seek(Math.max(0, AudioEngine.position - 30))
                            else
                                AudioEngine.previous()
                        }
                    }

                    Rectangle {
                        id: playButton
                        Layout.preferredWidth: Math.round(40 * Theme.uiScale)
                        Layout.preferredHeight: Math.round(40 * Theme.uiScale)
                        radius: width / 2
                        color: Theme.cTitle
                        scale: playArea.pressed ? 0.94 : 1.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.animationFaster
                                easing.type: Theme.easingType
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.get(AudioEngine.playing && root.hasTrack ? "pause" : "play")
                            font.family: Icons.fontFamily
                            font.pixelSize: Theme.fontSizeXL
                            color: Theme.cBase
                        }

                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioEngine.togglePause()
                        }
                    }

                    IconButton {
                        icon: root.episodeMode ? "skip-forward" : "track-next"
                        size: Theme.fontSizeL
                        tooltip: root.episodeMode
                                 ? qsTr("avançar 30 s") : qsTr("próxima faixa")
                        onClicked: {
                            if (root.episodeMode)
                                AudioEngine.seek(AudioEngine.position + 30)
                            else
                                AudioEngine.next()
                        }
                    }

                    IconButton {
                        visible: !root.episodeMode
                        icon: "repeat"
                        size: Theme.fontSizeL
                        baseColor: Theme.cMuted
                        accent: AudioEngine.repeatMode !== AudioEngine.RepeatOff
                        tooltip: AudioEngine.repeatMode === AudioEngine.RepeatOne
                                 ? qsTr("repetir esta faixa")
                                 : (AudioEngine.repeatMode === AudioEngine.RepeatAll
                                    ? qsTr("repetir a fila") : qsTr("repetir"))
                        onClicked: AudioEngine.cycleRepeat()

                        Text {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            visible: AudioEngine.repeatMode === AudioEngine.RepeatOne
                            text: "1"
                            font.family: Theme.fontFamilyFixed
                            font.pixelSize: Theme.fontSizeXXS
                            font.weight: Theme.fontWeightBold
                            color: Theme.cAccent
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.marginS

                    Text {
                        Layout.preferredWidth: Math.round(34 * Theme.uiScale)
                        horizontalAlignment: Text.AlignRight
                        text: root.formatTime(AudioEngine.position)
                        font.family: Theme.fontFamilyFixed
                        font.pixelSize: Theme.fontSizeXXS
                        color: Theme.cMuted
                    }

                    Rectangle {
                        id: progressTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(3, Math.round(3 * Theme.uiScale))
                        radius: Theme.radiusTrack
                        color: Theme.cLine

                        readonly property real fraction: AudioEngine.duration > 0
                            ? Math.max(0, Math.min(1, AudioEngine.position / AudioEngine.duration))
                            : 0

                        Rectangle {
                            width: progressTrack.width * progressTrack.fraction
                            height: parent.height
                            radius: parent.radius
                            color: progressArea.containsMouse ? Theme.cAccent : Theme.cStrong

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animationFast
                                    easing.type: Theme.easingType
                                }
                            }
                        }

                        Rectangle {
                            width: Math.round(8 * Theme.uiScale)
                            height: width
                            radius: width / 2
                            x: Math.max(0, Math.min(parent.width - width,
                                                   parent.width * progressTrack.fraction - width / 2))
                            anchors.verticalCenter: parent.verticalCenter
                            visible: progressArea.containsMouse || progressArea.pressed
                            color: Theme.cTitle
                        }

                        MouseArea {
                            id: progressArea
                            anchors.fill: parent
                            anchors.margins: -Theme.marginXS
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: function (mouse) {
                                root.seekAt(mouse.x + Theme.marginXS, progressTrack.width)
                            }
                            onPositionChanged: function (mouse) {
                                if (pressed)
                                    root.seekAt(mouse.x + Theme.marginXS, progressTrack.width)
                            }
                        }
                    }

                    Text {
                        Layout.preferredWidth: Math.round(34 * Theme.uiScale)
                        text: root.formatTime(AudioEngine.duration)
                        font.family: Theme.fontFamilyFixed
                        font.pixelSize: Theme.fontSizeXXS
                        color: Theme.cMuted
                    }
                }
            }
        }

        Item {
            id: rightZone
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0

            RowLayout {
                id: utilityRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.marginM

                IconButton {
                    icon: "list"
                    size: Theme.fontSizeL
                    baseColor: Theme.cMuted
                    accent: AudioEngine.queueCount > 1
                    tooltip: qsTr("abrir fila")
                    onClicked: root.queueOpenRequested()
                }

                IconButton {
                    icon: root.muted ? "volume-off"
                                     : (AudioEngine.volume < 50 ? "volume-low" : "volume")
                    size: Theme.fontSizeL
                    baseColor: root.muted ? Theme.cMuted : Theme.cTitle
                    tooltip: root.muted ? qsTr("com som") : qsTr("mudo")
                    onClicked: {
                        if (root.muted) {
                            AudioEngine.setVolume(root.volumeBeforeMute)
                        } else {
                            root.volumeBeforeMute = AudioEngine.volume
                            AudioEngine.setVolume(0)
                        }
                    }
                }

                Rectangle {
                    id: volumeTrack
                    visible: !root.compact
                    Layout.preferredWidth: Math.round(92 * Theme.uiScale)
                    Layout.preferredHeight: Math.max(3, Math.round(3 * Theme.uiScale))
                    radius: Theme.radiusTrack
                    color: Theme.cLine

                    readonly property real fraction: Math.max(0, Math.min(1,
                                                                          AudioEngine.volume / 100))

                    Rectangle {
                        width: parent.width * volumeTrack.fraction
                        height: parent.height
                        radius: parent.radius
                        color: volumeArea.containsMouse ? Theme.cAccent : Theme.cStrong
                    }

                    Rectangle {
                        width: Math.round(8 * Theme.uiScale)
                        height: width
                        radius: width / 2
                        x: Math.max(0, Math.min(parent.width - width,
                                               parent.width * volumeTrack.fraction - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        visible: volumeArea.containsMouse || volumeArea.pressed
                        color: Theme.cTitle
                    }

                    MouseArea {
                        id: volumeArea
                        anchors.fill: parent
                        anchors.margins: -Theme.marginXS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: function (mouse) {
                            root.setVolumeAt(mouse.x + Theme.marginXS, volumeTrack.width)
                        }
                        onPositionChanged: function (mouse) {
                            if (pressed)
                                root.setVolumeAt(mouse.x + Theme.marginXS, volumeTrack.width)
                        }
                    }
                }
            }
        }
    }
}
