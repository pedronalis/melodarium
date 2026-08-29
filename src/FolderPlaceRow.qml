import QtQuick
import QtQuick.Layouts
import Melodarium.App

// Uma linha da barra lateral do explorador de pastas: um lugar (pasta pessoal, música,
// downloads) ou um disco montado. Vive em arquivo próprio, e não como componente interno do
// diálogo, porque componente interno não enxerga os `id` do arquivo que o contém — a linha
// precisaria falar com o modelo por caminhos tortos.
Rectangle {
    id: root

    property string nome: ""
    property string glifo: "folder"
    property string detalhe: ""
    // Quem sabe se este é o lugar onde se está é o diálogo, que tem o modelo na mão.
    property bool aqui: false

    signal escolhido

    height: root.detalhe === "" ? Math.round(30 * Theme.uiScale)
                                : Math.round(40 * Theme.uiScale)
    radius: Theme.iRadiusXS
    color: root.aqui ? Theme.cPill : (toque.containsMouse ? Theme.cRowAlt : "transparent")

    Behavior on color {
        ColorAnimation { duration: Theme.animationFaster; easing.type: Theme.easingType }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginS
        anchors.rightMargin: Theme.marginS
        spacing: Theme.marginS

        Text {
            text: Icons.get(root.glifo)
            font.family: Icons.fontFamily
            font.pixelSize: Theme.fontSizeL
            color: root.aqui ? Theme.cStrong : Theme.cDim
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.nome
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.weight: root.aqui ? Theme.fontWeightSemiBold : Theme.fontWeightRegular
                color: root.aqui ? Theme.cTitle : Theme.cBody
            }

            Text {
                Layout.fillWidth: true
                visible: root.detalhe !== ""
                text: root.detalhe
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXXS
                color: Theme.cMuted
            }
        }
    }

    MouseArea {
        id: toque
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.escolhido()
    }
}
