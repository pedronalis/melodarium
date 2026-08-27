---
slug: download-youtube
feature: melodia
status: em-execucao
depende-de: [colecoes-tags]
decisao-humana: nao
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: download-youtube

**Goal:** Colar um link do YouTube dentro de uma coleção e a faixa aparecer lá — na melhor
qualidade disponível, com capa e nome certos, marcada como o que é: áudio comprimido, que
convive com os arquivos de verdade sem se passar por eles.

**Arquitetura:** O app **não embute** o baixador: chama por `QProcess` o `yt-dlp` que já estiver
instalado. Isso é decisão de spec, não conveniência — "O app publicado não distribui o
baixador; some o risco de takedown e o de quebrar a cada update". Um `YtDlpDownloader` monta a
linha de comando como `QStringList` (nunca string concatenada: o link é entrada não confiável),
lê progresso por `--progress-template` com formato próprio, e entrega o arquivo ao scanner.

**Constraints globais (spec §Requisito duro, verbatim):** "**Limite honesto e documentado:** o
que vier do YouTube é comprimido (Opus, ~160 kbps) e nunca será alta qualidade. As duas
qualidades convivem na biblioteca; o app não finge que são a mesma coisa." A UI **precisa**
marcar a origem.

**Achados verificados nesta máquina (2026-08-27), que o plano leva em conta:**

- Há **dois** `yt-dlp` instalados: o do PATH é o do Homebrew (`2026.01.31`, desatualizado) e o
  do sistema é `/usr/bin/yt-dlp` (`2026.08.19`). O app usa o do PATH — é o que o usuário
  espera — mas mostra a versão encontrada, para o dia em que uma delas quebrar.
- `ffmpeg` existe **nos dois lugares**: `/usr/bin/ffmpeg` (7.1.5) e no Homebrew. `--embed-thumbnail`
  precisa dele; se o `PATH` herdado por um `.desktop` não tiver nenhum, o app passa
  `--ffmpeg-location` explicitamente.
- Os subcampos de `--progress-template` foram confirmados rodando: `downloaded_bytes`,
  `total_bytes`, `eta`, `speed`, `status`, `filename`, `tmpfilename`. **`eta` e `speed` chegam
  como `null`** no começo do download — o parser precisa aguentar isso.

**Research:** `docs/plans/research/2026-08-27-rede-rss-ytdlp.md` Parte B.

## Arquivos

- Criar: `src/ytdlpdownloader.h` · `src/ytdlpdownloader.cpp`
- Criar: `src/AddFromLinkDialog.qml` · `src/DownloadProgressRow.qml` · `src/SourceBadge.qml`
- Criar: `tests/tst_ytdlp.cpp`
- Modificar: `src/database.cpp` (migração 6) · `src/collectionmanager.h/.cpp`
  (ingestão do arquivo baixado) · `src/CollectionsSection.qml` · `src/TrackRow.qml`
  · `src/Main.qml` · `CMakeLists.txt` · `tests/CMakeLists.txt`
- Testar: `tests/tst_ytdlp.cpp`

## Interfaces

- **Consome:** `Database` (`kUiConnection`), `CollectionManager`
  (`collections()`, `addTrackToCollection(int collectionId, int trackId)`,
  `clauseForCollection(int)`, `bindingsForCollection(int)`, sinal `collectionsChanged()`),
  `TagReader` (`read(const QString &absolutePath)`, `computeContentHash(const QString &)`),
  `LibraryScanner` (padrão de inserção de faixa), `Theme`, `Icons`, `MelodiaButton`,
  `IconButton`, `TrackRow`.
- **Produz:**

