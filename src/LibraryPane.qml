pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodarium.App

// O miolo da biblioteca do desenho aprovado (design/Biblioteca.dc.html): cabeçalho com a
// contagem, uma barra de busca, UMA linha de filtros e a lista densa. Sem moldura própria —
// no desenho o miolo é o fundo da janela, e uma caixa em volta da lista só rouba largura.
Item {
    id: root

    property alias model: list.model
    property string filter: "all"
    // Quando um eixo (artistas/álbuns/gêneros/tags) é escolhido sem grupo, a lista mostra os
    // grupos em vez das faixas. Sem isto, clicar em "Artistas" congelaria a tela.
    property var groups: []
    property bool showingGroups: false
    property string groupTitle: ""
    // The design puts "Ólafur Arnalds · 8 faixas · 35 min" in the header: without the artist,
    // two same-named albums by different artists are indistinguishable (design/Main.dc.html:82).
    property string groupSubtitle: ""
    property bool scanning: false

    // Lidas por `melodarium --measure`: a linha de filtros nunca pode pedir mais largura do
    // que tem. Ela não quebra em duas — ela espreme, e o Pedro reprovou as duas coisas.
    readonly property alias chipsImplicitWidth: chips.implicitWidth
    readonly property alias chipsWidth: chips.width

    signal groupChosen(string key)
    signal groupOpened(string section, int id)
    signal tagOpened(string name)
    signal trackActivated(int index)
    signal collectRequested(int trackId)
    signal searchRequested
    signal queueActivated(int queueIndex)
    signal queueExpandRequested
    signal collectAllRequested

    function reload() {
        chips.likedCount = LibraryBrowser.likedCount()
    }

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

    function withThousands(n) {
        return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ".")
    }

    Component.onCompleted: root.reload()

    Connections {
        target: LibraryBrowser
        function onLikedChanged(id, liked) {
            root.reload()
            // O contador do chip já se atualizava; a LINHA não. Sem esta chamada o
            // coração só muda quando a lista inteira é recarregada por outro motivo.
            if (list.model !== null)
                list.model.applyLiked(id, liked)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginXL + Theme.marginS
        anchors.bottomMargin: Theme.marginXL
        spacing: Theme.marginL

        // --- Cabeçalho: o que é a lista, e de que tamanho ela é ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            // O desenho empilha o nome da lista e a ficha dela (design/Main.dc.html:79-82).
            // Medido em 2026-08-28: em UMA linha, "Curses From Past Times (EP)" com o artista
            // e o botão pedia 44 px a mais do que a coluna tem, e o miolo inteiro transbordava
            // para fora da janela. Empilhado, cabe em qualquer largura.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.groupTitle !== "" ? root.groupTitle : qsTr("Biblioteca")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXL
                    font.weight: Theme.fontWeightSemiBold
                    font.letterSpacing: Theme.letterSpacingHeading * Theme.fontSizeXL
                    color: Theme.cTitle
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.marginS

                    // O artista do álbum, antes da contagem, para o cabeçalho ler como uma
                    // frase: "Ólafur Arnalds · 8 faixas · 35 min".
                    Text {
                        Layout.maximumWidth: root.width * 0.4
                        visible: root.groupSubtitle !== "" && !root.showingGroups
                        text: root.groupSubtitle + " ·"
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.cDim
                    }

                    Text {
                        text: root.showingGroups
                              ? root.groups.length + qsTr(" itens")
                              : root.withThousands(list.count) + qsTr(" faixas")
                                + (list.model !== null && list.model.totalDurationMs > 0
                                   ? " · " + root.formatTotal(list.model.totalDurationMs) : "")
                        font.family: Theme.fontFamilyFixed
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.cDim
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                visible: root.scanning
                text: qsTr("varrendo…")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                color: Theme.cMuted
            }

            // Doze faixas numa coleção custavam doze idas ao menu da linha. Este botão joga
            // a lista inteira que está na tela de uma vez (design/Main.dc.html:84-87).
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: Math.round(24 * Theme.uiScale)
                Layout.preferredWidth: rotuloColecao.implicitWidth + Theme.marginM * 2
                visible: !root.showingGroups && list.count > 0
                radius: Theme.iRadiusS
                color: coletarArea.containsMouse ? Theme.cRaised : "transparent"
                border.width: Theme.borderS
                border.color: Theme.cLine

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                Row {
                    id: rotuloColecao
                    anchors.centerIn: parent
                    spacing: Theme.marginS

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.get("plus")
                        font.family: Icons.fontFamily
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.cMuted
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Coleção")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.cSubtle
                    }
                }

                MouseArea {
                    id: coletarArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.collectAllRequested()
                }
            }

            // Reler a pasta é raro, então o botão é discreto: só o ícone, sem rótulo.
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                icon: "history"
                size: Theme.fontSizeS
                opacity: 0.55
                tooltip: qsTr("reler a pasta")
                enabled: Database.libraryPath !== "" && !root.scanning
                onClicked: Database.startScan()
            }
        }

        // --- A busca mora aqui, mas quem procura é o overlay ---
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.round(30 * Theme.uiScale)
            radius: Theme.iRadiusS
            color: searchArea.containsMouse ? Theme.cPill : Theme.cRaised
            border.width: Theme.borderS
            border.color: Theme.cLine

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.marginM
                anchors.rightMargin: Theme.marginM
                spacing: Theme.marginS

                Text {
                    text: Icons.get("search")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.cMuted
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("buscar por título, artista, álbum…")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.cDim
                }
                Text {
                    text: "Ctrl+K"
                    font.family: Theme.fontFamilyFixed
                    font.pixelSize: Theme.fontSizeXS
                    color: Theme.cFaint
                }
            }

            MouseArea {
                id: searchArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.searchRequested()
            }
        }

        FilterChips {
            id: chips
            Layout.fillWidth: true
            current: root.filter
            onChosen: function (key) { root.groupChosen(key) }
        }

        // --- A lista: grupos ou faixas, nunca as duas ---
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.showingGroups
            clip: true
            spacing: 1
            cacheBuffer: 400
            boundsBehavior: Flickable.StopAtBounds

            delegate: TrackRow {
                id: trackDelegate

                required property var model
                required property int index

                width: ListView.view.width
                position: trackDelegate.index + 1
                alternate: trackDelegate.index % 2 === 1
                title: trackDelegate.model.title
                artist: trackDelegate.model.artist
                album: trackDelegate.model.album
                durationMs: trackDelegate.model.durationMs
                coverUrl: trackDelegate.model.coverUrl
                isCurrent: trackDelegate.model.isCurrent
                trackId: trackDelegate.model.trackId
                liked: trackDelegate.model.liked
                showCollectButton: true
                sourceKind: trackDelegate.model.sourceKind

                // Sinal, nunca root.parent.algumaCoisa(): o pane não pode saber quem é o pai.
                onActivated: root.trackActivated(trackDelegate.index)
                onLikeToggled: LibraryBrowser.toggleLike(trackDelegate.model.trackId)
                onCollectRequested: root.collectRequested(trackDelegate.model.trackId)
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0 && !root.scanning
                text: Database.libraryPath === ""
                      ? qsTr("nenhuma pasta de música escolhida ainda")
                      : qsTr("nada nesta lista")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.cMuted
            }
        }

        ListView {
            id: groupList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.showingGroups
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            model: root.groups

            delegate: Rectangle {
                id: groupRow

                required property var modelData
                required property int index

                width: ListView.view.width
                height: Math.round(38 * Theme.uiScale)
                radius: Theme.radiusXS
                color: groupArea.containsMouse
                       ? Theme.cPill
                       : (groupRow.index % 2 === 1
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: groupRow.modelData.name
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeM
                            color: groupArea.containsMouse ? Theme.cTitle : Theme.cTitle
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: groupRow.modelData.subtitle !== undefined
                                  ? groupRow.modelData.subtitle : ""
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            color: groupArea.containsMouse ? Theme.cTitle : Theme.cFaint
                        }
                    }

                    Text {
                        text: groupRow.modelData.count + qsTr(" faixas")
                        font.family: Theme.fontFamilyFixed
                        font.pixelSize: Theme.fontSizeS
                        color: groupArea.containsMouse ? Theme.cTitle : Theme.cFaint
                    }
                }

                MouseArea {
                    id: groupArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.filter === "tags")
                            root.tagOpened(groupRow.modelData.name)
                        else
                            root.groupOpened(root.filter, groupRow.modelData.id)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: groupList.count === 0
                text: qsTr("nada nesta lista")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.cMuted
            }
        }

        // O pé da lista, como no desenho: a fila mora aqui, não no painel da capa.
        QueueStrip {
            Layout.fillWidth: true
            onEntryActivated: function (queueIndex) { root.queueActivated(queueIndex) }
            onExpandRequested: root.queueExpandRequested()
        }
    }
}
