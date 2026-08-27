# Research — TagLib 1.13.1 (leitura de tags) + Schema SQLite da biblioteca

Verificado em `/usr/include/taglib/*.h` (taglib-devel-1.13.1-6.fc43) e `sqlite3 3.53.2`
(FTS5 confirmado: `CREATE VIRTUAL TABLE t USING fts5(x)` funciona em `:memory:`).

## Parte A — TagLib 1.13.1

### A.1 Abrir arquivo, tag básica e AudioProperties

`FileName` no Linux é `typedef const char*` (tiostream.h:57) — passe UTF-8 direto, sem wrapper.

```cpp
#include <fileref.h>
#include <tag.h>

TagLib::FileRef f(path.c_str());          // path: std::string UTF-8
if (f.isNull() || f.tag() == nullptr) {
    // arquivo corrompido / formato não suportado — PULAR, não abortar o scan
    return;
}
TagLib::Tag *tag = f.tag();
TagLib::AudioProperties *props = f.audioProperties(); // pode ser nullptr

TagLib::String title  = tag->title();      // TagLib::String::null se ausente
unsigned int   track  = tag->track();      // 0 se ausente
```

`AudioProperties` (audioproperties.h) é abstrata; a base expõe só:
`length()` (deprecated), `lengthInSeconds()`, `lengthInMilliseconds()`, `bitrate()` (kb/s),
`sampleRate()` (Hz), `channels()`. **Não existe `bitsPerSample()` na base.**

### A.2 Bits por amostra — CRÍTICO para o requisito de alta resolução

`bitsPerSample()` só existe nas subclasses concretas. Como `FileRef::audioProperties()`
devolve o ponteiro polimórfico real (as classes têm destrutor virtual), `dynamic_cast`
funciona sem precisar recriar o File manualmente:

```cpp
#include <flacproperties.h>   // TagLib::FLAC::Properties::bitsPerSample()
#include <mp4properties.h>    // TagLib::MP4::Properties::bitsPerSample()  (AAC/ALAC)
#include <wavproperties.h>    // TagLib::RIFF::WAV::Properties::bitsPerSample()

int bitsPerSample = 0; // 0 = desconhecido/não aplicável (grava NULL no SQLite)
if (auto *p = dynamic_cast<TagLib::FLAC::Properties*>(props))        bitsPerSample = p->bitsPerSample();
else if (auto *p = dynamic_cast<TagLib::MP4::Properties*>(props))    bitsPerSample = p->bitsPerSample();
else if (auto *p = dynamic_cast<TagLib::RIFF::WAV::Properties*>(props)) bitsPerSample = p->bitsPerSample();
```

Verificado por header: `FLAC::Properties`, `MP4::Properties` e `RIFF::WAV::Properties` têm
`bitsPerSample()`. **`Vorbis::Properties` e `Opus::Properties` NÃO têm** (grep no header
confirma ausência) — são codecs lossy, bits/amostra não se aplica; grave `NULL`.
`MPEG::Properties` (MP3) também não expõe — é lossy. `FLAC::Properties` também expõe
`sampleFrames()` (unsigned long long) e `signature()` (MD5 do stream, ByteVector) — úteis
para hash de integridade se quiser evitar reprocessar depois.

### A.3 PropertyMap — ALBUMARTIST, DISCNUMBER, DATE, MusicBrainz, ReplayGain

```cpp
#include <tpropertymap.h>
TagLib::PropertyMap pm = f.file()->properties(); // ou tag->properties() -- mesma API
```

`PropertyMap` é `Map<String, StringList>` (tpropertymap.h) — **todo valor vem como
`StringList`, nunca escalar**. Chaves documentadas no header: `ALBUMARTIST`, `DISCNUMBER`,
`DATE` (não há `YEAR` — use `tag->year()` para o inteiro, ou parseie `DATE`), `COMPOSER`,
`MUSICBRAINZ_TRACKID`, `MUSICBRAINZ_ALBUMID`, `MUSICBRAINZ_ARTISTID`, etc. As tags de
ReplayGain e o `R128_TRACK_GAIN` do Opus **não estão na lista "well-known" do header**, mas
o PropertyMap é passthrough para Vorbis Comments / ID3v2 TXXX / MP4 freeform — chegam com a
chave literal:

