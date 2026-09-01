#!/usr/bin/env bash
# Fails on any qmllint warning; all_qmllint alone exits zero when warnings remain.
set -euo pipefail

BUILD_DIR="${1:-build}"
if [ ! -d "$BUILD_DIR" ]; then
    echo "check-qmllint-clean: build directory not found: $BUILD_DIR"
    exit 1
fi

if ! raw=$(cmake --build "$BUILD_DIR" --target all_qmllint 2>&1); then
    printf '%s\n' "$raw"
    exit 1
fi

warnings=$(grep -c '^Warning:' <<<"$raw" || true)
if [ "$warnings" -ne 0 ]; then
    echo "FAIL: qmllint reported $warnings warning(s); expected 0"
    grep '^Warning:' <<<"$raw"
    exit 1
fi

echo "check-qmllint-clean: 0 warnings"
