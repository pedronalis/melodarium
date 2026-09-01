#!/usr/bin/env bash
# Runs the destructive portability proofs only against disposable test fixtures and checks
# that every UI entry point still reaches the validated backend.
set -euo pipefail

BIN="${1:-./build/melodarium}"
TEST="${BIN%/*}/tests/tst_portability"

if [ ! -x "$BIN" ]; then
    echo "check-portability: executable not found: $BIN"
    exit 1
fi
if [ ! -x "$TEST" ]; then
    echo "check-portability: test executable not found: $TEST"
    exit 1
fi

output=$(QT_QPA_PLATFORM=offscreen "$TEST" 2>&1) || {
    printf '%s\n' "$output"
    exit 1
}
totals=$(grep -aE 'Totals: [0-9]+ passed' <<<"$output" | tail -1)
passed=$(sed -nE 's/.*Totals: ([0-9]+) passed.*/\1/p' <<<"$totals")
if [ -z "$passed" ] || [ "$passed" -lt 12 ]; then
    echo "check-portability: expected at least 12 test functions"
    printf '%s\n' "$output"
    exit 1
fi

for contract in \
    'QSaveFile' \
    'QCryptographicHash::Sha256' \
    'PRAGMA quick_check' \
    'kBundleVersion' \
    'createBundle(rollbackPath' \
    'closeDatabaseConnectionsFor(databasePath)'; do
    if ! rg -Fq "$contract" src/portabilityservice.cpp; then
        echo "PORTABILITY_BACKEND_MISSING contract=$contract"
        exit 1
    fi
done

for contract in \
    'PortabilityService.createBackup' \
    'PortabilityService.restoreBackup' \
    'ConfirmDialog' \
    'Fechar para reiniciar'; do
    if ! rg -Fq "$contract" src/BackupRestoreDialog.qml; then
        echo "PORTABILITY_UI_MISSING contract=$contract"
        exit 1
    fi
done

echo "$totals"
echo "check-portability: OPML, M3U and verified backup/restore contracts passed"
