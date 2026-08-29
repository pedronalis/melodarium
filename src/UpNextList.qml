pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodarium.App

// "A seguir na fila" dentro do painel da capa, em lista vertical — irmã da QueueStrip, que
// mora no pé do miolo e mostra as próximas como quatro capas lado a lado.
//
// Por que as duas existem: enquanto uma música toca, o painel perde o convite da tela vazia e
// não ganha nada no lugar; numa janela alta sobra mais da metade da coluna em branco, e vazio
// desse tamanho não lê como respiro, lê como tela inacabada. Aqui a coluna é estreita e sobra
// altura — o contrário do pé do miolo —, então a forma certa é a lista: capa pequena, título e
// artista, que é o que a tirinha de capas não consegue dizer.
Item {
    id: root

    // Três, não quatro: a tirinha do miolo mostra quatro porque lá cabe em uma faixa
    // horizontal. Aqui cada uma custa uma linha inteira da coluna.
    property int lookahead: 3

    signal entryActivated(int queueIndex)
    // O contador é a porta da fila inteira, como na tirinha: dizer quantas faltam sem dar
    // como olhar seria um número morto.
    signal expandRequested

    // O QML só rastreia LEITURA DE PROPRIEDADE, e uma chamada de método invocável não cria
    // dependência nenhuma: sem as duas leituras abaixo esta ligação valeria para sempre o que
    // valia ao nascer — uma lista congelada na fila vazia da abertura do app. As leituras têm
    // de ser USADAS, não descartadas: uma expressão sem efeito é eliminada pelo compilador e
    // a dependência vai junto. (Mesma armadilha da QueueStrip.)
    readonly property var proximos: {
        const total = AudioEngine.queueCount
        const pos = AudioEngine.playlistPos
        if (total <= 0 || pos + 1 >= total)
            return []
        return AudioEngine.upcoming(root.lookahead)
    }

    readonly property bool temProximos: root.proximos.length > 0
    // A altura que ela OCUPARIA, independente de estar visível: é com este número que o painel
    // decide se ainda sobra coluna para ela depois da capa e do transporte. Ler `implicitHeight`
    // para isso daria uma ligação circular — ele já depende de `visible`.
    readonly property int alturaCheia: coluna.implicitHeight

    // Some inteira quando a faixa que toca é a última: uma seção vazia com o rótulo sozinho
    // seria mais um buraco, e o buraco é justamente o que ela existe para resolver. Quem
    // instancia pode apertar mais a condição — o painel some com ela também quando não cabe.
    visible: root.temProximos
    implicitHeight: root.visible ? coluna.implicitHeight : 0

    ColumnLayout {
        id: coluna

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.marginS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS

            Text {
                text: qsTr("A seguir na fila").toUpperCase()
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeXXS
                font.weight: Theme.fontWeightBold
                font.letterSpacing: Theme.letterSpacingLabel * Theme.fontSizeXXS
                color: Theme.cFaint
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredHeight: Math.round(18 * Theme.uiScale)
                Layout.preferredWidth: contagem.implicitWidth + Theme.marginM * 2
                radius: Theme.iRadiusXS
                color: contagemArea.containsMouse ? Theme.cRaised : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                Text {
                    id: contagem
                    anchors.centerIn: parent
                    text: AudioEngine.queueCount + qsTr(" na fila")
                    font.family: Theme.fontFamilyFixed
                    font.pixelSize: Theme.fontSizeXS
                    color: contagemArea.containsMouse ? Theme.cBody : Theme.cFaint
                }

                MouseArea {
                    id: contagemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expandRequested()
                }
            }
        }

        Repeater {
            model: root.proximos

            Rectangle {
                id: linha

                required property string modelData
                required property int index

                // Um episódio de podcast não está na biblioteca de música: aí o mapa vem
                // vazio e quem nomeia a linha é o arquivo, que é melhor do que nada.
                readonly property var faixa: LibraryBrowser.trackForPath(linha.modelData)
                readonly property string titulo: linha.faixa.title !== undefined
                                                 && linha.faixa.title !== ""
                                                 ? linha.faixa.title
                                                 : linha.modelData.split("/").pop()
                readonly property string artista: linha.faixa.artist !== undefined
                                                  ? linha.faixa.artist : ""

                Layout.fillWidth: true
                implicitHeight: Math.round(52 * Theme.uiScale)
                radius: Theme.iRadiusS
                // Sem moldura: três linhas emolduradas empilhadas pesariam mais que a capa que
                // está acima delas. Quem marca a linha é o preenchimento no hover.
                color: linhaArea.containsMouse
                       ? Qt.rgba(Theme.cRaised.r, Theme.cRaised.g, Theme.cRaised.b, 0.55)
                       : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.marginS
                    anchors.rightMargin: Theme.marginM
                    spacing: Theme.marginM

                    RoundedCover {
                        Layout.preferredWidth: Math.round(38 * Theme.uiScale)
                        Layout.preferredHeight: Math.round(38 * Theme.uiScale)
                        radius: Theme.radiusXS
                        fallbackIconSize: Theme.fontSizeS
                        // O segundo argumento é ignorado pela implementação (a capa sai do
                        // caminho do arquivo). Passar 0 evita uma consulta por linha.
                        source: CoverCache.coverUrlForTrack(linha.modelData, 0)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.marginXXS

                        Text {
                            Layout.fillWidth: true
                            text: linha.titulo
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeS
                            color: linhaArea.containsMouse ? Theme.cTitle : Theme.cBody
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: linha.artista !== ""
                            text: linha.artista
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXS
                            color: Theme.cFaint
                        }
                    }
                }

                MouseArea {
                    id: linhaArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // O índice na FILA, não na lista: esta começa depois do que está tocando.
                    onClicked: root.entryActivated(AudioEngine.playlistPos + 1 + linha.index)
                }
            }
        }
    }
}
