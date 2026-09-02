#!/usr/bin/env bash
# Clicks the real previous/next buttons in the bottom player and verifies the resulting
# libmpv queue position. All media, settings and database files live under a temporary XDG.
set -euo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-transport-controls: executable not found: $BIN"
    exit 1
fi
for dependency in ffmpeg sqlite3 xvfb-run xdotool; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "check-transport-controls: missing dependency: $dependency"
        exit 1
    fi
done

for qml in src/GlobalMiniPlayer.qml src/NowPlayingPanel.qml; do
    if ! rg -Fq 'AudioEngine.previous()' "$qml" || ! rg -Fq 'AudioEngine.next()' "$qml"; then
        echo "check-transport-controls: transport calls are unreachable in $qml"
        exit 1
    fi
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"

ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=frequency=440:duration=20' \
    -metadata title=One -y "$TMP/one.flac"
ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=frequency=660:duration=20' \
    -metadata title=Two -y "$TMP/two.flac"

XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen \
    timeout 15 "$BIN" --measure 1100 --no-search --delay 250 >/dev/null 2>&1

DB="$TMP/data/melodarium/melodarium/melodarium.db"
sqlite3 "$DB" "
INSERT INTO tracks (path,mtime,size,duration_ms,title,added_at,source_kind)
VALUES ('$TMP/one.flac',1,1,20000,'One',1,'local_file'),
       ('$TMP/two.flac',1,1,20000,'Two',2,'local_file');"

run_case() {
    local name="$1"
    local start_index="$2"
    local click_x="$3"
    local expected_index="$4"
    local expected_file="$5"
    local log="$TMP/$name.log"

    xvfb-run -a -s '-screen 0 1100x700x24' bash -c '
        set -euo pipefail
        bin="$1"
        data="$2"
        config="$3"
        cache="$4"
        start_index="$5"
        click_x="$6"
        log="$7"
        XDG_CONFIG_HOME="$config" XDG_DATA_HOME="$data" XDG_CACHE_HOME="$cache" \
        MELODIA_NULL_AO=1 QT_QPA_PLATFORM=xcb \
        QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
            "$bin" --measure 1100 --measure-height 700 --pane collections \
            --play-queue --queue-index "$start_index" --no-search --sem-animacao \
            --delay 4200 >"$log" 2>&1 &
        app_pid=$!
        sleep 2
        xdotool mousemove "$click_x" 659 click 1
        wait "$app_pid"
    ' _ "$BIN" "$TMP/data" "$TMP/config" "$TMP/cache" "$start_index" "$click_x" "$log"

    if rg -q 'is not a type|Unable to assign|ReferenceError|TypeError|Binding loop' "$log"; then
        echo "check-transport-controls: QML runtime error in $name"
        rg 'is not a type|Unable to assign|ReferenceError|TypeError|Binding loop' "$log" | head -8
        exit 1
    fi

    local line
    line=$(grep -ao 'MEDIDA .*' "$log" | tail -1)
    if [[ "$line" != *"fila=2 queuepos=$expected_index"* \
       || "$line" != *"arquivo=$expected_file"* ]]; then
        echo "check-transport-controls: $name did not reach queue index $expected_index"
        echo "$line"
        exit 1
    fi
}

# Coordinates are the centers of the previous/next IconButtons in the 1100x700 bottom bar.
run_case previous-wrap 0 537 1 "$TMP/two.flac"
run_case next-wrap 1 620 0 "$TMP/one.flac"

echo "check-transport-controls: previous 0->1 and next 1->0 through real bottom-bar clicks"
