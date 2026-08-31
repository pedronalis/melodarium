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
if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "check-contextual-ui: sqlite3 é obrigatório para montar a coleção densa"
    exit 1
fi
if ! command -v xvfb-run >/dev/null 2>&1 || ! command -v xdotool >/dev/null 2>&1; then
    echo "check-contextual-ui: Xvfb e xdotool são obrigatórios para testar o menu nativo"
    exit 1
fi
if ! command -v import >/dev/null 2>&1; then
    echo "check-contextual-ui: ImageMagick é obrigatório para fotografar o menu nativo"
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
ffmpeg -loglevel error -f lavfi -i "sine=frequency=440:duration=8" \
    -metadata title="Episódio do gate" -metadata artist="Conversas do gate" \
    -y "$TMP/episodio.wav"

run_case() {
    local nome="$1"
    local pane="$2"
    local esperado_contexto="$3"
    local esperado_mini="$4"
    local tocar="$5"
    local shot="$6"
    local modo_mini="$7"
    local menu_velocidade="$8"
    local -a args=(--measure 1100 --pane "$pane" --measure-volume 100
                   --no-search --sem-animacao --delay 1800)
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
    if [ "$esperado_mini" = "on" ]; then
        for token in "minilayout=fit" "minicenter=fit" \
                     "minimode=$modo_mini" "speedmenu=$menu_velocidade"; do
            if ! printf '%s\n' "$line" | grep -q "$token"; then
                echo "FALHA: $nome não publicou $token"
                echo "$line"
                return 1
            fi
        done
    fi
    if [ -n "$shot" ] && [ ! -s "$shot" ]; then
        echo "FALHA: $nome não produziu a captura"
        return 1
    fi
    echo "ok:    $nome — context=$esperado_contexto mini=$esperado_mini"
}

run_case "Biblioteca com música" library player off sim "$TMP/library.png" na na
run_case "Podcast sem áudio" podcast podcast off nao "" na na
run_case "Podcast preservando música" podcast podcast on sim "$TMP/podcast.png" music na

DB="$TMP/data/melodarium/melodarium/melodarium.db"
sqlite3 "$DB" "
INSERT INTO tracks (id,path,mtime,size,duration_ms,title,added_at,source_kind)
VALUES (999,'$TMP/faixa.wav',1,1,8000,'Faixa do gate',1,'local_file');
INSERT INTO collections (id,name,created_at)
VALUES (999,'Coleção com nome comprido',1);
INSERT INTO collection_tracks (collection_id,track_id,position,added_at)
VALUES (999,999,1,1);
INSERT INTO podcast_shows (id,title,feed_url)
VALUES (999,'Conversas do gate','https://example.com/gate.xml');
INSERT INTO podcast_episodes
    (id,show_id,guid,title,published_at,duration_ms,local_path,download_state)
VALUES
    (999,999,'gate-999','Como desenhar um player melhor',1,8000,'$TMP/episodio.wav','done');"

run_case "Coleções sem áudio" collections collections off nao "" na na
run_case "Coleções preservando música" collections collections on sim \
    "$TMP/collections.png" music na

