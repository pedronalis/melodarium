import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodia.App

Popup {
    id: root

    property int collectionId: 0
    property string pendingUrl: ""
    property bool waitingForInfo: false
    property bool hasInfo: false
    property string infoTitle: ""
    property string infoChannel: ""
    property int infoDuration: 0
    property string infoThumbnail: ""

    signal accepted(string url)

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.marginL
    width: 520

    background: Rectangle {
        color: Theme.mSurfaceVariant
        radius: Theme.radiusM
        border.width: Theme.borderS
        border.color: Theme.mOutline
    }

    onOpened: {
        linkInput.text = ""
        warning.text = ""
        root.hasInfo = false
        root.waitingForInfo = false
        root.pendingUrl = ""
        YtDlpDownloader.probe()
        linkInput.forceActiveFocus()
    }

    function formatDuration(seconds) {
        if (seconds <= 0)
            return ""
        const m = Math.floor(seconds / 60)
        const s = seconds % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Connections {
        target: YtDlpDownloader
        function onInfoReady(url, title, channel, durationSeconds, thumbnailUrl) {
            root.waitingForInfo = false
            root.hasInfo = true
            root.pendingUrl = url
            root.infoTitle = title
            root.infoChannel = channel
            root.infoDuration = durationSeconds
            root.infoThumbnail = thumbnailUrl
        }
        function onInfoFailed(url, reason) {
            root.waitingForInfo = false
            root.hasInfo = false
            warning.text = reason
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.marginM

        Text {
            text: qsTr("Adicionar link")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeL
            font.weight: Theme.fontWeightSemiBold
            color: Theme.mOnSurface
        }

        // Without yt-dlp there is nothing to do here, and saying so beats a button that fails.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS
            visible: !YtDlpDownloader.available

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("O melodia não baixa nada sozinho: ele chama o yt-dlp que estiver instalado na sua máquina. Instale pelo gerenciador de pacotes da sua distro e reabra o melodia.")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM
            visible: YtDlpDownloader.available

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("O áudio do YouTube é comprimido e nunca terá a qualidade dos seus arquivos. Ele entra marcado como tal.")
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
                border.color: linkInput.activeFocus ? Theme.mPrimary : Theme.mOutline

                TextInput {
                    id: linkInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginM
                    anchors.rightMargin: Theme.marginM
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeM
                    color: Theme.mOnSurface
                    selectionColor: Theme.mPrimary
                    selectedTextColor: Theme.mOnPrimary
                    onAccepted: lookup.clicked()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.marginM
                visible: root.hasInfo

                Rectangle {
                    Layout.preferredWidth: Theme.marginXL * 4
                    Layout.preferredHeight: Theme.marginXL * 2.5
                    radius: Theme.radiusXS
                    color: Theme.mSurface
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.infoThumbnail
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: root.infoThumbnail !== ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.infoTitle
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeM
                        font.weight: Theme.fontWeightMedium
                        color: Theme.mOnSurface
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.infoChannel
                              + (root.infoDuration > 0
                                 ? " — " + root.formatDuration(root.infoDuration) : "")
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeS
                        color: Theme.mOnSurfaceVariant
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.waitingForInfo
            text: qsTr("consultando o vídeo…")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeS
            color: Theme.mOnSurfaceVariant
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

        // Two installs of yt-dlp on this machine, one older than the other: knowing which one
        // answered saves an hour of debugging the day one of them breaks.
        Text {
            Layout.fillWidth: true
            visible: YtDlpDownloader.toolVersion !== ""
            text: qsTr("yt-dlp %1").arg(YtDlpDownloader.toolVersion)
            font.family: Theme.fontFamilyFixed
            font.pointSize: Theme.fontSizeXXS
            color: Theme.mOnSurfaceVariant
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
                id: lookup
                text: qsTr("Buscar informações")
                outlined: true
                enabled: YtDlpDownloader.available && !root.waitingForInfo
                onClicked: {
                    const link = linkInput.text.trim()
                    if (!link.startsWith("http://") && !link.startsWith("https://")) {
                        warning.text = qsTr("Cole o endereço completo do vídeo.")
                        return
                    }
                    warning.text = ""
                    root.hasInfo = false
                    root.waitingForInfo = true
                    YtDlpDownloader.fetchInfo(link)
                }
            }
            MelodiaButton {
                text: qsTr("Baixar para esta coleção")
                enabled: YtDlpDownloader.available && root.hasInfo
                onClicked: {
                    YtDlpDownloader.download(root.pendingUrl, root.collectionId)
                    root.accepted(root.pendingUrl)
                    root.close()
                }
            }
        }
    }
}
