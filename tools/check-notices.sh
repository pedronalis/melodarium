#!/usr/bin/env bash
# Exercises the visible notice queue through the app's measurement seam.
set -euo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-notices: executable not found: $BIN"
    exit 1
fi
for component in src/NoticeCenter.qml src/StatusBanner.qml; do
    if [ ! -f "$component" ]; then
        echo "FAIL: missing notice component: $component"
        exit 1
    fi
done

for handler in onScanFailed onScanProgress onScanFinished onPlaybackError \
               onEngineUnavailable onLocalScanFailed onFeedCheckFailed onDownloadFailed; do
    if ! rg -q "function $handler" src/Main.qml; then
        echo "FAIL: Main.qml does not surface $handler"
        exit 1
    fi
done

if ! rg -q 'Accessible\.role' src/StatusBanner.qml \
   || ! rg -q 'Accessible\.name' src/StatusBanner.qml; then
    echo "FAIL: StatusBanner has no accessible role/name"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"
raw=$(QT_QPA_PLATFORM=offscreen MELODIA_NULL_AO=1 \
      XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
      QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
      timeout 20 "$BIN" --measure 1100 --measure-height 700 --no-search \
      --notice-gate --delay 1800 2>&1)

if grep -aEq \
    'ReferenceError|TypeError|is not a type|Unable to assign|Cannot assign|Binding loop' \
    <<<"$raw"; then
    echo "FAIL: notice scenario produced a QML runtime error"
    printf '%s\n' "$raw" | grep -E \
        'ReferenceError|TypeError|is not a type|Unable to assign|Cannot assign|Binding loop' \
        | head -10
    exit 1
fi

expect_line() {
    local pattern="$1"
    local label="$2"
    if ! grep -aEq "$pattern" <<<"$raw"; then
        echo "FAIL: missing notice proof: $label"
        printf '%s\n' "$raw" | grep -ao 'NOTICE .*' || true
        exit 1
    fi
}

expect_line 'NOTICE source=scan origin=Biblioteca message=yes action=retry severity=error count=1' \
            'scan failure'
expect_line 'NOTICE source=playback origin=Reprodução message=yes action=retry severity=error count=1' \
            'playback failure'
expect_line 'NOTICE source=feed origin=Podcast message=yes action=retry severity=error count=1' \
            'feed failure'
expect_line 'NOTICE source=download origin=Download message=yes action=retry severity=error count=1' \
            'download failure'
expect_line 'NOTICE source=progress origin=Biblioteca .*severity=progress count=1 progress=0\.300' \
            'scan progress'
expect_line 'NOTICE source=dedupe count=1' 'deduplicated queue'
expect_line 'NOTICE source=limit count=5' 'bounded queue'
expect_line 'NOTICE source=dismiss before=1 after=0' 'dismiss action'
expect_line 'NOTICE source=retry before=1 after=0 retries=1' 'retry action'
expect_line 'NOTICE source=fatal .*severity=fatal .*focused=yes' 'fatal focus'

echo "check-notices: four backends, progress, bounded dedupe, actions and fatal focus"
