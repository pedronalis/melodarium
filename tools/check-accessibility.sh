#!/usr/bin/env bash
# Verifies keyboard activation and accessible semantics without requiring a mouse.
set -euo pipefail

BIN="${1:-./build/melodarium}"
QMLTESTRUNNER="${QMLTESTRUNNER:-/usr/lib64/qt6/bin/qmltestrunner}"

if [ ! -x "$BIN" ]; then
    echo "check-accessibility: executable not found: $BIN"
    exit 1
fi
if [ ! -x "$QMLTESTRUNNER" ]; then
    echo "check-accessibility: qmltestrunner not found: $QMLTESTRUNNER"
    exit 1
fi

required_components=(
    src/IconButton.qml
    src/MelodariumButton.qml
    src/TrackRow.qml
    src/EpisodeRow.qml
    src/IconRail.qml
    src/QueueOverlay.qml
)

failed=0
for component in "${required_components[@]}"; do
    missing=()
    for contract in 'Accessible\.name' 'Accessible\.role' 'activeFocusOnTab' 'Keys\.'; do
        if ! rg -q "$contract" "$component"; then
            missing+=("$contract")
        fi
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        printf 'A11Y_MISSING component=%s contracts=%s\n' \
            "$component" "$(IFS=,; echo "${missing[*]}")"
        failed=1
    fi
done

for shortcut in 'Ctrl+K' 'Media Play' 'Media Next' 'Media Previous'; do
    if ! rg -Fq "$shortcut" src/Main.qml; then
        echo "A11Y_MISSING component=src/Main.qml shortcut=$shortcut"
        failed=1
    fi
done

if [ "$failed" -ne 0 ]; then
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"
mkdir -p "$TMP/imports/Melodarium/App"
cp tests/qml/fixtures/qmldir tests/qml/fixtures/ColorSchemeProvider.qml \
   src/Theme.qml src/VisualSettings.qml src/Icons.qml src/IconButton.qml src/MelodariumButton.qml \
   src/StatusBanner.qml "$TMP/imports/Melodarium/App/"

QT_QPA_PLATFORM="${A11Y_QPA_PLATFORM:-offscreen}" \
XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
"$QMLTESTRUNNER" -input tests/qml/tst_accessibility.qml -import "$TMP/imports"

echo "check-accessibility: names, roles, Tab, Space, Enter, Ctrl+K and media keys"
