#!/usr/bin/env bash
# Keeps the two playback surfaces on one sleep-control contract and replays the short engine
# scenarios so a decorative clock cannot pass without reaching the timer implementation.
set -euo pipefail

BIN="${1:-./build/melodarium}"
CONTROL="src/SleepControl.qml"
failed=0

require_literal() {
    local file="$1"
    local description="$2"
    local literal="$3"
    if [ ! -f "$file" ] || ! rg -Fq "$literal" "$file"; then
        echo "SLEEP_TIMER_MISSING $description: $file :: $literal"
        failed=1
    fi
}

require_literal "$CONTROL" start-call 'AudioEngine.startSleepTimer('
require_literal "$CONTROL" cancel-call 'AudioEngine.cancelSleepTimer()'
require_literal "$CONTROL" stop-after-call 'AudioEngine.setStopAfterCurrent('
require_literal "$CONTROL" remaining-state 'AudioEngine.sleepRemainingSeconds'
require_literal "$CONTROL" fifteen-minutes '15 min'
require_literal "$CONTROL" thirty-minutes '30 min'
require_literal "$CONTROL" sixty-minutes '60 min'
require_literal "$CONTROL" stop-after-label 'Parar após esta faixa'
require_literal src/NowPlayingPanel.qml full-player-instance 'SleepControl {'
require_literal src/GlobalMiniPlayer.qml mini-player-instance 'SleepControl {'

if [ "$failed" -ne 0 ]; then
    exit 1
fi
if [ ! -x "$BIN" ]; then
    echo "check-sleep-timer: executable not found: $BIN"
    exit 1
fi
TEST_BIN="$(dirname "$BIN")/tests/tst_audioengine"
if [ ! -x "$TEST_BIN" ]; then
    echo "check-sleep-timer: test executable not found: $TEST_BIN"
    exit 1
fi

"$TEST_BIN" sleepTimerCanBeCancelledAndExpiresCleanly \
    stopAfterCurrentFiresOnceOnEof \
    stopAfterCurrentSurvivesAManualTrackChange \
    sleepStateDoesNotSurviveEngineRestart

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"
XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen timeout 15 "$BIN" --measure 1100 --no-search \
    --delay 400 >"$TMP/app.log" 2>&1
if rg -q 'is not a type|Unable to assign|ReferenceError|TypeError|Binding loop' "$TMP/app.log"; then
    echo "check-sleep-timer: QML runtime error"
    rg 'is not a type|Unable to assign|ReferenceError|TypeError|Binding loop' "$TMP/app.log" | head -8
    exit 1
fi

echo "check-sleep-timer: full player, mini-player, remaining time and engine actions"