check_motion() {
    local pane="$1"
    local motion_raw motion_line
    motion_raw=$(XDG_DATA_HOME="$TMP/data" XDG_CONFIG_HOME="$TMP/config" \
                 MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen \
                 QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
                 timeout 30 "$BIN" --measure 1100 --pane "$pane" \
                 --play-track "$TMP/faixa.wav" --measure-volume 100 \
                 --measure-mini-motion --no-search --delay 2200 2>&1)
    motion_line=$(printf '%s\n' "$motion_raw" | grep -ao 'MOTION .*' | tail -1 || true)
    if [ -z "$motion_line" ]; then
        echo "FALHA: a entrada de $pane não publicou amostras MOTION"
        return 1
    fi
    printf '%s\n' "$motion_raw" | grep -E \
        'ReferenceError|TypeError|Unable to assign|Binding loop' || true
    python3 - "$pane" "$motion_line" <<'PY'
import re
import sys

pane = sys.argv[1]
line = sys.argv[2]
values = {key: float(value) for key, value in
          re.findall(
              r"(miniStart|miniMid|miniRaised|miniTarget|sectionBefore|sectionMid|sectionEnd|"
              r"playerBefore|playerMid|playerEnd|barDuration|contentDuration)=([0-9.]+)",
              line,
          )}
required = {
    "miniStart", "miniMid", "miniRaised", "miniTarget",
    "sectionBefore", "sectionMid", "sectionEnd",
    "playerBefore", "playerMid", "playerEnd",
    "barDuration", "contentDuration",
}
if set(values) != required:
    print("FALHA: linha MOTION incompleta:", line)
    raise SystemExit(1)
if values["miniStart"] > 1 or not 1 < values["miniMid"] < values["miniRaised"] - 1:
    print("FALHA: a barra não subiu progressivamente:", line)
    raise SystemExit(1)
if abs(values["miniRaised"] - values["miniTarget"]) > 2:
    print("FALHA: a barra não terminou na altura alvo:", line)
    raise SystemExit(1)
if values["sectionBefore"] > 0.02 or values["playerBefore"] > 0.02:
    print("FALHA: elementos apareceram antes de a barra terminar:", line)
    raise SystemExit(1)
if not (0.05 < values["sectionMid"] < 0.98
        and 0.05 < values["playerMid"] < 0.98
        and values["sectionEnd"] >= 0.99
        and values["playerEnd"] >= 0.99):
    print("FALHA: os elementos não entraram progressivamente depois da barra:", line)
    raise SystemExit(1)
if not (0 < values["barDuration"] < 300 and 0 < values["contentDuration"] < 300):
    print("FALHA: cada fase da entrada deve ficar abaixo de 300 ms:", line)
    raise SystemExit(1)
print(f"ok:    barra sobe e {pane} entra progressivamente — {line}")
PY
}

check_motion podcast
check_motion collections

muted_raw=$(XDG_DATA_HOME="$TMP/data" XDG_CONFIG_HOME="$TMP/config" \
            MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen \
            QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
            timeout 30 "$BIN" --measure 1100 --pane collections \
            --play-track "$TMP/faixa.wav" --measure-volume 0 \
            --no-search --sem-animacao --delay 1800 --shot "$TMP/muted.png" 2>&1)
if [ ! -s "$TMP/muted.png" ]; then
    echo "FALHA: o estado mutado não produziu captura"
    printf '%s\n' "$muted_raw" | tail -20
    exit 1
fi
python3 - "$TMP/collections.png" "$TMP/muted.png" <<'PY'
import sys
from PIL import Image

def peak(path):
    # Reamostrado no desenho 1100×700: o volume ocupa esta região sem tocar o slider.
    crop = Image.open(path).convert("RGB").crop((955, 635, 990, 670))
    return max(max(pixel) for pixel in crop.get_flattened_data())

active = peak(sys.argv[1])
muted = peak(sys.argv[2])
if active < 180:
    print(f"FALHA: ícone com som continua cinza (pico {active})")
    raise SystemExit(1)
if muted > 130:
    print(f"FALHA: ícone mutado não ficou cinza (pico {muted})")
    raise SystemExit(1)
print(f"ok:    volume ligado é claro ({active}) e mutado é cinza ({muted})")
PY

episode_raw=$(XDG_DATA_HOME="$TMP/data" XDG_CONFIG_HOME="$TMP/config" \
              MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen \
              QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
              timeout 30 "$BIN" --measure 1100 --pane collections --play-episode 999 \
              --no-search --sem-animacao --delay 1800 2>&1)
episode_line=$(printf '%s\n' "$episode_raw" | grep -ao 'MEDIDA .*' | tail -1)
for token in 'context=collections' 'mini=on' 'minilayout=fit' 'minicenter=fit' \
             'minimode=podcast' 'speedmenu=native'; do
    if ! printf '%s\n' "$episode_line" | grep -q "$token"; then
        echo "FALHA: Podcast no mini-player não publicou $token"
        echo "$episode_line"
        exit 1
    fi
done
echo "ok:    Podcast usa transporte próprio e prefere menu nativo"

narrow_raw=$(XDG_DATA_HOME="$TMP/data" XDG_CONFIG_HOME="$TMP/config" \
             MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen \
             QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
             timeout 30 "$BIN" --measure 720 --pane collections --play-track "$TMP/faixa.wav" \
             --no-search --sem-animacao --delay 1800 2>&1)
