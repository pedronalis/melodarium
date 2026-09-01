import QtQuick
import QtQuick.Layouts
import Melodarium.App

// Uma linha da lista de episódios do desenho aprovado (design/Podcast.dc.html): arte, título
// com "programa · data · duração" embaixo e, à direita, a única informação que muda de
// episódio para episódio — quanto falta, se precisa baixar, ou se já foi ouvido.
Item {
    id: root

    property string title: ""
    property string showTitle: ""
    property int durationMs: 0
    property int positionMs: 0
    property bool played: false
    property bool isCurrent: false
    property int episodeId: 0
    property double publishedAt: 0
    // Not on disk yet: the episode came from a feed and still lives on the server.
    property bool downloadable: false
    // -1 when idle, 0..1 while downloading. The server does not always declare a size, so an
    // in-flight download with no known total shows movement without a percentage.
    property real downloadProgress: -1
    property bool downloadSizeKnown: true

    readonly property real progress: durationMs > 0
                                     ? Math.min(1.0, positionMs / durationMs)
                                     : 0.0

    signal activated
    signal playedToggled
    signal downloadRequested

    implicitHeight: Math.round(58 * Theme.uiScale)
    activeFocusOnTab: enabled && visible

    Accessible.role: Accessible.ListItem
    Accessible.name: root.showTitle !== "" ? root.title + ", " + root.showTitle : root.title
    Accessible.description: root.formatLength(root.durationMs)
    Accessible.focusable: enabled && visible
    Accessible.onPressAction: root.activated()

    Keys.onSpacePressed: function(event) {
        root.activated()
        event.accepted = true
    }
    Keys.onReturnPressed: function(event) {
        root.activated()
        event.accepted = true
    }
    Keys.onEnterPressed: function(event) {
        root.activated()
        event.accepted = true
    }

    function formatLength(ms) {
        if (ms <= 0)
            return ""
        const minutes = Math.round(ms / 60000)
        if (minutes < 60)
            return minutes + qsTr(" min")
        return Math.floor(minutes / 60) + " h " + ("0" + (minutes % 60)).slice(-2)
    }

    function formatDate(secs) {
        if (secs <= 0)
            return ""
        return new Date(secs * 1000).toLocaleDateString(Qt.locale(), "dd MMM")
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginXS
        anchors.rightMargin: Theme.marginXS
        radius: Theme.iRadiusS
        color: mouse.containsMouse ? Theme.cPill
                                   : (root.isCurrent ? Theme.cRaised : "transparent")
        border.width: root.activeFocus ? Theme.borderM : 0
        border.color: Theme.cAccent

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.marginL
            anchors.rightMargin: Theme.marginL
            spacing: Theme.marginL

            Rectangle {
                Layout.preferredWidth: Math.round(40 * Theme.uiScale)
                Layout.preferredHeight: 40
                radius: Theme.radiusXS
                color: Theme.cRaised

                Text {
                    anchors.centerIn: parent
                    text: Icons.get(root.played ? "playlist" : "microphone")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeM
                    color: Theme.cMuted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.marginXXS

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
                    font.weight: root.isCurrent ? Theme.fontWeightSemiBold
                                                : Theme.fontWeightMedium
                    color: mouse.containsMouse
                           ? Theme.cTitle
                           : (root.isCurrent ? Theme.cTitle : Theme.cMuted)
                }
                Text {
                    Layout.fillWidth: true
                    text: [root.showTitle, root.formatDate(root.publishedAt),
                           root.formatLength(root.durationMs)]
                          .filter(function (p) { return p !== "" }).join(" · ")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: mouse.containsMouse ? Theme.cTitle : Theme.cFaint
                }
            }

            // Um episódio começado mostra a barra; um que falta baixar mostra a seta; um já
            // ouvido só diz que foi. Nunca os três juntos.
            Rectangle {
                Layout.preferredWidth: Math.round(62 * Theme.uiScale)
                Layout.preferredHeight: 3
                visible: root.downloadProgress < 0 && !root.played && root.progress > 0
                radius: height / 2
                color: Theme.cRaised

                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.cMuted
                }
            }

            Text {
                visible: root.downloadProgress >= 0
                text: root.downloadSizeKnown
                      ? Math.round(root.downloadProgress * 100) + "%"
                      : qsTr("baixando…")
                font.family: Theme.fontFamilyFixed
                font.pixelSize: Theme.fontSizeXS
                color: Theme.cMuted
            }

            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                icon: "download"
                size: Theme.fontSizeS
                visible: root.downloadable && root.downloadProgress < 0
                opacity: mouse.containsMouse ? 1.0 : 0.55
                tooltip: qsTr("baixar")
                onClicked: root.downloadRequested()

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }
            }

            Text {
                visible: root.played
                text: qsTr("ouvido")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXS
                font.letterSpacing: 0.6
                color: Theme.cFaint
            }

            // Marcar ouvido à mão é o gesto que o app não consegue inferir — e o único jeito
            // de desfazer um "ouvido" que ele inferiu errado.
            IconButton {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.preferredHeight: 22
                icon: "playlist"
                size: Theme.fontSizeS
                accent: root.played
                opacity: mouse.containsMouse ? 1.0 : 0.35
                tooltip: root.played ? qsTr("marcar como não ouvido") : qsTr("marcar como ouvido")
                onClicked: root.playedToggled()

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }
            }
        }
    }
}
