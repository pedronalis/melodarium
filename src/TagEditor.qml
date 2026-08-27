pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodia.App

ColumnLayout {
    id: root

    property int trackId: 0
    property var tags: []
    property var suggestions: []

    signal tagChosen(string name)

    spacing: Theme.marginS

    function refresh() {
        root.tags = root.trackId > 0 ? CollectionManager.tagsForTrack(root.trackId) : []
    }

    onTrackIdChanged: refresh()
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
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.marginXL * 1.8
        radius: Theme.iRadiusS
        color: Theme.mSurface
        border.width: Theme.borderS
        border.color: tagInput.activeFocus ? Theme.mPrimary : Theme.mOutline

        TextInput {
            id: tagInput
            anchors.fill: parent
            anchors.leftMargin: Theme.marginM
            anchors.rightMargin: Theme.marginM
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeS
            color: Theme.mOnSurface
            enabled: root.trackId > 0

            onTextChanged: root.suggestions = CollectionManager.completeTag(text)
            onAccepted: {
                // Enter picks the first suggestion when there is one: that is the brake that
                // keeps near-duplicate tags from being created by accident.
                const name = root.suggestions.length > 0 ? root.suggestions[0] : text
                if (name !== "") {
                    CollectionManager.addTagToTrack(root.trackId, name)
                    text = ""
                    root.suggestions = []
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: tagInput.text === ""
                text: root.trackId > 0 ? qsTr("nova tag…") : qsTr("toque uma faixa para etiquetar")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
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
                    tagInput.text = ""
                    root.suggestions = []
                }
            }
        }
    }
}
