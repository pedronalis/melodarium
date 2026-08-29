import QtQuick
import QtQuick.Layouts
import Melodarium.App

Rectangle {
    id: root

    property string current: "library"

    signal chosen(string section)
    // Separado de `chosen` de propósito: ajustes abre POR CIMA da tela, não troca de tela.
    signal settingsRequested

    implicitWidth: Theme.railWidth
    color: "transparent"

    Rectangle {
        anchors.right: parent.right
        width: Theme.borderS
        height: parent.height
        color: Theme.cPanelTop
    }

    // A tira escolhe o MODO da tela; a fileira de chips do miolo escolhe o EIXO dentro da
    // biblioteca. Álbuns e Tags viviam aqui SEM navegar, repetindo palavras que os chips já
    // entregam — decisão do Pedro em 2026-08-28: saem daqui. A fatia colecoes-tela insere
    // "collections" como PRIMEIRO item; a fatia ajustes acrescenta "settings" no pé.
    readonly property var items: [
        { key: "collections", icon: "playlist",   tip: qsTr("Coleções") },
        { key: "library",     icon: "list",       tip: qsTr("Biblioteca") },
        { key: "podcast",     icon: "microphone", tip: qsTr("Podcast") },
        { key: "search",      icon: "search",     tip: qsTr("Buscar") }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.marginXL
        anchors.bottomMargin: Theme.marginXL
        spacing: Theme.marginS

        // Aqui havia a marca do app: uma nota musical do mesmo tamanho e da mesma cor dos ícones
        // apagados que SÃO botões — indistinguível de um botão desligado, e sem clique nenhum.
        // O Pedro perguntou "para que serve esse botão" em 2026-08-28, que é a prova do defeito.
        // Saiu: todo item deste trilho clica. Identidade de marca é assunto do ícone da janela.

        Repeater {
            model: root.items

            Rectangle {
                id: cell

                required property var modelData

                Layout.preferredWidth: Math.round(34 * Theme.uiScale)
                Layout.preferredHeight: Math.round(34 * Theme.uiScale)
                radius: Theme.iRadiusS
                color: root.current === cell.modelData.key
                       ? Theme.cPill
                       : (area.containsMouse ? Theme.cRaised : "transparent")
                opacity: root.current === cell.modelData.key || area.containsMouse ? 1.0 : 0.85

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.get(cell.modelData.icon)
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeL
                    color: root.current === cell.modelData.key ? Theme.cTitle : Theme.cDim
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chosen(cell.modelData.key)
                }
            }
        }

        // Empurra a engrenagem para o pé: ela não pertence à lista de modos.
        Item { Layout.fillHeight: true }

        Rectangle {
            id: engrenagem

            Layout.preferredWidth: Math.round(34 * Theme.uiScale)
            Layout.preferredHeight: Math.round(34 * Theme.uiScale)
            radius: Theme.iRadiusS
            color: engrenagemArea.containsMouse ? Theme.cRaised : "transparent"
            opacity: engrenagemArea.containsMouse ? 1.0 : 0.7

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }

            Text {
                anchors.centerIn: parent
                text: Icons.get("settings")
                font.family: Icons.fontFamily
                font.pixelSize: Theme.fontSizeL
                color: Theme.cDim
            }

            MouseArea {
                id: engrenagemArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsRequested()
            }
        }
    }
}
