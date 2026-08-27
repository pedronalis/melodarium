import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Melodia.App

Window {
    id: root
    width: 1100
    height: 700
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: qsTr("melodia")
    color: Theme.mSurface

    TrackListModel {
        id: trackModel
        currentPath: AudioEngine.currentFile
    }

    Connections {
        target: Database
        function onScanFinished(added, updated, removed) {
            trackModel.loadAllTracks()
        }
    }

    Component.onCompleted: {
        if (Database.libraryPath !== "")
            trackModel.loadAllTracks()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginL
        spacing: Theme.marginM

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Text {
                text: Icons.get("music")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeXL
                color: Theme.mPrimary
            }
            Text {
                text: qsTr("melodia")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: Database.scanning
                text: qsTr("varrendo…")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }
            IconButton {
                icon: "history"
                size: Theme.fontSizeL
                enabled: Database.libraryPath !== "" && !Database.scanning
                onClicked: Database.startScan()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusM
            color: Theme.mSurfaceVariant
            border.width: Theme.borderS
            border.color: Theme.mOutline
            clip: true

            LibraryEmptyState {
                anchors.fill: parent
                visible: trackModel.count === 0 && !Database.scanning
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.topMargin: Theme.marginS
                anchors.bottomMargin: Theme.marginS
                visible: trackModel.count > 0
                model: trackModel
                clip: true
                cacheBuffer: 400
                boundsBehavior: Flickable.StopAtBounds

                // Roles are read through the `model` object, never redeclared as required
                // properties with the same names: redeclaring shadows TrackRow's own
                // properties and the row renders blank, with no error anywhere.
                delegate: TrackRow {
                    required property var model
                    required property int index

                    width: ListView.view.width
                    title: model.title
                    artist: model.artist
                    album: model.album
                    durationMs: model.durationMs
                    coverUrl: model.coverUrl
                    isCurrent: model.isCurrent

                    onActivated: {
                        // Load the whole visible list so "next" walks the list the user sees.
                        AudioEngine.loadPlaylist(trackModel.allPaths(), index)
                        AudioEngine.play()
                    }
                }
            }
        }

        PlayerBar {
            Layout.fillWidth: true
        }
    }
}
