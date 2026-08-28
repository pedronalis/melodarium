# Melodarium — o que está faltando para o app parar de parecer pela metade

## 1. O que aconteceu

As catorze fatias foram entregues de verdade, uma a uma, e cada uma funcionou no dia em que foi feita. O que quebrou o conjunto foi o redesenho da janela no fim do caminho: a barra lateral larga — que era o menu do app, com Coleções, Artistas, Álbuns, Gêneros, Tags e Todas as faixas — foi trocada por uma coluna estreita de cinco ícones, e a barra de controles do rodapé foi trocada pelo painel do disco à esquerda. Nessa mudança, as telas antigas não foram apagadas: elas continuam no projeto, continuam sendo compiladas junto com o resto, só que ninguém mais as abre. E como elas compilam, nenhuma verificação automática reclamou — para os testes, o app seguiu verde com tudo marcado como concluído, enquanto na tela um terço das funções tinha perdido a porta de entrada. Somou-se a isso um segundo hábito das últimas fatias: desenhar o botão agora e ligar a função "numa fatia futura", que nunca foi agendada. O resultado é o que você viu — a moldura nova inteira, com metade dos fios cortados por baixo.

---

## 2. O que está faltando

Legenda: **[quebrado]** existe na tela e não funciona · **[desligado]** foi construído e saiu da tela · **[nunca feito]** nunca foi escrito.

### Bloco A — O redesenho cortou os fios da barra lateral
É a maior história do relatório: sete coisas que você não consegue fazer hoje, todas pela mesma causa.

- **[quebrado] Clicar em Álbuns ou em Tags na barra de ícones não muda nada.** O ícone acende como se você tivesse navegado, e a lista continua idêntica. É a sua queixa nº 1, literal.
- **[quebrado] Clicar em Biblioteca também não faz nada quando você já está na biblioteca.** Não limpa o filtro, não sai da grade de álbuns. Ele só tem uma utilidade real: voltar da tela de podcast.
- **[quebrado] A barra de ícones e os botõezinhos acima da lista discordam entre si.** Eles têm as mesmas palavras (Álbuns, Tags), mas os de cima funcionam e os da lateral não — e clicar num não acende o outro. Dá a impressão de dois menus, um obediente e um quebrado.
- **[desligado] Coleções: dá para criar e para jogar faixa dentro, e não dá para abrir.** Você cria "Pra codar", coloca cinco músicas, e não existe botão, aba, menu ou busca que mostre o que tem lá dentro. É o que a especificação chama de diferencial do produto, e hoje ele é um poço: entra e não sai. A tela que listava as coleções existe pronta, só ficou sem casa.
- **[desligado] Não há onde colar um link do YouTube.** O baixador inteiro está construído e testado: sonda o programa, busca título e duração, mostra progresso, cancela, cataloga o arquivo com capa e um selo "YouTube" na lista. A caixa de colar o link também existe. Ela só abria de dentro do painel de coleções, e caiu junto com ele. O app ainda gasta um processo toda vez que abre para checar se o programa de download está instalado — informação que hoje não serve para nada.
- **[desligado] Não existe controle de volume nem mudo dentro do app.** O botão existia na barra antiga; a barra saiu e ele não migrou. Você é obrigado a usar o volume do sistema. (Detalhe honesto: o motor tem volume, mas mudo nunca existiu de verdade — o botão antigo só alternava entre zero e cheio.)
- **[quebrado] Clicar numa etiqueta embaixo da capa não leva a lugar nenhum.** A etiqueta vira mãozinha, você clica esperando ver tudo que é "piano", e nada acontece. O "x" de remover a etiqueta ao lado funciona, o que deixa o clique morto ainda mais estranho. Filtrar por etiqueta ainda é possível pelo caminho longo (botão Tags acima da lista); o atalho é que morreu.

### Bloco B — O curtir funciona pela metade
Duas falhas somadas, e é a sua queixa nº 3.

