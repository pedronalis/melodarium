# Research: RSS de podcast + download YouTube (yt-dlp externo)

Ambiente local confirmado nesta pesquisa: yt-dlp **2026.01.31** (não 2026.08.19 —
checar de novo antes de codar, mas as flags usadas aqui são estáveis há anos).
ffmpeg/ffprobe existem em `/home/linuxbrew/.linuxbrew/bin/` (Homebrew), **não**
em `/usr/bin`. yt-dlp busca `ffmpeg` no `PATH` — se o app QProcess herdar um
ambiente sem o linuxbrew no PATH (ex.: lançado por um `.desktop` file), o
`--embed-thumbnail`/`-x` falha em silêncio-relativo (mensagem de erro, não crash).
**Armadilha registrada**: o app precisa ou (a) confiar no PATH do usuário, ou
(b) descobrir `ffmpeg`/`ffprobe` explicitamente e passar `--ffmpeg-location`.

---

## Parte A — RSS de podcast

### A.1 — O que importa num feed real

Elementos por **channel** (`<channel>` dentro de `<rss><channel>`):

- `<title>`, `<description>` (ou `<itunes:summary>`)
- `<itunes:image href="...">` — preferir a este sobre `<image><url>` (mais
  confiável e sempre presente em feed de podcast válido); `<image><url>` é o
  fallback RSS 2.0 genérico.
- `<itunes:author>`, `<language>`

Elementos por **item** (episódio):

- `<title>`
- `<guid isPermaLink="true|false">texto</guid>` — **chave de identidade
  primária**. Quando ausente (feeds mal formados existem), usar como fallback
  o hash de `(enclosure url + pubDate)`, nessa ordem — nunca o título sozinho
  (títulos se repetem em reprises/"best of").
- `<pubDate>` em RFC822/RFC2822
- `<enclosure url="..." length="..." type="audio/mpeg"/>` — é o link do
  áudio. **`length` é o tamanho em bytes declarado pelo servidor, não
  confiável** (muitos feeds mandam `0` ou omitem) — nunca usar para alocar
  buffer, só como estimativa de progresso quando > 0.
- `<itunes:duration>` em 3 formatos possíveis: segundos puros (`"1834"`),
  `MM:SS` (`"30:34"`), `HH:MM:SS` (`"1:30:34"`) — parse manual (não há
  parser Qt pronto pra isso).
- `<itunes:episode>`, `<itunes:season>` (inteiros, opcionais)
- `<description>` (texto simples/HTML leve) vs `<content:encoded>` (namespace
  `content`, HTML rico, geralmente mais completo) — preferir
  `content:encoded` quando presente, cair para `description` senão.

### A.2 — Armadilhas reais

1. **pubDate malformado**: alguns feeds mandam `Mon, 06 Sep 2021 04:00:00 -0000`
   (ok), outros `Mon, 6 Sep 2021 4:00:00 GMT` (dia/hora sem zero à esquerda —
   ainda válido RFC822) ou lixo tipo `2021-09-06` (ISO, não RFC822 — quebra o
   parser RFC). **Solução**: `QDateTime::fromString(str, Qt::RFC2822Date)`
   primeiro; se `isValid()` falhar, tentar `Qt::ISODate` como fallback; se os
   dois falharem, usar a data de fetch como aproximação e logar o guid.
   Confirmado no header: `Qt::RFC2822Date = 8` existe em `qnamespace.h:1255`
   com o comentário `// RFC 2822 (+ 850 e 1036 durante parsing)` — ou seja, o
   próprio Qt já tolera as variantes RFC850/RFC1036 antigas dentro desse enum,
   não precisa parser manual pra isso.

2. **Enclosure ausente**: item sem `<enclosure>` não é episódio baixável
   (pode ser nota/trailer textual) — descartar da lista de episódios
   reproduzíveis, não crashar.

