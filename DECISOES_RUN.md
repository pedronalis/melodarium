# Decisões do run — leva 1 (clique-responde · fila-motor)

Sessão headless autônoma, branch `exec/melodia-religa`, 2026-08-28.
Cada item registra a decisão tomada, a alternativa descartada e o custo de estar errada.

## 1. `grep -c 'heart-filled' src/NowPlayingPanel.qml` esperava 2, dá 1

**Contexto.** A Task 3 do plano `clique-responde` manda a verificação mecânica
`grep -c 'heart-filled' src/Icons.qml src/TrackRow.qml src/NowPlayingPanel.qml` →
`src/NowPlayingPanel.qml:2`. O próprio bloco de código que o plano prescreve para esse
arquivo tem `heart-filled` numa única linha (`icon: root.info.liked === true ?
"heart-filled" : "heart"`), e `grep -c` conta LINHAS casadas, não ocorrências.

**Decisão.** O código do plano foi colado exatamente como escrito; a expectativa numérica
do plano é que está errada. O valor correto é 1. Aceito 1 como verde.

**Alternativa descartada.** Inventar uma segunda referência a `heart-filled` no arquivo só
para satisfazer o número — isso seria escrever código para agradar um grep.

**Custo de estar errada.** Nenhum funcional: o comportamento pedido (curtido = forma sólida,
não só cor) está entregue nos dois lugares que o desenho exige (a linha da lista e o painel).
O portão do objetivo do run cobra `grep -c 'heart-filled' src/Icons.qml` → 1, que passa.

## 2. O trilho de volume mantém `implicitHeight: 3` fixo, sem `Theme.uiScale`

**Contexto.** O perigo nº 8 do repositório manda todo tamanho NOVO de interface passar por
`Theme.uiScale`. O bloco de volume que a Task 6 prescreve traz `implicitHeight: 3` literal.

**Decisão.** Fica literal. O trilho da barra de progresso, logo acima no mesmo painel
(`Rectangle { id: track }`), já é `implicitHeight: 3` — o padrão vigente do app. Escalar só
o trilho de volume poria dois trilhos de espessuras diferentes um debaixo do outro na
mesma coluna.

**Alternativa descartada.** Trocar por `Math.round(3 * Theme.uiScale)`. Isso resolveria o
perigo nº 8 pela metade e criaria uma incoerência visível.

**Custo de estar errada.** Numa tela muito grande os dois trilhos ficam finos JUNTOS, que é
o defeito que o app já tem hoje e que se conserta numa passada só, nos dois, quando alguém
decidir a espessura certa. Nenhum trilho fica mais fino que o outro por causa desta fatia.

## 3. A aceitação visual não capturou o painel `collections`

**Contexto.** O briefing manda provar o resultado em tela virtual com
`--pane <library|collections|podcast>`. O app aceita hoje `library`, `podcast` e `empty`
(`src/Main.qml`, propriedade `measurePane` e o `currentIndex` do `StackLayout`). Não existe
painel de coleções para fotografar.

**Decisão.** Capturei `library` e `podcast`, mais uma terceira tela com música tocando
(`--play-track`), que é a única que mostra o transporte com o volume novo. `collections` fica
para quando a fatia `colecoes-tela` — que é da leva 2, não desta — construir o painel.

**Alternativa descartada.** Inventar um `--pane collections` nesta fatia só para satisfazer o
comando do briefing. Isso seria adiantar meia fatia de outra leva, e produziria exatamente o
defeito que este lote existe para curar: uma porta de entrada para um painel que não existe.

**Custo de estar errada.** Nenhum: as três telas capturadas cobrem tudo que as duas fatias
desta leva alteram (a tira de ícones, o coração sólido na lista, o transporte com volume, os
chips como eixo). A fila desta leva é motor puro, sem tela — o próprio plano diz isso.

## 4. O rail aparece aceso em "Biblioteca" na captura do painel de podcast

**Contexto.** Em `docs/telas/leva1-final-podcast.png` o miolo mostra Episódios enquanto o
ícone aceso na tira é o da Biblioteca.

**Decisão.** Não é defeito e não foi mexido. Em modo `--measure` o `currentIndex` do
`StackLayout` é forçado pela flag `--pane` e ignora `root.section` de propósito — o
comentário no próprio código diz por quê: "qual banco a máquina tem não pode mudar o
resultado do gate de layout". No app de verdade quem troca o painel é o clique na tira, que
escreve `root.section`, e aí os dois concordam.

**Alternativa descartada.** Fazer `--pane` escrever `root.section` também. Mexeria no harness
de medição que os 11 gates de layout usam, dentro de uma fatia que não tem nada com isso.

**Custo de estar errada.** Se fosse defeito de verdade, apareceria como ícone aceso errado ao
navegar no app real — e não aparece, porque `showPane` escreve `section` e o rail lê `section`
(`current: root.section`, `src/Main.qml`).

## 5. `RESUMO_RUN.md` fica fora do git; `DECISOES_RUN.md` fica dentro

**Contexto.** `git add RESUMO_RUN.md` foi recusado: o arquivo está listado no
`.git/info/exclude` do repositório principal, junto de `RUN_GATE` e afins. `DECISOES_RUN.md`
não está.

**Decisão.** Respeitei a exclusão em vez de forçar com `-f`. O resumo existe no disco do
worktree, que é de onde quem despachou o run vai lê-lo. As decisões continuam versionadas,
porque explicam escolhas feitas no código e sobrevivem ao run.

**Alternativa descartada.** `git add -f RESUMO_RUN.md`. A exclusão é anterior a este run e
foi escrita de propósito — passar por cima dela seria decidir por quem a escreveu.

**Custo de estar errada.** Se o resumo devia mesmo ser versionado, basta um `git add -f`
depois; o arquivo está pronto e intacto no worktree.
