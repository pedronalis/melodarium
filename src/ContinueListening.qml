pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodia.App

// The top of the podcast tab, and the whole reason podcast is not music: the spec says
// "podcast quer o oposto de música: retomar posição, não embaralhar".
ColumnLayout {
    id: root

    property var entries: []

    signal episodeChosen(int episodeId)

    spacing: Theme.marginS
    visible: root.entries.length > 0

    function refresh() {
        root.entries = PodcastLibrary.continueListening()
    }

    Component.onCompleted: refresh()

    Connections {
        target: PodcastLibrary
        function onEpisodesChanged(showId) { root.refresh() }
        function onShowsChanged() { root.refresh() }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.marginM
        text: qsTr("Continuar ouvindo")
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeS
        font.weight: Theme.fontWeightSemiBold
        color: Theme.mOnSurfaceVariant
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.marginXL * 4.5
        Layout.leftMargin: Theme.marginS
        Layout.rightMargin: Theme.marginS
        orientation: ListView.Horizontal
        spacing: Theme.marginS
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.entries

        delegate: Rectangle {
            id: card

            required property var modelData

            width: 240
            height: ListView.view.height
            radius: Theme.radiusS
            color: cardMouse.containsMouse ? Theme.mHover : Theme.mSurface
            border.width: Theme.borderS
            border.color: Theme.mOutline

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.marginM
                spacing: Theme.marginXXS

                Text {
                    Layout.fillWidth: true
                    text: card.modelData.showTitle
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeXS
                    color: Theme.mOnSurfaceVariant
                }
                Text {
                    Layout.fillWidth: true
                    text: card.modelData.title
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeM
                    font.weight: Theme.fontWeightMedium
                    color: cardMouse.containsMouse ? Theme.mOnHover : Theme.mOnSurface
                }

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("faltam %1 min").arg(
                              Math.max(0, Math.round((card.modelData.durationMs
                                                      - card.modelData.positionMs) / 60000)))
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeXS
                    color: Theme.mOnSurfaceVariant
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.borderL
                    radius: height / 2
                    color: Theme.mSurfaceVariant

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * card.modelData.progress
                        color: Theme.mPrimary
                    }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.episodeChosen(card.modelData.id)
            }
        }
    }
}
