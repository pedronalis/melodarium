#!/usr/bin/env bash
# Capture the real Qt/QML application with a disposable, copyright-safe media library.
set -euo pipefail

SOURCE_ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUTPUT_DIR="$SOURCE_ROOT/docs/assets/screenshots"
BIN="${1:-$SOURCE_ROOT/build/melodarium}"

cd "$SOURCE_ROOT"

gallery_files=(
    "$OUTPUT_DIR/now-playing.png"
    "$OUTPUT_DIR/library.png"
    "$OUTPUT_DIR/collections.png"
    "$OUTPUT_DIR/podcasts.png"
    "$OUTPUT_DIR/search.png"
)

verify_gallery() {
    python3 - "${gallery_files[@]}" <<'PY'
import hashlib
import statistics
import sys
from pathlib import Path

from PIL import Image, ImageStat

digests = set()
for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    if not path.is_file() or path.stat().st_size == 0:
        print(f"GALLERY_CAPTURE_MISSING {path}")
        raise SystemExit(1)
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        if rgb.size != (1100, 700):
            print(f"GALLERY_CAPTURE_SIZE {path} {rgb.width}x{rgb.height}")
            raise SystemExit(1)
        sample = rgb.resize((110, 70))
        spread = statistics.fmean(ImageStat.Stat(sample).stddev)
        colors = sample.getcolors(maxcolors=110 * 70)
        color_count = len(colors) if colors is not None else 110 * 70
        if spread < 8 or color_count < 48:
            print(
                f"GALLERY_CAPTURE_FLAT {path} "
                f"spread={spread:.2f} colors={color_count}"
            )
            raise SystemExit(1)
        if path.name in {"now-playing.png", "library.png", "collections.png"}:
            artwork = rgb.crop((65, 18, 390, 345)).resize((130, 130))
            artwork_pixels = (
                artwork.get_flattened_data()
                if hasattr(artwork, "get_flattened_data")
                else artwork.getdata()
            )
            chromatic = sum(
                1
                for red, green, blue in artwork_pixels
                if max(red, green, blue) >= 70 and max(red, green, blue) - min(red, green, blue) >= 24
            )
            if chromatic < 800:
                print(f"GALLERY_CAPTURE_ARTWORK {path} chromatic={chromatic}")
                raise SystemExit(1)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest in digests:
        print(f"GALLERY_CAPTURE_DUPLICATE {path}")
        raise SystemExit(1)
    digests.add(digest)
    print(
        f"GALLERY_CAPTURE_OK {path.relative_to(Path.cwd())} "
        f"1100x700 spread={spread:.2f} colors={color_count}"
    )
PY
}

if [ "${MELODARIUM_GALLERY_VERIFY_ONLY:-0}" = "1" ]; then
    verify_gallery
    exit 0
fi

if [ ! -x "$BIN" ]; then
    echo "GALLERY_CAPTURE_DEPENDENCY executable not found: $BIN"
    exit 1
fi
for dependency in ffmpeg magick sqlite3 python3 timeout; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "GALLERY_CAPTURE_DEPENDENCY missing command: $dependency"
        exit 1
    fi
done
if ! python3 -c 'import PIL' >/dev/null 2>&1; then
    echo "GALLERY_CAPTURE_DEPENDENCY missing module: python3-pillow"
    exit 1
fi