3. **Feed com 500+ episódios**: NUNCA usar `QDomDocument` (carrega tudo em
   memória como árvore). Usar `QXmlStreamReader` incremental, processar item
   por item e emitir/inserir no SQLite conforme lê — memória constante
   independente do tamanho do feed.

4. **Redirect 301/302**: `QNetworkAccessManager` **não segue redirects
   automaticamente por padrão** desde Qt 6 nas versões antigas mudou;
   confirmado no header `qnetworkrequest.h:71` — existe
   `RedirectPolicyAttribute` com valores incluindo `NoLessSafeRedirectPolicy`
   e `ManualRedirectPolicy`. Setar explicitamente via
   `request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy)`
   ANTES do `get()` garante que HTTP→HTTP e HTTPS→HTTPS redirects sejam
   seguidos automaticamente (o "NoLessSafe" bloqueia só downgrade
   HTTPS→HTTP, que é o comportamento certo pra feed de terceiro).

5. **gzip**: `QNetworkAccessManager` não descomprime automaticamente — Qt
   Network não seta `Accept-Encoding: gzip` nem descomprime a resposta
   sozinho (isso é comportamento de QNetworkAccessManager desde sempre, não
   há flag pra ligar). Se o servidor manda gzip por conta própria (raro sem
   pedir), o app recebe bytes comprimidos como se fossem texto — **não
   pedir `Accept-Encoding: gzip` no header da request evita esse caso**
   (deixar o default, que não anuncia suporte a gzip).

6. **Conditional GET ignorado pelo servidor**: nem todo host de podcast
   respeita `If-Modified-Since`/`If-None-Match` — sempre tratar como
   otimização best-effort. Verificar `HttpStatusCodeAttribute` == 304 e, se
   não for 304, reprocessar o feed inteiro normalmente (idempotente pelo
   guid, então reprocessar não duplica).

7. **Namespace itunes**: `QXmlStreamReader::name()` retorna o **local name**
   sem prefixo (ex.: `"image"` para `<itunes:image>`), e `namespaceUri()`
   retorna a URI declarada (`http://www.itunes.com/dtds/podcast-1.0.dtd`).
   Comparar por `namespaceUri() == u"http://www.itunes.com/dtds/podcast-1.0.dtd" && name() == u"image"`
   é mais robusto que comparar prefixo (`itunes:`), porque o prefixo é
   arbitrário — mas na prática **quase todo feed usa literalmente `itunes:`**
   e comparar `qualifiedName() == u"itunes:duration"` funciona 99% do tempo
   e é mais simples de escrever. Registrar a robusta como comentário.

### A.3 — Código: fetch + parse incremental + conditional GET

