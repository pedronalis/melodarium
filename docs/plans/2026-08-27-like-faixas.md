---
slug: like-faixas
feature: melodia-capa-manda
status: em-execucao
depende-de: []
decisao-humana: nao
spec: design/Main.dc.html (telas aprovadas em 2026-08-27; não há spec textual)
---

# Plano: like-faixas

**Goal:** Dar à faixa um "curtida" de primeira classe — coluna própria no banco,
consultas para filtrar e contar, e o dado exposto ao QML. Sem nenhuma tela: as
fatias de UI consomem o que esta produz.

**Arquitetura:** `liked_at INTEGER` (epoch em segundos, NULL = não curtida) na tabela
`tracks`, migração 4 no mecanismo versionado já existente. Timestamp em vez de booleano
porque "curtidas recentemente" é ordenação que o produto vai querer e um `BOOLEAN` não
dá de graça. Índice parcial só sobre as curtidas — são poucas contra 1.204 faixas.

**Constraints globais:** Qt 6.10.3, C++, SQLite via QtSql. O `liked_at` NUNCA é escrito
pelo scanner: curtir é ato do usuário, e uma re-varredura não pode apagar isso.

## Arquivos

- Modificar: `src/database.cpp` (migração 4) · `src/librarybrowser.h` · `src/librarybrowser.cpp`
- Modificar: `src/tracklistmodel.h` · `src/tracklistmodel.cpp`
- Modificar: `tests/tst_library.cpp` · `tests/tst_librarybrowser.cpp`
- Criar: nenhum · Testar: `tests/tst_library.cpp` · `tests/tst_librarybrowser.cpp`

## Interfaces

- **Consome:** o mecanismo de migração existente — `bool Database::migrate(QSqlDatabase &db)`
  itera a lista de `migrations()` e grava `PRAGMA user_version`. Acrescentar um elemento à
  lista É a migração; não escreva mecanismo novo.
- **Produz** — as fatias `biblioteca-densa` e `busca-overlay` chamam estas assinaturas verbatim:
  - `Q_INVOKABLE bool LibraryBrowser::toggleLike(int trackId)` — inverte o estado e devolve
    o estado NOVO (`true` = agora curtida). Faixa inexistente devolve `false` sem erro.
  - `Q_INVOKABLE bool LibraryBrowser::isLiked(int trackId)`
  - `Q_INVOKABLE QString LibraryBrowser::clauseForLiked()` — cláusula WHERE completa, no
    mesmo formato das outras (`clauseRecent()` etc.), já com `ORDER BY`.
  - `Q_INVOKABLE int LibraryBrowser::likedCount()`
  - `void LibraryBrowser::likedChanged(int trackId, bool liked)` — sinal, para a lista
    atualizar o coração sem recarregar a consulta inteira.
  - Papel novo no `TrackListModel`: `LikedRole`, nome QML `liked` (bool).

## Tasks

### Task 1: Migração 4 — a coluna e o índice

- [x] Em `src/database.cpp`, acrescentar ao fim da lista `migrations()` (depois do último
      elemento, antes do `};`) o novo script. **Não use `#` em nenhum lugar dentro do
      `R"SQL(...)"`**: no Qt 6.10.3 isso faz o gerador de código produzir arquivo vazio, sem
      erro (`docs/solutions/build-errors/2026-08-27-moc-raw-string-url-vazio.md`).

```cpp
        QStringLiteral(R"SQL(
ALTER TABLE tracks ADD COLUMN liked_at INTEGER;
CREATE INDEX idx_tracks_liked ON tracks(liked_at) WHERE liked_at IS NOT NULL;
)SQL"),
```

- [x] verificação mecânica da task: `cmake --build build && ./build/tests/tst_library` → exit 0
- [x] commit:

```bash
git add src/database.cpp
git commit -m "feat(library): migration 4 adds liked_at to tracks"
```

### Task 2: Teste da migração (roda antes da API existir)

- [ ] Em `tests/tst_library.cpp`, acrescentar ao slot de testes de schema:

