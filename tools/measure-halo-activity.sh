#!/usr/bin/env bash
# Measures aggregate process CPU over the ledger's required 20-second window for one state.
set -euo pipefail

STATE="${1:?usage: measure-halo-activity.sh <playing|paused|hidden|stopped> [binary]}"
BIN="${2:-./build/melodarium}"
case "$STATE" in
    playing|paused|hidden|stopped) ;;
    *) echo "measure-halo-activity: invalid state: $STATE"; exit 2 ;;
esac
if [ ! -x "$BIN" ]; then
    echo "measure-halo-activity: executable not found: $BIN"
    exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "measure-halo-activity: ffmpeg is required"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"
ffmpeg -loglevel error -f lavfi -i "sine=frequency=330:duration=30" \
    -y "$TMP/tone.wav"

args=(--measure 1100 --measure-height 700 --no-search --halo-teste --com-halo
      --measure-halo-activity "$STATE" --halo-activity-duration 23000 --delay 26000)
if [ "$STATE" != "stopped" ]; then
    args+=(--play-track "$TMP/tone.wav")
fi

QT_QPA_PLATFORM=offscreen MELODIA_NULL_AO=1 \
XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
    "$BIN" "${args[@]}" >"$TMP/app.log" 2>&1 &
pid=$!

sleep 2
if [ ! -r "/proc/$pid/stat" ]; then
    echo "measure-halo-activity: process exited before measurement"
    tail -20 "$TMP/app.log"
    exit 1
fi
read -r start_user start_sys < <(awk '{print $14, $15}' "/proc/$pid/stat")
sleep 20
read -r end_user end_sys < <(awk '{print $14, $15}' "/proc/$pid/stat")
wait "$pid"

ticks=$((end_user + end_sys - start_user - start_sys))
line=$(grep -ao 'HALO_ACTIVITY .*' "$TMP/app.log" | tail -1 || true)
if [ -z "$line" ]; then
    echo "measure-halo-activity: missing activity result"
    tail -20 "$TMP/app.log"
    exit 1
fi
printf 'HALO_CPU state=%s window=20s ticks=%d ticks_per_second=%s\n' \
    "$STATE" "$ticks" "$(awk -v n="$ticks" 'BEGIN { printf "%.2f", n / 20 }')"
printf '%s\n' "$line"
