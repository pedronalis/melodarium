---
slug: scan-biblioteca
feature: melodia
status: aprovado
depende-de: [esqueleto-build]
decisao-humana: nao
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: scan-biblioteca

**Goal:** O app varre uma pasta de música, lê as tags e as propriedades de áudio de cada
arquivo, extrai capas, e guarda tudo num banco SQLite — sem travar a interface e sem perder
estatísticas quando o usuário renomeia ou move um arquivo.

**Arquitetura:** Três peças. `Database` (singleton C++) é dona do arquivo `.db`, dos pragmas e
das migrações versionadas por `PRAGMA user_version`. `TagReader` é uma função pura sobre
TagLib: caminho entra, struct sai, sem tocar no banco. `LibraryScanner` é um `QObject` que vive
numa `QThread` própria, com sua própria conexão SQLite (regra dura do Qt: uma `QSqlDatabase`
por thread, nome de conexão próprio) e emite progresso para a UI por sinal.

**Constraints globais:** TagLib **1.13.1**, não 2.x — a API mudou entre as duas e a maior parte
dos exemplos públicos é da 2.x. SQLite 3.53 com FTS5 disponível (verificado). Um arquivo
corrompido no meio de 5000 **nunca** pode interromper o lote.

**Research:** `docs/plans/research/2026-08-27-tags-biblioteca.md` (assinaturas conferidas
contra `/usr/include/taglib/`) e `docs/plans/research/2026-08-27-qt-ponte.md` §5 (threads).

## Arquivos

- Criar: `src/database.h` · `src/database.cpp`
- Criar: `src/tagreader.h` · `src/tagreader.cpp`
- Criar: `src/libraryscanner.h` · `src/libraryscanner.cpp`
- Criar: `tests/tst_database.cpp` · `tests/tst_tagreader.cpp` · `tests/tst_scanner.cpp`
- Modificar: `CMakeLists.txt` · `tests/CMakeLists.txt`
- Testar: os três arquivos de teste acima

## Interfaces

- **Consome:** o alvo `appmelodia` e o módulo `Melodia.App` (fatia `esqueleto-build`).
  **Não** consome o `AudioEngine` — esta fatia e a `motor-audio` são independentes e podem ser
  executadas em paralelo.
- **Produz:**

```cpp
// src/tagreader.h — struct trafegada entre scanner, banco e (depois) modelos de lista.
struct TrackRecord {
    QString path;
    qint64  mtime = 0;          // epoch seconds
    qint64  size = 0;           // bytes
    QString contentHash;        // first 64KB + last 64KB + size, hex; empty when unreadable
    int     durationMs = 0;
    int     sampleRate = 0;
    int     bitsPerSample = 0;  // 0 = lossy or unknown -> stored as NULL
    int     channels = 0;
    int     bitrateKbps = 0;
    QString codec;              // "flac" | "mp3" | "aac" | "alac" | "vorbis" | "opus" | "wav"
    QString title;
    QString artist;
    QString albumArtist;
    QString album;
    QString genre;
    int     trackNo = 0;
    int     discNo = 0;
    int     year = 0;
    QString composer;
    double  replayGainTrackDb = 0.0;
    double  replayGainAlbumDb = 0.0;
    bool    hasReplayGain = false;
    QString musicBrainzTrackId;
    bool    valid = false;      // false = file could not be parsed; caller must skip it
};

// src/tagreader.h
namespace TagReader {
    TrackRecord read(const QString &absolutePath);
    // Returns the embedded front cover, or an empty QByteArray. mimeTypeOut receives
    // "image/jpeg" / "image/png" when a cover was found.
    QByteArray readCover(const QString &absolutePath, QString *mimeTypeOut);
    QString computeContentHash(const QString &absolutePath);
}

// src/database.h — singleton C++ (QML_ELEMENT + QML_SINGLETON), URI Melodia.App
class Database : public QObject {
    // Q_PROPERTY(int schemaVersion READ schemaVersion CONSTANT)
    // Q_PROPERTY(QString libraryPath READ libraryPath WRITE setLibraryPath NOTIFY libraryPathChanged)
    static QString defaultDatabasePath();           // QStandardPaths::AppDataLocation + "/melodia.db"
    static bool openConnection(const QString &connectionName, const QString &dbPath);
    static void applyPragmas(QSqlDatabase &db);     // foreign_keys, WAL, synchronous
    static bool migrate(QSqlDatabase &db);          // runs every migration above user_version
    int schemaVersion() const;
    QString libraryPath() const;                    // the folder the user picked
    void setLibraryPath(const QString &path);       // persisted in QSettings
    Q_INVOKABLE void startScan();                   // spawns LibraryScanner on its own thread
    Q_INVOKABLE void cancelScan();
    // signals:
    //   void libraryPathChanged();
    //   void scanProgress(int done, int total);
    //   void scanFinished(int added, int updated, int removed);
    //   void scanFailed(const QString &message);
};

// src/libraryscanner.h
class LibraryScanner : public QObject {
    // public slots:
    void run(const QString &rootPath, const QString &dbPath);
    void cancel();                                  // thread-safe: sets an atomic flag
    // signals:
    //   void progress(int done, int total);
    //   void finished(int added, int updated, int removed);
    //   void failed(const QString &message);
};
```

O nome de conexão SQLite usado pelo scanner é a constante `"melodia-scanner"`; o da thread da
UI é `"melodia-ui"`. Nenhuma outra fatia pode reusar esses nomes.

## Tasks

### Task 1: Ligar TagLib e Qt Sql ao build

- [x] Em `CMakeLists.txt`: acrescentar `Sql` e `Concurrent` aos componentes do
      `find_package(Qt6 REQUIRED COMPONENTS ...)`, e acrescentar após o bloco do mpv:

```cmake
pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)
```

