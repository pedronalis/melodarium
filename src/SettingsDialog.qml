pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodarium.App

// O app não tinha nenhum lugar de ajuste. O efeito colateral que mais dói: depois de
// escolher a pasta uma vez na tela de boas-vindas, não havia como trocá-la nunca mais.
Popup {
    id: root

    signal libraryPathPicked(string path)

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.marginXL
    width: Math.round(460 * Theme.uiScale)

    background: Rectangle {
        color: Theme.cRaised
        radius: Theme.radiusM
        border.width: Theme.borderS
        border.color: Theme.cLine
    }

    contentItem: ColumnLayout {
        spacing: Theme.marginXL

        Text {
            text: qsTr("Ajustes")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXL
            font.weight: Theme.fontWeightSemiBold
            color: Theme.cTitle
        }

        // --- Pasta da biblioteca ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS

            Text {
                text: qsTr("Pasta de música")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.weight: Theme.fontWeightSemiBold
                color: Theme.cMuted
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.marginM

                Text {
                    Layout.fillWidth: true
                    text: Database.libraryPath !== "" ? Database.libraryPath
                                                      : qsTr("nenhuma escolhida")
                    elide: Text.ElideMiddle
                    font.family: Theme.fontFamilyFixed
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.cTitle
                }

                MelodariumButton {
                    text: qsTr("Trocar")
                    outlined: true
                    enabled: !Database.scanning
                    onClicked: pastaDialog.abrirEm(Database.libraryPath)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.marginM

                Text {
                    Layout.fillWidth: true
                    visible: Database.scanning
                    text: qsTr("varrendo a pasta…")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXS
                    color: Theme.cMuted
                }

                Item { Layout.fillWidth: true; visible: !Database.scanning }

                MelodariumButton {
                    text: qsTr("Cancelar varredura")
                    outlined: true
                    visible: Database.scanning
                    onClicked: Database.cancelScan()
                }

                MelodariumButton {
                    text: qsTr("Reler a pasta")
                    outlined: true
                    visible: !Database.scanning && Database.libraryPath !== ""
                    onClicked: Database.startScan()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.borderS
            color: Theme.cFaint
        }

        // --- Qualidade de áudio ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Text {
                text: qsTr("Qualidade de áudio")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                font.weight: Theme.fontWeightSemiBold
                color: Theme.cMuted
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.marginM

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("Nivelar o volume entre faixas")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeM
                        color: Theme.cTitle
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        // Diz a verdade em vez de prometer efeito: medido em 2026-08-28,
                        // nenhuma das faixas do acervo traz esse dado gravado dentro.
                        text: qsTr("Usa o nível gravado dentro do arquivo. Só tem efeito em arquivos que o trazem — nenhum da sua biblioteca traz hoje.")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.cFaint
                    }
                }

                // Preenchido quando ligado, contornado quando não — o par visual que o app
                // já usa. Um Chip some aqui: a cor de "selecionado" dele é a mesma cor do
                // fundo desta gaveta, e o controle deixaria de parecer clicável.
                MelodariumButton {
                    id: nivelar

                    property bool checked: false

                    Layout.alignment: Qt.AlignVCenter
                    text: nivelar.checked ? qsTr("ligado") : qsTr("desligado")
                    outlined: !nivelar.checked
                    onClicked: {
                        nivelar.checked = !nivelar.checked
                        root.aplicar()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.marginM

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: qsTr("Saída exclusiva")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeM
                        color: Theme.cTitle
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("Pede à placa de som o sinal sem mistura do sistema. Enquanto estiver ligada, outros programas podem ficar sem áudio.")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXS
                        color: Theme.cFaint
                    }
                }

                MelodariumButton {
                    id: exclusiva

                    property bool checked: false

                    Layout.alignment: Qt.AlignVCenter
                    text: exclusiva.checked ? qsTr("ligada") : qsTr("desligada")
                    outlined: !exclusiva.checked
                    onClicked: {
                        exclusiva.checked = !exclusiva.checked
                        root.aplicar()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS
            Item { Layout.fillWidth: true }
            MelodariumButton {
                text: qsTr("Fechar")
                onClicked: root.close()
            }
        }
    }

    // Uma preferência que não sobrevive ao fechar o app não é uma preferência.
    function carregar() {
        nivelar.checked = melodariumSettings.replayGain
        exclusiva.checked = melodariumSettings.exclusiveOutput
    }

    function aplicar() {
        melodariumSettings.replayGain = nivelar.checked
        melodariumSettings.exclusiveOutput = exclusiva.checked
        AudioEngine.setReplayGainMode(nivelar.checked ? "track" : "no")
        AudioEngine.setExclusiveOutput(exclusiva.checked)
    }

    onOpened: root.carregar()

    Settings {
        id: melodariumSettings
        category: "audio"
        property bool replayGain: false
        property bool exclusiveOutput: false
    }

    FolderPickerDialog {
        id: pastaDialog
        title: qsTr("Pasta de música")
        confirmText: qsTr("Usar esta pasta")
        startPath: Database.libraryPath
        onFolderChosen: (path) => {
            Database.libraryPath = path
            Database.startScan()
            root.libraryPathPicked(path)
        }
    }
}
