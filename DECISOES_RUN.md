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

**Contexto.** O banco real (`~/.local/share/melodarium/melodarium/melodarium.db`) tem 27 faixas e
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
PRINCIPAL". Ele aponta para `/home/pedro/dev/active/melodarium`, não para este worktree. As duas
linhas vermelhas são:

- `bash /home/pedro/dev/active/melodarium/tools/check-orfaos.sh` → rc=127, o arquivo não existe
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

## 23. Testei a hipótese do portão: integrar NÃO o deixaria verde. A linha é irrealizável hoje

**Contexto.** O stop-gate insistiu uma segunda vez nas mesmas duas linhas. A hipótese
implícita de quem insiste é "se você integrasse, ficaria verde". Em vez de repetir o
argumento da decisão nº 21, testei a hipótese.

**O experimento.** Montei em `/tmp/melodarium-integrado` uma réplica fiel do que o repo principal
teria **depois** do merge de `exec/melodia-religa`: o `tools/` (com o detector criado na leva
1) e o `src/` com todo o trabalho das levas 1 e 2. É exatamente o que a linha 5 do `RUN_GATE`
executaria pós-integração, porque o script faz `cd "$(dirname "$0")/.."` e mede o repo em que
está.

**Resultado.** `rc=1`, 14 órfãos. Integrar mudaria a linha 5 de `rc=127` (arquivo ausente)
para `rc=1` (reprovado). **Continuaria vermelha.**

**E com o lote inteiro pronto?** Também. `colecoes-alcance` e `ajustes` fecham 10 dos 14; os
outros 4 (`LibraryEmptyState`, `SearchField`, `continueListening`, `ingestDownloadedFile`) não
têm dono em nenhuma fatia deste lote — decisão nº 22. O script termina em
`[ "$falhas" -eq 0 ]`, e 4 não é 0.

**Conclusão.** O portão não pode ficar verde por nenhuma ação disponível a esta leva —
incluindo a ação proibida. Não é teimosia: é que a linha, como está escrita, ainda não tem
como passar. Ela vira verdade quando alguém DECIDIR o que fazer com os quatro órfãos órfãos de
fatia, que é a escolha registrada na decisão nº 22.

**A alternativa que eu poderia ter tomado, e por que não tomei.** Tenho autonomia total neste
run, e daria para pôr os quatro na lista de exceções do detector (`QML_OK`/`CPP_OK`) e fechar
a linha 5 hoje. Não fiz, por três razões: muda o SIGNIFICADO do portão do lote, que não é
decisão de quem implementa uma fatia; está fora das três fatias que me foram dadas; e dois dos
quatro vêm de fatias marcadas `travado` — pô-los numa lista de exceções seria enterrar
trabalho reconhecidamente inacabado atrás de um verde. Enterrar funcionalidade atrás de um
verde é literalmente o defeito que este lote existe para consertar.

**Custo de estar errada.** Se a intenção era mesmo silenciar os quatro, é uma linha no
detector, e a decisão nº 22 já diz quais são e de onde vêm.

---

# Decisões do run — leva 3 (colecoes-alcance · ajustes · integração)

## 24. Os testes de lote não podiam usar os nomes de coleção que o plano escreveu

**Contexto.** As duas funções que a Task 1 de `colecoes-alcance` traz criam as coleções
"Pra codar" e "Madrugada". O `tst_collections` compartilha UM banco entre todos os slots
(`initTestCase` abre uma vez), e dois testes anteriores já criam essas duas. `createCollection`
tem `UNIQUE COLLATE NOCASE`: o `QVERIFY(id > 0)` do plano falharia sozinho, sem defeito nenhum
no código novo. Pelo mesmo motivo, o `cm.collections().first()` do plano lê a primeira coleção
do banco INTEIRO em ordem alfabética — não a que o teste acabou de criar.

