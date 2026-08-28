#!/usr/bin/env bash
# Mede a moldura contra o desenho aprovado (design/Main.dc.html) em vez de olhar para ela.
# O app aceita `--measure [largura]`: monta a tela, imprime uma linha "MEDIDA ..." e sai. Uma
# mudança acidental de layout aparece aqui como falha, não como tela torta descoberta pelo
# usuário. A segunda passada, na janela mínima, é o que pega a linha de filtros espremida.
set -uo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-layout: binário não encontrado ou não executável: $BIN"
    exit 1
fi

fail=0
line=""

medir() {
    local largura="$1"
    local raw
    raw=$(QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen \
          timeout 10 "$BIN" --measure "$largura" 2>&1)
    local ruido
    ruido=$(printf '%s\n' "$raw" | grep -Ec 'is not a type|Unable to assign|ReferenceError|TypeError|unavailable|Cannot override|Cannot assign')
    if [ "$ruido" -ne 0 ]; then
        echo "FALHA: o QML reclamou $ruido vez(es) ao montar a tela em $largura px"
        printf '%s\n' "$raw" | grep -E 'is not a type|Unable to assign|ReferenceError|TypeError|unavailable|Cannot override|Cannot assign' | head -5
        fail=1
    fi
    line=$(printf '%s\n' "$raw" | grep -ao 'MEDIDA .*' | tail -1)
    if [ -z "$line" ]; then
        echo "check-layout: o app não imprimiu a linha MEDIDA em $largura px"
        printf '%s\n' "$raw" | tail -20
        fail=1
        return 1
    fi
    echo "$line"
    return 0
}

campo() {
    printf '%s\n' "$line" | sed -n "s/.*$1=\([0-9.]*\).*/\1/p" | head -1
}

arredonda() { printf '%.0f' "${1:-0}"; }

esperado() {
    if [ "$2" != "$3" ]; then
        echo "FALHA: $1 = $2, o desenho manda $3"
        fail=1
    else
        echo "ok:    $1 = $2"
    fi
}

checa_miolo() {
    local miolo
    miolo=$(arredonda "$(campo miolo)")
    if [ "$miolo" -lt 360 ]; then
        echo "FALHA: miolo = $miolo, o mínimo é 360 (a lista é o ponto da tela)"
        fail=1
    else
        echo "ok:    miolo = $miolo (>= 360)"
    fi
}

checa_capa() {
    local w h delta
    w=$(arredonda "$(printf '%s\n' "$line" | sed -n 's/.*capa=\([0-9.]*\)x[0-9.]*.*/\1/p')")
    h=$(arredonda "$(printf '%s\n' "$line" | sed -n 's/.*capa=[0-9.]*x\([0-9.]*\).*/\1/p')")
    delta=$((w - h))
    [ "$delta" -lt 0 ] && delta=$((-delta))
    if [ "$delta" -gt 2 ]; then
        echo "FALHA: capa ${w}x${h} não é quadrada"
        fail=1
    else
        echo "ok:    capa = ${w}x${h} (quadrada)"
    fi
}

checa_motor() {
    if printf '%s\n' "$line" | grep -q 'motor=ok'; then
        echo "ok:    motor de áudio de pé"
    else
        echo "FALHA: o motor de áudio não subiu (mpv)"
        fail=1
    fi
}

checa_busca() {
    local w h
    w=$(arredonda "$(printf '%s\n' "$line" | sed -n 's/.*busca=\([0-9.]*\)x[0-9.]*.*/\1/p')")
    h=$(arredonda "$(printf '%s\n' "$line" | sed -n 's/.*busca=[0-9.]*x\([0-9.]*\).*/\1/p')")
    if [ "$w" -ne 660 ] || [ "$h" -ne 520 ]; then
        echo "FALHA: overlay de busca ${w}x${h}, o desenho manda 660x520"
        fail=1
    else
        echo "ok:    busca = ${w}x${h}"
    fi
}

checa_filtros() {
    local pede tem
    pede=$(arredonda "$(campo chips)")
    tem=$(arredonda "$(campo chipsvao)")
    if [ "$pede" -gt "$tem" ]; then
        echo "FALHA: a linha de filtros pede $pede px e só tem $tem — ela vai espremer"
        fail=1
    else
        echo "ok:    filtros = $pede px em $tem (uma linha só)"
    fi
}

echo "== janela nominal (1100 px) =="
if medir 1100; then
    esperado "rail" "$(arredonda "$(campo rail)")" 56
    esperado "painel" "$(arredonda "$(campo painel)")" 392
    checa_motor
    checa_miolo
    checa_capa
    checa_filtros
    checa_busca
fi

echo
echo "== janela mínima (720 px) =="
if medir 720; then
    esperado "rail" "$(arredonda "$(campo rail)")" 56
    checa_miolo
    checa_capa
    checa_filtros
fi

exit "$fail"
