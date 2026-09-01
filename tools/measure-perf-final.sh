#!/usr/bin/env bash
# Reproduces the final performance ledger on an isolated snapshot of the real library.
set -euo pipefail

BIN="${1:-./build/melodarium}"
SOURCE_DB="${MELODARIUM_PERF_DB:-/home/pedro/.local/share/melodarium/melodarium/melodarium.db}"
SOURCE_CONFIG="${MELODARIUM_PERF_CONFIG:-/home/pedro/.config/melodarium/melodarium.conf}"
WIDTH=2560
HEIGHT=1440
PLATFORM="${MELODARIUM_PERF_PLATFORM:-offscreen}"
STATE_ONLY="${MELODARIUM_PERF_STATE_ONLY:-}"

case "$STATE_ONLY" in
    ""|stopped|paused|playing) ;;
    *) echo "measure-perf-final: invalid MELODARIUM_PERF_STATE_ONLY: $STATE_ONLY"; exit 2 ;;
esac

if [ ! -x "$BIN" ]; then
    echo "measure-perf-final: executable not found: $BIN"
    exit 1
fi
for command_name in sqlite3 ffmpeg; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "measure-perf-final: $command_name is required"
        exit 1
    fi
done
if [ ! -r "$SOURCE_DB" ]; then
    echo "measure-perf-final: source database not readable: $SOURCE_DB"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

prepare_snapshot() {
    local root="$1"
    mkdir -p "$root/config/melodarium" "$root/data/melodarium/melodarium" \
             "$root/cache"
    sqlite3 -readonly "$SOURCE_DB" \
        ".backup '$root/data/melodarium/melodarium/melodarium.db'"
    if [ -r "$SOURCE_CONFIG" ]; then
        cp "$SOURCE_CONFIG" "$root/config/melodarium/melodarium.conf"
    fi
}

run_app() {
    local root="$1"
    shift
    QT_QPA_PLATFORM="$PLATFORM" MELODIA_NULL_AO=1 \
    XDG_CONFIG_HOME="$root/config" XDG_DATA_HOME="$root/data" XDG_CACHE_HOME="$root/cache" \
    QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 "$BIN" "$@"
}

measure_startup() {
    local root="$1"
    local label="$2"
    local output="$root/startup-$label.log"
    local start_ns end_ns elapsed_ms
    start_ns=$(date +%s%N)
    run_app "$root" --measure "$WIDTH" --measure-height "$HEIGHT" --no-search \
        --delay 50 >"$output" 2>&1
    end_ns=$(date +%s%N)
    elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
    if ! grep -q 'MEDIDA ' "$output"; then
        echo "measure-perf-final: startup run did not reach the measured frame"
        tail -20 "$output"
        exit 1
    fi
    printf '%s\n' "$elapsed_ms"
}

median() {
    sort -n | awk '{ values[NR] = $1 } END {
        if (NR % 2) print values[(NR + 1) / 2]
        else printf "%.1f\n", (values[NR / 2] + values[NR / 2 + 1]) / 2
    }'
}

printf 'PERF_CONTEXT geometry=%sx%s source_tracks=' "$WIDTH" "$HEIGHT"
sqlite3 -readonly "$SOURCE_DB" \
    'SELECT count(*) FROM tracks WHERE removed_at IS NULL;'

if [ -z "$STATE_ONLY" ]; then
    cold_samples=()
    for sample in 1 2 3 4 5; do
        root="$TMP/cold-$sample"
        prepare_snapshot "$root"
        cold_samples+=("$(measure_startup "$root" "$sample")")
    done

    warm_root="$TMP/warm"
    prepare_snapshot "$warm_root"
    warm_samples=()
    for sample in 1 2 3 4 5; do
        warm_samples+=("$(measure_startup "$warm_root" "$sample")")
    done
    printf 'STARTUP cold_process_ms=%s median_ms=%s\n' \
        "${cold_samples[*]}" "$(printf '%s\n' "${cold_samples[@]}" | median)"
    printf 'STARTUP warm_process_ms=%s median_ms=%s\n' \
        "${warm_samples[*]}" "$(printf '%s\n' "${warm_samples[@]}" | median)"
fi

ffmpeg -loglevel error -f lavfi -i 'sine=frequency=330:duration=30' \
    -y "$TMP/tone.wav"

measure_state() {
    local state="$1"
    local root="$TMP/state-$state"
    local output="$root/app.log"
    local -a args=(--measure "$WIDTH" --measure-height "$HEIGHT" --no-search
                   --halo-teste --com-halo --measure-halo-activity "$state"
                   --halo-activity-duration 26000 --delay 35000)
    prepare_snapshot "$root"
    if [ "$state" != "stopped" ]; then
        args+=(--play-track "$TMP/tone.wav")
    fi

    QT_QPA_PLATFORM="$PLATFORM" MELODIA_NULL_AO=1 \
    XDG_CONFIG_HOME="$root/config" XDG_DATA_HOME="$root/data" XDG_CACHE_HOME="$root/cache" \
    QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
        "$BIN" "${args[@]}" >"$output" 2>&1 &
    local pid=$!
    sleep 5
    if [ ! -r "/proc/$pid/stat" ] || [ ! -r "/proc/$pid/smaps_rollup" ]; then
        echo "measure-perf-final: $state process exited before sampling"
        tail -20 "$output"
        exit 1
    fi
    local start_user start_sys end_user end_sys pss_kb
    read -r start_user start_sys < <(awk '{print $14, $15}' "/proc/$pid/stat")
    pss_kb=$(awk '/^Pss:/ {print $2}' "/proc/$pid/smaps_rollup")
    sleep 20
    read -r end_user end_sys < <(awk '{print $14, $15}' "/proc/$pid/stat")
    wait "$pid"
    local ticks=$((end_user + end_sys - start_user - start_sys))
    local activity
    activity=$(grep -ao 'HALO_ACTIVITY .*' "$output" | tail -1 || true)
    if [ -z "$activity" ]; then
        echo "measure-perf-final: missing $state activity result"
        tail -20 "$output"
        exit 1
    fi
    printf 'CPU state=%s window=20s ticks=%d ticks_per_second=%s pss_kb=%s\n' \
        "$state" "$ticks" "$(awk -v n="$ticks" 'BEGIN { printf "%.2f", n / 20 }')" \
        "$pss_kb"
    printf '%s\n' "$activity"
}

if [ -n "$STATE_ONLY" ]; then
    measure_state "$STATE_ONLY"
    exit 0
fi

measure_state stopped
measure_state paused
measure_state playing

scroll_root="$TMP/scroll"
prepare_snapshot "$scroll_root"
scroll_output="$scroll_root/app.log"
run_app "$scroll_root" --measure "$WIDTH" --measure-height "$HEIGHT" --no-search \
    --measure-scroll --delay 15000 >"$scroll_output" 2>&1
scroll_line=$(grep -ao 'SCROLL_PERF .*' "$scroll_output" | tail -1 || true)
if [ -z "$scroll_line" ]; then
    echo "measure-perf-final: missing scroll result"
    tail -20 "$scroll_output"
    exit 1
fi
printf '%s\n' "$scroll_line"
