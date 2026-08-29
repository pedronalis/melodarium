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

    // Curto: o bastante para a linha dissolver, curto o bastante para não apagar a linha
    // inteira — 28 px cobrem pouco mais de meia linha da lista mais apertada do app.
    implicitHeight: Math.round(28 * Theme.uiScale)
    height: implicitHeight
    // Acima do conteúdo que rola, nunca abaixo.
    z: 2

    // `transparent` no QML é preto com alfa zero, e um degradê que passa por ele escurece a
    // lista antes de dissolvê-la. O ponto de partida tem de ser a MESMA cor com alfa zero.
    readonly property color invisivel: Qt.rgba(root.corDeFundo.r, root.corDeFundo.g,
                                               root.corDeFundo.b, 0)

    gradient: Gradient {
        GradientStop {
            position: 0.0
            color: root.paraCima ? root.corDeFundo : root.invisivel
        }
        GradientStop {
            position: 1.0
            color: root.paraCima ? root.invisivel : root.corDeFundo
        }
    }
}