```cpp
auto get1 = [&](const char *key) -> TagLib::String {
    auto v = pm.value(key);           // StringList; vazio se ausente
    return v.isEmpty() ? TagLib::String() : v.front();
};
TagLib::String trackGainStr = get1("REPLAYGAIN_TRACK_GAIN"); // ex: "-7.15 dB"
TagLib::String albumGainStr = get1("REPLAYGAIN_ALBUM_GAIN");
TagLib::String r128TrackStr = get1("R128_TRACK_GAIN");       // Opus: inteiro em Q7.8 (1/256 dB)
```

**Armadilha de conversão:** `REPLAYGAIN_*_GAIN` vem como string tipo `"-7.15 dB"` — o sufixo
` dB` (às vezes sem espaço, às vezes maiúsculo/minúsculo) quebra `std::stod` direto. Faça
strip do que não é dígito/sinal/ponto antes de converter (`std::strtod` já para no primeiro
caractere inválido — pode usar direto, ele ignora o `" dB"` sobrando). `R128_TRACK_GAIN` do
Opus é **inteiro** em unidades de 1/256 dB (Q7.8), não string com "dB" — divida por 256.0.
`REPLAYGAIN_*_PEAK` (se existir) é um float linear 0..1+, sem sufixo.

### A.4 Capa embutida — por formato

Estratégia geral: procurar a capa embutida primeiro; se não achar, cair para arquivo na
pasta (`cover.jpg`, `folder.jpg`, `cover.png`, `folder.png`, case-insensitive) e cachear o
caminho ou os bytes na tabela `albums`, não em cada `track` (ver schema).

**MP3 — `MPEG::File` + `ID3v2::AttachedPictureFrame` (APIC):**

```cpp
#include <mpegfile.h>
#include <id3v2tag.h>
#include <attachedpictureframe.h>

TagLib::MPEG::File mp3(path.c_str());
if (mp3.isValid() && mp3.ID3v2Tag()) {
    const TagLib::ID3v2::FrameList &frames = mp3.ID3v2Tag()->frameList("APIC");
    const TagLib::ID3v2::AttachedPictureFrame *best = nullptr;
    for (auto *frame : frames) {
        auto *pic = static_cast<TagLib::ID3v2::AttachedPictureFrame*>(frame);
        if (pic->type() == TagLib::ID3v2::AttachedPictureFrame::FrontCover) { best = pic; break; }
        if (!best) best = pic; // fallback: primeira que aparecer
    }
    if (best) { TagLib::ByteVector data = best->picture(); TagLib::String mime = best->mimeType(); }
}
```

`frameList(const ByteVector&)` (id3v2tag.h:257) já filtra por ID — não precisa varrer
`frameList()` inteira e checar `frameID()`.

**FLAC — `FLAC::File::pictureList()`:**

```cpp
#include <flacfile.h>
TagLib::FLAC::File flac(path.c_str());
if (flac.isValid()) {
    TagLib::List<TagLib::FLAC::Picture*> pics = flac.pictureList();
    for (auto *pic : pics) {
        if (pic->type() == TagLib::FLAC::Picture::FrontCover) { /* pic->data(), pic->mimeType() */ }
    }
}
```

**MP4/M4A/ALAC — `MP4::File`, item `"covr"`:**

```cpp
#include <mp4file.h>
#include <mp4tag.h>
#include <mp4coverart.h>
TagLib::MP4::File m4a(path.c_str());
if (m4a.isValid() && m4a.tag()->itemMap().contains("covr")) {
    TagLib::MP4::CoverArtList arts = m4a.tag()->itemMap()["covr"].toCoverArtList();
    if (!arts.isEmpty()) { TagLib::ByteVector data = arts.front().data();
        // arts.front().format(): CoverArt::JPEG/PNG/BMP/GIF/Unknown
    }
}
```

`MP4::Tag::itemMap()` retorna `const ItemMap&` (`Map<String, Item>`, mp4tag.h) — sem
método `cover()` direto na 1.13.1, o acesso é por essa chave literal `"covr"`.

**Ogg Vorbis / Opus — via `XiphComment::pictureList()` (a 1.13.1 já decodifica o
`METADATA_BLOCK_PICTURE` base64 para você, não precisa decodificar manualmente):**

```cpp
#include <vorbisfile.h>   // ou opusfile.h
#include <xiphcomment.h>
TagLib::Ogg::Vorbis::File ogg(path.c_str()); // ou TagLib::Ogg::Opus::File
if (ogg.isValid()) {
    TagLib::Ogg::XiphComment *xc = ogg.tag(); // Vorbis::File::tag() e Opus::File::tag()
                                               // retornam Ogg::XiphComment* (verificado)
    for (auto *pic : xc->pictureList()) {
        if (pic->type() == TagLib::FLAC::Picture::FrontCover) { /* pic->data() */ }
    }
}
```

