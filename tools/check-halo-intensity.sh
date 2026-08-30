#!/usr/bin/env bash
# Render the deterministic synthetic halo both enabled and disabled. The near probe proves that
# the effect is visibly present at the requested subtle intensity; the far probe proves that the
# change remains local to the artwork panel instead of tinting the whole window.
set -uo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-halo-intensity: executable not found: $BIN"
    exit 1
fi

if ! python3 -c "import PIL" 2>/dev/null; then
    echo "check-halo-intensity: python3-pillow is required"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"

shot() {
    local name="$1"
    shift
    QT_QPA_PLATFORM=offscreen \
    XDG_CONFIG_HOME="$TMP/config" \
    XDG_DATA_HOME="$TMP/data" \
    XDG_CACHE_HOME="$TMP/cache" \
        timeout 60 "$BIN" --measure 1100 --measure-height 700 --no-search \
        --halo-teste --shot "$TMP/$name.png" --delay 1800 "$@" >/dev/null 2>&1
    [ -s "$TMP/$name.png" ]
}

if ! shot halo-on --com-halo; then
    echo "check-halo-intensity: failed to render the enabled halo"
    exit 1
fi
if ! shot halo-off; then
    echo "check-halo-intensity: failed to render the disabled halo"
    exit 1
fi

python3 - "$TMP" <<'PY'
import sys
from PIL import Image

tmp = sys.argv[1]
enabled = Image.open(f"{tmp}/halo-on.png").convert("RGB")
disabled = Image.open(f"{tmp}/halo-off.png").convert("RGB")

def delta_at(point):
    on = enabled.getpixel(point)
    off = disabled.getpixel(point)
    return on, off, tuple(a - b for a, b in zip(on, off))

# The fixed synthetic orange focus is strongest below the artwork at this coordinate.
near_on, near_off, near = delta_at((400, 390))
near_peak = max(near)
if not 16 <= near_peak <= 19:
    print(
        "FAIL: halo peak outside the subtle-intensity band: "
        f"on={near_on} off={near_off} delta={near}, expected peak 16..19"
    )
    raise SystemExit(1)
if not near[0] > near[1] > near[2]:
    print(f"FAIL: halo color signature changed: delta={near}")
    raise SystemExit(1)

# The library background is outside the clipped artwork panel and must remain untouched.
far_on, far_off, far = delta_at((900, 655))
if max(abs(channel) for channel in far) > 1:
    print(f"FAIL: halo leaked into the library: on={far_on} off={far_off} delta={far}")
    raise SystemExit(1)

print(f"check-halo-intensity: near delta={near}, far delta={far}")
PY
