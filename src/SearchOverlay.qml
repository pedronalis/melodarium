pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodia.App

// O overlay de busca do desenho aprovado (design/Busca.dc.html): um painel de 660x520 a 74 px
// do topo, sobre a tela escurecida, com os resultados agrupados por tipo e tudo alcançável
// sem tirar a mão do teclado.
Popup {
    id: root

    // `opened` não existe aqui de propósito: no Qt 6.10 o Popup já tem uma propriedade FINAL
    // com esse nome, e redeclará-la faz o tipo inteiro deixar de carregar — em silêncio, a não
    // ser que alguém repare no log do disk cache.
    // Só os resultados, na ordem que o C++ devolveu. `linhas` é esta lista com os cabeçalhos
    // de grupo intercalados — o teclado anda em `hits`, o olho lê `linhas`.
    property var hits: []
    property var linhas: []
    property int highlighted: 0

    signal trackChosen(string path)
    signal episodeChosen(int episodeId)
    signal albumChosen(int albumId, string title)
    signal artistChosen(int artistId, string title)
    signal trackQueued(string path)

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: Overlay.overlay
    width: Math.min(660, parent ? parent.width - Theme.marginXL * 2 : 660)
    height: Math.min(520, parent ? parent.height - 96 : 520)
    x: parent ? Math.round((parent.width - width) / 2) : 0
    // 74 px do topo, não centralizado: o desenho põe o painel na altura do olhar, e o miolo
    // continua visível embaixo dele.
    y: 74
    padding: 0

    background: Rectangle {
        color: Theme.mSurface
        radius: Theme.radiusL
        border.width: Theme.borderS
        border.color: Theme.mOutline
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.62)
    }

    // Uma dica de teclado do rodapé: a tecla em fonte fixa, a ação em texto comum.
    component Dica: RowLayout {
        id: dica

        property string tecla: ""
        property string acao: ""

        spacing: Theme.marginS

        Text {
            // Sem font.family de propósito: JetBrains Mono não traz ↑↓ nem ↵, e uma família
            // fixa impede o Qt de cair numa fonte que traga.
            text: dica.tecla
            font.pointSize: Theme.fontSizeS
            color: Theme.mOnSurfaceVariant
        }
        Text {
            text: dica.acao
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeS
            color: Theme.mOutline
        }
    }

    onOpened: {
        input.text = ""
        root.hits = []
        root.linhas = []
        root.highlighted = 0
        input.forceActiveFocus()
    }

    // Nenhuma consulta por tecla: o banco só é tocado quando a digitação para.
    Timer {
        id: debounce
        interval: 180
        onTriggered: root.refresh()
    }

    // Só o modo --measure usa isto: digitar de verdade exige um teclado, e a foto precisa de
    // resultados na tela.
    function typeForMeasure(texto) {
        input.text = texto
        root.refresh()
    }

    function refresh() {
        root.hits = LibraryBrowser.searchGrouped(input.text, 4)
        root.highlighted = 0
        root.linhas = root.buildRows(root.hits)
    }

    // Cabeçalho de grupo a cada troca de tipo: é o que separa "Faixas" de "Álbuns" sem que o
    // QML precise saber que ordem o C++ escolheu.
    function buildRows(hits) {
        const out = []
        let lastKind = ""
        for (let i = 0; i < hits.length; ++i) {
            if (hits[i].kind !== lastKind) {
                lastKind = hits[i].kind
                out.push({ header: true, label: root.groupLabelFor(lastKind), hitIndex: -1 })
            }
            out.push({ header: false, hit: hits[i], hitIndex: i })
        }
        return out
    }

    function rowOfHit(hitIndex) {
        for (let i = 0; i < root.linhas.length; ++i) {
            if (root.linhas[i].hitIndex === hitIndex)
                return i
        }
        return 0
    }

    function move(delta) {
        if (root.hits.length === 0)
            return
        root.highlighted = Math.max(0, Math.min(root.highlighted + delta, root.hits.length - 1))
        results.positionViewAtIndex(root.rowOfHit(root.highlighted), ListView.Contain)
    }

    // A travessia única: `highlighted` é índice de HITS, não das linhas da tela — as linhas
    // levam cabeçalhos de grupo no meio, e indexá-las aqui devolveria um cabeçalho.
    function hitAt(index) {
        if (index < 0 || index >= root.hits.length)
            return null
        return root.hits[index]
    }

    // Pôr na fila não fecha a busca: quem enfileira quer enfileirar mais de uma.
    function queueAt(index) {
        const hit = root.hitAt(index)
        if (hit === null || hit.path === undefined || hit.path === "")
            return
        root.trackQueued(hit.path)
    }

    function activate(index) {
        const hit = root.hitAt(index)
        if (hit === null)
            return
        if (hit.kind === "track" && hit.path !== "")
            root.trackChosen(hit.path)
        else if (hit.kind === "episode")
            root.episodeChosen(hit.id)
        else if (hit.kind === "album")
            root.albumChosen(hit.id, hit.title)
        else if (hit.kind === "artist")
            root.artistChosen(hit.id, hit.title)
        else
            return
        root.close()
    }

    function glyphFor(kind) {
        if (kind === "album") return Icons.get("disc")
        if (kind === "artist") return Icons.get("microphone")
        if (kind === "episode") return Icons.get("rss")
        return Icons.get("music")
    }

    function groupLabelFor(kind) {
        if (kind === "album") return qsTr("Álbuns")
        if (kind === "artist") return qsTr("Artistas")
        if (kind === "episode") return qsTr("Episódios")
        return qsTr("Faixas")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // --- O campo: é a única coisa com foco enquanto o overlay está aberto ---
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.marginXL
            spacing: Theme.marginL

            Text {
                text: Icons.get("search")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeL
                color: Theme.mOnSurfaceVariant
            }

            TextInput {
                id: input
                Layout.fillWidth: true
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXL
                color: Theme.mOnSurface
                selectByMouse: true
                clip: true
                onTextChanged: debounce.restart()

                Keys.onDownPressed: root.move(1)
                Keys.onUpPressed: root.move(-1)
                Keys.onReturnPressed: function (event) {
                    if (event.modifiers & Qt.ShiftModifier)
                        root.queueAt(root.highlighted)
                    else
                        root.activate(root.highlighted)
                }
                Keys.onEnterPressed: function (event) {
                    if (event.modifiers & Qt.ShiftModifier)
                        root.queueAt(root.highlighted)
                    else
                        root.activate(root.highlighted)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: qsTr("buscar faixa, álbum, artista, episódio…")
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeM
                    color: Theme.mOutline
                }
            }

            Text {
                text: root.hits.length + qsTr(" resultados")
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOutline
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.borderS
            color: Theme.mSurfaceVariant
        }

        // --- Os resultados, agrupados por tipo ---
        ListView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Theme.marginL
            Layout.leftMargin: Theme.marginS
            Layout.rightMargin: Theme.marginS
            clip: true
            spacing: Theme.marginXS
            model: root.linhas
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: linha

                required property var modelData
                required property int index

                width: ListView.view.width
                height: linha.modelData.header ? 22 : 52

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.marginL
                    anchors.bottom: parent.bottom
                    visible: linha.modelData.header
                    text: linha.modelData.header ? linha.modelData.label.toUpperCase() : ""
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeXS
                    font.weight: Theme.fontWeightBold
                    font.letterSpacing: 1.2
                    color: Theme.mOutline
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !linha.modelData.header
                    radius: Theme.iRadiusS
                    color: root.highlighted === linha.modelData.hitIndex
                           ? Theme.mSurfaceVariant
                           : (hitArea.containsMouse
                              ? Qt.rgba(Theme.mSurfaceVariant.r, Theme.mSurfaceVariant.g,
                                        Theme.mSurfaceVariant.b, 0.5)
                              : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: Theme.animationFaster; easing.type: Theme.easingType }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.marginL
                        anchors.rightMargin: Theme.marginL
                        spacing: Theme.marginL

                        // Artista é redondo, o resto é quadrado: o formato já diz o tipo antes
                        // de o olho chegar ao rótulo do grupo.
                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: linha.modelData.header
                                    ? 0
                                    : (linha.modelData.hit.kind === "artist" ? 17 : Theme.radiusXS)
                            color: Theme.mSurfaceVariant

                            Text {
                                anchors.centerIn: parent
                                text: linha.modelData.header
                                      ? "" : root.glyphFor(linha.modelData.hit.kind)
                                font.family: Icons.fontFamily
                                font.pointSize: Theme.fontSizeM
                                color: Theme.mOnSurfaceVariant
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: linha.modelData.header ? "" : linha.modelData.hit.title
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSizeM
                                font.weight: root.highlighted === linha.modelData.hitIndex
                                             ? Theme.fontWeightSemiBold : Theme.fontWeightMedium
                                color: root.highlighted === linha.modelData.hitIndex
                                       ? Theme.mOnSurface : Theme.mOnSurfaceVariant
                            }
                            Text {
                                Layout.fillWidth: true
                                text: linha.modelData.header ? "" : linha.modelData.hit.subtitle
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSizeS
                                color: Theme.mOutline
                            }
                        }

                        Text {
                            visible: root.highlighted === linha.modelData.hitIndex
                            text: "↵"
                            font.pointSize: Theme.fontSizeS
                            color: Theme.mOnSurfaceVariant
                        }
                    }

                    MouseArea {
                        id: hitArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.highlighted = linha.modelData.hitIndex
                        onClicked: root.activate(linha.modelData.hitIndex)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.hits.length === 0
                text: input.text === "" ? qsTr("digite para procurar")
                                        : qsTr("nada encontrado")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                color: Theme.mOutline
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.borderS
            color: Theme.mSurfaceVariant
        }

        // --- O rodapé de atalhos: o overlay é feito para o teclado ---
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.marginL
            Layout.leftMargin: Theme.marginXL
            Layout.rightMargin: Theme.marginXL
            spacing: Theme.marginXL

            Dica { tecla: "↑↓"; acao: qsTr("navegar") }
            Dica { tecla: "↵"; acao: qsTr("tocar") }
            Dica { tecla: "⇧↵"; acao: qsTr("pôr na fila") }
            Item { Layout.fillWidth: true }
            Dica { tecla: "esc"; acao: qsTr("fechar") }
        }
    }
}