- **[quebrado] O coração da lista não reage ao clique.** O like é gravado de verdade, e o contador de curtidas ali do lado até pula na hora — mas a linha em si fica congelada. Só depois de trocar de filtro ou reler a pasta é que o coração aparece marcado. Nem rolar a lista para longe e voltar resolve.
- **[nunca feito] O coração cheio não existe no app.** Mesmo onde o like atualiza na hora (o coração grande, ao lado da faixa tocando), ele nunca "enche": só troca de cor. No desenho que você aprovou, curtido é um coração sólido e não curtido é um contorno vazado — duas formas distintas. Boa notícia: o desenho sólido já vem dentro da fonte de ícones que o app carrega, só nunca foi listado como disponível. É conserto de poucas linhas, sem arte nova.

### Bloco C — Botões que estão na tela e não fazem absolutamente nada
Foram desenhados primeiro, com a função marcada para depois. "Depois" nunca virou fatia.

- **[quebrado] Aleatório.** Está ao lado do play, acende no hover, tem cursor de mãozinha, e o clique não faz nada. Pior: existe um "tocar tudo em ordem aleatória" que funciona de verdade, mas ele só aparece na tela de boas-vindas, quando nada está tocando — ou seja, no instante em que a música começa, o único aleatório do app some da tela e é substituído pelo botão oco. E ele embaralha a biblioteca inteira uma vez na partida, sem como desligar.
- **[quebrado] Repetir.** Não existe em forma nenhuma, em momento nenhum: nem botão que funcione, nem menu, nem atalho. Só o desenho.
- Nenhum dos dois tem estado "ligado": mesmo que funcionassem, hoje não haveria como saber se estão ativos.

### Bloco D — Peças do desenho aprovado que nunca viraram trabalho

- **[nunca feito] A fila com as capinhas dos discos.** No desenho, o pé da lista tem o título "A seguir na fila", quatro capas pequenas dos próximos discos e um quadradinho "+2" dizendo quantas faltam. Nada disso existe. A ordem de reprodução até é guardada por dentro, mas nunca é mostrada. É a sua queixa nº 2, literal. Existiu uma lista de fila antiga, mas era uma lista de nomes de arquivo, não a tirinha de capas — e ela também está desligada.
- **[nunca feito] Pôr na fila pela busca e o contador de fila.** Os desenhos prometem um atalho de teclado para enfileirar um resultado da busca e um "fila 6" na barra de controles. Nenhum dos dois existe.
- **[nunca feito] O botão "+ Coleção" no cabeçalho da lista.** Para pôr um álbum de doze faixas numa coleção, hoje você abre o menu doze vezes, uma por linha. O botão que fazia isso de uma vez está no desenho aprovado e nunca foi escrito. Vale registrar um conflito: a especificação diz que o gesto manual é um só (jogar UMA faixa numa coleção) e os planos seguiram isso ao pé da letra; o desenho tem o botão. Essa é uma decisão sua, não um bug.
- **[nunca feito] O nome do artista no cabeçalho do álbum.** O desenho mostra "Ólafur Arnalds · 8 faixas · 35 min"; a tela mostra só a contagem e a duração. É a mesma linha do botão acima — conserto conjunto.

### Bloco E — Qualidade de áudio sem nenhum lugar para ajustar
Este bloco tem uma ressalva importante antes da lista.

- **[desligado] O nivelamento automático de volume está desligado por padrão e trancado.** O app lê essa informação de dentro dos arquivos e guarda no banco, e nunca a usa para tocar. O comando que ligaria existe e ninguém o chama.
- **[desligado] O modo de saída exclusiva (impedir o sistema de mexer no sinal) também existe pronto e é inalcançável.** Esse é promessa direta da especificação, na parte que você marcou como requisito duro.
- **[nunca feito] Não existe nenhuma tela de ajustes no app.** É a causa dos dois itens acima, e tem um efeito colateral que você provavelmente já sentiu: a única forma de escolher a pasta da biblioteca é a tela de boas-vindas, que some assim que existe biblioteca. Depois disso, não há por onde trocar de pasta.

**Ressalva honesta, medida na sua biblioteca:** das 27 faixas que você tem hoje, nenhuma traz a informação de nivelamento gravada dentro. Ligar essa opção agora não mudaria um decibel para você. A queixa que se confirma aqui é "não tem onde configurar nada", não "as músicas estão desniveladas". Isso rebaixa muito a urgência deste bloco.

---

## 3. As suas quatro queixas, uma a uma

