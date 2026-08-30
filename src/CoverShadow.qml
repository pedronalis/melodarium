import QtQuick
import Melodarium.App

// The two artwork layers crossfade, but their shadow is the same shape and color. Keeping the
// shadow outside those layers avoids calculating the same software blur twice. During a resize
// the last finished texture is transformed with the cover; after the geometry settles, the
// exact original raster parameters are applied once.
Item {
    id: root

    property real radius: Theme.radiusM

    readonly property real fracaoPendente:
        (Theme.coverShadowBlur + Theme.coverShadowY) / 340.0
    readonly property real raioPendente:
        root.width > 0 ? root.radius * sombra.base / root.width : -1
    readonly property int blurPendente: Theme.coverShadowBlur
    readonly property int deslocamentoYPendente: Theme.coverShadowY

    // These defaults are the original 1100x700 design values. They let the first texture paint
    // at a valid size even if Component.onCompleted runs before the parent has geometry.
    function agendarRaster() {
        estabilizaSombra.restart()
    }

    function atualizarRaster() {
        if (!(root.width > 0))
            return

        if (Math.abs(sombra.fracaoRasterizada - root.fracaoPendente) < 0.0001
                && Math.abs(sombra.raioRasterizado - root.raioPendente) < 0.0001
                && sombra.blurRasterizado === root.blurPendente
                && sombra.deslocamentoYRasterizado === root.deslocamentoYPendente)
            return

        sombra.fracaoRasterizada = root.fracaoPendente
        sombra.raioRasterizado = root.raioPendente
        sombra.blurRasterizado = root.blurPendente
        sombra.deslocamentoYRasterizado = root.deslocamentoYPendente
        sombra.requestPaint()
    }

    onFracaoPendenteChanged: root.agendarRaster()
    onRaioPendenteChanged: root.agendarRaster()
    onBlurPendenteChanged: root.agendarRaster()
    onDeslocamentoYPendenteChanged: root.agendarRaster()

    Timer {
        id: estabilizaSombra
        interval: 120
        repeat: false
        onTriggered: root.atualizarRaster()
    }

    Component.onCompleted: Qt.callLater(root.atualizarRaster)

    Canvas {
        id: sombra

        readonly property int base: 220
        property real fracaoRasterizada: (40 + 18) / 340.0
        property real raioRasterizado: 16 * 220 / 340.0
        property int blurRasterizado: 40
        property int deslocamentoYRasterizado: 18
        readonly property int lado:
            Math.round(sombra.base * (1 + sombra.fracaoRasterizada * 2))

        width: sombra.lado
        height: sombra.lado
        anchors.centerIn: parent
        transformOrigin: Item.Center
        scale: root.width > 0
               ? (root.width * (1 + sombra.fracaoRasterizada * 2)) / sombra.lado : 1

        Component.onCompleted: sombra.requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const f = sombra.base * sombra.fracaoRasterizada
            const fuga = sombra.lado * 3
            const escala = sombra.base / 340.0

            ctx.save()
            ctx.shadowColor = Theme.coverShadowColor
            ctx.shadowBlur = sombra.blurRasterizado * escala
            ctx.shadowOffsetX = fuga
            ctx.shadowOffsetY = sombra.deslocamentoYRasterizado * escala
            ctx.fillStyle = "#000000"
            ctx.beginPath()
            ctx.roundedRect(f - fuga, f, sombra.base, sombra.base,
                            sombra.raioRasterizado, sombra.raioRasterizado)
            ctx.fill()
            ctx.restore()
        }
    }
}
