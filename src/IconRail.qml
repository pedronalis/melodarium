import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property string current: "library"

    signal chosen(string section)

    implicitWidth: Theme.railWidth
    color: "transparent"

    Rectangle {
        anchors.right: parent.right
        width: Theme.borderS
        height: parent.height
        color: Theme.mSurfaceVariant
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
        anchors.topMargin: Theme.marginXL
        spacing: Theme.marginS

        // A marca, no topo da barra: não é botão, é de onde o olho parte (design/Main.dc.html).
        Item {
            Layout.preferredWidth: Math.round(34 * Theme.uiScale)
            Layout.preferredHeight: Math.round(34 * Theme.uiScale)
            Layout.bottomMargin: Theme.marginXS

            Text {
                anchors.centerIn: parent
                text: Icons.get("music")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeL
                color: Theme.mOutline
            }
        }

        Repeater {
            model: root.items

            Rectangle {
                id: cell

                required property var modelData

                Layout.preferredWidth: Math.round(34 * Theme.uiScale)
                Layout.preferredHeight: Math.round(34 * Theme.uiScale)
                radius: Theme.iRadiusS
                color: root.current === cell.modelData.key
                       ? Theme.mSurfaceVariant
                       : (area.containsMouse ? Theme.mSurfaceVariant : "transparent")
                opacity: root.current === cell.modelData.key || area.containsMouse ? 1.0 : 0.85

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                Text {
                    anchors.centerIn: parent
                    text: Icons.get(cell.modelData.icon)
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeL
                    color: root.current === cell.modelData.key ? Theme.mTertiary : Theme.mOnSurfaceVariant
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
    }
}