**(a) "Clico em biblioteca, ou nas tags, ou na lista, e a mesma coisa."**
Você está certo, e é literal. Três dos cinco ícones da barra lateral não navegam: Álbuns e Tags não trocam a tela nunca, e Biblioteca só serve para voltar do podcast. Eles acendem ao serem clicados, o que é a pior combinação possível — o app diz que navegou e não navegou. A capacidade de ver por álbum e por etiqueta existe e funciona, só que pelos botõezinhos acima da lista, não pela barra. Aconteceu porque o redesenho criou a barra nova com os cinco nomes e nunca escreveu para onde cada um leva; o plano da fatia já tinha esse buraco escrito nele, e a verificação da época era só "compila e abre sem erro". **Está na lista, Bloco A.** Conserto curto.

**(b) "Tinha um lance que ia ter uma fila ali embaixo com a capinha dos discos."**
Você lembrou certo: está no desenho que você aprovou, no pé da coluna do meio — o título "A seguir na fila", quatro capas pequenas e um "+2". Nunca foi construído. Não foi esquecimento silencioso: durante a execução ficou registrado nos planos que "a fila saiu desta direção" e que trazê-la de volta seria uma fatia nova. Essa decisão nunca subiu até você. Hoje não existe nada no app que mostre o que vem depois, e não há como reordenar. A lista do meio serve de fila enquanto você não navega para outro álbum — e mente quando o modo aleatório está ativo, porque a ordem real embaralhada não aparece em lugar nenhum. **Está na lista, Bloco D.**

**(c) "Quando eu clico para curtir, o coração não fica preenchido."**
São duas coisas ao mesmo tempo, e você acertou as duas. Na lista, o coração não muda nada ao clique — nem enche, nem troca de cor; o like foi gravado, mas a tela não responde até você trocar de filtro. E no painel do disco, onde ele até responde na hora, ele nunca enche: só muda de cor, porque o desenho sólido nunca foi disponibilizado ao app (embora esteja dentro da fonte de ícones que ele já carrega). O desenho aprovado usa duas formas diferentes; o plano da fatia mandou usar só cor e opacidade, e essa divergência passou batido. **Está na lista, Bloco B.** É o conserto mais barato de todos e o mais visível.

**(d) "Tem um monte de coisa que está faltando."**
Confirmado, e dá para nomear. Além das três acima: não há como abrir uma coleção que você criou (o diferencial do produto está gravado no banco e invisível na tela); não há onde colar um link do YouTube, apesar de o baixador inteiro estar pronto e testado; não há controle de volume dentro do app; os botões de aleatório e repetir são enfeites; clicar numa etiqueta embaixo da capa não faz nada; não há como jogar um álbum inteiro numa coleção de uma vez; e não existe tela de ajustes nenhuma — inclusive para trocar a pasta da biblioteca depois da primeira escolha. **Tudo isso está nos blocos acima.**

---

## 4. Por onde começar

### Onda 1 — "todo clique responde" · uma tarde
1. O coração enche e reage na hora, na lista e no painel.
2. Os ícones Álbuns e Tags passam a trocar a tela de verdade, e o destaque deles fica em acordo com os botõezinhos acima da lista.
3. Clicar numa etiqueta embaixo da capa filtra a biblioteca por ela.
4. O volume volta para a fileira de controles.

**É esta onda, sozinha, que faz o app deixar de parecer quebrado.** Ela resolve duas das suas quatro queixas por inteiro, e acaba com a sensação de "eu clico e o app ignora" — que é o que mais estraga a impressão. Nada aqui é reescrita: é religar fio e expor um ícone que já está embarcado.

### Onda 2 — "as coleções voltam a existir" · um dia
Devolver um lugar para listar e abrir coleções. Como o dado já sai no formato que a grade de álbuns consome, a navegação básica é curta; o custo está em decidir ONDE ela mora (a barra tem cinco lugares ocupados e a fileira de botões já está no limite de largura) — isso é decisão sua, de desenho. Com as coleções de volta, colar link do YouTube volta quase de graça, porque a caixa dele mora dentro de uma coleção aberta. Se quiser encurtar, dá para deixar o download cair solto na biblioteca e adiar a escolha da coleção.

Depois desta onda, as duas funções que você pediu explicitamente (coleções e download por link) saem do limbo.

