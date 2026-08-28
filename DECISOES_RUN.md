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

## 10. A tirinha da fila teria congelado: `upcoming()` é método, e método não cria dependência

**Contexto.** A Task 1 do plano `fila-tirinha` traz
`readonly property var proximos: AudioEngine.upcoming(root.lookahead)`. O QML só registra
dependência em LEITURA DE PROPRIEDADE; uma chamada de método invocável não é rastreada. Essa
ligação seria avaliada uma vez, ao nascer o componente — quando a fila ainda está vazia — e
nunca mais. A tirinha ficaria invisível para sempre, com build verde e sem um único aviso.
É o mesmo gênero de defeito que produziu este lote: funciona por dentro, não chega à tela.

**Decisão.** Mantive a chamada a `upcoming()` (é a interface que o plano contratou e o que
tira o invocável da lista de órfãos) e acrescentei duas leituras explícitas das propriedades
que decidem a resposta, `AudioEngine.queueCount` e `AudioEngine.playlistPos`, com comentário
dizendo por quê. As duas têm NOTIFY (`queueChanged`, `playlistPosChanged`), então a ligação
recalcula quando a fila é trocada e quando ela anda.

**Alternativa descartada.** Calcular a fatia em QML a partir de `AudioEngine.queue` e
`playlistPos`, sem chamar `upcoming()`. Duplicaria em JavaScript uma regra que já existe em
C++ testado, e deixaria `upcoming` órfão — que é justamente um dos itens que esta fatia
tinha de tirar do `check-orfaos.sh`.

**Custo de estar errada.** Se eu estiver errado sobre o rastreamento, as duas leituras são
inertes e não custam nada. Se estiver certo (e a foto com a fila carregada DEPOIS da
construção da tela é a prova), sem elas a fatia não entregaria nada.

**Correção, depois de medir.** A primeira versão da correção escrevia
`void AudioEngine.queueCount` — ler a propriedade e descartar. Não funcionou: a foto saiu sem
tirinha nenhuma. Instrumentei o componente e o sinal de mudança disparou UMA vez só, com
`queueCount=0`. Uma expressão sem efeito colateral é eliminada pelo compilador, e a
dependência morre junto com ela. A versão que funciona **usa** os dois valores
(`const total = AudioEngine.queueCount; const pos = AudioEngine.playlistPos;` seguidos de uma
guarda que os compara). Com ela o log mostrou a sequência inteira: `queueCount=0` na
abertura, depois `queueCount=27 pos=0 restantes=22 visible=true`, e a tirinha aparece na
foto. Lição para quem repetir isto: **ler a propriedade não basta — o valor lido tem de ser
usado.**

## 11. O `hitAt()` do plano indexava a lista errada — Shift+Enter nunca teria enfileirado nada

**Contexto.** A Task 3 do plano `fila-tirinha` propõe um `hitAt(index)` que monta
`root.buildRows(root.hits)` e indexa ESSA lista. Mas `buildRows` intercala cabeçalhos de
grupo ("FAIXAS", "ÁLBUNS") entre os resultados, e o `highlighted` que o teclado move é índice
de `hits`, não de linhas (`move()` o limita a `root.hits.length - 1`). Com o `hitAt` do
plano, `highlighted = 0` cairia no cabeçalho da primeira linha, `linha.hit` seria `undefined`,
e `queueAt` sairia calada. Shift+Enter não faria nada — de novo um botão que mente, que é o
defeito que este lote existe para consertar.

**Decisão.** `hitAt(index)` devolve `root.hits[index]` com a mesma guarda que o `activate`
original já usava, e o `activate` passou a chamá-lo — assim as duas funções realmente
compartilham UMA travessia, que era a intenção declarada do plano.

**Alternativa descartada.** Colar o `hitAt` do plano como está. Passaria no `grep` de
verificação da task (que conta `trackQueued|ShiftModifier`, não comportamento) e entregaria
um atalho morto.

**Custo de estar errada.** Nenhum: `activate` continua com a guarda idêntica à de antes, e os
quatro tipos de resultado seguem o mesmo caminho.

## 12. O rodapé da busca usa a peça `Dica`, não o `Text` solto do plano

