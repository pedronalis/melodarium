import QtQuick
import QtQuick.Layouts
import Melodarium.App

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
    // "plus" in the library (put into a collection), "close" inside a collection (take it
    // out of this one).
    property string collectGlyph: "plus"
    property bool liked: false
    // Posição na lista, não o número da faixa no álbum: a lista é uma fila, e é a ordem dela
    // que o usuário vê.
    property int position: 0
    // Zebra: uma listra a cada duas linhas guia o olho por linhas largas sem desenhar grade.
    property bool alternate: false
    // Arrastar só faz sentido onde a ordem é do usuário: dentro de uma coleção. Na biblioteca
    // a ordem vem da consulta, e uma alça lá prometeria uma gravação que não existe.
    property bool draggable: false
    // "local_file" or "youtube". The badge is how the spec's honest limit reaches the eye:
    // compressed audio lives next to the real files without passing for one.
    property string sourceKind: "local_file"

    signal activated
    signal collectRequested
    signal likeToggled

    implicitHeight: Math.round(34 * Theme.uiScale)

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
        // Os três estados do desenho são três tons vizinhos, e não um só com transparência:
        // a listra é quase invisível de propósito (só guia o olho na linha larga), a faixa
        // tocando é um degrau acima dela, e o hover é o degrau seguinte. Colapsados no mesmo
        // `mSurfaceVariant`, a lista virava um teclado de piano.
        color: mouse.containsMouse
               ? Theme.cPill
               : (root.isCurrent ? Theme.cRowCurrent
                                 : (root.alternate ? Theme.cRowAlt : "transparent"))

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

            // Seis pontos: o desenho universal de "isto se arrasta". Some sem hover para não
            // competir com o número na lista em repouso.
            Text {
                Layout.preferredWidth: root.draggable ? Math.round(12 * Theme.uiScale) : 0
                visible: root.draggable
                opacity: mouse.containsMouse ? 0.9 : 0.25
                text: "⠿"
                font.pixelSize: Theme.fontSizeM
                color: Theme.cMuted

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }
            }

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
                    font.pixelSize: root.isCurrent ? Theme.fontSizeXS : Theme.fontSizeS
                    color: root.isCurrent ? Theme.cStrong : Theme.cFaint
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
                    font.pixelSize: Theme.fontSizeM
                    font.weight: root.isCurrent ? Theme.fontWeightSemiBold
                                                : Theme.fontWeightRegular
                    color: root.isCurrent ? Theme.cTitle : Theme.cBody
                }
                Text {
                    Layout.fillWidth: true
                    text: root.artist
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: root.isCurrent ? Theme.cSecondary : Theme.cMuted
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
                font.pixelSize: Theme.fontSizeS
                color: Theme.cDim
            }

            SourceBadge {
                kind: root.sourceKind
            }

            // The one manual gesture of the whole product. Always visible when enabled —
            // a control that only appears on hover is a control the user never finds.
            IconButton {
                Layout.preferredWidth: Math.round(18 * Theme.uiScale)
                Layout.preferredHeight: 18
                icon: root.collectGlyph
                size: Theme.fontSizeS
                visible: root.showCollectButton
                opacity: mouse.containsMouse ? 1.0 : 0.35
                onClicked: root.collectRequested()

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }
            }

            // Curtir mora na linha, não num menu: o coração apagado é discreto o bastante
            // para não competir com o título, e presente o bastante para ser achado sem hover.
            Item {
                Layout.preferredWidth: Math.round(16 * Theme.uiScale)
                Layout.fillHeight: true

                Text {
                    id: heart

                    anchors.centerIn: parent
                    text: root.liked ? Icons.get("heart-filled") : Icons.get("heart")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: root.liked ? Theme.cStrong : Theme.cGhost
                    opacity: root.liked ? 1.0 : (heartArea.containsMouse ? 0.9 : 0.45)

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                    }

                    // Sobe passando do alvo e volta: OutBack devolve o excesso, e é esse
                    // excesso que separa "confirmei seu clique" de "comemorei com você".
                    SequentialAnimation {
                        id: puloDoCoracao

                        NumberAnimation {
                            target: heart
                            property: "scale"
                            to: Theme.popEscala
                            duration: Theme.animationPop
                            easing.type: Easing.OutBack
                            easing.overshoot: Theme.popOvershoot
                        }
                        NumberAnimation {
                            target: heart
                            property: "scale"
                            to: 1.0
                            duration: Theme.animationPopBack
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: heartArea
                    anchors.fill: parent
                    anchors.margins: -Theme.marginXS
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // `root.liked` ainda é o valor ANTIGO aqui: se era falso, este clique
                        // vai curtir, e é só aí que se comemora. E o disparo sai do clique,
                        // nunca de `onLikedChanged`: a ListView recicla o delegate ao rolar, e
                        // uma faixa já curtida entrando na tela faria a lista inteira pular.
                        if (!root.liked)
                            puloDoCoracao.restart()
                        root.likeToggled()
                    }
                }
            }

            Text {
                Layout.preferredWidth: Math.round(46 * Theme.uiScale)
                horizontalAlignment: Text.AlignRight
                text: root.formatDuration(root.durationMs)
                font.family: Theme.fontFamilyFixed
                font.pixelSize: Theme.fontSizeS
                color: Theme.cMuted
            }
        }
    }
}
