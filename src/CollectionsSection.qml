pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodia.App

ColumnLayout {
    id: root

    property int currentCollectionId: 0
    property var model: []
    // url -> { received, total }. Downloads are per link, not per row, so the state cannot
    // live inside a delegate that scrolling recycles.
    property var activeDownloads: ({})

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

    Connections {
        target: YtDlpDownloader
        function onProgress(url, downloaded, total) {
            const next = root.activeDownloads
            next[url] = { received: downloaded, total: total }
            root.activeDownloads = next
        }
        function onFinished(url, trackId) {
            const next = root.activeDownloads
            delete next[url]
            root.activeDownloads = next
            root.refresh()
        }
        function onFailed(url, reason) {
            const next = root.activeDownloads
            delete next[url]
            root.activeDownloads = next
            downloadWarning.text = reason
        }
    }

    function downloadKeys() {
        return Object.keys(root.activeDownloads)
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
        // Only offered with a collection open: a downloaded track has to land somewhere,
        // and "somewhere" is the collection the user is looking at.
        IconButton {
            icon: "download"
            size: Theme.fontSizeS
            visible: root.currentCollectionId > 0
            onClicked: {
                addLinkDialog.collectionId = root.currentCollectionId
                addLinkDialog.open()
            }
        }
        IconButton {
            icon: "plus"
            size: Theme.fontSizeS
            onClicked: newDialog.open()
        }
    }

    Repeater {
        model: root.downloadKeys()

        DownloadProgressRow {
            required property var modelData

            Layout.fillWidth: true
            Layout.leftMargin: Theme.marginM
            Layout.rightMargin: Theme.marginM
            url: modelData
            received: root.activeDownloads[modelData].received
            total: root.activeDownloads[modelData].total
            onCancelRequested: YtDlpDownloader.cancel(modelData)
        }
    }

    Text {
        id: downloadWarning
        Layout.fillWidth: true
        Layout.leftMargin: Theme.marginM
        Layout.rightMargin: Theme.marginM
        visible: downloadWarning.text !== ""
        wrapMode: Text.WordWrap
        text: ""
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeXS
        color: Theme.mError
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

    AddFromLinkDialog {
        id: addLinkDialog
    }

    NewCollectionDialog {
        id: newDialog
        onCreated: function (id, name) {
            root.currentCollectionId = id
            root.collectionChosen(id)
        }
    }
}
