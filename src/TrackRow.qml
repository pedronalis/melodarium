import QtQuick
import QtQuick.Layouts
import Melodia.App

// Uma linha da lista densa do desenho aprovado (design/Biblioteca.dc.html): número, título
// com o artista embaixo, álbum, curtir e duração. Sem miniatura de capa por linha — a capa
// grande do painel é a arte da tela, e repeti-la 1.200 vezes rouba a densidade que o desenho
// pede.
Item {
    id: root

    property string title: ""
    property string artist: ""
    property string album: ""
    property int durationMs: 0
    property string coverUrl: ""
    property bool isCurrent: false
    property int trackId: 0
    property bool showCollectButton: false
    property bool liked: false
    // Posição na lista, não o número da faixa no álbum: a lista é uma fila, e é a ordem dela
    // que o usuário vê.
    property int position: 0
    // Zebra: uma listra a cada duas linhas guia o olho por linhas largas sem desenhar grade.
    property bool alternate: false
    // "local_file" or "youtube". The badge is how the spec's honest limit reaches the eye:
    // compressed audio lives next to the real files without passing for one.
    property string sourceKind: "local_file"

    signal activated
    signal collectRequested
    signal likeToggled

    implicitHeight: Math.round(38 * Theme.uiScale)

    function formatDuration(ms) {
        if (ms <= 0)
            return "--:--"
        const total = Math.floor(ms / 1000)
        const minutes = Math.floor(total / 60)
        const seconds = total % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginXS
        anchors.rightMargin: Theme.marginXS
        radius: Theme.radiusXS
        color: mouse.containsMouse
               ? Theme.mHover
               : (root.isCurrent ? Theme.mSurfaceVariant
                                 : (root.alternate ? Qt.rgba(Theme.mSurfaceVariant.r,
                                                             Theme.mSurfaceVariant.g,
                                                             Theme.mSurfaceVariant.b, 0.45)
                                                   : "transparent"))

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        // Declared before the row content on purpose: the collect button sits inside the
        // RowLayout and has to receive its own clicks, which a MouseArea stacked on top
        // of it would swallow.
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

            // A faixa que toca troca o número por um triângulo: é a única marca de estado que
            // a lista precisa.
            Item {
                Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                Layout.fillHeight: true

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isCurrent ? Icons.get("play")
                                         : (root.position > 0 ? String(root.position) : "")
                    font.family: root.isCurrent ? Icons.fontFamily : Theme.fontFamilyFixed
                    font.pointSize: root.isCurrent ? Theme.fontSizeXS : Theme.fontSizeS
                    color: mouse.containsMouse
                           ? Theme.mOnHover
                           : (root.isCurrent ? Theme.mPrimary : Theme.mOutline)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeM
                    font.weight: root.isCurrent ? Theme.fontWeightSemiBold
                                                : Theme.fontWeightRegular
                    color: mouse.containsMouse ? Theme.mOnHover
                                               : (root.isCurrent ? Theme.mOnSurface
                                                                 : Theme.mOnSurfaceVariant)
                }
                Text {
                    Layout.fillWidth: true
                    text: root.artist
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: mouse.containsMouse ? Theme.mOnHover : Theme.mOutline
                }
            }

            Text {
                // Elástica em vez de fixa: numa janela larga sobra espaço de sobra e o nome do
                // álbum ficava cortado em "Brick City ..." com metade da tela vazia ao lado.
                Layout.fillWidth: true
                Layout.preferredWidth: Math.round(132 * Theme.uiScale)
                Layout.maximumWidth: Math.round(320 * Theme.uiScale)
                horizontalAlignment: Text.AlignRight
                visible: root.width > Math.round(420 * Theme.uiScale)
                text: root.album
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: mouse.containsMouse ? Theme.mOnHover : Theme.mOutline
            }

            SourceBadge {
                kind: root.sourceKind
            }

            // The one manual gesture of the whole product. Always visible when enabled —
            // a control that only appears on hover is a control the user never finds.
            IconButton {
                Layout.preferredWidth: Math.round(18 * Theme.uiScale)
                Layout.preferredHeight: 18
                icon: "plus"
                size: Theme.fontSizeS
                visible: root.showCollectButton
                opacity: mouse.containsMouse ? 1.0 : 0.35
                onClicked: root.collectRequested()

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }
            }

            // Curtir mora na linha, não num menu: o coração apagado é discreto o bastante para
            // não competir com o título, e presente o bastante para ser achado sem hover.
            Item {
                Layout.preferredWidth: Math.round(16 * Theme.uiScale)
                Layout.fillHeight: true

                Text {
                    id: heart
                    anchors.centerIn: parent
                    text: root.liked ? Icons.get("heart-filled") : Icons.get("heart")
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: root.liked ? Theme.mPrimary
                                      : (mouse.containsMouse ? Theme.mOnHover : Theme.mOutline)
                    opacity: root.liked ? 1.0 : (heartArea.containsMouse ? 0.9 : 0.45)

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                    }
                }

                MouseArea {
                    id: heartArea
                    anchors.fill: parent
                    anchors.margins: -Theme.marginXS
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.likeToggled()
                }
            }

            Text {
                Layout.preferredWidth: Math.round(46 * Theme.uiScale)
                horizontalAlignment: Text.AlignRight
                text: root.formatDuration(root.durationMs)
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeS
                color: mouse.containsMouse ? Theme.mOnHover : Theme.mOutline
            }
        }
    }
}
