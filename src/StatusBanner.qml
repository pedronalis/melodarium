import QtQuick
import QtQuick.Layouts
import Melodarium.App

FocusScope {
    id: root

    property var notice: null
    readonly property string originText:
        root.notice !== null && root.notice.origin !== undefined ? root.notice.origin : ""
    readonly property string messageText:
        root.notice !== null && root.notice.message !== undefined ? root.notice.message : ""
    readonly property string actionText:
        root.notice !== null && root.notice.actionLabel !== undefined
        ? root.notice.actionLabel : ""
    readonly property string severity:
        root.notice !== null && root.notice.severity !== undefined
        ? root.notice.severity : "info"
    readonly property real progressValue:
        root.notice !== null && root.notice.progress !== undefined
        ? root.notice.progress : -1
    readonly property bool fatal:
        root.notice !== null && root.notice.fatal === true

    signal dismissRequested
    signal retryRequested

    function dismiss() { root.dismissRequested() }
    function retry() {
        if (root.actionText !== "")
            root.retryRequested()
    }

    visible: root.notice !== null
    focus: root.fatal
    activeFocusOnTab: visible
    implicitHeight: body.implicitHeight
    Accessible.role: root.severity === "progress"
                     ? Accessible.ProgressBar : Accessible.AlertMessage
    Accessible.name: root.originText + (root.messageText !== "" ? ": " + root.messageText : "")
    Accessible.description: root.actionText !== ""
                            ? qsTr("Ação disponível: %1").arg(root.actionText)
                            : qsTr("Pressione Escape para fechar")
    Accessible.focusable: visible

    onNoticeChanged: {
        if (root.fatal) {
            root.focus = true
            Qt.callLater(function() { root.forceActiveFocus(Qt.TabFocusReason) })
        }
    }

    Keys.onEscapePressed: function(event) {
        root.dismiss()
        event.accepted = true
    }
    Keys.onReturnPressed: function(event) {
        root.retry()
        event.accepted = true
    }
    Keys.onEnterPressed: function(event) {
        root.retry()
        event.accepted = true
    }

    Rectangle {
        id: body
        anchors.fill: parent
        implicitHeight: content.implicitHeight + Theme.marginM * 2
        radius: Theme.iRadiusS
        color: Theme.cRaised
        border.width: Theme.borderS
        border.color: root.severity === "error" || root.severity === "fatal"
                      ? Theme.mError : Theme.cLine

        RowLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.marginM
            spacing: Theme.marginM

            Text {
                text: root.severity === "progress" ? Icons.get("refresh")
                      : (root.severity === "fatal" ? Icons.get("alert-triangle")
                                                   : Icons.get("alert-circle"))
                font.family: Icons.fontFamily
                font.pixelSize: Theme.fontSizeL
                color: root.severity === "error" || root.severity === "fatal"
                       ? Theme.mError : Theme.cSecondary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.marginXS

                Text {
                    Layout.fillWidth: true
                    text: root.originText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    font.weight: Theme.fontWeightSemiBold
                    color: Theme.cTitle
                }

                Text {
                    Layout.fillWidth: true
                    text: root.messageText
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
                    color: Theme.cBody
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(3, Math.round(3 * Theme.uiScale))
                    visible: root.progressValue >= 0
                    radius: Theme.radiusTrack
                    color: Theme.cLine

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.progressValue))
                        height: parent.height
                        radius: parent.radius
                        color: Theme.cAccent
                    }
                }
            }

            MelodariumButton {
                visible: root.actionText !== ""
                text: root.actionText
                outlined: true
                onClicked: root.retry()
            }

            IconButton {
                icon: "x"
                size: Theme.fontSizeM
                tooltip: qsTr("Fechar aviso")
                onClicked: root.dismiss()
            }
        }
    }
}
