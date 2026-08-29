pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodarium.App

// A fila inteira, por cima da tela. Mesma moldura do overlay de busca de propósito: os dois são
// "espiadas" sobre o que está na tela, não lugares onde se mora — e o app não pode ter duas
// gramáticas de painel flutuante.
//
// Por que existe: a tirinha do pé da lista mostra QUATRO capas e um "+8". Doze faixas
// enfileiradas, quatro visíveis, e nenhum jeito de ver o resto — o "+N" era a própria confissão
// de que faltava lugar. Aqui a fila aparece inteira e um clique pula para qualquer faixa.
//
// O que ele NÃO faz: tirar da fila e reordenar. O motor não tem esses dois verbos (só
// `loadPlaylist`, `appendToQueue` e `upcoming`), e inventá-los é mudança em C++ que esta fatia
// não abre.
Popup {
    id: root

    signal entryActivated(int queueIndex)

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    // Escala com a interface, como todos os outros diálogos do app: os números do desenho valem
    // para a janela do desenho (1100x700), e presos ali eles viravam um cartão pequeno perdido
    // no meio de uma tela grande, onde todo o resto já tinha crescido 1,7x.
    width: Math.min(Math.round(660 * Theme.uiScale),
                    Overlay.overlay ? Overlay.overlay.width - Theme.marginXL * 2 : 660)
    height: Math.min(Math.round(520 * Theme.uiScale),
                     Overlay.overlay ? Overlay.overlay.height - Theme.marginXL * 2 : 520)
    padding: 0

    background: Rectangle {
        color: Theme.cRowAlt
        radius: Theme.radiusL
        border.width: Theme.borderS
        border.color: Theme.cLine
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.62)
    }

    // Abrir no que está tocando, e não no topo: numa fila de mil e duzentas, o começo da lista
    // não é o lugar de onde alguém quer olhar.
    onOpened: lista.positionViewAtIndex(Math.max(0, AudioEngine.playlistPos), ListView.Center)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.marginXL
            spacing: Theme.marginM

            Text {
                text: qsTr("Fila")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXL
                font.weight: Theme.fontWeightSemiBold
                font.letterSpacing: Theme.letterSpacingHeading * Theme.fontSizeXL
                color: Theme.cTitle
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: AudioEngine.queueCount + qsTr(" faixas")
                font.family: Theme.fontFamilyFixed
                font.pixelSize: Theme.fontSizeS
                color: Theme.cFaint
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: AudioEngine.playlistPos >= 0 && AudioEngine.queueCount > 0
                text: qsTr("tocando a %1ª").arg(AudioEngine.playlistPos + 1)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                color: Theme.cMuted
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.borderS
            color: Theme.cRaised
        }

        ListView {
            id: lista
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Theme.marginL
            Layout.leftMargin: Theme.marginS
            Layout.rightMargin: Theme.marginS
            clip: true
            spacing: Theme.marginXXS
            cacheBuffer: 400
            boundsBehavior: Flickable.StopAtBounds
            // A fila é do motor: uma cópia local envelheceria na primeira faixa que terminasse.
            model: AudioEngine.queue

            delegate: Rectangle {
                id: linha

                required property string modelData
                required property int index

                // Uma consulta por linha VISÍVEL, não por faixa da fila: o ListView só constrói
                // o que cabe na tela, e uma fila de mil e duzentas abriria mil e duzentas
                // consultas se os metadados fossem levantados de uma vez.
                readonly property var info: LibraryBrowser.trackForPath(linha.modelData)
                readonly property bool atual: linha.index === AudioEngine.playlistPos
                readonly property bool jaTocou: linha.index < AudioEngine.playlistPos

                width: ListView.view.width
                height: Math.round(48 * Theme.uiScale)
                radius: Theme.iRadiusS
                color: area.containsMouse
                       ? Theme.cPill
                       : (linha.atual ? Theme.cRowCurrent : "transparent")
                opacity: linha.jaTocou && !area.containsMouse ? 0.45 : 1.0

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginL
                    anchors.rightMargin: Theme.marginL
                    spacing: Theme.marginL

                    // O número da posição some na que toca, como na lista da biblioteca: o
                    // triângulo é a marca de estado, e as duas juntas competiriam.
                    Item {
                        Layout.preferredWidth: Math.round(22 * Theme.uiScale)
                        Layout.fillHeight: true

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: linha.atual ? Icons.get("play") : String(linha.index + 1)
                            font.family: linha.atual ? Icons.fontFamily : Theme.fontFamilyFixed
                            font.pixelSize: linha.atual ? Theme.fontSizeXS : Theme.fontSizeS
                            color: linha.atual ? Theme.cStrong : Theme.cFaint
                        }
                    }

                    RoundedCover {
                        Layout.preferredWidth: Math.round(34 * Theme.uiScale)
                        Layout.preferredHeight: Math.round(34 * Theme.uiScale)
                        radius: Theme.radiusXS
                        fallbackIconSize: Theme.fontSizeM
                        source: CoverCache.coverUrlForTrack(
                                    linha.modelData,
                                    linha.info.albumId !== undefined ? linha.info.albumId : 0)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: linha.info.title !== undefined && linha.info.title !== ""
                                  ? linha.info.title : linha.modelData
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeM
                            font.weight: linha.atual ? Theme.fontWeightSemiBold
                                                     : Theme.fontWeightRegular
                            color: linha.atual ? Theme.cTitle : Theme.cBody
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: [linha.info.artist !== undefined ? linha.info.artist : "",
                                   linha.info.album !== undefined ? linha.info.album : ""]
                                  .filter(function (p) { return p !== "" }).join(" · ")
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            color: linha.atual ? Theme.cSecondary : Theme.cMuted
                        }
                    }

                    Text {
                        visible: linha.jaTocou
                        text: qsTr("já tocou")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.cFaint
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.entryActivated(linha.index)
                        root.close()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: lista.count === 0
                text: qsTr("a fila está vazia")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.cFaint
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.borderS
            color: Theme.cRaised
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.marginL
            Layout.leftMargin: Theme.marginXL
            Layout.rightMargin: Theme.marginXL
            spacing: Theme.marginS

            Text {
                text: qsTr("clique para pular para a faixa")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                color: Theme.cFaint
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "esc"
                font.pixelSize: Theme.fontSizeS
                color: Theme.cMuted
            }
            Text {
                text: qsTr("fechar")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                color: Theme.cFaint
            }
        }
    }
}
