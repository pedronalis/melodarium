pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Melodia.App

Window {
    id: root
    width: 1100
    height: 700
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: qsTr("melodia")
    color: Theme.mSurface

    // When a section is a group axis (artists/albums/genres) with no group picked yet, the
    // middle column lists the groups instead of the tracks.
    property bool showingGroups: false
    property var groups: []
    property string groupsTitle: ""
    // The track the tag editor is looking at: the last one the user activated.
    property int selectedTrackId: 0
    // The two tabs the spec draws at the top: Música | Podcast.
    property string tab: "music"
    // 0 when what is playing is not a podcast episode.
    property int currentEpisodeId: 0

    TrackListModel {
        id: trackModel
        currentPath: AudioEngine.currentFile
    }

    function clauseFor(section, id) {
        switch (section) {
        case "artists": return { clause: LibraryBrowser.clauseForArtist(id),
                                 bindings: LibraryBrowser.bindingsFor(id) }
        case "albums":  return { clause: LibraryBrowser.clauseForAlbum(id),
                                 bindings: LibraryBrowser.bindingsFor(id) }
        case "genres":  return { clause: LibraryBrowser.clauseForGenre(id),
                                 bindings: LibraryBrowser.bindingsFor(id) }
        case "collection": return { clause: CollectionManager.clauseForCollection(id),
                                   bindings: CollectionManager.bindingsForCollection(id) }
        case "recent":     return { clause: LibraryBrowser.clauseRecent(), bindings: [] }
        case "mostPlayed": return { clause: LibraryBrowser.clauseMostPlayed(), bindings: [] }
        case "forgotten":  return { clause: LibraryBrowser.clauseForgotten(), bindings: [] }
        case "never":      return { clause: LibraryBrowser.clauseNeverPlayed(), bindings: [] }
        default:           return { clause: LibraryBrowser.clauseForAll(), bindings: [] }
        }
    }

    function showSection(section, id) {
        search.text = ""
        const isGroupAxis = section === "artists" || section === "albums"
                            || section === "genres" || section === "tags"
        if (isGroupAxis && id === 0) {
            root.groups = section === "artists" ? LibraryBrowser.artists()
                        : (section === "albums" ? LibraryBrowser.albums()
                        : (section === "genres" ? LibraryBrowser.genres()
                                                : CollectionManager.allTags()))
            root.groupsTitle = section === "artists" ? qsTr("Artistas")
                             : (section === "albums" ? qsTr("Álbuns")
                             : (section === "genres" ? qsTr("Gêneros") : qsTr("Tags")))
            root.showingGroups = true
            return
        }
        const q = clauseFor(section, id)
        trackModel.loadFromQuery(q.clause, q.bindings)
        root.showingGroups = false
    }

    function reloadCurrent() {
        showSection(sidebar.currentSection, sidebar.currentId)
    }

    // Tags are picked by name, not by id, so they do not go through Sidebar.choose().
    function showTag(name) {
        trackModel.loadFromQuery(CollectionManager.clauseForTag(name),
                                 CollectionManager.bindingsForTag(name))
        root.groupsTitle = name
        root.showingGroups = false
    }

    Connections {
        target: Database
        function onScanFinished(added, updated, removed) {
            root.reloadCurrent()
        }
    }

    Connections {
        target: AudioEngine
        function onTrackFinished(path) {
            PlayStatsRecorder.recordPlay(path)
        }
        // Whatever starts playing decides whether the podcast machinery is armed at all.
        function onCurrentFileChanged() {
            const episode = PodcastLibrary.episodeForPath(AudioEngine.currentFile)
            root.currentEpisodeId = episode.id !== undefined ? episode.id : 0
        }
        // Pausing is the moment the user is most likely to walk away: save once more, so the
        // position survives even if the app is killed before the next 5 s tick.
        function onPlayingChanged() {
            if (!AudioEngine.playing && root.currentEpisodeId > 0)
                PodcastLibrary.savePosition(root.currentEpisodeId,
                                            Math.round(AudioEngine.position * 1000))
        }
    }

    Connections {
        target: PodcastLibrary
        function onEpisodePlayRequested(path, seekToSeconds) {
            root.tab = "podcast"
            AudioEngine.loadPlaylist([path], 0)
            AudioEngine.play()
            // The seek has to wait for the file to actually be loaded: duration only becomes
            // known after mpv opens it.
            resumeSeek.targetSeconds = seekToSeconds
            resumeSeek.restart()
        }
    }

    Timer {
        id: resumeSeek
        property int targetSeconds: 0
        interval: 120
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (AudioEngine.duration > 0) {
                AudioEngine.seek(targetSeconds)
                stop()
            }
        }
    }

    // Saving on every positionChanged would write to SQLite on every UI frame.
    Timer {
        id: positionSaver
        // Mirrors PodcastLibrary::kSaveIntervalMs. A C++ `static constexpr` is NOT visible
        // from QML, so this number is duplicated on purpose — keep the two in sync.
        interval: 5000
        repeat: true
        running: AudioEngine.playing && root.currentEpisodeId > 0
        onTriggered: PodcastLibrary.savePosition(root.currentEpisodeId,
                                                 Math.round(AudioEngine.position * 1000))
    }

    Component.onCompleted: {
        if (Database.libraryPath !== "")
            trackModel.loadAllTracks()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginL
        spacing: Theme.marginM

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Text {
                text: Icons.get("music")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeXL
                color: Theme.mPrimary
            }
            Text {
                text: qsTr("melodia")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }

            // Música | Podcast, exactly as the spec draws it.
            Row {
                spacing: Theme.marginXXS

                Repeater {
                    model: [{ key: "music", label: qsTr("Música") },
                            { key: "podcast", label: qsTr("Podcast") }]

                    Rectangle {
                        id: tabChip

                        required property var modelData

                        width: tabLabel.implicitWidth + Theme.marginL * 2
                        height: Theme.marginXL * 1.7
                        radius: Theme.iRadiusS
                        color: root.tab === tabChip.modelData.key
                               ? Theme.mPrimary
                               : (tabArea.containsMouse ? Theme.mHover : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.animationFast
                                easing.type: Theme.easingType
                            }
                        }

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: tabChip.modelData.label
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeM
                            font.weight: root.tab === tabChip.modelData.key
                                         ? Theme.fontWeightSemiBold
                                         : Theme.fontWeightMedium
                            color: root.tab === tabChip.modelData.key
                                   ? Theme.mOnPrimary
                                   : (tabArea.containsMouse ? Theme.mOnHover
                                                            : Theme.mOnSurfaceVariant)
                        }

                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tab = tabChip.modelData.key
                        }
                    }
                }
            }

            SearchField {
                id: search
                Layout.fillWidth: true
                Layout.maximumWidth: 420
                visible: root.tab === "music"
                onSearchChanged: function (text) {
                    if (text === "") {
                        root.reloadCurrent()
                        return
                    }
                    trackModel.loadFromQuery(LibraryBrowser.clauseForSearch(text),
                                             LibraryBrowser.bindingsForSearch(text))
                    root.showingGroups = false
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: Database.scanning || PodcastLibrary.scanning
                text: qsTr("varrendo…")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }
            IconButton {
                icon: "history"
                size: Theme.fontSizeL
                visible: root.tab === "music"
                enabled: Database.libraryPath !== "" && !Database.scanning
                onClicked: Database.startScan()
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tab === "music" ? 0 : 1

            RowLayout {
                spacing: Theme.marginM

                Sidebar {
                    id: sidebar
                    Layout.fillHeight: true
                    Layout.preferredWidth: 220
                    onSectionChosen: function (section, id) { root.showSection(section, id) }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusM
                    color: Theme.mSurfaceVariant
                    border.width: Theme.borderS
                    border.color: Theme.mOutline
                    clip: true

                    LibraryEmptyState {
                        anchors.fill: parent
                        visible: Database.libraryPath === "" && !Database.scanning
                    }

                    ListView {
                        id: groupList
                        anchors.fill: parent
                        anchors.margins: Theme.marginS
                        visible: Database.libraryPath !== "" && root.showingGroups
                        model: root.groups
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        header: Text {
                            width: groupList.width
                            leftPadding: Theme.marginM
                            bottomPadding: Theme.marginS
                            text: root.groupsTitle
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeS
                            font.weight: Theme.fontWeightSemiBold
                            color: Theme.mOnSurfaceVariant
                        }

                        delegate: SidebarItem {
                            id: groupEntry

                            required property var modelData

                            width: ListView.view.width
                            icon: sidebar.currentSection === "artists" ? "microphone"
                                : (sidebar.currentSection === "albums" ? "disc"
                                : (sidebar.currentSection === "genres" ? "music" : "tags"))
                            label: groupEntry.modelData.subtitle !== ""
                                   ? groupEntry.modelData.name + " — " + groupEntry.modelData.subtitle
                                   : groupEntry.modelData.name
                            badge: groupEntry.modelData.count
                            onClicked: {
                                if (sidebar.currentSection === "tags")
                                    root.showTag(groupEntry.modelData.name)
                                else
                                    sidebar.choose(sidebar.currentSection, groupEntry.modelData.id)
                            }
                        }
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        anchors.topMargin: Theme.marginS
                        anchors.bottomMargin: Theme.marginS
                        visible: Database.libraryPath !== "" && !root.showingGroups
                        model: trackModel
                        clip: true
                        cacheBuffer: 400
                        boundsBehavior: Flickable.StopAtBounds

                        // Roles are read through the `model` object, never redeclared as required
                        // properties with the same names: redeclaring shadows TrackRow's own
                        // properties and the row renders blank, with no error anywhere.
                        delegate: TrackRow {
                            required property var model
                            required property int index

                            width: ListView.view.width
                            title: model.title
                            artist: model.artist
                            album: model.album
                            durationMs: model.durationMs
                            coverUrl: model.coverUrl
                            isCurrent: model.isCurrent
                            trackId: model.trackId
                            showCollectButton: true

                            onActivated: {
                                // The queue is what was loaded, not the list showing right now.
                                queue.paths = trackModel.allPaths()
                                root.selectedTrackId = model.trackId
                                AudioEngine.loadPlaylist(queue.paths, index)
                                AudioEngine.play()
                            }
                            onCollectRequested: {
                                root.selectedTrackId = model.trackId
                                collectMenu.trackId = model.trackId
                                collectMenu.options = CollectionManager.collections()
                                collectMenu.popup()
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: trackModel.count === 0 && !Database.scanning
                            text: qsTr("nada nesta lista")
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeM
                            color: Theme.mOnSurfaceVariant
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 300
                    spacing: Theme.marginM

                    QueuePanel {
                        id: queue
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: tagColumn.implicitHeight + Theme.marginM * 2
                        radius: Theme.radiusM
                        color: Theme.mSurfaceVariant
                        border.width: Theme.borderS
                        border.color: Theme.mOutline

                        ColumnLayout {
                            id: tagColumn
                            anchors.fill: parent
                            anchors.margins: Theme.marginM
                            spacing: Theme.marginS

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Tags da faixa")
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSizeS
                                font.weight: Theme.fontWeightSemiBold
                                color: Theme.mOnSurfaceVariant
                            }

                            TagEditor {
                                Layout.fillWidth: true
                                trackId: root.selectedTrackId
                                onTagChosen: function (name) { root.showTag(name) }
                            }
                        }
                    }
                }
            }

            PodcastSection {
                episodePlaying: root.currentEpisodeId > 0
                currentPath: AudioEngine.currentFile
            }
        }

        PlayerBar {
            Layout.fillWidth: true
        }
    }

    // The single manual gesture: one click on the row's plus, one click on a collection.
    Menu {
        id: collectMenu

        property int trackId: 0
        property var options: []

        Instantiator {
            model: collectMenu.options
            delegate: MenuItem {
                required property var modelData
                text: modelData.name
                onTriggered: CollectionManager.addTrackToCollection(modelData.id,
                                                                    collectMenu.trackId)
            }
            onObjectAdded: function (index, object) { collectMenu.insertItem(index, object) }
            onObjectRemoved: function (index, object) { collectMenu.removeItem(object) }
        }

        MenuItem {
            text: qsTr("Nova coleção…")
            onTriggered: {
                newCollectionForTrack.pendingTrackId = collectMenu.trackId
                newCollectionForTrack.open()
            }
        }
    }

    NewCollectionDialog {
        id: newCollectionForTrack

        property int pendingTrackId: 0

        onCreated: function (id, name) {
            if (newCollectionForTrack.pendingTrackId > 0)
                CollectionManager.addTrackToCollection(id, newCollectionForTrack.pendingTrackId)
            newCollectionForTrack.pendingTrackId = 0
        }
    }
}
