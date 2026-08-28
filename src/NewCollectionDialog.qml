import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodarium.App

Popup {
    id: root

    signal created(int id, string name)

    // Com renameId > 0 o mesmo diálogo renomeia em vez de criar. Uma caixa de texto com
    // um botão é a mesma caixa nos dois casos; duplicá-la só duplicaria o bug.
    property int renameId: 0
    property string initialText: ""

    signal renamed(int id, string name)

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.marginL
    width: 360

    background: Rectangle {
        color: Theme.cRaised
        radius: Theme.radiusM
        border.width: Theme.borderS
        border.color: Theme.cLine
    }

    onOpened: {
        nameInput.text = root.initialText
        warning.text = ""
        nameInput.forceActiveFocus()
        nameInput.selectAll()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.marginM

        Text {
            text: root.renameId > 0 ? qsTr("Renomear coleção") : qsTr("Nova coleção")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeL
            font.weight: Theme.fontWeightSemiBold
            color: Theme.cTitle
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.marginXL * 2
            radius: Theme.iRadiusS
            color: Theme.cBase
            border.width: Theme.borderS
            border.color: nameInput.activeFocus ? Theme.cAccent : Theme.cFaint

            TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: Theme.marginM
                anchors.rightMargin: Theme.marginM
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.cTitle
                selectionColor: Theme.cAccent
                selectedTextColor: Theme.cBase
                onAccepted: confirm.clicked()
            }
        }

        Text {
            id: warning
            Layout.fillWidth: true
            visible: warning.text !== ""
            text: ""
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            color: Theme.mError
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS
            Item { Layout.fillWidth: true }
            MelodariumButton {
                text: qsTr("Cancelar")
                outlined: true
                onClicked: root.close()
            }
            MelodariumButton {
                id: confirm
                text: root.renameId > 0 ? qsTr("Renomear") : qsTr("Criar")
                onClicked: {
                    if (root.renameId > 0) {
                        if (CollectionManager.renameCollection(root.renameId, nameInput.text)) {
                            root.renamed(root.renameId, nameInput.text)
                            root.close()
                        } else {
                            warning.text = qsTr("Já existe uma coleção com esse nome.")
                        }
                        return
                    }
                    const id = CollectionManager.createCollection(nameInput.text)
                    if (id > 0) {
                        root.created(id, nameInput.text)
                        root.close()
                    } else {
                        warning.text = qsTr("Já existe uma coleção com esse nome.")
                    }
                }
            }
        }
    }
}
