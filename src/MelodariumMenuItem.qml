import QtQuick
import QtQuick.Controls.impl
import QtQuick.Templates as T
import Melodarium.App

T.MenuItem {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(Math.round(34 * Theme.uiScale),
                             implicitContentHeight + topPadding + bottomPadding,
                             implicitIndicatorHeight + topPadding + bottomPadding)

    padding: Theme.marginM
    spacing: Theme.marginS
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeS
    font.weight: Theme.fontWeightMedium
    icon.width: Theme.fontSizeL
    icon.height: Theme.fontSizeL
    icon.color: control.enabled ? Theme.cTitle : Theme.cFaint

    contentItem: IconLabel {
        readonly property real arrowPadding:
            control.subMenu && control.arrow ? control.arrow.width + control.spacing : 0
        readonly property real indicatorPadding:
            control.checkable && control.indicator ? control.indicator.width + control.spacing : 0

        leftPadding: control.mirrored ? arrowPadding : indicatorPadding
        rightPadding: control.mirrored ? indicatorPadding : arrowPadding
        spacing: control.spacing
        mirrored: control.mirrored
        display: control.display
        alignment: Qt.AlignLeft
        icon: control.icon
        text: control.text
        font: control.font
        color: control.enabled ? Theme.cTitle : Theme.cFaint
    }

    indicator: Item {
        x: control.mirrored ? control.width - width - control.rightPadding
                            : control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        implicitWidth: control.checkable ? Theme.fontSizeM : 0
        implicitHeight: Theme.fontSizeM
        visible: control.checkable

        Text {
            anchors.centerIn: parent
            text: control.checked ? "✓" : ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeM
            font.weight: Theme.fontWeightBold
            color: Theme.cTitle
        }
    }

    arrow: Item {
        x: control.mirrored ? control.leftPadding
                            : control.width - width - control.rightPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        implicitWidth: control.subMenu ? Theme.fontSizeM : 0
        implicitHeight: Theme.fontSizeM
        visible: control.subMenu

        Text {
            anchors.centerIn: parent
            text: Icons.get(control.mirrored ? "chevron-left" : "chevron-right")
            font.family: Icons.fontFamily
            font.pixelSize: Theme.fontSizeM
            color: Theme.cMuted
        }
    }

    background: Rectangle {
        x: Theme.marginXXS
        y: Theme.marginXXS
        width: control.width - Theme.marginXXS * 2
        height: control.height - Theme.marginXXS * 2
        radius: Theme.radiusXXS
        color: control.down || control.highlighted ? Theme.cPill : "transparent"
        border.width: control.visualFocus && control.highlighted ? Theme.borderS : 0
        border.color: Theme.cMuted

        Behavior on color {
            ColorAnimation { duration: Theme.animationFaster; easing.type: Theme.easingType }
        }
    }
}
