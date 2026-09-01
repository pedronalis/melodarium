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
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache"

foto() {
    local nome="$1"; shift
    if ! QT_QPA_PLATFORM=offscreen MELODIA_NULL_AO=1 \
         XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" \
         XDG_CACHE_HOME="$TMP/cache" \
         timeout 15 "$BIN" --measure 1100 "$@" \
         --shot "$TMP/$nome.png" --delay 1800 >"$TMP/$nome.log" 2>&1; then
        tail -20 "$TMP/$nome.log"
        return 1
    fi
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
# O explorador de pastas fotografado na RAIZ de propósito: "/" tem as mesmas pastas em
# qualquer máquina, e a foto não passa a depender do acervo de quem roda o portão.
if ! foto seletor --no-search --open-folder-picker /; then
    echo "FALHA: o app não produziu a foto do seletor de pasta"
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
    # A marca do app saiu do topo do trilho em 28/08 (era indistinguível de um botão apagado e
    # não clicava), e a fileira inteira subiu 38 px. Medido na foto: a pílula acesa vai de
    # y=58 a y=91, e o glifo ocupa 71..80 — 63 é o vão liso entre o topo da pílula e o ícone.
    ("trilho: ícone escolhido","biblioteca", ( 28,  63), "#232323"),
    ("fundo da janela (vazia)","vazio",      (900, 655), "#111111"),
    ("painel: topo (vazia)",   "vazio",      ( 70,   8), "#1a1a1a"),
    # O seletor de pasta: superfície elevada por fora, painéis fundos por dentro, zebra na
    # lista e a pílula no disco em que se está. Quatro papéis diferentes que, medidos só de
    # olho, é exatamente onde a escada de cinza colapsa num tom só.
    ("seletor: fundo do diálogo","seletor",  (170, 300), "#191919"),
    ("seletor: campo do caminho","seletor",  (420, 135), "#111111"),
    ("seletor: painel da lista", "seletor",  (700, 250), "#111111"),
    ("seletor: zebra da lista",  "seletor",  (700, 280), "#151515"),
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

# Music and Downloads are optional standard folders, so the root-volume row moves vertically
# across machines. Probe the stable right edge of the sidebar and require one full selected-row
# run instead of binding the color contract to a host-specific y coordinate.
seletor = fotos["seletor"]
pill = (0x23, 0x23, 0x23)
selected_rows = [
    y for y in range(200, 430)
    if max(abs(a - b) for a, b in zip(seletor.getpixel((340, y)), pill)) <= TOLERANCIA
]
if len(selected_rows) < 20:
    print("FALHA: seletor não mostra uma faixa de disco escolhido em #232323")
    falhas += 1
else:
    print(f"ok:    seletor mostra disco escolhido em #232323 ({len(selected_rows)} px)")

# A capa arredondada: no canto do quadrado a arte NÃO pode aparecer, senão o `radius` está
# desenhado embaixo de uma imagem de canto vivo — o defeito que o RoundedImage existe para
# resolver, e que compila verde de qualquer jeito.
capa = fotos["biblioteca"]
canto = capa.getpixel((84, 24))     # 2 px para dentro do canto superior esquerdo da capa
fora = capa.getpixel((80, 24))      # painel imediatamente antes da capa
centro = capa.getpixel((250, 190))  # no meio da arte
if (max(abs(a - b) for a, b in zip(canto, fora)) > TOLERANCIA
        or max(abs(a - b) for a, b in zip(fora, centro)) < 8):
    print(f"FALHA: canto={canto}, fora={fora}, miolo={centro} — a capa está quadrada")
    falhas += 1
else:
    print("ok:    a capa está arredondada (o canto preserva o painel)")

# The old dashed Canvas alternated between the dark stroke and the brighter gradient 44 times
# across this straight edge, which looked jagged even at rest. Exclude corners and require the
# replacement outline to remain continuous.
vazio = fotos["vazio"]
linha = [max(vazio.getpixel((x, 24))) for x in range(110, 395)]
escuro = [nivel < 45 for nivel in linha]
transicoes = sum(a != b for a, b in zip(escuro, escuro[1:]))
if transicoes > 4 or sum(escuro) < len(escuro) * 0.9:
    print(f"FALHA: borda do placeholder continua quebrada ({transicoes} transições)")
    falhas += 1
else:
    print(f"ok:    borda do placeholder é contínua ({transicoes} transições)")

sys.exit(1 if falhas else 0)
PY
