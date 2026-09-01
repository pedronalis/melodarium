#!/usr/bin/env bash
# Fails when CTest discovers fewer tests than the required floor.
set -euo pipefail

MINIMUM="${1:-25}"
BUILD_DIR="${2:-build}"

if ! [[ "$MINIMUM" =~ ^[0-9]+$ ]] || [ "$MINIMUM" -lt 1 ]; then
    echo "TEST_FLOOR_INVALID $MINIMUM"
    exit 2
fi

listing=$(ctest --test-dir "$BUILD_DIR" -N)
printf '%s\n' "$listing"

count=$(sed -n 's/^Total Tests: \([0-9][0-9]*\)$/\1/p' <<<"$listing")
if [ -z "$count" ]; then
    echo "TEST_FLOOR_COUNT_MISSING"
    exit 1
fi
if [ "$count" -lt "$MINIMUM" ]; then
    echo "TEST_FLOOR_FAILED discovered=$count required=$MINIMUM"
    exit 1
fi

echo "TEST_FLOOR_PASSED discovered=$count required=$MINIMUM"
