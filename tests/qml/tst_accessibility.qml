import QtQuick
import QtTest
import Melodarium.App

TestCase {
    id: testCase

    name: "AccessibilityKeyboard"
    when: testWindow.visible

    property int searchActivations: 0
    property int mediaPlayActivations: 0
    property int mediaNextActivations: 0
    property int mediaPreviousActivations: 0
    property var bannerNotice: null

    Window {
        id: testWindow
        width: 420
        height: 220
        visible: true

        Row {
            anchors.centerIn: parent
            spacing: 12

            IconButton {
                id: iconButton
                icon: "play"
                tooltip: "Tocar"
            }

            MelodariumButton {
                id: textButton
                text: "Aplicar"
            }
        }

        StatusBanner {
            id: statusBanner
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360
            height: implicitHeight
            notice: testCase.bannerNotice
        }

        Shortcut {
            sequences: ["Ctrl+K", "Ctrl+F"]
            onActivated: testCase.searchActivations += 1
        }

        Shortcut {
            sequence: "Media Play"
            onActivated: testCase.mediaPlayActivations += 1
        }

        Shortcut {
            sequence: "Media Next"
            onActivated: testCase.mediaNextActivations += 1
        }

        Shortcut {
            sequence: "Media Previous"
            onActivated: testCase.mediaPreviousActivations += 1
        }
    }

    SignalSpy {
        id: iconClickSpy
        target: iconButton
        signalName: "clicked"
    }

    SignalSpy {
        id: bannerDismissSpy
        target: statusBanner
        signalName: "dismissRequested"
    }

    SignalSpy {
        id: textClickSpy
        target: textButton
        signalName: "clicked"
    }

    function init() {
        iconClickSpy.clear()
        textClickSpy.clear()
        bannerDismissSpy.clear()
        searchActivations = 0
        mediaPlayActivations = 0
        mediaNextActivations = 0
        mediaPreviousActivations = 0
        bannerNotice = null
    }

    function activateTestWindow() {
        testWindow.requestActivate()
        tryVerify(function() { return testWindow.active })
    }

    function test_escape_dismisses_banner() {
        activateTestWindow()
        bannerNotice = ({ origin: "Banco de dados", message: "Falha", severity: "error",
                          action: "dismiss", progress: -1 })
        tryVerify(function() { return statusBanner.visible })
        statusBanner.focus = true
        statusBanner.forceActiveFocus(Qt.TabFocusReason)
        tryVerify(function() { return statusBanner.activeFocus })
        keyClick(Qt.Key_Escape)
        compare(bannerDismissSpy.count, 1)
    }

    function test_tab_space_enter_and_names() {
        activateTestWindow()
        iconButton.forceActiveFocus(Qt.TabFocusReason)
        verify(iconButton.activeFocus)
        compare(iconButton.Accessible.name, "Tocar")
        compare(textButton.visible, true)
        compare(textButton.enabled, true)
        compare(textButton.activeFocusOnTab, true)
        compare(iconButton.nextItemInFocusChain(true), textButton)
        keyClick(Qt.Key_Space)
        compare(iconClickSpy.count, 1)

        keyPress(Qt.Key_Tab)
        keyRelease(Qt.Key_Tab)
        verify(!iconButton.activeFocus)
        textButton.forceActiveFocus(Qt.TabFocusReason)
        verify(textButton.activeFocus)
        compare(textButton.Accessible.name, "Aplicar")
        keyClick(Qt.Key_Return)
        compare(textClickSpy.count, 1)
    }

    function test_search_and_media_shortcuts() {
        activateTestWindow()
        iconButton.forceActiveFocus(Qt.TabFocusReason)
        keyClick(Qt.Key_K, Qt.ControlModifier)
        compare(searchActivations, 1)
        keyClick(Qt.Key_MediaPlay)
        keyClick(Qt.Key_MediaNext)
        keyClick(Qt.Key_MediaPrevious)
        compare(mediaPlayActivations, 1)
        compare(mediaNextActivations, 1)
        compare(mediaPreviousActivations, 1)
    }
}
