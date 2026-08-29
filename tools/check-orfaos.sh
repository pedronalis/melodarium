#!/usr/bin/env bash
# Lista todo componente QML que nenhum outro QML instancia, e todo Q_INVOKABLE que nenhum
# QML chama. Foi a ausência deste portão que deixou um terço do app invisível com a suíte
# verde: um .qml órfão compila igual a um vivo, e teste de C++ não atravessa a tela.
#
# Sai 1 quando encontra órfão NOVO (fora da lista de exceções abaixo), 0 quando não.
set -u
cd "$(dirname "$0")/.." || exit 2

# Exceções conscientes. Singletons não são instanciados, são chamados (Icons.get(...)).
# Um invocável coberto por outro (pause/stop, cobertos por togglePause) também não é morto.
QML_OK="Main Theme Icons"
CPP_OK="pause stop trackAt episodeAt loadForShow isLiked recordSkip downloadDirectory"

# RESERVA DECLARADA: motor pronto e testado, gesto ainda não pedido por spec nem desenho.
# Diferente do CPP_OK acima: estes NÃO têm outro caminho: eles esperam uma tela que ninguém
# desenhou. Não é um silenciador — o detector imprime a lista a cada execução, para que
# reserva nunca se confunda com esquecimento. Foi funcionalidade esquecida atrás de um verde
# que produziu o lote melodia-religa, e um item dispensado que ninguém mais vê é exatamente
# um item esquecido.
#   collectionsForTrack   · marcar no menu quais coleções já têm a faixa: sem desenho
#   continueListening     · "continuar ouvindo" não aparece em design/Podcast.dc.html
#   ingestDownloadedFile  · pertence à fatia download-youtube, que está travada
#   setGaplessAggressive  · o gapless agressivo não está em desenho nenhum
#   unsubscribe           · o par de subscribe; desinscrever não tem tela nem desenho
CPP_RESERVA="collectionsForTrack continueListening ingestDownloadedFile \
setGaplessAggressive unsubscribe"

falhas=0
reserva=""

for f in src/*.qml; do
  n=$(basename "$f" .qml)
  case " $QML_OK " in *" $n "*) continue ;; esac
  outros=$(ls src/*.qml | grep -v "/${n}.qml$")
  if ! grep -qlE "(^|[^A-Za-z])${n}[[:space:]]*\{" $outros 2>/dev/null; then
    echo "ÓRFÃO QML: $n — existe no disco, nenhum outro QML o instancia"
    falhas=$((falhas + 1))
  fi
done

for m in $(grep -hoP 'Q_INVOKABLE.*?\b(\w+)\(' src/*.h | grep -oP '\w+(?=\()' | sort -u); do
  case " $CPP_OK " in *" $m "*) continue ;; esac
  if ! grep -q "\.$m(" src/*.qml; then
    case " $CPP_RESERVA " in
      *" $m "*) reserva="$reserva $m"; continue ;;
    esac
    echo "NUNCA CHAMADO: $m — motor pronto sem botão que chegue nele"
    falhas=$((falhas + 1))
  fi
done

echo "----------------------------------------"
[ -n "$reserva" ] && echo "em reserva declarada, esperando tela:$reserva"
echo "check-orfaos: $falhas item(ns) sem porta de entrada"
[ "$falhas" -eq 0 ]
