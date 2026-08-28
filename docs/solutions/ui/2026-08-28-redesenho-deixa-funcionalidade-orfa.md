---
title: Redesenho que troca o shell da UI deixa funcionalidade órfã — e o build passa verde
category: ui
module: Main.qml, IconRail.qml, Sidebar.qml
symptoms:
  - "app parece pela metade mesmo com todas as fatias marcadas concluido"
  - "clicar num item de menu acende o item e não muda nada na tela"
  - "funcionalidade construída e testada não tem porta de entrada nenhuma"
  - "ctest verde, gate de layout verde, e um terço das funções invisível"
tags: [qml, redesign, orfao, regressao, gate, ledger]
---

## O problema

O redesenho `melodia-capa-manda` trocou o shell da janela: `Sidebar.qml` (menu largo com
Coleções, Artistas, Álbuns, Gêneros, Tags, Todas as faixas) saiu no commit `ec45204` e entrou
`IconRail.qml`, cinco ícones. A barra de transporte do rodapé saiu em `738acd3` e virou
`NowPlayingPanel.qml`.

Nenhum dos dois commits apagou o que substituiu. `Sidebar.qml` continua no disco, continua
registrado em `CMakeLists.txt`, continua **compilando** — e nenhum QML o instancia. Junto com
ele ficaram órfãos `CollectionsSection.qml` (o diferencial nº 1 do spec), `AddFromLinkDialog.qml`
(colar link do YouTube), `DownloadProgressRow.qml` e `QueuePanel.qml`.

Auditoria de 2026-08-28: **24 lacunas confirmadas**, todas nascidas dessas duas trocas ou do
hábito de desenhar o botão e adiar a função. Os catorze planos estavam `status: concluido`.

## Por que nada acusou

Três gates rodaram verdes o tempo todo:

1. **O compilador.** Um `.qml` órfão registrado no módulo compila igual. Órfão não é erro.
2. **`ctest` (9 alvos).** Os testes exercitam o C++ (`CollectionManager`, `YtDlpDownloader`)
   direto, nunca pela tela. Motor testado + tela desligada = suíte verde.
3. **`tools/check-layout.sh`.** Mede largura de painel e de chips. Uma tela pode estar
   perfeitamente medida e completamente inerte.

O ledger também mentiu: fatia marcada `concluido` no dia em que funcionou continua `concluido`
depois de um redesenho posterior desligá-la. **Concluído não é um estado permanente quando
uma fatia futura reescreve o shell.**

## A regra

**Toda fatia que substitui um contêiner de UI deve, no mesmo commit, ou religar ou apagar o
que o contêiner antigo hospedava.** Deixar o arquivo no disco "para reaproveitar depois" é
o modo de falha: ele some do radar de todo mundo e do de todos os gates.

## O detector (barato, roda em segundos)

```bash
# Todo componente QML que nenhum outro QML instancia.
for f in src/*.qml; do
  n=$(basename "$f" .qml)
  case "$n" in Main|Theme|Icons) continue;; esac   # raiz e singletons
  grep -qlE "(^|[^A-Za-z])${n}[[:space:]]*\{" $(ls src/*.qml | grep -v "/${n}.qml$") \
    || echo "ÓRFÃO: $n"
done
```

Cuidado com um falso positivo: **singleton QML não é instanciado, é chamado** (`Icons.get(...)`).
Excluir `Theme` e `Icons` à mão, como acima.

Complemento em C++ — `Q_INVOKABLE` que nenhum QML chama é motor sem botão:

```bash
grep -hoP 'Q_INVOKABLE.*?\b(\w+)\(' src/*.h | grep -oP '\w+(?=\()' | sort -u \
  | while read -r m; do grep -q "\.$m(" src/*.qml || echo "NUNCA CHAMADO: $m"; done
```

Foi assim que apareceram `setReplayGainMode`, `setExclusiveOutput`, `setVolume`, `cancelScan`,
`unsubscribe`, `continueListening` e toda a gerência de coleções (`renameCollection`,
`deleteCollection`, `removeTrackFromCollection`, `moveTrackInCollection`): construídos,
testados, inalcançáveis.

Os dois detectores têm ruído previsível — triar à mão, é rápido:

- **Órfão transitivo não aparece no detector 1.** `CollectionsSection` passa limpo porque
  `Sidebar` o instancia; só que `Sidebar` é órfão. Depois de listar os órfãos diretos,
  perguntar de cada um o que ELE hospedava.
- **Um invocável coberto por outro não é morto.** `pause()` e `stop()` saem na lista, mas o
  botão chama `togglePause()`. Conferir o irmão antes de acusar.

## O que NÃO funcionou

- **Confiar no `status: concluido` dos planos.** Catorze fatias concluídas produziram um app
  pela metade. O ledger registra o dia da entrega, não o estado de hoje.
- **Confiar em `ctest`.** Nove alvos verdes com a tela morta. Teste de C++ não atravessa o QML.
- **Confiar no `check-layout.sh`.** Ele mede geometria, não alcançabilidade. Uma tela inerte
  passa nas onze medidas.
- **Confiar em captura de tela.** As quatro fotos em `docs/telas/` mostram a tela montada e
  bonita. Nenhuma foto revela que três dos cinco ícones não navegam — só o clique revela, e
  ninguém clicou até o dono abrir o app.
- **Grep ingênuo por órfão.** Sem excluir os singletons, `Icons` e `Theme` aparecem como
  órfãos e poluem o resultado logo na primeira execução.
