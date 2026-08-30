#!/usr/bin/env bash
# Build a deterministic search result set whose music artwork is red and whose podcast artwork
# is blue. Saturated pixels in the thumbnail column prove that the real images reached the QML
# delegate; text labels and generic glyphs cannot satisfy this gate.
set -uo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-search-covers: executable not found: $BIN"
    exit 1
fi
if ! command -v sqlite3 >/dev/null; then
    echo "check-search-covers: sqlite3 is required"
    exit 1
fi
if ! command -v magick >/dev/null; then
    echo "check-search-covers: ImageMagick is required"
    exit 1
fi
if ! python3 -c "import PIL" 2>/dev/null; then
    echo "check-search-covers: python3-pillow is required"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache" "$TMP/media/needle"

TRACK="$TMP/media/needle/needle.flac"
MUSIC_COVER="$TMP/media/needle/cover.png"
PODCAST_COVER="$TMP/media/podcast.png"
touch "$TRACK"
magick -size 40x40 xc:'#d02020' "$MUSIC_COVER"
magick -size 40x40 xc:'#2060d0' "$PODCAST_COVER"

run_app() {
    QT_QPA_PLATFORM=offscreen \
    XDG_CONFIG_HOME="$TMP/config" \
    XDG_DATA_HOME="$TMP/data" \
    XDG_CACHE_HOME="$TMP/cache" \
        timeout 60 "$BIN" "$@"
}

if ! run_app --measure 1100 --measure-height 700 --no-search --delay 50 >/dev/null 2>&1; then
    echo "check-search-covers: failed to initialize the temporary database"
    exit 1
fi

DB="$TMP/data/melodarium/melodarium/melodarium.db"
if [ ! -s "$DB" ]; then
    echo "check-search-covers: temporary database was not created"
    exit 1
fi

sqlite3 "$DB" <<SQL
INSERT INTO artists (id, name) VALUES (101, 'Needle Artist');
INSERT INTO albums (id, title, album_artist_id, year) VALUES (101, 'Needle Album', 101, 2026);
INSERT INTO tracks (id, path, mtime, size, title, artist_id, album_id, added_at)
VALUES (101, '$TRACK', 1, 1, 'Needle Song', 101, 101, 1);
INSERT INTO podcast_shows (id, title, cover_path)
VALUES (101, 'Needle Podcast', '$PODCAST_COVER');
INSERT INTO podcast_episodes (id, show_id, guid, title, published_at)
VALUES (101, 101, 'needle-episode', 'Needle Episode', 1);
SQL

SHOT="$TMP/search.png"
if ! run_app --measure 1100 --measure-height 700 --search-text Needle \
        --shot "$SHOT" --delay 1800 >/dev/null 2>&1 || [ ! -s "$SHOT" ]; then
    echo "check-search-covers: failed to render the populated search overlay"
    exit 1
fi

python3 - "$SHOT" <<'PY'
import sys
from PIL import Image

image = Image.open(sys.argv[1]).convert("RGB")

# At 1100x700 the existing 34 px thumbnail slot occupies this narrow column. Search the whole
# result viewport vertically so adding or removing a group does not make the probe brittle.
red_rows = set()
blue_rows = set()
for y in range(150, 570):
    for x in range(235, 290):
        red, green, blue = image.getpixel((x, y))
        if red >= 160 and red >= green * 2 and red >= blue * 2:
            red_rows.add(y)
        if blue >= 160 and blue >= red * 2 and blue >= green * 1.4:
            blue_rows.add(y)

def clusters(rows):
    groups = []
    for row in sorted(rows):
        if not groups or row > groups[-1][-1] + 1:
            groups.append([row])
        else:
            groups[-1].append(row)
    return [group for group in groups if len(group) >= 12]

red_clusters = clusters(red_rows)
blue_clusters = clusters(blue_rows)
if len(red_clusters) < 2:
    print(f"FAIL: expected red artwork on track and album rows, found {len(red_clusters)} row(s)")
    raise SystemExit(1)
if len(blue_clusters) < 1:
    print("FAIL: expected blue podcast artwork, found none")
    raise SystemExit(1)

print(
    "check-search-covers: "
    f"music rows={[(g[0], g[-1]) for g in red_clusters]}, "
    f"podcast rows={[(g[0], g[-1]) for g in blue_clusters]}"
)
PY
