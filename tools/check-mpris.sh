#!/usr/bin/env bash
# Exercise the desktop integration over a private session bus. This proves the same boundary
# used by Noctalia and the keyboard bindings instead of calling AudioEngine directly.
set -euo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-mpris: executable not found: $BIN"
    exit 1
fi
for command in dbus-run-session ffmpeg gdbus playerctl; do
    if ! command -v "$command" >/dev/null; then
        echo "check-mpris: $command is required"
        exit 1
    fi
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config/melodarium" "$TMP/data" "$TMP/cache" "$TMP/media"

TRACK_A="$TMP/media/mpris-a.flac"
TRACK_B="$TMP/media/mpris-b.flac"
ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=440:d=12' \
    -metadata title='MPRIS A' -metadata artist='Desktop Artist' \
    -metadata album='Desktop Album' -y "$TRACK_A"
ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=660:d=12' \
    -metadata title='MPRIS B' -metadata artist='Desktop Artist' \
    -metadata album='Desktop Album' -y "$TRACK_B"

{
    printf '[playback]\n'
    printf 'currentIndex=0\n'
    printf 'queue=%s, %s\n' "$TRACK_A" "$TRACK_B"
} > "$TMP/config/melodarium/melodarium.conf"

export MPRIS_TEST_BIN="$BIN"
export MPRIS_TEST_TMP="$TMP"
dbus-run-session -- bash <<'SESSION'
set -euo pipefail

SERVICE='org.mpris.MediaPlayer2.melodarium'
OBJECT='/org/mpris/MediaPlayer2'
LOG="$MPRIS_TEST_TMP/app.log"
APP_PID=''

cleanup() {
    if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
        kill "$APP_PID"
        wait "$APP_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

QT_QPA_PLATFORM=offscreen \
MELODIA_NULL_AO=1 \
QT_FORCE_STDERR_LOGGING=1 \
XDG_CONFIG_HOME="$MPRIS_TEST_TMP/config" \
XDG_DATA_HOME="$MPRIS_TEST_TMP/data" \
XDG_CACHE_HOME="$MPRIS_TEST_TMP/cache" \
    "$MPRIS_TEST_BIN" >"$LOG" 2>&1 &
APP_PID=$!

wait_for_player() {
    for _ in $(seq 1 100); do
        if playerctl -l 2>/dev/null | grep -qx 'melodarium'; then
            return 0
        fi
        if ! kill -0 "$APP_PID" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    echo "FAIL: $SERVICE did not appear on the session bus"
    tail -n 40 "$LOG" || true
    return 1
}

wait_for_status() {
    local expected=$1
    for _ in $(seq 1 100); do
        if [ "$(playerctl -p melodarium status 2>/dev/null || true)" = "$expected" ]; then
            return 0
        fi
        sleep 0.1
    done
    echo "FAIL: expected PlaybackStatus=$expected, got $(playerctl -p melodarium status 2>/dev/null || true)"
    return 1
}

wait_for_title() {
    local expected=$1
    for _ in $(seq 1 100); do
        if [ "$(playerctl -p melodarium metadata xesam:title 2>/dev/null || true)" = "$expected" ]; then
            return 0
        fi
        sleep 0.1
    done
    echo "FAIL: expected title '$expected', got '$(playerctl -p melodarium metadata xesam:title 2>/dev/null || true)'"
    return 1
}

wait_for_player

root_xml=$(gdbus introspect --session --dest "$SERVICE" --object-path "$OBJECT")
for interface in org.mpris.MediaPlayer2 org.mpris.MediaPlayer2.Player; do
    if ! grep -q "interface $interface" <<<"$root_xml"; then
        echo "FAIL: missing $interface"
        exit 1
    fi
done

identity=$(gdbus call --session --dest "$SERVICE" --object-path "$OBJECT" \
    --method org.freedesktop.DBus.Properties.Get org.mpris.MediaPlayer2 Identity)
can_control=$(gdbus call --session --dest "$SERVICE" --object-path "$OBJECT" \
    --method org.freedesktop.DBus.Properties.Get org.mpris.MediaPlayer2.Player CanControl)
can_play=$(gdbus call --session --dest "$SERVICE" --object-path "$OBJECT" \
    --method org.freedesktop.DBus.Properties.Get org.mpris.MediaPlayer2.Player CanPlay)
if [[ "$identity" != *Melodarium* || "$can_control" != *true* || "$can_play" != *true* ]]; then
    echo "FAIL: invalid root/player properties: identity=$identity control=$can_control play=$can_play"
    exit 1
fi

playerctl -p melodarium play
wait_for_status Playing
wait_for_title 'MPRIS A'

playerctl -p melodarium pause
wait_for_status Paused

playerctl -p melodarium next
wait_for_title 'MPRIS B'

echo "check-mpris: discovered Melodarium; Play, Pause and Next crossed the session bus"
SESSION