```cpp
// src/ytdlpdownloader.h — QML_ELEMENT + QML_SINGLETON
class YtDlpDownloader : public QObject {
    // Q_PROPERTY(bool available READ available NOTIFY availabilityChanged)
    // Q_PROPERTY(QString toolVersion READ toolVersion NOTIFY availabilityChanged)
    Q_INVOKABLE void probe();                          // fills available/toolVersion
    Q_INVOKABLE void fetchInfo(const QUrl &url);       // metadata only, no download
    Q_INVOKABLE void download(const QUrl &url, int collectionId);
    Q_INVOKABLE void cancel(const QUrl &url);
    Q_INVOKABLE QString downloadDirectory() const;     // AppDataLocation + "/youtube"
    static QStringList buildArguments(const QUrl &url, const QString &destDir,
                                      const QString &ffmpegLocation);
    static bool parseProgressLine(const QString &line, qint64 *downloaded, qint64 *total);
    static QString findFfmpeg();                       // "" when ffmpeg is on PATH already
    // signals:
    //   void availabilityChanged();
    //   void infoReady(const QUrl &url, const QString &title, const QString &channel,
    //                  int durationSeconds, const QString &thumbnailUrl);
    //   void infoFailed(const QUrl &url, const QString &reason);
    //   void progress(const QUrl &url, qint64 downloaded, qint64 total);
    //   void finished(const QUrl &url, int trackId);
    //   void failed(const QUrl &url, const QString &reason);
};
```

`CollectionManager` ganha um método novo:

```cpp
    // Registers an already-downloaded file as a track and puts it in the collection.
    // Returns the track id, or 0 on failure.
    Q_INVOKABLE int ingestDownloadedFile(const QString &path, int collectionId,
                                         const QString &sourceUrl, const QString &formatNote);
```

Componentes QML: `AddFromLinkDialog { collectionId; signal accepted(url) }`,
`DownloadProgressRow { url; title; received; total; signal cancelRequested }`,
`SourceBadge { kind }` — `kind` é `"youtube"` ou `"local_file"`.

## Tasks

### Task 1: Migração 6 — a marca de origem

- [x] Acrescentar ao vetor `migrations()` em `src/database.cpp`, como sexta entrada:

```cpp
        QStringLiteral(R"SQL(
ALTER TABLE tracks ADD COLUMN source_kind TEXT
    CHECK(source_kind IN ('local_file','youtube')) DEFAULT 'local_file';
ALTER TABLE tracks ADD COLUMN source_url TEXT;
ALTER TABLE tracks ADD COLUMN source_format_note TEXT;
ALTER TABLE tracks ADD COLUMN downloaded_at INTEGER;
CREATE INDEX idx_tracks_source ON tracks(source_kind);
)SQL"),
```

- [x] Acrescentar `t.source_kind` e `t.source_format_note` à lista de colunas do `kSelect` em
      `src/tracklistmodel.cpp`, mais os papéis `SourceKindRole` e `SourceNoteRole` no enum
      `Roles`, no `data()` e no `roleNames()` (`"sourceKind"` e `"sourceNote"`).
- [x] verificação mecânica da task:
      `QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia; sqlite3 ~/.local/share/melodia/melodia.db "PRAGMA user_version; SELECT COUNT(*) FROM pragma_table_info('tracks') WHERE name='source_kind';"`
      → `6` e `1`
- [x] commit:

```bash
git add src/database.cpp src/tracklistmodel.h src/tracklistmodel.cpp
git commit -m "feat(download): record track origin as schema migration 6"
```

### Task 2: YtDlpDownloader — montar o comando e ler o progresso

As duas funções estáticas (`buildArguments` e `parseProgressLine`) são puras de propósito:
são elas que os testes cobrem sem tocar a rede.

- [ ] Criar `src/ytdlpdownloader.h` conforme a assinatura da seção Interfaces, com os membros
      privados `bool m_available`, `QString m_toolVersion`, `QHash<QString, QProcess *> m_jobs`,
      `QHash<QString, int> m_collectionForUrl`.
- [ ] Criar `src/ytdlpdownloader.cpp`:

