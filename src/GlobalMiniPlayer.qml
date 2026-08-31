pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodarium.App

// Reprodução é global, mas não precisa dominar todo contexto. Esta barra aparece somente quando
// a coluna esquerda está falando da aba atual em vez do arquivo que continua tocando.
Rectangle {
    id: root

    property bool episodeMode: false
    property var trackInfo: ({})
    property var episodeInfo: ({})

    readonly property bool hasTrack: AudioEngine.currentFile !== ""
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

    implicitHeight: Math.round(64 * Theme.uiScale)
    color: Theme.cRaised

    function refresh() {
        const path = AudioEngine.currentFile
        root.trackInfo = path === "" ? ({}) : LibraryBrowser.trackForPath(path)
        root.episodeInfo = path === "" ? ({}) : PodcastLibrary.episodeForPath(path)
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
        anchors.rightMargin: Theme.marginXL
        anchors.topMargin: Theme.marginS
        anchors.bottomMargin: Theme.marginS
        spacing: Theme.marginL

        RoundedCover {
            Layout.preferredWidth: Math.round(44 * Theme.uiScale)
            Layout.preferredHeight: Math.round(44 * Theme.uiScale)
            radius: Theme.radiusXS
            source: root.coverSource
            fallbackIcon: root.episodeMode ? "microphone" : "music"
            fallbackIconSize: Theme.fontSizeL
            placeholderTop: root.episodeMode ? Theme.cCoverTopPod : Theme.cCoverTop
            placeholderMid: root.episodeMode ? Theme.cCoverMidPod : Theme.cCoverMid
            fallbackIconColor: root.episodeMode ? Theme.cCoverIconPod : Theme.cCoverIcon
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Math.round(430 * Theme.uiScale)
            spacing: Theme.marginXXS

            Text {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
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
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                color: Theme.cMuted
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(2, Math.round(2 * Theme.uiScale))
                radius: Theme.radiusTrack
                color: Theme.cLine

                Rectangle {
                    width: AudioEngine.duration > 0
                           ? parent.width * Math.min(1, AudioEngine.position / AudioEngine.duration)
                           : 0
                    height: parent.height
                    radius: parent.radius
                    color: Theme.cStrong
                }
            }
        }

        Item { Layout.fillWidth: true }

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
            Layout.preferredWidth: Math.round(34 * Theme.uiScale)
            Layout.preferredHeight: Math.round(34 * Theme.uiScale)
            radius: width / 2
            color: Theme.cTitle

            Text {
                anchors.centerIn: parent
                text: Icons.get(AudioEngine.playing && root.hasTrack ? "pause" : "play")
                font.family: Icons.fontFamily
                font.pixelSize: Theme.fontSizeL
                color: Theme.cBase
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: AudioEngine.togglePause()
            }
        }

        IconButton {
            icon: root.episodeMode ? "skip-forward" : "track-next"
            size: Theme.fontSizeL
            tooltip: root.episodeMode ? qsTr("avançar 30 s") : qsTr("próxima faixa")
            onClicked: {
                if (root.episodeMode)
                    AudioEngine.seek(AudioEngine.position + 30)
                else
                    AudioEngine.next()
            }
        }

        Text {
            Layout.preferredWidth: Math.round(46 * Theme.uiScale)
            horizontalAlignment: Text.AlignRight
            text: root.formatTime(AudioEngine.position)
            font.family: Theme.fontFamilyFixed
            font.pixelSize: Theme.fontSizeXS
            color: Theme.cFaint
        }
    }

    function formatTime(seconds) {
        if (!(seconds > 0))
            return "0:00"
        const total = Math.floor(seconds)
        const minutes = Math.floor(total / 60)
        const secs = total % 60
        return minutes + ":" + (secs < 10 ? "0" : "") + secs
    }
}
