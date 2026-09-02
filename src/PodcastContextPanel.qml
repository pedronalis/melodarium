pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodarium.App

// A aba de Podcast fala de programas e continuidade. Música pode continuar tocando no rodapé,
// mas não toma esta coluna emprestada enquanto o usuário escolhe o que ouvir depois.
Rectangle {
    id: root

    property bool compact: false
    property int selectedShowId: 0
    property var shows: []
    property var continuing: []

    signal showRequested(int showId)

    readonly property int coverSide: root.compact
        ? Math.round(176 * Theme.uiScale) : Math.round(244 * Theme.uiScale)
    readonly property var selectedShow: {
        for (let i = 0; i < root.shows.length; ++i) {
            if (root.shows[i].id === root.selectedShowId)
                return root.shows[i]
        }
        return ({})
    }
    readonly property var resumeEpisode: root.continuing.length > 0 ? root.continuing[0] : ({})
    readonly property bool showingShow: root.selectedShow.id !== undefined
    readonly property bool showingResume: !root.showingShow
                                           && root.resumeEpisode.id !== undefined
    readonly property string coverPath: root.showingShow
        ? (root.selectedShow.coverPath !== undefined ? root.selectedShow.coverPath : "")
        : (root.showingResume && root.resumeEpisode.coverPath !== undefined
           ? root.resumeEpisode.coverPath : "")
    readonly property int totalUnplayed: {
        let total = 0
        for (let i = 0; i < root.shows.length; ++i)
            total += root.shows[i].unplayedCount !== undefined ? root.shows[i].unplayedCount : 0
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
        root.shows = PodcastLibrary.shows()
        root.continuing = PodcastLibrary.continueListening(1)
    }

    function showMeta(show) {
        const episodes = show.episodeCount !== undefined ? show.episodeCount : 0
        const unplayed = show.unplayedCount !== undefined ? show.unplayedCount : 0
        return episodes + qsTr(" episódios") + " · " + unplayed + qsTr(" não ouvidos")
    }

    function retentionLabel(count) {
        if (count === undefined || count <= 0)
            return qsTr("Manter todos")
        return qsTr("Manter %1").arg(count)
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: PodcastLibrary
        function onShowsChanged() { root.refresh() }
        function onEpisodesChanged(showId) { root.refresh() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginXL + Theme.marginS
        spacing: Theme.marginL

        Text {
            Layout.fillWidth: true
            text: root.showingShow ? qsTr("PROGRAMA")
                                   : (root.showingResume ? qsTr("CONTINUAR OUVINDO")
                                                         : qsTr("SEUS PODCASTS"))
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXXS
            font.weight: Theme.fontWeightSemiBold
            font.letterSpacing: Theme.letterSpacingLabel * Theme.fontSizeXXS
            color: Theme.cFaint
        }

        RoundedCover {
            Layout.preferredWidth: root.coverSide
            Layout.preferredHeight: root.coverSide
            Layout.alignment: Qt.AlignHCenter
            radius: Theme.radiusM
            source: root.coverPath !== "" ? "file://" + root.coverPath : ""
            fallbackIcon: "microphone"
            fallbackIconSize: Math.round(root.coverSide * 0.22)
            placeholderTop: Theme.cCoverTopPod
            placeholderMid: Theme.cCoverMidPod
            fallbackIconColor: Theme.cCoverIconPod
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS

            Text {
                Layout.fillWidth: true
                text: root.showingShow
                      ? root.selectedShow.title
                      : (root.showingResume ? root.resumeEpisode.title : qsTr("Seus programas"))
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
                text: root.showingShow
                      ? root.showMeta(root.selectedShow)
                      : (root.showingResume
                         ? root.resumeEpisode.showTitle
                         : root.shows.length + qsTr(" programas · ")
                           + root.totalUnplayed + qsTr(" não ouvidos"))
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                color: Theme.cSecondary
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(3 * Theme.uiScale)
                visible: root.showingResume
                radius: Theme.radiusTrack
                color: Theme.cLine

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1,
                        root.resumeEpisode.progress !== undefined ? root.resumeEpisode.progress : 0))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.cStrong
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showingResume || root.showingShow

                MelodariumButton {
                    visible: root.showingResume
                    text: qsTr("Continuar")
                    onClicked: PodcastLibrary.playEpisode(root.resumeEpisode.id)
                }

                MelodariumButton {
                    visible: root.showingShow
                    text: qsTr("Todos os programas")
                    outlined: true
                    onClicked: root.showRequested(0)
                }

                Item { Layout.fillWidth: true }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.showingShow && root.selectedShow.feedUrl !== ""
                spacing: Theme.marginXS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.marginXS

                    MelodariumButton {
                        text: root.selectedShow.autoDownload
                              ? qsTr("Baixar novos: sim") : qsTr("Baixar novos: não")
                        outlined: !root.selectedShow.autoDownload
                        accessibleName: qsTr("Alternar download automático de novos episódios")
                        onClicked: PodcastLibrary.setFeedPolicy(
                            root.selectedShow.id, !root.selectedShow.autoDownload,
                            root.selectedShow.retentionCount)
                    }

                    MelodariumButton {
                        id: retentionButton
                        text: root.retentionLabel(root.selectedShow.retentionCount)
                        outlined: true
                        accessibleName: qsTr("Escolher retenção de downloads")
                        onClicked: retentionMenu.popup(retentionButton, 0,
                                                       retentionButton.height + Theme.marginXS)
                    }

                    Item { Layout.fillWidth: true }
                }

                MelodariumButton {
                    text: qsTr("Deixar de seguir")
                    outlined: true
                    accessibleName: qsTr("Deixar de seguir este podcast")
                    onClicked: unsubscribeDialog.openForShow(root.selectedShow.id,
                                                              root.selectedShow.title)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderS
            color: Theme.cLine
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("PROGRAMAS")
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
                model: root.shows.slice(0, root.compact ? 2 : 3)

                Rectangle {
                    id: showRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Math.round(38 * Theme.uiScale)
                    radius: Theme.radiusXS
                    color: showArea.containsMouse || root.selectedShowId === showRow.modelData.id
                           ? Theme.cPill : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.marginM
                        anchors.rightMargin: Theme.marginM
                        spacing: Theme.marginM

                        Text {
                            text: Icons.get("rss")
                            font.family: Icons.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            color: root.selectedShowId === showRow.modelData.id
                                   ? Theme.cTitle : Theme.cMuted
                        }
                        Text {
                            Layout.fillWidth: true
                            text: showRow.modelData.title
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeM
                            color: Theme.cBody
                        }
                        Text {
                            text: showRow.modelData.unplayedCount
                            font.family: Theme.fontFamilyFixed
                            font.pixelSize: Theme.fontSizeXS
                            color: Theme.cFaint
                        }
                    }

                    MouseArea {
                        id: showArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showRequested(showRow.modelData.id)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.shows.length === 0
            text: qsTr("Assine um feed ou escolha uma pasta para começar sua estante de podcasts.")
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            color: Theme.cMuted
        }

        Item { Layout.fillHeight: true }
    }

    MelodariumMenu {
        id: retentionMenu

        function apply(count) {
            PodcastLibrary.setFeedPolicy(root.selectedShow.id,
                                         root.selectedShow.autoDownload, count)
        }

        MelodariumMenuItem { text: qsTr("Manter todos"); onTriggered: retentionMenu.apply(0) }
        MelodariumMenuItem { text: qsTr("Manter os 3 mais recentes"); onTriggered: retentionMenu.apply(3) }
        MelodariumMenuItem { text: qsTr("Manter os 5 mais recentes"); onTriggered: retentionMenu.apply(5) }
        MelodariumMenuItem { text: qsTr("Manter os 10 mais recentes"); onTriggered: retentionMenu.apply(10) }
    }

    UnsubscribeDialog {
        id: unsubscribeDialog
        onUnsubscribed: root.showRequested(0)
    }
}
