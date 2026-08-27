import QtQuick
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

    Rectangle {
        anchors.fill: parent
        color: Theme.mSurface

        Behavior on color {
            ColorAnimation { duration: Theme.animationSlowest; easing.type: Theme.easingType }
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.marginM

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.get("music")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeXXXL
                color: Theme.mPrimary
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("melodia")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXXL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Theme.usingNoctalia ? qsTr("paleta do Noctalia") : qsTr("paleta padrão")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }
        }
    }
}