```cpp
void TestLibrary::migration4AddsLikedColumn()
{
    QTemporaryDir dir;
    const QString dbPath = dir.filePath(QStringLiteral("m4.db"));
    QVERIFY(Database::openConnection(QStringLiteral("m4"), dbPath));
    QSqlDatabase db = QSqlDatabase::database(QStringLiteral("m4"));
    QVERIFY(Database::migrate(db));

    QSqlQuery v(db);
    QVERIFY(v.exec(QStringLiteral("PRAGMA user_version")));
    QVERIFY(v.next());
    QCOMPARE(v.value(0).toInt(), 4);

    QSqlQuery c(db);
    QVERIFY(c.exec(QStringLiteral("SELECT COUNT(*) FROM pragma_table_info('tracks') "
                                  "WHERE name = 'liked_at'")));
    QVERIFY(c.next());
    QCOMPARE(c.value(0).toInt(), 1);

    QSqlQuery i(db);
    QVERIFY(i.exec(QStringLiteral("SELECT COUNT(*) FROM sqlite_master "
                                  "WHERE type='index' AND name='idx_tracks_liked'")));
    QVERIFY(i.next());
    QCOMPARE(i.value(0).toInt(), 1);
    QSqlDatabase::removeDatabase(QStringLiteral("m4"));
}
```

- [ ] Declarar o slot no bloco `private slots:` da classe de teste:
      `void migration4AddsLikedColumn();`
- [ ] verificação mecânica da task:
      `./build/tests/tst_library -functions | grep -c migration4AddsLikedColumn` → `1`
      e `./build/tests/tst_library` → exit 0
- [ ] commit:

```bash
git add tests/tst_library.cpp
git commit -m "test(library): migration 4 creates the liked column and its index"
```

### Task 3: API de like no LibraryBrowser

- [ ] Em `src/librarybrowser.h`, dentro da classe, acrescentar depois de
      `Q_INVOKABLE QString clauseNeverPlayed();`:

```cpp
    Q_INVOKABLE bool toggleLike(int trackId);
    Q_INVOKABLE bool isLiked(int trackId);
    Q_INVOKABLE QString clauseForLiked();
    Q_INVOKABLE int likedCount();

signals:
    void likedChanged(int trackId, bool liked);

public:
```

- [ ] Em `src/librarybrowser.cpp`, acrescentar ao fim do arquivo (antes de nenhum namespace
      fechado — o `namespace { }` anônimo termina no topo do arquivo):

```cpp
bool LibraryBrowser::toggleLike(int trackId)
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    // Um único UPDATE decide e aplica: ler-depois-escrever abriria janela para dois cliques
    // rápidos gravarem o mesmo estado.
    q.prepare(QStringLiteral(
        "UPDATE tracks SET liked_at = CASE WHEN liked_at IS NULL "
        "THEN CAST(strftime('%s','now') AS INTEGER) ELSE NULL END WHERE id = ?"));
    q.addBindValue(trackId);
    if (!q.exec() || q.numRowsAffected() <= 0)
        return false;

    const bool nowLiked = isLiked(trackId);
    emit likedChanged(trackId, nowLiked);
    return nowLiked;
}

bool LibraryBrowser::isLiked(int trackId)
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT liked_at IS NOT NULL FROM tracks WHERE id = ?"));
    q.addBindValue(trackId);
    if (!q.exec() || !q.next())
        return false;
    return q.value(0).toBool();
}

QString LibraryBrowser::clauseForLiked()
{
    return QStringLiteral("t.removed_at IS NULL AND t.liked_at IS NOT NULL "
                          "ORDER BY t.liked_at DESC");
}

int LibraryBrowser::likedCount()
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("SELECT COUNT(*) FROM tracks "
                               "WHERE removed_at IS NULL AND liked_at IS NOT NULL"))
        || !q.next())
        return 0;
    return q.value(0).toInt();
}
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0 e
      `grep -c "toggleLike" src/librarybrowser.cpp` → `1`
- [ ] commit:

```bash
git add src/librarybrowser.h src/librarybrowser.cpp
git commit -m "feat(library): toggle, query and count liked tracks"
```

### Task 4: O papel `liked` no modelo de lista

- [ ] Em `src/tracklistmodel.h`, acrescentar `bool liked = false;` ao struct `TrackRow`
      (depois de `QString sourceNote;`) e `LikedRole,` ao enum `Roles` (depois de
      `SourceNoteRole,`).
- [ ] Em `src/tracklistmodel.cpp`, acrescentar `t.liked_at IS NOT NULL` ao `kSelect`, como
      última coluna antes do `FROM`:

```cpp
constexpr const char *kSelect =
    "SELECT t.id, t.path, t.title, t.artist_id, t.album_id, t.duration_ms, t.track_no, "
    "t.year, t.codec, t.sample_rate, t.bits_per_sample, "
    "IFNULL(ar.name,''), IFNULL(al.title,''), "
    "IFNULL(t.source_kind,'local_file'), IFNULL(t.source_format_note,''), "
    "t.liked_at IS NOT NULL "
    "FROM tracks t "
    "LEFT JOIN artists ar ON ar.id = t.artist_id "
    "LEFT JOIN albums al ON al.id = t.album_id ";