- [x] Acrescentar `src/database.h/.cpp`, `src/tagreader.h/.cpp`, `src/libraryscanner.h/.cpp`
      à lista de `qt_add_executable(appmelodia ...)`; acrescentar apenas
      `src/database.h` e `src/database.cpp` ao bloco `SOURCES` de `qt_add_qml_module`
      (só o `Database` é exposto ao QML; `TagReader` e `LibraryScanner` não são).
- [x] Acrescentar `Qt6::Sql Qt6::Concurrent PkgConfig::TAGLIB` ao `target_link_libraries`.
- [x] verificação mecânica da task: `pkg-config --modversion taglib` → `1.13.1`
- [x] commit:

```bash
git add CMakeLists.txt
git commit -m "build(library): link TagLib and Qt Sql"
```

### Task 2: TagReader — ler tags, propriedades e ReplayGain

`AudioProperties` na base **não tem** `bitsPerSample()`: só as subclasses concretas têm, e é
por `dynamic_cast` que se chega nelas. Opus/Vorbis/MP3 não expõem (são lossy) — fica 0, que
o banco grava como NULL.

- [x] Criar `src/tagreader.h`:

```cpp
#pragma once

#include <QByteArray>
#include <QString>

struct TrackRecord {
    QString path;
    qint64 mtime = 0;
    qint64 size = 0;
    QString contentHash;
    int durationMs = 0;
    int sampleRate = 0;
    int bitsPerSample = 0;
    int channels = 0;
    int bitrateKbps = 0;
    QString codec;
    QString title;
    QString artist;
    QString albumArtist;
    QString album;
    QString genre;
    int trackNo = 0;
    int discNo = 0;
    int year = 0;
    QString composer;
    double replayGainTrackDb = 0.0;
    double replayGainAlbumDb = 0.0;
    bool hasReplayGain = false;
    QString musicBrainzTrackId;
    bool valid = false;
};

namespace TagReader {
QString computeContentHash(const QString &absolutePath);
TrackRecord read(const QString &absolutePath);
QByteArray readCover(const QString &absolutePath, QString *mimeTypeOut);
} // namespace TagReader
```

- [x] Criar `src/tagreader.cpp`:

