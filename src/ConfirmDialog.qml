import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodia.App

// Apagar uma coleção não tem desfazer. Um Popup pequeno é a diferença entre um clique
// errado custar um segundo e custar a organização inteira de uma noite.
Popup {
    id: root

    property string message: ""
    property string confirmLabel: qsTr("Apagar")

    signal confirmed

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.marginL
    width: Math.round(360 * Theme.uiScale)

    background: Rectangle {
        color: Theme.mSurfaceVariant
        radius: Theme.radiusM
        border.width: Theme.borderS
        border.color: Theme.mOutline
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.marginL

        Text {
            Layout.fillWidth: true
            text: root.message
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeM
            color: Theme.mOnSurface
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS
            Item { Layout.fillWidth: true }
            MelodiaButton {
                text: qsTr("Cancelar")
                outlined: true
                onClicked: root.close()
            }
            MelodiaButton {
                text: root.confirmLabel
                onClicked: {
                    root.confirmed()
                    root.close()
                }
            }
        }
    }
}