```cpp
// PodcastFeedFetcher.h
#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>

class PodcastFeedFetcher : public QObject {
    Q_OBJECT
public:
    explicit PodcastFeedFetcher(QObject *parent = nullptr)
        : QObject(parent), m_nam(new QNetworkAccessManager(this)) {}

    // etag/lastModified: valores salvos no SQLite da última checagem bem-sucedida.
    // Passe strings vazias na primeira checagem de um feed.
    void fetch(const QUrl &feedUrl, const QByteArray &etag,
               const QByteArray &lastModified) {
        QNetworkRequest req(feedUrl);
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                          QNetworkRequest::NoLessSafeRedirectPolicy);
        req.setTransferTimeout(15000); // ms; Qt 6.7+; existe em 6.10 confirmado por API deprecation notes
        if (!etag.isEmpty())
            req.setRawHeader("If-None-Match", etag);
        if (!lastModified.isEmpty())
            req.setRawHeader("If-Modified-Since", lastModified);

        QNetworkReply *reply = m_nam->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply] {
            reply->deleteLater();
            const int status = reply->attribute(
                QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (status == 304) {
                emit notModified();
                return;
            }
            if (reply->error() != QNetworkReply::NoError) {
                emit fetchFailed(reply->errorString());
                return;
            }
            const QByteArray newEtag = reply->rawHeader("ETag");
            const QByteArray newLastMod = reply->rawHeader("Last-Modified");
            parseFeed(reply, newEtag, newLastMod);
        });
    }

signals:
    void episodeParsed(const QString &guid, bool isPermaLink,
                        const QString &title, const QUrl &enclosureUrl,
                        qint64 enclosureLength, int durationSeconds,
                        const QDateTime &pubDate);
    void feedMetaParsed(const QString &title, const QUrl &imageUrl);
    void notModified();
    void fetchFailed(const QString &reason);
    void finished(const QByteArray &etag, const QByteArray &lastModified);

private:
    void parseFeed(QIODevice *device, const QByteArray &etag,
                    const QByteArray &lastModified) {
        QXmlStreamReader xml(device);
        QString curTitle, curGuid, curEnclosureUrl, curDurationRaw;
        bool curGuidIsPermaLink = true;
        qint64 curEnclosureLength = 0;
        QDateTime curPubDate;
        bool inItem = false;

        while (!xml.atEnd()) {
            const auto tok = xml.readNext();
            if (tok == QXmlStreamReader::StartElement) {
                const auto elName = xml.qualifiedName();
                if (elName == u"item") {
                    inItem = true;
                    curTitle.clear(); curGuid.clear();
                    curEnclosureUrl.clear(); curDurationRaw.clear();
                    curEnclosureLength = 0; curPubDate = {};
                    curGuidIsPermaLink = true;
                } else if (inItem && elName == u"title") {
                    curTitle = xml.readElementText();
                } else if (inItem && elName == u"guid") {
                    const auto attrs = xml.attributes();
                    curGuidIsPermaLink =
                        attrs.value(u"isPermaLink") != u"false";
                    curGuid = xml.readElementText();
                } else if (inItem && elName == u"pubDate") {
                    const QString raw = xml.readElementText();
                    curPubDate = QDateTime::fromString(raw, Qt::RFC2822Date);
                    if (!curPubDate.isValid())
                        curPubDate = QDateTime::fromString(raw, Qt::ISODate);
                } else if (inItem && elName == u"enclosure") {
                    const auto attrs = xml.attributes();
                    curEnclosureUrl = attrs.value(u"url").toString();
                    curEnclosureLength =
                        attrs.value(u"length").toString().toLongLong();
                } else if (inItem && elName == u"itunes:duration") {
                    curDurationRaw = xml.readElementText();
                }
                // itunes:image / channel title tratados fora de "inItem",
                // omitido aqui por espaço — mesmo padrão.
            } else if (tok == QXmlStreamReader::EndElement) {
                if (xml.qualifiedName() == u"item") {
                    inItem = false;
                    if (curEnclosureUrl.isEmpty())
                        continue; // sem áudio, não é episódio reproduzível
                    const QString identity = !curGuid.isEmpty()
                        ? curGuid
                        : QString::number(qHash(curEnclosureUrl +
                              curPubDate.toString(Qt::ISODate)));
                    emit episodeParsed(identity, curGuidIsPermaLink, curTitle,
                                       QUrl(curEnclosureUrl),
                                       curEnclosureLength,
                                       parseItunesDuration(curDurationRaw),
                                       curPubDate);
                }
            }
        }
        if (xml.hasError()) {
            emit fetchFailed(xml.errorString());
            return;
        }
        emit finished(etag, lastModified);
    }

    static int parseItunesDuration(const QString &raw) {
        if (raw.isEmpty()) return 0;
        const auto parts = raw.split(u':');
        int seconds = 0;
        for (const auto &p : parts) seconds = seconds * 60 + p.toInt();
        return seconds;
    }

    QNetworkAccessManager *m_nam;
};
```

