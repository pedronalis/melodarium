pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Melodarium.App

// O miolo do podcast do desenho aprovado (design/Podcast.dc.html): UMA coluna com todos os
// episódios, do mais novo para o mais velho, com o nome do programa em cada linha. A escolha
// de programa virou um menu de filtro em vez de uma segunda coluna — o desenho não tem essa
// coluna, e o transporte de fala mora no painel, não aqui.
Item {
    id: root

    property bool episodePlaying: false
    property string currentPath: ""

    property var shows: []
    property var episodes: []
    property string filter: "all"
    property int showFilter: 0
    // episodeId -> { received, total }. Vive no pane, não na linha: linhas são recicladas ao
    // rolar e perderiam o progresso do que ainda está baixando.
    property var downloads: ({})

    signal showRequested(int showId)

    readonly property var filtros: [
        { key: "all",      label: qsTr("Todos") },
        { key: "unplayed", label: qsTr("Não ouvidos") },
        { key: "local",    label: qsTr("Baixados") },
        { key: "started",  label: qsTr("Começados") }
    ]

    function refresh() {
        root.shows = PodcastLibrary.shows()
        root.episodes = PodcastLibrary.allEpisodes(root.showFilter)
    }

    function matches(ep) {
        if (root.filter === "unplayed")
            return !ep.played
        if (root.filter === "local")
            return ep.path !== ""
        if (root.filter === "started")
            return !ep.played && ep.positionMs > 0
        return true
    }

    readonly property var visiveis: root.episodes.filter(root.matches)

    readonly property int naoOuvidos: root.episodes.filter(function (e) {
        return !e.played
    }).length

    readonly property int baixados: root.episodes.filter(function (e) {
        return e.path !== ""
    }).length

    onShowFilterChanged: root.refresh()

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

    function nomeDoPrograma(id) {
        for (let i = 0; i < root.shows.length; ++i) {
            if (root.shows[i].id === id)
                return root.shows[i].title
        }
        return qsTr("Programas")
    }

    function showOpmlResult(action, result) {
        if (result.error !== "") {
            opmlStatus.text = ""
            erro.text = result.error
            return
        }
        erro.text = ""
        if (action === "import") {
            opmlStatus.text = qsTr("OPML: %1 importados · %2 duplicados · %3 inválidos")
                              .arg(result.imported).arg(result.duplicates).arg(result.failed)
        } else {
            opmlStatus.text = qsTr("OPML salvo com %1 assinaturas").arg(result.imported)
        }
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: PodcastLibrary
        function onShowsChanged() { root.refresh() }
        function onEpisodesChanged(showId) { root.refresh() }
        function onDownloadProgress(episodeId, received, total) {
            const next = root.downloads
            next[episodeId] = { received: received, total: total }
            root.downloads = next
        }
        function onDownloadFinished(episodeId) {
            const next = root.downloads
            delete next[episodeId]
            root.downloads = next
            root.refresh()
        }
        function onDownloadFailed(episodeId, reason) {
            const next = root.downloads
            delete next[episodeId]
            root.downloads = next
            erro.text = reason
        }
        function onSubscribeFailed(reason) { erro.text = reason }
        function onFeedCheckFailed(showId, reason) { erro.text = reason }
    }

    Connections {
        target: PortabilityService
        function onSubscriptionRequested(feedUrl) { PodcastLibrary.subscribe(feedUrl) }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginXL + Theme.marginS
        anchors.bottomMargin: Theme.marginXL
        spacing: Theme.marginL

        // --- Cabeçalho: o que há, e como trazer mais ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginL

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.marginXXS

                Text {
                    text: qsTr("Episódios")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXL
                    font.weight: Theme.fontWeightSemiBold
                    color: Theme.cTitle
                }
                Text {
                    text: [root.shows.length + qsTr(" feeds"),
                           root.naoOuvidos + qsTr(" não ouvidos"),
                           root.baixados + qsTr(" baixados")].join(" · ")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.cFaint
                }
            }

            Chip {
                label: PodcastLibrary.checkingFeeds ? qsTr("verificando…") : qsTr("Assinar feed")
                glyph: Icons.get("rss")
                onClicked: subscribeDialog.open()
            }

            Chip {
                id: opmlChip
                label: qsTr("OPML")
                glyph: Icons.get("playlist")
                onClicked: opmlMenu.popup(opmlChip, 0, opmlChip.height + Theme.marginXS)
            }

            MelodariumMenu {
                id: opmlMenu
                MelodariumMenuItem {
                    text: qsTr("Importar assinaturas…")
                    onTriggered: importOpmlDialog.open()
                }
                MelodariumMenuItem {
                    text: qsTr("Exportar assinaturas…")
                    onTriggered: exportOpmlDialog.open()
                }
            }

            IconButton {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                icon: "folder"
                size: Theme.fontSizeS
                opacity: 0.55
                tooltip: qsTr("pasta de podcast")
                onClicked: podcastFolderDialog.abrirEm(PodcastLibrary.podcastPath)
            }

            IconButton {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                icon: "history"
                size: Theme.fontSizeS
                opacity: 0.55
                tooltip: qsTr("procurar episódios novos")
                enabled: !PodcastLibrary.checkingFeeds && !PodcastLibrary.scanning
                onClicked: {
                    PodcastLibrary.checkAllFeeds()
                    if (PodcastLibrary.podcastPath !== "")
                        PodcastLibrary.scanPodcastFolder()
                }
            }
        }

        // --- Os filtros, na mesma gramática da biblioteca ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS

            Repeater {
                model: root.filtros

                Chip {
                    required property var modelData
                    label: modelData.label
                    selected: root.filter === modelData.key
                    onClicked: root.filter = modelData.key
                }
            }

            Item { Layout.fillWidth: true }

            // O desenho não tem a coluna de programas; escolher um vira um menu, para a lista
            // continuar sendo uma coluna só.
            Chip {
                id: showChip
                visible: root.shows.length > 1
                label: root.showFilter === 0 ? qsTr("Programas")
                                             : root.nomeDoPrograma(root.showFilter)
                glyph: Icons.get("chevron-right")
                glyphPointsDown: true
                selected: root.showFilter !== 0
                onClicked: showMenu.popup(showChip, 0, showChip.height + Theme.marginXS)
            }

            MelodariumMenu {
                id: showMenu

                MelodariumMenuItem {
                    text: qsTr("Todos os programas")
                    onTriggered: root.showRequested(0)
                }

                Repeater {
                    model: root.shows

                    MelodariumMenuItem {
                        required property var modelData
                        text: modelData.title
                        onTriggered: root.showRequested(modelData.id)
                    }
                }
            }
        }

        ListView {
            id: lista
            reuseItems: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            cacheBuffer: 400
            boundsBehavior: Flickable.StopAtBounds
            model: root.visiveis

            // As duas bordas dissolvem no fundo em vez de cortar a linha ao meio. Filhos diretos da
            // lista, não do conteúdo dela: o conteúdo rola, estes ficam.
            ListFade {
                parent: lista
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                paraCima: true
                corDeFundo: Theme.cBase
                opacity: lista.atYBeginning ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animationFast } }
            }
            ListFade {
                parent: lista
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                corDeFundo: Theme.cBase
                opacity: lista.atYEnd ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animationFast } }
            }

            delegate: EpisodeRow {
                id: linha

                required property var modelData

                width: ListView.view.width
                title: linha.modelData.title
                showTitle: linha.modelData.showTitle
                durationMs: linha.modelData.durationMs
                positionMs: linha.modelData.positionMs
                played: linha.modelData.played
                isCurrent: linha.modelData.path !== ""
                           && linha.modelData.path === root.currentPath
                episodeId: linha.modelData.id
                publishedAt: linha.modelData.publishedAt

                downloadable: linha.modelData.path === ""
                downloadProgress: root.progressOf(linha.modelData.id)
                downloadSizeKnown: root.sizeKnownFor(linha.modelData.id)

                onActivated: PodcastLibrary.playEpisode(linha.modelData.id)
                onPlayedToggled: PodcastLibrary.markPlayed(linha.modelData.id,
                                                          !linha.modelData.played)
                onDownloadRequested: PodcastLibrary.downloadEpisode(linha.modelData.id)
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - Theme.marginXL * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: lista.count === 0
                text: root.shows.length === 0
                      ? qsTr("Nenhum programa ainda. Assine um feed, ou escolha a pasta de podcast: uma subpasta por programa.")
                      : qsTr("nenhum episódio nesta lista")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.cMuted
            }
        }

        Text {
            id: opmlStatus
            Layout.fillWidth: true
            visible: opmlStatus.text !== ""
            wrapMode: Text.WordWrap
            text: ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            color: Theme.cMuted
        }

        Text {
            id: erro
            Layout.fillWidth: true
            visible: erro.text !== ""
            wrapMode: Text.WordWrap
            text: ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            color: Theme.mError
        }

        // --- O rodapé só existe enquanto há download em voo ---
        Repeater {
            model: Object.keys(root.downloads)

            Rectangle {
                id: baixando

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: Math.round(40 * Theme.uiScale)
                radius: Theme.iRadiusS
                color: Qt.rgba(Theme.cRaised.r, Theme.cRaised.g,
                               Theme.cRaised.b, 0.5)
                border.width: Theme.borderS
                border.color: Theme.cLine

                readonly property var entrada: root.downloads[baixando.modelData]
                readonly property real recebido: baixando.entrada !== undefined
                                                 ? baixando.entrada.received : 0
                readonly property real total: baixando.entrada !== undefined
                                              ? baixando.entrada.total : -1

                function tituloDe(id) {
                    for (let i = 0; i < root.episodes.length; ++i) {
                        if (String(root.episodes[i].id) === String(id))
                            return root.episodes[i].title
                    }
                    return qsTr("episódio")
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginL
                    anchors.rightMargin: Theme.marginL
                    spacing: Theme.marginM

                    Text {
                        text: Icons.get("download")
                        font.family: Icons.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.cMuted
                    }

                    Text {
                        Layout.maximumWidth: 220
                        text: qsTr("Baixando ") + baixando.tituloDe(baixando.modelData)
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.cMuted
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 3
                        radius: height / 2
                        color: Theme.cRaised

                        // O servidor nem sempre declara o tamanho: sem ele, a barra mostra um
                        // sinal de vida em vez de uma porcentagem inventada.
                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: baixando.total > 0
                                   ? parent.width * Math.min(1.0, baixando.recebido / baixando.total)
                                   : parent.width * 0.15
                            color: Theme.cMuted
                        }
                    }

                    Text {
                        text: baixando.total > 0
                              ? (Math.round(baixando.total / 104857.6) / 10) + " MB"
                              : qsTr("baixando…")
                        font.family: Theme.fontFamilyFixed
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.cFaint
                    }

                    IconButton {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        icon: "close"
                        size: Theme.fontSizeS
                        onClicked: PodcastLibrary.cancelDownload(parseInt(baixando.modelData))
                    }
                }
            }
        }
    }

    SubscribeDialog {
        id: subscribeDialog
    }

    FileDialog {
        id: importOpmlDialog
        title: qsTr("Importar assinaturas OPML")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Arquivos OPML (*.opml *.xml)")]
        onAccepted: root.showOpmlResult("import",
                                        PortabilityService.importOpml(selectedFile))
    }

    FileDialog {
        id: exportOpmlDialog
        title: qsTr("Exportar assinaturas OPML")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "opml"
        nameFilters: [qsTr("Arquivos OPML (*.opml)")]
        onAccepted: root.showOpmlResult("export",
                                        PortabilityService.exportOpml(selectedFile))
    }

    FolderPickerDialog {
        id: podcastFolderDialog
        title: qsTr("Pasta de podcast")
        confirmText: qsTr("Usar esta pasta")
        startPath: PodcastLibrary.podcastPath
        onFolderChosen: (path) => {
            PodcastLibrary.podcastPath = path
            PodcastLibrary.scanPodcastFolder()
        }
    }
}
