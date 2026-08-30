pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodarium.App

// O explorador de pastas do próprio melodarium. Antes daqui, escolher a pasta abria o
// FolderDialog do Qt, que no Wayland é o portal do sistema: a janela de OUTRO programa, com
// a paleta de outro programa, bem no primeiro gesto de quem abre o app pela primeira vez.
// E o que mais faltava lá: alcançar um HD que não é o de casa.
Popup {
    id: root

    property string title: qsTr("Escolher pasta")
    property string confirmText: qsTr("Escolher esta pasta")
    // A pasta que a tela sugere ao abrir; vazio cai na pasta pessoal.
    property string startPath: ""

    signal folderChosen(string path)

    // A pasta que o botão vai confirmar: a subpasta destacada quando há uma, senão a pasta em
    // que se está. Sem isso, escolher a pasta ATUAL exigiria entrar nela e sair de novo.
    readonly property string pastaEscolhida:
        lista.currentIndex >= 0 && lista.currentIndex < browser.count
        ? browser.pathAt(lista.currentIndex)
        : browser.path

    function abrirEm(caminho) {
        const alvo = browser.resolveInput(caminho !== undefined ? caminho : "")
        browser.path = alvo !== "" ? alvo : browser.resolveInput("~")
        root.open()
    }

    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.marginXL
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: Math.min(Math.round(780 * Theme.uiScale),
                    Overlay.overlay ? Overlay.overlay.width - Theme.marginXL * 2 : 780)
    height: Math.min(Math.round(560 * Theme.uiScale),
                     Overlay.overlay ? Overlay.overlay.height - Theme.marginXL * 2 : 560)

    background: Rectangle {
        color: Theme.cRaised
        radius: Theme.radiusM
        border.width: Theme.borderS
        border.color: Theme.cLine
    }

    onOpened: {
        if (root.startPath !== "") {
            const alvo = browser.resolveInput(root.startPath)
            if (alvo !== "")
                browser.path = alvo
        }
        browser.ensureLoaded()
        browser.refreshVolumes()
        lista.currentIndex = -1
        caminhoDigitado.text = ""
        root.modoDigitar = false
        root.criandoPasta = false
        aviso.text = ""
        lista.forceActiveFocus()
    }

    // Dois campos ocupam o mesmo lugar da barra de cima; um de cada vez.
    property bool modoDigitar: false
    property bool criandoPasta: false

    FolderBrowser {
        id: browser
        // Uma listagem grande com a contagem de músicas por pasta chegando depois: a lista é
        // um modelo de verdade, não uma chamada de função — chamada não cria dependência e a
        // tela congelaria com os números que existiam no primeiro desenho.
        onPathChanged: {
            lista.currentIndex = -1
            lista.positionViewAtBeginning()
            aviso.text = ""
        }
    }

    function irPara(caminho) {
        if (caminho !== "" && caminho !== undefined)
            browser.path = caminho
    }

    contentItem: ColumnLayout {
        spacing: Theme.marginM

        // --- Título ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Text {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXL
                font.weight: Theme.fontWeightSemiBold
                font.letterSpacing: Theme.letterSpacingHeading
                color: Theme.cTitle
            }

            IconButton {
                icon: "close"
                size: Theme.fontSizeL
                baseColor: Theme.cDim
                onClicked: root.close()
            }
        }

        // --- Caminho: subir, migalhas (ou campo de digitar) e os três interruptores ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginXS

            IconButton {
                icon: "arrow-up"
                size: Theme.fontSizeL
                baseColor: Theme.cDim
                enabled: browser.parentPath !== ""
                tooltip: qsTr("pasta acima")
                onClicked: browser.goUp()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(30 * Theme.uiScale)
                radius: Theme.iRadiusS
                color: Theme.cBase
                border.width: Theme.borderS
                border.color: caminhoDigitado.activeFocus ? Theme.cAccent : Theme.cLine

                // As migalhas: cada pedaço do caminho é um destino.
                Flickable {
                    id: trilha
                    visible: !root.modoDigitar
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginM
                    anchors.rightMargin: Theme.marginM
                    contentWidth: migalhas.width
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick

                    // Caminho fundo rola sozinho para o fim: o pedaço que interessa é o último.
                    function mostrarOFim() {
                        contentX = Math.max(0, migalhas.width - width)
                    }

                    Row {
                        id: migalhas
                        height: trilha.height
                        // A trilha só sabe rolar para o fim depois que as migalhas do caminho
                        // novo mediram a própria largura — rolar antes disso deixa à vista o
                        // começo de um caminho fundo, que é a parte que ninguém está lendo.
                        onWidthChanged: trilha.mostrarOFim()

                        Repeater {
                            model: browser.crumbs

                            delegate: Row {
                                id: migalha
                                required property var modelData
                                required property int index
                                height: trilha.height

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: migalha.index > 1
                                    text: "/"
                                    font.family: Theme.fontFamilyFixed
                                    font.pixelSize: Theme.fontSizeS
                                    color: Theme.cFaint
                                    leftPadding: Theme.marginXXS
                                    rightPadding: Theme.marginXXS
                                }

                                Text {
                                    id: pedaco
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: migalha.modelData.name
                                    font.family: Theme.fontFamilyFixed
                                    font.pixelSize: Theme.fontSizeS
                                    font.weight: migalha.index === browser.crumbs.length - 1
                                                 ? Theme.fontWeightSemiBold : Theme.fontWeightRegular
                                    color: toqueMigalha.containsMouse
                                           ? Theme.cAccent
                                           : (migalha.index === browser.crumbs.length - 1
                                              ? Theme.cTitle : Theme.cSecondary)

                                    MouseArea {
                                        id: toqueMigalha
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.irPara(migalha.modelData.path)
                                    }
                                }
                            }
                        }
                    }

                    Connections {
                        target: browser
                        function onPathChanged() { Qt.callLater(trilha.mostrarOFim) }
                    }
                }

                TextInput {
                    id: caminhoDigitado
                    objectName: "caminhoDigitado"
                    visible: root.modoDigitar
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginM
                    anchors.rightMargin: Theme.marginM
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamilyFixed
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.cTitle
                    selectionColor: Theme.cAccent
                    selectedTextColor: Theme.cBase
                    clip: true

                    onAccepted: {
                        const alvo = browser.resolveInput(text)
                        if (alvo === "") {
                            aviso.text = qsTr("Não há pasta nesse caminho.")
                            return
                        }
                        aviso.text = ""
                        browser.path = alvo
                        root.modoDigitar = false
                        lista.forceActiveFocus()
                    }
                    Keys.onEscapePressed: {
                        root.modoDigitar = false
                        lista.forceActiveFocus()
                    }
                }
            }

            IconButton {
                icon: "keyboard"
                size: Theme.fontSizeL
                baseColor: root.modoDigitar ? Theme.cTitle : Theme.cDim
                tooltip: qsTr("digitar ou colar um caminho")
                onClicked: {
                    root.modoDigitar = !root.modoDigitar
                    if (root.modoDigitar) {
                        caminhoDigitado.text = browser.path
                        caminhoDigitado.forceActiveFocus()
                        caminhoDigitado.selectAll()
                    } else {
                        lista.forceActiveFocus()
                    }
                }
            }

            IconButton {
                icon: browser.showHidden ? "eye" : "eye-off"
                size: Theme.fontSizeL
                baseColor: browser.showHidden ? Theme.cTitle : Theme.cDim
                tooltip: browser.showHidden ? qsTr("esconder pastas ocultas")
                                            : qsTr("mostrar pastas ocultas")
                onClicked: browser.showHidden = !browser.showHidden
            }

            IconButton {
                icon: "folder-plus"
                size: Theme.fontSizeL
                baseColor: root.criandoPasta ? Theme.cTitle : Theme.cDim
                tooltip: qsTr("criar pasta aqui")
                onClicked: {
                    root.criandoPasta = !root.criandoPasta
                    aviso.text = ""
                    if (root.criandoPasta) {
                        nomeNovaPasta.text = ""
                        nomeNovaPasta.forceActiveFocus()
                    }
                }
            }
        }

        // --- Nome da pasta nova, quando pedida ---
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(30 * Theme.uiScale)
            visible: root.criandoPasta
            radius: Theme.iRadiusS
            color: Theme.cBase
            border.width: Theme.borderS
            border.color: nomeNovaPasta.activeFocus ? Theme.cAccent : Theme.cLine

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.marginM
                anchors.rightMargin: Theme.marginS
                spacing: Theme.marginS

                Text {
                    text: Icons.get("folder-plus")
                    font.family: Icons.fontFamily
                    font.pixelSize: Theme.fontSizeS
                    color: Theme.cDim
                }

                TextInput {
                    id: nomeNovaPasta
                    objectName: "nomeNovaPasta"
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeM
                    color: Theme.cTitle
                    selectionColor: Theme.cAccent
                    selectedTextColor: Theme.cBase
                    clip: true
                    onAccepted: criar.clicked()
                    Keys.onEscapePressed: {
                        root.criandoPasta = false
                        lista.forceActiveFocus()
                    }
                }

                MelodariumButton {
                    id: criar
                    text: qsTr("Criar")
                    outlined: true
                    onClicked: {
                        const erro = browser.createFolder(nomeNovaPasta.text)
                        aviso.text = erro
                        if (erro === "") {
                            root.criandoPasta = false
                            lista.forceActiveFocus()
                        }
                    }
                }
            }
        }

        // --- O miolo: locais à esquerda, pastas à direita ---
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.marginM

            // Barra de locais e discos.
            Rectangle {
                Layout.preferredWidth: Math.round(190 * Theme.uiScale)
                Layout.fillHeight: true
                radius: Theme.iRadiusS
                color: Theme.cBase
                border.width: Theme.borderS
                border.color: Theme.cLine
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: Theme.marginS
                    contentHeight: colunaLocais.height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: colunaLocais
                        width: parent.width
                        spacing: Theme.marginXXS

                        Text {
                            text: qsTr("LOCAIS")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXXS
                            font.weight: Theme.fontWeightSemiBold
                            font.letterSpacing: Theme.letterSpacingLabel
                            color: Theme.cFaint
                            leftPadding: Theme.marginS
                            bottomPadding: Theme.marginXS
                        }

                        Repeater {
                            model: browser.places
                            delegate: FolderPlaceRow {
                                required property var modelData
                                width: colunaLocais.width
                                nome: modelData.name
                                glifo: modelData.icon
                                aqui: browser.path === modelData.path
                                onEscolhido: root.irPara(modelData.path)
                            }
                        }

                        Item { width: 1; height: Theme.marginM }

                        Text {
                            text: qsTr("DISCOS")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXXS
                            font.weight: Theme.fontWeightSemiBold
                            font.letterSpacing: Theme.letterSpacingLabel
                            color: Theme.cFaint
                            leftPadding: Theme.marginS
                            bottomPadding: Theme.marginXS
                        }

                        Repeater {
                            model: browser.volumes
                            delegate: FolderPlaceRow {
                                required property var modelData
                                width: colunaLocais.width
                                nome: modelData.name
                                glifo: modelData.icon
                                aqui: browser.path === modelData.path
                                detalhe: qsTr("%1 livres").arg(modelData.free)
                                onEscolhido: root.irPara(modelData.path)
                            }
                        }
                    }
                }
            }

            // As subpastas.
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.iRadiusS
                color: Theme.cBase
                border.width: Theme.borderS
                border.color: Theme.cLine
                clip: true

                ListView {
                    id: lista
                    reuseItems: true
                    anchors.fill: parent
                    anchors.margins: Theme.borderS
                    model: browser
                    currentIndex: -1
                    clip: true
                    focus: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: Theme.animationFaster

                    ScrollBar.vertical: ScrollBar {
                        policy: lista.contentHeight > lista.height ? ScrollBar.AsNeeded
                                                                   : ScrollBar.AlwaysOff
                    }

                    // Enter entra na pasta destacada (e confirma quando não há nenhuma),
                    // Backspace sobe: é o que a mão já faz em qualquer gerenciador de arquivos.
                    Keys.onPressed: (evento) => {
                        if (evento.key === Qt.Key_Return || evento.key === Qt.Key_Enter) {
                            if (lista.currentIndex >= 0)
                                browser.enter(lista.currentIndex)
                            else
                                confirmar.clicked()
                            evento.accepted = true
                        } else if (evento.key === Qt.Key_Backspace) {
                            browser.goUp()
                            evento.accepted = true
                        }
                    }

                    delegate: Rectangle {
                        id: linha
                        required property int index
                        required property string name
                        required property string path
                        required property int audioCount
                        required property bool entryReadable

                        width: ListView.view.width
                        height: Math.round(34 * Theme.uiScale)
                        color: linha.ListView.isCurrentItem
                               ? Theme.cPill
                               : (toque.containsMouse ? Theme.cRowCurrent
                                                      : (linha.index % 2 === 1 ? Theme.cRowAlt
                                                                               : "transparent"))

                        Behavior on color {
                            ColorAnimation { duration: Theme.animationFaster
                                             easing.type: Theme.easingType }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.marginM
                            anchors.rightMargin: Theme.marginM
                            spacing: Theme.marginM

                            Text {
                                text: linha.entryReadable ? Icons.get("folder") : Icons.get("lock")
                                font.family: Icons.fontFamily
                                font.pixelSize: Theme.fontSizeL
                                color: linha.ListView.isCurrentItem ? Theme.cStrong : Theme.cDim
                            }

                            Text {
                                Layout.fillWidth: true
                                text: linha.name
                                elide: Text.ElideMiddle
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeM
                                color: !linha.entryReadable
                                       ? Theme.cFaint
                                       : (linha.ListView.isCurrentItem ? Theme.cTitle : Theme.cBody)
                            }

                            // A contagem chega depois da listagem (o disco externo demora); -1 é
                            // "ainda não sei", e "ainda não sei" não escreve nada na tela.
                            Text {
                                visible: linha.audioCount > 0
                                text: linha.audioCount === 1 ? qsTr("1 música")
                                                             : qsTr("%1 músicas").arg(linha.audioCount)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXS
                                color: Theme.cMuted
                            }

                            Text {
                                visible: toque.containsMouse
                                text: Icons.get("chevron-right")
                                font.family: Icons.fontFamily
                                font.pixelSize: Theme.fontSizeS
                                color: Theme.cSubtle
                            }
                        }

                        MouseArea {
                            id: toque
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                lista.currentIndex = linha.index
                                lista.forceActiveFocus()
                            }
                            onDoubleClicked: browser.enter(linha.index)
                        }
                    }
                }

                // Pasta sem subpasta e pasta sem permissão dizem coisas diferentes.
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - Theme.marginXL * 2
                    visible: browser.count === 0
                    spacing: Theme.marginS

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: browser.readable ? Icons.get("folder") : Icons.get("lock")
                        font.family: Icons.fontFamily
                        font.pixelSize: Theme.fontSizeXXL
                        color: Theme.cEmptyIcon
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: browser.readable
                              ? qsTr("Nenhuma subpasta aqui. Dá para escolher esta mesma pasta.")
                              : qsTr("Esta pasta não pode ser lida com as suas permissões.")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeS
                        color: Theme.cFaint
                    }
                }
            }
        }

        Text {
            id: aviso
            Layout.fillWidth: true
            visible: text !== ""
            text: ""
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeS
            color: Theme.mError
        }

        // --- O que vai ser escolhido, e os botões ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Text {
                Layout.fillWidth: true
                text: root.pastaEscolhida
                elide: Text.ElideMiddle
                font.family: Theme.fontFamilyFixed
                font.pixelSize: Theme.fontSizeS
                color: Theme.cSecondary
            }

            MelodariumButton {
                text: qsTr("Cancelar")
                outlined: true
                onClicked: root.close()
            }

            MelodariumButton {
                id: confirmar
                text: root.confirmText
                onClicked: {
                    root.folderChosen(root.pastaEscolhida)
                    root.close()
                }
            }
        }
    }
}