```cpp
#include "tagreader.h"

#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>

#include <attachedpictureframe.h>
#include <fileref.h>
#include <flacfile.h>
#include <flacproperties.h>
#include <id3v2tag.h>
#include <mp4coverart.h>
#include <mp4file.h>
#include <mp4properties.h>
#include <mp4tag.h>
#include <mpegfile.h>
#include <opusfile.h>
#include <tag.h>
#include <tpropertymap.h>
#include <vorbisfile.h>
#include <wavproperties.h>
#include <xiphcomment.h>

namespace {

QString qs(const TagLib::String &s)
{
    // toCString(true) = UTF-8. Passing false silently mangles accented characters.
    return s.isEmpty() ? QString() : QString::fromUtf8(s.toCString(true));
}

QString firstValue(const TagLib::PropertyMap &pm, const char *key)
{
    const TagLib::StringList values = pm.value(key);
    return values.isEmpty() ? QString() : qs(values.front());
}

// "-7.15 dB" -> -7.15. strtod stops at the first invalid character, so the suffix is ignored.
bool parseGainDb(const QString &raw, double *out)
{
    if (raw.isEmpty())
        return false;
    bool ok = false;
    const double v = raw.trimmed().split(QLatin1Char(' ')).first().toDouble(&ok);
    if (ok)
        *out = v;
    return ok;
}

QString codecFromSuffix(const QString &path)
{
    const QString s = QFileInfo(path).suffix().toLower();
    if (s == QLatin1String("m4a") || s == QLatin1String("mp4"))
        return QStringLiteral("aac");
    if (s == QLatin1String("ogg") || s == QLatin1String("oga"))
        return QStringLiteral("vorbis");
    return s;
}

} // namespace

QString TagReader::computeContentHash(const QString &absolutePath)
{
    QFile f(absolutePath);
    if (!f.open(QIODevice::ReadOnly))
        return {};

    // Sampled hash: first 64KB + last 64KB + size. Hashing whole FLAC files would cost
    // minutes over a 5000-file library; this is enough to pair a moved file with its row.
    constexpr qint64 kChunk = 64 * 1024;
    QCryptographicHash hash(QCryptographicHash::Sha1);
    hash.addData(f.read(kChunk));
    const qint64 total = f.size();
    if (total > 2 * kChunk) {
        f.seek(total - kChunk);
        hash.addData(f.read(kChunk));
    }
    hash.addData(QByteArray::number(total));
    return QString::fromLatin1(hash.result().toHex());
}

TrackRecord TagReader::read(const QString &absolutePath)
{
    TrackRecord r;
    r.path = absolutePath;

    const QFileInfo info(absolutePath);
    if (!info.exists() || !info.isReadable())
        return r; // r.valid stays false

    r.mtime = info.lastModified().toSecsSinceEpoch();
    r.size = info.size();

    const QByteArray pathBytes = absolutePath.toUtf8();
    TagLib::FileRef ref(pathBytes.constData());
    if (ref.isNull() || ref.tag() == nullptr)
        return r; // unsupported or corrupt: caller skips this file, never aborts the batch

    TagLib::Tag *tag = ref.tag();
    r.title = qs(tag->title());
    r.artist = qs(tag->artist());
    r.album = qs(tag->album());
    r.genre = qs(tag->genre());
    r.trackNo = static_cast<int>(tag->track());
    r.year = static_cast<int>(tag->year());

    if (TagLib::AudioProperties *props = ref.audioProperties()) {
        r.durationMs = props->lengthInMilliseconds();
        r.sampleRate = props->sampleRate();
        r.channels = props->channels();
        r.bitrateKbps = props->bitrate();

        // bitsPerSample lives only on concrete subclasses (research §A.2).
        if (auto *p = dynamic_cast<TagLib::FLAC::Properties *>(props))
            r.bitsPerSample = p->bitsPerSample();
        else if (auto *p = dynamic_cast<TagLib::MP4::Properties *>(props))
            r.bitsPerSample = p->bitsPerSample();
        else if (auto *p = dynamic_cast<TagLib::RIFF::WAV::Properties *>(props))
            r.bitsPerSample = p->bitsPerSample();
    }

    if (TagLib::File *file = ref.file()) {
        const TagLib::PropertyMap pm = file->properties();
        r.albumArtist = firstValue(pm, "ALBUMARTIST");
        r.composer = firstValue(pm, "COMPOSER");
        r.musicBrainzTrackId = firstValue(pm, "MUSICBRAINZ_TRACKID");
        r.discNo = firstValue(pm, "DISCNUMBER").split(QLatin1Char('/')).first().toInt();

        double gain = 0.0;
        if (parseGainDb(firstValue(pm, "REPLAYGAIN_TRACK_GAIN"), &gain)) {
            r.replayGainTrackDb = gain;
            r.hasReplayGain = true;
        } else {
            // Opus stores R128_TRACK_GAIN as an integer in Q7.8 units (1/256 dB).
            const QString r128 = firstValue(pm, "R128_TRACK_GAIN");
            bool ok = false;
            const int q78 = r128.toInt(&ok);
            if (ok) {
                r.replayGainTrackDb = q78 / 256.0;
                r.hasReplayGain = true;
            }
        }
        if (parseGainDb(firstValue(pm, "REPLAYGAIN_ALBUM_GAIN"), &gain))
            r.replayGainAlbumDb = gain;
    }

    if (r.albumArtist.isEmpty())
        r.albumArtist = r.artist;
    r.codec = codecFromSuffix(absolutePath);
    r.valid = true;
    return r;
}

QByteArray TagReader::readCover(const QString &absolutePath, QString *mimeTypeOut)
{
    const QByteArray pathBytes = absolutePath.toUtf8();
    const QString suffix = QFileInfo(absolutePath).suffix().toLower();
    if (mimeTypeOut)
        mimeTypeOut->clear();

    auto fromFlacPicture = [mimeTypeOut](const TagLib::List<TagLib::FLAC::Picture *> &pics) -> QByteArray {
        const TagLib::FLAC::Picture *best = nullptr;
        for (auto *pic : pics) {
            if (pic->type() == TagLib::FLAC::Picture::FrontCover) {
                best = pic;
                break;
            }
            if (!best)
                best = pic;
        }
        if (!best)
            return {};
        if (mimeTypeOut)
            *mimeTypeOut = qs(best->mimeType());
        return QByteArray(best->data().data(), static_cast<int>(best->data().size()));
    };

    if (suffix == QLatin1String("mp3")) {
        TagLib::MPEG::File mp3(pathBytes.constData());
        if (mp3.isValid() && mp3.ID3v2Tag()) {
            const TagLib::ID3v2::FrameList &frames = mp3.ID3v2Tag()->frameList("APIC");
            const TagLib::ID3v2::AttachedPictureFrame *best = nullptr;
            for (auto *frame : frames) {
                auto *pic = static_cast<TagLib::ID3v2::AttachedPictureFrame *>(frame);
                if (pic->type() == TagLib::ID3v2::AttachedPictureFrame::FrontCover) {
                    best = pic;
                    break;
                }
                if (!best)
                    best = pic;
            }
            if (best) {
                if (mimeTypeOut)
                    *mimeTypeOut = qs(best->mimeType());
                return QByteArray(best->picture().data(), static_cast<int>(best->picture().size()));
            }
        }
        return {};
    }

    if (suffix == QLatin1String("flac")) {
        TagLib::FLAC::File flac(pathBytes.constData());
        return flac.isValid() ? fromFlacPicture(flac.pictureList()) : QByteArray();
    }

    if (suffix == QLatin1String("m4a") || suffix == QLatin1String("mp4")) {
        TagLib::MP4::File m4a(pathBytes.constData());
        if (m4a.isValid() && m4a.tag() && m4a.tag()->itemMap().contains("covr")) {
            const TagLib::MP4::CoverArtList arts = m4a.tag()->itemMap()["covr"].toCoverArtList();
            if (!arts.isEmpty()) {
                if (mimeTypeOut) {
                    *mimeTypeOut = arts.front().format() == TagLib::MP4::CoverArt::PNG
                                       ? QStringLiteral("image/png")
                                       : QStringLiteral("image/jpeg");
                }
                return QByteArray(arts.front().data().data(),
                                  static_cast<int>(arts.front().data().size()));
            }
        }
        return {};
    }

    if (suffix == QLatin1String("opus")) {
        TagLib::Ogg::Opus::File opus(pathBytes.constData());
        if (opus.isValid() && opus.tag())
            return fromFlacPicture(opus.tag()->pictureList());
        return {};
    }

    if (suffix == QLatin1String("ogg") || suffix == QLatin1String("oga")) {
        TagLib::Ogg::Vorbis::File ogg(pathBytes.constData());
        if (ogg.isValid() && ogg.tag())
            return fromFlacPicture(ogg.tag()->pictureList());
        return {};
    }

    return {};
}
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/tagreader.h src/tagreader.cpp CMakeLists.txt
git commit -m "feat(library): read tags, audio properties, ReplayGain and embedded covers"
```

### Task 3: Database — schema, pragmas e migrações

- [x] Criar `src/database.h`:

