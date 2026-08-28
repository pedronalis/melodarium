import QtQuick
import QtQuick.Layouts
import Melodia.App

// The honest limit, written where the user reads it. A desktop app does not run with its
// window closed, so "baixa sozinho" without this sentence would be a promise the app cannot
// keep. The feed-rss plan makes this wording part of the deliverable, not decoration.
ColumnLayout {
    id: root

    property int showId: 0
    property double lastCheckedAt: 0
    property bool showActions: true

    spacing: Theme.marginXXS

    function formatLastChecked(secs) {
        if (secs <= 0)
            return qsTr("ainda não verificado")
        return qsTr("verificado em %1").arg(
                   new Date(secs * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat))
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.marginS
        visible: root.showActions

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: PodcastLibrary.checkingFeeds
                  ? qsTr("verificando…")
                  : root.formatLastChecked(root.lastCheckedAt)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXS
            color: Theme.cMuted
        }

        IconButton {
            icon: "history"
            size: Theme.fontSizeS
            enabled: !PodcastLibrary.checkingFeeds && root.showId > 0
            onClicked: PodcastLibrary.checkFeed(root.showId)
        }
    }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Verifica novos episódios enquanto o melodia está aberto.")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeXS
        color: Theme.cMuted
    }
}
