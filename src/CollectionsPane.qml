pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodia.App

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

    function close() {
        root.openId = 0
        root.openName = ""
        root.closeRequested()
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
                font.pointSize: Theme.fontSizeXL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.openId > 0
                      ? tracks.count + qsTr(" faixas")
                      : root.items.length + qsTr(" coleções")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeS
                color: Theme.mOutline
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
            font.pointSize: Theme.fontSizeXS
            color: Theme.mError
        }

        // --- A lista das coleções ---
        ListView {
            id: lista
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.openId === 0
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            model: root.items

            delegate: Rectangle {
                id: linha

                required property var modelData
                required property int index

                width: ListView.view.width
                height: Math.round(44 * Theme.uiScale)
                radius: Theme.radiusXS
                color: area.containsMouse
                       ? Theme.mHover
                       : (linha.index % 2 === 1
                          ? Qt.rgba(Theme.mSurfaceVariant.r, Theme.mSurfaceVariant.g,
                                    Theme.mSurfaceVariant.b, 0.45)
                          : "transparent")

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginL
                    anchors.rightMargin: Theme.marginL
                    spacing: Theme.marginL

                    Text {
                        text: Icons.get("playlist")
                        font.family: Icons.fontFamily
                        font.pointSize: Theme.fontSizeM
                        color: area.containsMouse ? Theme.mOnHover : Theme.mTertiary
                    }

                    Text {
                        Layout.fillWidth: true
                        text: linha.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeM
                        color: area.containsMouse ? Theme.mOnHover : Theme.mOnSurface
                    }

                    Text {
                        text: linha.modelData.count + qsTr(" faixas")
                        font.family: Theme.fontFamilyFixed
                        font.pointSize: Theme.fontSizeS
                        color: area.containsMouse ? Theme.mOnHover : Theme.mOutline
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
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurfaceVariant
            }
        }

        // --- As faixas da coleção aberta ---
        ListView {
            id: tracks
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.openId > 0
            clip: true
            spacing: 1
            cacheBuffer: 400
            boundsBehavior: Flickable.StopAtBounds

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
                coverUrl: faixa.model.coverUrl
                isCurrent: faixa.model.isCurrent
                trackId: faixa.model.trackId
                liked: faixa.model.liked
                sourceKind: faixa.model.sourceKind
                // Dentro de uma coleção o gesto útil não é "pôr numa coleção": é tirar
                // desta. O + da biblioteca daria uma segunda porta para o mesmo lugar.
                showCollectButton: false

                onActivated: root.trackActivated(faixa.index)
                onLikeToggled: LibraryBrowser.toggleLike(faixa.model.trackId)
            }

            Text {
                anchors.centerIn: parent
                visible: tracks.count === 0
                text: qsTr("coleção vazia — jogue faixas nela pelo + da biblioteca")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurfaceVariant
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