```cpp
#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

class QThread;
class LibraryScanner;

class Database : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int schemaVersion READ schemaVersion NOTIFY schemaVersionChanged)
    Q_PROPERTY(QString libraryPath READ libraryPath WRITE setLibraryPath NOTIFY libraryPathChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)

public:
    static constexpr const char *kUiConnection = "melodia-ui";
    static constexpr const char *kScannerConnection = "melodia-scanner";

    explicit Database(QObject *parent = nullptr);
    ~Database() override;

    static QString defaultDatabasePath();
    static bool openConnection(const QString &connectionName, const QString &dbPath);
    static void applyPragmas(QSqlDatabase &db);
    static bool migrate(QSqlDatabase &db);

    int schemaVersion() const;
    QString libraryPath() const { return m_libraryPath; }
    void setLibraryPath(const QString &path);
    bool scanning() const { return m_scanning; }

    Q_INVOKABLE void startScan();
    Q_INVOKABLE void cancelScan();

signals:
    void schemaVersionChanged();
    void libraryPathChanged();
    void scanningChanged();
    void scanProgress(int done, int total);
    void scanFinished(int added, int updated, int removed);
    void scanFailed(const QString &message);

private:
    QString m_dbPath;
    QString m_libraryPath;
    bool m_scanning = false;
    QThread *m_scanThread = nullptr;
    LibraryScanner *m_scanner = nullptr;
};
```

- [x] Criar `src/database.cpp` com o DDL completo. As migrações são um vetor indexado por
      versão: cada fatia futura **acrescenta** uma entrada e nunca edita uma já publicada.

```cpp
#include "database.h"
#include "libraryscanner.h"

#include <QDir>
#include <QSettings>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QThread>
#include <QVariant>

namespace {

// Index = target version. migrations[0] takes the database from version 0 to 1.
// NEVER edit a published entry: a wrong migration is fixed by appending a new one.
const QList<QString> &migrations()
{
    static const QList<QString> list = {
        QStringLiteral(R"SQL(
CREATE TABLE artists (
    id             INTEGER PRIMARY KEY,
    name           TEXT NOT NULL UNIQUE,
    sort_name      TEXT,
    musicbrainz_id TEXT
);
CREATE TABLE albums (
    id              INTEGER PRIMARY KEY,
    title           TEXT NOT NULL,
    album_artist_id INTEGER REFERENCES artists(id) ON DELETE SET NULL,
    year            INTEGER,
    musicbrainz_id  TEXT,
    cover_path      TEXT,
    cover_source    TEXT CHECK(cover_source IN ('embedded','file','none')) DEFAULT 'none',
    UNIQUE(title, album_artist_id)
);
CREATE TABLE genres (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);
CREATE TABLE tracks (
    id                    INTEGER PRIMARY KEY,
    path                  TEXT NOT NULL UNIQUE,
    mtime                 INTEGER NOT NULL,
    size                  INTEGER NOT NULL,
    content_hash          TEXT,
    duration_ms           INTEGER,
    sample_rate           INTEGER,
    bits_per_sample       INTEGER,
    channels              INTEGER,
    bitrate_kbps          INTEGER,
    codec                 TEXT,
    title                 TEXT,
    track_no              INTEGER,
    disc_no               INTEGER,
    year                  INTEGER,
    composer              TEXT,
    artist_id             INTEGER REFERENCES artists(id) ON DELETE SET NULL,
    album_id              INTEGER REFERENCES albums(id) ON DELETE SET NULL,
    genre_id              INTEGER REFERENCES genres(id) ON DELETE SET NULL,
    replaygain_track_gain REAL,
    replaygain_album_gain REAL,
    musicbrainz_track_id  TEXT,
    added_at              INTEGER NOT NULL,
    removed_at            INTEGER
);
CREATE INDEX idx_tracks_album  ON tracks(album_id);
CREATE INDEX idx_tracks_artist ON tracks(artist_id);
CREATE INDEX idx_tracks_genre  ON tracks(genre_id);
CREATE INDEX idx_tracks_hash   ON tracks(content_hash);
CREATE INDEX idx_tracks_active ON tracks(removed_at) WHERE removed_at IS NULL;
CREATE TABLE track_stats (
    track_id       INTEGER PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE,
    play_count     INTEGER NOT NULL DEFAULT 0,
    skip_count     INTEGER NOT NULL DEFAULT 0,
    last_played_at INTEGER,
    first_seen_at  INTEGER NOT NULL
);
)SQL"),
    };
    return list;
}

} // namespace

Database::Database(QObject *parent)
    : QObject(parent)
{
    m_dbPath = defaultDatabasePath();
    QDir().mkpath(QFileInfo(m_dbPath).absolutePath());

    if (openConnection(QLatin1String(kUiConnection), m_dbPath)) {
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(kUiConnection));
        applyPragmas(db);
        migrate(db);
    }

    QSettings settings;
    m_libraryPath = settings.value(QStringLiteral("library/path")).toString();
}

Database::~Database()
{
    cancelScan();
}

QString Database::defaultDatabasePath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return dir + QStringLiteral("/melodia.db");
}

bool Database::openConnection(const QString &connectionName, const QString &dbPath)
{
    QSqlDatabase db = QSqlDatabase::contains(connectionName)
                          ? QSqlDatabase::database(connectionName)
                          : QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
    db.setDatabaseName(dbPath);
    return db.open();
}

void Database::applyPragmas(QSqlDatabase &db)
{
    QSqlQuery q(db);
    q.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
    // WAL lets the scanner write while the UI reads, with no blocking.
    q.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
    q.exec(QStringLiteral("PRAGMA synchronous = NORMAL"));
}

bool Database::migrate(QSqlDatabase &db)
{
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("PRAGMA user_version")) || !q.next())
        return false;
    int current = q.value(0).toInt();

    const QList<QString> &all = migrations();
    for (int v = current; v < all.size(); ++v) {
        db.transaction();
        bool ok = true;
        // Each migration is a script: split on ";" and run statement by statement,
        // because QSqlQuery::exec runs exactly one statement per call.
        const QStringList statements = all.at(v).split(QLatin1Char(';'), Qt::SkipEmptyParts);
        for (const QString &raw : statements) {
            const QString stmt = raw.trimmed();
            if (stmt.isEmpty())
                continue;
            QSqlQuery mq(db);
            if (!mq.exec(stmt)) {
                ok = false;
                break;
            }
        }
        if (!ok) {
            db.rollback();
            return false;
        }
        QSqlQuery vq(db);
        vq.exec(QStringLiteral("PRAGMA user_version = %1").arg(v + 1));
        db.commit();
    }
    return true;
}

int Database::schemaVersion() const
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(kUiConnection));
    QSqlQuery q(db);
    if (q.exec(QStringLiteral("PRAGMA user_version")) && q.next())
        return q.value(0).toInt();
    return -1;
}

void Database::setLibraryPath(const QString &path)
{
    if (m_libraryPath == path)
        return;
    m_libraryPath = path;
    QSettings().setValue(QStringLiteral("library/path"), path);
    emit libraryPathChanged();
}

void Database::startScan()
{
    if (m_scanning || m_libraryPath.isEmpty())
        return;

    m_scanThread = new QThread(this);
    m_scanner = new LibraryScanner;
    m_scanner->moveToThread(m_scanThread);

    const QString root = m_libraryPath;
    const QString dbPath = m_dbPath;
    connect(m_scanThread, &QThread::started, m_scanner, [this, root, dbPath]() {
        m_scanner->run(root, dbPath);
    });
    connect(m_scanner, &LibraryScanner::progress, this, &Database::scanProgress);
    connect(m_scanner, &LibraryScanner::failed, this, &Database::scanFailed);
    connect(m_scanner, &LibraryScanner::finished, this,
            [this](int added, int updated, int removed) {
                m_scanning = false;
                emit scanningChanged();
                emit scanFinished(added, updated, removed);
            });
    connect(m_scanner, &LibraryScanner::finished, m_scanThread, &QThread::quit);
    connect(m_scanThread, &QThread::finished, m_scanner, &QObject::deleteLater);
    connect(m_scanThread, &QThread::finished, this, [this]() {
        m_scanner = nullptr;
        m_scanThread = nullptr;
    });

    m_scanning = true;
    emit scanningChanged();
    m_scanThread->start();
}

void Database::cancelScan()
{
    if (m_scanner)
        m_scanner->cancel();
    if (m_scanThread) {
        m_scanThread->quit();
        m_scanThread->wait(5000);
    }
}
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/database.h src/database.cpp CMakeLists.txt
git commit -m "feat(library): SQLite schema with versioned migrations and WAL"
```

