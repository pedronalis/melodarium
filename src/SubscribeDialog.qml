import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodia.App

Popup {
    id: root

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.marginL
    width: 460

    background: Rectangle {
        color: Theme.mSurfaceVariant
        radius: Theme.radiusM
        border.width: Theme.borderS
        border.color: Theme.mOutline
    }

    onOpened: {
        urlInput.text = ""
        warning.text = ""
        urlInput.forceActiveFocus()
    }

    Connections {
        target: PodcastLibrary
        function onSubscribeFailed(reason) { warning.text = reason }
        function onShowsChanged() { if (root.opened) root.close() }
    }

    function looksLikeAFeed(text) {
        const t = text.trim()
        return t.startsWith("http://") || t.startsWith("https://")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.marginM

        Text {
            text: qsTr("Assinar podcast")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeL
            font.weight: Theme.fontWeightSemiBold
            color: Theme.mOnSurface
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Cole o endereço do feed RSS do programa.")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeS
            color: Theme.mOnSurfaceVariant
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.marginXL * 2
            radius: Theme.iRadiusS
            color: Theme.mSurface
            border.width: Theme.borderS
            border.color: urlInput.activeFocus ? Theme.mPrimary : Theme.mOutline

            TextInput {
                id: urlInput
                anchors.fill: parent
                anchors.leftMargin: Theme.marginM
                anchors.rightMargin: Theme.marginM
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurface
                selectionColor: Theme.mPrimary
                selectedTextColor: Theme.mOnPrimary
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
            font.pointSize: Theme.fontSizeS
            color: Theme.mError
        }

        FeedStatusRow {
            Layout.fillWidth: true
            showActions: false
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS
            Item { Layout.fillWidth: true }
            MelodiaButton {
                text: qsTr("Cancelar")
                outlined: true
                onClicked: root.close()
            }
            MelodiaButton {
                id: confirm
                text: qsTr("Assinar")
                onClicked: {
                    if (!root.looksLikeAFeed(urlInput.text)) {
                        warning.text = qsTr("O endereço tem de começar com http:// ou https://.")
                        return
                    }
                    warning.text = ""
                    PodcastLibrary.subscribe(urlInput.text.trim())
                }
            }
        }
    }
}
