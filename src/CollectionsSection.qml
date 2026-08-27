pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodia.App

ColumnLayout {
    id: root

    property int currentCollectionId: 0
    property var model: []

    signal collectionChosen(int id)

    spacing: Theme.marginXXS

    function refresh() {
        root.model = CollectionManager.collections()
    }

    Component.onCompleted: refresh()

    Connections {
        target: CollectionManager
        function onCollectionsChanged() { root.refresh() }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.marginM
        Layout.rightMargin: Theme.marginXS

        Text {
            Layout.fillWidth: true
            text: qsTr("Coleções")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeS
            font.weight: Theme.fontWeightSemiBold
            color: Theme.mOnSurfaceVariant
        }
        IconButton {
            icon: "plus"
            size: Theme.fontSizeS
            onClicked: newDialog.open()
        }
    }

    Repeater {
        model: root.model
        SidebarItem {
            required property var modelData
            Layout.fillWidth: true
            icon: "playlist"
            label: modelData.name
            badge: modelData.count
            selected: root.currentCollectionId === modelData.id
            onClicked: {
                root.currentCollectionId = modelData.id
                root.collectionChosen(modelData.id)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.marginM
        Layout.rightMargin: Theme.marginM
        visible: root.model.length === 0
        wrapMode: Text.WordWrap
        text: qsTr("Nenhuma ainda. Crie uma e jogue faixas dentro.")
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeXS
        color: Theme.mOnSurfaceVariant
    }

    NewCollectionDialog {
        id: newDialog
        onCreated: function (id, name) {
            root.currentCollectionId = id
            root.collectionChosen(id)
        }
    }
}
