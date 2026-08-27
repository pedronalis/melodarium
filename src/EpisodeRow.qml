import QtQuick
import QtQuick.Layouts
import Melodia.App

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

    implicitHeight: 58

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
        color: mouse.containsMouse ? Theme.mHover
                                   : (root.isCurrent ? Theme.mSurfaceVariant : "transparent")

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
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: Theme.radiusXS
                color: Theme.mSurfaceVariant

                Text {
                    anchors.centerIn: parent
                    text: Icons.get(root.played ? "playlist" : "microphone")
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeM
                    color: Theme.mOnSurfaceVariant
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
                    font.pointSize: Theme.fontSizeM
                    font.weight: root.isCurrent ? Theme.fontWeightSemiBold
                                                : Theme.fontWeightMedium
                    color: mouse.containsMouse
                           ? Theme.mOnHover
                           : (root.isCurrent ? Theme.mOnSurface : Theme.mOnSurfaceVariant)
                }
                Text {
                    Layout.fillWidth: true
                    text: [root.showTitle, root.formatDate(root.publishedAt),
                           root.formatLength(root.durationMs)]
                          .filter(function (p) { return p !== "" }).join(" · ")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: mouse.containsMouse ? Theme.mOnHover : Theme.mOutline
                }
            }

            // Um episódio começado mostra a barra; um que falta baixar mostra a seta; um já
            // ouvido só diz que foi. Nunca os três juntos.
            Rectangle {
                Layout.preferredWidth: 62
                Layout.preferredHeight: 3
                visible: root.downloadProgress < 0 && !root.played && root.progress > 0
                radius: height / 2
                color: Theme.mSurfaceVariant

                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.mOnSurfaceVariant
                }
            }

            Text {
                visible: root.downloadProgress >= 0
                text: root.downloadSizeKnown
                      ? Math.round(root.downloadProgress * 100) + "%"
                      : qsTr("baixando…")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOnSurfaceVariant
            }

            IconButton {
                Layout.preferredWidth: 22
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
                font.pointSize: Theme.fontSizeXS
                font.letterSpacing: 0.6
                color: Theme.mOutline
            }

            // Marcar ouvido à mão é o gesto que o app não consegue inferir — e o único jeito
            // de desfazer um "ouvido" que ele inferiu errado.
            IconButton {
                Layout.preferredWidth: 22
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