### Task 4: LibraryScanner — varredura incremental numa thread

Regras que esta task tem de honrar, todas verificadas no research:

- Uma `QSqlDatabase` por thread, com nome de conexão próprio. Ao final, a variável local
  precisa **sair de escopo antes** do `removeDatabase`, senão o Qt reclama
  `connection ... is still in use`.
- Arquivo cujo `(mtime, size)` bate com o banco é pulado **sem abrir com TagLib** — é o caso
  de 99% dos arquivos e o que faz a segunda varredura ser rápida.
- Arquivo que sumiu vira `removed_at = now()` (soft delete), nunca `DELETE` imediato: cobre
  disco externo desmontado.
- Arquivo cujo caminho é novo mas cujo `content_hash` bate com um sumido é um **move**: o
  `id` é preservado, e com ele `track_stats` e (na fatia `colecoes-tags`) as coleções.

- [x] Criar `src/libraryscanner.h`:

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <atomic>

class LibraryScanner : public QObject
{
    Q_OBJECT

public:
    explicit LibraryScanner(QObject *parent = nullptr);

    void cancel(); // thread-safe

public slots:
    void run(const QString &rootPath, const QString &dbPath);

signals:
    void progress(int done, int total);
    void finished(int added, int updated, int removed);
    void failed(const QString &message);

private:
    std::atomic_bool m_cancelled{false};
};
```

- [x] Criar `src/libraryscanner.cpp`:

```cpp
#include "libraryscanner.h"

#include "database.h"
#include "tagreader.h"

#include <QDateTime>
#include <QDirIterator>
#include <QFileInfo>
#include <QHash>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariant>

