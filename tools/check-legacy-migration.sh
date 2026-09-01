#!/usr/bin/env bash
set -euo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "FAIL: melodarium binary not found: $BIN"
    exit 1
fi
if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "FAIL: sqlite3 is required"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DATA="$TMP/data"
CACHE="$TMP/cache"
CONFIG="$TMP/config"
MUSIC="$TMP/music"

mkdir -p "$DATA/melodia/melodia" "$CACHE/melodia/melodia" \
         "$DATA/melodarium/melodarium" "$CACHE/melodarium/melodarium" \
         "$CONFIG/melodia" "$MUSIC"

sqlite3 "$DATA/melodia/melodia/melodia.db" \
    "CREATE TABLE legacy_marker (value TEXT); INSERT INTO legacy_marker VALUES ('preserved');"
printf 'legacy cache\n' > "$CACHE/melodia/melodia/legacy-cover.txt"
printf '[General]\nlibrary\\path=%s\n' "$MUSIC" > "$CONFIG/melodia/melodia.conf"

raw=$(XDG_DATA_HOME="$DATA" XDG_CACHE_HOME="$CACHE" XDG_CONFIG_HOME="$CONFIG" \
      QT_QPA_PLATFORM=offscreen MELODIA_NULL_AO=1 QT_FORCE_STDERR_LOGGING=1 \
      timeout 30 "$BIN" --scan 2>&1) || {
    printf '%s\n' "$raw"
    exit 1
}

NEW_DB="$DATA/melodarium/melodarium/melodarium.db"
if [ "$(sqlite3 "$NEW_DB" "SELECT value FROM legacy_marker" 2>/dev/null || true)" != "preserved" ]; then
    echo "FAIL: legacy database was not merged into the pre-existing empty destination"
    exit 1
fi
if [ ! -f "$CACHE/melodarium/melodarium/legacy-cover.txt" ]; then
    echo "FAIL: legacy cache was not merged into the pre-existing empty destination"
    exit 1
fi
if [ -e "$DATA/melodia/melodia/melodia.db" ]; then
    echo "FAIL: legacy database remained at the old path"
    exit 1
fi

echo "check-legacy-migration: database, cache and settings survived an existing destination"
