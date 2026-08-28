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

---

# Decisões do run — leva 2 (colecoes-tela · fila-tirinha · shuffle-repeat)

## 6. `grep -c 'renameId' src/NewCollectionDialog.qml` esperava 5, dá 7

**Contexto.** A Task 1 do plano `colecoes-tela` pede `grep -c 'renameId'` → `5`. O próprio
código que o plano prescreve para esse arquivo espalha `renameId` por sete LINHAS: o
comentário explicativo, a declaração da propriedade, o título, o rótulo do botão, o `if`, a
chamada a `renameCollection` e a emissão de `renamed`. `grep -c` conta linhas casadas.

**Decisão.** O código do plano foi colado exatamente como escrito, comentário incluído; a
expectativa numérica é que está errada. Aceito 7 como verde. Mesmo padrão da decisão nº 1
desta série (o plano contou ocorrências mentalmente e escreveu o número de um grep).

**Alternativa descartada.** Apagar o comentário do plano e reescrever o bloco para caber em
cinco linhas casadas — escrever código para agradar um grep, e jogar fora justamente a
explicação de por que o diálogo tem dois modos.

**Custo de estar errada.** Nenhum funcional: o modo renomear existe, o título e o botão
trocam de texto, e o duplicado de nome volta o aviso em vez de fechar o diálogo. Nenhum
portão do objetivo do run cobra esse número.

## 7. Provei que o portão de erros QML tem dentes antes de confiar nele

**Contexto.** O plano `colecoes-tela` manda provar os popups abrindo-os, porque a lição
`docs/solutions/ui/2026-08-27-popup-final-property-nao-carrega.md` diz que "o conteúdo de um
Popup só é construído na primeira abertura". Mas o comando que o plano dá
(`--measure --pane collections --no-search`) **não abre** nenhum dos três diálogos do painel
novo. Ou o comando prova menos do que o plano acha, ou a lição vale só para o filtro antigo.

**Decisão.** Em vez de deduzir, injetei o defeito exato da lição
(`property bool opened: visible` no `ConfirmDialog`), reconstruí e rodei o portão. Ele
acusou **9** linhas, entre elas as três que importam:
`ConfirmDialog.qml:11:5: Cannot override FINAL property`,
`CollectionsPane.qml:332:5: Type ConfirmDialog unavailable` e
`Main.qml:520:13: Type CollectionsPane unavailable`. Revertido em seguida, o portão voltou a
`0`. Conclusão: com o filtro ALARGADO (que já inclui `unavailable` e `Cannot override`), o
portão pega a redeclaração sem precisar abrir o popup — o que a lição descreve como cego era
o filtro de três padrões, não o gesto de não abrir. Nenhuma linha de código de produto foi
acrescentada só para o gate.

**Alternativa descartada.** Acrescentar ao harness de `--measure` uma rotina que abre e fecha
os três diálogos do painel. Seria código de produto existindo só para o portão, e agora sei
que ele não acrescenta nada: o tipo já falha na instanciação do painel, não na abertura.

**Custo de estar errada.** Se um defeito de popup escapasse assim mesmo, o sintoma seria um
diálogo que não abre no app real. Mas a prova foi feita com o defeito real, no arquivo real,
com o comando real do portão — não é inferência.

## 8. Acrescentei a bandeira de medição `--open-collection`, que o plano não previu

**Contexto.** A aceitação visual do run exige provar que a tela aparece. O painel de coleções
tem DOIS estados, e o segundo — a coleção aberta com as faixas dentro — é a metade da fatia
que o Pedro reclamou ("dá para criar e não dá para abrir"). Em tela virtual não há clique:
sem uma bandeira, esse estado não tem como ser fotografado, e a prova seria só do estado
vazio.

**Decisão.** Acrescentei `--open-collection <id>`, idêntica em forma e propósito às quatro
bandeiras de medição que o app já tinha (`--play-track`, `--play-episode`, `--search-text`,
`--pane`), mais o auxiliar `openById(id)` no painel. As duas fotos estão em
`docs/telas/leva2-colecoes-lista.png` e `docs/telas/leva2-colecoes-aberta.png`.

**Alternativa descartada.** Fotografar só o estado vazio e afirmar que o resto funciona
porque compila. É exatamente o raciocínio que produziu este lote inteiro de 24 lacunas.

**Custo de estar errada.** A bandeira só age em `--measure`; no app normal ela não existe. Se
sobrar, é uma função de dez linhas num harness que já tem quatro iguais.

## 9. As fotos saem de uma CÓPIA do banco, nunca do banco do Pedro

**Contexto.** O banco real (`~/.local/share/melodia/melodia/melodia.db`) tem 27 faixas e
**zero** coleções. Fotografar a lista de coleções exigia dados que ele não tem.

**Decisão.** Copiei o banco com `sqlite3 .backup` para `/tmp/mel-shot/…` e semeei três
coleções lá, rodando o app com `XDG_DATA_HOME=/tmp/mel-shot`. O banco do Pedro continua com
zero coleções — conferido depois de cada escrita.

**Alternativa descartada.** Semear direto no banco dele. Seriam três coleções falsas
aparecendo no app dele amanhã, criadas por um run que ele não estava acompanhando.

**Nota de armadilha.** `cp` do arquivo `.db` copia um banco VAZIO: o SQLite está em modo WAL
e os dados vivem no `-wal`. Só `.backup` (ou copiar os três arquivos) traz os dados.

**Custo de estar errada.** Nenhum: as fotos provam o código, não o acervo. Se o Pedro criar
coleções de verdade, a mesma tela as mostra.