namespace {

const QStringList &audioSuffixes()
{
    static const QStringList list = {
        QStringLiteral("flac"), QStringLiteral("mp3"),  QStringLiteral("m4a"),
        QStringLiteral("mp4"),  QStringLiteral("opus"), QStringLiteral("ogg"),
        QStringLiteral("oga"),  QStringLiteral("wav"),  QStringLiteral("aiff"),
    };
    return list;
}

struct KnownTrack {
    int id = 0;
    qint64 mtime = 0;
    qint64 size = 0;
    QString contentHash;
};

// Resolves a name to a row id in a lookup table, inserting it when new.
int idFor(QSqlDatabase &db, const QString &table, const QString &name)
{
    if (name.isEmpty())
        return 0;
    QSqlQuery sel(db);
    sel.prepare(QStringLiteral("SELECT id FROM %1 WHERE name = ?").arg(table));
    sel.addBindValue(name);
    if (sel.exec() && sel.next())
        return sel.value(0).toInt();

    QSqlQuery ins(db);
    ins.prepare(QStringLiteral("INSERT INTO %1 (name) VALUES (?)").arg(table));
    ins.addBindValue(name);
    return ins.exec() ? ins.lastInsertId().toInt() : 0;
}

int albumIdFor(QSqlDatabase &db, const QString &title, int albumArtistId, int year)
{
    if (title.isEmpty())
        return 0;
    QSqlQuery sel(db);
    sel.prepare(QStringLiteral(
        "SELECT id FROM albums WHERE title = ? AND IFNULL(album_artist_id,0) = ?"));
    sel.addBindValue(title);
    sel.addBindValue(albumArtistId);
    if (sel.exec() && sel.next())
        return sel.value(0).toInt();

    QSqlQuery ins(db);
    ins.prepare(QStringLiteral(
        "INSERT INTO albums (title, album_artist_id, year) VALUES (?, ?, ?)"));
    ins.addBindValue(title);
    ins.addBindValue(albumArtistId > 0 ? QVariant(albumArtistId) : QVariant());
    ins.addBindValue(year > 0 ? QVariant(year) : QVariant());
    return ins.exec() ? ins.lastInsertId().toInt() : 0;
}

void bindTrack(QSqlQuery &q, const TrackRecord &r, int artistId, int albumId, int genreId)
{
    q.addBindValue(r.mtime);
    q.addBindValue(r.size);
    q.addBindValue(r.contentHash);
    q.addBindValue(r.durationMs);
    q.addBindValue(r.sampleRate > 0 ? QVariant(r.sampleRate) : QVariant());
    q.addBindValue(r.bitsPerSample > 0 ? QVariant(r.bitsPerSample) : QVariant());
    q.addBindValue(r.channels > 0 ? QVariant(r.channels) : QVariant());
    q.addBindValue(r.bitrateKbps > 0 ? QVariant(r.bitrateKbps) : QVariant());
    q.addBindValue(r.codec);
    q.addBindValue(r.title);
    q.addBindValue(r.trackNo > 0 ? QVariant(r.trackNo) : QVariant());
    q.addBindValue(r.discNo > 0 ? QVariant(r.discNo) : QVariant());
    q.addBindValue(r.year > 0 ? QVariant(r.year) : QVariant());
    q.addBindValue(r.composer);
    q.addBindValue(artistId > 0 ? QVariant(artistId) : QVariant());
    q.addBindValue(albumId > 0 ? QVariant(albumId) : QVariant());
    q.addBindValue(genreId > 0 ? QVariant(genreId) : QVariant());
    q.addBindValue(r.hasReplayGain ? QVariant(r.replayGainTrackDb) : QVariant());
    q.addBindValue(r.hasReplayGain ? QVariant(r.replayGainAlbumDb) : QVariant());
    q.addBindValue(r.musicBrainzTrackId);
}

} // namespace

LibraryScanner::LibraryScanner(QObject *parent)
    : QObject(parent)
{
}

void LibraryScanner::cancel()
{
    m_cancelled.store(true);
}