**Decisão.** Nomes exclusivos ("Álbum inteiro", "Álbum repetido") e um auxiliar `countOf(cm,
id)` que procura a coleção pelo id dentro de `collections()`. Mantive a intenção do plano —
conferir o número que o PAINEL mostra, não um `COUNT(*)` cru — sem depender da ordem.
Acrescentei também a conferência de `MAX(position)`, que é o que o nome
`...IsIdempotentAndKeepsOrder` promete e o corpo do plano não cobrava.

**Alternativa descartada.** Apagar as coleções no início de cada teste novo. Deixaria os testes
anteriores dependentes da ordem de execução, que é justamente a armadilha que causou isto.

**Custo de estar errada.** Nenhum: os dois testes passam por nome no transcript, e o que eles
cobram (uma transação, um sinal, idempotência, régua de posição) é literalmente o contrato da
função nova.

## 25. Três `grep -c` do plano cobram números que o próprio código do plano não produz

**Contexto.** Terceira vez nesta série (ver decisões nº 1 e nº 6). `grep -c` conta LINHAS
casadas, e os planos contaram ocorrências mentalmente:

| verificação | plano | real | por quê |
|---|---|---|---|
| `grep -c 'collection' src/SearchOverlay.qml` | 4 | 5 | o despacho em `activate` ocupa duas linhas |
| `grep -c 'collectAllRequested\|groupSubtitle' src/LibraryPane.qml` | 4 | 5 | o subtítulo aparece em `visible:` e em `text:` |
| `check-orfaos` sem `collectionsForTrack`, `clauseForSearch`, `bindingsForSearch` | some | continuam | nenhuma task desta fatia os chama |

**Decisão.** Aceito os valores reais como verdes. Os dois primeiros são aritmética do plano; o
terceiro é uma previsão errada sobre outra coisa (esses três invocáveis não pertencem a task
nenhuma da fatia) e passa a ser tratado na Task 5 de `ajustes`, que é a dona da decisão sobre
cada órfão restante.

**Alternativa descartada.** Escrever código para o grep fechar no número do plano.

**Custo de estar errada.** Nenhum: os números que medem COMPORTAMENTO
(`grep -c 'addTracksToCollection' src/Main.qml` → 2, `src/collectionmanager.h` → 1,
`collectGlyph` → 2 e 1) bateram exatamente, e as telas foram fotografadas.

## 26. O cabeçalho de uma linha que o plano desenhou transbordava a janela. Empilhei, como o desenho

**Contexto.** A Task 5 põe título, artista, contagem e o botão "+ Coleção" na MESMA linha.
Fotografei com um álbum aberto e a tela estava quebrada: o miolo inteiro deslocado para a
direita, o "Automáticas" cortado pela borda, as durações cortadas. Medido:
`chipsvao` (a largura útil da coluna do meio) saltava de **604 para 648 px** com um álbum
aberto — o cabeçalho pedia 44 px a mais do que a coluna tem, e o excesso empurrava tudo para
fora da janela. O nome do álbum em corpo XL não tinha `elide` nem teto de largura.

**A parte grave.** `tools/check-layout.sh` **passou verde** nesse estado, porque ele afere
`chips <= chipsvao` e o vão inflado satisfaz a conta. O gate nunca abre um álbum. É o mesmo
gênero de cegueira que originou este lote.