```

- [ ] No `switch` de `data()`, acrescentar antes do `default:`:

```cpp
    case LikedRole:
        return r.liked;
```

- [ ] Em `roleNames()`, acrescentar `{LikedRole, "liked"},` ao mapa.
- [ ] Em `loadFromQuery()`, onde as colunas são lidas para o `TrackRow`, acrescentar a
      leitura da coluna nova (índice 15, a que foi acrescentada ao `kSelect`):
      `row.liked = q.value(15).toBool();`
- [ ] verificação mecânica da task:
      `cmake --build build && ./build/tests/tst_tracklistmodel` → exit 0
- [ ] commit:

```bash
git add src/tracklistmodel.h src/tracklistmodel.cpp
git commit -m "feat(library): expose liked state as a model role"
```

### Task 5: Teste da API de like

- [ ] Em `tests/tst_librarybrowser.cpp`, acrescentar (a fixture desse arquivo já cria banco
      temporário e faixas; siga o padrão dela para semear):

```cpp
void TestLibraryBrowser::toggleLikeFlipsAndPersists()
{
    LibraryBrowser browser;
    const int id = firstTrackId();          // helper já existente na fixture
    QVERIFY(!browser.isLiked(id));

    QSignalSpy spy(&browser, &LibraryBrowser::likedChanged);
    QCOMPARE(browser.toggleLike(id), true);
    QVERIFY(browser.isLiked(id));
    QCOMPARE(spy.count(), 1);
    QCOMPARE(spy.at(0).at(1).toBool(), true);

    QCOMPARE(browser.toggleLike(id), false);
    QVERIFY(!browser.isLiked(id));
    QCOMPARE(browser.likedCount(), 0);
}

void TestLibraryBrowser::likedClauseOrdersByMostRecent()
{
    LibraryBrowser browser;
    QVERIFY(browser.clauseForLiked().contains(QStringLiteral("liked_at IS NOT NULL")));
    QVERIFY(browser.clauseForLiked().contains(QStringLiteral("ORDER BY t.liked_at DESC")));

    TrackListModel model;
    browser.toggleLike(firstTrackId());
    model.loadFromQuery(browser.clauseForLiked(), {});
    QCOMPARE(model.rowCount(), 1);
    QCOMPARE(model.data(model.index(0), TrackListModel::LikedRole).toBool(), true);
}

void TestLibraryBrowser::toggleLikeOnMissingTrackIsHarmless()
{
    LibraryBrowser browser;
    QCOMPARE(browser.toggleLike(999999), false);
    QCOMPARE(browser.likedCount(), 0);
}
```

- [ ] Declarar os três slots em `private slots:` e garantir `#include <QSignalSpy>` e
      `#include "tracklistmodel.h"` no topo do arquivo de teste.
- [ ] verificação mecânica da task: `./build/tests/tst_librarybrowser` → exit 0 e
      `./build/tests/tst_librarybrowser -functions | grep -c toggleLike` → `2`
- [ ] commit:

```bash
git add tests/tst_librarybrowser.cpp
git commit -m "test(library): like toggles, persists, orders and tolerates missing ids"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `test "$(ctest --test-dir build -N | grep -cE '^  Test +#')" -ge 9` → exit 0
- `grep -q "liked_at" src/database.cpp` → exit 0
- `grep -q "toggleLike" src/librarybrowser.h` → exit 0
- `grep -q "LikedRole" src/tracklistmodel.h` → exit 0

## Fora de escopo

- Qualquer tela: o coração, o filtro "Curtidas" e a contagem são da fatia `biblioteca-densa`.
- Sincronizar curtidas com serviço externo — o spec do produto é explícito em ser local.
- Curtir episódio de podcast: episódio tem "ouvido/não ouvido", que já existe e resolve.