void LibraryScanner::run(const QString &rootPath, const QString &dbPath)
{
    int added = 0, updated = 0, removed = 0;

    { // db must leave scope before removeDatabase, or Qt warns "still in use".
        if (!Database::openConnection(QLatin1String(Database::kScannerConnection), dbPath)) {
            emit failed(QStringLiteral("could not open the library database"));
            return;
        }
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kScannerConnection));
        Database::applyPragmas(db);

        // 1. Everything the scanner needs to compare, in one query — no file is read yet.
        QHash<QString, KnownTrack> known;
        {
            QSqlQuery q(db);
            q.exec(QStringLiteral(
                "SELECT id, path, mtime, size, content_hash FROM tracks WHERE removed_at IS NULL"));
            while (q.next()) {
                KnownTrack k;
                k.id = q.value(0).toInt();
                k.mtime = q.value(2).toLongLong();
                k.size = q.value(3).toLongLong();
                k.contentHash = q.value(4).toString();
                known.insert(q.value(1).toString(), k);
            }
        }

        // 2. Enumerate the files on disk.
        QStringList files;
        QDirIterator it(rootPath, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            if (audioSuffixes().contains(QFileInfo(path).suffix().toLower()))
                files.append(path);
        }

        const qint64 now = QDateTime::currentSecsSinceEpoch();
        QSet<QString> seen;
        db.transaction();

        for (int i = 0; i < files.size(); ++i) {
            if (m_cancelled.load()) {
                db.rollback();
                { QSqlDatabase closing = db; closing.close(); }
                QSqlDatabase::removeDatabase(QLatin1String(Database::kScannerConnection));
                emit failed(QStringLiteral("scan cancelled"));
                return;
            }

            const QString path = files.at(i);
            seen.insert(path);
            const QFileInfo info(path);

            const auto knownIt = known.constFind(path);
            if (knownIt != known.constEnd() && knownIt->mtime == info.lastModified().toSecsSinceEpoch()
                && knownIt->size == info.size()) {
                if (i % 50 == 0)
                    emit progress(i, files.size());
                continue; // unchanged: never opened with TagLib
            }

            TrackRecord r = TagReader::read(path);
            if (!r.valid) {
                if (i % 50 == 0)
                    emit progress(i, files.size());
                continue; // corrupt or unsupported: skip this one, never abort the batch
            }
            r.contentHash = TagReader::computeContentHash(path);

            const int artistId = idFor(db, QStringLiteral("artists"), r.artist);
            const int albumArtistId = idFor(db, QStringLiteral("artists"), r.albumArtist);
            const int genreId = idFor(db, QStringLiteral("genres"), r.genre);
            const int albumId = albumIdFor(db, r.album, albumArtistId, r.year);

            if (knownIt != known.constEnd()) {
                QSqlQuery q(db);
                q.prepare(QStringLiteral(
                    "UPDATE tracks SET mtime=?, size=?, content_hash=?, duration_ms=?, "
                    "sample_rate=?, bits_per_sample=?, channels=?, bitrate_kbps=?, codec=?, "
                    "title=?, track_no=?, disc_no=?, year=?, composer=?, artist_id=?, "
                    "album_id=?, genre_id=?, replaygain_track_gain=?, replaygain_album_gain=?, "
                    "musicbrainz_track_id=? WHERE id=?"));
                bindTrack(q, r, artistId, albumId, genreId);
                q.addBindValue(knownIt->id);
                if (q.exec())
                    ++updated;
            } else {
                // A new path whose content hash matches a row missing from this scan is a
                // move, not a new file: reuse the id so play counts and collections survive.
                int movedId = 0;
                if (!r.contentHash.isEmpty()) {
                    QSqlQuery mq(db);
                    mq.prepare(QStringLiteral(
                        "SELECT id, path FROM tracks WHERE content_hash = ? AND size = ?"));
                    mq.addBindValue(r.contentHash);
                    mq.addBindValue(r.size);
                    while (mq.exec() && mq.next()) {
                        const QString oldPath = mq.value(1).toString();
                        if (!seen.contains(oldPath) && !QFileInfo::exists(oldPath)) {
                            movedId = mq.value(0).toInt();
                            break;
                        }
                        break;
                    }
                }

                if (movedId > 0) {
                    QSqlQuery q(db);
                    q.prepare(QStringLiteral(
                        "UPDATE tracks SET path=?, mtime=?, size=?, removed_at=NULL WHERE id=?"));
                    q.addBindValue(path);
                    q.addBindValue(r.mtime);
                    q.addBindValue(r.size);
                    q.addBindValue(movedId);
                    if (q.exec())
                        ++updated;
                } else {
                    QSqlQuery q(db);
                    q.prepare(QStringLiteral(
                        "INSERT INTO tracks (path, mtime, size, content_hash, duration_ms, "
                        "sample_rate, bits_per_sample, channels, bitrate_kbps, codec, title, "
                        "track_no, disc_no, year, composer, artist_id, album_id, genre_id, "
                        "replaygain_track_gain, replaygain_album_gain, musicbrainz_track_id, "
                        "added_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, "
                        "?, ?, ?, ?, ?)"));
                    q.addBindValue(path);
                    bindTrack(q, r, artistId, albumId, genreId);
                    q.addBindValue(now);
                    if (q.exec()) {
                        ++added;
                        QSqlQuery sq(db);
                        sq.prepare(QStringLiteral(
                            "INSERT INTO track_stats (track_id, first_seen_at) VALUES (?, ?)"));
                        sq.addBindValue(q.lastInsertId().toInt());
                        sq.addBindValue(now);
                        sq.exec();
                    }
                }
            }

            if (i % 50 == 0)
                emit progress(i, files.size());
        }

        // 3. Soft-delete what vanished: an unmounted external drive must not wipe the library.
        for (auto it2 = known.constBegin(); it2 != known.constEnd(); ++it2) {
            if (seen.contains(it2.key()))
                continue;
            QSqlQuery q(db);
            q.prepare(QStringLiteral("UPDATE tracks SET removed_at = ? WHERE id = ? AND removed_at IS NULL"));
            q.addBindValue(now);
            q.addBindValue(it2->id);
            if (q.exec() && q.numRowsAffected() > 0)
                ++removed;
        }

        db.commit();
        emit progress(files.size(), files.size());
        db.close();
    }

    QSqlDatabase::removeDatabase(QLatin1String(Database::kScannerConnection));
    emit finished(added, updated, removed);
}
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/libraryscanner.h src/libraryscanner.cpp CMakeLists.txt
git commit -m "feat(library): incremental scanner with soft delete and move detection"
```

### Task 5: Testes de banco, tags e varredura

- [ ] Acrescentar a `tests/CMakeLists.txt`:

```cmake
qt_add_executable(tst_library
    tst_library.cpp
    ../src/database.h ../src/database.cpp
    ../src/tagreader.h ../src/tagreader.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
)
target_include_directories(tst_library PRIVATE ../src)
target_link_libraries(tst_library PRIVATE
    Qt6::Core Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB)