**Contexto.** O plano manda acrescentar ao rodapé um `Text` com o literal
`"⇧↵ pôr na fila"`. O rodapé já é feito de `Dica { tecla: …; acao: … }`, uma peça declarada
no próprio arquivo que pinta a tecla numa cor e a ação em outra. E o desenho
(`design/Busca.dc.html:330`) mostra a dica nova exatamente na mesma forma das vizinhas.

**Decisão.** `Dica { tecla: "⇧↵"; acao: qsTr("pôr na fila") }`, entre "tocar" e o espaçador —
posição do desenho. A referência mandava nesta ordem: desenho primeiro, padrão do app
depois, plano por último.

**Alternativa descartada.** O `Text` do plano. Sairia numa cor só, sem separar tecla de ação,
destoando das três dicas ao lado — e sem tradução.

**Custo de estar errada.** Visual e reversível numa linha.

## 13. Duas bandeiras de medição a mais, para a fila poder ser fotografada e o atalho, provado

**Contexto.** O comando de prova que o plano `fila-tirinha` traz é
`--play-track "<um arquivo>"`, que monta uma fila de UM. Com fila de um não há "a seguir", a
tirinha fica corretamente invisível, e a foto não prova nada. E o Shift+Enter, por ser uma
tecla, não tem como ser acionado em tela virtual: sem alguma porta, a única evidência
possível seria "o rodapé anuncia o atalho" — que é literalmente o defeito que este lote
conserta (botão que anuncia e não faz).

**Decisão.** Duas bandeiras, só ativas em `--measure`: `--play-queue`, que carrega a
biblioteca como fila e toca a primeira; e `--queue-hit`, que manda o overlay de busca
enfileirar o resultado em destaque e fechar — o mesmo caminho de código do Shift+Enter
(`queueAt` → `trackQueued` → `appendToQueue`). As provas:
`docs/telas/leva2-fila-tirinha.png` (quatro capas e "+22" com 27 na fila) e
`docs/telas/leva2-busca-enfileirou.png` (o noturno de Chopin seguindo em 0:02 enquanto o
resultado buscado aparece como próximo — "sem interromper o que toca", que é a frase do
objetivo da fatia).

**Alternativa descartada.** Declarar a fatia pronta com a foto do rodapé, que mostra a dica
"⇧↵ pôr na fila" e não prova que a tecla faz alguma coisa.

**Custo de estar errada.** As duas só existem sob `--measure`; no app normal não há nada
diferente. Somadas à `--open-collection`, o harness ganhou três entradas — todas do mesmo
feitio das cinco que já tinha.

## 14. `ctest` roda o binário que existe, não o código que está no disco

**Contexto.** Depois de implementar `cycleRepeat`, rodei
`quiet-run ctest --test-dir build -R tst_audioengine` e li `100% tests passed`. Fui conferir
qual teste tinha passado e o binário respondeu
`Unknown test function: 'repeatCyclesThroughThreePositions'`: o ctest tinha rodado o
executável ANTERIOR, de antes da compilação falhar na etapa do teste vermelho. O verde era
sobre código que não existia.

**Decisão.** `quiet-run cmake --build build` **antes** de todo `ctest`, e conferência do
teste novo por nome (`./build/tests/tst_audioengine -functions` e execução isolada com
`-v1`, que mostra `3 passed, 0 skipped`). O mesmo cuidado vale para o `QSKIP` por falta de
ffmpeg: um teste pulado também sai verde.

**Alternativa descartada.** Confiar no `100% tests passed`. É o primo do "suíte verde não
prova que a tela existe" que motivou este lote inteiro — aqui, suíte verde não prova nem que
o código foi compilado.

**Custo de estar errada.** Se eu não tivesse conferido, esta fatia teria fechado com um teste
fantasma e uma função possivelmente quebrada.

## 15. O aleatório do plano reiniciava a música. Medido, trocado por `playlist-move`

**Contexto.** A Task 2 do plano `shuffle-repeat` implementa `reloadQueueKeepingCurrent()`
reescrevendo a playlist do mpv com `loadfile <arquivo> replace` seguido de `append`. No mpv,
`replace` limpa a lista e **começa o arquivo do zero**. Apertar aleatório no meio de uma
faixa mandaria a faixa de volta ao início — num tocador de música, o gesto mais visível que
existe.

**Prova.** Escrevi `shuffleDoesNotRestartWhatIsPlaying`: toca um tom de 8 s, espera passar de
3 s, liga o aleatório, espera 800 ms. Com o código do plano:
`a faixa voltou ao início: 3.01639 s -> 0.691546 s`.

