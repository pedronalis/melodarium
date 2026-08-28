pragma Singleton

import QtQuick
import Melodia.App

QtObject {
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

    // --- Escala da interface ---
    // Todo tamanho abaixo nasceu de um desenho feito para uma janela de 1100x700. Numa tela
    // de 2540x1384 esses mesmos números viram uma interface perdida no canto — foi a
    // reclamação do Pedro em 28/08: "em uma escala microscópica". Main.qml escreve aqui o
    // fator derivado do tamanho real da janela, e a escada inteira acompanha.
    property real uiScale: 1.0

    // --- Typography (Noctalia Style.qml, ratio 1.0) ---
    readonly property string fontFamily: "Inter"
    readonly property string fontFamilyFixed: "JetBrains Mono"
    readonly property real fontSizeXXS: 8 * uiScale
    readonly property real fontSizeXS: 9 * uiScale
    readonly property real fontSizeS: 10 * uiScale
    readonly property real fontSizeM: 11 * uiScale
    readonly property real fontSizeL: 13 * uiScale
    readonly property real fontSizeXL: 16 * uiScale
    readonly property real fontSizeXXL: 18 * uiScale
    readonly property real fontSizeXXXL: 24 * uiScale
    readonly property int fontWeightRegular: 400
    readonly property int fontWeightMedium: 500
    readonly property int fontWeightSemiBold: 600
    readonly property int fontWeightBold: 700

    // --- Shape ---
    readonly property int radiusXXS: Math.round(4 * uiScale)
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

    // --- Motion ---
    readonly property int animationFaster: 75
    readonly property int animationFast: 150
    readonly property int animationNormal: 300
    readonly property int animationSlow: 450
    readonly property int animationSlowest: 750
    readonly property int easingType: Easing.OutCubic
}