```cpp
#include "ytdlpdownloader.h"

#include "collectionmanager.h"

#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

QString YtDlpDownloader::findFfmpeg()
{
    // yt-dlp looks for ffmpeg on PATH. When the app is launched from a .desktop file the
    // inherited PATH can be narrower than the user's shell, so we resolve it ourselves and
    // pass --ffmpeg-location only when we had to look it up.
    if (!QStandardPaths::findExecutable(QStringLiteral("ffmpeg")).isEmpty())
        return {};
    const QStringList extra = {QStringLiteral("/usr/bin"),
                               QStringLiteral("/usr/local/bin"),
                               QStringLiteral("/home/linuxbrew/.linuxbrew/bin")};
    const QString found = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"), extra);
    return found.isEmpty() ? QString() : QFileInfo(found).absolutePath();
}

QStringList YtDlpDownloader::buildArguments(const QUrl &url, const QString &destDir,
                                            const QString &ffmpegLocation)
{
    QStringList args;

    // bestaudio/best, not bestaudio alone: some videos expose no isolated audio stream, and
    // the fallback keeps those from failing with "requested format not available".
    args << QStringLiteral("-f") << QStringLiteral("bestaudio/best");

    // --audio-format best means "do not re-encode": the YouTube audio is already lossy and
    // transcoding it would only lose more.
    args << QStringLiteral("--extract-audio") << QStringLiteral("--audio-format")
         << QStringLiteral("best");

    // Thumbnails come as webp; convert to jpg so tag readers and players actually show them.
    args << QStringLiteral("--embed-thumbnail") << QStringLiteral("--convert-thumbnails")
         << QStringLiteral("jpg") << QStringLiteral("--embed-metadata");

    args << QStringLiteral("--newline");
    // Fixed, self-defined progress format: parsing the human-readable bar with a regex breaks
    // across versions and locales.
    args << QStringLiteral("--progress-template")
         << QStringLiteral("download:MELODIA_PROGRESS %(progress.downloaded_bytes)s "
                           "%(progress.total_bytes)s");
    args << QStringLiteral("--no-playlist");
    args << QStringLiteral("-o") << QStringLiteral("%(title)s [%(id)s].%(ext)s");
    args << QStringLiteral("-P") << destDir;

    if (!ffmpegLocation.isEmpty())
        args << QStringLiteral("--ffmpeg-location") << ffmpegLocation;

    // The URL is the last argument and travels as its own list element: QProcess execs
    // directly with no shell, so quotes or semicolons in it cannot become commands.
    args << url.toString();
    return args;
}

bool YtDlpDownloader::parseProgressLine(const QString &line, qint64 *downloaded, qint64 *total)
{
    if (!line.startsWith(QStringLiteral("MELODIA_PROGRESS ")))
        return false;

    const QStringList parts = line.trimmed().split(QLatin1Char(' '), Qt::SkipEmptyParts);
    if (parts.size() < 3)
        return false;

    bool okDownloaded = false;
    const qint64 got = parts.at(1).toLongLong(&okDownloaded);
    if (!okDownloaded)
        return false;

    // total_bytes is "NA" when the server does not declare a size, and eta/speed arrive as
    // "None" on the first ticks. Unknown total becomes -1, never a parse failure.
    bool okTotal = false;
    const qint64 size = parts.at(2).toLongLong(&okTotal);

    if (downloaded)
        *downloaded = got;
    if (total)
        *total = okTotal ? size : -1;
    return true;
}

void YtDlpDownloader::probe()
{
    QProcess probe;
    probe.start(QStringLiteral("yt-dlp"), {QStringLiteral("--version")});
    if (!probe.waitForStarted(2000)) {
        m_available = false; // QProcess::FailedToStart: not on PATH
        m_toolVersion.clear();
        emit availabilityChanged();
        return;
    }
    probe.waitForFinished(5000);
    m_available = probe.exitStatus() == QProcess::NormalExit && probe.exitCode() == 0;
    m_toolVersion = QString::fromUtf8(probe.readAllStandardOutput()).trimmed();
    emit availabilityChanged();
}

QString YtDlpDownloader::downloadDirectory() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QStringLiteral("/youtube");
}

void YtDlpDownloader::fetchInfo(const QUrl &url)
{
    // -J implies --simulate, so nothing is downloaded — but it IS a real network request,
    // so the UI must show a waiting state before enabling the confirm button.
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this,
            [this, proc, url](int exitCode, QProcess::ExitStatus status) {
                proc->deleteLater();
                if (status != QProcess::NormalExit || exitCode != 0) {
                    emit infoFailed(url, QString::fromUtf8(proc->readAllStandardError())
                                             .trimmed()
                                             .section(QLatin1Char('\n'), -1));
                    return;
                }
                const QJsonObject obj =
                    QJsonDocument::fromJson(proc->readAllStandardOutput()).object();
                emit infoReady(url, obj.value(QStringLiteral("title")).toString(),
                               obj.value(QStringLiteral("channel")).toString(),
                               obj.value(QStringLiteral("duration")).toInt(),
                               obj.value(QStringLiteral("thumbnail")).toString());
            });
    proc->start(QStringLiteral("yt-dlp"), {QStringLiteral("-J"), url.toString()});
}

void YtDlpDownloader::download(const QUrl &url, int collectionId)
{
    const QString key = url.toString();
    if (m_jobs.contains(key))
        return; // already downloading this exact link

    const QString destDir = downloadDirectory();
    QDir().mkpath(destDir);

    auto *proc = new QProcess(this);
    m_jobs.insert(key, proc);
    m_collectionForUrl.insert(key, collectionId);

    connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc, url]() {
        const QStringList lines = QString::fromUtf8(proc->readAllStandardOutput())
                                      .split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        for (const QString &line : lines) {
            qint64 got = 0;
            qint64 total = 0;
            if (parseProgressLine(line, &got, &total))
                emit progress(url, got, total);
            else if (line.contains(QStringLiteral("[ExtractAudio] Destination:")))
                m_lastDestination.insert(url.toString(),
                                         line.section(QStringLiteral("Destination: "), 1).trimmed());
        }
    });

    connect(proc, &QProcess::errorOccurred, this, [this, url](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            emit failed(url,
                        tr("yt-dlp não foi encontrado. Instale pelo gerenciador de pacotes da "
                           "sua distro e reabra o melodia."));
        }
    });

    connect(proc, &QProcess::finished, this,
            [this, proc, url, key](int exitCode, QProcess::ExitStatus status) {
                proc->deleteLater();
                m_jobs.remove(key);
                const int collectionId = m_collectionForUrl.take(key);
                const QString destination = m_lastDestination.take(key);

                if (status != QProcess::NormalExit || exitCode != 0) {
                    emit failed(url, tr("o download falhou (código %1)").arg(exitCode));
                    return;
                }
                if (destination.isEmpty() || !QFile::exists(destination)) {
                    emit failed(url, tr("o arquivo baixado não foi encontrado"));
                    return;
                }

                CollectionManager manager;
                const int trackId = manager.ingestDownloadedFile(
                    destination, collectionId, url.toString(), QStringLiteral("YouTube"));
                if (trackId <= 0) {
                    emit failed(url, tr("não consegui registrar a faixa na biblioteca"));
                    return;
                }
                emit finished(url, trackId);
            });

    proc->start(QStringLiteral("yt-dlp"), buildArguments(url, destDir, findFfmpeg()));
}

void YtDlpDownloader::cancel(const QUrl &url)
{
    QProcess *proc = m_jobs.value(url.toString(), nullptr);
    if (!proc)
        return;
    proc->terminate(); // SIGTERM first: gives yt-dlp a chance to clean up its own .part
    if (!proc->waitForFinished(3000))
        proc->kill();
}
```

