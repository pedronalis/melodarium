pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodia.App

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
    property bool scanning: false

    // Lidas por `appmelodia --measure`: a linha de filtros nunca pode pedir mais largura do
    // que tem. Ela não quebra em duas — ela espreme, e o Pedro reprovou as duas coisas.
    readonly property alias chipsImplicitWidth: chips.implicitWidth
    readonly property alias chipsWidth: chips.width

    signal groupChosen(string key)
    signal groupOpened(string section, int id)
    signal tagOpened(string name)
    signal trackActivated(int index)
    signal collectRequested(int trackId)
    signal searchRequested

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
        function onLikedChanged(id, liked) { root.reload() }
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

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.groupTitle !== "" ? root.groupTitle : qsTr("Biblioteca")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.showingGroups
                      ? root.groups.length + qsTr(" itens")
                      : root.withThousands(list.count) + qsTr(" faixas")
                        + (list.model !== null && list.model.totalDurationMs > 0
                           ? " · " + root.formatTotal(list.model.totalDurationMs) : "")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeS
                color: Theme.mOutline
            }

            Item { Layout.fillWidth: true }

            Text {
                Layout.alignment: Qt.AlignBaseline
                visible: root.scanning
                text: qsTr("varrendo…")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }

            // Reler a pasta é raro, então o botão é discreto: só o ícone, sem rótulo.
            IconButton {
                Layout.preferredWidth: 22
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
            implicitHeight: 30
            radius: Theme.iRadiusS
            color: searchArea.containsMouse
                   ? Theme.mSurfaceVariant
                   : Qt.rgba(Theme.mSurfaceVariant.r, Theme.mSurfaceVariant.g,
                             Theme.mSurfaceVariant.b, 0.5)
            border.width: Theme.borderS
            border.color: Theme.mSurfaceVariant

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
                    font.pointSize: Theme.fontSizeS
                    color: Theme.mOnSurfaceVariant
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("buscar por título, artista, álbum…")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: Theme.mOutline
                }
                Text {
                    text: "Ctrl+K"
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeXS
                    color: Theme.mOutline
                    opacity: 0.7
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
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurfaceVariant
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
                height: 38
                radius: Theme.radiusXS
                color: groupArea.containsMouse
                       ? Theme.mHover
                       : (groupRow.index % 2 === 1
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: groupRow.modelData.name
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeM
                            color: groupArea.containsMouse ? Theme.mOnHover : Theme.mOnSurface
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: groupRow.modelData.subtitle !== undefined
                                  ? groupRow.modelData.subtitle : ""
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSizeS
                            color: groupArea.containsMouse ? Theme.mOnHover : Theme.mOutline
                        }
                    }

                    Text {
                        text: groupRow.modelData.count + qsTr(" faixas")
                        font.family: Theme.fontFamilyFixed
                        font.pointSize: Theme.fontSizeS
                        color: groupArea.containsMouse ? Theme.mOnHover : Theme.mOutline
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
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurfaceVariant
            }
        }
    }
}
