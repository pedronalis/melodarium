pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodarium.App

// O diferencial nº 1 do produto, de volta à tela. Dois estados no mesmo painel: a lista das
// coleções, e as faixas de UMA coleção aberta. A linha de faixa é o mesmo TrackRow da
// biblioteca de propósito — uma faixa não pode ter duas aparências no mesmo app.
Item {
    id: root

    property alias model: tracks.model
    property int openId: 0
    property string openName: ""

    signal collectionOpened(int id, string name)
    signal closeRequested
    signal trackActivated(int index)
    signal trackRemoved(int trackId)
    // A coleção é uma playlist: playlist se toca inteira. Sem isto o único jeito de ouvir
    // "Pra codar" era abrir e clicar numa faixa, o que é navegar, não tocar.
    signal playRequested(bool shuffled)
    signal trackMoved(int trackId, int newIndex)

    property var items: []
    // url -> { received, total }. O download é por link, não por linha: guardar isso dentro
    // de um delegate que a rolagem recicla perderia o progresso ao rolar.
    property var activeDownloads: ({})

    function refresh() {
        root.items = CollectionManager.collections()
    }

    function open(id, name) {
        root.openId = id
        root.openName = name
        root.collectionOpened(id, name)
    }

    // Abrir por id: quem chama de fora (a medição) tem o id, não o nome.
    function openById(id) {
        for (let i = 0; i < root.items.length; ++i) {
            if (root.items[i].id === id) {
                root.open(id, root.items[i].name)
                return
            }
        }
    }

    function close() {
        root.openId = 0
        root.openName = ""
        root.closeRequested()
    }

    // Duplicada de LibraryPane.formatTotal de propósito: QML não tem um lugar comum para
    // função pura (Theme é singleton de ESTILO, e pendurar lógica nele mistura os papéis).
    // Se as duas divergirem, a lista e o cabeçalho passam a contar tempo de jeitos diferentes.
    function formatTotal(ms) {
        const minutes = Math.floor(ms / 60000)
        const hours = Math.floor(minutes / 60)
        const days = Math.floor(hours / 24)
        if (days > 0)
            return days + " d " + (hours % 24) + " h"
        if (hours > 0)
            return hours + " h " + (minutes % 60) + " min"
        return minutes + " min"
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: CollectionManager
        function onCollectionsChanged() { root.refresh() }
    }

    Connections {
        target: YtDlpDownloader
        function onProgress(url, downloaded, total) {
            const next = root.activeDownloads
            next[url] = { received: downloaded, total: total }
            root.activeDownloads = next
        }
        function onFinished(url, trackId) {
            const next = root.activeDownloads
            delete next[url]
            root.activeDownloads = next
            root.refresh()
        }
        function onFailed(url, reason) {
            const next = root.activeDownloads
            delete next[url]
            root.activeDownloads = next
            aviso.text = reason
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginXL + Theme.marginS
        anchors.bottomMargin: Theme.marginXL
        spacing: Theme.marginL

        // --- Cabeçalho: o nome do lugar, e o que dá para fazer nele ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId > 0
                icon: "chevron-left"
                size: Theme.fontSizeS
                tooltip: qsTr("todas as coleções")
                onClicked: root.close()
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.openId > 0 ? root.openName : qsTr("Coleções")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.cTitle
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.openId > 0
                      ? tracks.count + qsTr(" faixas")
                      : root.items.length + qsTr(" coleções")
                font.family: Theme.fontFamilyFixed
                font.pixelSize: Theme.fontSizeS
                color: Theme.cFaint
            }

            // O único disco claro da tela significa "tocar" — é o mesmo do transporte.
            Rectangle {
                Layout.leftMargin: Theme.marginS
                Layout.preferredWidth: Math.round(30 * Theme.uiScale)
                Layout.preferredHeight: Math.round(30 * Theme.uiScale)
                visible: root.openId > 0 && tracks.count > 0
                radius: width / 2
                color: tocarArea.containsMouse ? Theme.cStrong : Theme.cTitle

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.get("play")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.cBase
                }

                MouseArea {
                    id: tocarArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.playRequested(false)
                }
            }

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId > 0 && tracks.count > 0
                icon: "shuffle"
                size: Theme.fontSizeS
                tooltip: qsTr("tocar embaralhado")
                onClicked: root.playRequested(true)
            }

            Item { Layout.fillWidth: true }

            // Baixar só faz sentido com uma coleção aberta: o arquivo tem de cair em algum
            // lugar, e o lugar é a coleção que o usuário está olhando.
            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId > 0
                icon: "download"
                size: Theme.fontSizeS
                tooltip: qsTr("colar link do YouTube")
                onClicked: {
                    linkDialog.collectionId = root.openId
                    linkDialog.open()
                }
            }

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId > 0
                icon: "history"
                size: Theme.fontSizeS
                tooltip: qsTr("renomear")
                onClicked: {
                    nomeDialog.renameId = root.openId
                    nomeDialog.initialText = root.openName
                    nomeDialog.open()
                }
            }

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId > 0
                icon: "close"
                size: Theme.fontSizeS
                tooltip: qsTr("apagar coleção")
                onClicked: {
                    apagar.message = qsTr("Apagar \"%1\"? As faixas continuam na biblioteca.")
                                     .arg(root.openName)
                    apagar.open()
                }
            }

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                visible: root.openId === 0
                icon: "plus"
                size: Theme.fontSizeS
                tooltip: qsTr("nova coleção")
                onClicked: {
                    nomeDialog.renameId = 0
                    nomeDialog.initialText = ""
                    nomeDialog.open()
                }
            }
        }

        Repeater {
            model: Object.keys(root.activeDownloads)

            DownloadProgressRow {
                required property var modelData
                Layout.fillWidth: true
                url: modelData
                received: root.activeDownloads[modelData].received
                total: root.activeDownloads[modelData].total
                onCancelRequested: YtDlpDownloader.cancel(modelData)
            }
        }

        Text {
            id: aviso
            Layout.fillWidth: true
            visible: aviso.text !== ""
            text: ""
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXS
            color: Theme.mError
        }

        // --- A lista das coleções ---
        ListView {
            id: lista
            reuseItems: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.openId === 0
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            model: root.items

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

            delegate: Rectangle {
                id: linha

                required property var modelData
                required property int index

                width: ListView.view.width
                height: Math.round(60 * Theme.uiScale)
                radius: Theme.radiusXS
                color: area.containsMouse
                       ? Theme.cPill
                       : (linha.index % 2 === 1
                          ? Qt.rgba(Theme.cRaised.r, Theme.cRaised.g,
                                    Theme.cRaised.b, 0.45)
                          : "transparent")

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginL
                    anchors.rightMargin: Theme.marginL
                    spacing: Theme.marginL

                    // A arte da coleção: mosaico com quatro, capa única com uma a três,
                    // ícone quando não há nenhuma. Sem isto a linha é texto puro e não lê
                    // como playlist.
                    Item {
                        id: arte

                        // `id` explícito, nunca `parent.parent`: dentro de um Repeater o pai
                        // muda de identidade conforme o QML embrulha o delegate, e a cadeia
                        // de parents quebra em silêncio — a arte some sem erro no console.
                        readonly property var capas: linha.modelData.covers !== undefined
                                                     ? linha.modelData.covers : []
                        readonly property int lado: Math.round(44 * Theme.uiScale)
                        readonly property int celula: Math.round((arte.lado - 2 * Theme.uiScale) / 2)

                        Layout.preferredWidth: arte.lado
                        Layout.preferredHeight: arte.lado

                        Grid {
                            anchors.fill: parent
                            visible: arte.capas.length >= 4
                            columns: 2
                            spacing: Math.round(2 * Theme.uiScale)

                            Repeater {
                                model: arte.capas.length >= 4 ? arte.capas.slice(0, 4) : []

                                RoundedCover {
                                    required property var modelData
                                    width: arte.celula
                                    height: arte.celula
                                    radius: Theme.radiusXXS
                                    fallbackIconSize: Theme.fontSizeXS
                                    source: CoverCache.coverUrlForTrack(modelData.path,
                                                                        modelData.albumId)
                                }
                            }
                        }

                        RoundedCover {
                            anchors.fill: parent
                            visible: arte.capas.length > 0 && arte.capas.length < 4
                            radius: Theme.radiusXS
                            fallbackIconSize: Theme.fontSizeL
                            source: arte.capas.length > 0
                                    ? CoverCache.coverUrlForTrack(arte.capas[0].path,
                                                                  arte.capas[0].albumId)
                                    : ""
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: arte.capas.length === 0
                            radius: Theme.radiusXS
                            color: Theme.cRaised

                            Text {
                                anchors.centerIn: parent
                                text: Icons.get("playlist")
                                font.family: Icons.fontFamily
                                font.pixelSize: Theme.fontSizeL
                                color: Theme.cLine
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.marginXXS

                        Text {
                            Layout.fillWidth: true
                            text: linha.modelData.name
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeM
                            font.weight: Theme.fontWeightMedium
                            color: Theme.cTitle
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                const n = linha.modelData.count + qsTr(" faixas")
                                const ms = linha.modelData.totalMs !== undefined
                                           ? linha.modelData.totalMs : 0
                                return ms > 0 ? n + " · " + root.formatTotal(ms) : n
                            }
                            elide: Text.ElideRight
                            font.family: Theme.fontFamilyFixed
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.cFaint
                        }
                    }

                    // Tocar sem abrir: o gesto que separa uma playlist de uma pasta.
                    Rectangle {
                        Layout.preferredWidth: Math.round(30 * Theme.uiScale)
                        Layout.preferredHeight: Math.round(30 * Theme.uiScale)
                        // Presente em repouso, aceso no hover — o idioma que o desenho usa
                        // para controle de linha (`.x { opacity: .35 }` em Colecoes.dc.html)
                        // e que o TrackRow já escreveu por extenso: um controle que só
                        // aparece no hover é um controle que o usuário nunca acha.
                        visible: linha.modelData.count > 0
                        opacity: area.containsMouse ? 1.0 : 0.35
                        radius: width / 2
                        color: Theme.cTitle

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.get("play")
                            font.family: Icons.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.cBase
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // Abrir ANTES de tocar: o modelo de faixas é o da coleção aberta,
                            // e tocar sem abrir carregaria a lista que estava na tela.
                            onClicked: {
                                root.open(linha.modelData.id, linha.modelData.name)
                                root.playRequested(false)
                            }
                        }
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.open(linha.modelData.id, linha.modelData.name)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: lista.count === 0
                width: parent.width * 0.7
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Nenhuma coleção ainda.\nCrie uma e jogue faixas dentro pelo + da lista.")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.cMuted
            }
        }

        // --- As faixas da coleção aberta ---
        ListView {
            id: tracks
            reuseItems: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.openId > 0
            clip: true
            spacing: 1
            cacheBuffer: 400
            boundsBehavior: Flickable.StopAtBounds

            // As duas bordas dissolvem no fundo em vez de cortar a linha ao meio. Filhos diretos da
            // lista, não do conteúdo dela: o conteúdo rola, estes ficam.
            ListFade {
                parent: tracks
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                paraCima: true
                corDeFundo: Theme.cBase
                opacity: tracks.atYBeginning ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animationFast } }
            }
            ListFade {
                parent: tracks
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                corDeFundo: Theme.cBase
                opacity: tracks.atYEnd ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.animationFast } }
            }

            delegate: TrackRow {
                id: faixa

                required property var model
                required property int index

                width: ListView.view.width
                position: faixa.index + 1
                alternate: faixa.index % 2 === 1
                title: faixa.model.title
                artist: faixa.model.artist
                album: faixa.model.album
                durationMs: faixa.model.durationMs
                isCurrent: faixa.model.isCurrent
                trackId: faixa.model.trackId
                liked: faixa.model.liked
                sourceKind: faixa.model.sourceKind
                // Dentro de uma coleção o gesto útil é o inverso: o mesmo botão da linha
                // tira a faixa daqui em vez de pô-la em outro lugar.
                showCollectButton: true
                collectGlyph: "close"

                draggable: true

                // A linha arrastada sobe para cima das outras e segue o dedo; o índice de
                // destino sai da altura da própria linha, que é fixa.
                z: dragArea.drag.active ? 2 : 0

                Drag.active: dragArea.drag.active
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                MouseArea {
                    id: dragArea
                    // 34 e não 20: a alça desenhada começa em 17 px (a margem do Rectangle
                    // do TrackRow mais a do RowLayout) e termina em 29. Com 20 a faixa
                    // arrastável cobria 3 px da alça e 17 px de vão — o gesto ficava onde o
                    // desenho não está. Para em 34, antes do número da faixa (42).
                    width: Math.round(34 * Theme.uiScale)
                    height: parent.height
                    anchors.left: parent.left
                    cursorShape: Qt.OpenHandCursor
                    drag.target: faixa
                    drag.axis: Drag.YAxis

                    onReleased: {
                        if (!drag.active)
                            return
                        // Quantas linhas o dedo andou, arredondando para a linha mais próxima.
                        const passo = faixa.height + tracks.spacing
                        const deslocou = Math.round(faixa.y / passo) - faixa.index
                        const destino = Math.max(0, Math.min(tracks.count - 1,
                                                             faixa.index + deslocou))
                        // Devolver a linha ao lugar ANTES de recarregar: o modelo vai
                        // repintar, e uma linha com y deslocado herdaria o deslocamento.
                        faixa.y = faixa.index * passo
                        if (destino !== faixa.index)
                            root.trackMoved(faixa.model.trackId, destino)
                    }
                }

                onActivated: root.trackActivated(faixa.index)
                onLikeToggled: LibraryBrowser.toggleLike(faixa.model.trackId)
                onCollectRequested: {
                    CollectionManager.removeTrackFromCollection(root.openId,
                                                               faixa.model.trackId)
                    root.trackRemoved(faixa.model.trackId)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: tracks.count === 0
                text: qsTr("coleção vazia — jogue faixas nela pelo + da biblioteca")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.cMuted
            }
        }
    }

    NewCollectionDialog {
        id: nomeDialog
        onCreated: function (id, name) { root.open(id, name) }
        onRenamed: function (id, name) { root.openName = name; root.refresh() }
    }

    ConfirmDialog {
        id: apagar
        onConfirmed: {
            CollectionManager.deleteCollection(root.openId)
            root.close()
        }
    }

    AddFromLinkDialog {
        id: linkDialog
    }
}
