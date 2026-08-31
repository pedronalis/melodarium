#!/usr/bin/env bash
# The artwork layers may become ready synchronously or after the fallback timer. Both paths
# must finish on the layer selected for this transition; toggling blindly can put the old
# cover back in front after the new one has already loaded.
set -uo pipefail

PANEL="${1:-src/NowPlayingPanel.qml}"
fail=0

require() {
    local pattern="$1"
    local description="$2"
    if rg -q -- "$pattern" "$PANEL"; then
        echo "ok:    $description"
    else
        echo "FALHA: $description"
        fail=1
    fi
}

reject() {
    local pattern="$1"
    local description="$2"
    if rg -q -- "$pattern" "$PANEL"; then
        echo "FALHA: $description"
        fail=1
    else
        echo "ok:    $description"
    fi
}

require 'property bool alvoAnaFrente:' \
    "a transição guarda explicitamente qual camada deve terminar na frente"
require 'function finalizarTrocaDeCapa\(alvoAnaFrente\)' \
    "ready e timeout convergem pela mesma finalização"
require 'onTriggered: root\.finalizarTrocaDeCapa\(alvoAnaFrente\)' \
    "o timeout termina na camada-alvo"
reject 'onTriggered:[[:space:]]*root\.capaAnaFrente[[:space:]]*=[[:space:]]*!root\.capaAnaFrente' \
    "o timeout nunca inverte a capa às cegas"

if [ "$fail" -eq 0 ]; then
    echo "check-cover-crossfade: asynchronous artwork always ends on its target layer"
fi

exit "$fail"