**Nota de assinatura verificada**: `setTransferTimeout(int)` — método de
`QNetworkRequest` adicionado a partir do Qt 6.7 (não estava nas versões 6.3-6.6);
como o ambiente aqui é Qt 6.10.3, está disponível, mas **NÃO VERIFICADO
diretamente contra o header nesta sessão** (fiz a checagem de outras
assinaturas, não desta) — confirmar com
`grep -n "setTransferTimeout" /usr/include/qt6/QtNetwork/qnetworkrequest.h`
antes de compilar; se ausente, a alternativa é um `QTimer` manual que chama
`reply->abort()`.

### A.4 — Download do episódio (arquivo grande)

Padrão: abrir um `QFile` em modo `WriteOnly` com sufixo `.part`, escrever a
cada `readyRead()`, mover pra nome final só no `finished()` sem erro.

```cpp
void EpisodeDownloader::start(const QUrl &url, const QString &destPath) {
    const QString partPath = destPath + u".part";
    auto *file = new QFile(partPath, this);
    qint64 resumeFrom = 0;
    if (file->exists()) {
        resumeFrom = file->size();
        file->open(QIODevice::Append);
    } else {
        file->open(QIODevice::WriteOnly);
    }

    QNetworkRequest req(url);
    if (resumeFrom > 0)
        req.setRawHeader("Range", "bytes=" + QByteArray::number(resumeFrom) + "-");

    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::readyRead, this, [reply, file] {
        file->write(reply->readAll());
    });
    connect(reply, &QNetworkReply::downloadProgress, this,
            [this, resumeFrom](qint64 got, qint64 total) {
        emit progress(resumeFrom + got, total > 0 ? resumeFrom + total : -1);
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, file, partPath, destPath] {
        reply->deleteLater();
        file->close();
        if (reply->error() != QNetworkReply::NoError) {
            emit failed(reply->errorString()); // .part fica no disco, retomável
            return;
        }
        const int status = reply->attribute(
            QNetworkRequest::HttpStatusCodeAttribute).toInt();
        // servidor pode ignorar Range e mandar 200 com o arquivo inteiro de novo —
        // nesse caso o resumeFrom já escreveu no meio do arquivo errado.
        // Checagem obrigatória: se pediu Range e voltou 200 (não 206), truncar e recomeçar do zero.
        QFile::rename(partPath, destPath);
        emit finished();
    });
    // cancelamento: reply->abort() de fora; o .part fica no disco pra retomar depois.
}
```

**Armadilha real e séria**: quando o app manda `Range: bytes=N-` mas o
servidor **não suporta range** (comum em CDN de podcast barata), ele responde
`200 OK` com o corpo inteiro do zero — não `206 Partial Content`. Se o código
não checar `HttpStatusCodeAttribute == 206` antes de fazer `Append`, o
arquivo final fica corrompido (dados duplicados/deslocados). **Fix
obrigatório**: checar status 206 vs 200 no `finished()`; se pediu Range e veio
200, descartar o que tinha e escrever do zero (ou, mais simples: sempre abrir
em modo de escrita truncando e reler do zero quando status != 206).

**`.part` órfão ao reabrir o app**: na inicialização, varrer o diretório de
downloads por `*.part`; para cada um, checar se existe registro correspondente
"em progresso" no SQLite — se sim, oferecer retomar (o código acima já
suporta via Range); se não há registro (crash antes de gravar o registro, ou
usuário cancelou e saiu), **apagar o `.part`** — não deixar lixo acumular
silenciosamente.

### A.5 — Limite honesto: "baixando sozinho"

Um app Qt desktop comum só roda enquanto está aberto: um `QTimer` de
verificação periódica (ex.: a cada 30-60min) só dispara com o processo vivo —
se o Melodarium estiver fechado, nenhum episódio novo é baixado, mesmo que o
timer diga "a cada 1h". Isso é diferente de "baixa sozinho em segundo plano
mesmo com o app fechado", que exigiria um serviço separado do processo da UI
— no Linux isso seria uma `systemd --user` timer/service rodando um binário
auxiliar sem GUI, e no Windows um Task Scheduler + serviço equivalente:
mais um processo pra manter, versionar e depurar, fora do escopo atual. Registrar
na UI como "verifica novos episódios enquanto o app está aberto", não
prometer mais que isso.