GALLERY_TMP=$(mktemp -d)
cleanup() {
    if [[ -n "${GALLERY_TMP:-}" && "$GALLERY_TMP" == /tmp/* && -d "$GALLERY_TMP" ]]; then
        rm -rf -- "$GALLERY_TMP"
    fi
}
trap cleanup EXIT

CONFIG_HOME="$GALLERY_TMP/config"
DATA_HOME="$GALLERY_TMP/data"
CACHE_HOME="$GALLERY_TMP/cache"
MEDIA_ROOT="$GALLERY_TMP/media"
COVER_ROOT="$MEDIA_ROOT/artwork"
mkdir -p "$CONFIG_HOME/melodarium" "$DATA_HOME" "$CACHE_HOME" "$COVER_ROOT" "$OUTPUT_DIR"

# The release gallery must never inherit the developer's library or settings. QSettings reads
# only this disposable file, and the path itself points inside the same disposable root.
printf '[library]\npath=%s\n' "$MEDIA_ROOT" >"$CONFIG_HOME/melodarium/melodarium.conf"

# Original geometric artwork: no downloaded assets and no third-party album covers.
magick -size 900x900 gradient:'#100b2b-#bd72ff' \
    -fill '#f6eaff33' -stroke '#f6eaffaa' -strokewidth 3 \
    -draw 'circle 450,450 450,105 circle 450,450 450,190 circle 450,450 450,280' \
    -fill '#100b2b99' -stroke none -draw 'circle 450,450 450,335' \
    -fill '#fff3bd' -draw 'circle 450,450 450,418' \
    "$COVER_ROOT/night-geometry.png"

magick -size 900x900 gradient:'#051724-#1686a8' \
    -fill none -stroke '#b8f4ff99' -strokewidth 7 \
    -draw "path 'M 0,190 C 170,80 290,300 455,190 S 735,80 900,190'" \
    -draw "path 'M 0,340 C 170,230 290,450 455,340 S 735,230 900,340'" \
    -draw "path 'M 0,490 C 170,380 290,600 455,490 S 735,380 900,490'" \
    -draw "path 'M 0,640 C 170,530 290,750 455,640 S 735,530 900,640'" \
    -fill '#e4fbff' -stroke none -draw 'circle 690,240 690,260' \
    "$COVER_ROOT/tidal-memory.png"

magick -size 900x900 xc:'#151515' \
    -fill '#f4c95d' -draw 'rectangle 85,85 365,365 rectangle 535,535 815,815' \
    -fill '#d95d8c' -draw 'rectangle 535,85 815,365' \
    -fill '#70d6c8' -draw 'rectangle 85,535 365,815' \
    -fill '#151515' -draw 'circle 450,450 450,315' \
    -fill '#f4f1ea' -draw 'circle 450,450 450,425' \
    "$COVER_ROOT/quiet-machines.png"

magick -size 900x900 gradient:'#321137-#f06479' \
    -fill '#ffe9a8aa' -stroke none \
    -draw 'polygon 0,710 160,510 300,650 480,330 650,580 790,390 900,520 900,900 0,900' \
    -fill '#fff7df' -draw 'circle 210,210 210,285' \
    "$COVER_ROOT/afterglow-atlas.png"

magick -size 900x900 xc:'#0b1118' -fill none -stroke '#78d9ff' -strokewidth 5 \
    -draw 'circle 450,450 450,125 circle 450,450 450,220 circle 450,450 450,315' \
    -stroke '#ff8cca' -draw 'line 110,520 790,380 line 150,610 750,290' \
    -fill '#f2f7fa' -stroke none -draw 'circle 450,450 450,435' \
    "$COVER_ROOT/night-signals.png"

magick -size 900x900 gradient:'#0b251d-#42b883' \
    -fill none -stroke '#d8ffeccc' -strokewidth 4 \
    -draw "path 'M 80,520 C 220,210 340,700 470,390 S 710,190 830,500'" \
    -draw "path 'M 80,610 C 220,300 340,790 470,480 S 710,280 830,590'" \
    -fill '#d8ffec' -stroke none -draw 'circle 450,260 450,290' \
    "$COVER_ROOT/small-hours.png"

# Generate one valid lossless source and expose it at distinct paths. The database metadata is
# intentionally synthetic; only the pixels and application behavior are under demonstration.
ffmpeg -hide_banner -loglevel error -f lavfi \
    -i 'sine=frequency=392:duration=90:sample_rate=44100' -c:a flac \
    -metadata title='Night Bloom' -metadata artist='Aurora Circuit' \
    -y "$MEDIA_ROOT/master.flac"

NIGHT_ROOT="$MEDIA_ROOT/night-geometry"
TIDAL_ROOT="$MEDIA_ROOT/tidal-memory"
MACHINES_ROOT="$MEDIA_ROOT/quiet-machines"
AFTERGLOW_ROOT="$MEDIA_ROOT/afterglow-atlas"
mkdir -p "$NIGHT_ROOT" "$TIDAL_ROOT" "$MACHINES_ROOT" "$AFTERGLOW_ROOT"
cp "$COVER_ROOT/night-geometry.png" "$NIGHT_ROOT/cover.png"
cp "$COVER_ROOT/tidal-memory.png" "$TIDAL_ROOT/cover.png"
cp "$COVER_ROOT/quiet-machines.png" "$MACHINES_ROOT/cover.png"
cp "$COVER_ROOT/afterglow-atlas.png" "$AFTERGLOW_ROOT/cover.png"

for track_name in night-bloom parallel-light low-orbit glass-horizon; do
    ln "$MEDIA_ROOT/master.flac" "$NIGHT_ROOT/$track_name.flac"
done
for track_name in static-tides soft-current blue-hour shoreline-code; do
    ln "$MEDIA_ROOT/master.flac" "$TIDAL_ROOT/$track_name.flac"
done
for track_name in warm-cache quiet-machines; do
    ln "$MEDIA_ROOT/master.flac" "$MACHINES_ROOT/$track_name.flac"
done
for track_name in last-process dawn-index; do
    ln "$MEDIA_ROOT/master.flac" "$AFTERGLOW_ROOT/$track_name.flac"
done
ln "$MEDIA_ROOT/master.flac" "$MEDIA_ROOT/signal-path-episode.flac"
ln "$MEDIA_ROOT/master.flac" "$MEDIA_ROOT/small-hours-episode.flac"

run_app() {
    XDG_CONFIG_HOME="$CONFIG_HOME" \
    XDG_DATA_HOME="$DATA_HOME" \
    XDG_CACHE_HOME="$CACHE_HOME" \
    MELODIA_NULL_AO=1 \
    QT_QPA_PLATFORM=offscreen \
    QT_LOGGING_RULES='*.debug=true' \
    QT_FORCE_STDERR_LOGGING=1 \
        timeout 35 "$BIN" "$@"
}

# Let the application create and migrate its own database before adding the public fixture.
if ! run_app --measure 1100 --measure-height 700 --pane empty --no-search \
        --sem-animacao --delay 80 >"$GALLERY_TMP/initialize.log" 2>&1; then
    echo "GALLERY_CAPTURE_INIT_FAILED"
    tail -20 "$GALLERY_TMP/initialize.log"
    exit 1
fi

DB="$DATA_HOME/melodarium/melodarium/melodarium.db"
if [ ! -s "$DB" ]; then
    echo "GALLERY_CAPTURE_INIT_FAILED database was not created"
    exit 1
fi

sqlite3 "$DB" <<SQL
BEGIN;
INSERT INTO artists (id, name, sort_name) VALUES
    (1, 'Aurora Circuit', 'Aurora Circuit'),
    (2, 'Sombra Azul', 'Sombra Azul'),
    (3, 'Northbound Signals', 'Northbound Signals'),
    (4, 'Lumen Archive', 'Lumen Archive');
INSERT INTO genres (id, name) VALUES
    (1, 'Ambient'), (2, 'Electronic'), (3, 'Post-rock'), (4, 'Downtempo');
INSERT INTO albums (id, title, album_artist_id, year, cover_path, cover_source) VALUES
    (1, 'Night Geometry', 1, 2026, '$COVER_ROOT/night-geometry.png', 'file'),
    (2, 'Tidal Memory', 2, 2024, '$COVER_ROOT/tidal-memory.png', 'file'),
    (3, 'Quiet Machines', 3, 2025, '$COVER_ROOT/quiet-machines.png', 'file'),
    (4, 'Afterglow Atlas', 4, 2023, '$COVER_ROOT/afterglow-atlas.png', 'file');
INSERT INTO tracks
    (id, path, mtime, size, duration_ms, sample_rate, bits_per_sample, channels,
     bitrate_kbps, codec, title, track_no, year, artist_id, album_id, genre_id,
     added_at, source_kind, liked_at)
VALUES
    (1, '$NIGHT_ROOT/night-bloom.flac', 1, 1, 318000, 96000, 24, 2, 2800, 'FLAC', 'Night Bloom', 1, 2026, 1, 1, 1, 1788200100, 'local_file', 1788280200),
    (2, '$NIGHT_ROOT/parallel-light.flac', 1, 1, 274000, 96000, 24, 2, 2600, 'FLAC', 'Parallel Light', 2, 2026, 1, 1, 1, 1788200200, 'local_file', NULL),
    (3, '$NIGHT_ROOT/low-orbit.flac', 1, 1, 361000, 96000, 24, 2, 2900, 'FLAC', 'Low Orbit', 3, 2026, 1, 1, 2, 1788200300, 'local_file', 1788280300),
    (4, '$NIGHT_ROOT/glass-horizon.flac', 1, 1, 246000, 96000, 24, 2, 2400, 'FLAC', 'Glass Horizon', 4, 2026, 1, 1, 2, 1788200400, 'local_file', NULL),
    (5, '$TIDAL_ROOT/static-tides.flac', 1, 1, 405000, 48000, 24, 2, 1800, 'FLAC', 'Static Tides', 1, 2024, 2, 2, 4, 1788200500, 'local_file', NULL),
    (6, '$TIDAL_ROOT/soft-current.flac', 1, 1, 289000, 48000, 24, 2, 1700, 'FLAC', 'Soft Current', 2, 2024, 2, 2, 4, 1788200600, 'local_file', 1788280600),
    (7, '$TIDAL_ROOT/blue-hour.flac', 1, 1, 332000, 48000, 24, 2, 1900, 'FLAC', 'Blue Hour', 3, 2024, 2, 2, 1, 1788200700, 'local_file', NULL),
    (8, '$TIDAL_ROOT/shoreline-code.flac', 1, 1, 257000, 48000, 24, 2, 1750, 'FLAC', 'Shoreline Code', 4, 2024, 2, 2, 2, 1788200800, 'local_file', NULL),
    (9, '$MACHINES_ROOT/warm-cache.flac', 1, 1, 298000, 44100, 16, 2, 980, 'FLAC', 'Warm Cache', 1, 2025, 3, 3, 3, 1788200900, 'local_file', NULL),
    (10, '$MACHINES_ROOT/quiet-machines.flac', 1, 1, 344000, 44100, 16, 2, 1050, 'FLAC', 'Quiet Machines', 2, 2025, 3, 3, 3, 1788201000, 'local_file', 1788281000),
    (11, '$AFTERGLOW_ROOT/last-process.flac', 1, 1, 231000, 44100, 16, 2, 920, 'FLAC', 'Last Process', 1, 2023, 4, 4, 2, 1788201100, 'local_file', NULL),
    (12, '$AFTERGLOW_ROOT/dawn-index.flac', 1, 1, 386000, 44100, 16, 2, 1100, 'FLAC', 'Dawn Index', 2, 2023, 4, 4, 1, 1788201200, 'local_file', NULL);
INSERT INTO track_stats (track_id, play_count, skip_count, last_played_at, first_seen_at) VALUES
    (1, 14, 0, 1788280000, 1788200100), (3, 8, 1, 1788270000, 1788200300),
    (6, 11, 0, 1788260000, 1788200600), (10, 5, 0, 1788250000, 1788201000);
INSERT INTO tags (id, name) VALUES (1, 'focus'), (2, 'night'), (3, 'headphones');
INSERT INTO track_tags (track_id, tag_id) VALUES
    (1, 2), (1, 3), (2, 1), (3, 2), (5, 3), (6, 1), (10, 1);
INSERT INTO collections (id, name, created_at) VALUES
    (1, 'Night Drive', 1788210000),
    (2, 'Deep Focus', 1788220000),
    (3, 'Sunday Morning', 1788230000);
INSERT INTO collection_tracks (collection_id, track_id, position, added_at) VALUES
    (1, 1, 1000, 1788210100), (1, 3, 2000, 1788210200),
    (1, 5, 3000, 1788210300), (1, 8, 4000, 1788210400),
    (1, 10, 5000, 1788210500), (1, 12, 6000, 1788210600),
    (2, 2, 1000, 1788220100), (2, 6, 2000, 1788220200),
    (2, 9, 3000, 1788220300), (3, 7, 1000, 1788230100);
INSERT INTO podcast_shows
    (id, title, feed_url, last_checked_at, cover_path, auto_download, retention_count)
VALUES
    (1, 'Night Signals', 'https://example.test/night-signals.xml', 1788280000,
     '$COVER_ROOT/night-signals.png', 0, 10),
    (2, 'Small Hours', 'https://example.test/small-hours.xml', 1788270000,
     '$COVER_ROOT/small-hours.png', 0, 0);
INSERT INTO podcast_episodes
    (id, show_id, guid, title, published_at, duration_ms, local_path, position_ms,
     played, last_played_at, remote_url, download_state)
VALUES
    (101, 1, 'night-signals-42', 'The architecture of listening', 1788270000, 2860000,
     '$MEDIA_ROOT/signal-path-episode.flac', 742000, 0, 1788280000,
     'https://example.test/audio/night-signals-42.flac', 'done'),
    (102, 1, 'night-signals-41', 'Why local software still matters', 1787665200, 2520000,
     NULL, 0, 0, NULL, 'https://example.test/audio/night-signals-41.flac', 'none'),
    (201, 2, 'small-hours-18', 'Designing for the quiet hours', 1787060400, 3180000,
     '$MEDIA_ROOT/small-hours-episode.flac', 0, 1, 1787146800,
     'https://example.test/audio/small-hours-18.flac', 'done'),
    (202, 2, 'small-hours-17', 'A field guide to digital calm', 1786455600, 2940000,
     NULL, 0, 0, NULL, 'https://example.test/audio/small-hours-17.flac', 'none');
COMMIT;
SQL

capture() {
    local name="$1"
    shift
    local output="$OUTPUT_DIR/$name.png"
    local log="$GALLERY_TMP/$name.log"
    if ! run_app --measure 1100 --measure-height 700 --sem-animacao \
            --shot "$output" --delay 2400 "$@" >"$log" 2>&1; then
        echo "GALLERY_CAPTURE_FAILED $name"
        tail -20 "$log"
        exit 1
    fi
    if rg -q 'is not a type|Unable to assign|ReferenceError|TypeError|Binding loop|Cannot assign' \
            "$log"; then
        echo "GALLERY_CAPTURE_QML_ERROR $name"
        rg 'is not a type|Unable to assign|ReferenceError|TypeError|Binding loop|Cannot assign' \
            "$log" | head -8
        exit 1
    fi
    if ! rg -Fq "SHOT $output" "$log"; then
        echo "GALLERY_CAPTURE_FAILED $name did not confirm the output path"
        tail -20 "$log"
        exit 1
    fi
}

capture now-playing --pane library --open-album 1 \
    --play-track "$NIGHT_ROOT/night-bloom.flac" --no-search --com-halo
capture library --pane library --play-queue --queue-index 2 --no-search
capture collections --pane collections --open-collection 1 \
    --play-track "$NIGHT_ROOT/night-bloom.flac" --no-search
capture podcasts --pane podcast --play-episode 101 --no-search
capture search --pane library --search-text Night

verify_gallery