narrow_line=$(printf '%s\n' "$narrow_raw" | grep -ao 'MEDIDA .*' | tail -1)
for token in 'mini=on' 'minilayout=fit' 'minicenter=fit' 'minimode=music'; do
    if ! printf '%s\n' "$narrow_line" | grep -q "$token"; then
        echo "FALHA: mini-player de 720 px não publicou $token"
        echo "$narrow_line"
        exit 1
    fi
done
echo "ok:    mini-player cabe e permanece centrado em 720 px"

native_log="$TMP/native-menu.log"
native_shot="$TMP/native-menu.png"
xvfb-run -a -s '-screen 0 1100x700x24' bash -c '
    set -euo pipefail
    bin="$1"
    data="$2"
    config="$3"
    log="$4"
    shot="$5"
    XDG_DATA_HOME="$data" XDG_CONFIG_HOME="$config" MELODIA_NULL_AO=1 \
        QT_QPA_PLATFORM=xcb QT_QPA_PLATFORMTHEME=gnome \
        QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
        "$bin" --measure 1100 --pane collections --play-episode 999 \
        --open-speed-menu --no-search --sem-animacao --delay 6000 >"$log" 2>&1 &
    app_pid=$!
    sleep 2.8
    import -window root "$shot"
    xdotool key Home
    sleep 0.15
    xdotool key Down
    sleep 0.15
    xdotool key Down
    sleep 0.15
    xdotool key Down
    sleep 0.15
    xdotool key Down
    sleep 0.15
    xdotool key Return
    wait "$app_pid"
' _ "$BIN" "$TMP/data" "$TMP/config" "$native_log" "$native_shot"

native_line=$(grep -ao 'MEDIDA .*' "$native_log" | tail -1)
if ! printf '%s\n' "$native_line" | grep -q 'speedmenu=native' \
   || ! printf '%s\n' "$native_line" | grep -q 'speed=1.50'; then
    echo "FALHA: o menu nativo não escolheu 1,5× pelo teclado"
    echo "$native_line"
    exit 1
fi
if [ ! -s "$native_shot" ]; then
    echo "FALHA: o menu nativo não produziu captura externa"
    exit 1
fi
echo "ok:    menu nativo escolhe 1,5× por interação real"

dense_raw=$(XDG_DATA_HOME="$TMP/data" XDG_CONFIG_HOME="$TMP/config" \
            MELODIA_NULL_AO=1 QT_QPA_PLATFORM=offscreen \
            QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 \
            timeout 30 "$BIN" --measure 720 --pane collections --open-collection 999 \
            --no-search --sem-animacao --delay 1800 2>&1)
dense_line=$(printf '%s\n' "$dense_raw" | grep -ao 'MEDIDA .*' | tail -1)
if ! printf '%s\n' "$dense_line" | grep -q 'collectionheader=fit'; then
    echo "FALHA: o cabeçalho da coleção aberta não provou que cabe em 720 px"
    echo "$dense_line"
    exit 1
fi
echo "ok:    cabeçalho da coleção aberta cabe em 720 px"

python3 - "$TMP/library.png" "$TMP/podcast.png" "$TMP/collections.png" <<'PY'
import sys
from PIL import Image, ImageChops

images = {
    "Biblioteca": Image.open(sys.argv[1]).convert("RGB").crop((56, 0, 448, 620)),
    "Podcast": Image.open(sys.argv[2]).convert("RGB").crop((56, 0, 448, 620)),
    "Coleções": Image.open(sys.argv[3]).convert("RGB").crop((56, 0, 448, 620)),
}
for first, second in (("Biblioteca", "Podcast"),
                      ("Biblioteca", "Coleções"),
                      ("Podcast", "Coleções")):
    diff = ImageChops.difference(images[first], images[second])
    changed = sum(1 for pixel in diff.get_flattened_data() if max(pixel) > 8)
    ratio = changed / (diff.width * diff.height)
    if ratio < 0.02:
        print(f"FALHA: {first} e {second} diferem em só {ratio:.1%} da coluna contextual")
        raise SystemExit(1)
    print(f"ok:    {first} e {second} diferem em {ratio:.1%} da coluna contextual")
PY
