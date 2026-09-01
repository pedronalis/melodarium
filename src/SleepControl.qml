import QtQuick
import QtQuick.Controls
import Melodarium.App

// One native menu serves both playback surfaces. The engine owns the countdown so switching
// panes or hiding the mini-player never destroys an armed timer.
IconButton {
    id: root

    icon: "clock"
    size: Theme.fontSizeL
    baseColor: Theme.cMuted
    accent: AudioEngine.sleepActive || AudioEngine.stopAfterCurrent
    tooltip: AudioEngine.sleepActive
             ? qsTr("Timer: %1").arg(root.formatRemaining(AudioEngine.sleepRemainingSeconds))
             : (AudioEngine.stopAfterCurrent
                ? qsTr("Parar após esta faixa") : qsTr("Timer de desligamento"))
    onClicked: menu.popup(root, 0, root.height + Theme.marginXS)

    readonly property bool nativeMenuPreferred: menu.popupType === Popup.Native
    readonly property int optionCount: menu.count

    function formatRemaining(seconds) {
        if (seconds < 60)
            return qsTr("%1 s").arg(seconds)
        const minutes = Math.ceil(seconds / 60)
        return qsTr("%1 min").arg(minutes)
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: AudioEngine.sleepActive || AudioEngine.stopAfterCurrent
        text: AudioEngine.sleepActive
              ? (AudioEngine.sleepRemainingSeconds < 60
                 ? AudioEngine.sleepRemainingSeconds + "s"
                 : Math.ceil(AudioEngine.sleepRemainingSeconds / 60) + "m")
              : "1"
        font.family: Theme.fontFamilyFixed
        font.pixelSize: Theme.fontSizeXXS
        font.weight: Theme.fontWeightBold
        color: Theme.cAccent
    }

    Menu {
        id: menu
        title: qsTr("Timer de desligamento")
        popupType: Popup.Native

        MenuItem {
            text: qsTr("15 min")
            onTriggered: AudioEngine.startSleepTimer(15 * 60)
        }
        MenuItem {
            text: qsTr("30 min")
            onTriggered: AudioEngine.startSleepTimer(30 * 60)
        }
        MenuItem {
            text: qsTr("60 min")
            onTriggered: AudioEngine.startSleepTimer(60 * 60)
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Parar após esta faixa")
            checkable: true
            checked: AudioEngine.stopAfterCurrent
            onTriggered: AudioEngine.setStopAfterCurrent(checked)
        }
        MenuItem {
            text: AudioEngine.sleepActive
                  ? qsTr("Cancelar timer (%1)").arg(
                        root.formatRemaining(AudioEngine.sleepRemainingSeconds))
                  : qsTr("Cancelar timer")
            enabled: AudioEngine.sleepActive
            onTriggered: AudioEngine.cancelSleepTimer()
        }
    }
}
