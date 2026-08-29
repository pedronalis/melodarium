---
slug: colecao-dados
feature: colecao-playlist
status: concluido
depende-de: []
decisao-humana: nao
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: colecao-dados

**Goal:** `CollectionManager::collections()` passa a devolver o que uma linha de playlist
precisa mostrar sem abrir a coleção: a duração total e as capas das primeiras faixas.
**Arquitetura:** DUAS consultas, nunca N+1 — uma agregada para id/nome/contagem/duração, e
uma única com `ROW_NUMBER() OVER (PARTITION BY …)` que traz até quatro faixas de CADA
coleção de uma vez. O `CollectionManager` não conhece o `CoverCache`: devolve `path` e
`albumId` crus, e quem monta a URL da capa é o QML, como já faz em toda lista.
**Constraints globais:** SQLite via `QSqlQuery` na conexão de UI (`uiDb()`), padrão de todo
este arquivo. Faixa removida da pasta (`tracks.removed_at IS NOT NULL`) não conta nem para a
duração nem para as capas — a lista mentiria o tamanho da coleção.

## Arquivos

- Modificar: `src/collectionmanager.cpp` · `tests/tst_collections.cpp`
- Criar: nenhum (a assinatura pública em `collectionmanager.h` não muda)
- Testar: `tests/tst_collections.cpp`

## Interfaces

- Consome: schema já existente — `collections(id, name, created_at)`,
  `collection_tracks(collection_id, track_id, position, added_at)`,
  `tracks(id, path, duration_ms, album_id, removed_at)`.
- Produz: `CollectionManager::collections() -> QVariantList`, onde cada `QVariantMap` ganha
  DUAS chaves além das três de hoje (`id`, `name`, `count`):
  - `totalMs` (`qint64`) — soma de `tracks.duration_ms` das faixas vivas da coleção; `0`
    quando a coleção está vazia ou nenhuma faixa tem duração gravada.
  - `covers` (`QVariantList` de `QVariantMap`) — até 4 entradas, na ordem manual da coleção
    (`collection_tracks.position`), cada uma com `path` (`QString`) e `albumId` (`int`, `0`
    quando a faixa não tem álbum). Lista vazia quando a coleção está vazia.
    A fatia `colecao-cartao` consome EXATAMENTE estes dois nomes e a forma de `covers`.

## Tasks

### Task 1: Teste que falha — duração total e capas na lista

- [x] Em `tests/tst_collections.cpp`, acrescentar ao `initTestCase()`, logo depois do laço
      que insere as três faixas, três faixas com duração e álbum (as de hoje não têm
      `duration_ms`, e um teste de soma precisa de números):

```cpp
        for (int i = 4; i <= 6; ++i) {
            exec(QStringLiteral("INSERT INTO tracks (id, path, mtime, size, title, added_at, "
                                "duration_ms, album_id) "
                                "VALUES (%1, '/m/%1.flac', 1, 1, 'F%1', 100, %2, %3)")
                     .arg(i)
                     .arg(i * 1000)
                     .arg(i));
        }
```

- [x] Acrescentar o teste como novo `private slots:` do mesmo arquivo:

```cpp
    void collectionsCarryTotalDurationAndCovers()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Com duração"));
        QVERIFY(id > 0);
        // 4 000 + 5 000 + 6 000 = 15 000 ms, e três capas em ordem de position.
        QVERIFY(cm.addTrackToCollection(id, 4));
        QVERIFY(cm.addTrackToCollection(id, 5));
        QVERIFY(cm.addTrackToCollection(id, 6));

        QVariantMap row;
        for (const QVariant &entry : cm.collections()) {
            if (entry.toMap().value(QStringLiteral("id")).toInt() == id)
                row = entry.toMap();
        }
        QVERIFY(!row.isEmpty());
        QCOMPARE(row.value(QStringLiteral("totalMs")).toLongLong(), 15000LL);

        const QVariantList covers = row.value(QStringLiteral("covers")).toList();
        QCOMPARE(covers.size(), 3);
        QCOMPARE(covers.at(0).toMap().value(QStringLiteral("path")).toString(),
                 QStringLiteral("/m/4.flac"));
        QCOMPARE(covers.at(0).toMap().value(QStringLiteral("albumId")).toInt(), 4);
    }

    // Uma coleção sem faixa nenhuma não pode devolver chave ausente: o QML leria undefined e
    // escreveria "undefined min" na linha.
    void emptyCollectionHasZeroTotalAndNoCovers()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Vazia de propósito"));
        QVERIFY(id > 0);

        QVariantMap row;
        for (const QVariant &entry : cm.collections()) {
            if (entry.toMap().value(QStringLiteral("id")).toInt() == id)
                row = entry.toMap();
        }
        QVERIFY(!row.isEmpty());
        QCOMPARE(row.value(QStringLiteral("totalMs")).toLongLong(), 0LL);
        QCOMPARE(row.value(QStringLiteral("covers")).toList().size(), 0);
    }
```

