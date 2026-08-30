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
    //
    // E não é só o modo compacto: quando o cartão do pé entra, a capa paga por ele em altura,
    // e uma capa menor dentro de uma coluna larga como antes ficaria boiando entre duas faixas
    // de vazio — que é justamente o defeito que o cartão veio fechar. Sem cartão a largura é a
    // de sempre, e a janela do desenho continua medindo 392.
    implicitWidth: (root.cabeCartao ? capaRect.lado : root.coverSide)
                   + (Theme.marginXL + Theme.marginS) * 2 + 4
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
    readonly property double coverRevision: CoverCache.revision

    // O endereço da arte do que está tocando, num lugar só: as duas camadas da capa e o halo
    // leem daqui, e antes disso a mesma expressão de três linhas vivia dentro do RoundedCover.
    readonly property url fonteDaCapa:
        root.episodeMode
        ? (root.episodeInfo.coverPath !== undefined && root.episodeInfo.coverPath !== ""
           ? "file://" + root.episodeInfo.coverPath : "")
        : (root.coverRevision >= 0 && root.info.albumId !== undefined
           ? CoverCache.coverUrlForTrack(AudioEngine.currentFile, root.info.albumId) : "")

    // Qual das duas camadas está na frente. A troca NÃO acontece no instante em que a faixa
    // muda: a camada de trás recebe a arte nova e as duas só trocam de lugar quando ela
    // terminou de carregar. Sem essa espera, o cruzamento mostraria o bloco cinza do
    // placeholder no meio do caminho — remédio pior que a doença.
    property bool capaAnaFrente: true

    readonly property var capaDaFrente: root.capaAnaFrente ? capaA : capaB
    readonly property var capaDeTras: root.capaAnaFrente ? capaB : capaA

    // Os focos de luz que o halo pinta. Guardados em vez de derivados: quando a faixa nova não
    // tem cor a dar (capa ausente, capa em escala de cinza) o halo apaga pela opacidade e os
    // últimos focos ficam parados onde estavam, em vez de sumirem no meio da travessia.
    //
    // E são FOCOS, no plural, desde 29/08: uma cor média só devolve um bege que não existe na
    // arte quando a capa tem céu azul em cima e areia laranja embaixo. A luz de uma capa tem
    // as cores dela, nos lugares delas.
    property var focosDoHalo: []

    // `--halo-teste`: acende o halo com focos sintéticos, sem precisar de música. Existe para
    // que o halo possa ser posto sob esforço (redimensionamento em rajada) por um script, em
    // vez de depender de alguém clicar numa faixa — foi assim que o crash de 29/08 pôde ser
    // reproduzido fora da tela do Pedro.
    readonly property bool haloDeTeste:
        Qt.application.arguments.indexOf("--halo-teste") >= 0

    readonly property var focosSinteticos: [
        { color: Qt.rgba(0.20, 0.42, 0.90, 1), x: 0.16, y: 0.16, weight: 1.00 },
        { color: Qt.rgba(0.90, 0.52, 0.10, 1), x: 0.83, y: 0.83, weight: 0.80 },
        { color: Qt.rgba(0.10, 0.80, 0.40, 1), x: 0.83, y: 0.16, weight: 0.60 },
        { color: Qt.rgba(0.80, 0.10, 0.50, 1), x: 0.16, y: 0.83, weight: 0.40 }
    ]

    readonly property var focosDaCapaAtual:
        root.haloDeTeste ? root.focosSinteticos : root.capaDaFrente.colorSpots

    onFocosDaCapaAtualChanged: {
        if (root.focosDaCapaAtual.length > 0)
            root.focosDoHalo = root.focosDaCapaAtual
    }

    // O halo sai da foto do gate: a cor dele vem do acervo de quem roda, e o gate de
    // fidelidade mede 15 pontos fixos com 3 níveis de tolerância por canal — um deles a
    // 16 px da capa. Ou o halo sai da foto, ou o gate passa a medir sorte.
    readonly property bool mostrarHalo:
        !Theme.medindo && (root.hasTrack || root.haloDeTeste)
        && root.focosDaCapaAtual.length > 0

    onFonteDaCapaChanged: {
        root.capaDeTras.source = root.fonteDaCapa
        // Uma faixa sem capa nenhuma nunca fica "pronta": o relógio garante que a troca
        // acontece de qualquer jeito, e o placeholder cruza como cruzaria uma arte.
        trocaDeCapa.restart()
    }

    Timer {
        id: trocaDeCapa
        interval: 350
        onTriggered: root.capaAnaFrente = !root.capaAnaFrente
    }

    // O que a coluna gasta abaixo da capa: título, progresso, transporte, volume, etiquetas e
    // os espaçamentos entre eles. MEDIDO, não estimado — o app imprime a soma real com
    // `--measure`, e ela dá 309 px na escala 1 em qualquer altura de janela. O número antigo
    // (330) era chute, e o chute só não aparecia porque a conta usava a altura da JANELA
    // inteira: as margens da coluna, 48 px, cobriam o erro. Contra a altura da coluna, que é
    // o espaço que existe de verdade, o erro vira cartão transbordando pelo pé.
    readonly property int reservaAbaixoDaCapa: Math.round(310 * Theme.uiScale)

    // O cartão do pé custa altura, e quem paga é a capa — é o único bloco elástico da coluna.
    // A conta sai da altura da COLUNA e de mais nada: medir o vazio que sobra seria circular
    // (o cartão mediria o espaço que ele próprio ocupa), e o QML corta uma ligação circular no
    // meio — o que aparece na tela é um buraco do tamanho do cartão, no lugar do cartão.
    readonly property int custoDoCartao: proxima.alturaCheia + Theme.marginXL
    readonly property int capaComCartao: Math.min(root.coverSide,
                                                  col.height - root.reservaAbaixoDaCapa
                                                  - root.custoDoCartao)

    // 340 px de tela, sem escala: é a capa do desenho. Abaixo disso o cartão estaria comprando
    // espaço com a arte, que é o assunto do painel — então em janela baixa ele não entra, e
    // quem fala da fila é a tirinha do pé da lista. Numa janela alta a capa paga sem sentir:
    // ela já tinha crescido junto com a interface.
    readonly property bool cabeCartao: proxima.temProximo && root.capaComCartao >= 340

    // Se o que vem a seguir já está dito AQUI. A janela lê isto para não repetir o assunto no
    // pé da lista: a fila tem um lugar só na tela, e o lugar muda com a altura da janela —
    // numa janela baixa o cartão não cabe e a tirinha do pé volta a ser esse lugar.
    readonly property bool mostrandoProxima: root.hasTrack && root.cabeCartao

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

    Component.onCompleted: {
        root.refresh()
        capaA.source = root.fonteDaCapa
    }



    Connections {
        target: AudioEngine
        function onCurrentFileChanged() {
            root.refresh()
            entradaDosTextos.restart()
        }
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

    AmbientGlow {
        anchors.fill: parent
        // Sem `z`, e declarado ANTES da coluna: no Qt Quick um filho com z NEGATIVO é
        // desenhado atrás do conteúdo do próprio pai, e o pai aqui é o painel — cujo degradê
        // é opaco. Com `z: -1` o halo existia, respondia, e não aparecia em pixel nenhum
        // (medido: zero diferença de cor com ele ligado e desligado). A ordem de declaração
        // já o põe atrás da capa, que é o único lugar em que ele precisa ficar.
        focos: root.focosDoHalo
        // A capa é o primeiro item da coluna e está centrada nela: a posição sai da conta, e
        // não de mapToItem, porque mapeamento não é reativo e a capa muda de tamanho com a
        // altura da janela.
        capaX: Math.round((root.width - capaRect.lado) / 2)
        capaY: Theme.marginXL + Theme.marginS
        capaLado: capaRect.lado
        opacity: root.mostrarHalo ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animationSlowest; easing.type: Theme.easingType }
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.marginXL + Theme.marginS
        spacing: Theme.marginXL

        Item {
            id: capaRect

            // O resto da coluna (título, progresso, controles, tags) ocupa 310px, mais o
            // cartão do pé quando ele entra. Quando a janela é mais baixa que isso + 340, a
            // capa cede espaço — mas cede QUADRADA: sem amarrar largura à altura, o Layout
            // encolheria só a altura e a arte sairia deformada. Salvaguarda: numa janela de
            // 1384 a medida confirma 340x340.
            readonly property int lado: Math.max(Math.round(120 * Theme.uiScale),
                                                Math.min(root.coverSide,
                                                         col.height - root.reservaAbaixoDaCapa
                                                         - (root.cabeCartao ? root.custoDoCartao : 0)))

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

            // Duas capas, não uma. A arte trocava no mesmo quadro em que a faixa trocava, e
            // 340x340 px mudando de golpe é a coisa mais brusca que este painel faz. Com duas
            // camadas a nova sobe enquanto a velha desce, e nenhum quadro fica vazio — que é
            // o que aconteceria fazendo a mesma capa piscar.
            //
            // O bloco existe mesmo sem nada tocando: o desenho põe degradê e sombra no
            // quadrado da capa em todas as telas, e era a ausência dele que fazia o painel
            // vazio parecer um buraco recortado no fundo. A moldura tracejada e o "nada
            // tocando" continuam por cima — é o que distingue vazio de capa que falta.
            component Capa: RoundedCover {
                anchors.fill: parent
                radius: Theme.radiusM
                analyzeColors: true
                // A única capa do app que projeta sombra: é ela que descola a arte do painel.
                shadow: true
                placeholderColor: Theme.cRaised
                placeholderTop: root.episodeMode ? Theme.cCoverTopPod : Theme.cCoverTop
                placeholderMid: root.episodeMode ? Theme.cCoverMidPod : Theme.cCoverMid
                // Sem faixa quem desenha o ícone é a coluna de baixo, no tamanho pequeno do
                // desenho; aqui ele sairia grande e duplicado.
                fallbackIcon: !root.hasTrack ? ""
                                             : (root.episodeMode ? "microphone" : "music")
                // 64 px num bloco de 340 no desenho — proporção, não medida fixa, porque a
                // capa encolhe junto com a janela.
                fallbackIconSize: Math.round(capaRect.lado * 64 / 340)
                fallbackIconColor: root.episodeMode ? Theme.cCoverIconPod : Theme.cCoverIcon

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationNormal
                        easing.type: Theme.easingType
                    }
                }
            }

            Capa {
                id: capaA
                opacity: root.capaAnaFrente ? 1 : 0
                // 0 e -1, nunca 1 e 0: a moldura tracejada e o "nada tocando" que ficam por
                // cima da capa usam `z: 1`, e com empate de z quem é declarado depois ganha.
                // Com `z: 1` aqui, as duas camadas cobriam os dois e o painel sem faixa virava
                // um quadrado cinza liso — a capa antiga não tinha z nenhum, e era só por isso
                // que funcionava.
                z: root.capaAnaFrente ? 0 : -1
                onReadyChanged: {
                    if (capaA.ready && !root.capaAnaFrente && trocaDeCapa.running) {
                        trocaDeCapa.stop()
                        root.capaAnaFrente = true
                    }
                }
            }

            Capa {
                id: capaB
                opacity: root.capaAnaFrente ? 0 : 1
                z: root.capaAnaFrente ? -1 : 0
                onReadyChanged: {
                    if (capaB.ready && root.capaAnaFrente && trocaDeCapa.running) {
                        trocaDeCapa.stop()
                        root.capaAnaFrente = false
                    }
                }
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
                id: textos
                Layout.fillWidth: true
                spacing: Theme.marginXXS

                // Os metadados trocam junto com a capa. Sem isto eles saltavam enquanto a
                // arte cruzava, e o cruzamento ficava pela metade — a parte animada dizendo
                // "está mudando" e a parte de texto já mudada.
                transform: Translate { id: deslocDosTextos }

                SequentialAnimation {
                    id: entradaDosTextos

                    ParallelAnimation {
                        NumberAnimation {
                            target: textos
                            property: "opacity"
                            from: 0.0
                            to: 1.0
                            duration: Theme.animationFast
                            easing.type: Theme.easingType
                        }
                        NumberAnimation {
                            target: deslocDosTextos
                            property: "y"
                            from: Math.round(6 * Theme.uiScale)
                            to: 0
                            duration: Theme.animationFast
                            easing.type: Theme.easingType
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.tituloAtual
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXXL
                    font.weight: Theme.fontWeightBold
                    font.letterSpacing: Theme.letterSpacingTitle * Theme.fontSizeXXL
                    color: Theme.cTitle
                    // Encolher antes de cortar: a coluna estreita quando o cartão do pé entra,
                    // e um nome de treze letras que cabia inteiro virava "One Mor…". Só depois
                    // de chegar ao tamanho do subtítulo é que o corte volta a valer.
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: Theme.fontSizeXL
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
                id: botaoCurtir

                visible: root.trackId > 0 && !root.episodeMode
                icon: root.info.liked === true ? "heart-filled" : "heart"
                size: Theme.fontSizeXL
                accent: root.info.liked === true
                onClicked: {
                    // O estado ainda é o antigo aqui: comemorar só quando o clique vai
                    // CURTIR. Descurtir troca o desenho e mais nada.
                    if (root.info.liked !== true)
                        botaoCurtir.comemorar()
                    root.likeRequested(root.trackId)
                }
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
                id: botaoPlay

                Layout.preferredWidth: Math.round(52 * Theme.uiScale)
                Layout.preferredHeight: Math.round(52 * Theme.uiScale)
                radius: Math.round(26 * Theme.uiScale)
                color: Theme.cTitle

                // É o botão mais apertado do app, e por isso a animação aqui é quase
                // imperceptível de propósito: um gesto repetido dezenas de vezes por dia com
                // transição longa deixa de parecer rápido. Encolher 6% em 75 ms confirma o
                // toque sem cobrar tempo por ele.
                scale: playArea.pressed ? 0.94 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animationFaster
                        easing.type: Theme.easingType
                    }
                }

                // Os dois glifos sobrepostos: um Text só trocando de texto põe o desenho novo
                // no lugar do velho sem passar por lugar nenhum, e é o único lugar da tela
                // onde isso acontece a cada pausa.
                Text {
                    anchors.centerIn: parent
                    text: Icons.get("play")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeXL
                    color: Theme.cBase
                    opacity: AudioEngine.playing && root.hasTrack ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animationFaster
                            easing.type: Theme.easingType
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.get("pause")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeXL
                    color: Theme.cBase
                    opacity: AudioEngine.playing && root.hasTrack ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animationFaster
                            easing.type: Theme.easingType
                        }
                    }
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

                    // Clicar no trilho leva o volume de um lugar a outro sem passar pelo meio.
                    // Deslizar diz que foi a MESMA barra que mudou, e não uma barra nova
                    // aparecendo no lugar da anterior.
                    //
                    // Só o volume: a barra de progresso da faixa já se move sozinha, e um
                    // Behavior nela faria o tempo mentir e brigar com cada arrasto de seek.
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animationFast
                            easing.type: Theme.easingType
                        }
                    }
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

        // O primeiro pedaço do que sobra, e no máximo isto: o transporte deixa de encostar nas
        // etiquetas sem que uma janela muito alta abra um corredor entre os dois.
        Item {
            id: folga
            Layout.fillHeight: true
            Layout.maximumHeight: Theme.marginXL * 2
            visible: root.hasTrack
        }

        TagEditor {
            id: tagEd
            Layout.fillWidth: true
            visible: root.hasTrack && root.trackId > 0 && !root.episodeMode
            trackId: root.trackId
            onTagChosen: function (name) { root.tagChosen(name) }
        }

        // O resto do vazio, entre as etiquetas e o cartão do pé: é ele que separa o bloco do
        // que toca do bloco do que vem, e é ele que segura a capa no topo quando a coluna
        // encolhe. Numa janela que só dá para o mínimo, ele fica em zero e a coluna fecha
        // cheia; numa janela alta, ele é o respiro.
        Item { id: sobra; Layout.fillHeight: true }

        // O pé da coluna enquanto toca. Sem ele o painel entrega capa, transporte e etiquetas
        // e devolve o resto da altura ao vazio — numa janela alta, mais da metade.
        NextUpCard {
            id: proxima

            Layout.fillWidth: true
            // Quem decide se ele entra é a altura da janela (`cabeCartao`), lá em cima: na
            // janela do desenho (700) a capa teria de cair abaixo do tamanho aprovado para
            // pagar por ele, e aí quem fala da fila é a tirinha do pé da lista.
            visible: root.hasTrack && root.cabeCartao
            onEntryActivated: function (queueIndex) { root.queueJumpRequested(queueIndex) }
            onExpandRequested: root.queueOpenRequested()
        }
    }
}
