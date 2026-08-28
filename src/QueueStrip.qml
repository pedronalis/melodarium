pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodarium.App

// "A seguir na fila": o rótulo, quatro capas pequenas e o quadradinho "+N" com quantas
// faltam (design/Main.dc.html:141-152). Mora no pé da coluna do meio, não no painel da
// capa — no desenho ele é o pé da LISTA.
Item {
    id: root

    property int lookahead: 4

    signal entryActivated(int queueIndex)

    // Some inteira quando não há próximos: uma tirinha vazia rouba altura da lista, que é o
    // ponto da tela.
    readonly property var proximos: {
        // O QML só rastreia LEITURA DE PROPRIEDADE, e uma chamada de método invocável não
        // cria dependência nenhuma: sem as duas leituras abaixo esta ligação valeria para
        // sempre o que valia ao nascer — uma tirinha congelada na fila vazia da abertura do
        // app. As leituras têm de ser USADAS, não descartadas: uma expressão sem efeito é
        // eliminada pelo compilador e a dependência vai junto.
        const total = AudioEngine.queueCount
        const pos = AudioEngine.playlistPos
        if (total <= 0 || pos + 1 >= total)
            return []
        return AudioEngine.upcoming(root.lookahead)
    }

    readonly property int restantes: Math.max(0, AudioEngine.queueCount
                                                 - (AudioEngine.playlistPos < 0
                                                    ? 0 : AudioEngine.playlistPos + 1)
                                                 - root.proximos.length)

    visible: root.proximos.length > 0
    implicitHeight: root.visible ? coluna.implicitHeight : 0

    ColumnLayout {
        id: coluna
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.marginS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS

            Text {
                // Caixa alta, letra apertada e o tom mais apagado da escada: no desenho este
                // rótulo é uma etiqueta de seção, não uma frase que compete com a lista.
                text: qsTr("A seguir na fila").toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXXS
                font.weight: Theme.fontWeightBold
                font.letterSpacing: Theme.letterSpacingLabel * Theme.fontSizeXXS
                color: Theme.cFaint
            }
            Text {
                text: AudioEngine.queueCount + qsTr(" na fila")
                font.family: Theme.fontFamilyFixed
                font.pixelSize: Theme.fontSizeXS
                color: Theme.cFaint
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS

            Repeater {
                model: root.proximos

                Item {
                    id: quadro

                    required property string modelData
                    required property int index

                    readonly property int lado: Math.round(62 * Theme.uiScale)

                    Layout.preferredWidth: quadro.lado
                    Layout.preferredHeight: quadro.lado

                    RoundedCover {
                        anchors.fill: parent
                        radius: Theme.radiusS
                        fallbackIconSize: Theme.fontSizeL
                        // O segundo argumento é ignorado pela implementação (a capa sai do
                        // caminho do arquivo). Passar 0 evita uma consulta por quadradinho.
                        source: CoverCache.coverUrlForTrack(quadro.modelData, 0)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusS
                        color: "transparent"
                        border.width: capaArea.containsMouse ? Theme.borderS : 0
                        border.color: Theme.cTitle
                    }

                    MouseArea {
                        id: capaArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // O índice na fila, não na tirinha: a tirinha começa depois do que
                        // está tocando.
                        onClicked: root.entryActivated(AudioEngine.playlistPos + 1 + quadro.index)
                    }
                }
            }

            // "+2": quantas faltam além das que couberam na tirinha.
            Rectangle {
                readonly property int lado: Math.round(62 * Theme.uiScale)

                Layout.preferredWidth: lado
                Layout.preferredHeight: lado
                visible: root.restantes > 0
                radius: Theme.radiusS
                color: "transparent"
                border.width: Theme.borderS
                border.color: Theme.cLine

                Text {
                    anchors.centerIn: parent
                    text: "+" + root.restantes
                    font.family: Theme.fontFamilyFixed
                    font.pixelSize: Theme.fontSizeXS
                    color: Theme.cFaint
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
