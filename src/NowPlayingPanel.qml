import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property int trackId: 0
    property bool compact: false
    property var info: ({})

    signal likeRequested(int trackId)

    // Compact does not just shrink the cover: the whole panel narrows with it. Leaving the
    // panel at 392 while the cover drops to 200 would push the frame past a 720 px window and
    // send the right edge of the pane off screen.
    implicitWidth: root.coverSide + (Theme.marginXL + Theme.marginS) * 2 + 4
    color: Theme.mSurface

    // Um degradê muito sutil separa o painel do miolo sem precisar de borda.
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.mSurfaceVariant }
        GradientStop { position: 0.6; color: Theme.mSurface }
    }

    readonly property int coverSide: root.compact ? 200 : 340

    // Lidos por `appmelodia --measure`: a capa quadrada é uma das linhas do gate de layout.
    readonly property alias coverWidth: capaRect.width
    readonly property alias coverHeight: capaRect.height

    // mpv reports pause=false while it is idle, so AudioEngine.playing is true before any file
    // is loaded. Without this guard the transport shows a pause button with nothing playing.
    readonly property bool hasTrack: AudioEngine.currentFile !== ""

    function refresh() {
        const path = AudioEngine.currentFile
        root.info = path === "" ? ({}) : LibraryBrowser.trackForPath(path)
        root.trackId = root.info.id !== undefined ? root.info.id : 0
    }

    Component.onCompleted: root.refresh()



    Connections {
        target: AudioEngine
        function onCurrentFileChanged() { root.refresh() }
    }

    Connections {
        target: LibraryBrowser
        function onLikedChanged(id, liked) {
            if (id === root.trackId)
                root.refresh()
        }
    }

    function formatTime(seconds) {
        if (!(seconds > 0))
            return "0:00"
        const total = Math.floor(seconds)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.marginXL + Theme.marginS
        spacing: Theme.marginXL

        Rectangle {
            id: capaRect

            // O resto da coluna (título, progresso, controles, tags) ocupa ~330px. Quando a
            // janela é mais baixa que isso + 340, a capa cede espaço — mas cede QUADRADA:
            // sem amarrar largura à altura, o Layout encolheria só a altura e a arte sairia
            // deformada. Salvaguarda: numa janela de 1384 a medida confirma 340x340.
            readonly property int lado: Math.max(120, Math.min(root.coverSide, root.height - 330))

            Layout.preferredWidth: capaRect.lado
            Layout.preferredHeight: capaRect.lado
            Layout.maximumHeight: capaRect.lado
            Layout.alignment: Qt.AlignHCenter
            radius: Theme.radiusM
            color: Theme.mSurfaceVariant
            clip: true

            Image {
                anchors.fill: parent
                source: root.info.albumId !== undefined
                        ? CoverCache.coverUrlForTrack(AudioEngine.currentFile, root.info.albumId)
                        : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                sourceSize.width: capaRect.lado
            }

            Text {
                anchors.centerIn: parent
                visible: root.trackId === 0
                text: Icons.get("music")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeXXXL
                color: Theme.mOutline
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginL

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.marginXXS

                Text {
                    Layout.fillWidth: true
                    text: root.info.title !== undefined && root.info.title !== ""
                          ? root.info.title : qsTr("nada tocando")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeXXL
                    font.weight: Theme.fontWeightBold
                    color: Theme.mOnSurface
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.info.artist !== undefined && root.info.artist !== ""
                    text: root.info.artist !== undefined ? root.info.artist : ""
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeL
                    color: Theme.mOnSurfaceVariant
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.trackId > 0
                    text: [root.info.album, root.info.year > 0 ? root.info.year : "",
                           root.info.codec].filter(function (p) { return p !== "" && p !== undefined })
                                           .join(" · ")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: Theme.mOutline
                    elide: Text.ElideRight
                }
            }

            IconButton {
                visible: root.trackId > 0
                icon: "heart"
                size: Theme.fontSizeXL
                accent: root.info.liked === true
                onClicked: root.likeRequested(root.trackId)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS

            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 3
                radius: Theme.radiusXXS
                color: Theme.mSurfaceVariant

                Rectangle {
                    width: AudioEngine.duration > 0
                           ? parent.width * (AudioEngine.position / AudioEngine.duration) : 0
                    height: parent.height
                    radius: parent.radius
                    color: Theme.mTertiary
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Theme.marginS
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function (mouse) {
                        if (AudioEngine.duration > 0)
                            AudioEngine.seek(AudioEngine.duration * (mouse.x / track.width))
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.formatTime(AudioEngine.position)
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeXS
                    color: Theme.mOnSurfaceVariant
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.formatTime(AudioEngine.duration)
                    font.family: Theme.fontFamilyFixed
                    font.pointSize: Theme.fontSizeXS
                    color: Theme.mOnSurfaceVariant
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.marginXL

            IconButton { icon: "shuffle"; size: Theme.fontSizeL; onClicked: {} }
            IconButton { icon: "track-prev"; size: Theme.fontSizeXL; onClicked: AudioEngine.previous() }

            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: 26
                color: Theme.mTertiary

                Text {
                    anchors.centerIn: parent
                    text: AudioEngine.playing && root.hasTrack ? Icons.get("pause") : Icons.get("play")
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeXL
                    color: Theme.mOnTertiary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioEngine.togglePause()
                }
            }

            IconButton { icon: "track-next"; size: Theme.fontSizeXL; onClicked: AudioEngine.next() }
            IconButton { icon: "repeat"; size: Theme.fontSizeL; onClicked: {} }
        }

        TagEditor {
            id: tagEd
            Layout.fillWidth: true
            visible: root.trackId > 0
            trackId: root.trackId
        }

        Item { Layout.fillHeight: true }
    }
}
