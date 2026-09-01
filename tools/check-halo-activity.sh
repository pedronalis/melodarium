#!/usr/bin/env bash
# Proves that the ambient glow advances only while real audio is playing in an exposed window.
# The synthetic palette keeps the visual present in every case, so an inactive result also proves
# that pausing/hiding freezes the last frame instead of clearing the effect.
set -euo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-halo-activity: executable not found: $BIN"
    exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "check-halo-activity: ffmpeg is required"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"
ffmpeg -loglevel error -f lavfi -i "sine=frequency=330:duration=12" \
    -y "$TMP/tone.wav"

run_case() {
    local state="$1"
    local -a args=(--measure 1100 --measure-height 700 --no-search --halo-teste
                   --com-halo --measure-halo-activity "$state" --delay 5000)
    if [ "$state" != "stopped" ]; then
        args+=(--play-track "$TMP/tone.wav")
    fi

    local raw line
    raw=$(QT_QPA_PLATFORM=offscreen MELODIA_NULL_AO=1 \
          XDG_CONFIG_HOME="$TMP/config/$state" \
          XDG_DATA_HOME="$TMP/data/$state" \
          XDG_CACHE_HOME="$TMP/cache/$state" \
          QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
          timeout 20 "$BIN" "${args[@]}" 2>&1)
    line=$(printf '%s\n' "$raw" | grep -ao 'HALO_ACTIVITY .*' | tail -1 || true)
    if [ -z "$line" ]; then
        echo "FAIL: $state did not publish HALO_ACTIVITY"
        printf '%s\n' "$raw" | tail -20
        return 1
    fi
    printf '%s\n' "$line"
}

if ! playing=$(run_case playing); then
    printf '%s\n' "$playing"
    exit 1
fi
if ! paused=$(run_case paused); then
    printf '%s\n' "$paused"
    exit 1
fi
if ! hidden=$(run_case hidden); then
    printf '%s\n' "$hidden"
    exit 1
fi
if ! stopped=$(run_case stopped); then
    printf '%s\n' "$stopped"
    exit 1
fi

python3 - "$playing" "$paused" "$hidden" "$stopped" <<'PY'
import re
import sys

expected = {
    "playing": True,
    "paused": False,
    "hidden": False,
    "stopped": False,
}

for line in sys.argv[1:]:
    state = re.search(r"state=(\w+)", line)
    active = re.search(r"active=(on|off)", line)
    frame = re.search(r"frame=(retained|cleared)", line)
    delta = re.search(r"delta=([0-9.]+)", line)
    if not all((state, active, frame, delta)):
        raise SystemExit(f"FAIL: malformed activity line: {line}")
    name = state.group(1)
    is_active = active.group(1) == "on"
    is_retained = frame.group(1) == "retained"
    movement = float(delta.group(1))
    if is_active != expected[name]:
        raise SystemExit(f"FAIL: {name} active={is_active}, expected {expected[name]}: {line}")
    if not is_retained:
        raise SystemExit(f"FAIL: {name} cleared the glow instead of retaining its frame: {line}")
    if name == "playing" and movement < 0.20:
        raise SystemExit(f"FAIL: playing glow did not advance: {line}")
    if name != "playing" and movement > 0.02:
        raise SystemExit(f"FAIL: inactive glow kept advancing: {line}")

print("check-halo-activity: playing advances; paused, hidden and stopped retain a frozen frame")
PY
