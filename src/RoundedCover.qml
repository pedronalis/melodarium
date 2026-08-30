import QtQuick
import Melodarium.App

// A capa do desenho tem canto arredondado — e no QML isso não sai de graça. `radius` desenha
// o canto do Rectangle, e `clip: true` recorta os filhos pelo RETÂNGULO do item, não pelo raio:
// a moldura arredondada ficava no código enquanto a imagem por cima dela seguia de canto vivo
// em todas as capas do app. Quem consertou foi a máscara: a imagem é pintada através de um
// retângulo arredondado, que é o que o navegador faz com `border-radius` numa `<img>`.
//
// Vale para as três medidas do desenho: 340 (painel), 62 (tirinha da fila) e as capinhas de
// lista. Sem capa, mostra o placeholder — que também é arredondado, senão o canto vivo só
// mudava de dono. Quem recorta é o RoundedImage (QPainter, em C++): a saída por shader some
// no adaptador de software, e com ela sumia a capa inteira.
Item {
    id: root

    property url source: ""
    property int radius: Theme.radiusM
    property string fallbackIcon: "music"
    property color placeholderColor: Theme.cRaised
    // Os dois tons de cima vêm do desenho (design/Main.dc.html:39), não de um clareamento
    // calculado: Qt.lighter multiplica o V do HSV, e partindo de #191919 ele chegava a
    // #2f2f2f onde o desenho manda #3a3a3a — o bloco nascia um terço mais fraco que o
    // aprovado, que é justamente o degradê que o olho registra nesta tela.
    property color placeholderTop: Theme.cCoverTop
    property color placeholderMid: Theme.cCoverMid
    property real fallbackIconSize: Theme.fontSizeXXXL
    property color fallbackIconColor: Theme.cCoverIcon
    property bool analyzeColors: false

    readonly property bool ready: img.ready

    // A cor que esta arte "é", para quem quiser pintar luz com ela. Transparente (alpha 0)
    // enquanto não há capa carregada, ou quando a capa não tem cor a dar — capa em escala de
    // cinza, quase preta, quase branca.
    readonly property alias dominantColor: img.dominantColor

    // Os focos de luz desta arte: `[{ color, x, y, weight }]`, com `x`/`y` de 0 a 1 dentro do
    // quadrado. Uma cor média só não é a luz que uma capa dá — céu azul em cima e areia
    // laranja embaixo são duas luzes, em dois lugares, e a média das duas é um bege que não
    // existe na arte.
    readonly property alias colorSpots: img.colorSpots

    // O desenho não põe retângulo cinza no lugar da capa que falta: põe um degradê, que é o
    // que faz o quadrado vazio parecer arte e não buraco. E o degradê dele é DIAGONAL
    // (`linear-gradient(145deg, …)`): a luz entra pelo canto de cima à esquerda e cai no de
    // baixo à direita. O `Gradient` do QML só sabe descer reto, e o placeholder vertical não
    // era o desenho — era a aproximação possível dentro do Rectangle.
    //
    // Quem dá o ângulo é este Canvas: por baixo ele é QPainter, o mesmo caminho do
    // RoundedImage, que é o único que sobrevive ao adaptador de software neste projeto (a
    // saída por shader some, e some junto a capa inteira).
    // O bloco que faz as vezes de capa quando não há arte. O desenho não põe um retângulo
    // cinza aí: põe um degradê DIAGONAL (`linear-gradient(145deg, …)`), que é o que faz o
    // quadrado vazio parecer arte e não buraco.
    //
    // Quem pinta é C++ (`GradientBlock`), e não um `Canvas`: o degradê tem ~31 níveis de
    // cinza espalhados por 340 px, e em 8 bits por canal isso vira listras diagonais de ~9 px
    // — a reclamação do Pedro em 29/08. A quebra dessas faixas é ruído de ±1 nível por pixel,
    // e o `Canvas` do QML não sabe aplicá-lo: `getImageData` devolve os pixels e
    // `putImageData` não os grava de volta (fotos idênticas ao pixel, verificado).
    GradientBlock {
        anchors.fill: parent
        visible: !root.ready
        radius: root.radius
        topColor: root.placeholderTop
        midColor: root.placeholderMid
        bottomColor: root.placeholderColor
    }

    Text {
        anchors.centerIn: parent
        visible: !root.ready && root.fallbackIcon !== ""
        text: Icons.get(root.fallbackIcon)
        font.family: Icons.fontFamily
        font.pixelSize: root.fallbackIconSize
        color: root.fallbackIconColor
    }

    RoundedImage {
        id: img
        anchors.fill: parent
        source: root.source
        radius: root.radius
        analyzeColors: root.analyzeColors
    }
}
