#!/usr/bin/env bash
# Mede a COR da tela contra o desenho aprovado, ponto a ponto.
#
# Por que existe: o gate de layout mede a moldura (56, 392, capa quadrada) e passa verde com a
# paleta inteira errada. Foi assim que o app chegou até 28/08 com quatro fundos de estado
# diferentes colapsados num tom só, textos dois degraus mais escuros que o desenho e nenhum
# degradê — tudo compilando, tudo passando, e nada parecido com o que foi aprovado. Cor não
# tem como ser conferida "de olho" a cada mudança: ou é medida, ou volta a derrapar.
#
# Os pontos são coordenadas fixas na janela nominal de 1100x700, escolhidas em regiões que NÃO
# dependem do acervo de quem roda (fundo, painel, trilho, campo de busca, pílula de filtro).
set -uo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-fidelidade: binário não encontrado ou não executável: $BIN"
    exit 1
fi

if ! python3 -c "import PIL" 2>/dev/null; then
    echo "check-fidelidade: python3-pillow não está instalado — o gate não pode medir"
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

foto() {
    local nome="$1"; shift
    QT_QPA_PLATFORM=offscreen timeout 60 "$BIN" --measure 1100 "$@" \
        --shot "$TMP/$nome.png" --delay 1800 >/dev/null 2>&1
    [ -s "$TMP/$nome.png" ]
}

if ! foto biblioteca --no-search --play-queue; then
    echo "FALHA: o app não produziu a foto da biblioteca"
    exit 1
fi
if ! foto vazio --pane empty --no-search; then
    echo "FALHA: o app não produziu a foto da tela vazia"
    exit 1
fi

python3 - "$TMP" <<'PY'
import sys
from PIL import Image

tmp = sys.argv[1]

# nome | foto | (x, y) | hex do desenho
# Cada linha aponta para um trecho liso: medir em cima de texto ou de ícone lê o glifo, não a
# superfície, e produz falha falsa.
PONTOS = [
    ("fundo da janela",        "biblioteca", (900, 655), "#111111"),
    ("painel: topo do degradê","biblioteca", ( 70,   8), "#1a1a1a"),
    ("painel: pé do degradê",  "biblioteca", ( 70, 690), "#111111"),
    ("campo de busca",         "biblioteca", (700,  90), "#191919"),
    ("pílula escolhida",       "biblioteca", (482, 122), "#262626"),
    ("pílula em repouso",      "biblioteca", (556, 122), "#111111"),
    ("trilho: ícone escolhido","biblioteca", ( 16, 108), "#232323"),
    ("fundo da janela (vazia)","vazio",      (900, 655), "#111111"),
    ("painel: topo (vazia)",   "vazio",      ( 70,   8), "#1a1a1a"),
]

# 3 níveis de tolerância por canal: o mesmo hex desenhado pelo Qt pode variar de 1 em arredon-
# damento de composição. Acima disso é cor trocada, não ruído.
TOLERANCIA = 3

fotos = {}
falhas = 0
for nome, foto, (x, y), esperado in PONTOS:
    if foto not in fotos:
        fotos[foto] = Image.open(f"{tmp}/{foto}.png").convert("RGB")
    r, g, b = fotos[foto].getpixel((x, y))
    er, eg, eb = (int(esperado[1:3], 16), int(esperado[3:5], 16), int(esperado[5:7], 16))
    delta = max(abs(r - er), abs(g - eg), abs(b - eb))
    if delta > TOLERANCIA:
        print(f"FALHA: {nome} = #{r:02x}{g:02x}{b:02x}, o desenho manda {esperado}")
        falhas += 1
    else:
        print(f"ok:    {nome} = {esperado}")

# A capa arredondada: no canto do quadrado a arte NÃO pode aparecer, senão o `radius` está
# desenhado embaixo de uma imagem de canto vivo — o defeito que o RoundedImage existe para
# resolver, e que compila verde de qualquer jeito.
capa = fotos["biblioteca"]
canto = capa.getpixel((84, 24))     # 2 px para dentro do canto superior esquerdo da capa
centro = capa.getpixel((250, 190))  # no meio da arte
if max(abs(a - b) for a, b in zip(canto, centro)) < 12:
    print(f"FALHA: o canto da capa {canto} é igual ao miolo dela {centro} — a capa está quadrada")
    falhas += 1
else:
    print("ok:    a capa está arredondada (o canto não é arte)")

sys.exit(1 if falhas else 0)
PY
