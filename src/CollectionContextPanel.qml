pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodarium.App

// Coleções são curadoria, não uma variação da tela de reprodução. O painel mostra o objeto
// escolhido e deixa a faixa que continua tocando para o mini-player global.
Rectangle {
    id: root

    property bool compact: false
    property int selectedCollectionId: 0
    property var items: []

    signal openRequested(int collectionId, string name)
    signal playRequested(bool shuffled)
    signal createRequested()

    readonly property double coverRevision: CoverCache.revision
    readonly property int coverSide: root.compact
        ? Math.round(176 * Theme.uiScale) : Math.round(244 * Theme.uiScale)
    readonly property var selectedCollection: {
        for (let i = 0; i < root.items.length; ++i) {
            if (root.items[i].id === root.selectedCollectionId)
                return root.items[i]
        }
        return ({})
    }
    readonly property bool showingCollection: root.selectedCollection.id !== undefined
    readonly property var displayCovers: {
        if (root.showingCollection)
            return root.selectedCollection.covers !== undefined
                   ? root.selectedCollection.covers.slice(0, 4) : []
        const result = []
        for (let i = 0; i < root.items.length && result.length < 4; ++i) {
            const covers = root.items[i].covers !== undefined ? root.items[i].covers : []
            for (let j = 0; j < covers.length && result.length < 4; ++j)
                result.push(covers[j])
        }
        return result
    }
    readonly property int totalTracks: {
        let total = 0
        for (let i = 0; i < root.items.length; ++i)
            total += root.items[i].count !== undefined ? root.items[i].count : 0
        return total
    }

    implicitWidth: (root.compact ? Math.round(200 * Theme.uiScale) : Theme.panelCover)
                   + (Theme.marginXL + Theme.marginS) * 2 + 4
    color: Theme.cBase
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.cPanelTop }
        GradientStop { position: 0.55; color: Theme.cPanelMid }
        GradientStop { position: 1.0; color: Theme.cBase }
    }

    function refresh() {
        root.items = CollectionManager.collections()
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

    function statsFor(collection) {
        const count = collection.count !== undefined ? collection.count : 0
        const totalMs = collection.totalMs !== undefined ? collection.totalMs : 0
        return count + qsTr(" faixas") + (totalMs > 0 ? " · " + root.formatTotal(totalMs) : "")
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: CollectionManager
        function onCollectionsChanged() { root.refresh() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginXL + Theme.marginS
        spacing: Theme.marginL

        Text {
            Layout.fillWidth: true
            text: root.showingCollection ? qsTr("COLEÇÃO") : qsTr("SUA CURADORIA")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXXS
            font.weight: Theme.fontWeightSemiBold
            font.letterSpacing: Theme.letterSpacingLabel * Theme.fontSizeXXS
            color: Theme.cFaint
        }

        Item {
            Layout.preferredWidth: root.coverSide
            Layout.preferredHeight: root.coverSide
            Layout.alignment: Qt.AlignHCenter

            Grid {
                anchors.fill: parent
                visible: root.displayCovers.length > 1
                columns: 2
                spacing: Math.round(3 * Theme.uiScale)

                Repeater {
                    model: 4

                    RoundedCover {
                        required property int index
                        readonly property var cover: index < root.displayCovers.length
                                                     ? root.displayCovers[index] : ({})
                        width: Math.floor((root.coverSide - Math.round(3 * Theme.uiScale)) / 2)
                        height: width
                        radius: Theme.radiusXS
                        source: cover.path !== undefined && root.coverRevision >= 0
                                ? CoverCache.coverUrlForTrack(cover.path, cover.albumId) : ""
                        fallbackIcon: "playlist"
                        fallbackIconSize: Theme.fontSizeL
                    }
                }
            }

            RoundedCover {
                anchors.fill: parent
                visible: root.displayCovers.length <= 1
                radius: Theme.radiusM
                source: root.displayCovers.length === 1 && root.coverRevision >= 0
                        ? CoverCache.coverUrlForTrack(root.displayCovers[0].path,
                                                     root.displayCovers[0].albumId)
                        : ""
                fallbackIcon: "playlist"
                fallbackIconSize: Math.round(root.coverSide * 0.22)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS

            Text {
                Layout.fillWidth: true
                text: root.showingCollection ? root.selectedCollection.name : qsTr("Suas coleções")
                maximumLineCount: 2
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: root.compact ? Theme.fontSizeXL : Theme.fontSizeXXL
                font.weight: Theme.fontWeightBold
                font.letterSpacing: Theme.letterSpacingTitle
                                    * (root.compact ? Theme.fontSizeXL : Theme.fontSizeXXL)
                color: Theme.cTitle
            }

            Text {
                Layout.fillWidth: true
                text: root.showingCollection
                      ? root.statsFor(root.selectedCollection)
                      : root.items.length + qsTr(" coleções · ")
                        + root.totalTracks + qsTr(" faixas")
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                color: Theme.cSecondary
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.marginM

                Rectangle {
                    Layout.preferredWidth: Math.round(36 * Theme.uiScale)
                    Layout.preferredHeight: Math.round(36 * Theme.uiScale)
                    visible: root.showingCollection && root.selectedCollection.count > 0
                    radius: width / 2
                    color: Theme.cTitle

                    Text {
                        anchors.centerIn: parent
                        text: Icons.get("play")
                        font.family: Icons.fontFamily
                        font.pixelSize: Theme.fontSizeL
                        color: Theme.cBase
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.playRequested(false)
                    }
                }

                IconButton {
                    visible: root.showingCollection && root.selectedCollection.count > 0
                    icon: "shuffle"
                    size: Theme.fontSizeL
                    tooltip: qsTr("tocar embaralhado")
                    onClicked: root.playRequested(true)
                }

                MelodariumButton {
                    visible: !root.showingCollection
                    text: qsTr("Nova coleção")
                    onClicked: root.createRequested()
                }

                Item { Layout.fillWidth: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderS
            color: Theme.cLine
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("COLEÇÕES")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXXS
            font.weight: Theme.fontWeightSemiBold
            font.letterSpacing: Theme.letterSpacingLabel * Theme.fontSizeXXS
            color: Theme.cFaint
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS

            Repeater {
                model: root.items.slice(0, root.compact ? 2 : 3)

                Rectangle {
                    id: collectionRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Math.round(38 * Theme.uiScale)
                    radius: Theme.radiusXS
                    color: collectionArea.containsMouse
                           || root.selectedCollectionId === collectionRow.modelData.id
                           ? Theme.cPill : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.marginM
                        anchors.rightMargin: Theme.marginM
                        spacing: Theme.marginM

                        Text {
                            text: Icons.get("playlist")
                            font.family: Icons.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            color: root.selectedCollectionId === collectionRow.modelData.id
                                   ? Theme.cTitle : Theme.cMuted
                        }
                        Text {
                            Layout.fillWidth: true
                            text: collectionRow.modelData.name
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeM
                            color: Theme.cBody
                        }
                        Text {
                            text: collectionRow.modelData.count
                            font.family: Theme.fontFamilyFixed
                            font.pixelSize: Theme.fontSizeXS
                            color: Theme.cFaint
                        }
                    }

                    MouseArea {
                        id: collectionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openRequested(collectionRow.modelData.id,
                                                      collectionRow.modelData.name)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.items.length === 0
            text: qsTr("Crie uma coleção e transforme faixas soltas em um lugar com intenção.")
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            color: Theme.cMuted
        }

        Item { Layout.fillHeight: true }
    }
}
