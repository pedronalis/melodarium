import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property var paths: []

    implicitWidth: 300
    color: Theme.mSurfaceVariant
    radius: Theme.radiusM
    border.width: Theme.borderS
    border.color: Theme.mOutline

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginM
        spacing: Theme.marginS

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: qsTr("Fila")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }
            Text {
                text: root.paths.length
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOnSurfaceVariant
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.paths
            clip: true
            spacing: Theme.marginXXS

            delegate: Item {
                id: entry

                required property int index
                required property string modelData

                width: ListView.view.width
                height: Theme.marginXL * 1.6

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusXXS
                    color: entry.index === AudioEngine.playlistPos ? Theme.mSurface : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.marginS
                        anchors.rightMargin: Theme.marginS
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: entry.modelData.split("/").pop()
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeS
                        color: entry.index === AudioEngine.playlistPos ? Theme.mPrimary
                                                                        : Theme.mOnSurfaceVariant
                    }
                }
            }
        }
    }
}