- [ ] Acrescentar ao header os membros `QHash<QString, QString> m_lastDestination;` e os
      `#include <QFile>` / `#include <QFileInfo>` necessários no `.cpp`.
- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/ytdlpdownloader.h src/ytdlpdownloader.cpp CMakeLists.txt
git commit -m "feat(download): drive external yt-dlp with safe args and parseable progress"
```

### Task 3: Registrar o arquivo baixado como faixa da coleção

- [ ] Acrescentar ao fim de `src/collectionmanager.cpp`:

```cpp
int CollectionManager::ingestDownloadedFile(const QString &path, int collectionId,
                                            const QString &sourceUrl, const QString &formatNote)
{
    const QFileInfo info(path);
    if (!info.exists())
        return 0;

    const TrackRecord rec = TagReader::read(path);
    if (!rec.valid)
        return 0;

    QSqlQuery existing(uiDb());
    existing.prepare(QStringLiteral("SELECT id FROM tracks WHERE path = ?"));
    existing.addBindValue(path);
    int trackId = 0;
    if (existing.exec() && existing.next())
        trackId = existing.value(0).toInt();

    if (trackId == 0) {
        QSqlQuery artist(uiDb());
        artist.prepare(QStringLiteral("INSERT OR IGNORE INTO artists (name) VALUES (?)"));
        artist.addBindValue(rec.artist);
        artist.exec();

        QSqlQuery artistId(uiDb());
        artistId.prepare(QStringLiteral("SELECT id FROM artists WHERE name = ?"));
        artistId.addBindValue(rec.artist);
        const int aid = (artistId.exec() && artistId.next()) ? artistId.value(0).toInt() : 0;

        const qint64 now = QDateTime::currentSecsSinceEpoch();
        QSqlQuery ins(uiDb());
        ins.prepare(QStringLiteral(
            "INSERT INTO tracks (path, mtime, size, content_hash, duration_ms, sample_rate, "
            "channels, bitrate_kbps, codec, title, artist_id, added_at, source_kind, "
            "source_url, source_format_note, downloaded_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'youtube', ?, ?, ?)"));
        ins.addBindValue(path);
        ins.addBindValue(rec.mtime);
        ins.addBindValue(rec.size);
        ins.addBindValue(TagReader::computeContentHash(path));
        ins.addBindValue(rec.durationMs);
        ins.addBindValue(rec.sampleRate > 0 ? QVariant(rec.sampleRate) : QVariant());
        ins.addBindValue(rec.channels > 0 ? QVariant(rec.channels) : QVariant());
        ins.addBindValue(rec.bitrateKbps > 0 ? QVariant(rec.bitrateKbps) : QVariant());
        ins.addBindValue(rec.codec);
        ins.addBindValue(rec.title.isEmpty() ? info.completeBaseName() : rec.title);
        ins.addBindValue(aid > 0 ? QVariant(aid) : QVariant());
        ins.addBindValue(now);
        ins.addBindValue(sourceUrl);
        ins.addBindValue(formatNote);
        ins.addBindValue(now);
        if (!ins.exec())
            return 0;
        trackId = ins.lastInsertId().toInt();

        QSqlQuery stats(uiDb());
        stats.prepare(QStringLiteral(
            "INSERT OR IGNORE INTO track_stats (track_id, first_seen_at) VALUES (?, ?)"));
        stats.addBindValue(trackId);
        stats.addBindValue(now);
        stats.exec();
    }

    if (collectionId > 0)
        addTrackToCollection(collectionId, trackId);
    return trackId;
}
```

- [ ] Acrescentar `#include "tagreader.h"`, `#include <QDateTime>` e `#include <QFileInfo>` ao
      topo de `src/collectionmanager.cpp`, e a declaração do método ao header.
- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/collectionmanager.h src/collectionmanager.cpp
git commit -m "feat(download): register downloaded audio as a tagged collection track"
```

### Task 4: Interface — colar link dentro da coleção

- [ ] Criar `src/SourceBadge.qml` — a marca que cumpre o limite honesto do spec:

```qml
import QtQuick
import Melodia.App

Rectangle {
    id: root

    property string kind: "local_file"

    visible: kind === "youtube"
    implicitWidth: label.implicitWidth + Theme.marginS * 2
    implicitHeight: Theme.marginL
    radius: height / 2
    color: "transparent"
    border.width: Theme.borderS
    border.color: Theme.mOutline

    Text {
        id: label
        anchors.centerIn: parent
        // The spec is explicit: the app must not pretend compressed audio is the same thing
        // as the lossless files next to it.
        text: qsTr("YouTube")
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeXXS
        color: Theme.mOnSurfaceVariant
    }
}
```

- [ ] Criar `src/AddFromLinkDialog.qml`: campo de URL, botão "Buscar informações" chamando
      `YtDlpDownloader.fetchInfo(url)` com estado de espera visível (o `-J` faz requisição de
      rede real, ~1-3 s), exibição de título/canal/duração/miniatura ao voltar `infoReady`, e
      botão "Baixar para esta coleção" chamando `YtDlpDownloader.download(url, collectionId)`.
      Quando `YtDlpDownloader.available` for falso, o diálogo mostra em vez disso a instrução de
      instalar o `yt-dlp` e não deixa prosseguir. Mostrar `YtDlpDownloader.toolVersion` em
      texto pequeno — há duas instalações possíveis nesta máquina e saber qual respondeu
      economiza uma hora de depuração no dia em que uma delas quebrar.
- [ ] Criar `src/DownloadProgressRow.qml`: barra de progresso ligada a
      `YtDlpDownloader.progress`, que mostra "baixando…" sem porcentagem quando `total === -1`
      (o servidor nem sempre declara o tamanho), e botão de cancelar.
- [ ] Em `src/TrackRow.qml`: acrescentar `property string sourceKind: "local_file"` e um
      `SourceBadge { kind: root.sourceKind }` no `RowLayout`, antes da duração. O delegate em
      `src/Main.qml` passa `required property string sourceKind`.
- [ ] Em `src/CollectionsSection.qml`: acrescentar, no cabeçalho de uma coleção aberta, o botão
      "Adicionar link" que abre o `AddFromLinkDialog` com aquele `collectionId`.
- [ ] Em `src/Main.qml`: chamar `YtDlpDownloader.probe()` no `Component.onCompleted` e recarregar
      a lista da coleção no sinal `finished`.
- [ ] Acrescentar os três `.qml` ao `QML_FILES`.
- [ ] verificação mecânica da task:
      `cmake --build build && QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec "is not a type|ReferenceError"`
      → `0`
- [ ] commit:

```bash
git add src/SourceBadge.qml src/AddFromLinkDialog.qml src/DownloadProgressRow.qml src/TrackRow.qml src/CollectionsSection.qml src/Main.qml CMakeLists.txt
git commit -m "feat(download): paste-a-link flow inside a collection with origin badge"
```

### Task 5: Testes — argumentos, progresso e ingestão, sem tocar a rede

- [ ] Acrescentar a `tests/CMakeLists.txt` o alvo `tst_ytdlp` (fontes de `tst_collections` mais
      `../src/ytdlpdownloader.*`), com `add_test` e `QT_QPA_PLATFORM=offscreen`.
- [ ] Criar `tests/tst_ytdlp.cpp`:

```cpp
#include <QtTest/QtTest>
#include <QProcess>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "collectionmanager.h"
#include "database.h"
#include "ytdlpdownloader.h"

