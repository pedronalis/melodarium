pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodarium.App

// As etiquetas da faixa e o convite para criar mais uma, numa fileira só — como no desenho
// (design/Main.dc.html:110-114). O campo de digitação não fica sempre aberto atravessando o
// painel: ele NASCE do chip "+ tag", no lugar dele, e some quando o trabalho acaba. Um campo
// permanentemente aberto era a peça que mais destoava do desenho no painel.
ColumnLayout {
    id: root

    property int trackId: 0
    property var tags: []
    property var suggestions: []
    // Só existe enquanto se digita: fora disso, o painel mostra etiquetas, não formulário.
    property bool editando: false

    signal tagChosen(string name)

    spacing: Theme.marginS

    function refresh() {
        root.tags = root.trackId > 0 ? CollectionManager.tagsForTrack(root.trackId) : []
    }

    function fecharEdicao() {
        root.editando = false
        tagInput.text = ""
        root.suggestions = []
    }

    onTrackIdChanged: {
        refresh()
        fecharEdicao()
    }
    // The change signal for the very first assignment can land before this handler exists,
    // so the initial load is done explicitly instead of relying on it.
    Component.onCompleted: refresh()

    Connections {
        target: CollectionManager
        function onTagsChanged(id) { if (id === root.trackId) root.refresh() }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Theme.marginXS

        Repeater {
            model: root.tags
            TagChip {
                required property var modelData
                text: modelData.name
                removable: true
                onRemoveRequested: CollectionManager.removeTagFromTrack(root.trackId, modelData.name)
                onClicked: root.tagChosen(modelData.name)
            }
        }

        TagChip {
            visible: !root.editando && root.trackId > 0
            dashed: true
            text: qsTr("+ tag")
            onClicked: {
                root.editando = true
                tagInput.forceActiveFocus()
            }
        }

        // O campo ocupa exatamente o lugar do chip, com a mesma altura e o mesmo canto: quem
        // clicou em "+ tag" continua olhando para o mesmo ponto da tela.
        Rectangle {
            visible: root.editando
            width: Math.round(140 * Theme.uiScale)
            height: Math.round(22 * Theme.uiScale)
            radius: Theme.iRadiusS
            color: Theme.cPill
            border.width: Theme.borderS
            border.color: tagInput.activeFocus ? Theme.cMuted : Theme.cLine

            TextInput {
                id: tagInput
                anchors.fill: parent
                anchors.leftMargin: Theme.marginM
                anchors.rightMargin: Theme.marginM
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXS
                color: Theme.cBody
                enabled: root.trackId > 0

                onTextChanged: root.suggestions = CollectionManager.completeTag(text)
                onAccepted: {
                    // Enter picks the first suggestion when there is one: that is the brake that
                    // keeps near-duplicate tags from being created by accident.
                    const name = root.suggestions.length > 0 ? root.suggestions[0] : text
                    if (name !== "") {
                        CollectionManager.addTagToTrack(root.trackId, name)
                        root.fecharEdicao()
                    }
                }
                // Sair do campo sem escrever nada devolve o chip: um campo aberto e vazio é
                // exatamente o que o desenho não tem.
                Keys.onEscapePressed: root.fecharEdicao()
                onActiveFocusChanged: {
                    if (!activeFocus && tagInput.text === "")
                        root.fecharEdicao()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: tagInput.text === ""
                    text: qsTr("nova tag…")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXS
                    color: Theme.cDim
                }
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Theme.marginXS
        visible: root.suggestions.length > 0

        Repeater {
            model: root.suggestions
            TagChip {
                required property string modelData
                text: modelData
                onClicked: {
                    CollectionManager.addTagToTrack(root.trackId, modelData)
                    root.fecharEdicao()
                }
            }
        }
    }
}
