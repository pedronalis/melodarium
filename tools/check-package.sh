#!/usr/bin/env bash
# Validates the install tree and package metadata without touching the user's real prefix.
set -euo pipefail

BUILD_DIR="${1:-build}"
APP_ID="io.github.pedronalis.melodarium"
MANIFEST="packaging/$APP_ID.yml"
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

python3 - "$MANIFEST" "$APP_ID" <<'PY'
import pathlib
import sys

import yaml

manifest_path = pathlib.Path(sys.argv[1])
app_id = sys.argv[2]
if not manifest_path.is_file():
    raise SystemExit(f"FLATPAK_MANIFEST_MISSING {manifest_path}")

manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
required_top_level = {
    "id": app_id,
    "runtime": "org.kde.Platform",
    "sdk": "org.kde.Sdk",
    "command": "melodarium",
}
for key, expected in required_top_level.items():
    if manifest.get(key) != expected:
        raise SystemExit(f"FLATPAK_MANIFEST_INVALID {key}={manifest.get(key)!r}")

finish_args = set(manifest.get("finish-args", []))
required_permissions = {
    "--share=network",
    "--socket=wayland",
    "--socket=fallback-x11",
    "--socket=pulseaudio",
    "--own-name=org.mpris.MediaPlayer2.melodarium",
}
missing_permissions = sorted(required_permissions - finish_args)
if missing_permissions:
    raise SystemExit(
        "FLATPAK_PERMISSIONS_MISSING " + " ".join(missing_permissions)
    )

modules = [module for module in manifest.get("modules", []) if isinstance(module, dict)]
module_names = {module.get("name") for module in modules}
missing_modules = sorted({"libmpv", "taglib", "melodarium"} - module_names)
if missing_modules:
    raise SystemExit("FLATPAK_MODULES_MISSING " + " ".join(missing_modules))

libmpv = next(module for module in modules if module.get("name") == "libmpv")
libmpv_options = set(libmpv.get("config-opts", []))
if "-Dplain-gl=enabled" not in libmpv_options:
    raise SystemExit("FLATPAK_LIBMPV_PLAIN_GL_MISSING")
PY

XDG_CONFIG_HOME="$TMP/xdg-config" \
XDG_DATA_HOME="$TMP/xdg-data" \
XDG_CACHE_HOME="$TMP/xdg-cache" \
XDG_STATE_HOME="$TMP/xdg-state" \
QT_QPA_PLATFORM=offscreen \
    "$PREFIX/bin/melodarium" --scan >"$TMP/scan.log" 2>&1 || scan_status=$?
scan_status=${scan_status:-0}
if [ "$scan_status" -ne 2 ]; then
    echo "PACKAGE_SCAN_UNEXPECTED_EXIT $scan_status"
    cat "$TMP/scan.log"
    exit 1
fi
if ! grep -Fq "nenhuma pasta" "$TMP/scan.log"; then
    echo "PACKAGE_SCAN_MISSING_EMPTY_LIBRARY_MESSAGE"
    cat "$TMP/scan.log"
    exit 1
fi

if ! command -v flatpak-builder >/dev/null 2>&1; then
    echo "FLATPAK_BUILDER_MISSING install flatpak-builder and org.kde.Sdk//6.9"
    exit 1
fi
flatpak-builder --show-manifest "$MANIFEST" >"$TMP/canonical-manifest.json"

echo "check-package: install tree, metadata, Flatpak manifest and isolated scan passed"