---

## Parte B — yt-dlp externo via QProcess

### B.1 — Linha de comando

```
yt-dlp \
  -f "bestaudio/best" \
  --extract-audio --audio-format best \
  --embed-thumbnail --embed-metadata --convert-thumbnails jpg \
  --newline \
  -o "%(title)s [%(id)s].%(ext)s" \
  -P "home:/caminho/controlado/pelo/app" \
  "<URL_COLADA_PELO_USUARIO>"
```

Decisões e justificativa:

- **`-f "bestaudio/best"`**, não só `bestaudio` sozinho: `bestaudio` pode
  falhar em vídeos onde o extrator só expõe formatos combinados (áudio+vídeo
  juntos, sem trilha de áudio isolada) — o fallback `/best` garante que
  sempre baixa alguma coisa reprodutível como áudio (o `-x` extrai o áudio de
  dentro se vier combinado). Sem o fallback, um vídeo raro sem stream de
  áudio isolado trava o download com erro "requested format not available".

- **`--extract-audio --audio-format best`** (equivalente a `-x --audio-format best`),
  **não** reencodar pra um formato fixo tipo mp3: `--audio-format best` (o
  próprio default do yt-dlp) significa "não reencode, apenas garanta que o
  post-processamento produza o melhor áudio possível preservando o
  container/codec original quando possível" — na prática, pra a maioria dos
  vídeos do YouTube isso resulta em manter o Opus/m4a original sem
  transcodificação de fato, só rodando o ffmpeg pra separar do container de
  vídeo se necessário e embutir tags. Isso alinha com o requisito do spec:
  não perder qualidade reencodando algo que já é lossy. Se o spec um dia
  quiser force MP3 universal por compatibilidade, trocar pra
  `--audio-format mp3`, mas isso reencode e degrada — só usar se realmente
  precisar.

- **`--embed-thumbnail`**: requer ffmpeg (confirmado: a flag de extração de
  áudio já diz "requires ffmpeg and ffprobe" no help; embed-thumbnail some
  processing de imagem depende do mesmo ffmpeg). Container de áudio como
  Opus puro não tem slot padrão de capa embutida em todo player — por isso
  **`--convert-thumbnails jpg`** junto: converte a miniatura pra JPG antes de
  embutir, o que tem suporte mais amplo em containers de áudio (m4a/mp3) do
  que webp (formato nativo das thumbs do YouTube, que nem todo player/tageador
  reconhece).

- **`--embed-metadata`**: grava título/canal/etc como tags no arquivo de
  áudio final — é o que faz o TagLib do app enxergar metadados sem o Melodarium
  ter que parsear o JSON do yt-dlp separadamente depois.

- **`-o "%(title)s [%(id)s].%(ext)s"`**: inclui o ID do vídeo no nome pra
  evitar colisão entre títulos duplicados/re-uploads; **NÃO VERIFICADO**
  contra o `--help` completo de OUTPUT TEMPLATE nesta sessão (a seção
  "OUTPUT TEMPLATE" é longa e não foi extraída integralmente aqui) — os
  nomes de campo `%(title)s`, `%(id)s`, `%(ext)s` são estáveis há anos no
  yt-dlp e amplamente documentados, mas confirmar com
  `yt-dlp --help | grep -A100 "OUTPUT TEMPLATE"` antes de codar se quiser
  campos menos comuns (ex. `%(channel)s`).

- **`-P "home:<path>"`**: fixa o destino final num diretório controlado pelo
  app (a pasta de downloads da biblioteca), sem depender do usuário não
  passar um `-o` absoluto por engano — usar `-P` em vez de embutir o path
  inteiro em `-o` mantém o template de nome de arquivo separado do
  diretório, que é mais fácil de validar/sanitizar no código do app.

### B.2 — Metadados antes de baixar