- [x] Rodar e confirmar que falha pelo motivo certo:
      `ctest --test-dir build -R tst_collections --output-on-failure 2>&1 | grep -c FAIL` → `1`
      (falha em `QCOMPARE(totalMs, 15000)`: a chave não existe e o QVariant vazio vira 0 —
      o teste de coleção vazia passa desde já, e é ele que trava a regressão inversa)
- [x] commit:

```bash
git add tests/tst_collections.cpp
git commit -m "test(collections): total duration and first covers belong to the list row"
```

### Task 2: As duas consultas em collections()

- [x] Em `src/collectionmanager.cpp`, substituir o corpo INTEIRO de
      `QVariantList CollectionManager::collections()` por:

```cpp
QVariantList CollectionManager::collections()
{
    QSqlQuery q(uiDb());
    QVariantList out;
    // Faixa removida da pasta não conta: a linha mostraria um tamanho que a coleção não tem.
    if (!q.exec(QStringLiteral(
            "SELECT c.id, c.name, COUNT(t.id), IFNULL(SUM(t.duration_ms), 0) "
            "FROM collections c "
            "LEFT JOIN collection_tracks ct ON ct.collection_id = c.id "
            "LEFT JOIN tracks t ON t.id = ct.track_id AND t.removed_at IS NULL "
            "GROUP BY c.id ORDER BY c.name COLLATE NOCASE")))
        return out;

    QList<int> ordem;
    QHash<int, QVariantMap> porId;
    while (q.next()) {
        const int id = q.value(0).toInt();
        ordem.append(id);
        porId.insert(id,
                     QVariantMap{{QStringLiteral("id"), id},
                                 {QStringLiteral("name"), q.value(1).toString()},
                                 {QStringLiteral("count"), q.value(2).toInt()},
                                 {QStringLiteral("totalMs"), q.value(3).toLongLong()},
                                 {QStringLiteral("covers"), QVariantList{}}});
    }

    // UMA consulta para as capas de TODAS as coleções. Uma por coleção seria N+1 e a lista
    // é redesenhada a cada mudança de coleção.
    QSqlQuery capas(uiDb());
    if (capas.exec(QStringLiteral(
            "SELECT collection_id, path, album_id FROM ("
            "  SELECT ct.collection_id AS collection_id, t.path AS path, "
            "         IFNULL(t.album_id, 0) AS album_id, "
            "         ROW_NUMBER() OVER (PARTITION BY ct.collection_id ORDER BY ct.position) AS rn "
            "  FROM collection_tracks ct "
            "  JOIN tracks t ON t.id = ct.track_id "
            "  WHERE t.removed_at IS NULL"
            ") WHERE rn <= 4"))) {
        while (capas.next()) {
            const int id = capas.value(0).toInt();
            auto it = porId.find(id);
            if (it == porId.end())
                continue;
            QVariantList lista = it->value(QStringLiteral("covers")).toList();
            lista.append(QVariantMap{{QStringLiteral("path"), capas.value(1).toString()},
                                     {QStringLiteral("albumId"), capas.value(2).toInt()}});
            it->insert(QStringLiteral("covers"), lista);
        }
    }

    for (int id : ordem)
        out.append(porId.value(id));
    return out;
}
```

- [x] Garantir o include de `QHash` no topo do arquivo, se ainda não houver:

```bash
grep -q "#include <QHash>" src/collectionmanager.cpp || \
  sed -i '0,/#include <QSqlQuery>/s//#include <QHash>\n#include <QSqlQuery>/' src/collectionmanager.cpp
grep -c "#include <QHash>" src/collectionmanager.cpp
```

→ `1`

- [x] verificação mecânica da task:
      `cmake --build build 2>&1 | tail -1 && ctest --test-dir build -R tst_collections --output-on-failure 2>&1 | tail -3`
      → `100% tests passed`
- [x] commit:

```bash
git add src/collectionmanager.cpp
git commit -m "feat(collections): list rows carry total duration and the first four covers"
```

## Verificação da fatia (E2E)

- `cmake --build build 2>&1 | tail -1` → `exit 0`
- `ctest --test-dir build --output-on-failure 2>&1 | tail -2` → `100% tests passed, 0 tests failed out of 9`
- A contagem antiga não regrediu:
  `ctest --test-dir build -R tst_collections --output-on-failure 2>&1 | grep -c "Passed"` → `1`
- Nenhuma consulta por linha: `grep -c "PARTITION BY" src/collectionmanager.cpp` → `1`

## Fora de escopo

- Desenhar a linha com as capas — é a fatia `colecao-cartao`, que consome `totalMs` e `covers`.
- Capa da COLEÇÃO escolhida à mão (imagem própria por playlist): não há campo no banco e o
  spec não pede.
- Duração formatada: o QML já tem `formatTotal(ms)` em `LibraryPane.qml`; a fatia
  `colecao-cartao` decide onde ela mora.