`Ogg::XiphComment::pictureList()`/`addPicture()` reaproveitam `TagLib::FLAC::Picture` como
tipo comum de capa entre FLAC e Xiph — útil pra ter UM caminho de código para os dois.

**Fallback de capa em arquivo:** se nenhum formato acima retornar picture, procurar na pasta
do álbum (mesmo diretório do primeiro arquivo escaneado daquele álbum) por, em ordem:
`cover.jpg` > `cover.png` > `folder.jpg` > `folder.png` > `front.jpg`, case-insensitive.
Guardar o caminho resolvido em `albums.cover_path` (nunca por-track) e um flag
`albums.cover_source` (`embedded` | `file` | `none`) para o scanner saber se precisa
reverificar quando o arquivo de capa mudar de mtime.

### A.5 Armadilhas de encoding e robustez

- `TagLib::String` é **sempre UTF-8 internamente na API pública** — use
  `str.toCString(true)` (o `true` = UTF-8; `false` = Latin-1, NUNCA use `false` para texto
  não-ASCII, corrompe acentos) para converter pra `std::string`/`QString::fromUtf8`.
- `FileRef::isNull()` (fileref.h:249) — true se o construtor não reconheceu o tipo de
  arquivo OU o arquivo está corrompido a ponto de falhar o parse. **Sempre checar antes de
  chamar `.tag()`**, senão é ponteiro nulo dereferenciado.
- Mesmo com `!isNull()`, `f.audioProperties()` pode retornar `nullptr` (se você abriu com
  `readAudioProperties=false`, ou parse parcial) — sempre checar antes de usar.
- Scanner de 5000 arquivos: **envolver a leitura de CADA arquivo num try/catch** (TagLib não
  lança exceções por padrão nas operações normais, mas builds com allocator customizado ou
  arquivos absurdamente corrompidos podem estourar `std::bad_alloc` em alocação de buffer
  gigante de tamanho inválido) e logar+pular em vez de deixar o processo morrer no meio do
  lote. Nunca deixar 1 arquivo ruim interromper os outros 4999.

---

## Parte B — Schema SQLite (sqlite 3.53.2, FTS5 confirmado ativo)

### B.1 Pragmas de abertura (toda conexão)

```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA user_version = 1;  -- só na migração inicial, ver B.5
```

### B.2 DDL — núcleo (tracks / albums / artists / genres)

```sql
CREATE TABLE artists (
    id            INTEGER PRIMARY KEY,
    name          TEXT NOT NULL,
    sort_name     TEXT,
    musicbrainz_id TEXT,
    UNIQUE(name)
);

CREATE TABLE albums (
    id             INTEGER PRIMARY KEY,
    title          TEXT NOT NULL,
    album_artist_id INTEGER REFERENCES artists(id) ON DELETE SET NULL,
    year           INTEGER,
    musicbrainz_id TEXT,
    cover_path     TEXT,               -- resolvido: embutido extraído p/ cache ou arquivo na pasta
    cover_source   TEXT CHECK(cover_source IN ('embedded','file','none')) DEFAULT 'none',
    UNIQUE(title, album_artist_id)
);

CREATE TABLE genres (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE tracks (
    id              INTEGER PRIMARY KEY,
    path            TEXT NOT NULL UNIQUE,   -- caminho absoluto, chave de identidade primária
    mtime           INTEGER NOT NULL,        -- epoch seconds, do stat()
    size            INTEGER NOT NULL,        -- bytes, do stat()
    content_hash    TEXT,                    -- ver B.6: hash parcial p/ sobreviver a rename/move
    duration_ms     INTEGER,
    sample_rate     INTEGER,                 -- Hz
    bits_per_sample INTEGER,                 -- NULL = lossy/desconhecido (A.2)
    channels        INTEGER,
    bitrate_kbps    INTEGER,
    codec           TEXT,                    -- 'flac','mp3','aac','alac','vorbis','opus','wav'
    title           TEXT,
    track_no        INTEGER,
    disc_no         INTEGER,
    year            INTEGER,
    composer        TEXT,
    artist_id       INTEGER REFERENCES artists(id) ON DELETE SET NULL,
    album_id        INTEGER REFERENCES albums(id) ON DELETE SET NULL,
    genre_id        INTEGER REFERENCES genres(id) ON DELETE SET NULL,
    replaygain_track_gain REAL,   -- dB, já convertido (sem "dB")
    replaygain_album_gain REAL,
    musicbrainz_track_id  TEXT,
    added_at        INTEGER NOT NULL,        -- epoch seconds, quando entrou na biblioteca
    removed_at      INTEGER                  -- NULL = ativo; setado quando sumiu do disco (B.6)
);
CREATE INDEX idx_tracks_album   ON tracks(album_id);
CREATE INDEX idx_tracks_artist  ON tracks(artist_id);
CREATE INDEX idx_tracks_genre   ON tracks(genre_id);
CREATE INDEX idx_tracks_active  ON tracks(removed_at) WHERE removed_at IS NULL;
CREATE INDEX idx_tracks_hash    ON tracks(content_hash);
```