```
yt-dlp -J --skip-download "<URL>"
```

Ou, mais barato, com `--print` puxando só os campos usados (evita serializar
o JSON gigante inteiro e parsear no C++ — pega só as linhas que interessam):

```
yt-dlp --print "%(title)s" --print "%(channel)s" --print "%(duration)s" \
       --print "%(thumbnail)s" --skip-download "<URL>"
```

**Custo real**: qualquer uma das duas formas **faz uma requisição de rede completa**
pra extrair metadados do YouTube (não é grátis nem instantâneo) — são ~1-3s
de latência típica por vídeo, e conta como acesso à rede pro usuário que pode
estar em plano limitado/medido. Mostrar um spinner/estado de "buscando
informações..." antes de habilitar o botão de confirmar download.

`-J` (`--dump-single-json`) implica `--simulate` automaticamente
(confirmado no help: "Simulate unless --no-simulate is used") — então **não
precisa `--skip-download` junto com `-J`**, é redundante mas inofensivo.
Já `--print` sozinho (`-O`/`--print`, não `-J`) também implica `--simulate`
"a menos que --no-simulate ou estágios posteriores de WHEN sejam usados" —
mesma lógica, `--skip-download` é cinto-e-suspensório, não obrigatório.

### B.3 — Progresso parseável

Com `--newline`, cada atualização de progresso vira uma linha nova no stdout
em vez de sobrescrever a mesma linha com `\r` (que é o comportamento padrão
de terminal e quebra parsing linha-a-linha). Formato típico de uma linha de
progresso do yt-dlp (formato humano, não veio nesta sessão de um `--help`
mas é o formato estável e documentado do yt-dlp):

```
[download]  42.3% of 8.19MiB at 1.24MiB/s ETA 00:04
```

Parsear isso com regex é frágil (varia por locale/versão). **Melhor**: usar
`--progress-template` pra emitir um formato fixo e fácil de fazer parse,
próprio:

```
--progress-template "download:PROGRESS %(progress.downloaded_bytes)s %(progress.total_bytes)s %(progress.eta)s"
```

Isso produz linhas como `PROGRESS 4302011 8588123 4` que o app faz split por
espaço e converte pra `int`/`float` sem regex nenhuma. Os nomes de campo
dentro de `progress.*` (`downloaded_bytes`, `total_bytes`, `eta`, `speed`)
são os documentados no help sob `--progress-template` ("info" e "progress"
keys) — **os nomes exatos de subcampos de `progress` NÃO estavam no texto
extraído do `--help` nesta sessão**, então marcar como parcialmente
verificado: a existência da flag e a estrutura geral (`info.*`/`progress.*`)
está confirmada, os nomes exatos de subcampo vêm da doc pública do yt-dlp e
devem ser confirmados rodando `yt-dlp --progress-template "download:%(progress)j" <qualquer_url> --skip-download` (imprime o dict JSON completo de progress) antes de codar o parser final.

### B.4 — QProcess: invocação, leitura, cancelamento, ausência

