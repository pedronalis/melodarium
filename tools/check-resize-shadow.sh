#!/usr/bin/env bash
# The main cover crossfades two artwork layers, but its shadow is independent of the artwork.
# Keep exactly one shadow texture and never feed transient resize values directly to Qt's
# synchronous software box blur. The settled raster still uses the original design tokens.
set -uo pipefail

SHADOW="${1:-src/CoverShadow.qml}"
COVER="${2:-src/RoundedCover.qml}"
PANEL="${3:-src/NowPlayingPanel.qml}"
fail=0

require_file() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "ok:    $file existe"
    else
        echo "FALHA: $file não existe"
        fail=1
    fi
}

require_in() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if [ -f "$file" ] && rg -q -- "$pattern" "$file"; then
        echo "ok:    $description"
    else
        echo "FALHA: $description"
        fail=1
    fi
}

reject_in() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    if [ -f "$file" ] && rg -q -- "$pattern" "$file"; then
        echo "FALHA: $description"
        fail=1
    else
        echo "ok:    $description"
    fi
}

require_file "$SHADOW"
require_in "$PANEL" 'CoverShadow[[:space:]]*\{' \
    "o painel instancia a sombra compartilhada"

shadow_instances=$(rg -c 'CoverShadow[[:space:]]*\{' "$PANEL" 2>/dev/null || true)
if [ "$shadow_instances" = "1" ]; then
    echo "ok:    existe uma única sombra para as duas capas"
else
    echo "FALHA: esperado 1 CoverShadow no painel, encontrado ${shadow_instances:-0}"
    fail=1
fi

reject_in "$COVER" 'shadowBlur|property bool shadow' \
    "as camadas de arte não carregam mais blur duplicado"
reject_in "$PANEL" 'shadow:[[:space:]]*true' \
    "as duas capas do crossfade não rasterizam sombras próprias"

require_in "$SHADOW" 'property real fracaoRasterizada:' \
    "a textura mantém a fração exata já rasterizada"
require_in "$SHADOW" 'property real raioRasterizado:' \
    "a textura mantém o raio exato já rasterizado"
require_in "$SHADOW" 'property int blurRasterizado:' \
    "a textura mantém o blur exato já rasterizado"
require_in "$SHADOW" 'property int deslocamentoYRasterizado:' \
    "a textura mantém o deslocamento exato já rasterizado"
require_in "$SHADOW" 'id: estabilizaSombra' \
    "mudanças transitórias passam por debounce"
require_in "$SHADOW" 'interval: 120' \
    "o debounce termina logo depois da rajada"
require_in "$SHADOW" 'onTriggered: root\.atualizarRaster\(\)' \
    "o fim da rajada atualiza a textura uma única vez"
require_in "$SHADOW" 'if \(!\(root\.width > 0\)\)' \
    "geometria ainda não montada não pode criar textura inválida"

# These are the original visual equations. Keeping them in the settled raster is what makes
# the before/after screenshots pixel-identical instead of trading responsiveness for fidelity.
require_in "$SHADOW" 'const escala = sombra\.base / 340\.0' \
    "a escala interna original da sombra foi preservada"
require_in "$SHADOW" 'ctx\.shadowBlur = sombra\.blurRasterizado \* escala' \
    "o blur final continua usando o valor original"
require_in "$SHADOW" 'ctx\.shadowOffsetY = sombra\.deslocamentoYRasterizado \* escala' \
    "o deslocamento final continua usando o valor original"

reject_in "$SHADOW" 'onRaioPendenteChanged:[[:space:]]*sombra\.requestPaint\(\)' \
    "resize não dispara o box blur diretamente"
reject_in "$SHADOW" 'onBlurPendenteChanged:[[:space:]]*sombra\.requestPaint\(\)' \
    "mudança transitória de blur não pinta diretamente"

if [ "$fail" -eq 0 ]; then
    echo "check-resize-shadow: one exact shadow, repainted only after resize settles"
fi

exit "$fail"
