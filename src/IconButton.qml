import QtQuick
import Melodarium.App

Item {
    id: root

    property string icon: ""
    property real size: Theme.fontSizeXL
    property bool accent: false
    property string tooltip: ""
    // O desenho não pinta todos os ícones com o mesmo tom: os do transporte principal são
    // mais claros que aleatório e repetir, que ficam um degrau atrás. Quem chama escolhe.
    property color baseColor: Theme.cSecondary

    signal clicked

    // 1,8x e não 2x: com a tipografia em pixels o dobro do glifo virava uma área de toque de
    // 38 px por botão, e a fileira do transporte passava a ser mais larga do que o painel que
    // a contém — o tempo total da faixa saía cortado pela borda.
    implicitWidth: Math.round(size * 1.8)
    implicitHeight: Math.round(size * 1.8)
    opacity: enabled ? 1.0 : 0.4
    activeFocusOnTab: enabled && visible

    Accessible.role: Accessible.Button
    Accessible.name: tooltip !== "" ? tooltip : icon
    Accessible.description: tooltip
    Accessible.focusable: enabled && visible
    Accessible.onPressAction: if (root.enabled) root.clicked()

    Keys.onSpacePressed: function(event) {
        if (root.enabled)
            root.clicked()
        event.accepted = true
    }
    Keys.onReturnPressed: function(event) {
        if (root.enabled)
            root.clicked()
        event.accepted = true
    }
    Keys.onEnterPressed: function(event) {
        if (root.enabled)
            root.clicked()
        event.accepted = true
    }
    Keys.onTabPressed: function(event) {
        const next = root.nextItemInFocusChain(true)
        if (next)
            next.forceActiveFocus(Qt.TabFocusReason)
        event.accepted = true
    }
    Keys.onBacktabPressed: function(event) {
        const previous = root.nextItemInFocusChain(false)
        if (previous)
            previous.forceActiveFocus(Qt.BacktabFocusReason)
        event.accepted = true
    }

    // A cor de repouso do glifo, num lugar só: os dois Text abaixo a leem, e escrita duas
    // vezes ela derraparia na primeira edição.
    readonly property color corDoGlifo: mouse.containsMouse && root.enabled
                                        ? Theme.cTitle
                                        : (root.accent ? Theme.cAccent : root.baseColor)

    // Trocar de desenho no lugar: dois glifos sobrepostos, o novo entrando enquanto o velho
    // sai. Um Text só trocando `text` pisca o desenho novo sem passar por lugar nenhum — dá
    // para ver no botão de volume (som → baixo → mudo) e no de repetir, que trocam de glifo
    // sem mudar de posição nem de tamanho, e por isso a troca seca aparece como um susto.
    property bool glifoAnaFrente: true
    property string glifoA: ""
    property string glifoB: ""

    onIconChanged: {
        if (root.glifoAnaFrente)
            root.glifoB = root.icon
        else
            root.glifoA = root.icon
        root.glifoAnaFrente = !root.glifoAnaFrente
    }

    // Os dois iguais na partida: `icon` costuma ser um binding que assenta em mais de um
    // passo, e sem isto o botão nasceria cruzando de um glifo vazio para o certo.
    Component.onCompleted: {
        root.glifoA = root.icon
        root.glifoB = root.icon
        root.glifoAnaFrente = true
    }

    // O pulo, pedido de fora. Quem sabe que houve comemoração é quem tratou o clique, e não
    // o botão: `accent` também muda ao ligar o aleatório e ao ligar o repetir, e nem um nem
    // outro comemora. Um botão que pulasse sozinho a cada mudança de `accent` transformaria
    // a fileira inteira do transporte numa festa.
    function comemorar() { puloDoBotao.restart() }

    SequentialAnimation {
        id: puloDoBotao

        NumberAnimation {
            target: root
            property: "scale"
            to: Theme.popEscala
            duration: Theme.animationPop
            easing.type: Easing.OutBack
            easing.overshoot: Theme.popOvershoot
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1.0
            duration: Theme.animationPopBack
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        // O realce do desenho é a pílula escura, não um disco claro: com mHover (quase branco)
        // o hover apagava o próprio ícone que ele deveria destacar.
        color: mouse.containsMouse && root.enabled ? Theme.cPill : "transparent"
        border.width: root.activeFocus ? Theme.borderM : 0
        border.color: Theme.cAccent

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.get(root.glifoA)
            font.family: Icons.fontFamily
            font.pixelSize: root.size
            color: root.corDoGlifo
            opacity: root.glifoAnaFrente ? 1 : 0

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animationFaster; easing.type: Theme.easingType }
            }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.get(root.glifoB)
            font.family: Icons.fontFamily
            font.pixelSize: root.size
            color: root.corDoGlifo
            opacity: root.glifoAnaFrente ? 0 : 1

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.animationFaster; easing.type: Theme.easingType }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
