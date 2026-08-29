pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Melodarium.App

// "Próximo a tocar" no pé do painel da capa: UMA faixa, no mesmo cartão do "Continuar de onde
// parou" da tela vazia — capa, nome, artista, quanto dura, e o botão redondo que a põe para
// tocar agora.
//
// Antes daqui morava uma lista de até três linhas que vivia das sobras da coluna e quase
// sempre mostrava uma só, com um vazio menor que uma linha embaixo — vazio que não cabia
// nada e que o Pedro apontou na tela em 29/08. Uma peça de tamanho conhecido, ancorada no pé
// da coluna, fecha a coluna de ponta a ponta; quem quer a fila inteira clica em "N na fila".
Item {
    id: root

    signal entryActivated(int queueIndex)
    // O contador é a porta da fila inteira: dizer quantas faltam sem dar como olhar seria um
    // número morto.
    signal expandRequested

    // A altura que o cartão OCUPARIA, esteja visível ou não: é com este número que o painel
    // decide se ainda sobra coluna para ele. Ler `implicitHeight` para isso daria uma ligação
    // circular — ele já depende de `visible`.
    readonly property int alturaCheia: coluna.implicitHeight

    // O QML só rastreia LEITURA DE PROPRIEDADE, e uma chamada de método invocável não cria
    // dependência nenhuma: sem as duas leituras abaixo esta ligação valeria para sempre o que
    // valia ao nascer — um cartão congelado na fila vazia da abertura do app. As leituras têm
    // de ser USADAS, não descartadas: uma expressão sem efeito é eliminada pelo compilador e
    // a dependência vai junto. (Mesma armadilha da QueueStrip.)
    readonly property string proximoCaminho: {
        const total = AudioEngine.queueCount
        const pos = AudioEngine.playlistPos
        if (total <= 0 || pos + 1 >= total)
            return ""
        const lista = AudioEngine.upcoming(1)
        return lista.length > 0 ? lista[0] : ""
    }

    readonly property bool temProximo: root.proximoCaminho !== ""

    // Um episódio de podcast não está na biblioteca de música: aí o mapa vem vazio e quem
    // nomeia o cartão é o arquivo, que é melhor do que nada.
    readonly property var faixa: root.temProximo
                                 ? LibraryBrowser.trackForPath(root.proximoCaminho) : ({})

    readonly property string titulo: root.faixa.title !== undefined && root.faixa.title !== ""
                                     ? root.faixa.title
                                     : root.proximoCaminho.split("/").pop()

    function formatClock(ms) {
        if (!(ms > 0))
            return ""
        const total = Math.floor(ms / 1000)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // Some inteiro quando a faixa que toca é a última: um rótulo de seção sobre um cartão
    // vazio seria mais um buraco, e o buraco é justamente o que ele existe para fechar. Quem
    // instancia pode apertar mais a condição — o painel some com ele em janela baixa.
    visible: root.temProximo
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
                text: qsTr("Próximo a tocar").toUpperCase()
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

        // O cartão do "Continuar de onde parou" (EmptyPane.qml), nas mesmas medidas: as duas
        // peças dizem a mesma coisa — "esta é a faixa que sai daqui a pouco, e este botão a
        // põe para tocar" —, e uma forma diferente para o mesmo gesto ensinaria dois
        // vocabulários.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.round(68 * Theme.uiScale)
            radius: Theme.iRadiusS
            color: cartaoArea.containsMouse
                   ? Theme.cRaised
                   : Qt.rgba(Theme.cRaised.r, Theme.cRaised.g, Theme.cRaised.b, 0.55)
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
                    fallbackIconColor: Theme.cCoverIcon
                    // O segundo argumento é ignorado pela implementação (a capa sai do
                    // caminho do arquivo). Passar 0 evita uma consulta a mais.
                    source: root.temProximo
                            ? CoverCache.coverUrlForTrack(root.proximoCaminho, 0) : ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.marginXXS

                    Text {
                        Layout.fillWidth: true
                        text: root.titulo
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeM
                        font.weight: Theme.fontWeightSemiBold
                        color: Theme.cTitle
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: {
                            const artista = root.faixa.artist !== undefined
                                            ? root.faixa.artist : ""
                            const dura = root.formatClock(root.faixa.durationMs !== undefined
                                                          ? root.faixa.durationMs : 0)
                            return [artista, dura].filter(function (p) { return p !== "" })
                                                  .join(" · ")
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
                id: cartaoArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // O índice na FILA: o cartão é sempre a faixa logo depois da que toca.
                onClicked: root.entryActivated(AudioEngine.playlistPos + 1)
            }
        }
    }
}