**Decisão.** Troquei por `reorderMpvPlaylist(const QStringList &atual)`, que leva a lista do
mpv da ordem antiga para a nova com `playlist-move`, entrada por entrada. O mpv move as
entradas sem interromper nada e leva o índice do que toca junto. Com ele o teste passa. O
nome mudou junto com o mecanismo: `reloadQueueKeepingCurrent` descrevia recarregar, e não é
mais isso que acontece.

**Alternativa descartada.** Manter o `replace` e recuperar a posição com um `seek` depois do
arquivo carregar. Seria uma corrida contra o carregamento do mpv para desfazer um estrago que
não precisava acontecer.

**Custo de estar errada.** `playlist-move` é uma operação de lista; se a permutação estivesse
errada, tocaria a faixa errada a seguir — que é justamente o que o teste da decisão nº 16
cobre.

## 16. O primeiro teste do reordenador era vacuoso — passava com o reordenador desligado

**Contexto.** Escrevi `shuffleReordersWhatMpvPlaysNext` para provar que embaralhar mexe na
fila do mpv, e não só no espelho que a tela lê (se mexesse só no espelho, a tirinha mostraria
uma ordem e o som seguiria outra — exatamente o gênero de defeito deste lote). A primeira
versão dava `next()` com a música tocando e esperava o arquivo esperado com
`QTRY_COMPARE_WITH_TIMEOUT(…, 10000)`.

**Prova de que não prestava.** Desliguei o reordenador com um `return` no topo, recompilei, e
o teste **passou assim mesmo** (2642 ms). A causa: com tons de 1 s a fila anda sozinha e em
10 s passa por TODOS os arquivos — esperar por um deles sempre acaba dando certo.

**Decisão.** A versão final pausa antes de pular, espera `playlistPos == 1` e compara o
arquivo UMA vez, num instante só. Repeti a mutação: com o reordenador desligado agora dá
`FAIL! Compared values are not the same`; com ele ligado, passa. O `return` foi revertido e a
conferência refeita.

**Alternativa descartada.** Aceitar o verde da primeira versão. Teria fechado a fatia com um
teste que não testava nada — a definição do problema que este lote existe para corrigir.

**Custo de estar errada.** Nenhum: os dois estados (mutado e são) foram medidos no
transcript, não inferidos.

## 17. Suspeitei do aleatório da tela vazia, o teste me desmentiu, e a FOTO me deu razão

**Contexto.** A Task 4 faz `loadPlaylist(paths, 0)` e só então `setShuffle(true)`. Nesse
instante o mpv já recebeu a ordem antiga e começou a primeira entrada dela. Suspeitei que ele
ficasse presa nela — e aí "Tocar tudo em ordem aleatória" tocaria só um pedaço da fila,
sempre começando pela mesma faixa.

**Decisão.** Em vez de "consertar" por precaução, escrevi o teste
`shuffleFromAStandstillStartsAtTheTopOfTheNewOrder`, que monta a situação exata (motor novo,
nada tocando, carrega, embaralha, pausa) e cobra que o arquivo tocado seja `queue[0]` da
ordem NOVA. **Passou.** A suspeita estava errada: com a reordenação por `playlist-move`, o
mpv acompanha. Nenhuma linha foi acrescentada por precaução, e o teste ficou — com a mutação
conferida (`FAIL! Compared values are not the same` com o reordenador desligado).

**Alternativa descartada.** Acrescentar um `playlist-pos = 0` "por garantia" depois do
embaralhamento. Seria código sem defeito que o justificasse, e mais uma linha para alguém
entender depois.

**Custo de estar errada.** Zero: a hipótese virou teste em vez de virar código.

**CORREÇÃO — a suspeita estava CERTA, e o teste é que mentia.** Ao fotografar os botões
ligados, a tirinha mostrou "+21" com 27 na fila e 4 capas, o que só fecha com a posição em 1,
não em 0. Instrumentei o app e a conta era pior: `pos=24 count=27`, tocando a faixa original
nº 1, que o embaralhamento tinha levado para o índice 24. "Tocar tudo em ordem aleatória"
tocava **três** faixas de 27. O teste passava porque com cinco tons de 1 s a reordenação
termina antes de o mpv abrir o primeiro arquivo; com 27 MP3 de verdade, não termina — é uma
corrida, e o tamanho da fila decide quem ganha. Escalei o teste para 26 entradas e **ainda
assim passou**: arquivo minúsculo abre rápido demais para reproduzir. A evidência boa é a
medição no app, não a suíte.

