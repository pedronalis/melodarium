import QtQuick
import QtQuick.Layouts
import Melodia.App

RowLayout {
    id: root

    readonly property var steps: [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    spacing: Theme.marginXXS

    Repeater {
        model: root.steps

        Rectangle {
            required property real modelData

            implicitWidth: label.implicitWidth + Theme.marginM
            implicitHeight: Theme.marginXL * 1.3
            radius: Theme.iRadiusXS
            color: Math.abs(AudioEngine.speed - modelData) < 0.01
                   ? Theme.mPrimary
                   : (area.containsMouse ? Theme.mHover : "transparent")

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: modelData + "×"
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Math.abs(AudioEngine.speed - modelData) < 0.01
                       ? Theme.mOnPrimary
                       : (area.containsMouse ? Theme.mOnHover : Theme.mOnSurfaceVariant)
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AudioEngine.setSpeed(modelData)
            }
        }
    }
}
