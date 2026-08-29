import QtQuick
import Melodarium.App

// A borda de uma lista que rola não é um corte: é uma dissolução. Sem isto a última linha
// visível é cortada ao meio por um rodapé sólido — a faixa aparece pela metade e o olho lê
// defeito, não continuação. O degradê faz a linha SUMIR para dentro do fundo, que é o que diz
// "tem mais coisa aqui embaixo" sem escrever nada.
//
// Sem shader de propósito: um efeito de máscara desapareceria no adaptador de software, como
// já aconteceu com a capa deste app. Isto é um retângulo com degradê por cima da lista, que é
// o caminho que sobrevive em qualquer máquina.
Rectangle {
    id: root

    // O degradê precisa terminar EXATAMENTE na cor que está atrás da lista, senão em vez de
    // sumir a linha entra numa faixa cinza que não pertence a lugar nenhum.
    property color corDeFundo: Theme.cBase
    // Falso: a lista some para baixo (o caso comum, o pé da lista). Verdadeiro: some para
    // cima, sob o cabeçalho.
    property bool paraCima: false

    // Alto o bastante para a dissolução ter tempo de acontecer: com 28 px ela cabia em meia
    // linha e o olho ainda lia um corte, só que borrado. Uma linha inteira e meia é o que faz
    // a última faixa PARECER estar indo embora em vez de ser apagada.
    implicitHeight: Math.round(72 * Theme.uiScale)
    height: implicitHeight
    // Acima do conteúdo que rola, nunca abaixo.
    z: 2

    // `transparent` no QML é preto com alfa zero, e um degradê que passa por ele escurece a
    // lista antes de dissolvê-la. O ponto de partida tem de ser a MESMA cor com alfa zero.
    readonly property color invisivel: Qt.rgba(root.corDeFundo.r, root.corDeFundo.g,
                                               root.corDeFundo.b, 0)

    // Uma reta entre transparente e opaco não parece suave: o alfa cresce igual do começo ao
    // fim e o olho enxerga a entrada do degradê como uma linha. As paradas abaixo desenham uma
    // curva — quase nada de véu no primeiro terço, o peso todo no fim —, que é como uma sombra
    // real cai. Escritas à mão, uma a uma: um Repeater aqui dentro não roda (o delegate dele
    // tem de ser um Item, e GradientStop não é), e o app sequer abre.
    //
    // Quando a lista some para CIMA a mesma curva é lida ao contrário, e por isso cada parada
    // carrega os dois valores: as posições precisam subir em ordem nos dois sentidos.
    function veu(alfa) {
        return Qt.rgba(root.corDeFundo.r, root.corDeFundo.g, root.corDeFundo.b, alfa)
    }

    gradient: Gradient {
        GradientStop {
            position: root.paraCima ? 0.00 : 0.00
            color: root.veu(root.paraCima ? 1.00 : 0.00)
        }
        GradientStop {
            position: root.paraCima ? 0.10 : 0.25
            color: root.veu(root.paraCima ? 0.82 : 0.05)
        }
        GradientStop {
            position: root.paraCima ? 0.22 : 0.45
            color: root.veu(root.paraCima ? 0.58 : 0.16)
        }
        GradientStop {
            position: root.paraCima ? 0.38 : 0.62
            color: root.veu(root.paraCima ? 0.34 : 0.34)
        }
        GradientStop {
            position: root.paraCima ? 0.55 : 0.78
            color: root.veu(root.paraCima ? 0.16 : 0.58)
        }
        GradientStop {
            position: root.paraCima ? 0.75 : 0.90
            color: root.veu(root.paraCima ? 0.05 : 0.82)
        }
        GradientStop {
            position: root.paraCima ? 1.00 : 1.00
            color: root.veu(root.paraCima ? 0.00 : 1.00)
        }
    }
}
