import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import Melodarium.App

T.Menu {
    id: control

    popupType: Popup.Item
    margins: Theme.marginS
    overlap: Theme.borderS
    padding: Theme.marginXS

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    delegate: MelodariumMenuItem {}

    contentItem: ListView {
        implicitHeight: contentHeight
        model: control.contentModel
        currentIndex: control.currentIndex
        interactive: Window.window
                     ? contentHeight + control.topPadding + control.bottomPadding > control.height
                     : false
        clip: true

        ScrollIndicator.vertical: ScrollIndicator {
            opacity: size < 1.0 ? (active ? 0.8 : 0.45) : 0

            contentItem: Rectangle {
                implicitWidth: Theme.borderM
                implicitHeight: Math.round(40 * Theme.uiScale)
                radius: Theme.borderS
                color: Theme.cMuted
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }
        }
    }

    background: Rectangle {
        implicitWidth: Math.round(190 * Theme.uiScale)
        implicitHeight: Math.round(38 * Theme.uiScale)
        radius: Theme.radiusXS
        color: Theme.cRaised
        border.width: Theme.borderS
        border.color: Theme.cLine
    }
}
