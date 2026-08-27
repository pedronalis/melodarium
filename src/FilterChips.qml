import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodia.App

// A linha de filtros do desenho aprovado. UMA linha, sempre: o Pedro reprovou explicitamente
// a versão que quebrava em duas fileiras de chips. Os quatro eixos automáticos recolhem num
// chip com menu, empurrado para a direita, porque nove chips não cabem em ~650 px.
RowLayout {
    id: root

    property string current: "all"
    property int likedCount: 0

    signal chosen(string key)

    spacing: Theme.marginXS

    // Numa janela estreita os sete chips não cabem em uma linha, e uma linha é o que o desenho
    // manda. Em vez de espremer (texto cortado) ou embrulhar (duas fileiras, reprovadas), os
    // eixos menos usados recolhem para dentro do menu. O limiar é uma largura fixa de
    // propósito: derivá-lo do implicitWidth da própria linha fecharia um laço de binding.
    readonly property bool compact: root.width > 0 && root.width < 560

    readonly property var eixosLargos: [
        { key: "all",     label: qsTr("Todas") },
        { key: "artists", label: qsTr("Artistas") },
        { key: "albums",  label: qsTr("Álbuns") },
        { key: "genres",  label: qsTr("Gêneros") },
        { key: "tags",    label: qsTr("Tags") }
    ]

    readonly property var eixosCompactos: [
        { key: "all",     label: qsTr("Todas") },
        { key: "artists", label: qsTr("Artistas") },
        { key: "albums",  label: qsTr("Álbuns") }
    ]

    readonly property var eixos: root.compact ? root.eixosCompactos : root.eixosLargos

    readonly property var automaticas: [
        { key: "recent",    label: qsTr("Recentes") },
        { key: "most",      label: qsTr("Mais tocadas") },
        { key: "forgotten", label: qsTr("Esquecidas") },
        { key: "never",     label: qsTr("Nunca ouvi") }
    ]

    readonly property var recolhidos: root.compact
                                      ? [{ key: "genres", label: qsTr("Gêneros") },
                                         { key: "tags",   label: qsTr("Tags") }]
                                      : []

    readonly property var menuItens: root.recolhidos.concat(root.automaticas)

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property bool selected: false
        property string glyph: ""
        // Um chevron deitado vira um chevron para baixo: a fonte de ícones não traz o de
        // baixo, e girar custa menos que embutir outro glifo.
        property bool glyphPointsDown: false

        signal clicked

        implicitWidth: chipRow.implicitWidth + Theme.marginM * 2
        implicitHeight: 24
        radius: Theme.iRadiusS
        color: chip.selected ? Theme.mSurfaceVariant
                             : (chipArea.containsMouse ? Theme.mSurfaceVariant : "transparent")
        border.width: chip.selected ? 0 : Theme.borderS
        border.color: Theme.mSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.marginS

            Text {
                visible: chip.glyph !== ""
                text: chip.glyph
                rotation: chip.glyphPointsDown ? 90 : 0
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeXS
                color: chip.selected ? Theme.mOnSurface : Theme.mOnSurfaceVariant
            }
            Text {
                text: chip.label
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                font.weight: chip.selected ? Theme.fontWeightSemiBold : Theme.fontWeightRegular
                color: chip.selected ? Theme.mOnSurface : Theme.mOnSurfaceVariant
            }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    Repeater {
        model: root.eixos

        Chip {
            required property var modelData
            label: modelData.label
            selected: root.current === modelData.key
            onClicked: root.chosen(modelData.key)
        }
    }

    Chip {
        label: root.compact ? "" : qsTr("Curtidas")
        glyph: Icons.get("heart")
        selected: root.current === "liked"
        onClicked: root.chosen("liked")
    }

    Text {
        visible: root.likedCount > 0
        text: root.likedCount
        font.family: Theme.fontFamilyFixed
        font.pointSize: Theme.fontSizeXS
        color: Theme.mOutline
    }

    Item { Layout.fillWidth: true }

    Chip {
        id: autoChip
        label: root.compact ? qsTr("Mais") : qsTr("Automáticas")
        glyph: Icons.get("chevron-right")
        glyphPointsDown: true
        selected: ["recent", "most", "forgotten", "never"].indexOf(root.current) >= 0
                  || (root.compact && ["genres", "tags"].indexOf(root.current) >= 0)
        onClicked: autoMenu.popup(autoChip, 0, autoChip.height + Theme.marginXS)
    }

    Menu {
        id: autoMenu

        Repeater {
            model: root.menuItens

            MenuItem {
                required property var modelData
                text: modelData.label
                onTriggered: root.chosen(modelData.key)
            }
        }
    }
}