**Decisão.** Empilhei título e ficha em duas linhas — que é como o desenho aprovado sempre
mostrou (`design/Main.dc.html:79-82`: "Island Songs" em cima, "Ólafur Arnalds · 8 faixas ·
35 min" embaixo). O título ganhou `elide` e `fillWidth`; o artista, teto de 40% e `elide`.
Medido depois: `chipsvao` volta a 604 com álbum aberto, e a 720 px (janela mínima) o título
elide e o botão continua inteiro. A referência mandava nesta ordem — desenho primeiro — e aqui
o desenho e o defeito apontavam para o mesmo conserto.

**Alternativa descartada.** Manter a linha única e só pôr `elide` no título. Continuaria
estourando na soma artista + contagem + botão, e brigaria com o desenho para salvar uma linha
de código.

**Custo de estar errada.** O cabeçalho da biblioteca ficou uma linha mais alto que o do painel
de coleções, que continua em linha única. Se isso incomodar, é o mesmo bloco de seis linhas
aplicado lá.

## 27. Duas bandeiras de medição novas, porque sem elas as duas metades desta fatia não têm foto

**Contexto.** O cabeçalho com o artista e o botão "+ Coleção" só existe com um ÁLBUM aberto, e
o app não tinha como abrir um em tela virtual. O resultado de busca do tipo coleção podia ser
fotografado na lista, mas fotografar o resultado prova que a busca ACHA — não que ele LEVA a
algum lugar, que é a metade que este lote existe para consertar.

**Decisão.** `--open-album <id>`, que percorre o caminho do clique (carrega o eixo de álbuns e
abre um grupo a partir dele, que é de onde o artista vem), e `--activate-hit`, que aperta Enter
no resultado em destaque. As duas só agem sob `--measure`, no mesmo feitio das sete que o
harness já tinha. A prova: `docs/telas/leva3-busca-abre-colecao.png` mostra o overlay fechado,
o ícone de coleções aceso na tira e a coleção "Pra codar" aberta com as 8 faixas dentro.

**Alternativa descartada.** Declarar a fatia pronta com a foto do resultado na lista de busca.
É a inferência "compila, logo funciona" que produziu as 24 lacunas.

**Custo de estar errada.** Duas funções de dez linhas num harness que já tinha sete iguais.

## 28. Detalhes em que o código do plano não batia com o arquivo real

**Contexto e decisão.** Três ajustes mecânicos, todos verificados contra o código:

- `addTracksToCollection` usa o auxiliar `uiDb()` do próprio arquivo, não a chamada crua a
  `QSqlDatabase::database(...)` que o plano escreveu — é o padrão das outras dez funções.
- `added_at` entra por `bindValue(QDateTime::currentSecsSinceEpoch())`, como em
  `addTrackToCollection`, e não pelo `CAST(strftime('%s','now') …)` do plano. Um `%s` dentro do
  SQL num arquivo que trata data em C++ seria a única exceção da casa.
- O despacho do tipo `collection` em `activate()` entrou como mais um `else if` da cadeia
  existente, em vez do bloco com `close()` e `return` do plano: a função já fecha o overlay no
  fim para todos os tipos casados.
- `onCollectionChosen` chama `root.showPane("collections")` em vez de escrever `root.section`
  direto. Mesmo efeito; `showPane` é a porta que a tira de ícones usa.

**Custo de estar errada.** Nenhum medido: build, suíte, gates e as quatro fotos.

## 29. Um teste a mais para `allTrackIds`, que o plano não pedia

**Contexto.** A Task 4 fecha com `grep` e build, sem teste. O irmão dela, `allPaths`, tem
teste (`allPathsFeedsThePlaylistInOrder`).

**Decisão.** Escrevi `allTrackIdsFeedsCollectionsInTheSameOrder`, do mesmo tamanho e no mesmo
lugar. A ordem importa: é ela que decide a ordem em que o álbum entra na coleção.

**Custo de estar errada.** Seis linhas de teste a mais numa suíte que roda em 5 segundos.

## 30. Os dois liga/desliga não são `Switch`, e a primeira tentativa (Chip) sumiu na foto

**Contexto.** A Task 1 de `ajustes` usa `Switch` do QtQuick.Controls. O app não tem um único
`Switch` — o estilo padrão dos Controls não segue o tema do Noctalia, e a peça entraria com
cor e animação próprias no meio de uma interface monocromática.

**Primeira decisão, e por que ela falhou.** Troquei por `Chip`, que é o "ligado/desligado" que
o app já usa na linha de filtros. Fotografei: os dois controles **desapareceram**. O `Chip`
desenha o estado selecionado com `Theme.mSurfaceVariant`, que é exatamente a cor de fundo
desta gaveta; e a borda do não-selecionado é a mesma cor. Ficaram duas palavras soltas, sem
nada que dissesse "isto é clicável".

**Decisão final.** `MelodariumButton`, preenchido quando ligado e contornado quando desligado —
o outro par de liga/desliga que o app já tem, e o mesmo componente dos botões "Trocar" e
"Fechar" ao lado. Fotografado nos dois estados
(`docs/telas/leva3-ajustes.png` e `leva3-ajustes-ligado.png`): distinguem-se por FORMA, não só
por matiz, que é o defeito de contraste registrado na decisão nº 20.

**Alternativa descartada.** Manter o `Chip` e mudar a cor de fundo da gaveta. Mexeria no
contraste de um popup para acomodar um controle, em vez do contrário.

**Custo de estar errada.** Nenhum medido: as duas fotos mostram os dois estados legíveis.

## 31. `grep -c 'settingsRequested' src/Main.qml` dá 0, e está certo

**Contexto.** A verificação da Task 2 pede 1. O handler de um sinal `settingsRequested` chama-se
`onSettingsRequested` — com S maiúsculo. `grep` é sensível a caixa.

**Decisão.** Conferi por `grep -c 'onSettingsRequested' src/Main.qml` → 1, e provei a ligação
na tela: a engrenagem aparece no pé da tira e `--open-settings` abre a gaveta, fotografada.

**Custo de estar errada.** Nenhum: a foto mostra a gaveta aberta pelo caminho real.

## 32. O que fiz com os dez órfãos que sobraram — item a item

**Contexto.** A decisão nº 22 da leva 2 previu que o detector não fecharia em zero só com as
duas fatias que faltavam, e listou quatro sem dono. A Task 5 de `ajustes` é a dona desta
escolha, e me dá duas saídas por item: ou existe caminho na tela (exceção), ou não existe
(some do código). Depois das duas fatias sobraram dez. Decidi um a um, com evidência:

**Saem do código — tela morta que o redesenho substituiu:**

| item | prova |
|---|---|
| `src/LibraryEmptyState.qml` | é o antecessor do `EmptyPane`: mesmo texto ("Escolha a pasta onde sua música está"), mesmo botão, mesmo `FolderDialog`. Quem está no `StackLayout` é o `EmptyPane`. |
| `src/SearchField.qml` | a barra da biblioteca hoje é um `Rectangle` próprio que abre o overlay, e o overlay tem o seu próprio campo. Nenhum QML o instancia, nenhum teste o toca. |
| `LibraryBrowser::clauseForSearch` e `bindingsForSearch` | montavam a busca como FILTRO da lista; a busca do app é `searchGrouped`, que devolve cinco tipos agrupados. Sem chamador e sem teste — `toFtsPrefixQuery`, que os dois usavam, fica porque `searchGrouped` a usa. |

**Ficam, em RESERVA DECLARADA — motor pronto e testado, sem tela pedida por spec ou desenho:**

| item | por quê |
|---|---|
| `collectionsForTrack` | testado; marcaria no menu quais coleções já têm a faixa — não está em desenho nenhum |
| `continueListening` | testado; "continuar ouvindo" não aparece em `design/Podcast.dc.html` |
| `ingestDownloadedFile` | testado; pertence à fatia `download-youtube`, que está **travada** |
| `moveTrackInCollection` | o plano `colecoes-tags` decide por escrito: arrastar para reordenar "entra só se a ordem manual se mostrar usada de fato" |
| `setGaplessAggressive` | o gapless agressivo não está em desenho nenhum |
| `unsubscribe` | o par de `subscribe`; desinscrever não tem tela nem desenho |

**Como a reserva não vira esquecimento.** A objeção da decisão nº 23 era exata: pôr itens numa
lista de exceções é enterrar funcionalidade atrás de um verde, que é o defeito que este lote
existe para consertar. Por isso a reserva **não silencia**: é uma lista separada da de
"coberto por outro caminho", cada item traz o motivo no próprio script, e o detector
**imprime a reserva inteira a cada execução**, acima da linha de resultado. Quem rodar o
portão vê os seis, com nome, sempre. Um item dispensado que ninguém mais vê é exatamente um
item esquecido.

**Prova de que o detector continua com dentes.** Injetei um `.qml` que ninguém instancia e um
`Q_INVOKABLE` que ninguém chama: voltou a `2 item(ns)` e `rc=1`, nomeando os dois. Revertido,
`0` e `rc=0`.

**Alternativa descartada.** Inventar telas para os seis (um botão de desinscrever, uma faixa
"continuar ouvindo", arrastar para reordenar). Seriam seis funcionalidades novas fora das 24
lacunas auditadas e fora dos sete planos aprovados — deriva de escopo decidida por quem
implementa.

**Custo de estar errada.** Se algum dos seis devia mesmo ter tela, ele está nomeado na saída do
portão, com o motivo, e volta à discussão na primeira vez que alguém rodar o detector.

## 33. Dois ajustes mecânicos no diálogo, contra o arquivo real

- `contentItem: ColumnLayout { … }` em vez de `ColumnLayout { anchors.fill: parent }`: com
  âncoras, o conteúdo não dá altura ao `Popup`, e a gaveta abriria achatada. A foto é a prova
  de que a forma escolhida mede certo.
- `pastaDialog.selectedFolder` qualificado: com `pragma ComponentBehavior: Bound`, o
  `selectedFolder` solto do plano não resolve dentro do handler.
- Um espaçador na linha dos botões de varredura, para que "Reler a pasta" fique à direita
  quando o aviso de varredura está invisível — sem ele o botão flutuava no meio da linha.

# Decisões do run — lote colecao-playlist (toca · dados · cartão · ordem)

## 34. Os quatro planos não estavam neste worktree, e copiá-los foi a primeira decisão

O run manda executar `docs/plans/2026-08-29-colecao-{toca,dados,cartao,ordem}.md`. Nenhum dos
quatro existia nesta branch: os arquivos estavam **não commitados** no worktree principal
(`/home/pedro/dev/active/melodarium/docs/plans/`), que é justamente o worktree que o run
proíbe de tocar.

**O que fiz.** Li os quatro de lá (leitura, nunca escrita) e os copiei para cá **verbatim**,
num commit próprio (`docs(plans): the four approved slices…`) antes de qualquer código. Só
depois passei a marcar `- [x]` e `status:`.

**Alternativa descartada.** Reescrever os planos do zero a partir do enunciado do run. Seriam
planos meus com o nome dos dele: o lote deixaria de ser "executar o que foi aprovado" e
viraria "planejar e executar sozinho", que é exatamente o que o Fluxo Maré separa em dois
donos.

**Custo de estar errada.** Se a versão do worktree principal tiver mudado depois da cópia, o
que rodou aqui é a foto de 29/08 12:08. Os quatro arquivos estão commitados nesta branch, então
a diferença é um `diff` de dois caminhos, não uma arqueologia.

## 35. `album_id` é chave estrangeira, e a fixture do plano `colecao-dados` não criava o álbum

O plano manda inserir três faixas com `album_id` 4, 5 e 6 no `initTestCase`. Rodou e reprovou
com `FOREIGN KEY constraint failed` — `tracks.album_id` referencia `albums(id)`, e a tabela
`albums` está vazia no banco temporário do teste.

**O que fiz.** Três `INSERT INTO albums (id, title)` antes do laço das faixas, com comentário
dizendo por quê. O resto do plano ficou intacto, e o teste então falhou pelo motivo que o
plano previu (`totalMs` = 0 porque a chave não existia).

**Alternativa descartada.** Deixar `album_id` nulo nas três faixas. O teste do plano compara
`covers.at(0).albumId` com `4`; sem álbum, a asserção mais interessante da fatia (a capa sabe
de qual álbum é) viraria uma comparação de zero com zero.

**Custo de estar errada.** Nenhum fora do teste: são linhas de fixture num banco temporário.

## 36. O disco de tocar da LISTA fica visível em repouso, contra o que o plano escreveu

O plano `colecao-cartao` põe `visible: area.containsMouse` no disco de tocar da linha — ele só
existe sob o mouse. Duas referências acima do plano dizem o contrário, e concordam entre si:

- **O desenho** (`design/Colecoes.dc.html`): o idioma dele para controle de linha é
  `.x { opacity: 0.35 }` com `.lin:hover .x { opacity: 1 }` — presente em repouso, aceso no
  hover. Nunca ausente.
- **O padrão vigente do app** (`src/TrackRow.qml`, escrito por extenso no código): "Always
  visible when enabled — a control that only appears on hover is a control the user never
  finds."

**O que fiz.** `visible: linha.modelData.count > 0` com `opacity: 0.35 → 1.0` no hover e um
`Behavior`, exatamente como o botão de coletar do `TrackRow`. Efeito colateral bem-vindo: a
foto `11-colecao-cartao.png` passa a PROVAR o gesto em vez de escondê-lo.

**Alternativa descartada.** Seguir o plano ao pé da letra. Entregaria o botão principal da
fatia invisível na única evidência que o run produz, e contrariando uma regra que o próprio
repo já escreveu no código.

**Custo de estar errada.** Se o disco em repouso poluir a lista, é uma linha: voltar o
`visible` para `area.containsMouse`. A informação da linha (nome, contagem, tempo, mosaico)
não muda.

## 37. A área de arrasto do plano não ficava embaixo da alça que ele mesmo desenhou

O plano `colecao-ordem` põe a alça (`⠿`) como primeiro filho do `RowLayout` do `TrackRow`, e a
`MouseArea` de arrasto com `width: 20` ancorada à esquerda do delegate. Medindo o arquivo real:
o `Rectangle` do `TrackRow` tem `leftMargin` 4 e o `RowLayout` dentro dele tem `leftMargin` 13,
então a alça ocupa **17 a 29 px**. A área de 0 a 20 px cobre **3 px** dela — 17 px do gesto
caem em vão vazio, e 9 px da alça desenhada não arrastam.

**O que fiz.** `width: 34`, que cobre a alça inteira e para antes do número da faixa (que
começa em 42).

**Alternativa descartada.** Mover a alça para fora do `RowLayout`, ancorada no zero. Mexeria no
espaçamento de TODAS as linhas da biblioteca, que usam o mesmo `TrackRow` — uma fatia de
coleção mudando a lista principal.

**Custo de estar errada.** Se 34 for largo demais, os 5 px finais roubam clique de ativação
numa faixa da coleção. É um número num arquivo.

## 38. Uma bandeira de medição a mais, porque a alça sozinha não prova gravação

O plano prova a ordem por dois caminhos: o teste em C++ (`moveTrackInCollection` reescreve as
posições) e a foto (as alças aparecem). Nenhum dos dois executa o caminho do QML — sinal
`trackMoved` → handler no `Main.qml` → gravação → recarga da lista. Alça desenhada sobre um
caminho que nunca rodou é o defeito que este repo já registrou em
`docs/solutions/ui/2026-08-28-redesenho-deixa-funcionalidade-orfa.md`.

**O que fiz.** `--move-last-to-top` no `Main.qml`, mesmo padrão das bandeiras da decisão 27:
manda a última faixa da coleção aberta para o começo pelo MESMO sinal que a alça emite. Medido
com a coleção-fixture de 6 faixas: a ordem no banco passou de `1,2,3,4,5,6` para
`6,1,2,3,4,5`, e a foto da tela mostra "Back Home" na linha 1, renumerada — a recarga do banco
chega ao olho.

**Alternativa descartada.** Ficar só com o teste e a foto do plano. Entregaria a única fatia do
lote cujo caminho de escrita nunca foi executado uma vez.

**Custo de estar errada.** É uma bandeira de medição: não aparece em nenhum gesto do usuário e
custa duas linhas no `Loader` que só existe sob `--measure`.

## 39. `moveTrackInCollection` saiu da RESERVA DECLARADA do detector de órfãos

O `tools/check-orfaos.sh` listava `moveTrackInCollection` como reserva, com o motivo por
escrito: "o plano colecoes-tags decide: arrastar para reordenar entra só se a ordem manual se
mostrar usada de fato". Esta fatia é essa decisão, tomada — o método agora tem tela.

**O que fiz.** Tirei o item da lista e o comentário que o explicava. Provei que a remoção deu
dentes ao detector: quebrando a chamada no `Main.qml`, ele passou a imprimir
`NUNCA CHAMADO: moveTrackInCollection` e `1 item(ns)`; restaurada, volta a `0`.

**Alternativa descartada.** Deixar na lista. O gate do run já exige que o nome suma da saída, e
sumiria de qualquer jeito — mas o comentário continuaria dizendo que o gesto não existe, e doc
que mente é pior que doc que falta.

**Custo de estar errada.** Nenhum: se o gesto for removido um dia, o detector reprova em vez de
silenciar, que é o comportamento correto.

## 40. Detalhes em que o código do plano não batia com o arquivo real

- O comando de medição dos planos (`./build/melodarium --measure … | grep fila=`) **não imprime
  nada**: o `console.log` do Qt está mudo sem `QT_LOGGING_RULES="*.debug=true"` e
  `QT_FORCE_STDERR_LOGGING=1`, que é o que o `tools/check-layout.sh` já faz. Rodei todas as
  medições com as duas variáveis.
- `grep -c FAIL` do plano `colecao-dados` cobra `1` e dá `2`: o `ctest` imprime a linha `FAIL!`
  do caso e mais a linha `The following tests FAILED:`. A substância bateu — um teste falhando,
  na comparação de `totalMs`, e o teste da coleção vazia passando desde o início, como previsto.
- `trackModel.rowCount()` não é `Q_INVOKABLE` (a contagem sai da `Q_PROPERTY count`), e a chave
  do id em `trackAt` é `id`, não `trackId`. Ajustado na bandeira da decisão 38.

# Decisões do run — lote melodarium-anima (seis fatias de animação)

Sessão headless autônoma, branch `exec/melodarium-anima`, 2026-08-29. As fatias 3, 4, 5 e 6
nasceram `decisao-humana: sim`; o despacho revogou a espera e mandou decidir contra a
referência disponível, nesta ordem: o desenho, o padrão vigente do app, o plano.

## 1. O halo existia, respondia, e não pintava um pixel

**Contexto.** O plano manda pôr o halo no painel com `z: -1`, dizendo que assim ele fica
"atrás de todo o conteúdo e ainda por cima do degradê do painel". No Qt Quick isso é o
contrário: filho com z negativo é desenhado ATRÁS do conteúdo do próprio pai — e o pai aqui é
o painel, cujo degradê é opaco. Medido: com o halo ligado e desligado, a cor de sete pontos da
tela era **idêntica em todos os canais**.

**Decisão.** Tirei o `z` e deixei a ordem de declaração fazer o trabalho: o halo é declarado
antes da coluna, portanto desenhado antes dela — atrás da capa, na frente do degradê. Medido
depois: a 16 px da capa a cor sai de (20,20,20) para (30,41,51) com a capa azul do Discovery.

**Alternativa descartada.** Manter `z: -1` e acreditar no texto do plano. O gate de fidelidade
não pegaria isso nunca — ele fotografa com o halo desligado de propósito.

**Custo de estar errada.** Nenhum: a prova é numérica e está no transcript.

## 2. A luz é cortada na borda do painel, e isso ficou

**Contexto.** A capa ocupa 340 px dos 392 da coluna: sobram 26 px de cada lado. Qualquer luz
em volta dela chega à borda ainda forte, e ali ela é cortada — uma transição dura entre a
coluna iluminada e o rail escuro.

**Decisão.** O corte fica. Rodei a versão SEM corte e fotografei: a luz atravessa o rail e a
lista, e as molduras que a compõem passam a se ver **como molduras** — um retângulo arredondado
gigante desenhado por cima da tela inteira. Muito pior que a fronteira. O painel já é uma
superfície própria, com degradê próprio; a luz terminar na borda dele lê como janela iluminada,
não como defeito.

**Alternativa descartada.** Desvanecer a luz nas laterais com uma cortina de degradê. O fundo
do painel muda de cor de cima para baixo, então a cortina precisaria de degradê nas duas
direções ao mesmo tempo — o que no QML só sai de shader, e shader é justamente o que some no
adaptador de software (lição de 2026-08-28).

**Custo de estar errada.** Se o Pedro achar a faixa lateral incômoda, o conserto é uma linha:
`alcance` menor em `src/AmbientGlow.qml` aproxima a luz da arte, e `opacity` menor por camada a
enfraquece por igual.

## 3. A intensidade do halo ficou nos números do plano

**Contexto.** 14 camadas a 3% de opacidade cada, alcance de 35% do lado da capa. O desenho
(`design/Main.dc.html`) não tem halo nenhum: ele põe uma sombra PRETA sob a capa. Ou seja, a
referência de primeira ordem não opina — ela só diz que o painel é escuro e sóbrio, e que a
arte se destaca por sombra.

**Decisão.** Fiquei nos números do plano, que são conservadores. Na foto, a luz azul da capa do
Discovery levanta o fundo do painel em cerca de 30 níveis no canal azul junto da arte e some
completamente antes do meio da coluna. A capa continua sendo o assunto.

**Alternativa descartada.** Subir a intensidade para o halo "aparecer de verdade" numa captura.
Halo que aparece na foto compete com a arte na tela.

**Custo de estar errada.** Baixo e reversível: os dois números vivem juntos no topo de
`src/AmbientGlow.qml`.

## 4. Uma chave nova só para fotografar o halo aceso

**Contexto.** O halo desliga sob `--measure` de propósito (a cor dele vem do acervo de quem
roda, e o gate mede pontos fixos). Só que tocar uma faixa por linha de comando **também** só
acontece sob `--measure`. Resultado: não havia como o app produzir a imagem que prova que o
halo existe — que é justamente o que o portão deste run cobra.

**Decisão.** Criei `--com-halo`: sob medição, mantém o halo aceso. A foto que MEDE continua sem
halo; a foto que MOSTRA passa a ter. Três linhas na janela.

**Alternativa descartada.** Fazer o `--play-track` funcionar fora do modo de medição. Mexeria
no caminho de partida do app inteiro para servir a uma foto.

**Custo de estar errada.** Nenhum no uso normal: sem a chave, nada muda.

## 5. O campo `halo=on/off` foi para a linha de medição, não para uma `diag`

**Contexto.** O plano manda acrescentar o campo a uma propriedade `diag` do painel. Não existe
`diag` em lugar nenhum do app — nem no painel, nem em outro arquivo.

**Decisão.** O campo entrou na linha `MEDIDA`, que é a porta de saída mecânica que existe de
fato e já lê o painel. A verificação do plano passa igual.

**Custo de estar errada.** Nenhum: é saída de diagnóstico.