add_test(NAME tst_library COMMAND tst_library)
set_tests_properties(tst_library PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen" TIMEOUT 120)
```

- [ ] Criar `tests/tst_library.cpp`:

```cpp
#include <QtTest/QtTest>
#include <QProcess>
#include <QSignalSpy>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "database.h"
#include "libraryscanner.h"
#include "tagreader.h"

class TstLibrary : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_music;
    QTemporaryDir m_data;

    // Writes a FLAC with real tags using ffmpeg. Empty return = ffmpeg missing.
    static QString makeTagged(const QString &path, const QString &title, const QString &artist,
                              const QString &album)
    {
        QProcess p;
        p.start(QStringLiteral("ffmpeg"),
                {QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"),
                 QStringLiteral("error"), QStringLiteral("-f"), QStringLiteral("lavfi"),
                 QStringLiteral("-i"), QStringLiteral("sine=440:d=1"),
                 QStringLiteral("-metadata"), QStringLiteral("title=%1").arg(title),
                 QStringLiteral("-metadata"), QStringLiteral("artist=%1").arg(artist),
                 QStringLiteral("-metadata"), QStringLiteral("album=%1").arg(album),
                 QStringLiteral("-y"), path});
        if (!p.waitForStarted(3000))
            return {};
        p.waitForFinished(15000);
        return (p.exitCode() == 0 && QFile::exists(path)) ? path : QString();
    }

    QString dbPath() const { return m_data.filePath(QStringLiteral("test.db")); }

    int scalar(const QString &sql)
    {
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("verify"));
        QSqlQuery q(db);
        return (q.exec(sql) && q.next()) ? q.value(0).toInt() : -1;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_music.isValid());
        QVERIFY(m_data.isValid());
        if (makeTagged(m_music.filePath(QStringLiteral("one.flac")),
                       QStringLiteral("Primeira"), QStringLiteral("Artista"),
                       QStringLiteral("Álbum"))
                .isEmpty())
            QSKIP("ffmpeg unavailable: cannot generate tagged fixtures");
        makeTagged(m_music.filePath(QStringLiteral("two.flac")), QStringLiteral("Segunda"),
                   QStringLiteral("Artista"), QStringLiteral("Álbum"));

        QVERIFY(Database::openConnection(QStringLiteral("verify"), dbPath()));
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("verify"));
        Database::applyPragmas(db);
        QVERIFY(Database::migrate(db));
    }

    void migrationSetsUserVersion()
    {
        QCOMPARE(scalar(QStringLiteral("PRAGMA user_version")), 1);
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='tracks'")),
                 1);
    }

    void migrationIsIdempotent()
    {
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("verify"));
        QVERIFY(Database::migrate(db)); // running it again must not fail nor duplicate anything
        QCOMPARE(scalar(QStringLiteral("PRAGMA user_version")), 1);
    }

    void tagReaderReadsUtf8Metadata()
    {
        const TrackRecord r = TagReader::read(m_music.filePath(QStringLiteral("one.flac")));
        QVERIFY(r.valid);
        QCOMPARE(r.title, QStringLiteral("Primeira"));
        QCOMPARE(r.artist, QStringLiteral("Artista"));
        QCOMPARE(r.album, QStringLiteral("Álbum")); // accented text must survive round-trip
        QCOMPARE(r.codec, QStringLiteral("flac"));
        QVERIFY(r.durationMs > 500);
        QVERIFY(r.sampleRate > 0);
        QVERIFY(r.bitsPerSample > 0); // FLAC::Properties exposes it; lossy formats do not
    }

    void tagReaderSkipsGarbageInsteadOfCrashing()
    {
        const QString junk = m_music.filePath(QStringLiteral("junk.mp3"));
        QFile f(junk);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("this is definitely not an mp3");
        f.close();
        const TrackRecord r = TagReader::read(junk);
        QCOMPARE(r.valid, false); // no crash, no exception: caller just skips it
        QFile::remove(junk);
    }

    void scanPopulatesTheLibrary()
    {
        LibraryScanner scanner;
        QSignalSpy done(&scanner, &LibraryScanner::finished);
        scanner.run(m_music.path(), dbPath());
        QCOMPARE(done.count(), 1);
        QCOMPARE(done.at(0).at(0).toInt(), 2); // added
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE removed_at IS NULL")), 2);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM artists")), 1);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM track_stats")), 2);
    }

    void rescanOfUnchangedFilesAddsNothing()
    {
        LibraryScanner scanner;
        QSignalSpy done(&scanner, &LibraryScanner::finished);
        scanner.run(m_music.path(), dbPath());
        QCOMPARE(done.at(0).at(0).toInt(), 0); // added
        QCOMPARE(done.at(0).at(1).toInt(), 0); // updated
        QCOMPARE(done.at(0).at(2).toInt(), 0); // removed
    }

    void movedFileKeepsItsRowAndStats()
    {
        // Give the track a play count, then move the file and rescan.
        QSqlDatabase db = QSqlDatabase::database(QStringLiteral("verify"));
        QSqlQuery up(db);
        QVERIFY(up.exec(QStringLiteral(
            "UPDATE track_stats SET play_count = 7 WHERE track_id = "
            "(SELECT id FROM tracks WHERE path LIKE '%one.flac')")));

        QVERIFY(QDir(m_music.path()).mkpath(QStringLiteral("sub")));
        const QString from = m_music.filePath(QStringLiteral("one.flac"));
        const QString to = m_music.filePath(QStringLiteral("sub/one.flac"));
        QVERIFY(QFile::rename(from, to));

        LibraryScanner scanner;
        QSignalSpy done(&scanner, &LibraryScanner::finished);
        scanner.run(m_music.path(), dbPath());
        QCOMPARE(done.at(0).at(0).toInt(), 0); // nothing was added: it was recognised as a move

        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE removed_at IS NULL")), 2);
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT play_count FROM track_stats WHERE track_id = "
                     "(SELECT id FROM tracks WHERE path LIKE '%sub/one.flac')")),
                 7); // the play count survived the move
    }

    void deletedFileIsSoftDeleted()
    {
        QVERIFY(QFile::remove(m_music.filePath(QStringLiteral("two.flac"))));
        LibraryScanner scanner;
        QSignalSpy done(&scanner, &LibraryScanner::finished);
        scanner.run(m_music.path(), dbPath());
        QCOMPARE(done.at(0).at(2).toInt(), 1); // removed
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE removed_at IS NULL")), 1);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks")), 2); // row still there
    }
};

QTEST_MAIN(TstLibrary)
#include "tst_library.moc"
```

- [ ] verificação mecânica da task:
      `cmake --build build && ctest --test-dir build -R tst_library --output-on-failure`
      → `100% tests passed`
- [ ] commit:

```bash
git add tests/tst_library.cpp tests/CMakeLists.txt
git commit -m "test(library): schema migration, tag reading, move detection and soft delete"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `grep -c "melodia-scanner" src/libraryscanner.cpp src/database.h` → ao menos `1` em cada
- `grep -c "removeDatabase" src/libraryscanner.cpp` → `1`

## Fora de escopo

- Mostrar qualquer coisa na tela — nenhum modelo de lista, nenhuma view. A fatia `tocador-ui`
  é a primeira a exibir o conteúdo do banco.
- Extrair a capa para arquivo de cache e preencher `albums.cover_path`/`cover_source`: nasce
  na fatia `tocador-ui`, junto com o primeiro lugar que de fato mostra uma capa.
- FTS5 e busca — fatia `navegacao-biblioteca` (é ela que tem a caixa de busca).
- Coleções, tags e podcast: cada uma na sua fatia, como migração nova (`user_version` 2, 3...).
- Escrever qualquer coisa nos arquivos do usuário. O spec é explícito: "O app lê; não escreve
  no arquivo do usuário."
- Limpeza periódica dos soft-deleted (`DELETE ... WHERE removed_at < now - 30d`): sem valor
  antes de existir uma biblioteca real que acumule lixo.
