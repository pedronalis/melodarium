#!/usr/bin/env bash
# Verifies that every queue mutation has a reachable keyboard-accessible control, then opens
# the real overlay with an isolated three-track library so QML/runtime failures cannot hide
# behind static checks.
set -euo pipefail

BIN="${1:-./build/melodarium}"
OVERLAY="src/QueueOverlay.qml"
failed=0

require_literal() {
    local description="$1"
    local literal="$2"
    if ! rg -Fq "$literal" "$OVERLAY"; then
        echo "QUEUE_EDIT_MISSING $description: $literal"
        failed=1
    fi
}

require_literal play-next-call 'AudioEngine.playNext(linha.modelData)'
require_literal remove-call 'AudioEngine.removeQueueItem(linha.index)'
require_literal move-up-call 'AudioEngine.moveQueueItem(linha.index, linha.index - 1)'
require_literal move-down-call 'AudioEngine.moveQueueItem(linha.index, linha.index + 1)'
require_literal clear-call 'AudioEngine.clearUpcoming()'
require_literal clear-confirmation 'ConfirmDialog {'
require_literal delete-key 'Keys.onDeletePressed'
require_literal modified-arrow-key 'Qt.ControlModifier'
require_literal play-next-label 'Tocar a seguir'
require_literal move-up-label 'Mover para cima'
require_literal move-down-label 'Mover para baixo'
require_literal remove-label 'Remover da fila'

if [ "$failed" -ne 0 ]; then
    exit 1
fi
if [ ! -x "$BIN" ]; then
    echo "check-queue-editing: executable not found: $BIN"
    exit 1
fi
for dependency in ffmpeg sqlite3; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "check-queue-editing: missing dependency: $dependency"
        exit 1
    fi
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"

for fixture in one two three; do
    ffmpeg -hide_banner -loglevel error -f lavfi -i "sine=frequency=440:duration=8" \
        -metadata title="$fixture" -y "$TMP/$fixture.flac"
done

XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen \
    timeout 15 "$BIN" --measure 1100 --no-search --delay 300 >/dev/null 2>&1

DB="$TMP/data/melodarium/melodarium/melodarium.db"
sqlite3 "$DB" "
INSERT INTO tracks (path,mtime,size,duration_ms,title,added_at,source_kind)
VALUES ('$TMP/one.flac',1,1,8000,'one',1,'local_file'),
       ('$TMP/two.flac',1,1,8000,'two',2,'local_file'),
       ('$TMP/three.flac',1,1,8000,'three',3,'local_file');"

LOG="$TMP/queue.log"
XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen QT_LOGGING_RULES="*.debug=true" \
QT_FORCE_STDERR_LOGGING=1 timeout 20 "$BIN" --measure 1100 --play-queue --open-queue \
    --no-search --shot "$TMP/queue.png" --delay 1800 >"$LOG" 2>&1

if rg -q 'is not a type|Unable to assign|ReferenceError|TypeError|Binding loop' "$LOG"; then
    echo "check-queue-editing: QML runtime error"
    rg 'is not a type|Unable to assign|ReferenceError|TypeError|Binding loop' "$LOG" | head -8
    exit 1
fi
line=$(grep -ao 'MEDIDA .*' "$LOG" | tail -1)
if [[ "$line" != *"fila=3"* || "$line" != *"queuepos=0"* || ! -s "$TMP/queue.png" ]]; then
    echo "check-queue-editing: overlay did not mount a three-entry active queue"
    echo "$line"
    exit 1
fi
if [ -n "${QUEUE_EDIT_SCREENSHOT:-}" ]; then
    cp "$TMP/queue.png" "$QUEUE_EDIT_SCREENSHOT"
fi

echo "check-queue-editing: play-next, remove, move, clear confirmation and keyboard contracts"