### Onda 3 — "a fila aparece" · um a dois dias
A tirinha de capas no pé da lista, com o "+N". Todas as peças existem (as capas já funcionam a partir do caminho do arquivo, e a posição atual da fila já é conhecida); falta escrever o componente e decidir o lugar dele. Resolve sua queixa nº 2. É a onda com o maior efeito visual por hora gasta depois da primeira.

### Onda 4 — "os botões param de mentir" · uma tarde a um dia
Aleatório e repetir. Duas saídas possíveis, e a escolha é sua:
- **barata (uma hora):** tirar os dois botões da tela até existir função. Um botão ausente é melhor que um botão que mente.
- **completa (um dia):** ligar de verdade, com estado ligado/desligado visível, repetir em três posições (nada / tudo / uma faixa) e o aleatório agindo sobre a fila corrente, não sobre a biblioteca inteira.

### Onda 5 — "uma tela de ajustes" · um a dois dias
Nivelamento de volume, saída exclusiva e — o que mais importa no dia a dia — trocar a pasta da biblioteca depois da primeira vez. Deixei por último de propósito: hoje nenhuma das suas 27 faixas tem informação de nivelamento gravada, então as duas primeiras opções não mudariam nada no som. O que dói de verdade aqui é não ter onde trocar de pasta.

### Fora de onda, para decidir depois
O botão "+ Coleção" no cabeçalho (jogar um álbum inteiro numa coleção de uma vez) e o nome do artista no cabeçalho — mesma linha da tela, conserto conjunto de poucas horas. Precisa da sua palavra antes: a especificação diz que o gesto manual é um só, faixa a faixa; o desenho tem o botão. Os dois não podem estar certos.

---

## 5. Apêndice técnico

Confiança "alta" em todos os itens: cada um foi confirmado linha a linha e submetido a busca ativa por caminho alternativo (atalho, menu, componente carregado dinamicamente, argumento de linha de comando) que pudesse refutá-lo.

