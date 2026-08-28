import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property int trackId: 0
    property bool compact: false
    property var info: ({})
    // Um episódio de podcast pede outro transporte: velocidade e pulos de 30 s no lugar do
    // aleatório e do repetir, que não querem dizer nada numa conversa.
    property bool episodeMode: false

    signal likeRequested(int trackId)
    signal playRequested(string mode)

    // O TagEditor emite tagChosen desde sempre; o painel nunca repassou, e o clique na
    // etiqueta morria aqui dentro (regressão do commit 202b7bb).
    signal tagChosen(string name)

    // Compact does not just shrink the cover: the whole panel narrows with it. Leaving the
    // panel at 392 while the cover drops to 200 would push the frame past a 720 px window and
    // send the right edge of the pane off screen.
    implicitWidth: root.coverSide + (Theme.marginXL + Theme.marginS) * 2 + 4
    color: Theme.mSurface

    // Um degradê muito sutil separa o painel do miolo sem precisar de borda.
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.mSurfaceVariant }
        GradientStop { position: 0.6; color: Theme.mSurface }
    }

    readonly property int coverSide: root.compact ? Math.round(200 * Theme.uiScale) : Theme.panelCover

    // Lidos por `appmelodia --measure`: a capa quadrada é uma das linhas do gate de layout.
    readonly property alias coverWidth: capaRect.width
    readonly property alias coverHeight: capaRect.height

    // mpv reports pause=false while it is idle, so AudioEngine.playing is true before any file
    // is loaded. Without this guard the transport shows a pause button with nothing playing.
    readonly property bool hasTrack: AudioEngine.currentFile !== ""

    // O que está tocando pode ser um episódio, e aí os metadados vêm do podcast, não da
    // biblioteca: um episódio não tem artista nem álbum, tem programa e data.
    property var episodeInfo: ({})

    readonly property string tituloAtual: root.episodeMode
                                          ? (root.episodeInfo.title !== undefined
                                             ? root.episodeInfo.title : "")
                                          : (root.info.title !== undefined
                                             && root.info.title !== ""
                                             ? root.info.title : qsTr("nada tocando"))

    readonly property string subtituloAtual: root.episodeMode
                                             ? (root.episodeInfo.showTitle !== undefined
                                                ? root.episodeInfo.showTitle : "")
                                             : (root.info.artist !== undefined
                                                ? root.info.artist : "")

    function formatDate(secs) {
        if (!(secs > 0))
            return ""
        return new Date(secs * 1000).toLocaleDateString(Qt.locale(), "dd MMM")
    }

    function refresh() {
        const path = AudioEngine.currentFile
        root.info = path === "" ? ({}) : LibraryBrowser.trackForPath(path)
        root.trackId = root.info.id !== undefined ? root.info.id : 0
        root.episodeInfo = path === "" ? ({}) : PodcastLibrary.episodeForPath(path)
    }

    Component.onCompleted: root.refresh()



    Connections {
        target: AudioEngine
        function onCurrentFileChanged() { root.refresh() }
    }

    Connections {
        target: LibraryBrowser
        function onLikedChanged(id, liked) {
            if (id === root.trackId)
                root.refresh()
        }
    }

    function formatTime(seconds) {
        if (!(seconds > 0))
            return "0:00"
        const total = Math.floor(seconds)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.marginXL + Theme.marginS
        spacing: Theme.marginXL

        Rectangle {
            id: capaRect

            // O resto da coluna (título, progresso, controles, tags) ocupa ~330px. Quando a
            // janela é mais baixa que isso + 340, a capa cede espaço — mas cede QUADRADA:
            // sem amarrar largura à altura, o Layout encolheria só a altura e a arte sairia
            // deformada. Salvaguarda: numa janela de 1384 a medida confirma 340x340.
            readonly property int lado: Math.max(Math.round(120 * Theme.uiScale),
                                                Math.min(root.coverSide, root.height - Math.round(330 * Theme.uiScale)))

            Layout.preferredWidth: capaRect.lado
            Layout.preferredHeight: capaRect.lado
            Layout.maximumHeight: capaRect.lado
            Layout.alignment: Qt.AlignHCenter
            radius: Theme.radiusM
            // Sem faixa, a capa não é um retângulo cinza: é uma moldura tracejada que diz o
            // que está acontecendo (design/SemMusica.dc.html).
            color: root.hasTrack ? Theme.mSurfaceVariant : "transparent"
            clip: true

            Canvas {
                anchors.fill: parent
                visible: !root.hasTrack
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    // mOutline, não mSurfaceVariant: no topo do painel o degradê tem
                    // exatamente a cor de mSurfaceVariant, e a moldura sumiria ali.
                    ctx.strokeStyle = Theme.mOutline
                    ctx.lineWidth = Theme.borderS
                    ctx.setLineDash([6, 5])
                    const r = Theme.radiusM
                    const w = width - 1
                    const h = height - 1
                    ctx.beginPath()
                    ctx.moveTo(r, 0.5)
                    ctx.lineTo(w - r, 0.5)
                    ctx.arcTo(w, 0.5, w, r, r)
                    ctx.lineTo(w, h - r)
                    ctx.arcTo(w, h, w - r, h, r)
                    ctx.lineTo(r, h)
                    ctx.arcTo(0.5, h, 0.5, h - r, r)
                    ctx.lineTo(0.5, r)
                    ctx.arcTo(0.5, 0.5, r, 0.5, r)
                    ctx.stroke()
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: !root.hasTrack
                spacing: Theme.marginL

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Icons.get("music")
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeXXXL
                    color: Theme.mSurfaceVariant
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("nada tocando")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeM
                    color: Theme.mOutline
                }
            }

            Image {
                id: capaVazia
                anchors.fill: parent
                source: root.episodeMode
                        ? (root.episodeInfo.coverPath !== undefined
                           && root.episodeInfo.coverPath !== ""
                           ? "file://" + root.episodeInfo.coverPath : "")
                        : (root.info.albumId !== undefined
                           ? CoverCache.coverUrlForTrack(AudioEngine.currentFile,
                                                         root.info.albumId)
                           : "")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                sourceSize.width: capaRect.lado
            }

            Text {
                anchors.centerIn: parent
                visible: root.hasTrack && capaVazia.status !== Image.Ready
                text: Icons.get(root.episodeMode ? "microphone" : "music")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeXXXL
                color: Theme.mOutline
            }
        }

        // Sem nada tocando, o painel não mostra um transporte que não controla nada: mostra o
        // convite da tela "nada tocando".
        EmptyPane {
            id: convite
            Layout.fillWidth: true
            Layout.preferredHeight: convite.implicitHeight
            // Sem pasta escolhida o convite não teria o que oferecer, e o miolo já está
            // pedindo a pasta: aqui fica só a moldura vazia.
            visible: !root.hasTrack && Database.libraryPath !== ""
            onPlayRequested: function (mode) { root.playRequested(mode) }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.hasTrack
            spacing: Theme.marginL

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.marginXXS

                Text {
                    Layout.fillWidth: true
                    text: root.tituloAtual
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeXXL
                    font.weight: Theme.fontWeightBold
                    color: Theme.mOnSurface
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.subtituloAtual !== ""
                    text: root.subtituloAtual
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeL
                    color: Theme.mOnSurfaceVariant
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.episodeMode
                          ? [root.formatDate(root.episodeInfo.publishedAt),
                             AudioEngine.duration > 0
                             ? Math.round(AudioEngine.duration / 60) + qsTr(" min") : ""]
                            .filter(function (p) { return p !== "" }).join(" · ")
                          : (root.trackId > 0
                             ? [root.info.album, root.info.year > 0 ? root.info.year : "",
                                root.info.codec]
                               .filter(function (p) { return p !== "" && p !== undefined })
                               .join(" · ")
                             : "")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: Theme.mOutline
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: root.trackId > 0 && !root.episodeMode
                icon: root.info.liked === true ? "heart-filled" : "heart"
                size: Theme.fontSizeXL
                accent: root.info.liked === true
                onClicked: root.likeRequested(root.trackId)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.hasTrack
            spacing: Theme.marginXS

            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 3
                radius: Theme.radiusXXS
                color: Theme.mSurfaceVariant

                Rectangle {
                    width: AudioEngine.duration > 0
                           ? parent.width * (AudioEngine.position / AudioEngine.duration) : 0
                    height: parent.height
                    radius: parent.radius
                    color: Theme.mTertiary
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.marginS
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function (mouse) {
                        if (AudioEngine.duration > 0)
                            AudioEngine.seek(AudioEngine.duration * (mouse.x / track.width))
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.formatTime(AudioEngine.position)
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeXS
                    color: Theme.mOnSurfaceVariant
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.formatTime(AudioEngine.duration)
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeXS
                    color: Theme.mOnSurfaceVariant
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.hasTrack
            spacing: Theme.marginXL

            SpeedControl {
                visible: root.episodeMode
                speed: AudioEngine.speed
                onSpeedPicked: function (v) { AudioEngine.setSpeed(v) }
            }

            IconButton {
                visible: !root.episodeMode
                icon: "shuffle"
                size: Theme.fontSizeL
                onClicked: {}
            }

            IconButton {
                icon: root.episodeMode ? "skip-back" : "track-prev"
                size: Theme.fontSizeXL
                tooltip: root.episodeMode ? qsTr("voltar 30 s") : ""
                onClicked: {
                    if (root.episodeMode)
                        AudioEngine.seek(Math.max(0, AudioEngine.position - 30))
                    else
                        AudioEngine.previous()
                }
            }

            Rectangle {
                Layout.preferredWidth: Math.round(52 * Theme.uiScale)
                Layout.preferredHeight: Math.round(52 * Theme.uiScale)
                radius: Math.round(26 * Theme.uiScale)
                color: Theme.mTertiary

                Text {
                    anchors.centerIn: parent
                    text: AudioEngine.playing && root.hasTrack ? Icons.get("pause") : Icons.get("play")
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeXL
                    color: Theme.mOnTertiary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioEngine.togglePause()
                }
            }

            IconButton {
                icon: root.episodeMode ? "skip-forward" : "track-next"
                size: Theme.fontSizeXL
                tooltip: root.episodeMode ? qsTr("avançar 30 s") : ""
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
                onClicked: {}
            }

            // O rótulo do pulo: sem ele, as duas setas viriam a ser "faixa anterior" aos olhos
            // de quem já usou o painel com música.
            Rectangle {
                visible: root.episodeMode
                implicitWidth: pulo.implicitWidth + Theme.marginL * 2
                implicitHeight: Math.round(26 * Theme.uiScale)
                radius: Theme.iRadiusS
                color: "transparent"
                border.width: Theme.borderS
                border.color: Theme.mSurfaceVariant

                Text {
                    id: pulo
                    anchors.centerIn: parent
                    text: qsTr("30s")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: Theme.mOutline
                }
            }
        }

        TagEditor {
            id: tagEd
            Layout.fillWidth: true
            visible: root.hasTrack && root.trackId > 0 && !root.episodeMode
            trackId: root.trackId
            onTagChosen: function (name) { root.tagChosen(name) }
        }

        // Sempre presente: é ele que mantém a capa no topo quando o resto da coluna encolhe.
        Item { Layout.fillHeight: true }
    }
}
