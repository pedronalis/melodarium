import QtQuick
import QtQuick.Layouts
import Melodarium.App

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
    // Guardar numa coleção existia só na linha da lista, e é tocando que a vontade aparece:
    // a essa altura a faixa muitas vezes nem está na tela — a lista rolou, ou o miolo está em
    // outra seção. O painel é o único lugar que fala da música que TOCA.
    signal collectRequested(int trackId)
    // O que vem a seguir é da fila, não do painel: ele só repassa o gesto para quem manda
    // nela, que é a janela.
    signal queueJumpRequested(int queueIndex)
    signal queueOpenRequested()

    // O TagEditor emite tagChosen desde sempre; o painel nunca repassou, e o clique na
    // etiqueta morria aqui dentro (regressão do commit 202b7bb).
    signal tagChosen(string name)

    // Compact does not just shrink the cover: the whole panel narrows with it. Leaving the
    // panel at 392 while the cover drops to 200 would push the frame past a 720 px window and
    // send the right edge of the pane off screen.
    implicitWidth: root.coverSide + (Theme.marginXL + Theme.marginS) * 2 + 4
    color: Theme.cBase

    // O degradê do desenho (design/Main.dc.html): claro no topo, fundo da janela no pé. Duas
    // paradas achatavam a queda no meio da coluna e o painel lia como um retângulo chapado;
    // são as TRÊS do desenho que fazem a luz cair atrás da capa.
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.cPanelTop }
        GradientStop { position: 0.55; color: Theme.cPanelMid }
        GradientStop { position: 1.0; color: Theme.cBase }
    }

    readonly property int coverSide: root.compact ? Math.round(200 * Theme.uiScale) : Theme.panelCover

    // Lidos por `melodarium --measure`: a capa quadrada é uma das linhas do gate de layout.
    readonly property alias coverWidth: capaRect.width
    readonly property alias coverHeight: capaRect.height

    // mpv reports pause=false while it is idle, so AudioEngine.playing is true before any file
    // is loaded. Without this guard the transport shows a pause button with nothing playing.
    readonly property bool hasTrack: AudioEngine.currentFile !== ""

    // O que está tocando pode ser um episódio, e aí os metadados vêm do podcast, não da
    // biblioteca: um episódio não tem artista nem álbum, tem programa e data.
    property var episodeInfo: ({})

    // O motor não tem mudo: o botão antigo alternava entre 0 e 100 e perdia o valor que o
    // usuário tinha escolhido. Guardar o volume anterior é o que faz o mudo ser reversível.
    property real volumeAntesDoMudo: 100
    readonly property bool mudo: AudioEngine.volume <= 0

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

        Item {
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
            // Sem faixa, a capa não é um retângulo cinza: é uma moldura tracejada que diz o
            // que está acontecendo (design/SemMusica.dc.html).

            Canvas {
                anchors.fill: parent
                visible: !root.hasTrack
                // Acima do bloco de capa, que é declarado depois e sem isto o cobriria.
                z: 1
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    // cLine, e não a cor do painel: no topo do degradê o painel tem quase
                    // esse mesmo tom, e uma moldura mais escura sumiria ali.
                    ctx.strokeStyle = Theme.cLine
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
                z: 1
                spacing: Theme.marginL

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Icons.get("music")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeXXXL
                    color: Theme.cEmptyIcon
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("nada tocando")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
                    color: Theme.cDim
                }
            }

            RoundedCover {
                id: capaVazia
                anchors.fill: parent
                // O bloco existe mesmo sem nada tocando: o desenho põe degradê e sombra no
                // quadrado da capa em todas as telas, e era a ausência dele que fazia o painel
                // vazio parecer um buraco recortado no fundo. A moldura tracejada e o "nada
                // tocando" continuam por cima — é o que distingue vazio de capa que falta.
                radius: Theme.radiusM
                // A única capa do app que projeta sombra: é ela que descola a arte do painel.
                shadow: true
                placeholderColor: Theme.cRaised
                placeholderTop: root.episodeMode ? Theme.cCoverTopPod : Theme.cCoverTop
                placeholderMid: root.episodeMode ? Theme.cCoverMidPod : Theme.cCoverMid
                // Sem faixa quem desenha o ícone é a coluna de baixo, no tamanho pequeno do
                // desenho; aqui ele sairia grande e duplicado.
                fallbackIcon: !root.hasTrack ? ""
                                             : (root.episodeMode ? "microphone" : "music")
                // 64 px num bloco de 340 no desenho — proporção, não medida fixa, porque a capa
                // encolhe junto com a janela.
                fallbackIconSize: Math.round(capaRect.lado * 64 / 340)
                fallbackIconColor: root.episodeMode ? Theme.cCoverIconPod : Theme.cCoverIcon
                source: root.episodeMode
                        ? (root.episodeInfo.coverPath !== undefined
                           && root.episodeInfo.coverPath !== ""
                           ? "file://" + root.episodeInfo.coverPath : "")
                        : (root.info.albumId !== undefined
                           ? CoverCache.coverUrlForTrack(AudioEngine.currentFile,
                                                         root.info.albumId)
                           : "")
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
                    font.pixelSize: Theme.fontSizeXXL
                    font.weight: Theme.fontWeightBold
                    font.letterSpacing: Theme.letterSpacingTitle * Theme.fontSizeXXL
                    color: Theme.cTitle
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.subtituloAtual !== ""
                    text: root.subtituloAtual
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeL
                    color: Theme.cSecondary
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
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.cDim
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

            // O mesmo "+" da linha da lista, e de propósito: é o glifo que já quer dizer
            // "guardar numa coleção" neste app. Um ícone novo aqui ensinaria um segundo
            // vocabulário para o mesmo gesto.
            IconButton {
                visible: root.trackId > 0 && !root.episodeMode
                icon: "plus"
                size: Theme.fontSizeXL
                tooltip: qsTr("Guardar numa coleção")
                onClicked: root.collectRequested(root.trackId)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.hasTrack
            spacing: Theme.marginXS

            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: Math.round(3 * Theme.uiScale)
                radius: Theme.radiusTrack
                color: Theme.cLine

                Rectangle {
                    id: percorrido
                    width: AudioEngine.duration > 0
                           ? parent.width * (AudioEngine.position / AudioEngine.duration) : 0
                    height: parent.height
                    radius: parent.radius
                    color: Theme.cStrong
                }

                // O botão na posição atual. Sem ele a barra é uma faixa que muda de tamanho;
                // com ele a barra tem um lugar onde se pega (design/Main.dc.html).
                Rectangle {
                    width: Math.round(9 * Theme.uiScale)
                    height: width
                    radius: width / 2
                    x: percorrido.width - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: AudioEngine.duration > 0
                    color: Theme.cTitle
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
                    font.pixelSize: Theme.fontSizeXS
                    color: Theme.cMuted
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.formatTime(AudioEngine.duration)
                    font.family: Theme.fontFamilyFixed
                    font.pixelSize: Theme.fontSizeXS
                    color: Theme.cMuted
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.hasTrack
            spacing: Theme.marginL

            SpeedControl {
                visible: root.episodeMode
                speed: AudioEngine.speed
                onSpeedPicked: function (v) { AudioEngine.setSpeed(v) }
            }

            IconButton {
                visible: !root.episodeMode
                icon: "shuffle"
                size: Theme.fontSizeL
                baseColor: Theme.cMuted
                // Sem estado visível, um botão ligado é indistinguível de um desligado.
                accent: AudioEngine.shuffle
                tooltip: AudioEngine.shuffle ? qsTr("aleatório ligado") : qsTr("aleatório")
                onClicked: AudioEngine.setShuffle(!AudioEngine.shuffle)
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
                color: Theme.cTitle

                Text {
                    anchors.centerIn: parent
                    text: AudioEngine.playing && root.hasTrack ? Icons.get("pause") : Icons.get("play")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeXL
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
                baseColor: Theme.cMuted
                accent: AudioEngine.repeatMode !== AudioEngine.RepeatOff
                // O terceiro estado precisa se distinguir do segundo por mais do que a cor:
                // um "1" sobreposto é o que diz "esta faixa" em vez de "a fila".
                tooltip: AudioEngine.repeatMode === AudioEngine.RepeatOne
                         ? qsTr("repetir esta faixa")
                         : (AudioEngine.repeatMode === AudioEngine.RepeatAll
                            ? qsTr("repetir a fila") : qsTr("repetir"))
                onClicked: AudioEngine.cycleRepeat()

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: Math.round(2 * Theme.uiScale)
                    visible: AudioEngine.repeatMode === AudioEngine.RepeatOne
                    text: "1"
                    font.family: Theme.fontFamilyFixed
                    font.pixelSize: Theme.fontSizeXXS
                    font.weight: Theme.fontWeightBold
                    color: Theme.cAccent
                }
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
                border.color: Theme.cLine

                Text {
                    id: pulo
                    anchors.centerIn: parent
                    text: qsTr("30s")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.cMuted
                }
            }

        }

        // O volume tem linha própria, encostado à direita. Dentro da fileira do transporte ele
        // desequilibrava a única peça centrada da tela — e o desenho não o prevê ali.
        RowLayout {
            Layout.fillWidth: true
            visible: root.hasTrack
            spacing: Theme.marginS

            Item { Layout.fillWidth: true }

            IconButton {
                icon: root.mudo ? "volume-off"
                                : (AudioEngine.volume < 50 ? "volume-low" : "volume")
                size: Theme.fontSizeS
                baseColor: Theme.cMuted
                tooltip: root.mudo ? qsTr("com som") : qsTr("mudo")
                onClicked: {
                    if (root.mudo) {
                        AudioEngine.setVolume(root.volumeAntesDoMudo)
                    } else {
                        root.volumeAntesDoMudo = AudioEngine.volume
                        AudioEngine.setVolume(0)
                    }
                }
            }

            Rectangle {
                id: trilhoVolume
                Layout.preferredWidth: Math.round(72 * Theme.uiScale)
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Math.round(3 * Theme.uiScale)
                radius: Theme.radiusTrack
                color: Theme.cLine

                Rectangle {
                    width: parent.width * (AudioEngine.volume / 100)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.cMuted
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.marginS
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function (mouse) {
                        AudioEngine.setVolume(
                            Math.max(0, Math.min(100, 100 * mouse.x / trilhoVolume.width)))
                    }
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

        // O que ocupa a coluna enquanto toca. Sem isto o painel entrega capa, transporte e
        // etiquetas e devolve o resto da altura ao vazio — numa janela alta, mais da metade.
        UpNextList {
            id: proximas

            Layout.fillWidth: true
            Layout.topMargin: Theme.marginM
            // Ela vive do que SOBRA, e só disso: a conta desconta a capa inteira e o resto da
            // coluna antes de perguntar se ela cabe. Na janela do desenho (700) não sobra nada
            // e ela não aparece — encolher a capa para caber uma lista seria trocar o assunto
            // do painel, que é a arte do que está tocando.
            visible: root.hasTrack && proximas.temProximos
                     && root.height - Math.round(330 * Theme.uiScale) - root.coverSide
                        >= proximas.alturaCheia + Theme.marginM
            onEntryActivated: function (queueIndex) { root.queueJumpRequested(queueIndex) }
            onExpandRequested: root.queueOpenRequested()
        }

        // Sempre presente: é ele que mantém a capa no topo quando o resto da coluna encolhe.
        Item { Layout.fillHeight: true }
    }
}
