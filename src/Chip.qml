import QtQuick
import Melodarium.App

// A pílula do desenho: fundo cheio quando escolhida, só contorno quando não. Vive aqui, e não
// dentro da linha de filtros, porque o podcast usa exatamente a mesma peça.
Rectangle {
    id: root

    property string label: ""
    property bool selected: false
    property string glyph: ""
    // Um chevron deitado vira um chevron para baixo: a fonte de ícones não traz o de baixo, e
    // girar custa menos que embutir outro glifo.
    property bool glyphPointsDown: false

    signal clicked

    implicitWidth: row.implicitWidth + Theme.marginM * 2
    implicitHeight: Math.round(22 * Theme.uiScale)
    radius: Theme.iRadiusS
    // Escolhida: fundo cheio um degrau acima da borda das outras. Antes as duas usavam o
    // mesmo tom e a pílula acesa não se distinguia do contorno das apagadas.
    color: root.selected ? Theme.cLine
                         : (area.containsMouse ? Theme.cPill : "transparent")
    border.width: root.selected ? 0 : Theme.borderS
    border.color: Theme.cPill

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.glyph !== "" && root.label !== "" ? Theme.marginS : 0

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            text: root.glyph
            rotation: root.glyphPointsDown ? 90 : 0
            font.family: Icons.fontFamily
            font.pixelSize: Theme.fontSizeXS
            color: root.selected ? Theme.cTitle : Theme.cMuted
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            font.weight: root.selected ? Theme.fontWeightSemiBold : Theme.fontWeightRegular
            color: root.selected ? Theme.cTitle : Theme.cMuted
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