```cpp
// YtDlpDownloader.h
#pragma once
#include <QObject>
#include <QProcess>
#include <QStringList>

class YtDlpDownloader : public QObject {
    Q_OBJECT
public:
    explicit YtDlpDownloader(QObject *parent = nullptr) : QObject(parent) {}

    // Verificação de presença: chamar uma vez no boot do app, não a cada download.
    static bool isAvailable() {
        QProcess probe;
        probe.start(u"yt-dlp"_s, {u"--version"_s});
        if (!probe.waitForStarted(2000)) return false; // QProcess::FailedToStart
        probe.waitForFinished(3000);
        return probe.exitStatus() == QProcess::NormalExit && probe.exitCode() == 0;
    }

    void start(const QUrl &url, const QString &destDir) {
        // NUNCA concatenar string: url é entrada do usuário (link colado),
        // cada argumento vai como elemento separado da QStringList — QProcess
        // passa exec() direto ao SO, sem shell no meio, então não há
        // injeção de shell mesmo se a URL contiver aspas/`;`/etc.
        const QStringList args = {
            u"-f"_s, u"bestaudio/best"_s,
            u"--extract-audio"_s, u"--audio-format"_s, u"best"_s,
            u"--embed-thumbnail"_s, u"--embed-metadata"_s,
            u"--convert-thumbnails"_s, u"jpg"_s,
            u"--newline"_s,
            u"--progress-template"_s,
            u"download:PROGRESS %(progress.downloaded_bytes)s %(progress.total_bytes)s"_s,
            u"-o"_s, u"%(title)s [%(id)s].%(ext)s"_s,
            u"-P"_s, u"home:" + destDir,
            url.toString(),
        };
        m_proc = new QProcess(this);
        connect(m_proc, &QProcess::readyReadStandardOutput, this, [this] {
            const auto lines = QString::fromUtf8(m_proc->readAllStandardOutput())
                                    .split(u'\n', Qt::SkipEmptyParts);
            for (const auto &line : lines) {
                if (line.startsWith(u"PROGRESS ")) {
                    const auto parts = line.split(u' ');
                    if (parts.size() >= 3) {
                        emit progress(parts[1].toLongLong(), parts[2].toLongLong());
                    }
                }
            }
        });
        connect(m_proc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
            if (err == QProcess::FailedToStart)
                emit failed(u"yt-dlp não encontrado no PATH"_s);
        });
        connect(m_proc, &QProcess::finished, this,
                [this](int exitCode, QProcess::ExitStatus status) {
            if (status == QProcess::NormalExit && exitCode == 0)
                emit finished();
            else
                emit failed(u"yt-dlp saiu com código %1"_s.arg(exitCode));
        });
        m_proc->start(u"yt-dlp"_s, args);
    }

    void cancel() {
        if (m_proc && m_proc->state() != QProcess::NotRunning) {
            m_proc->terminate();          // SIGTERM — dá chance de yt-dlp limpar .part
            if (!m_proc->waitForFinished(3000))
                m_proc->kill();           // SIGKILL se ignorar o terminate
        }
    }

signals:
    void progress(qint64 downloaded, qint64 total);
    void finished();
    void failed(const QString &reason);

private:
    QProcess *m_proc = nullptr;
};
```

**Detecção de ausência**: `isAvailable()` acima cobre o caso "yt-dlp não está
instalado" via `waitForStarted` falhando (o SO não encontra o executável no
PATH → `QProcess::FailedToStart`). Mensagem sugerida pra UI: "yt-dlp não foi
encontrado. Instale com `pipx install yt-dlp` ou pelo gerenciador de pacotes
da sua distro e reinicie o app." — não tentar auto-instalar (fora de escopo,
e mexe com o sistema do usuário sem pedir).

### B.5 — O que a tabela da biblioteca precisa guardar

Colunas mínimas na tabela de faixas (ou uma tabela de extensão
`track_youtube_origin` referenciando a faixa por FK) pra distinguir origem
YouTube de arquivo de alta qualidade:

- `source_url` (TEXT) — a URL original colada pelo usuário
- `source_kind` (TEXT/ENUM) — `"youtube"` vs `"local_file"` (o discriminador
  que a UI usa pra badge/aviso de qualidade)
- `downloaded_at` (DATETIME)
- `source_format_note` (TEXT) — string livre com o que o yt-dlp reportou
  como formato real do stream baixado (ex. `"opus 160kbps"` ou `"m4a
~128kbps"` — vem do `-J`/`--print %(acodec)s %(abr)s` se quiser capturar
  antes do download, ou do nome do arquivo pós-processado); serve só pra
  exibir "qualidade aproximada: X" na UI, nunca pra decisão de reprodução.

Não precisa guardar o `format_id` bruto do yt-dlp (código interno tipo
`"251"`) — é instável entre execuções/vídeos e não tem valor pro usuário
final.
