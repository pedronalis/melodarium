import QtQuick
import Melodia.App

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
    implicitHeight: 24
    radius: Theme.iRadiusS
    color: root.selected ? Theme.mSurfaceVariant
                         : (area.containsMouse ? Theme.mSurfaceVariant : "transparent")
    border.width: root.selected ? 0 : Theme.borderS
    border.color: Theme.mSurfaceVariant

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
            font.pointSize: Theme.fontSizeXS
            color: root.selected ? Theme.mOnSurface : Theme.mOnSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeS
            font.weight: root.selected ? Theme.fontWeightSemiBold : Theme.fontWeightRegular
            color: root.selected ? Theme.mOnSurface : Theme.mOnSurfaceVariant
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
