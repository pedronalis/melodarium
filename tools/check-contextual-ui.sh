#!/usr/bin/env bash
# Prova que navegar troca o CONTEXTO da coluna esquerda sem interromper o áudio global.
# A linha MEDIDA cobre o estado; as fotos cobrem o modo de falha em que dois componentes
# diferentes existem, mas pintam a mesma tela.
set -euo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-contextual-ui: binário não encontrado ou não executável: $BIN"
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "check-contextual-ui: ffmpeg é obrigatório para criar o áudio isolado"
    exit 1
fi
if ! python3 -c "import PIL" 2>/dev/null; then
    echo "check-contextual-ui: python3-pillow é obrigatório para comparar as telas"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/data" "$TMP/config"

ffmpeg -loglevel error -f lavfi -i "sine=frequency=330:duration=8" \
    -metadata title="Faixa global" -metadata artist="Gate contextual" \
    -y "$TMP/faixa.wav"

run_case() {
    local nome="$1"
    local pane="$2"
    local esperado_contexto="$3"
    local esperado_mini="$4"
    local tocar="$5"
    local shot="$6"
    local -a args=(--measure 1100 --pane "$pane" --no-search --sem-animacao --delay 1800)
    if [ "$tocar" = "sim" ]; then
        args+=(--play-track "$TMP/faixa.wav")
    fi
    if [ -n "$shot" ]; then
        args+=(--shot "$shot")
    fi

    local raw line ruido
    raw=$(XDG_DATA_HOME="$TMP/data" XDG_CONFIG_HOME="$TMP/config" \
          MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen \
          QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
          timeout 30 "$BIN" "${args[@]}" 2>&1)
    ruido=$(printf '%s\n' "$raw" | grep -Ec \
        'is not a type|Unable to assign|ReferenceError|TypeError|unavailable|Binding loop' || true)
    if [ "$ruido" -ne 0 ]; then
        echo "FALHA: $nome produziu $ruido erro(s) de QML"
        printf '%s\n' "$raw" | grep -E \
            'is not a type|Unable to assign|ReferenceError|TypeError|unavailable|Binding loop' \
            | head -8
        return 1
    fi

    line=$(printf '%s\n' "$raw" | grep -ao 'MEDIDA .*' | tail -1)
    if [ -z "$line" ]; then
        echo "FALHA: $nome não publicou MEDIDA"
        printf '%s\n' "$raw" | tail -20
        return 1
    fi
    if ! printf '%s\n' "$line" | grep -q "context=$esperado_contexto"; then
        echo "FALHA: $nome esperava context=$esperado_contexto"
        echo "$line"
        return 1
    fi
    if ! printf '%s\n' "$line" | grep -q "mini=$esperado_mini"; then
        echo "FALHA: $nome esperava mini=$esperado_mini"
        echo "$line"
        return 1
    fi
    if [ -n "$shot" ] && [ ! -s "$shot" ]; then
        echo "FALHA: $nome não produziu a captura"
        return 1
    fi
    echo "ok:    $nome — context=$esperado_contexto mini=$esperado_mini"
}

run_case "Biblioteca com música" library player off sim "$TMP/library.png"
run_case "Podcast sem áudio" podcast podcast off nao ""
run_case "Podcast preservando música" podcast podcast on sim "$TMP/podcast.png"

python3 - "$TMP/library.png" "$TMP/podcast.png" <<'PY'
import sys
from PIL import Image, ImageChops

library = Image.open(sys.argv[1]).convert("RGB").crop((56, 0, 448, 620))
podcast = Image.open(sys.argv[2]).convert("RGB").crop((56, 0, 448, 620))
diff = ImageChops.difference(library, podcast)
changed = sum(1 for pixel in diff.getdata() if max(pixel) > 8)
ratio = changed / (library.width * library.height)
if ratio < 0.02:
    print(f"FALHA: Biblioteca e Podcast diferem em só {ratio:.1%} da coluna contextual")
    raise SystemExit(1)
print(f"ok:    Biblioteca e Podcast diferem em {ratio:.1%} da coluna contextual")
PY