**A correção.** Em `setShuffle`, quando `m_playlistPos < 0` (nada começou a tocar ainda),
escrever `playlist-pos = 0` depois de reordenar. A guarda importa: com música tocando,
`m_playlistPos >= 0` e mexer ali interromperia a faixa. Medido depois: `pos=0` e o arquivo
tocando é o `queue[0]` da ordem nova, em quatro execuções seguidas com ordens diferentes.

**Lição.** Um teste verde num fixture minúsculo não é evidência sobre um app que abre
arquivos reais. Foi o "+21" numa foto — três pixels de texto — que denunciou o defeito, não a
suíte.

## 18. Nota: o plano lista `src/EmptyPane.qml` como arquivo a modificar e nenhuma task o toca

**Contexto.** A seção "Arquivos" de `shuffle-repeat` inclui `src/EmptyPane.qml`, mas as
quatro tasks só mexem em `audioengine.{h,cpp}`, `NowPlayingPanel.qml`, `Main.qml` e o teste.

**Decisão.** Não mexi. O `EmptyPane` já emite `playRequested("shuffle")` e quem trata isso é
o `startFromEmpty` do `Main.qml`, que é justamente o que a Task 4 mudou. O comportamento
pedido chegou inteiro sem tocar no arquivo.

**Alternativa descartada.** Inventar uma mudança no `EmptyPane` para cumprir a lista.

**Custo de estar errada.** Se faltasse algo lá, o botão "Tocar tudo em ordem aleatória" não
ligaria o modo — e o portão `grep -c 'AudioEngine.setShuffle' src/Main.qml` → 1 mostra que a
ligação está no lugar por onde o sinal passa.

## 19. O teste do aleatório-parado ficou instável, e a instabilidade era dele

**Contexto.** Depois da correção acima, `shuffleFromAStandstillStartsAtTheTopOfTheNewOrder`
passou a falhar em 2 de 3 execuções, na linha que compara o arquivo tocando.

**Decisão.** A corrida era do teste: escrever `playlist-pos` manda o mpv **carregar**, e o
teste comparava o arquivo no instante seguinte, antes de o carregamento acontecer. Troquei a
comparação imediata por `QTRY_COMPARE_WITH_TIMEOUT` — seguro aqui porque o teste pausa antes,
e uma fila pausada não anda sozinha para passar pelo esperado por acaso (que foi o defeito da
decisão nº 16). Conferido: 10 execuções isoladas e 5 da suíte inteira, todas
`16 passed, 0 failed, 0 skipped`.

**Alternativa descartada.** Aumentar um `qWait` fixo. Esconderia a corrida em vez de esperar
pelo evento certo, e voltaria a falhar numa máquina mais lenta.

**Custo de estar errada.** Um teste instável é pior que nenhum: ensina a ignorar vermelho.
Por isso a conferência foi por repetição, não por uma execução verde.

## 20. O "ligado" dos dois botões é visível, mas discreto — e fica como está, com a medida

**Contexto.** Ampliei a fileira de transporte para conferir o estado aceso e, a olho, o
aleatório parecia idêntico ligado e desligado. Medi os pixels do ícone em vez de julgar pela
vista: desligado `#828282` (`mOnSurface`), ligado `#aaaaaa` (`mPrimary`). O `accent` está
sendo aplicado — o que o deixa discreto é a paleta do Noctalia do próprio Pedro
(`~/.config/noctalia/colors.json`), que é monocromática: entre `mPrimary` e `mOnSurface` há
40 níveis de cinza e nenhuma cor. Na paleta de reserva do app (`mPrimary #fff59b`, amarelo)
a diferença seria berrante.

**Decisão.** Fica como o plano manda. Consultei a referência na ordem: o desenho
(`design/Main.dc.html:61-69`) mostra os dois botões apagados e **nunca desenhou** o estado
ligado; o padrão vigente do app para "ligado" é o `accent` do `IconButton`; e o plano escolheu
exatamente esse. Os três apontam para o mesmo lugar. O terceiro estado do repetir (esta
faixa) ganha o "1" sobreposto, que se distingue por forma e não só por cor — esse aparece bem
na foto.

