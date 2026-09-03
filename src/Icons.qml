pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property FontLoader loader: FontLoader {
        source: "qrc:/qt/qml/Melodarium/App/assets/fonts/noctalia-tabler-icons.ttf"
    }
    readonly property string fontFamily: loader.name

    readonly property var glyphs: ({
        "play": "",
        "pause": "",
        "stop": "",
        "skip-back": "",
        "skip-forward": "",
        "track-next": "",
        "track-prev": "",
        "repeat": "",
        "shuffle": "",
        "volume": "",
        "volume-low": "",
        "volume-off": "",
        "search": "",
        "music": "",
        "disc": "",
        "microphone": "",
        "playlist": "",
        "heart": "",
        "heart-filled": "",
        "clock": "",
        "star": "",
        "download": "",
        "pencil": "",
        "trash": "",
        "rss": "",
        "settings": "",
        "close": "",
        "plus": "",
        "more": "",
        "chevron-right": "",
        "chevron-left": "",
        "folder": "",
        "folder-plus": "",
        "home": "",
        "database": "",
        "device-desktop": "",
        "network": "",
        "arrow-up": "",
        "eye": "",
        "eye-off": "",
        "keyboard": "",
        "lock": "",
        "tags": "",
        "list": "",
        "history": ""
    })

    function get(name) {
        return glyphs[name] !== undefined ? glyphs[name] : ""
    }
}
