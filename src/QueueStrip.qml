pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodia.App

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
        // O QML só rastreia LEITURA DE PROPRIEDADE. Uma chamada de método sozinha não cria
        // dependência nenhuma, e esta ligação valeria para sempre o que valia ao nascer —
        // uma tirinha congelada na fila vazia da abertura do app. Tocar em queueCount e
        // playlistPos aqui é o que a faz recalcular quando a fila anda.
        void AudioEngine.queueCount
        void AudioEngine.playlistPos
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
                text: qsTr("A seguir na fila")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXS
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurfaceVariant
            }
            Text {
                text: AudioEngine.queueCount + qsTr(" na fila")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOutline
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS

            Repeater {
                model: root.proximos

                Rectangle {
                    id: quadro

                    required property string modelData
                    required property int index

                    readonly property int lado: Math.round(62 * Theme.uiScale)

                    Layout.preferredWidth: quadro.lado
                    Layout.preferredHeight: quadro.lado
                    radius: Theme.radiusXS
                    color: Theme.mSurfaceVariant
                    clip: true
                    border.width: capaArea.containsMouse ? Theme.borderS : 0
                    border.color: Theme.mTertiary

                    Image {
                        id: capa
                        anchors.fill: parent
                        // O segundo argumento é ignorado pela implementação (a capa sai do
                        // caminho do arquivo). Passar 0 evita uma consulta por quadradinho.
                        source: CoverCache.coverUrlForTrack(quadro.modelData, 0)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: capa.status === Image.Ready
                        sourceSize.width: quadro.lado
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: capa.status !== Image.Ready
                        text: Icons.get("music")
                        font.family: Icons.fontFamily
                        font.pointSize: Theme.fontSizeL
                        color: Theme.mOutline
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
                radius: Theme.radiusXS
                color: "transparent"
                border.width: Theme.borderS
                border.color: Theme.mSurfaceVariant

                Text {
                    anchors.centerIn: parent
                    text: "+" + root.restantes
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeS
                    color: Theme.mOnSurfaceVariant
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
