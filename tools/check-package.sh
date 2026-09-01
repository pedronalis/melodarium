#!/usr/bin/env bash
# Validates the install tree and package metadata without touching the user's real prefix.
set -euo pipefail

BUILD_DIR="${1:-build}"
APP_ID="io.github.pedronalis.melodarium"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PREFIX="$TMP/prefix"

cmake --install "$BUILD_DIR" --prefix "$PREFIX"

required=(
    "bin/melodarium"
    "share/applications/$APP_ID.desktop"
    "share/metainfo/$APP_ID.metainfo.xml"
    "share/icons/hicolor/scalable/apps/$APP_ID.svg"
)
for relative in "${required[@]}"; do
    if [ ! -e "$PREFIX/$relative" ]; then
        echo "PACKAGE_INSTALL_MISSING $relative"
        exit 1
    fi
done
if [ ! -x "$PREFIX/bin/melodarium" ]; then
    echo "PACKAGE_INSTALL_NOT_EXECUTABLE bin/melodarium"
    exit 1
fi

desktop-file-validate "$PREFIX/share/applications/$APP_ID.desktop"
appstreamcli validate --no-net "$PREFIX/share/metainfo/$APP_ID.metainfo.xml"

echo "check-package: install tree, desktop entry, AppStream metadata and icon passed"
