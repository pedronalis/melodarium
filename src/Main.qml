pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Melodia.App

Window {
    id: root
    // `--measure [largura]`: medir também na janela mínima é o único jeito de saber se a
    // linha de filtros aguenta a tela estreita.
    readonly property bool measuring: Qt.application.arguments.indexOf("--measure") >= 0

    readonly property int measureWidth: {
        const i = Qt.application.arguments.indexOf("--measure")
        if (i < 0 || Qt.application.arguments.length <= i + 1)
            return 0
        const w = parseInt(Qt.application.arguments[i + 1])
        return isNaN(w) ? 0 : w
    }

    width: root.measureWidth > 0 ? root.measureWidth : 1100
    height: 700
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: qsTr("melodia")
    color: Theme.mSurface

    // Which pane the icon rail is showing: "library", "albums", "tags", "podcast", "search".
    property string section: "library"

    // When a section is a group axis (artists/albums/genres) with no group picked yet, the
    // middle column lists the groups instead of the tracks.
    property bool showingGroups: false
    property var groups: []
    property string groupsTitle: ""
    // The track the tag editor is looking at: the last one the user activated.
    property int selectedTrackId: 0
    // What the middle pane is querying right now, so a rescan can ask for it again. The rail
    // picks the pane; these pick what the pane lists.
    property string currentSection: "all"
    property int currentId: 0
    // 0 when what is playing is not a podcast episode.
    property int currentEpisodeId: 0
    // Which chip of the filter row is lit. The rail picks the pane; this picks the list.
    property string libraryFilter: "all"
    // The order the engine is playing, kept here because the queue drawer left this design.
    property var queuePaths: []

    readonly property var filterTitles: ({
        "liked": qsTr("Curtidas"),
        "recent": qsTr("Recentes"),
        "mostPlayed": qsTr("Mais tocadas"),
        "forgotten": qsTr("Esquecidas"),
        "never": qsTr("Nunca ouvi")
    })

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
        case "liked":      return { clause: LibraryBrowser.clauseForLiked(), bindings: [] }
        default:           return { clause: LibraryBrowser.clauseForAll(), bindings: [] }
        }
    }

    function showSection(section, id) {
        root.currentSection = section
        root.currentId = id
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
        // O cabeçalho do miolo diz que lista é esta: "Biblioteca" só quando é a lista inteira.
        if (id === 0)
            root.groupsTitle = root.filterTitles[section] !== undefined
                               ? root.filterTitles[section] : ""
    }

    // The filter row speaks its own keys; the query layer speaks the section names.
    function chooseFilter(key) {
        root.libraryFilter = key
        root.showSection(key === "most" ? "mostPlayed" : key, 0)
    }

    // Opening a group keeps its name on screen: the list is no longer "Biblioteca".
    function openGroup(section, id) {
        for (let i = 0; i < root.groups.length; ++i) {
            if (root.groups[i].id === id) {
                root.groupsTitle = root.groups[i].name
                break
            }
        }
        const q = clauseFor(section, id)
        root.currentSection = section
        root.currentId = id
        trackModel.loadFromQuery(q.clause, q.bindings)
        root.showingGroups = false
    }

    function activateTrack(index) {
        root.queuePaths = trackModel.allPaths()
        AudioEngine.loadPlaylist(root.queuePaths, index)
        AudioEngine.play()
    }

    function collectTrack(trackId) {
        root.selectedTrackId = trackId
        collectMenu.trackId = trackId
        collectMenu.options = CollectionManager.collections()
        collectMenu.popup()
    }

    // The rail picks the pane. Search is not a pane: it is an overlay the busca-overlay slice
    // brings in, so until then the rail says so instead of pretending to switch.
    function showPane(name) {
        if (name === "search") {
            console.log("busca ainda não implementada")
            return
        }
        root.section = name
    }

    function reloadCurrent() {
        showSection(root.currentSection, root.currentId)
    }

    // Tags are picked by name, not by id, so they do not go through showSection().
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
            root.section = "podcast"
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

    Connections {
        target: YtDlpDownloader
        // The freshly downloaded track only shows up in the list if the list is asked again.
        function onFinished(url, trackId) { root.reloadCurrent() }
    }

    // `appmelodia --measure` imprime UMA linha com as medidas dos painéis e sai. É assim que a
    // fidelidade ao desenho aprovado vira verificação mecânica (tools/check-layout.sh) em vez
    // de opinião: uma mudança acidental de layout falha o gate em vez de virar tela torta.
    Loader {
        active: Qt.application.arguments.indexOf("--measure") >= 0
        sourceComponent: Timer {
            running: true
            interval: 1200
            onTriggered: {
                console.log("MEDIDA rail=" + Math.round(rail.width)
                            + " painel=" + Math.round(nowPlaying.width)
                            + " miolo=" + Math.round(pane.width)
                            + " capa=" + Math.round(nowPlaying.coverWidth)
                            + "x" + Math.round(nowPlaying.coverHeight)
                            + " janela=" + Math.round(root.width)
                            + "x" + Math.round(root.height)
                            + " chips=" + Math.round(libraryPane.chipsImplicitWidth)
                            + " chipsvao=" + Math.round(libraryPane.chipsWidth))
                Qt.quit()
            }
        }
    }

    Component.onCompleted: {
        if (Database.libraryPath !== "")
            trackModel.loadAllTracks()
        // Finding out whether yt-dlp exists costs one process start; finding out at the moment
        // the user clicks costs a dialog that fails in their face.
        YtDlpDownloader.probe()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        IconRail {
            id: rail
            Layout.fillHeight: true
            current: root.section
            onChosen: function (name) { root.showPane(name) }
        }

        NowPlayingPanel {
            id: nowPlaying
            Layout.fillHeight: true
            // Both follow the panel's own implicit width so compact mode actually narrows the
            // frame; fillWidth stays false so the panel can never eat the pane.
            Layout.preferredWidth: nowPlaying.implicitWidth
            Layout.maximumWidth: nowPlaying.implicitWidth
            Layout.fillWidth: false
            compact: root.width < 900
            onLikeRequested: function (id) { LibraryBrowser.toggleLike(id) }
        }

        StackLayout {
            id: pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            // A lista é o ponto da tela: nunca cede espaço ao painel.
            Layout.minimumWidth: 360
            // Medir mede a tela da biblioteca: qual banco a máquina tem não pode mudar o
            // resultado do gate de layout.
            currentIndex: root.measuring
                          ? 0
                          : (root.section === "podcast"
                             ? 1
                             : (Database.libraryPath === "" ? 2 : 0))

            LibraryPane {
                id: libraryPane
                model: trackModel
                filter: root.libraryFilter
                groups: root.groups
                showingGroups: root.showingGroups
                groupTitle: root.groupsTitle
                scanning: Database.scanning
                onGroupChosen: function (key) { root.chooseFilter(key) }
                onGroupOpened: function (section, id) { root.openGroup(section, id) }
                onTagOpened: function (name) { root.showTag(name) }
                onTrackActivated: function (index) { root.activateTrack(index) }
                onCollectRequested: function (trackId) { root.collectTrack(trackId) }
            }

            PodcastPane { }
            EmptyPane { }
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
