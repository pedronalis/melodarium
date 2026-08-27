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

    // --- Typography (Noctalia Style.qml, ratio 1.0) ---
    readonly property string fontFamily: "Inter"
    readonly property string fontFamilyFixed: "JetBrains Mono"
    readonly property real fontSizeXXS: 8
    readonly property real fontSizeXS: 9
    readonly property real fontSizeS: 10
    readonly property real fontSizeM: 11
    readonly property real fontSizeL: 13
    readonly property real fontSizeXL: 16
    readonly property real fontSizeXXL: 18
    readonly property real fontSizeXXXL: 24
    readonly property int fontWeightRegular: 400
    readonly property int fontWeightMedium: 500
    readonly property int fontWeightSemiBold: 600
    readonly property int fontWeightBold: 700

    // --- Shape ---
    readonly property int radiusXXS: 4
    readonly property int radiusXS: 8
    readonly property int radiusS: 12
    readonly property int radiusM: 16
    readonly property int radiusL: 20
    readonly property int iRadiusXS: 8
    readonly property int iRadiusS: 12
    readonly property int iRadiusM: 16
    readonly property int borderS: 1
    readonly property int borderM: 2
    readonly property int borderL: 3

    // --- Spacing ---
    readonly property int marginXXS: 2
    readonly property int marginXS: 4
    readonly property int marginS: 6
    readonly property int marginM: 9
    readonly property int marginL: 13
    readonly property int marginXL: 18

    // --- Motion ---
    readonly property int animationFaster: 75
    readonly property int animationFast: 150
    readonly property int animationNormal: 300
    readonly property int animationSlow: 450
    readonly property int animationSlowest: 750
    readonly property int easingType: Easing.OutCubic
}