### B.3 Coleções — N:N com ordem manual (o diferencial do produto)

```sql
CREATE TABLE collections (
    id         INTEGER PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE,
    created_at INTEGER NOT NULL
);

CREATE TABLE collection_tracks (
    collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    track_id      INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    position      INTEGER NOT NULL,   -- ordem manual dentro da coleção; reordenar = UPDATE
    added_at      INTEGER NOT NULL,
    PRIMARY KEY (collection_id, track_id)
);
CREATE INDEX idx_coltracks_order ON collection_tracks(collection_id, position);
```

Reordenar sem renumerar tudo: usar `position` com passo 1000 (`1000, 2000, 3000...`) e
inserir no meio como `(a+b)/2`; renumerar em lote só quando o espaço acabar.

### B.4 Tags livres — N:N preparado para autocomplete por prefixo

```sql
CREATE TABLE tags (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE COLLATE NOCASE
);
CREATE TABLE track_tags (
    track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    tag_id   INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (track_id, tag_id)
);
-- autocomplete por prefixo: índice comum já resolve, LIKE 'prefixo%' usa o índice
-- (só LIKE com % no FINAL usa índice B-tree; % no início não usa — não é o caso aqui)
CREATE INDEX idx_tags_name ON tags(name);
```

### B.5 Estatísticas de escuta

```sql
CREATE TABLE track_stats (
    track_id       INTEGER PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE,
    play_count     INTEGER NOT NULL DEFAULT 0,
    skip_count     INTEGER NOT NULL DEFAULT 0,
    last_played_at INTEGER,
    first_seen_at  INTEGER NOT NULL
);
```

### B.6 Podcast — schema separado (sem coleção, sem tag)

```sql
CREATE TABLE podcast_shows (
    id             INTEGER PRIMARY KEY,
    title          TEXT NOT NULL,
    feed_url       TEXT NOT NULL UNIQUE,
    etag           TEXT,             -- HTTP ETag da última checagem do feed
    last_modified  TEXT,             -- HTTP Last-Modified da última checagem
    last_checked_at INTEGER,
    cover_path     TEXT
);
CREATE TABLE podcast_episodes (
    id             INTEGER PRIMARY KEY,
    show_id        INTEGER NOT NULL REFERENCES podcast_shows(id) ON DELETE CASCADE,
    guid           TEXT NOT NULL,     -- <guid> do RSS, chave de dedupe do episódio
    title          TEXT NOT NULL,
    published_at   INTEGER,
    duration_ms    INTEGER,
    local_path     TEXT,              -- NULL até ser baixado (via yt-dlp externo)
    position_ms    INTEGER NOT NULL DEFAULT 0,  -- posição de escuta
    played         INTEGER NOT NULL DEFAULT 0 CHECK(played IN (0,1)),
    UNIQUE(show_id, guid)
);
CREATE INDEX idx_episodes_show ON podcast_episodes(show_id, published_at DESC);
```

### B.7 FTS5 — busca por título/artista/álbum

FTS5 confirmado disponível na build do Fedora (`CREATE VIRTUAL TABLE ... USING fts5(x)` já
testado OK). Use **`content=`** external-content para não duplicar os dados e manter tudo em
dia via triggers:

