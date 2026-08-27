import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Melodia.App

Item {
    id: root

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.marginL
        width: Math.min(parent.width * 0.7, 420)

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Icons.get("folder")
            font.family: Icons.fontFamily
            font.pointSize: Theme.fontSizeXXXL
            color: Theme.mOnSurfaceVariant
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("Escolha a pasta onde sua música está. O melodia lê os arquivos; nunca escreve neles.")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeM
            color: Theme.mOnSurfaceVariant
        }
        MelodiaButton {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Escolher pasta")
            onClicked: folderDialog.open()
        }
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Pasta de música")
        onAccepted: {
            Database.libraryPath = selectedFolder.toString().replace("file://", "")
            Database.startScan()
        }
    }
}
