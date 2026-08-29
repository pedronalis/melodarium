pragma Singleton

import QtQuick
import Melodarium.App

QtObject {
    id: theme

    // --- Colors: passthrough from the C++ provider (falls back when Noctalia is absent) ---
    readonly property color mPrimary: ColorSchemeProvider.mPrimary
    readonly property color mOnPrimary: ColorSchemeProvider.mOnPrimary
    readonly property color mSecondary: ColorSchemeProvider.mSecondary
    readonly property color mOnSecondary: ColorSchemeProvider.mOnSecondary
    readonly property color mTertiary: ColorSchemeProvider.mTertiary
    readonly property color mOnTertiary: ColorSchemeProvider.mOnTertiary
    readonly property color mError: ColorSchemeProvider.mError
    readonly property color mOnError: ColorSchemeProvider.mOnError
    readonly property color mSurface: ColorSchemeProvider.mSurface
    readonly property color mOnSurface: ColorSchemeProvider.mOnSurface
    readonly property color mSurfaceVariant: ColorSchemeProvider.mSurfaceVariant
    readonly property color mOnSurfaceVariant: ColorSchemeProvider.mOnSurfaceVariant
    readonly property color mOutline: ColorSchemeProvider.mOutline
    readonly property color mShadow: ColorSchemeProvider.mShadow
    readonly property color mHover: ColorSchemeProvider.mHover
    readonly property color mOnHover: ColorSchemeProvider.mOnHover
    readonly property bool usingNoctalia: ColorSchemeProvider.usingNoctalia

    // --- A escada de cinza do desenho aprovado ---
    // Por que ela existe: o mapa do Noctalia tem 16 chaves e o desenho usa 14 tons com papéis
    // distintos. Consumindo só as 16, cada componente escolhia a chave "mais próxima" e QUATRO
    // fundos de estado diferentes (zebra, linha tocando, pílula, ícone escolhido) colapsavam
    // no mesmo `mSurfaceVariant`. A tela perdia resolução e deixava de ser o desenho — foi a
    // reclamação do Pedro em 28/08: "não está fiel às cores do artifact desenhado".
    //
    // Os nomes são de PAPEL, não de tom: quem escreve tela escolhe pela função ("isto é um
    // metadado") e não pelo hex, que é o que impede a escada de colapsar de novo.
    // Valores lidos de design/Main.dc.html e design/Biblioteca.dc.html.
    readonly property color cBase: "#111111"          // fundo da janela
    readonly property color cPanelTop: "#1a1a1a"      // topo do degradê do painel
    readonly property color cPanelMid: "#131313"      // meio do degradê do painel
    readonly property color cRowAlt: "#151515"        // zebra da lista densa
    readonly property color cRaised: "#191919"        // campo de busca, superfície elevada
    readonly property color cCoverTop: "#3a3a3a"      // topo do bloco de capa sem arte
    readonly property color cCoverMid: "#262626"      // meio do bloco de capa sem arte
    // O bloco do podcast não é cinza: o desenho o puxa para o quente, e é o que separa
    // um episódio sem arte de uma música sem arte antes de qualquer texto ser lido.
    readonly property color cCoverTopPod: "#35312c"   // topo do bloco de episódio sem arte
    readonly property color cCoverMidPod: "#24211f"   // meio do bloco de episódio sem arte
    // O ícone do bloco sem arte vive em cima do MEIO do degradê (~#2b2b2b), não do pé: em
    // #3c3c3c ele ficava um degrau acima do próprio fundo e sumia — mais ainda nas capinhas
    // de 46 px, onde o traço é fino. Sobe para ler como a nota que é (Pedro, 2026-08-29).
    readonly property color cCoverIcon: "#575757"     // o ícone dentro do bloco de música
    readonly property color cCoverIconPod: "#57534a"  // o ícone dentro do bloco de episódio
    // O desenho manda #191919 no ícone da tela vazia (design/SemMusica.dc.html:71), mas ali
    // ele é o MESMO tom do pé do degradê da capa: na tela real o glifo some dentro do bloco e
    // sobra o texto sozinho. Pedro pediu o ícone visível (2026-08-29), no tom do rótulo que
    // vem logo abaixo — ícone e legenda leem como um bloco só.
    readonly property color cEmptyIcon: "#4a4a4a"     // o ícone grande do estado vazio
    readonly property color cRowCurrent: "#1c1c1c"    // a linha que está tocando
    readonly property color cRowWide: "#1e1e1e"       // a linha tocando na lista de álbum
    readonly property color cPill: "#232323"          // pílula de tag, ícone escolhido no trilho
    readonly property color cLine: "#262626"          // borda, trilho de progresso
    readonly property color cGhost: "#2f2f2f"         // traço do coração apagado
    readonly property color cFaint: "#3c3c3c"         // número da faixa, rótulo de seção
    readonly property color cDim: "#4a4a4a"           // metadados, ícone não escolhido
    readonly property color cMuted: "#5d5d5d"         // duração, tempo, texto de pílula
    readonly property color cSubtle: "#6e6e6e"        // texto de botão discreto
    readonly property color cSecondary: "#828282"     // artista no painel, texto de apoio
    readonly property color cBody: "#a4a4a4"          // título de faixa em repouso
    readonly property color cStrong: "#cccccc"        // progresso, triângulo do que toca
    readonly property color cTitle: "#dddddd"         // títulos, botão de tocar

    // O acento é a única porta por onde uma cor do tema do sistema entra na tela. Sem Noctalia
    // (ou com um Noctalia monocromático como o do Pedro) ele é o branco do desenho.
    readonly property color cAccent: theme.usingNoctalia ? theme.mPrimary : theme.cStrong

    // --- Escala da interface ---
    // Todo tamanho abaixo nasceu de um desenho feito para uma janela de 1100x700. Numa tela
    // de 2540x1384 esses mesmos números viram uma interface perdida no canto — foi a
    // reclamação do Pedro em 28/08: "em uma escala microscópica". Main.qml escreve aqui o
    // fator derivado do tamanho real da janela, e a escada inteira acompanha.
    property real uiScale: 1.0

    // --- Typography ---
    // Em PIXELS, e não em pontos: o desenho é medido em px, e um `pointSize` de 11 vira ~14.7 px
    // a 96 dpi — 25% maior do que o desenho manda em cada linha da lista. Os NOMES continuam os
    // mesmos para que nenhum uso precise mudar de nome ao trocar de unidade; só os valores
    // passaram a ser os do desenho.
    readonly property string fontFamily: "Inter"
    readonly property string fontFamilyFixed: "JetBrains Mono"
    readonly property real fontSizeXXS: Math.round(10 * uiScale)  // rótulo de seção
    readonly property real fontSizeXS: Math.round(11 * uiScale)   // números, tempos, pílulas
    readonly property real fontSizeS: Math.round(11 * uiScale)    // artista, álbum, duração
    readonly property real fontSizeM: Math.round(12 * uiScale)    // título de faixa
    readonly property real fontSizeL: Math.round(14 * uiScale)    // artista no painel, ícones
    readonly property real fontSizeXL: Math.round(19 * uiScale)   // título do miolo
    readonly property real fontSizeXXL: Math.round(26 * uiScale)  // título no painel
    readonly property real fontSizeXXXL: Math.round(34 * uiScale) // ícone da capa vazia
    readonly property int fontWeightRegular: 400
    readonly property int fontWeightMedium: 500
    readonly property int fontWeightSemiBold: 600
    readonly property int fontWeightBold: 700

    // O desenho aperta as letras dos títulos; sem isto um título de 26 px lê mais largo e mais
    // solto do que a arte ao lado dele.
    readonly property real letterSpacingTitle: -0.02
    readonly property real letterSpacingHeading: -0.01
    readonly property real letterSpacingLabel: 0.1

    // --- Shape ---
    readonly property int radiusXXS: Math.round(4 * uiScale)
    // O trilho de progresso do desenho tem 3 px de altura e 2 px de raio: com 4 ele vira
    // uma cápsula e some a leitura de "barra".
    readonly property int radiusTrack: 2
    readonly property int radiusXS: Math.round(8 * uiScale)
    readonly property int radiusS: Math.round(12 * uiScale)
    readonly property int radiusM: Math.round(16 * uiScale)
    readonly property int radiusL: Math.round(20 * uiScale)
    readonly property int iRadiusXS: Math.round(8 * uiScale)
    readonly property int iRadiusS: Math.round(12 * uiScale)
    readonly property int iRadiusM: Math.round(16 * uiScale)
    readonly property int borderS: 1
    readonly property int borderM: 2
    readonly property int borderL: 3

    // --- Spacing ---
    readonly property int marginXXS: Math.round(2 * uiScale)
    readonly property int marginXS: Math.round(4 * uiScale)
    readonly property int marginS: Math.round(6 * uiScale)
    readonly property int marginM: Math.round(9 * uiScale)
    readonly property int marginL: Math.round(13 * uiScale)
    readonly property int marginXL: Math.round(18 * uiScale)

    // --- Medidas estruturais (escalam junto) ---
    readonly property int railWidth: Math.round(56 * uiScale)
    readonly property int panelCover: Math.round(340 * uiScale)
    readonly property int paneMinWidth: Math.round(360 * uiScale)

    // --- Sombra da capa (design/Main.dc.html: 0 18px 40px rgba(0,0,0,0.55)) ---
    readonly property int coverShadowBlur: Math.round(40 * uiScale)
    readonly property int coverShadowY: Math.round(18 * uiScale)
    readonly property color coverShadowColor: "#8c000000"

    // --- Motion ---
    // O interruptor. Ligado, toda duração abaixo vale 0: o app continua igual, só sem
    // transição. Existe por dois motivos que apontam para o mesmo lugar — a foto do gate de
    // fidelidade é tirada num instante fixo e pegaria qualquer animação pela metade, e
    // "movimento reduzido" é o que quem se incomoda com tela que se mexe precisa poder pedir.
    property bool reduzirMovimento: false

    // Ligado SÓ por `--measure`, e separado do de cima de propósito: ele não desliga
    // movimento, desliga efeito cuja cor vem do acervo de quem roda. O halo do painel tem a
    // cor da capa que está tocando, e o gate mede 15 pontos fixos com tolerância de 3 níveis
    // por canal — um deles a 16 px da capa. Ou o halo sai da foto, ou o gate mede sorte.
    property bool medindo: false

    readonly property int animationFaster: theme.reduzirMovimento ? 0 : 75
    readonly property int animationFast: theme.reduzirMovimento ? 0 : 150
    readonly property int animationNormal: theme.reduzirMovimento ? 0 : 300
    readonly property int animationSlow: theme.reduzirMovimento ? 0 : 450
    readonly property int animationSlowest: theme.reduzirMovimento ? 0 : 750
    readonly property int easingType: Easing.OutCubic

    // O pulo do coração tem forma própria e não é transição: sobe rápido passando do alvo
    // (OutBack devolve o excesso) e desce um pouco mais devagar. Separado dos tokens acima
    // porque reaproveitar `animationFast` nos dois lados apagaria justamente a diferença
    // entre confirmar um gesto e comemorar um.
    readonly property int animationPop: theme.reduzirMovimento ? 0 : 120
    readonly property int animationPopBack: theme.reduzirMovimento ? 0 : 140
    readonly property real popEscala: 1.3
    readonly property real popOvershoot: 2.5

    // O passo entre um item e o próximo numa entrada escalonada. Um consumidor só, a tela
    // vazia: ela é rara e ninguém a espera para fazer outra coisa. Numa lista de mil linhas o
    // mesmo efeito é a definição de animação que atrapalha, e o token existir aqui não é
    // convite para usá-lo lá.
    readonly property int animationStagger: theme.reduzirMovimento ? 0 : 60
}