class TstYtDlp : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;

    int scalar(const QString &sql)
    {
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        QSqlQuery q(db);
        return (q.exec(sql) && q.next()) ? q.value(0).toInt() : -1;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QVERIFY(Database::openConnection(QLatin1String(Database::kUiConnection),
                                         m_dir.filePath(QStringLiteral("t.db"))));
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        Database::applyPragmas(db);
        QVERIFY(Database::migrate(db));
    }

    void schemaIsAtVersionSix() { QCOMPARE(scalar(QStringLiteral("PRAGMA user_version")), 6); }

    void argumentsNeverConcatenateTheUrl()
    {
        const QUrl url(QStringLiteral("https://youtu.be/abc; rm -rf /"));
        const QStringList args = YtDlpDownloader::buildArguments(
            url, QStringLiteral("/tmp/out"), QString());

        // The whole URL must be exactly one element: QProcess execs with no shell, so even a
        // hostile link cannot become a second command.
        QCOMPARE(args.last(), url.toString());
        QCOMPARE(args.count(url.toString()), 1);
        for (const QString &a : args)
            QVERIFY2(!a.contains(QStringLiteral("rm -rf")) || a == url.toString(),
                     "user input leaked into another argument");
    }

    void argumentsKeepTheQualityContract()
    {
        const QStringList args = YtDlpDownloader::buildArguments(
            QUrl(QStringLiteral("https://youtu.be/x")), QStringLiteral("/tmp/out"), QString());

        QVERIFY(args.contains(QStringLiteral("bestaudio/best")));
        // "best" means do not re-encode. A fixed codec here would degrade already-lossy audio.
        const int formatIndex = args.indexOf(QStringLiteral("--audio-format"));
        QVERIFY(formatIndex >= 0);
        QCOMPARE(args.at(formatIndex + 1), QStringLiteral("best"));
        QVERIFY(!args.contains(QStringLiteral("mp3")));
        QVERIFY(args.contains(QStringLiteral("--embed-thumbnail")));
        QVERIFY(args.contains(QStringLiteral("--no-playlist")));
    }

    void ffmpegLocationOnlyWhenItWasLookedUp()
    {
        const QStringList without = YtDlpDownloader::buildArguments(
            QUrl(QStringLiteral("https://youtu.be/x")), QStringLiteral("/tmp"), QString());
        QVERIFY(!without.contains(QStringLiteral("--ffmpeg-location")));

        const QStringList with = YtDlpDownloader::buildArguments(
            QUrl(QStringLiteral("https://youtu.be/x")), QStringLiteral("/tmp"),
            QStringLiteral("/usr/bin"));
        const int idx = with.indexOf(QStringLiteral("--ffmpeg-location"));
        QVERIFY(idx >= 0);
        QCOMPARE(with.at(idx + 1), QStringLiteral("/usr/bin"));
    }

    void progressLineParsesRealOutput()
    {
        qint64 got = 0;
        qint64 total = 0;
        QVERIFY(YtDlpDownloader::parseProgressLine(
            QStringLiteral("MELODIA_PROGRESS 4302011 8588123"), &got, &total));
        QCOMPARE(got, 4302011);
        QCOMPARE(total, 8588123);
    }

    void unknownTotalBecomesMinusOneNotAFailure()
    {
        qint64 got = 0;
        qint64 total = 0;
        // yt-dlp emits "NA" when the server declares no size.
        QVERIFY(YtDlpDownloader::parseProgressLine(
            QStringLiteral("MELODIA_PROGRESS 1024 NA"), &got, &total));
        QCOMPARE(got, 1024);
        QCOMPARE(total, -1);
    }

    void unrelatedOutputIsIgnored()
    {
        qint64 got = 0;
        qint64 total = 0;
        QVERIFY(!YtDlpDownloader::parseProgressLine(
            QStringLiteral("[youtube] Extracting URL: https://..."), &got, &total));
        QVERIFY(!YtDlpDownloader::parseProgressLine(QString(), &got, &total));
        QVERIFY(!YtDlpDownloader::parseProgressLine(QStringLiteral("MELODIA_PROGRESS"), &got, &total));
    }

    void ingestedFileIsMarkedAsYouTubeAndJoinsTheCollection()
    {
        // Build a real tagged file so TagReader has something valid to read.
        const QString path = m_dir.filePath(QStringLiteral("baixado.flac"));
        QProcess ff;
        ff.start(QStringLiteral("ffmpeg"),
                 {QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"),
                  QStringLiteral("error"), QStringLiteral("-f"), QStringLiteral("lavfi"),
                  QStringLiteral("-i"), QStringLiteral("sine=440:d=1"),
                  QStringLiteral("-metadata"), QStringLiteral("title=Do YouTube"),
                  QStringLiteral("-y"), path});
        if (!ff.waitForStarted(3000))
            QSKIP("ffmpeg unavailable");
        ff.waitForFinished(15000);
        QVERIFY(QFile::exists(path));

        CollectionManager cm;
        const int collectionId = cm.createCollection(QStringLiteral("Pra codar"));
        QVERIFY(collectionId > 0);

        const int trackId = cm.ingestDownloadedFile(
            path, collectionId, QStringLiteral("https://youtu.be/abc"), QStringLiteral("YouTube"));
        QVERIFY(trackId > 0);

        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE id = %1 "
                                       "AND source_kind = 'youtube'")
                            .arg(trackId)),
                 1);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM collection_tracks "
                                       "WHERE collection_id = %1 AND track_id = %2")
                            .arg(collectionId)
                            .arg(trackId)),
                 1);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM track_stats WHERE track_id = %1")
                            .arg(trackId)),
                 1);
    }

    void ingestingTheSamePathTwiceDoesNotDuplicate()
    {
        const QString path = m_dir.filePath(QStringLiteral("baixado.flac"));
        if (!QFile::exists(path))
            QSKIP("fixture missing");

        CollectionManager cm;
        const int before = scalar(QStringLiteral("SELECT COUNT(*) FROM tracks"));
        const int trackId = cm.ingestDownloadedFile(path, 0, QStringLiteral("https://youtu.be/abc"),
                                                    QStringLiteral("YouTube"));
        QVERIFY(trackId > 0);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks")), before);
    }

    void missingFileIsRejectedCleanly()
    {
        CollectionManager cm;
        QCOMPARE(cm.ingestDownloadedFile(QStringLiteral("/nao/existe.opus"), 0,
                                         QStringLiteral("https://youtu.be/z"), QString()),
                 0);
    }
};

