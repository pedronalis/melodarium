import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodarium.App

Popup {
    id: root

    property int showId: 0
    property string showTitle: ""

    signal unsubscribed

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.marginL
    width: Math.round(440 * Theme.uiScale)

    function openForShow(id, title) {
        root.showId = id
        root.showTitle = title
        root.open()
    }

    function finish(deleteFiles) {
        PodcastLibrary.unsubscribe(root.showId, deleteFiles)
        root.unsubscribed()
        root.close()
    }

    background: Rectangle {
        color: Theme.cRaised
        radius: Theme.radiusM
        border.width: Theme.borderS
        border.color: Theme.cLine
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.marginL

        Text {
            Layout.fillWidth: true
            text: qsTr("Deixar de seguir %1?").arg(root.showTitle)
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL
            font.weight: Theme.fontWeightSemiBold
            color: Theme.cTitle
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("Você pode manter os episódios já baixados ou apagar somente os arquivos gerenciados pelo Melodarium.")
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            color: Theme.cMuted
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS

            MelodariumButton {
                text: qsTr("Cancelar")
                outlined: true
                onClicked: root.close()
            }
            Item { Layout.fillWidth: true }
            MelodariumButton {
                text: qsTr("Manter arquivos")
                outlined: true
                onClicked: root.finish(false)
            }
            MelodariumButton {
                text: qsTr("Apagar arquivos")
                accessibleName: qsTr("Deixar de seguir e apagar downloads gerenciados")
                onClicked: root.finish(true)
            }
        }
    }
}