```sql
CREATE VIRTUAL TABLE tracks_fts USING fts5(
    title, artist_name, album_title,
    content='',              -- external content "vazio": guardamos só o índice, resolvemos join na leitura
    tokenize='unicode61 remove_diacritics 2'
);

-- Repovoar após inserir/atualizar um track (artist_name/album_title vêm de JOIN no app,
-- ou desnormalize em colunas denormalized_artist/denormalized_album em tracks para simplificar o trigger):
CREATE TRIGGER trg_tracks_ai AFTER INSERT ON tracks BEGIN
    INSERT INTO tracks_fts(rowid, title, artist_name, album_title)
    SELECT new.id, new.title,
           (SELECT name FROM artists WHERE id = new.artist_id),
           (SELECT title FROM albums WHERE id = new.album_id);
END;
CREATE TRIGGER trg_tracks_ad AFTER DELETE ON tracks BEGIN
    INSERT INTO tracks_fts(tracks_fts, rowid, title, artist_name, album_title)
    VALUES('delete', old.id, old.title, NULL, NULL);
END;
CREATE TRIGGER trg_tracks_au AFTER UPDATE ON tracks BEGIN
    INSERT INTO tracks_fts(tracks_fts, rowid, title, artist_name, album_title)
    VALUES('delete', old.id, old.title, NULL, NULL);
    INSERT INTO tracks_fts(rowid, title, artist_name, album_title)
    SELECT new.id, new.title,
           (SELECT name FROM artists WHERE id = new.artist_id),
           (SELECT title FROM albums WHERE id = new.album_id);
END;
```

Busca: `SELECT tracks.* FROM tracks_fts JOIN tracks ON tracks.id = tracks_fts.rowid
WHERE tracks_fts MATCH 'quer*' ORDER BY rank;` — `rank` é coluna implícita do FTS5 (BM25).

Se preferir simplicidade (biblioteca pessoal, não catálogo de streaming): **LIKE com índice
em `tracks(title COLLATE NOCASE)` + `artists(name COLLATE NOCASE)` já resolve bem até a casa
de dezenas de milhares de faixas** para busca por prefixo; FTS5 só compensa a complexidade
extra quando você quer busca por palavra-no-meio-do-título ou ranking por relevância. Como
FTS5 já está confirmado disponível e o custo de manutenção via trigger é baixo, a
recomendação é usar FTS5 desde já — evita migração de busca depois.

### B.8 As 4 listas automáticas — SQL literal

```sql
-- Recentes (adicionados à biblioteca há pouco tempo)
SELECT t.* FROM tracks t WHERE t.removed_at IS NULL
ORDER BY t.added_at DESC LIMIT 50;

-- Mais tocadas
SELECT t.* FROM tracks t JOIN track_stats s ON s.track_id = t.id
WHERE t.removed_at IS NULL AND s.play_count > 0
ORDER BY s.play_count DESC LIMIT 50;

-- Esquecidas (tocadas muito no passado, nada há meses)
-- regra: play_count acima da mediana E last_played_at mais antigo que 90 dias
SELECT t.* FROM tracks t JOIN track_stats s ON s.track_id = t.id
WHERE t.removed_at IS NULL
  AND s.play_count >= 5
  AND s.last_played_at IS NOT NULL
  AND s.last_played_at < strftime('%s','now') - 90*86400
ORDER BY s.play_count DESC, s.last_played_at ASC LIMIT 50;

-- Nunca ouvi
SELECT t.* FROM tracks t JOIN track_stats s ON s.track_id = t.id
WHERE t.removed_at IS NULL AND s.play_count = 0
ORDER BY t.added_at DESC LIMIT 50;
```

O limiar `play_count >= 5` de "Esquecidas" é arbitrário — ajustável por config; documentar
como constante nomeada no código, não number mágico espalhado.

### B.9 Varredura incremental (5000 arquivos sem reler tudo)

**Detecção rápida de "mudou":** comparar `(mtime, size)` do `stat()` contra o que está salvo
em `tracks`. Se ambos batem, **pula o arquivo inteiro sem abrir com TagLib** — é o caso
comum (99% dos arquivos não mudaram entre scans). Só reabre e relê tags quando
`mtime` OU `size` divergem.

```sql
-- 1 query, carrega tudo que o scanner precisa comparar, sem reler arquivo nenhum
SELECT id, path, mtime, size, content_hash FROM tracks WHERE removed_at IS NULL;
```

**Arquivo novo:** path não existe na tabela → INSERT.
**Arquivo alterado:** path existe, mtime/size divergem → UPDATE das colunas de tag/áudio,
mantendo o mesmo `id` (preserva `track_stats` e `collection_tracks`, que são FK em `id`).
**Arquivo sumiu:** estava na tabela, não apareceu nesta varredura do diretório → **não
DELETE imediato.** Marcar `removed_at = now()` (soft delete) e manter por N dias (ex.: 30) —
cobre o caso comum de disco externo/rede temporariamente desmontado. Um job de limpeza
periódico faz `DELETE FROM tracks WHERE removed_at < now() - 30d` de fato.

