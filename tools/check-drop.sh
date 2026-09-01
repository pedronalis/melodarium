#!/usr/bin/env bash
# Couples the pure URL matrix to reachable window-level drag/drop actions and mounts the real
# QML tree under isolated XDG paths. Downloads remain behind their existing confirmation UI.
set -euo pipefail

BIN="${1:-./build/melodarium}"
failed=0

require_literal() {
    local file="$1"
    local description="$2"
    local literal="$3"
    if [ ! -f "$file" ] || ! rg -Fq "$literal" "$file"; then
        echo "DROP_MISSING $description: $file :: $literal"
        failed=1
    fi
}

require_literal src/Main.qml drop-area 'DropArea {'
require_literal src/Main.qml classifier 'DropRouter.classify(drop.urls)'
require_literal src/Main.qml preview 'dropOverlay.preview('
require_literal src/Main.qml local-files 'AudioEngine.appendToQueue(decision.paths[i])'
require_literal src/Main.qml remote-media 'AudioEngine.appendToQueue(decision.url)'
require_literal src/Main.qml folder-path 'Database.libraryPath = root.pendingDropFolder'
require_literal src/Main.qml folder-scan 'Database.startScan()'
require_literal src/Main.qml feed-dialog 'dropSubscribeDialog.openForUrl(decision.url)'
require_literal src/Main.qml youtube-dialog 'dropLinkDialog.openForUrl(decision.url)'
require_literal src/Main.qml folder-confirmation 'ConfirmDialog {'
require_literal src/DropOverlay.qml accepted-preview 'property var decision'
require_literal src/DropOverlay.qml rejected-preview 'decision.action === "reject"'
require_literal src/SubscribeDialog.qml feed-prefill 'function openForUrl(url)'
require_literal src/AddFromLinkDialog.qml youtube-prefill 'function openForUrl(url)'

if [ "$failed" -ne 0 ]; then
    exit 1
fi
if [ ! -x "$BIN" ]; then
    echo "check-drop: executable not found: $BIN"
    exit 1
fi
TEST_BIN="$(dirname "$BIN")/tests/tst_droprouter"
if [ ! -x "$TEST_BIN" ]; then
    echo "check-drop: test executable not found: $TEST_BIN"
    exit 1
fi
"$TEST_BIN"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"
XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen QT_LOGGING_RULES="*.debug=true" \
QT_FORCE_STDERR_LOGGING=1 timeout 15 "$BIN" --measure 1100 --no-search --delay 500 \
    >"$TMP/app.log" 2>&1
if rg -q 'is not a type|Unable to assign|ReferenceError|TypeError|Binding loop' "$TMP/app.log"; then
    echo "check-drop: QML runtime error"
    rg 'is not a type|Unable to assign|ReferenceError|TypeError|Binding loop' "$TMP/app.log" | head -8
    exit 1
fi

echo "check-drop: URL matrix, preview, confirmation and existing destination flows"
