import QtQuick
import QtQuick.Layouts
import Melodarium.App

Item {
    id: root

    property var decision: ({ action: "reject", accepted: false, paths: [], url: "", reason: "" })
    property bool dragging: false

    visible: root.dragging
    z: 10000

    Accessible.role: Accessible.AlertMessage
    Accessible.name: root.titleForAction(root.decision.action)
    Accessible.description: root.detailForDecision()

    function preview(nextDecision) {
        root.decision = nextDecision
        root.dragging = true
    }

    function dismiss() {
        root.dragging = false
    }

    function titleForAction(action) {
        switch (action) {
        case "queue-files": return qsTr("Adicionar arquivos à fila")
        case "queue-stream": return qsTr("Adicionar mídia remota à fila")
        case "scan-folder": return qsTr("Usar pasta como biblioteca")
        case "subscribe-feed": return qsTr("Assinar feed de podcast")
        case "confirm-youtube": return qsTr("Abrir link do YouTube")
        default: return qsTr("Este item não pode ser importado")
        }
    }

    function detailForDecision() {
        if (root.decision.action === "queue-files")
            return qsTr("%1 arquivo(s) de áudio").arg(root.decision.paths.length)
        if (root.decision.action === "scan-folder")
            return root.decision.paths.length > 0 ? root.decision.paths[0] : ""
        if (root.decision.url !== undefined && root.decision.url !== "")
            return String(root.decision.url)
        return root.decision.reason !== undefined ? root.decision.reason : ""
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.72)
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.marginXL * 2,
                        Math.round(520 * Theme.uiScale))
        height: Math.round(190 * Theme.uiScale)
        radius: Theme.radiusL
        color: Theme.cRaised
        border.width: Theme.borderM
        border.color: root.decision.action === "reject" ? Theme.mError : Theme.cAccent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.marginXL
            spacing: Theme.marginM

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Icons.get(root.decision.action === "scan-folder" ? "folder-plus"
                                : (root.decision.action === "subscribe-feed" ? "rss"
                                   : (root.decision.action === "confirm-youtube" ? "download"
                                      : (root.decision.action === "reject" ? "close"
                                         : "playlist"))))
                font.family: Icons.fontFamily
                font.pixelSize: Theme.fontSizeXXXL
                color: root.decision.action === "reject" ? Theme.mError : Theme.cTitle
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.titleForAction(root.decision.action)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.cTitle
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                text: root.detailForDecision()
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                color: Theme.cMuted
            }
        }
    }
}
