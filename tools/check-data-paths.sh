#!/usr/bin/env bash
set -euo pipefail

scope=(src tests tools CMakeLists.txt README.md)

if rg -n --pcre2 '(?<!melodarium/)melodarium/melodarium\.db' "${scope[@]}"; then
    echo "FAIL: executable project content references the one-level ghost database path"
    exit 1
fi

if rg -n 'QStringLiteral\("melodarium\.db"\)|"melodarium\.db"' src; then
    echo "FAIL: runtime code hard-codes the database filename"
    exit 1
fi

if ! rg -q 'QStandardPaths::AppDataLocation' src/database.cpp; then
    echo "FAIL: Database::defaultDatabasePath no longer derives from AppDataLocation"
    exit 1
fi

echo "check-data-paths: runtime derives AppDataLocation and no one-level ghost path is executable"
