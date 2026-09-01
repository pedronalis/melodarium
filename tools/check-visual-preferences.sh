#!/usr/bin/env bash
# Measures text contrast and proves visual preferences survive a process restart.
set -euo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-visual-preferences: executable not found: $BIN"
    exit 1
fi

for contract in 'category: "ui"' 'property bool reduceMotion' 'property bool highContrast'; do
    if ! rg -Fq "$contract" src/VisualSettings.qml; then
        echo "VISUAL_PREF_MISSING VisualSettings.qml contract=$contract"
        exit 1
    fi
done
for contract in 'function setReduceMotion' 'function setHighContrast'; do
    if ! rg -Fq "$contract" src/Theme.qml; then
        echo "VISUAL_PREF_MISSING Theme.qml contract=$contract"
        exit 1
    fi
done

for label in 'Movimento reduzido' 'Alto contraste'; do
    if ! rg -Fq "$label" src/SettingsDialog.qml; then
        echo "VISUAL_PREF_MISSING SettingsDialog.qml label=$label"
        exit 1
    fi
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"

run_app() {
    QT_QPA_PLATFORM=offscreen MELODIA_NULL_AO=1 \
    XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
    QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
    timeout 20 "$BIN" --no-search "$@" 2>&1
}

initial_raw=$(run_app --visual-preferences-read)
set_raw=$(run_app --visual-preferences-set-on)
persisted_raw=$(run_app --visual-preferences-read)

line_for() {
    local raw="$1"
    local mode="$2"
    local line
    line=$(grep -aE "VISUAL_PREF mode=$mode " <<<"$raw" | tail -1 || true)
    if [ -z "$line" ]; then
        echo "FAIL: missing VISUAL_PREF mode=$mode"
        printf '%s\n' "$raw" | tail -20
        exit 1
    fi
    printf '%s\n' "$line"
}

initial=$(line_for "$initial_raw" read)
set_line=$(line_for "$set_raw" set)
persisted=$(line_for "$persisted_raw" read)

if [[ "$initial" != *"preferredReduce=off high=off"* ]] \
   || [[ "$initial" != *"duration=150 continuous=on"* ]]; then
    echo "FAIL: unexpected default visual preferences"
    echo "$initial"
    exit 1
fi
if [[ "$set_line" != *"preferredReduce=on high=on"* ]] \
   || [[ "$set_line" != *"duration=0 continuous=off"* ]]; then
    echo "FAIL: setting visual preferences did not disable motion"
    echo "$set_line"
    exit 1
fi
if [[ "$persisted" != *"preferredReduce=on high=on"* ]] \
   || [[ "$persisted" != *"duration=0 continuous=off"* ]]; then
    echo "FAIL: visual preferences did not survive restart"
    echo "$persisted"
    exit 1
fi

NORMAL_LINE="$initial" HIGH_LINE="$persisted" python3 - <<'PY'
import os
import re
import sys

roles = ("cFaint", "cDim", "cMuted", "cSubtle", "cSecondary", "cBody",
         "cStrong", "cTitle")

def colors(line):
    return {name: value.lower() for name, value in
            re.findall(r"(c[A-Za-z]+)=(#[0-9a-fA-F]{6})", line)}

def channel(value):
    value /= 255.0
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

def luminance(value):
    red, green, blue = (int(value[i:i + 2], 16) for i in (1, 3, 5))
    return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)

def contrast(foreground, background="#232323"):
    high, low = sorted((luminance(foreground), luminance(background)), reverse=True)
    return (high + 0.05) / (low + 0.05)

normal = colors(os.environ["NORMAL_LINE"])
high = colors(os.environ["HIGH_LINE"])
failures = []
for palette_name, palette in (("normal", normal), ("high", high)):
    for role in roles:
        if role not in palette:
            failures.append(f"{palette_name}: missing {role}")
            continue
        ratio = contrast(palette[role])
        print(f"CONTRAST palette={palette_name} role={role} ratio={ratio:.2f}")
        if ratio < 4.5:
            failures.append(f"{palette_name}: {role}={palette[role]} ratio={ratio:.2f} < 4.5")

if normal.get("cFaint") == high.get("cFaint"):
    failures.append("high contrast does not change cFaint")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    sys.exit(1)
PY

echo "check-visual-preferences: contrast >= 4.5, persistence and reduced motion"
