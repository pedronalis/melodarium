pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Melodarium.App

Window {
    id: root
    // `--measure [largura]`: medir também na janela mínima é o único jeito de saber se a
    // linha de filtros aguenta a tela estreita.
    readonly property bool measuring: Qt.application.arguments.indexOf("--measure") >= 0

    // `--sem-animacao`: desliga toda transição sem precisar de tela de ajustes. `--measure`
    // liga junto de qualquer jeito — a foto do gate é tirada num instante fixo e pegaria a
    // animação pela metade, reprovando por movimento em vez de por cor errada.
    readonly property bool semAnimacao:
        root.measuring || Qt.application.arguments.indexOf("--sem-animacao") >= 0

    // `--com-halo`: fotografar o halo aceso. O gate de fidelidade mede 15 pontos fixos e o
    // halo tem a cor do acervo de quem roda, por isso `--measure` o desliga — mas então NADA
    // no app consegue produzir a imagem que prova que ele existe, porque tocar uma faixa por
    // linha de comando também só acontece sob `--measure`. Esta chave separa as duas coisas:
    // a foto que MEDE continua sem halo, a foto que MOSTRA passa a ter.
    readonly property bool comHalo: Qt.application.arguments.indexOf("--com-halo") >= 0

    // `--shot <arquivo.png>`: salva a tela montada, para comparar com o desenho aprovado sem
    // depender de alguém descrever o que está vendo.
    readonly property string shotPath: {
        const i = Qt.application.arguments.indexOf("--shot")
        return i >= 0 && Qt.application.arguments.length > i + 1
               ? Qt.application.arguments[i + 1] : ""
    }

    // `--pane <library|podcast|empty|collections>`: qual miolo montar ao medir ou fotografar.
    readonly property string measurePane: {
        const i = Qt.application.arguments.indexOf("--pane")
        return i >= 0 && Qt.application.arguments.length > i + 1
               ? Qt.application.arguments[i + 1] : "library"
    }

    // `--search-text <texto>`: digita no overlay antes de fotografar, para a foto mostrar
    // resultados de verdade em vez de um campo vazio.
    readonly property string measureSearchText: {
        const i = Qt.application.arguments.indexOf("--search-text")
        return i >= 0 && Qt.application.arguments.length > i + 1
               ? Qt.application.arguments[i + 1] : ""
    }

    // `--play-episode <id>`: põe um episódio para tocar antes de fotografar, que é o único
    // jeito de ver o transporte de fala montado.
    readonly property int measureEpisode: {
        const i = Qt.application.arguments.indexOf("--play-episode")
        if (i < 0 || Qt.application.arguments.length <= i + 1)
            return 0
        const id = parseInt(Qt.application.arguments[i + 1])
        return isNaN(id) ? 0 : id
    }

    // `--delay <ms>`: quanto esperar antes de medir. Abrir um arquivo no mpv leva mais do que
    // montar a tela.
    readonly property int measureDelay: {
        const i = Qt.application.arguments.indexOf("--delay")
        if (i < 0 || Qt.application.arguments.length <= i + 1)
            return 1200
        const ms = parseInt(Qt.application.arguments[i + 1])
        return isNaN(ms) ? 1200 : ms
    }

    // `--play-track <caminho>`: mesma ideia do --play-episode, para a tela com música.
    readonly property string measureTrack: {
        const i = Qt.application.arguments.indexOf("--play-track")
        return i >= 0 && Qt.application.arguments.length > i + 1
               ? Qt.application.arguments[i + 1] : ""
    }

    // `--open-collection <id>`: abre uma coleção antes de fotografar. Sem isto o painel de
    // coleções só pode ser fotografado no estado "nenhuma aberta", e a metade da fatia que
    // importa — a coleção ABERTA, com as faixas dentro — não teria como ser provada.
    readonly property int measureCollection: {
        const i = Qt.application.arguments.indexOf("--open-collection")
        if (i < 0 || Qt.application.arguments.length <= i + 1)
            return 0
        const id = parseInt(Qt.application.arguments[i + 1])
        return isNaN(id) ? 0 : id
    }

    // `--open-album <id>`: entra no eixo de álbuns e abre um deles, pelo mesmo caminho do
    // clique. O cabeçalho com o artista e o botão "+ Coleção" só existem com um álbum
    // aberto: sem isto essa metade da tela não teria como ser fotografada.
    readonly property int measureAlbum: {
        const i = Qt.application.arguments.indexOf("--open-album")
        if (i < 0 || Qt.application.arguments.length <= i + 1)
            return 0
        const id = parseInt(Qt.application.arguments[i + 1])
        return isNaN(id) ? 0 : id
    }

    // `--play-queue`: carrega a biblioteca inteira como fila e toca a primeira. A tirinha
    // "a seguir na fila" só existe quando há PRÓXIMOS, e `--play-track` monta uma fila de
    // um só — com ela a tirinha ficaria corretamente invisível e não haveria o que provar.
    readonly property bool measureQueue: Qt.application.arguments.indexOf("--play-queue") >= 0

    // `--play-queue-mode <all|shuffle|never|forgotten>`: qual dos convites da tela vazia
    // disparar. Com "shuffle" o modo aleatório fica LIGADO, que é o único jeito de
    // fotografar o botão aceso — apagado ele não prova o estado visível que a fatia promete.
    readonly property string measureQueueMode: {
        const i = Qt.application.arguments.indexOf("--play-queue-mode")
        return i >= 0 && Qt.application.arguments.length > i + 1
               ? Qt.application.arguments[i + 1] : "all"
    }

    // `--repeat <n>`: avança o repetir n posições (1 = a fila, 2 = esta faixa), para o "1"
    // sobreposto do terceiro estado poder ser visto na foto.
    readonly property int measureRepeat: {
        const i = Qt.application.arguments.indexOf("--repeat")
        if (i < 0 || Qt.application.arguments.length <= i + 1)
            return 0
        const n = parseInt(Qt.application.arguments[i + 1])
        return isNaN(n) ? 0 : n
    }

    // `--queue-hit`: manda o overlay pôr na fila o resultado em destaque e fecha, que é o
    // gesto do Shift+Enter. Sem isto o atalho só poderia ser provado por alguém apertando a
    // tecla — e um atalho que anuncia no rodapé e não faz nada é o defeito deste lote.
    readonly property bool measureQueueHit: Qt.application.arguments.indexOf("--queue-hit") >= 0

    // `--activate-hit`: aperta Enter no resultado em destaque. Fotografar o resultado na
    // lista prova que a busca ACHA; só ativá-lo prova que o resultado LEVA a algum lugar —
    // que é a metade que este lote existe para consertar.
    readonly property bool measureActivateHit: Qt.application.arguments.indexOf("--activate-hit") >= 0

    // `--open-settings`: abre a gaveta de ajustes antes de medir. Um Popup só é construído
    // na primeira abertura: sem alguém abri-lo, nenhuma verificação o alcança.
    readonly property bool measureSettings: Qt.application.arguments.indexOf("--open-settings") >= 0

    // `--open-folder-picker [caminho]`: o explorador de pastas não aparece em nenhuma foto de
    // gate sem isto — ele nasce fechado atrás de um botão dentro de outro diálogo.
    readonly property string measureFolderPicker: {
        const i = Qt.application.arguments.indexOf("--open-folder-picker")
        if (i < 0)
            return ""
        const arg = i + 1 < Qt.application.arguments.length ? Qt.application.arguments[i + 1] : ""
        return arg.startsWith("--") || arg === "" ? "/" : arg
    }

    // `--open-queue`: abre a fila inteira antes de fotografar. Mesma razão do de cima — e sem
    // ele a tela nova da fila não teria como ser provada sem alguém clicando.
    readonly property bool measureQueueOverlay: Qt.application.arguments.indexOf("--open-queue") >= 0

    // `--play-open-collection`: dispara o botão de tocar da coleção que `--open-collection`
    // abriu. Sem ele, o gesto só poderia ser provado por alguém clicando.
    readonly property bool measurePlayCollection:
        Qt.application.arguments.indexOf("--play-open-collection") >= 0

    // `--move-last-to-top`: manda a última faixa da coleção aberta para o começo, pelo MESMO
    // sinal que a alça de arrastar emite. Sem isto, o caminho que GRAVA a ordem nunca roda
    // fora da mão de alguém — e uma alça desenhada sobre um caminho que nunca gravou é o
    // defeito que este repo já registrou uma vez.
    readonly property bool measureMoveLastToTop:
        Qt.application.arguments.indexOf("--move-last-to-top") >= 0

    // `--no-search`: não abre o overlay antes de medir.
    readonly property bool measureSearch: Qt.application.arguments.indexOf("--no-search") < 0

    readonly property int measureWidth: {
        const i = Qt.application.arguments.indexOf("--measure")
        if (i < 0 || Qt.application.arguments.length <= i + 1)
            return 0
        const w = parseInt(Qt.application.arguments[i + 1])
        return isNaN(w) ? 0 : w
    }

    // `--measure-height <px>`: a foto sai em 700 por padrão, a altura do desenho. Mas a escala
    // da interface cresce com a MENOR razão entre janela e desenho, então uma janela alta muda
    // tudo de tamanho — e o defeito que só aparece na janela real do usuário não aparecia em
    // nenhuma foto de gate. Poder pedir a altura é o que torna essa janela reproduzível.
    readonly property int measureHeight: {
        const i = Qt.application.arguments.indexOf("--measure-height")
        if (i < 0 || Qt.application.arguments.length <= i + 1)
            return 0
        const h = parseInt(Qt.application.arguments[i + 1])
        return isNaN(h) ? 0 : h
    }

    width: root.measureWidth > 0 ? root.measureWidth : 1100
    height: root.measureHeight > 0 ? root.measureHeight : 700
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: qsTr("melodarium")
    color: Theme.cBase

    // Which pane the icon rail is showing: "library" or "podcast". Search is an overlay,
    // not a pane. The axis inside the library ("albums", "tags", …) is the chips' job.
    property string section: "library"

    // A interface foi desenhada para 1100x700. Numa janela muito maior, tamanho fixo vira
    // interface minúscula perdida no canto; numa muito menor, vira conteúdo cortado. O fator
    // sai da menor razão entre a janela real e o desenho, preso entre 1 e 1,7 para o texto
    // não virar cartaz numa tela de 4K.
    readonly property real escalaDaJanela:
        Math.max(1.0, Math.min(1.7, Math.min(root.width / 1100, root.height / 700)))

    onEscalaDaJanelaChanged: Theme.uiScale = root.escalaDaJanela

    // When a section is a group axis (artists/albums/genres) with no group picked yet, the
    // middle column lists the groups instead of the tracks.
    property bool showingGroups: false
    property var groups: []
    property string groupsTitle: ""
    // O artista do álbum aberto, para o cabeçalho. Vazio em qualquer outra lista.
    property string groupSubtitle: ""
    // The track the tag editor is looking at: the last one the user activated.
    property int selectedTrackId: 0
    // What the middle pane is querying right now, so a rescan can ask for it again. The rail
    // picks the pane; these pick what the pane lists.
    property string currentSection: "all"
    property int currentId: 0
    // 0 when what is playing is not a podcast episode.
    property int currentEpisodeId: 0
    // Which chip of the filter row is lit. The rail picks the pane; this picks the list.
    property string libraryFilter: "all"

    readonly property var filterTitles: ({
        "liked": qsTr("Curtidas"),
        "recent": qsTr("Recentes"),
        "mostPlayed": qsTr("Mais tocadas"),
        "forgotten": qsTr("Esquecidas"),
        "never": qsTr("Nunca ouvi")
    })

    TrackListModel {
        id: trackModel
        currentPath: AudioEngine.currentFile
    }

    function clauseFor(section, id) {
        switch (section) {
        case "artists": return { clause: LibraryBrowser.clauseForArtist(id),
                                 bindings: LibraryBrowser.bindingsFor(id) }
        case "albums":  return { clause: LibraryBrowser.clauseForAlbum(id),
                                 bindings: LibraryBrowser.bindingsFor(id) }
        case "genres":  return { clause: LibraryBrowser.clauseForGenre(id),
                                 bindings: LibraryBrowser.bindingsFor(id) }
        case "collection": return { clause: CollectionManager.clauseForCollection(id),
                                   bindings: CollectionManager.bindingsForCollection(id) }
        case "recent":     return { clause: LibraryBrowser.clauseRecent(), bindings: [] }
        case "mostPlayed": return { clause: LibraryBrowser.clauseMostPlayed(), bindings: [] }
        case "forgotten":  return { clause: LibraryBrowser.clauseForgotten(), bindings: [] }
        case "never":      return { clause: LibraryBrowser.clauseNeverPlayed(), bindings: [] }
        case "liked":      return { clause: LibraryBrowser.clauseForLiked(), bindings: [] }
        default:           return { clause: LibraryBrowser.clauseForAll(), bindings: [] }
        }
    }

    function showSection(section, id) {
        root.currentSection = section
        root.currentId = id
        const isGroupAxis = section === "artists" || section === "albums"
                            || section === "genres" || section === "tags"
        if (isGroupAxis && id === 0) {
            root.groups = section === "artists" ? LibraryBrowser.artists()
                        : (section === "albums" ? LibraryBrowser.albums()
                        : (section === "genres" ? LibraryBrowser.genres()
                                                : CollectionManager.allTags()))
            root.groupsTitle = section === "artists" ? qsTr("Artistas")
                             : (section === "albums" ? qsTr("Álbuns")
                             : (section === "genres" ? qsTr("Gêneros") : qsTr("Tags")))
            root.showingGroups = true
            return
        }
        const q = clauseFor(section, id)
        trackModel.loadFromQuery(q.clause, q.bindings)
        root.showingGroups = false
        // O cabeçalho do miolo diz que lista é esta: "Biblioteca" só quando é a lista inteira.
        if (id === 0)
            root.groupsTitle = root.filterTitles[section] !== undefined
                               ? root.filterTitles[section] : ""
    }

    // The filter row speaks its own keys; the query layer speaks the section names.
    function chooseFilter(key) {
        root.libraryFilter = key
        root.showSection(key === "most" ? "mostPlayed" : key, 0)
    }

    // Opening a group keeps its name on screen: the list is no longer "Biblioteca".
    function openGroup(section, id) {
        let name = ""
        let subtitle = ""
        for (let i = 0; i < root.groups.length; ++i) {
            if (root.groups[i].id === id) {
                name = root.groups[i].name
                // O artista já veio na consulta que montou a lista de grupos: buscá-lo de
                // novo seria uma segunda varredura da tabela de álbuns por clique.
                subtitle = root.groups[i].subtitle !== undefined
                           ? root.groups[i].subtitle : ""
                break
            }
        }
        root.groupSubtitle = section === "albums" ? subtitle : ""
        root.openNamedGroup(section, id, name)
    }

    // Chegar por busca é chegar de fora da lista de grupos: o nome vem junto do resultado.
    function openNamedGroup(section, id, name) {
        // Chegando pela busca não há grupo carregado de onde tirar o artista; chegando pela
        // lista de grupos, openGroup já escreveu o subtítulo uma linha antes.
        if (section !== "albums")
            root.groupSubtitle = ""
        root.section = "library"
        root.libraryFilter = section
        root.currentSection = section
        root.currentId = id
        root.groupsTitle = name
        const q = clauseFor(section, id)
        trackModel.loadFromQuery(q.clause, q.bindings)
        root.showingGroups = false
    }

    function activateTrack(index) {
        AudioEngine.loadPlaylist(trackModel.allPaths(), index)
        AudioEngine.play()
    }

    // Pular dentro da fila que já está carregada: a tirinha e o painel da fila chegam aqui pelo
    // mesmo caminho, e recarregar a MESMA lista com outro índice é o que o motor entende por
    // "vá para esta faixa" sem perder o resto da fila.
    function pularNaFila(queueIndex) {
        AudioEngine.loadPlaylist(AudioEngine.queue, queueIndex)
        AudioEngine.play()
    }

    // As três saídas do estado "nada tocando". Nenhuma delas começa a tocar sozinha: o app
    // só toca quando alguém pede.
    function startFromEmpty(mode) {
        if (mode === "resume") {
            const info = LibraryBrowser.lastPlayed()
            if (info.path === undefined || info.path === "")
                return
            AudioEngine.loadPlaylist([info.path], 0)
            AudioEngine.play()
            if (info.positionMs > 0) {
                resumeSeek.targetSeconds = Math.floor(info.positionMs / 1000)
                resumeSeek.restart()
            }
            return
        }

        const clause = mode === "never" ? LibraryBrowser.clauseNeverPlayed()
                     : (mode === "forgotten" ? LibraryBrowser.clauseForgotten()
                                             : LibraryBrowser.clauseForAll())
        trackModel.loadFromQuery(clause, [])
        root.currentSection = mode === "never" ? "never"
                            : (mode === "forgotten" ? "forgotten" : "all")
        root.currentId = 0
        root.libraryFilter = mode === "shuffle" ? "all" : mode
        root.groupsTitle = root.filterTitles[root.currentSection] !== undefined
                           ? root.filterTitles[root.currentSection] : ""
        root.showingGroups = false

        const paths = trackModel.allPaths()
        if (paths.length === 0)
            return
        AudioEngine.loadPlaylist(paths, 0)
        // Antes daqui o embaralhamento era feito à mão e sumia da tela junto com o convite:
        // ligar o modo do motor deixa o botão do painel aceso e desligável.
        if (mode === "shuffle")
            AudioEngine.setShuffle(true)
        AudioEngine.play()
    }

    function collectTrack(trackId) {
        root.selectedTrackId = trackId
        collectMenu.trackId = trackId
        collectMenu.emLote = false
        collectMenu.options = CollectionManager.collections()
        collectMenu.popup()
    }

    // O mesmo menu, servindo a lista inteira que está na tela.
    function collectAll() {
        collectMenu.trackId = 0
        collectMenu.emLote = true
        collectMenu.options = CollectionManager.collections()
        collectMenu.popup()
    }

    // The rail picks the pane. Search is not a pane: it is an overlay over whatever is on
    // screen, so the rail opens it and leaves the pane where it was.
    function showPane(name) {
        if (name === "search") {
            searchOverlay.open()
            return
        }
        // Voltar para a biblioteca releva a lista que estava aberta: sem isto, sair do
        // podcast e voltar mostrava a lista velha, e clicar em "Biblioteca" já estando
        // nela não fazia absolutamente nada.
        if (name === "library" && root.section === "library")
            root.reloadCurrent()
        root.section = name
    }

    function openSettings() {
        settingsLoader.active = true
        settingsLoader.item.open()
    }

    function openMeasureFolderPicker(path) {
        measureFolderPickerLoader.active = true
        measureFolderPickerLoader.item.abrirEm(path)
    }

    function reloadCurrent() {
        showSection(root.currentSection, root.currentId)
    }

    // Tags are picked by name, not by id, so they do not go through showSection().
    function showTag(name) {
        root.section = "library"
        root.libraryFilter = "tags"
        root.currentSection = "tags"
        root.currentId = 0
        trackModel.loadFromQuery(CollectionManager.clauseForTag(name),
                                 CollectionManager.bindingsForTag(name))
        root.groupsTitle = name
        root.showingGroups = false
    }

    Connections {
        target: Database
        function onScanFinished(added, updated, removed) {
            root.reloadCurrent()
        }
    }

    Connections {
        target: AudioEngine
        // Um motor que não sobe, ou um arquivo que não abre, não podem falhar em silêncio: sem
        // esta linha o sintoma é "clico e não acontece nada".
        function onEngineUnavailable(message) {
            console.warn("melodarium: motor de áudio indisponível — " + message)
        }
        function onPlaybackError(path, message) {
            console.warn("melodarium: não consegui tocar " + path + " — " + message)
        }
        function onTrackFinished(path) {
            PlayStatsRecorder.recordPlay(path)
        }
        // Whatever starts playing decides whether the podcast machinery is armed at all.
        function onCurrentFileChanged() {
            const episode = PodcastLibrary.episodeForPath(AudioEngine.currentFile)
            root.currentEpisodeId = episode.id !== undefined ? episode.id : 0
        }
        // Pausing is the moment the user is most likely to walk away: save once more, so the
        // position survives even if the app is killed before the next 5 s tick.
        function onPlayingChanged() {
            if (!AudioEngine.playing && root.currentEpisodeId > 0)
                PodcastLibrary.savePosition(root.currentEpisodeId,
                                            Math.round(AudioEngine.position * 1000))
            else if (!AudioEngine.playing && root.currentEpisodeId === 0)
                PlayStatsRecorder.savePosition(AudioEngine.currentFile,
                                               Math.round(AudioEngine.position * 1000))
        }
    }

    Connections {
        target: PodcastLibrary
        function onEpisodePlayRequested(path, seekToSeconds) {
            root.section = "podcast"
            AudioEngine.loadPlaylist([path], 0)
            AudioEngine.play()
            // The seek has to wait for the file to actually be loaded: duration only becomes
            // known after mpv opens it.
            resumeSeek.targetSeconds = seekToSeconds
            resumeSeek.restart()
        }
    }

    Timer {
        id: resumeSeek
        property int targetSeconds: 0
        interval: 120
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (AudioEngine.duration > 0) {
                AudioEngine.seek(targetSeconds)
                stop()
            }
        }
    }

    // Saving on every positionChanged would write to SQLite on every UI frame.
    Timer {
        id: positionSaver
        // Mirrors PodcastLibrary::kSaveIntervalMs. A C++ `static constexpr` is NOT visible
        // from QML, so this number is duplicated on purpose — keep the two in sync.
        interval: 5000
        repeat: true
        running: AudioEngine.playing && root.currentEpisodeId > 0
        onTriggered: PodcastLibrary.savePosition(root.currentEpisodeId,
                                                 Math.round(AudioEngine.position * 1000))
    }

    // Mesma razão do timer do podcast: gravar a cada positionChanged escreveria no SQLite a
    // cada quadro. Cinco segundos de imprecisão ao retomar não se percebem.
    Timer {
        interval: 5000
        repeat: true
        running: AudioEngine.playing && root.currentEpisodeId === 0
                 && AudioEngine.currentFile !== ""
        onTriggered: PlayStatsRecorder.savePosition(AudioEngine.currentFile,
                                                    Math.round(AudioEngine.position * 1000))
    }

    Connections {
        target: YtDlpDownloader
        // The freshly downloaded track only shows up in the list if the list is asked again.
        function onFinished(url, trackId) { root.reloadCurrent() }
    }

    // `melodarium --measure` imprime UMA linha com as medidas dos painéis e sai. É assim que a
    // fidelidade ao desenho aprovado vira verificação mecânica (tools/check-layout.sh) em vez
    // de opinião: uma mudança acidental de layout falha o gate em vez de virar tela torta.
    Loader {
        active: root.measuring
        // O overlay abre antes de medir de propósito: o conteúdo de um Popup só é construído
        // na primeira abertura, e um erro lá dentro passaria despercebido por um app que
        // nunca o abre.
        sourceComponent: Item {
            Timer {
                running: true
                interval: 600
                onTriggered: {
                    if (root.measureCollection > 0)
                        collectionsPane.openById(root.measureCollection)
                    if (root.measurePlayCollection)
                        collectionsPane.playRequested(false)
                    // `count`, não `rowCount()`: o modelo expõe a contagem por Q_PROPERTY, e
                    // a chave do id em `trackAt` é `id`, não `trackId`.
                    if (root.measureMoveLastToTop && trackModel.count > 1)
                        collectionsPane.trackMoved(
                            trackModel.trackAt(trackModel.count - 1).id, 0)
                    if (root.measureAlbum > 0) {
                        // O caminho do clique: o eixo carrega os grupos, e o grupo abre a
                        // partir deles — é de lá que o artista do cabeçalho vem.
                        root.showSection("albums", 0)
                        root.openGroup("albums", root.measureAlbum)
                    }
                    if (root.measureEpisode > 0)
                        PodcastLibrary.playEpisode(root.measureEpisode)
                    if (root.measureTrack !== "") {
                        AudioEngine.loadPlaylist([root.measureTrack], 0)
                        AudioEngine.play()
                    }
                    if (root.measureQueue)
                        root.startFromEmpty(root.measureQueueMode)
                    for (let r = 0; r < root.measureRepeat; ++r)
                        AudioEngine.cycleRepeat()
                    if (root.measureSettings)
                        root.openSettings()
                    if (root.measureFolderPicker !== "")
                        root.openMeasureFolderPicker(root.measureFolderPicker)
                    if (root.measureQueueOverlay)
                        queueOverlay.open()
                    if (!root.measureSearch)
                        return
                    searchOverlay.open()
                    if (root.measureSearchText !== "")
                        searchOverlay.typeForMeasure(root.measureSearchText)
                    if (root.measureQueueHit) {
                        searchOverlay.queueAt(searchOverlay.highlighted)
                        searchOverlay.close()
                    }
                    if (root.measureActivateHit)
                        searchOverlay.activate(searchOverlay.highlighted)
                }
            }

            Timer {
            running: true
            interval: root.measureDelay
            onTriggered: {
                console.log("MEDIDA rail=" + Math.round(rail.width)
                            + " painel=" + Math.round(nowPlaying.width)
                            + " miolo=" + Math.round(pane.width)
                            + " capa=" + Math.round(nowPlaying.coverWidth)
                            + "x" + Math.round(nowPlaying.coverHeight)
                            + " janela=" + Math.round(root.width)
                            + "x" + Math.round(root.height)
                            + " chips=" + Math.round(libraryPane.chipsImplicitWidth)
                            + " chipsvao=" + Math.round(libraryPane.chipsWidth)
                            + " busca=" + Math.round(searchOverlay.width)
                            + "x" + Math.round(searchOverlay.height)
                            + " fila=" + AudioEngine.queueCount
                            + " movimento=" + (Theme.reduzirMovimento ? "off" : "on")
                            + " halo=" + (nowPlaying.mostrarHalo ? "on" : "off")
                            + " motor=" + (AudioEngine.isAvailable() ? "ok" : "MORTO"))
                if (root.shotPath === "") {
                    Qt.quit()
                    return
                }
                const grab = root.contentItem.grabToImage(function (result) {
                    console.log("SHOT " + (result.saveToFile(root.shotPath)
                                           ? root.shotPath : "falhou"))
                    Qt.quit()
                })
                if (!grab) {
                    console.log("SHOT falhou: grabToImage recusou")
                    Qt.quit()
                }
            }
            }
        }
    }

    // As mesmas chaves que o SettingsDialog grava. Duplicadas de propósito: um Settings do
    // QML é um par (categoria, propriedade), e a janela precisa lê-las antes de o diálogo
    // existir.
    Settings {
        id: prefsAudio
        category: "audio"
        property bool replayGain: false
        property bool exclusiveOutput: false
    }

    Component.onCompleted: {
        Theme.uiScale = root.escalaDaJanela
        Theme.reduzirMovimento = root.semAnimacao
        Theme.medindo = root.measuring && !root.comHalo
        // Preferência que não vale na partida não é preferência: o diálogo só aplica quando
        // é aberto, e ninguém abre ajustes toda vez que liga o app.
        AudioEngine.setReplayGainMode(prefsAudio.replayGain ? "track" : "no")
        AudioEngine.setExclusiveOutput(prefsAudio.exclusiveOutput)
        if (Database.libraryPath !== "")
            trackModel.loadAllTracks()
        // Finding out whether yt-dlp exists costs one process start; finding out at the moment
        // the user clicks costs a dialog that fails in their face.
        YtDlpDownloader.probe()
    }

    // O fundo da cena, e não só o da janela: `Window.color` pinta o "clear color", que existe
    // na tela mas NÃO entra em nenhuma captura — e a conferência de fidelidade ao desenho é
    // feita sobre a captura. Com ele, toda foto mostra a mesma tela que o Pedro vê.
    Rectangle {
        anchors.fill: parent
        color: Theme.cBase
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        IconRail {
            id: rail
            Layout.fillHeight: true
            current: root.section
            onChosen: function (name) { root.showPane(name) }
            onSettingsRequested: root.openSettings()
        }

        NowPlayingPanel {
            id: nowPlaying
            Layout.fillHeight: true
            // Both follow the panel's own implicit width so compact mode actually narrows the
            // frame; fillWidth stays false so the panel can never eat the pane.
            Layout.preferredWidth: nowPlaying.implicitWidth
            Layout.maximumWidth: nowPlaying.implicitWidth
            Layout.fillWidth: false
            compact: root.width < 900
            episodeMode: root.currentEpisodeId > 0
            onLikeRequested: function (id) { LibraryBrowser.toggleLike(id) }
            onPlayRequested: function (mode) { root.startFromEmpty(mode) }
            onTagChosen: function (name) { root.showTag(name) }
            onCollectRequested: function (id) { root.collectTrack(id) }
            onQueueJumpRequested: function (queueIndex) { root.pularNaFila(queueIndex) }
            onQueueOpenRequested: queueOverlay.open()
        }

        StackLayout {
            id: pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            // A lista é o ponto da tela: nunca cede espaço ao painel.
            Layout.minimumWidth: Theme.paneMinWidth
            // Medir mede a tela da biblioteca: qual banco a máquina tem não pode mudar o
            // resultado do gate de layout.
            currentIndex: root.measuring
                          ? (root.measurePane === "podcast"
                             ? 1 : (root.measurePane === "empty"
                                    ? 2 : (root.measurePane === "collections" ? 3 : 0)))
                          : (root.section === "podcast"
                             ? 1
                             : (root.section === "collections"
                                ? 3
                                : (Database.libraryPath === "" ? 2 : 0)))

            LibraryPane {
                id: libraryPane
                model: trackModel
                // Um assunto, um lugar: o pé da lista só assume a fila quando o cartão do
                // painel não coube.
                showQueueStrip: !nowPlaying.mostrandoProxima
                filter: root.libraryFilter
                groups: root.groups
                showingGroups: root.showingGroups
                groupTitle: root.groupsTitle
                groupSubtitle: root.groupSubtitle
                scanning: Database.scanning
                onGroupChosen: function (key) { root.chooseFilter(key) }
                onGroupOpened: function (section, id) { root.openGroup(section, id) }
                onTagOpened: function (name) { root.showTag(name) }
                onTrackActivated: function (index) { root.activateTrack(index) }
                onCollectRequested: function (trackId) { root.collectTrack(trackId) }
                onCollectAllRequested: root.collectAll()
                onSearchRequested: searchOverlay.open()
                onQueueActivated: function (queueIndex) { root.pularNaFila(queueIndex) }
                onQueueExpandRequested: queueOverlay.open()
            }

            PodcastPane {
                episodePlaying: root.currentEpisodeId > 0
                currentPath: AudioEngine.currentFile
            }

            EmptyPane {
                framed: true
                onPlayRequested: function (mode) { root.startFromEmpty(mode) }
            }

            CollectionsPane {
                id: collectionsPane
                model: trackModel
                onCollectionOpened: function (id, name) {
                    root.currentSection = "collection"
                    root.currentId = id
                    const q = root.clauseFor("collection", id)
                    trackModel.loadFromQuery(q.clause, q.bindings)
                }
                onCloseRequested: {
                    // Sair de uma coleção devolve a lista inteira ao modelo: o painel da
                    // biblioteca compartilha este modelo e não pode herdar o filtro.
                    root.currentSection = "all"
                    root.currentId = 0
                    root.showSection("all", 0)
                }
                onTrackActivated: function (index) { root.activateTrack(index) }
                onPlayRequested: function (shuffled) {
                    // O modelo é o da coleção aberta: allPaths() já devolve as faixas dela na
                    // ordem manual (clauseForCollection ordena por collection_tracks.position).
                    const paths = trackModel.allPaths()
                    if (paths.length === 0)
                        return
                    AudioEngine.loadPlaylist(paths, 0)
                    // Depois do loadPlaylist, como em startFromEmpty: ligar o modo antes de a
                    // fila existir deixa o botão do painel aceso sobre uma fila vazia.
                    AudioEngine.setShuffle(shuffled)
                    AudioEngine.play()
                }
                // Sem recarregar, a linha removida continua na tela até alguém trocar de
                // painel — e o usuário clica de novo achando que o botão não funcionou.
                onTrackRemoved: function (trackId) {
                    const q = root.clauseFor("collection", collectionsPane.openId)
                    trackModel.loadFromQuery(q.clause, q.bindings)
                }
                onTrackMoved: function (trackId, newIndex) {
                    if (!CollectionManager.moveTrackInCollection(collectionsPane.openId,
                                                                 trackId, newIndex))
                        return
                    // Recarregar do banco, nunca reordenar a lista na mão: o banco é a fonte
                    // da ordem, e uma lista remendada mentiria até a próxima troca de painel.
                    const q = root.clauseFor("collection", collectionsPane.openId)
                    trackModel.loadFromQuery(q.clause, q.bindings)
                }
            }
        }
    }

    SearchOverlay {
        id: searchOverlay

        onTrackChosen: function (path) {
            AudioEngine.loadPlaylist([path], 0)
            AudioEngine.play()
        }
        onEpisodeChosen: function (episodeId) { PodcastLibrary.playEpisode(episodeId) }
        onTrackQueued: function (path) { AudioEngine.appendToQueue(path) }
        onAlbumChosen: function (albumId, title) {
            root.openNamedGroup("albums", albumId, title)
        }
        onArtistChosen: function (artistId, title) {
            root.openNamedGroup("artists", artistId, title)
        }
        onCollectionChosen: function (collectionId, title) {
            root.showPane("collections")
            collectionsPane.open(collectionId, title)
        }
    }

    QueueOverlay {
        id: queueOverlay
        onEntryActivated: function (queueIndex) { root.pularNaFila(queueIndex) }
    }

    // Ferramentas fechadas não devem montar centenas de objetos nem tocar o filesystem. Os
    // loaders são síncronos na primeira abertura, então o gesto continua abrindo no mesmo frame.
    Loader {
        id: measureFolderPickerLoader
        active: false
        sourceComponent: FolderPickerDialog {
            title: qsTr("Pasta de música")
        }
    }

    Loader {
        id: settingsLoader
        active: false
        sourceComponent: SettingsDialog {
            onLibraryPathPicked: function (path) {
                // A pasta mudou: a lista aberta é da pasta antiga.
                root.showSection("all", 0)
            }
        }
    }

    // Ctrl+F por hábito antigo, Ctrl+K porque é o gesto que todo app com paleta usa hoje.
    Shortcut {
        sequences: ["Ctrl+K", "Ctrl+F"]
        onActivated: searchOverlay.open()
    }

    // The single manual gesture: one click on the row's plus, one click on a collection.
    Menu {
        id: collectMenu

        property int trackId: 0
        property var options: []
        // Com emLote, o alvo não é uma faixa: é tudo que a lista está mostrando.
        property bool emLote: false

        Instantiator {
            model: collectMenu.options
            delegate: MenuItem {
                required property var modelData
                text: modelData.name
                onTriggered: {
                    if (collectMenu.emLote)
                        CollectionManager.addTracksToCollection(modelData.id,
                                                               trackModel.allTrackIds())
                    else
                        CollectionManager.addTrackToCollection(modelData.id,
                                                               collectMenu.trackId)
                }
            }
            onObjectAdded: function (index, object) { collectMenu.insertItem(index, object) }
            onObjectRemoved: function (index, object) { collectMenu.removeItem(object) }
        }

        MenuItem {
            text: qsTr("Nova coleção…")
            onTriggered: {
                newCollectionForTrack.pendingTrackId = collectMenu.trackId
                newCollectionForTrack.pendingLote = collectMenu.emLote
                newCollectionForTrack.renameId = 0
                newCollectionForTrack.initialText = ""
                newCollectionForTrack.open()
            }
        }
    }

    NewCollectionDialog {
        id: newCollectionForTrack

        property int pendingTrackId: 0
        property bool pendingLote: false

        onCreated: function (id, name) {
            if (newCollectionForTrack.pendingLote)
                CollectionManager.addTracksToCollection(id, trackModel.allTrackIds())
            else if (newCollectionForTrack.pendingTrackId > 0)
                CollectionManager.addTrackToCollection(id, newCollectionForTrack.pendingTrackId)
            newCollectionForTrack.pendingTrackId = 0
            newCollectionForTrack.pendingLote = false
        }
    }
}
