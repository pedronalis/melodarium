pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Melodia.App

// O convite da tela "nada tocando" (design/SemMusica.dc.html): em vez de uma capa cinza e um
// transporte que não controla nada, o app oferece três saídas — voltar para onde parou, jogar
// a biblioteca no aleatório, ou atacar o que nunca foi ouvido.
Item {
    id: root

    property var resumeInfo: ({})
    property int neverCount: 0
    property int forgottenCount: 0
    // No painel ele é uma coluna solta embaixo da capa; no miolo é um bloco centralizado com
    // título próprio.
    property bool framed: false

    signal playRequested(string mode)

    // O painel dá altura ao convite pelo que ele realmente ocupa.
    implicitHeight: coluna.implicitHeight

    readonly property bool temRetomar: root.resumeInfo.path !== undefined
                                       && root.resumeInfo.path !== ""

    // Sem pasta escolhida não há o que embaralhar nem o que retomar: o convite vira outro.
    readonly property bool temBiblioteca: Database.libraryPath !== ""

    function refresh() {
        root.resumeInfo = LibraryBrowser.lastPlayed()
        root.neverCount = LibraryBrowser.neverPlayedCount()
        root.forgottenCount = LibraryBrowser.forgottenCount()
    }

    function formatClock(ms) {
        const total = Math.max(0, Math.floor(ms / 1000))
        return Math.floor(total / 60) + ":" + ("0" + (total % 60)).slice(-2)
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Database
        function onScanFinished(added, updated, removed) { root.refresh() }
    }

    Connections {
        target: AudioEngine
        // Ao parar de tocar, o que "continuar de onde parou" oferece mudou.
        function onCurrentFileChanged() { root.refresh() }
    }

    // Uma das três saídas: ícone, rótulo e, quando faz sentido, quantas faixas esperam ali.
    component Atalho: Rectangle {
        id: atalho

        property string glyph: ""
        property string label: ""
        property string badge: ""

        signal clicked

        implicitHeight: Math.round(40 * Theme.uiScale)
        radius: Theme.iRadiusS
        color: atalhoArea.containsMouse
               ? Qt.rgba(Theme.cRaised.r, Theme.cRaised.g,
                         Theme.cRaised.b, 0.6)
               : "transparent"
        border.width: Theme.borderS
        border.color: Theme.cLine

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.marginM
            anchors.rightMargin: Theme.marginM
            spacing: Theme.marginM

            Text {
                text: atalho.glyph
                font.family: Icons.fontFamily
                font.pixelSize: Theme.fontSizeM
                color: Theme.cMuted
            }
            Text {
                Layout.fillWidth: true
                text: atalho.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeS
                color: atalhoArea.containsMouse ? Theme.cTitle : Theme.cMuted
            }
            Text {
                visible: atalho.badge !== ""
                text: atalho.badge
                font.family: Theme.fontFamilyFixed
                font.pixelSize: Theme.fontSizeXS
                color: Theme.cFaint
            }
        }

        MouseArea {
            id: atalhoArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: atalho.clicked()
        }
    }

    ColumnLayout {
        id: coluna

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: root.framed ? undefined : parent.top
        anchors.verticalCenter: root.framed ? parent.verticalCenter : undefined
        width: Math.min(parent.width, root.framed ? 420 : parent.width)
        spacing: Theme.marginXL

        // Só no miolo: no painel, quem diz "nada tocando" é a capa vazia logo acima.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.marginS
            visible: root.framed
            spacing: Theme.marginM

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Icons.get("music")
                font.family: Icons.fontFamily
                font.pixelSize: Theme.fontSizeXXXL
                color: Theme.cRaised
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.temBiblioteca ? qsTr("Nada tocando")
                                         : qsTr("Sua biblioteca ainda está vazia")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeL
                color: Theme.cMuted
            }
        }

        // --- Continuar de onde parou ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.temRetomar
            spacing: Theme.marginM

            Text {
                text: qsTr("Continuar de onde parou").toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXS
                font.weight: Theme.fontWeightBold
                font.letterSpacing: 1.0
                color: Theme.cFaint
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.round(68 * Theme.uiScale)
                radius: Theme.iRadiusS
                color: retomarArea.containsMouse
                       ? Theme.cRaised
                       : Qt.rgba(Theme.cRaised.r, Theme.cRaised.g,
                                 Theme.cRaised.b, 0.55)
                border.width: Theme.borderS
                border.color: Theme.cLine

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.marginM
                    spacing: Theme.marginL

                    RoundedCover {
                        Layout.preferredWidth: Math.round(46 * Theme.uiScale)
                        Layout.preferredHeight: Math.round(46 * Theme.uiScale)
                        radius: Theme.radiusXS
                        fallbackIconSize: Theme.fontSizeM
                        fallbackIconColor: Theme.cFaint
                        source: root.temRetomar
                                ? CoverCache.coverUrlForTrack(
                                      root.resumeInfo.path,
                                      root.resumeInfo.albumId !== undefined
                                      ? root.resumeInfo.albumId : 0)
                                : ""
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.marginXXS

                        Text {
                            Layout.fillWidth: true
                            text: root.resumeInfo.title !== undefined
                                  ? root.resumeInfo.title : ""
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeM
                            font.weight: Theme.fontWeightSemiBold
                            color: Theme.cTitle
                        }
                        Text {
                            Layout.fillWidth: true
                            text: {
                                const artista = root.resumeInfo.artist !== undefined
                                                ? root.resumeInfo.artist : ""
                                const pos = root.resumeInfo.positionMs !== undefined
                                            ? root.resumeInfo.positionMs : 0
                                const parou = pos > 0
                                              ? qsTr("parou em ") + root.formatClock(pos)
                                              : qsTr("do começo")
                                return artista !== "" ? artista + " · " + parou : parou
                            }
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.cFaint
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: Math.round(34 * Theme.uiScale)
                        Layout.preferredHeight: Math.round(34 * Theme.uiScale)
                        radius: Math.round(17 * Theme.uiScale)
                        color: Theme.cTitle

                        Text {
                            anchors.centerIn: parent
                            text: Icons.get("play")
                            font.family: Icons.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            color: Theme.cBase
                        }
                    }
                }

                MouseArea {
                    id: retomarArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.playRequested("resume")
                }
            }
        }

        // --- As outras duas saídas ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS

            Atalho {
                Layout.fillWidth: true
                visible: root.temBiblioteca
                glyph: Icons.get("shuffle")
                label: qsTr("Tocar tudo em ordem aleatória")
                onClicked: root.playRequested("shuffle")
            }
            Atalho {
                Layout.fillWidth: true
                visible: root.neverCount > 0
                glyph: Icons.get("star")
                label: qsTr("Nunca ouvi")
                badge: String(root.neverCount)
                onClicked: root.playRequested("never")
            }
            Atalho {
                Layout.fillWidth: true
                visible: root.forgottenCount > 0
                glyph: Icons.get("history")
                label: qsTr("Esquecidas")
                badge: String(root.forgottenCount)
                onClicked: root.playRequested("forgotten")
            }
        }

        // Sem pasta escolhida não há o que embaralhar: aí o convite é outro.
        Text {
            Layout.fillWidth: true
            visible: !root.temBiblioteca
            horizontalAlignment: root.framed ? Text.AlignHCenter : Text.AlignLeft
            wrapMode: Text.WordWrap
            text: qsTr("Escolha a pasta onde sua música está: o melodia lê os arquivos, nunca escreve neles.")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            color: Theme.cFaint
        }

        MelodiaButton {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.temBiblioteca
            text: qsTr("Escolher pasta")
            onClicked: folderDialog.open()
        }
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Pasta de música")
        onAccepted: {
            Database.libraryPath = selectedFolder.toString().replace("file://", "")
            Database.startScan()
        }
    }
}