| # | Achado | Local | Símbolos / evidência | Tipo | Custo |
|---|--------|-------|----------------------|------|-------|
| 1 | Coração da lista não reage ao clique | `src/tracklistmodel.cpp` (nenhum `connect` no arquivo; único `dataChanged` na :104, só `{IsCurrentRole}`), `src/tracklistmodel.h:58` (`LikedRole`), `src/librarybrowser.h:57` (`likedChanged`), `src/LibraryPane.qml:34-36,55-58` | `reload()` só atualiza `chips.likedCount`; `m_rows[i].liked` fica velho em memória. Conserto: `Q_INVOKABLE applyLiked(int,bool)` + `dataChanged({LikedRole})`, chamado do `onLikedChanged` já existente | quebrado | minutos |
| 2 | Coração cheio não existe | `src/Icons.qml:31` (só `"heart"` vazado), `src/TrackRow.qml:168-173`, `src/NowPlayingPanel.qml:259-263`, `src/IconButton.qml:29-35` (`accent` só troca cor), desenho: `design/Main.dc.html:47,94,112,130` | O glifo `heart-filled` (U+F67C) já está em `assets/fonts/noctalia-tabler-icons.ttf`; falta a entrada no mapa. Origem da divergência: `docs/plans/2026-08-27-biblioteca-densa.md:66-73` mandou usar `accent`+`opacity`, e a seção "Divergências" (:454-480) omite este ponto | nunca feito | minutos |
| 3 | Ícones Álbuns/Tags/Biblioteca não navegam | `src/Main.qml:261-267` (`showPane` só faz `root.section = name`), `src/Main.qml:477-482` (`currentIndex` só distingue `"podcast"`), `src/IconRail.qml:22-28,83`, `src/Main.qml:451-452` | `root.section` é lido só em 2 lugares (destaque + `currentIndex`); `LibraryPane` depende de `libraryFilter`/`groups`/`showingGroups`, nenhum derivado de `section`. Caminho vivo paralelo: `src/FilterChips.qml:26-31` → `chooseFilter` → `showSection` (:146-159). Origem: `docs/plans/2026-08-27-moldura-capa.md:500-506` já entregava `showPane` incompleto | quebrado | minutos |
| 4 | Destaques da barra e dos chips dessincronizados | `root.section` (`src/Main.qml:85,191,266,321,451,480`) vs `root.libraryFilter` (`src/Main.qml:172-175`) | Conserto correto escreve os dois estados em `showPane` e `chooseFilter` | quebrado | minutos |
| 5 | Coleções sem porta de entrada | `src/CollectionsSection.qml` (instanciado só em `src/Sidebar.qml:31`; `Sidebar` não é instanciado por nenhum QML — só `CMakeLists.txt:74,78`), `src/Main.qml:135-136` (`case "collection"` inalcançável), `src/Main.qml:149-150` (`isGroupAxis` sem coleções), `src/IconRail.qml:22-28`, `src/FilterChips.qml:25-46` | Vivo: `collectMenu` (`src/Main.qml:535-560`), `NewCollectionDialog` (:562-572), `CollectionManager::addTrackToCollection`. Morto: `clauseForCollection`/`bindingsForCollection`. Busca não indexa coleção (`src/librarybrowser.cpp:315,335,356,376`). `collections()` já devolve `{id,name,count}` (`src/collectionmanager.cpp:35-52`), formato que a grade de grupos consome. Plano `docs/plans/2026-08-27-colecoes-tags.md` está `status: concluido`, `decisao-humana: sim`. Regressão do commit `ec45204` | desligado | horas |
| 6 | Colar link do YouTube inalcançável | `src/AddFromLinkDialog.qml:236,243` (únicos chamadores de `fetchInfo`/`download`), instanciado só em `src/CollectionsSection.qml:144`; botão em `:72-79` com `visible: currentCollectionId > 0`; `src/DownloadProgressRow.qml` idem (`:90`) | Motor vivo e testado (`src/ytdlpdownloader.cpp:194-208`, selo em `:208`, `tests/tst_ytdlp.cpp`). `src/Main.qml:441` (`probe()` a cada abertura) e `:368-372` (`onFinished`) seguem armados. Sem `DropArea`, sem `clipboard`, sem `QCommandLineParser` (`src/main.cpp:22` só `--scan`). Plano `docs/plans/2026-08-27-download-youtube.md` `status: concluido` | desligado | horas |
| 7 | Sem controle de volume/mudo | `src/NowPlayingPanel.qml:316-404` (fileira sem volume), `src/Icons.qml:23-25` (3 glifos sem uso), `src/audioengine.cpp:162-169` (`setVolume`, clamp 0..100) | Não existe mute no motor — o botão antigo alternava 0↔100. Nasceu em `e6332f3`, apagado em `738acd3`; trecho preservado em `docs/plans/2026-08-27-tocador-ui.md:876-882`. A perda foi desenhada: `docs/plans/2026-08-27-moldura-capa.md:419,444` já não lista volume | desligado | minutos |
| 8 | Etiqueta sob a capa não filtra | `src/TagEditor.qml:14,43` (`tagChosen`), `src/NowPlayingPanel.qml:408-413` (instancia sem `onTagChosen`; painel só declara `likeRequested`/`playRequested` em :15-16), `src/Main.qml:274-279` (`showTag` vivo, único consumidor é `onTagOpened` em :494) | Regressão comprovada por `git log -S onTagChosen`: existia em `0716b7f`, cortado em `202b7bb`. Conserto precisa de sinal próprio no painel + `showTag` ajustando `section`/`libraryFilter` | quebrado | minutos |
| 9 | Aleatório e repetir inertes | `src/NowPlayingPanel.qml:327-332` e `:379-384` (`onClicked: {}`), dentro do RowLayout `visible: root.hasTrack` (:318) | `src/audioengine.h:39-56` e `.cpp` sem `shuffle`/`loop`/`repeat`; comandos mpv usados: `stop`, `seek`, `playlist-next/prev`, `loadfile`. Único aleatório: `src/EmptyPane.qml:285-287` → Fisher-Yates em `src/Main.qml:236-247`, com `visible: !root.hasTrack` (`NowPlayingPanel.qml:206`) — mutuamente exclusivo com os botões. Estado "ligado" é barato (`src/IconButton.qml:9,35`, `accent`). Dívida assumida em `docs/plans/2026-08-27-moldura-capa.md:613-615` e `navegacao-biblioteca.md:997` | quebrado | horas |
| 10 | Fila "A seguir na fila" com capinhas | `design/Main.dc.html:141-152` (rótulo + 4 capas 62px + "+2", na coluna do MEIO, não no painel do disco), `src/Main.qml:112,202,247` (`queuePaths` write-only), `src/QueuePanel.qml` órfão (só `CMakeLists.txt:77`) | Peças prontas: `CoverCache::coverUrlForTrack(path, albumId)` com `Q_UNUSED(albumId)` (`src/covercache.cpp:40`), `AudioEngine.playlistPos` (`src/audioengine.h:22`). Também ausentes: coluna "Fila" (`design/HierarquiaContraste.dc.html:197-212`), contador "fila 6" (`design/DensaTabular.dc.html:259`), `⇧↵ pôr na fila` (`design/Busca.dc.html:330` vs `src/SearchOverlay.qml:193-194`). Adiamento registrado em `biblioteca-densa.md:402-403` e `podcast-vazio.md:609-610` | nunca feito | horas |
| 11 | Botão "+ Coleção" no cabeçalho | `design/Main.dc.html:78-88`, `src/LibraryPane.qml:66-113` (cabeçalho completo, 4 filhos, sem o botão) | Não existe API em lote: `src/collectionmanager.h:26` só tem `addTrackToCollection(int,int)`. Nenhum `DropArea`/seleção múltipla. Conflito spec×desenho: `docs/specs/2026-08-27-player-musica-podcast.md:81` × `design/Main.dc.html:84-87` — precisa de decisão humana | nunca feito | horas |
| 12 | Artista ausente no cabeçalho do álbum | `design/Main.dc.html:82` × `src/LibraryPane.qml:78-88` | Mesma linha de layout do item 11 | nunca feito | minutos |
| 13 | ReplayGain / saída exclusiva / sem tela de ajustes | `src/audioengine.cpp:46-48` (`replaygain=no`, `replaygain-clip=no`, `gapless-audio=weak` fixos antes do `mpv_initialize` :52), `:188` `setReplayGainMode`, `:196` `setExclusiveOutput` — zero chamadores em todo o repo | Dado é lido (`src/tagreader.cpp:139-148`) e gravado (`src/libraryscanner.cpp:107-108`, colunas em `src/database.cpp:60-61`) e nunca relido — colunas write-only. Nenhuma tela de ajustes; `QSettings` só guarda `library/path` e `podcast/path`. **Medição na base real** (`~/.local/share/melodarium/melodarium/melodarium.db`): 27 faixas, 0 com `replaygain_track_gain` → ligar não mudaria nada hoje. `gapless-audio=weak` é decisão deliberada e correta (`docs/plans/2026-08-27-motor-audio.md:226-230`), não tratar como defeito. Buraco entre fatias: `motor-audio.md:693` empurra para `navegacao-biblioteca`, que o joga no Fora de escopo (`:999`) | desligado | horas |
| 14 | Trocar a pasta da biblioteca depois da 1ª vez | `src/EmptyPane.qml:327` (`FolderDialog`), `src/Main.qml:482` (a tela vazia some quando `libraryPath != ""`) | Consequência direta do item 13 | nunca feito | horas |

**Falsos positivos já descartados na investigação:** `Icons.qml` aparenta ser órfão e não é (singleton usado como `Icons.get(...)`); os planos `docs/plans/*.md` estão todos `status: concluido`, o que não reflete a tela — o ledger precisa ser reaberto nas fatias `colecoes-tags`, `download-youtube` e `moldura-capa`.

**Não verificado por teto de custo (16 itens, majoritariamente menores):** nivelamento de volume entre faixas; "Continuar ouvindo" do podcast sumido da tela e a tirinha correspondente nunca escrita; cancelar assinatura de podcast e ver quando o feed foi checado; ícones da barra sem rótulo ao passar o mouse (e nenhum botão só-de-ícone com dica); atalho "pôr na fila" ausente no rodapé da busca; qualidade do arquivo tocando não exibida (e exibida pela metade em outro lugar); busca limitada a 4 resultados por tipo; varredura da pasta sem progresso, sem cancelar e falhando em silêncio; listas automáticas que não se atualizam depois de ouvir; capa genérica nas linhas de busca e podcast; número do episódio ausente no painel.