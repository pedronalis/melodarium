#!/usr/bin/env bash
# Reproduce a cold asynchronous artwork switch with two real audio files and two solid covers.
# The final main cover must be blue; any red left in front is the stale-layer regression.
set -uo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-cover-switch: executable not found: $BIN"
    exit 1
fi
for command in ffmpeg magick sqlite3; do
    if ! command -v "$command" >/dev/null; then
        echo "check-cover-switch: $command is required"
        exit 1
    fi
done
if ! python3 -c "import PIL" 2>/dev/null; then
    echo "check-cover-switch: python3-pillow is required"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache" "$TMP/media/red" "$TMP/media/blue"

RED_TRACK="$TMP/media/red/red.flac"
BLUE_TRACK="$TMP/media/blue/blue.flac"
ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=440:d=8' -y "$RED_TRACK"
ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=660:d=8' -y "$BLUE_TRACK"
magick -size 420x420 xc:'#d02020' "$TMP/media/red/cover.png"
magick -size 420x420 xc:'#2060d0' "$TMP/media/blue/cover.png"

run_app() {
    QT_QPA_PLATFORM=offscreen \
    MELODIA_NULL_AO=1 \
    XDG_CONFIG_HOME="$TMP/config" \
    XDG_DATA_HOME="$TMP/data" \
    XDG_CACHE_HOME="$TMP/cache" \
        timeout 60 "$BIN" "$@"
}

if ! run_app --measure 1100 --measure-height 700 --no-search --delay 50 >/dev/null 2>&1; then
    echo "check-cover-switch: failed to initialize the temporary database"
    exit 1
fi

DB="$TMP/data/melodarium/melodarium/melodarium.db"
sqlite3 "$DB" <<SQL
INSERT INTO artists (id, name) VALUES (201, 'Red Artist'), (202, 'Blue Artist');
INSERT INTO albums (id, title, album_artist_id, year)
VALUES (201, 'Red Album', 201, 2025), (202, 'Blue Album', 202, 2026);
INSERT INTO tracks (id, path, mtime, size, title, artist_id, album_id, duration_ms, added_at)
VALUES (201, '$RED_TRACK', 1, 1, 'Red Track', 201, 201, 8000, 1),
       (202, '$BLUE_TRACK', 1, 1, 'Blue Track', 202, 202, 8000, 2);
SQL

SHOT="$TMP/switched.png"
if ! run_app --measure 1100 --measure-height 700 --no-search \
        --play-track "$RED_TRACK" --switch-track "$BLUE_TRACK" \
        --shot "$SHOT" --delay 2600 >/dev/null 2>&1 || [ ! -s "$SHOT" ]; then
    echo "check-cover-switch: failed to render the switched track"
    exit 1
fi

python3 - "$SHOT" <<'PY'
import sys
from PIL import Image

image = Image.open(sys.argv[1]).convert("RGB")
red = 0
blue = 0

# The main cover lives in the left playback panel. Excluding the rail and library ensures
# that only the large artwork can contribute thousands of saturated pixels.
for y in range(35, 430):
    for x in range(95, 480):
        r, g, b = image.getpixel((x, y))
        if r >= 150 and r >= g * 1.8 and r >= b * 1.8:
            red += 1
        if b >= 150 and b >= r * 1.8 and b >= g * 1.25:
            blue += 1

if blue < 20000:
    print(f"FAIL: final blue cover is not visible enough: blue={blue}, red={red}")
    raise SystemExit(1)
if red > 500:
    print(f"FAIL: old red cover remained in front: blue={blue}, red={red}")
    raise SystemExit(1)

print(f"check-cover-switch: final blue cover visible, blue={blue}, stale red={red}")
PY
