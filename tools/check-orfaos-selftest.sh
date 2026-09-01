#!/usr/bin/env bash
# Regression proof for type-scoped homonyms and stale reservations.
set -euo pipefail

raw=$(bash tools/check-orfaos.sh --self-test 2>&1 || true)
if ! grep -Fq 'check-orfaos-selftest: homonyms and reservations scoped by type' <<<"$raw"; then
    echo "FAIL: check-orfaos.sh did not distinguish homonyms/stale reservations"
    printf '%s\n' "$raw" | tail -20
    exit 1
fi

echo "check-orfaos-selftest: homonyms and reservations scoped by type"