**Alternativa descartada.** Marcar "ligado" com uma pílula de fundo, como a tira de ícones faz
com o modo selecionado. Seria mais visível na paleta do Pedro, mas mudaria o `IconButton`,
que é usado em todo o app, para resolver um contraste que vem do tema dele — e sem nenhum
desenho aprovado pedindo.

**Custo de estar errada.** Se o Pedro achar discreto demais na tela dele, é uma linha no
`IconButton`. A medida está aqui para ele decidir sem precisar reabrir o assunto do zero:
`#828282` → `#aaaaaa`.

## 21. O RUN_GATE reprova em 2 linhas, e reprovar é o resultado correto desta leva

**Contexto.** O `RUN_GATE` do worktree diz de si mesmo, na primeira linha: "Portão do lote
melodia-religa. O lote só está PRONTO quando o trabalho está integrado em main NO REPO
PRINCIPAL". Ele aponta para `/home/pedro/dev/active/melodia`, não para este worktree. As duas
linhas vermelhas são:

- `bash /home/pedro/dev/active/melodia/tools/check-orfaos.sh` → rc=127, o arquivo não existe
  lá. O detector foi criado na leva 1, no commit `d1e1a88`, e
  `git branch --contains d1e1a88` responde apenas `exec/melodia-religa` — o repo principal
  está em `main` e ainda não o tem.
- `test -f INTEGRADO.ok` → o marcador de integração.

**Decisão.** Nenhum dos dois foi fabricado. A instrução desta leva é literal: "NÃO faça merge
nem integração nesta leva — a leva 3 integra tudo", e a fronteira do repo é "commits locais,
nunca push, nunca PR". Copiar o detector para o repo principal É integração; criar o
`INTEGRADO.ok` é afirmar por escrito uma coisa que não aconteceu. O objetivo verificável
DESTA leva tem nove linhas e as nove passam — elas estão no transcript com comando e saída.

**Alternativa descartada.** Criar o arquivo vazio para o portão ficar verde. Seria falsificar
o estado do lote para o único leitor que confia nele.

**Custo de estar errada.** Se o portão devia mesmo fechar aqui, fechá-lo custa um `touch` na
leva 3 — depois da integração de verdade, que é quando ele passa a ser verdade.

## 22. Achado para a leva 3: o detector de órfãos NÃO fica verde só com este lote

**Contexto.** Fui verificar se algum dos 14 órfãos restantes era responsabilidade das minhas
três fatias. Nenhum era: os oito nomes que os planos `colecoes-tela`, `fila-tirinha` e
`shuffle-repeat` mandavam limpar sumiram todos. Mas o mapeamento revelou outra coisa.

**O achado.** Dos 14, dez pertencem às fatias que faltam (`colecoes-alcance` e `ajustes`).
Os outros **quatro não pertencem a nenhuma fatia deste lote**:

| órfão | vem de | status daquela fatia |
|---|---|---|
| `LibraryEmptyState` | `2026-08-27-tocador-ui` | concluido |
| `SearchField` | `2026-08-27-navegacao-biblioteca` · `colecoes-tags` | concluido · **travado** |
| `continueListening` | `2026-08-27-podcast-local` · `podcast-vazio` | concluido |
| `ingestDownloadedFile` | `2026-08-27-download-youtube` | **travado** |

Nenhum deles aparece em `docs/auditoria-completude.md`. São restos de um lote anterior, dois
deles de fatias travadas.

**Consequência prática.** A linha `bash …/tools/check-orfaos.sh` do `RUN_GATE` continuará
saindo rc=1 mesmo depois de `colecoes-alcance` e `ajustes` — ou seja, mesmo com o lote
melodia-religa inteiro pronto e integrado. Para a leva 3 isso significa uma escolha
consciente entre três saídas, e nenhuma delas é "insistir e esperar ficar verde": pôr os
quatro na lista de exceções do próprio detector (que já tem uma, `CPP_OK`/`QML_OK`), abrir uma
fatia para eles, ou trocar a linha do portão por um piso ("não mais que N").

**Correção do registro da leva 1.** O `ORQUESTRADOR.log` da leva 1 diz que os 20 órfãos eram
"todos das levas 2 e 3". Não eram: quatro já estavam fora do alcance do lote naquele momento
e continuam agora.