**Rename ou move (não pode perder `play_count` nem coleção):** como `path` é a chave e o
caminho mudou, o algoritmo acima trataria como "sumiu" + "novo" — perdendo o `id` e tudo que
pendura nele. Regra proposta: manter `content_hash` (hash rápido, NÃO do arquivo inteiro —
custo demais em 5000 FLACs grandes) calculado sobre uma amostra estável: primeiros 64KB +
últimos 64KB + `size` total, hasheados com xxHash64 (ou SHA-1 se preferir lib já disponível,
mas xxHash é ~10x mais rápido e suficiente pra dedupe, não é criptográfico). Quando o
scanner encontra um path novo (não está na tabela) MAS o `content_hash` bate com um `id`
que está em estado "sumiu nesta varredura" (candidato a `removed_at`), trata como **move**:
`UPDATE tracks SET path = novo_path, mtime = ..., removed_at = NULL WHERE id = ...` — em vez
de soft-delete + insert novo. Custo: 1 hash extra (leitura de 128KB) só para os arquivos que
JÁ mudaram de path detectado nesta passada (não para os 99% que não mudaram) — barato.

### B.10 Migrações — `PRAGMA user_version`

```sql
-- No boot do app, antes de qualquer query:
PRAGMA user_version;  -- lê a versão atual (0 = banco novo)
```

```cpp
int current = /* resultado do PRAGMA acima */;
static const std::vector<const char*> migrations = {
    /* v0 -> v1 */ "CREATE TABLE ... /* todo o DDL da Parte B */; PRAGMA user_version = 1;",
    /* v1 -> v2 */ "ALTER TABLE tracks ADD COLUMN lyrics TEXT; PRAGMA user_version = 2;",
    // cada fatia futura acrescenta 1 entrada; nunca edita uma entrada já lançada
};
for (int v = current; v < (int)migrations.size(); ++v) {
    db.exec("BEGIN;");
    db.exec(migrations[v]);
    db.exec("COMMIT;");
}
```

Regra: cada migração é **aditiva e idempotente por índice de versão** (nunca reescreve uma
migração já publicada — se algo errado foi lançado, a correção é uma NOVA migração). Rodar
dentro de transação garante que uma migração parcialmente aplicada não deixa o schema num
estado intermediário se o app crashar no meio.

---

## Armadilhas verificadas (resumo)

1. `AudioProperties` base NÃO tem `bitsPerSample()` — é preciso `dynamic_cast` para
   `FLAC::Properties` / `MP4::Properties` / `RIFF::WAV::Properties`. Opus/Vorbis/MP3 não têm
   (lossy) — grave `NULL`.
2. `PropertyMap` valores são sempre `StringList`, nunca escalar — `.front()` ou iterar.
3. `REPLAYGAIN_*_GAIN` chega como string `"-7.15 dB"`; `R128_TRACK_GAIN` (Opus) chega como
   inteiro Q7.8 (dividir por 256.0) — conversões diferentes, não tratar igual.
4. `String::toCString(false)` corrompe acentos — sempre `toCString(true)` (UTF-8).
5. `FileRef::isNull()` e `audioProperties() == nullptr` são checks **separados e ambos
   necessários** antes de usar o resultado.
6. `MP4::Tag` não tem getter de capa dedicado na 1.13.1 — acesso é via `itemMap()["covr"]`.
7. `Ogg::XiphComment::pictureList()` já decodifica `METADATA_BLOCK_PICTURE` — não implementar
   base64 manual para Vorbis/Opus.
8. Rename/move de arquivo já catalogado perde `id` (e portanto stats/coleção) se tratado
   como sumiço+novo — precisa do pareamento por `content_hash` parcial (B.9).

## Não verificado (risco aberto)

- `taglib_config.h` / flags de build específicas do pacote Fedora (ex.: se APE, MPC, IT,
  S3M, MOD estão habilitados no build oficial) — não testado neste research; se o produto
  precisar desses formatos, confirmar antes de assumir cobertura.
- Comportamento exato do `dynamic_cast` cross-shared-library (TagLib compilado com RTTI
  padrão do gcc 15 — assumido OK por ser mesmo compilador/ABI, mas não houve compilação real
  de teste neste research, só leitura de header).
- Custo real de I/O do hash parcial (128KB) em disco de rede/HD externo para a heurística de
  move — não medido, é estimativa de engenharia.