QTEST_MAIN(TstYtDlp)
#include "tst_ytdlp.moc"
```

- [ ] verificação mecânica da task:
      `cmake --build build && ctest --test-dir build -R tst_ytdlp --output-on-failure`
      → `100% tests passed`
- [ ] commit:

```bash
git add tests/tst_ytdlp.cpp tests/CMakeLists.txt
git commit -m "test(download): argument safety, progress parsing and library ingestion"
```

### Task 6: Registrar o limite de qualidade no README [sem-código]

- [ ] Acrescentar ao `README.md` uma seção "Baixar do YouTube" registrando: que o app **não
      distribui** o `yt-dlp` e chama o que estiver instalado; que o áudio do YouTube é
      comprimido e nunca será alta qualidade, convivendo com os arquivos de verdade sem se
      passar por eles (é o que a marca de origem na interface diz); que `--embed-thumbnail`
      exige `ffmpeg`; e o achado desta máquina — dois `yt-dlp` instalados, o do `PATH` sendo o
      mais antigo, e por isso o app mostra a versão que encontrou.
- [ ] verificação mecânica da task: `grep -c "yt-dlp" README.md` → `2` ou mais
- [ ] commit:

```bash
git add README.md
git commit -m "docs(download): record the external downloader and the quality limit"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `grep -c "bestaudio/best" src/ytdlpdownloader.cpp` → `1`
- `grep -c '"mp3"' src/ytdlpdownloader.cpp` → `0` (reencodar para MP3 degradaria áudio já
  comprimido; este check guarda o requisito de qualidade)
- `grep -rc "yt-dlp" CMakeLists.txt` → `0` (o baixador **não** pode virar dependência de build:
  o app o invoca em runtime, e é isso que o mantém fora do pacote publicado)

## Fora de escopo

- Embutir o `yt-dlp` ou baixá-lo automaticamente — o spec decide o contrário, e mexer no
  sistema do usuário sem pedir não é opção.
- Baixar playlists inteiras (`--no-playlist` é explícito) e baixar de outros sites que o
  `yt-dlp` suporta: o spec fala de YouTube, e cada site novo é uma promessa de manutenção.
- Fila de downloads com prioridade e limite de simultâneos: por ora, um link por vez por URL.
- Buscar por nome dentro do YouTube — o app recebe um link, não é um buscador.
- Atualizar o `yt-dlp` a partir do app.
- Re-baixar em qualidade melhor quando o vídeo mudar: não existe "melhor" no YouTube que
  atenda o requisito de alta resolução, então a promessa seria falsa.
