#!/usr/bin/env bash
# Mede a moldura contra o desenho aprovado (design/Main.dc.html) em vez de olhar para ela.
# O app aceita --measure: imprime uma linha "MEDIDA ..." e sai. Uma mudança acidental de
# layout aparece aqui como falha, não como tela torta descoberta pelo usuário.
set -uo pipefail

BIN="${1:-./build/appmelodia}"
if [ ! -x "$BIN" ]; then
    echo "check-layout: binário não encontrado ou não executável: $BIN"
    exit 1
fi

raw=$(QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen \
      timeout 10 "$BIN" --measure 2>&1)
line=$(printf '%s\n' "$raw" | grep -ao 'MEDIDA .*' | tail -1)

if [ -z "$line" ]; then
    echo "check-layout: o app não imprimiu a linha MEDIDA"
    printf '%s\n' "$raw" | tail -20
    exit 1
fi
echo "$line"

round() { printf '%.0f' "${1:-0}"; }

rail=$(round "$(printf '%s\n' "$line" | sed -n 's/.*rail=\([0-9.]*\).*/\1/p')")
painel=$(round "$(printf '%s\n' "$line" | sed -n 's/.*painel=\([0-9.]*\).*/\1/p')")
miolo=$(round "$(printf '%s\n' "$line" | sed -n 's/.*miolo=\([0-9.]*\).*/\1/p')")
capa_w=$(round "$(printf '%s\n' "$line" | sed -n 's/.*capa=\([0-9.]*\)x[0-9.]*.*/\1/p')")
capa_h=$(round "$(printf '%s\n' "$line" | sed -n 's/.*capa=[0-9.]*x\([0-9.]*\).*/\1/p')")

fail=0

expect_eq() {
    if [ "$2" != "$3" ]; then
        echo "FALHA: $1 = $2, o desenho manda $3"
        fail=1
    else
        echo "ok:    $1 = $2"
    fi
}

expect_eq "rail" "$rail" 56
expect_eq "painel" "$painel" 392

if [ "$miolo" -lt 360 ]; then
    echo "FALHA: miolo = $miolo, o mínimo é 360 (a lista é o ponto da tela)"
    fail=1
else
    echo "ok:    miolo = $miolo (>= 360)"
fi

delta=$((capa_w - capa_h))
[ "$delta" -lt 0 ] && delta=$((-delta))
if [ "$delta" -gt 2 ]; then
    echo "FALHA: capa ${capa_w}x${capa_h} não é quadrada"
    fail=1
else
    echo "ok:    capa = ${capa_w}x${capa_h} (quadrada)"
fi

exit "$fail"
