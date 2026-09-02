import QtQuick
import QtQuick.Templates as T
import Melodarium.App

T.MenuSeparator {
    id: control

    padding: Theme.marginXS
    verticalPadding: Theme.marginS

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    contentItem: Rectangle {
        implicitWidth: Math.round(178 * Theme.uiScale)
        implicitHeight: Theme.borderS
        color: Theme.cLine
    }
}
