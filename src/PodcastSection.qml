pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Melodia.App

// The whole Podcast tab. No collections and no tags anywhere in here: the spec organizes
// podcast by show, with "Continuar ouvindo" on top.
RowLayout {
    id: root

    property int currentShowId: 0
    property var shows: []
    // Set by Main.qml: the speed control only makes sense while an episode is the thing
    // playing, not while an album is.
    property bool episodePlaying: false
    property string currentPath: ""
    // episodeId -> { received, total }. Lives here rather than in the row because rows are
    // recycled while scrolling and would lose the progress of what is still downloading.
    property var downloads: ({})

    signal showChosen(int showId)

    spacing: Theme.marginM

    function refreshShows() {
        root.shows = PodcastLibrary.shows()
        if (root.currentShowId === 0 && root.shows.length > 0)
            root.selectShow(root.shows[0].id)
    }

    function currentShow() {
        for (let i = 0; i < root.shows.length; ++i) {
            if (root.shows[i].id === root.currentShowId)
                return root.shows[i]
        }
        return null
    }

    function progressOf(episodeId) {
        const entry = root.downloads[episodeId]
        if (entry === undefined)
            return -1
        return entry.total > 0 ? Math.min(1.0, entry.received / entry.total) : 0
    }

    function sizeKnownFor(episodeId) {
        const entry = root.downloads[episodeId]
        return entry !== undefined && entry.total > 0
    }

    function selectShow(showId) {
        root.currentShowId = showId
        episodeModel.loadForShow(showId)
        root.showChosen(showId)
    }

    Component.onCompleted: refreshShows()

    PodcastEpisodeModel {
        id: episodeModel
        currentPath: root.currentPath
    }

    Connections {
        target: PodcastLibrary
        function onShowsChanged() { root.refreshShows() }
        function onEpisodesChanged(showId) {
            if (showId === root.currentShowId)
                episodeModel.loadForShow(showId)
        }
        function onDownloadProgress(episodeId, received, total) {
            const next = root.downloads
            next[episodeId] = { received: received, total: total }
            root.downloads = next
        }
        function onDownloadFinished(episodeId) {
            const next = root.downloads
            delete next[episodeId]
            root.downloads = next
        }
        function onDownloadFailed(episodeId, reason) {
            const next = root.downloads
            delete next[episodeId]
            root.downloads = next
            downloadError.text = reason
        }
    }

    // --- Left: the shows ---
    Rectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: 220
        radius: Theme.radiusM
        color: Theme.mSurfaceVariant
        border.width: Theme.borderS
        border.color: Theme.mOutline
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.marginS
            spacing: Theme.marginXXS

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.marginM
                Layout.rightMargin: Theme.marginXS

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Programas")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    font.weight: Theme.fontWeightSemiBold
                    color: Theme.mOnSurfaceVariant
                }
                IconButton {
                    icon: "rss"
                    size: Theme.fontSizeS
                    onClicked: subscribeDialog.open()
                }
                IconButton {
                    icon: "folder"
                    size: Theme.fontSizeS
                    onClicked: podcastFolderDialog.open()
                }
                IconButton {
                    icon: "history"
                    size: Theme.fontSizeS
                    enabled: PodcastLibrary.podcastPath !== "" && !PodcastLibrary.scanning
                    onClicked: PodcastLibrary.scanPodcastFolder()
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.shows
                spacing: 0

                delegate: SidebarItem {
                    id: showEntry

                    required property var modelData

                    width: ListView.view.width
                    icon: "rss"
                    label: showEntry.modelData.title
                    badge: showEntry.modelData.unplayedCount
                    selected: root.currentShowId === showEntry.modelData.id
                    onClicked: root.selectShow(showEntry.modelData.id)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.marginM
                Layout.rightMargin: Theme.marginM
                visible: root.shows.length === 0
                wrapMode: Text.WordWrap
                text: qsTr("Escolha a pasta de podcast: uma subpasta por programa, ou assine um feed.")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOnSurfaceVariant
            }

            FeedStatusRow {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.marginM
                Layout.rightMargin: Theme.marginM
                Layout.bottomMargin: Theme.marginS
                showId: root.currentShowId
                lastCheckedAt: root.currentShow() !== null
                               ? root.currentShow().lastCheckedAt : 0
            }
        }
    }

    // --- Right: continue listening, then the episodes ---
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.radiusM
        color: Theme.mSurfaceVariant
        border.width: Theme.borderS
        border.color: Theme.mOutline
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.marginS
            spacing: Theme.marginS

            ContinueListening {
                Layout.fillWidth: true
                Layout.topMargin: Theme.marginS
                onEpisodeChosen: function (episodeId) { PodcastLibrary.playEpisode(episodeId) }
            }

            ListView {
                id: episodeList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cacheBuffer: 400
                boundsBehavior: Flickable.StopAtBounds
                model: episodeModel

                delegate: EpisodeRow {
                    id: episodeDelegate

                    required property var model

                    width: ListView.view.width
                    title: episodeDelegate.model.title
                    durationMs: episodeDelegate.model.durationMs
                    positionMs: episodeDelegate.model.positionMs
                    played: episodeDelegate.model.played
                    isCurrent: episodeDelegate.model.isCurrent
                    episodeId: episodeDelegate.model.episodeId
                    publishedAt: episodeDelegate.model.publishedAt

                    downloadable: episodeDelegate.model.path === ""
                    downloadProgress: root.progressOf(episodeDelegate.model.episodeId)
                    downloadSizeKnown: root.sizeKnownFor(episodeDelegate.model.episodeId)

                    onActivated: PodcastLibrary.playEpisode(episodeDelegate.model.episodeId)
                    onPlayedToggled: PodcastLibrary.markPlayed(episodeDelegate.model.episodeId,
                                                              !episodeDelegate.model.played)
                    onDownloadRequested: PodcastLibrary.downloadEpisode(
                                             episodeDelegate.model.episodeId)
                }

                Text {
                    anchors.centerIn: parent
                    visible: episodeModel.count === 0
                    text: qsTr("nenhum episódio neste programa")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeM
                    color: Theme.mOnSurfaceVariant
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.marginM
                Layout.rightMargin: Theme.marginM
                Layout.bottomMargin: Theme.marginXS
                visible: root.episodePlaying
                spacing: Theme.marginS

                Text {
                    text: qsTr("Velocidade")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeXS
                    color: Theme.mOnSurfaceVariant
                }
                SpeedControl {}
                Item { Layout.fillWidth: true }
            }

            Text {
                id: downloadError
                Layout.fillWidth: true
                Layout.leftMargin: Theme.marginM
                Layout.rightMargin: Theme.marginM
                Layout.bottomMargin: Theme.marginXS
                visible: downloadError.text !== ""
                wrapMode: Text.WordWrap
                text: ""
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXS
                color: Theme.mError
            }
        }
    }

    SubscribeDialog {
        id: subscribeDialog
    }

    FolderDialog {
        id: podcastFolderDialog
        title: qsTr("Pasta de podcast")
        onAccepted: {
            PodcastLibrary.podcastPath = selectedFolder.toString().replace("file://", "")
            PodcastLibrary.scanPodcastFolder()
        }
    }
}
