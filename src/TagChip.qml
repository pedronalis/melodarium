import QtQuick
import QtQuick.Layouts
import Melodarium.App

// A etiqueta do desenho (design/Main.dc.html:110-114): pílula de canto 12, fundo um degrau
// acima do painel, texto de corpo. A variante tracejada é o convite a criar uma nova — no
// desenho ela é um chip vazio ao lado das outras, do mesmo tamanho, e não um campo de texto
// atravessando o painel.
Rectangle {
    id: root

    property string text: ""
    property bool removable: false
    // "+ tag": moldura pontilhada e nenhum fundo, porque ainda não é uma etiqueta.
    property bool dashed: false

    signal removeRequested
    signal clicked

    implicitWidth: row.implicitWidth + Theme.marginM * 2
    implicitHeight: Math.round(22 * Theme.uiScale)
    radius: Theme.iRadiusS
    color: root.dashed
           ? (mouse.containsMouse ? Theme.cRaised : "transparent")
           : (mouse.containsMouse ? Theme.cLine : Theme.cPill)

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
    }

    // Rectangle não sabe desenhar borda pontilhada; Canvas sabe, e é o mesmo recurso que a
    // moldura da capa vazia já usa.
    Canvas {
        anchors.fill: parent
        visible: root.dashed
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = Theme.cFaint
            ctx.lineWidth = Theme.borderS
            ctx.setLineDash([4, 3])
            const r = root.radius
            const w = width - 1
            const h = height - 1
            ctx.beginPath()
            ctx.moveTo(r, 0.5)
            ctx.lineTo(w - r, 0.5)
            ctx.arcTo(w, 0.5, w, r, r)
            ctx.lineTo(w, h - r)
            ctx.arcTo(w, h, w - r, h, r)
            ctx.lineTo(r, h)
            ctx.arcTo(0.5, h, 0.5, h - r, r)
            ctx.lineTo(0.5, r)
            ctx.arcTo(0.5, 0.5, r, 0.5, r)
            ctx.stroke()
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.marginXS

        Text {
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXS
            color: root.dashed
                   ? (mouse.containsMouse ? Theme.cMuted : Theme.cDim)
                   : Theme.cBody
        }
        Text {
            visible: root.removable
            text: Icons.get("close")
            font.family: Icons.fontFamily
            font.pixelSize: Theme.fontSizeXXS
            color: mouse.containsMouse ? Theme.cBody : Theme.cMuted

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.marginXS
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeRequested()
            }
        }
    }
}
