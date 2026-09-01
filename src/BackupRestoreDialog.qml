import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Melodarium.App

Popup {
    id: root

    property url pendingRestoreFile
    property string message: ""
    property bool restartRequired: false

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.marginXL
    width: Math.round(480 * Theme.uiScale)

    function showResult(result, successMessage) {
        if (!result.ok) {
            root.restartRequired = false
            root.message = result.error
            return
        }
        root.restartRequired = result.restartRequired
        root.message = successMessage
        if (result.rollbackPath !== "")
            root.message += "\n" + qsTr("Backup de retorno: %1").arg(result.rollbackPath)
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
            text: qsTr("Backup e restauração")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXL
            font.weight: Theme.fontWeightSemiBold
            color: Theme.cTitle
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("O bundle inclui o banco de dados e as preferências. A restauração valida versão, hashes e integridade SQLite antes de trocar qualquer arquivo.")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            color: Theme.cMuted
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            MelodariumButton {
                text: qsTr("Criar backup…")
                outlined: true
                onClicked: saveDialog.open()
            }
            MelodariumButton {
                text: qsTr("Restaurar…")
                outlined: true
                onClicked: restoreDialog.open()
            }
            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            visible: root.message !== ""
            text: root.message
            wrapMode: Text.WrapAnywhere
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            color: root.restartRequired ? Theme.cTitle : Theme.cMuted
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS
            Item { Layout.fillWidth: true }
            MelodariumButton {
                visible: root.restartRequired
                text: qsTr("Fechar para reiniciar")
                accessibleName: qsTr("Fechar o Melodarium após restauração")
                onClicked: Qt.quit()
            }
            MelodariumButton {
                visible: !root.restartRequired
                text: qsTr("Fechar")
                onClicked: root.close()
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: qsTr("Criar backup do Melodarium")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "melodarium-backup"
        nameFilters: [qsTr("Backup do Melodarium (*.melodarium-backup)")]
        onAccepted: root.showResult(PortabilityService.createBackup(selectedFile),
                                    qsTr("Backup criado e verificado."))
    }

    FileDialog {
        id: restoreDialog
        title: qsTr("Restaurar backup do Melodarium")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("Backup do Melodarium (*.melodarium-backup)")]
        onAccepted: {
            root.pendingRestoreFile = selectedFile
            confirmRestore.message = qsTr("Restaurar este bundle? O estado atual será preservado em um backup de retorno. O aplicativo precisará ser reiniciado.")
            confirmRestore.open()
        }
    }

    ConfirmDialog {
        id: confirmRestore
        confirmLabel: qsTr("Restaurar")
        onConfirmed: root.showResult(
            PortabilityService.restoreBackup(root.pendingRestoreFile),
            qsTr("Restauração concluída. Feche o Melodarium e abra novamente."))
    }
}
