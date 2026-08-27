---
slug: colecoes-tags
feature: melodia
status: em-execucao
depende-de: [navegacao-biblioteca]
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: colecoes-tags

**Goal:** O diferencial do produto. O usuário cria coleções por contexto ("Pra codar",
"Madrugada"), joga faixas dentro com **um gesto só**, e a mesma faixa vive em quantas coleções
quiser. Tags livres com autocomplete completam o eixo, sem virar três tags iguais escritas
diferente.

**Arquitetura:** Migração 3 acrescenta `collections`, `collection_tracks` (N:N com ordem
manual), `tags` e `track_tags`. Um `CollectionManager` (singleton C++) é dono de toda escrita;
o QML nunca monta SQL. A ordem dentro da coleção usa passo de 1000 para permitir inserir no
meio sem renumerar tudo.

**Constraints globais (spec §Pra quê e §Fora de escopo, verbatim):** "Coleções por contexto
('Pra codar', 'Madrugada') em vez de só o eixo artista → álbum → faixa"; "**O gesto manual é um
só:** jogar uma faixa numa coleção. Todo o resto o app preenche sozinho". Fica **fora**:
energia/humor/contexto por faixa, e pasta exclusiva — "Coleção múltipla ganhou".

O autocomplete não é enfeite: é o freio que impede "codar"/"programar"/"foco" de virarem três
tags distintas (spec §Decisões, linha "Tags").

**Research:** `docs/plans/research/2026-08-27-tags-biblioteca.md` §B.3 e §B.4.

## Arquivos

- Criar: `src/collectionmanager.h` · `src/collectionmanager.cpp`
- Criar: `src/CollectionsSection.qml` · `src/TagChip.qml` · `src/TagEditor.qml`
  · `src/NewCollectionDialog.qml`
- Criar: `tests/tst_collections.cpp`
- Modificar: `src/database.cpp` (migração 3) · `src/Sidebar.qml` · `src/TrackRow.qml`
  · `src/Main.qml` · `CMakeLists.txt` · `tests/CMakeLists.txt`
- Testar: `tests/tst_collections.cpp`

## Interfaces

- **Consome:** `Database` (`kUiConnection`), `LibraryBrowser`
  (`clauseForAll()`, `bindingsFor(int)`), `TrackListModel`
  (`loadFromQuery(const QString &whereClause, const QVariantList &bindings)`, `allPaths()`,
  `trackAt(int row)`), `AudioEngine` (`loadPlaylist(const QStringList &, int)`), `Theme`,
  `Icons`, `TrackRow`, `SidebarItem`, `IconButton`, `MelodiaButton`, `SearchField`.
- **Produz:**

```cpp
// src/collectionmanager.h — QML_ELEMENT + QML_SINGLETON
class CollectionManager : public QObject {
    static constexpr int kPositionStep = 1000;

    // Collections. Entries: { "id": int, "name": QString, "count": int }
    Q_INVOKABLE QVariantList collections();
    Q_INVOKABLE int createCollection(const QString &name);      // 0 when the name is taken/empty
    Q_INVOKABLE bool renameCollection(int collectionId, const QString &newName);
    Q_INVOKABLE bool deleteCollection(int collectionId);
    Q_INVOKABLE bool addTrackToCollection(int collectionId, int trackId);   // idempotent
    Q_INVOKABLE bool removeTrackFromCollection(int collectionId, int trackId);
    Q_INVOKABLE QVariantList collectionsForTrack(int trackId);
    Q_INVOKABLE QString clauseForCollection(int collectionId);  // for TrackListModel
    Q_INVOKABLE QVariantList bindingsForCollection(int collectionId);
    Q_INVOKABLE bool moveTrackInCollection(int collectionId, int trackId, int newIndex);

    // Free tags. Entries: { "id": int, "name": QString, "count": int }
    Q_INVOKABLE QVariantList allTags();
    Q_INVOKABLE QVariantList tagsForTrack(int trackId);
    Q_INVOKABLE QStringList completeTag(const QString &prefix, int limit = 8);
    Q_INVOKABLE bool addTagToTrack(int trackId, const QString &tagName);
    Q_INVOKABLE bool removeTagFromTrack(int trackId, const QString &tagName);
    Q_INVOKABLE QString clauseForTag(const QString &tagName);
    Q_INVOKABLE QVariantList bindingsForTag(const QString &tagName);

    // signals: void collectionsChanged(); void tagsChanged(int trackId);
};
```

Componentes QML publicados: `CollectionsSection { signal collectionChosen(int id) }`,
`TagChip { text; removable; signal removeRequested }`,
`TagEditor { trackId }`, `NewCollectionDialog { signal created(int id, string name) }`.

`TrackRow` ganha duas propriedades novas, que as fatias anteriores continuam podendo ignorar
(têm default): `property int trackId: 0` e `property bool showCollectButton: false`, mais o
sinal `signal collectRequested()`.

## Tasks

### Task 1: Migração 3 — coleções e tags

- [x] Acrescentar ao vetor `migrations()` em `src/database.cpp`, como terceira entrada:

```cpp
        QStringLiteral(R"SQL(
CREATE TABLE collections (
    id         INTEGER PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE COLLATE NOCASE,
    created_at INTEGER NOT NULL
);
CREATE TABLE collection_tracks (
    collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    track_id      INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    position      INTEGER NOT NULL,
    added_at      INTEGER NOT NULL,
    PRIMARY KEY (collection_id, track_id)
);
CREATE INDEX idx_coltracks_order ON collection_tracks(collection_id, position);
CREATE TABLE tags (
    id   INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE COLLATE NOCASE
);
CREATE TABLE track_tags (
    track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    tag_id   INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (track_id, tag_id)
);
CREATE INDEX idx_tags_name    ON tags(name);
CREATE INDEX idx_tracktags_tag ON track_tags(tag_id);
)SQL"),
```

- [x] verificação mecânica da task:
      `QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia; sqlite3 ~/.local/share/melodia/melodia.db "PRAGMA user_version;"`
      → `3`
- [x] commit:

```bash
git add src/database.cpp
git commit -m "feat(collections): add collections and free tags as schema migration 3"
```

### Task 2: CollectionManager — coleções

`ON DELETE CASCADE` em `collection_tracks` faz a faixa sair de todas as coleções se a linha da
faixa for apagada de verdade — mas o scanner faz soft delete, então a coleção **sobrevive** a
um disco desmontado. Essa combinação é intencional.

- [ ] Criar `src/collectionmanager.h`:

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

class CollectionManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    // Manual order uses gaps of 1000 so inserting between two items is an UPDATE of one row
    // instead of a renumbering of the whole collection.
    static constexpr int kPositionStep = 1000;

    explicit CollectionManager(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList collections();
    Q_INVOKABLE int createCollection(const QString &name);
    Q_INVOKABLE bool renameCollection(int collectionId, const QString &newName);
    Q_INVOKABLE bool deleteCollection(int collectionId);
    Q_INVOKABLE bool addTrackToCollection(int collectionId, int trackId);
    Q_INVOKABLE bool removeTrackFromCollection(int collectionId, int trackId);
    Q_INVOKABLE QVariantList collectionsForTrack(int trackId);
    Q_INVOKABLE QString clauseForCollection(int collectionId);
    Q_INVOKABLE QVariantList bindingsForCollection(int collectionId);
    Q_INVOKABLE bool moveTrackInCollection(int collectionId, int trackId, int newIndex);

    Q_INVOKABLE QVariantList allTags();
    Q_INVOKABLE QVariantList tagsForTrack(int trackId);
    Q_INVOKABLE QStringList completeTag(const QString &prefix, int limit = 8);
    Q_INVOKABLE bool addTagToTrack(int trackId, const QString &tagName);
    Q_INVOKABLE bool removeTagFromTrack(int trackId, const QString &tagName);
    Q_INVOKABLE QString clauseForTag(const QString &tagName);
    Q_INVOKABLE QVariantList bindingsForTag(const QString &tagName);

signals:
    void collectionsChanged();
    void tagsChanged(int trackId);

private:
    static QString normalise(const QString &raw);
};
```

- [ ] Criar `src/collectionmanager.cpp`:

```cpp
#include "collectionmanager.h"

#include "database.h"

#include <QDateTime>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariantMap>

namespace {

QSqlDatabase uiDb()
{
    return QSqlDatabase::database(QLatin1String(Database::kUiConnection));
}

} // namespace

CollectionManager::CollectionManager(QObject *parent)
    : QObject(parent)
{
}

QString CollectionManager::normalise(const QString &raw)
{
    // Collapse inner whitespace and trim. Without this, "pra codar" and "pra  codar" become
    // two different names and the UNIQUE constraint never fires.
    return raw.simplified();
}

QVariantList CollectionManager::collections()
{
    QSqlQuery q(uiDb());
    QVariantList out;
    if (!q.exec(QStringLiteral(
            "SELECT c.id, c.name, COUNT(ct.track_id) "
            "FROM collections c "
            "LEFT JOIN collection_tracks ct ON ct.collection_id = c.id "
            "GROUP BY c.id ORDER BY c.name COLLATE NOCASE")))
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("name"), q.value(1).toString()},
                               {QStringLiteral("count"), q.value(2).toInt()}});
    }
    return out;
}

int CollectionManager::createCollection(const QString &name)
{
    const QString clean = normalise(name);
    if (clean.isEmpty())
        return 0;

    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral("INSERT INTO collections (name, created_at) VALUES (?, ?)"));
    q.addBindValue(clean);
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    if (!q.exec())
        return 0; // UNIQUE COLLATE NOCASE already rejected a duplicate name
    emit collectionsChanged();
    return q.lastInsertId().toInt();
}

bool CollectionManager::renameCollection(int collectionId, const QString &newName)
{
    const QString clean = normalise(newName);
    if (clean.isEmpty() || collectionId <= 0)
        return false;
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral("UPDATE collections SET name = ? WHERE id = ?"));
    q.addBindValue(clean);
    q.addBindValue(collectionId);
    const bool ok = q.exec() && q.numRowsAffected() > 0;
    if (ok)
        emit collectionsChanged();
    return ok;
}

bool CollectionManager::deleteCollection(int collectionId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral("DELETE FROM collections WHERE id = ?"));
    q.addBindValue(collectionId);
    const bool ok = q.exec() && q.numRowsAffected() > 0;
    if (ok)
        emit collectionsChanged(); // collection_tracks rows go with it via ON DELETE CASCADE
    return ok;
}

bool CollectionManager::addTrackToCollection(int collectionId, int trackId)
{
    if (collectionId <= 0 || trackId <= 0)
        return false;

    QSqlQuery pos(uiDb());
    pos.prepare(QStringLiteral(
        "SELECT IFNULL(MAX(position), 0) FROM collection_tracks WHERE collection_id = ?"));
    pos.addBindValue(collectionId);
    int next = kPositionStep;
    if (pos.exec() && pos.next())
        next = pos.value(0).toInt() + kPositionStep;

    QSqlQuery q(uiDb());
    // The one manual gesture in the whole product: adding the same track twice is a no-op,
    // never an error the user has to think about.
    q.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO collection_tracks (collection_id, track_id, position, added_at) "
        "VALUES (?, ?, ?, ?)"));
    q.addBindValue(collectionId);
    q.addBindValue(trackId);
    q.addBindValue(next);
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    if (!q.exec())
        return false;
    emit collectionsChanged();
    return true;
}

bool CollectionManager::removeTrackFromCollection(int collectionId, int trackId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "DELETE FROM collection_tracks WHERE collection_id = ? AND track_id = ?"));
    q.addBindValue(collectionId);
    q.addBindValue(trackId);
    const bool ok = q.exec() && q.numRowsAffected() > 0;
    if (ok)
        emit collectionsChanged();
    return ok;
}

QVariantList CollectionManager::collectionsForTrack(int trackId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT c.id, c.name FROM collections c "
        "JOIN collection_tracks ct ON ct.collection_id = c.id "
        "WHERE ct.track_id = ? ORDER BY c.name COLLATE NOCASE"));
    q.addBindValue(trackId);
    QVariantList out;
    if (!q.exec())
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("name"), q.value(1).toString()}});
    }
    return out;
}

QString CollectionManager::clauseForCollection(int)
{
    // Ordered by the collection's own manual position, not by album/track number.
    return QStringLiteral(
        "t.removed_at IS NULL AND t.id IN (SELECT track_id FROM collection_tracks WHERE collection_id = ?) "
        "ORDER BY (SELECT position FROM collection_tracks ct WHERE ct.track_id = t.id "
        "AND ct.collection_id = ?)");
}

QVariantList CollectionManager::bindingsForCollection(int collectionId)
{
    return QVariantList{collectionId, collectionId}; // the clause binds the id twice
}

bool CollectionManager::moveTrackInCollection(int collectionId, int trackId, int newIndex)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT track_id, position FROM collection_tracks WHERE collection_id = ? ORDER BY position"));
    q.addBindValue(collectionId);
    if (!q.exec())
        return false;

    QList<QPair<int, int>> items;
    while (q.next())
        items.append({q.value(0).toInt(), q.value(1).toInt()});
    if (newIndex < 0 || newIndex >= items.size())
        return false;

    int before = 0;
    int after = 0;
    for (int i = 0; i < items.size(); ++i) {
        if (items.at(i).first == trackId)
            continue;
        if (i < newIndex)
            before = items.at(i).second;
        else if (after == 0)
            after = items.at(i).second;
    }
    // Land halfway between the neighbours; when the gap is exhausted, renumber the whole
    // collection with fresh steps.
    int target = (after > 0) ? (before + after) / 2 : before + kPositionStep;
    if (after > 0 && target <= before) {
        int p = kPositionStep;
        for (const auto &item : items) {
            QSqlQuery r(uiDb());
            r.prepare(QStringLiteral(
                "UPDATE collection_tracks SET position = ? WHERE collection_id = ? AND track_id = ?"));
            r.addBindValue(p);
            r.addBindValue(collectionId);
            r.addBindValue(item.first);
            r.exec();
            p += kPositionStep;
        }
        target = (newIndex + 1) * kPositionStep - kPositionStep / 2;
    }

    QSqlQuery up(uiDb());
    up.prepare(QStringLiteral(
        "UPDATE collection_tracks SET position = ? WHERE collection_id = ? AND track_id = ?"));
    up.addBindValue(target);
    up.addBindValue(collectionId);
    up.addBindValue(trackId);
    const bool ok = up.exec() && up.numRowsAffected() > 0;
    if (ok)
        emit collectionsChanged();
    return ok;
}
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/collectionmanager.h src/collectionmanager.cpp CMakeLists.txt
git commit -m "feat(collections): create, fill and order context collections"
```

### Task 3: Tags livres com autocomplete

`UNIQUE ... COLLATE NOCASE` mais `simplified()` fazem "Codar", "codar" e "codar " serem a mesma
tag. O autocomplete por prefixo usa o índice B-tree (`LIKE 'prefixo%'` — o `%` no fim usa
índice; no começo não usaria).

- [ ] Acrescentar ao fim de `src/collectionmanager.cpp`:

```cpp
QVariantList CollectionManager::allTags()
{
    QSqlQuery q(uiDb());
    QVariantList out;
    if (!q.exec(QStringLiteral(
            "SELECT tg.id, tg.name, COUNT(tt.track_id) "
            "FROM tags tg LEFT JOIN track_tags tt ON tt.tag_id = tg.id "
            "GROUP BY tg.id ORDER BY tg.name COLLATE NOCASE")))
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("name"), q.value(1).toString()},
                               {QStringLiteral("count"), q.value(2).toInt()}});
    }
    return out;
}

QVariantList CollectionManager::tagsForTrack(int trackId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT tg.id, tg.name FROM tags tg JOIN track_tags tt ON tt.tag_id = tg.id "
        "WHERE tt.track_id = ? ORDER BY tg.name COLLATE NOCASE"));
    q.addBindValue(trackId);
    QVariantList out;
    if (!q.exec())
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("name"), q.value(1).toString()}});
    }
    return out;
}

QStringList CollectionManager::completeTag(const QString &prefix, int limit)
{
    const QString clean = normalise(prefix);
    if (clean.isEmpty())
        return {};
    QSqlQuery q(uiDb());
    // Prefix match only: this is the brake that stops "codar"/"programar"/"foco" from
    // becoming three near-identical tags.
    q.prepare(QStringLiteral(
        "SELECT name FROM tags WHERE name LIKE ? ORDER BY name COLLATE NOCASE LIMIT ?"));
    q.addBindValue(clean + QLatin1Char('%'));
    q.addBindValue(limit);
    QStringList out;
    if (!q.exec())
        return out;
    while (q.next())
        out.append(q.value(0).toString());
    return out;
}

bool CollectionManager::addTagToTrack(int trackId, const QString &tagName)
{
    const QString clean = normalise(tagName);
    if (trackId <= 0 || clean.isEmpty())
        return false;

    QSqlQuery ins(uiDb());
    ins.prepare(QStringLiteral("INSERT OR IGNORE INTO tags (name) VALUES (?)"));
    ins.addBindValue(clean);
    ins.exec();

    QSqlQuery sel(uiDb());
    sel.prepare(QStringLiteral("SELECT id FROM tags WHERE name = ?"));
    sel.addBindValue(clean);
    if (!sel.exec() || !sel.next())
        return false;

    QSqlQuery link(uiDb());
    link.prepare(QStringLiteral(
        "INSERT OR IGNORE INTO track_tags (track_id, tag_id) VALUES (?, ?)"));
    link.addBindValue(trackId);
    link.addBindValue(sel.value(0).toInt());
    if (!link.exec())
        return false;
    emit tagsChanged(trackId);
    return true;
}

bool CollectionManager::removeTagFromTrack(int trackId, const QString &tagName)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "DELETE FROM track_tags WHERE track_id = ? "
        "AND tag_id = (SELECT id FROM tags WHERE name = ?)"));
    q.addBindValue(trackId);
    q.addBindValue(normalise(tagName));
    const bool ok = q.exec() && q.numRowsAffected() > 0;
    if (ok) {
        // A tag nobody uses any more is noise in the autocomplete: drop it.
        QSqlQuery gc(uiDb());
        gc.exec(QStringLiteral(
            "DELETE FROM tags WHERE id NOT IN (SELECT tag_id FROM track_tags)"));
        emit tagsChanged(trackId);
    }
    return ok;
}

QString CollectionManager::clauseForTag(const QString &)
{
    return QStringLiteral(
        "t.removed_at IS NULL AND t.id IN (SELECT tt.track_id FROM track_tags tt "
        "JOIN tags tg ON tg.id = tt.tag_id WHERE tg.name = ?)");
}

QVariantList CollectionManager::bindingsForTag(const QString &tagName)
{
    return QVariantList{normalise(tagName)};
}
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/collectionmanager.cpp
git commit -m "feat(collections): free tags with prefix autocomplete and orphan cleanup"
```

### Task 4: O gesto único — jogar a faixa numa coleção

Um clique no ícone `plus` da linha abre a lista de coleções; escolher uma adiciona a faixa.
Nada de arrastar, nada de diálogo de duas etapas: o spec exige que o gesto manual seja **um só**.

- [ ] Criar `src/NewCollectionDialog.qml`:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Melodia.App

Popup {
    id: root

    signal created(int id, string name)

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: Theme.marginL
    width: 360

    background: Rectangle {
        color: Theme.mSurfaceVariant
        radius: Theme.radiusM
        border.width: Theme.borderS
        border.color: Theme.mOutline
    }

    onOpened: {
        nameInput.text = ""
        nameInput.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.marginM

        Text {
            text: qsTr("Nova coleção")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeL
            font.weight: Theme.fontWeightSemiBold
            color: Theme.mOnSurface
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.marginXL * 2
            radius: Theme.iRadiusS
            color: Theme.mSurface
            border.width: Theme.borderS
            border.color: nameInput.activeFocus ? Theme.mPrimary : Theme.mOutline

            TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: Theme.marginM
                anchors.rightMargin: Theme.marginM
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurface
                selectionColor: Theme.mPrimary
                selectedTextColor: Theme.mOnPrimary
                onAccepted: confirm.clicked()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: warning.text !== ""
            id: warning
            text: ""
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeS
            color: Theme.mError
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS
            Item { Layout.fillWidth: true }
            MelodiaButton {
                text: qsTr("Cancelar")
                outlined: true
                onClicked: root.close()
            }
            MelodiaButton {
                id: confirm
                text: qsTr("Criar")
                onClicked: {
                    const id = CollectionManager.createCollection(nameInput.text)
                    if (id > 0) {
                        root.created(id, nameInput.text)
                        root.close()
                    } else {
                        warning.text = qsTr("Já existe uma coleção com esse nome.")
                    }
                }
            }
        }
    }
}
```

- [ ] Criar `src/CollectionsSection.qml` — o bloco que vai no **topo** da barra lateral, onde
      o spec o coloca ("Coleções ← o diferencial, no topo"):

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

ColumnLayout {
    id: root

    property int currentCollectionId: 0
    property var model: []

    signal collectionChosen(int id)

    spacing: Theme.marginXXS

    function refresh() {
        root.model = CollectionManager.collections()
    }

    Component.onCompleted: refresh()

    Connections {
        target: CollectionManager
        function onCollectionsChanged() { root.refresh() }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.marginM
        Layout.rightMargin: Theme.marginXS

        Text {
            Layout.fillWidth: true
            text: qsTr("Coleções")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeS
            font.weight: Theme.fontWeightSemiBold
            color: Theme.mOnSurfaceVariant
        }
        IconButton {
            icon: "plus"
            size: Theme.fontSizeS
            onClicked: newDialog.open()
        }
    }

    Repeater {
        model: root.model
        SidebarItem {
            required property var modelData
            Layout.fillWidth: true
            icon: "playlist"
            label: modelData.name
            badge: modelData.count
            selected: root.currentCollectionId === modelData.id
            onClicked: {
                root.currentCollectionId = modelData.id
                root.collectionChosen(modelData.id)
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.marginM
        Layout.rightMargin: Theme.marginM
        visible: root.model.length === 0
        wrapMode: Text.WordWrap
        text: qsTr("Nenhuma ainda. Crie uma e jogue faixas dentro.")
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeXS
        color: Theme.mOnSurfaceVariant
    }

    NewCollectionDialog {
        id: newDialog
        onCreated: function (id, name) {
            root.currentCollectionId = id
            root.collectionChosen(id)
        }
    }
}
```

- [ ] Acrescentar a `src/TrackRow.qml`: as propriedades `property int trackId: 0` e
      `property bool showCollectButton: false`, o sinal `signal collectRequested()`, e — dentro
      do `RowLayout`, imediatamente antes do `Text` de duração — o botão que dispara o gesto:

```qml
            IconButton {
                icon: "plus"
                size: Theme.fontSizeS
                visible: root.showCollectButton && (mouse.containsMouse || collectMenu.visible)
                onClicked: root.collectRequested()
            }
```

- [ ] Em `src/Main.qml`: instanciar `CollectionsSection` no topo da `Sidebar`, ligar
      `collectionChosen(id)` a
      `trackModel.loadFromQuery(CollectionManager.clauseForCollection(id), CollectionManager.bindingsForCollection(id))`,
      e responder a `TrackRow.collectRequested()` abrindo um `Menu` com as coleções existentes
      (mais o item "Nova coleção…"), cujo `onTriggered` chama
      `CollectionManager.addTrackToCollection(collectionId, trackId)`.
- [ ] verificação mecânica da task:
      `cmake --build build && QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec "is not a type|ReferenceError"`
      → `0`
- [ ] commit:

```bash
git add src/CollectionsSection.qml src/NewCollectionDialog.qml src/TrackRow.qml src/Main.qml CMakeLists.txt
git commit -m "feat(collections): one-gesture add-to-collection from the track row"
```

### Task 5: Editor de tags com autocomplete

- [ ] Criar `src/TagChip.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property string text: ""
    property bool removable: false

    signal removeRequested
    signal clicked

    implicitWidth: row.implicitWidth + Theme.marginM * 2
    implicitHeight: Theme.marginXL * 1.4
    radius: height / 2
    color: mouse.containsMouse ? Theme.mHover : Theme.mSurface
    border.width: Theme.borderS
    border.color: Theme.mOutline

    Behavior on color {
        ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.marginXS

        Text {
            text: root.text
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeXS
            color: mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurface
        }
        Text {
            visible: root.removable
            text: Icons.get("close")
            font.family: Icons.fontFamily
            font.pointSize: Theme.fontSizeXXS
            color: mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurfaceVariant

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.marginXS
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removeRequested()
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
```

- [ ] Criar `src/TagEditor.qml` — a caixa que sugere enquanto o usuário digita:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

ColumnLayout {
    id: root

    property int trackId: 0
    property var tags: []
    property var suggestions: []

    signal tagChosen(string name)

    spacing: Theme.marginS

    function refresh() {
        root.tags = root.trackId > 0 ? CollectionManager.tagsForTrack(root.trackId) : []
    }

    onTrackIdChanged: refresh()

    Connections {
        target: CollectionManager
        function onTagsChanged(id) { if (id === root.trackId) root.refresh() }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Theme.marginXS

        Repeater {
            model: root.tags
            TagChip {
                required property var modelData
                text: modelData.name
                removable: true
                onRemoveRequested: CollectionManager.removeTagFromTrack(root.trackId, modelData.name)
                onClicked: root.tagChosen(modelData.name)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.marginXL * 1.8
        radius: Theme.iRadiusS
        color: Theme.mSurface
        border.width: Theme.borderS
        border.color: tagInput.activeFocus ? Theme.mPrimary : Theme.mOutline

        TextInput {
            id: tagInput
            anchors.fill: parent
            anchors.leftMargin: Theme.marginM
            anchors.rightMargin: Theme.marginM
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeS
            color: Theme.mOnSurface

            onTextChanged: root.suggestions = CollectionManager.completeTag(text)
            onAccepted: {
                // Enter picks the first suggestion when there is one: that is the brake that
                // keeps near-duplicate tags from being created by accident.
                const name = root.suggestions.length > 0 ? root.suggestions[0] : text
                if (name !== "") {
                    CollectionManager.addTagToTrack(root.trackId, name)
                    text = ""
                    root.suggestions = []
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: tagInput.text === ""
                text: qsTr("nova tag…")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Theme.marginXS
        visible: root.suggestions.length > 0

        Repeater {
            model: root.suggestions
            TagChip {
                required property string modelData
                text: modelData
                onClicked: {
                    CollectionManager.addTagToTrack(root.trackId, modelData)
                    tagInput.text = ""
                    root.suggestions = []
                }
            }
        }
    }
}
```

- [ ] Acrescentar os dois `.qml` ao `QML_FILES` e expor o `TagEditor` na tela (painel lateral
      direito, abaixo da fila, mostrando as tags da faixa selecionada).
- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/TagChip.qml src/TagEditor.qml src/Main.qml CMakeLists.txt
git commit -m "feat(collections): tag editor with prefix suggestions"
```

### Task 6: Testes de coleções e tags

- [ ] Acrescentar a `tests/CMakeLists.txt` o alvo `tst_collections` (fontes de `tst_library`
      mais `../src/collectionmanager.*` e `../src/librarybrowser.*`), com `add_test` e
      `QT_QPA_PLATFORM=offscreen`.
- [ ] Criar `tests/tst_collections.cpp`:

```cpp
#include <QtTest/QtTest>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "collectionmanager.h"
#include "database.h"

class TstCollections : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;

    void exec(const QString &sql)
    {
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        QSqlQuery q(db);
        QVERIFY2(q.exec(sql), qPrintable(q.lastError().text()));
    }

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
        for (int i = 1; i <= 3; ++i) {
            exec(QStringLiteral("INSERT INTO tracks (id, path, mtime, size, title, added_at) "
                                "VALUES (%1, '/m/%1.flac', 1, 1, 'F%1', 100)")
                     .arg(i));
        }
    }

    void schemaIsAtVersionThree() { QCOMPARE(scalar(QStringLiteral("PRAGMA user_version")), 3); }

    void createRejectsDuplicateNameRegardlessOfCase()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Pra codar"));
        QVERIFY(id > 0);
        QCOMPARE(cm.createCollection(QStringLiteral("pra CODAR")), 0);
        QCOMPARE(cm.createCollection(QStringLiteral("  Pra   codar  ")), 0); // simplified()
        QCOMPARE(cm.createCollection(QString()), 0);
    }

    void oneTrackLivesInSeveralCollections()
    {
        CollectionManager cm;
        const int night = cm.createCollection(QStringLiteral("Madrugada"));
        const int code = cm.collections().first().toMap().value(QStringLiteral("id")).toInt();
        QVERIFY(night > 0);

        QVERIFY(cm.addTrackToCollection(night, 1));
        QVERIFY(cm.addTrackToCollection(code, 1));
        QCOMPARE(cm.collectionsForTrack(1).size(), 2); // the whole point of the product
    }

    void addingTheSameTrackTwiceIsANoOp()
    {
        CollectionManager cm;
        const int id = cm.collections().first().toMap().value(QStringLiteral("id")).toInt();
        QVERIFY(cm.addTrackToCollection(id, 2));
        QVERIFY(cm.addTrackToCollection(id, 2)); // must not fail, must not duplicate
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM collection_tracks WHERE collection_id = %1 AND track_id = 2")
                     .arg(id)),
                 1);
    }

    void positionsUseGapsOfAThousand()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Ordem"));
        cm.addTrackToCollection(id, 1);
        cm.addTrackToCollection(id, 2);
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT MAX(position) FROM collection_tracks WHERE collection_id = %1").arg(id)),
                 2 * CollectionManager::kPositionStep);
    }

    void deletingCollectionDropsItsLinksButKeepsTracks()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Descartável"));
        cm.addTrackToCollection(id, 3);
        QVERIFY(cm.deleteCollection(id));
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM collection_tracks WHERE collection_id = %1").arg(id)),
                 0);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE id = 3")), 1);
    }

    void tagsAreCaseInsensitiveAndAutocomplete()
    {
        CollectionManager cm;
        QVERIFY(cm.addTagToTrack(1, QStringLiteral("codar")));
        QVERIFY(cm.addTagToTrack(2, QStringLiteral("CODAR"))); // same tag, different case
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tags")), 1);

        cm.addTagToTrack(3, QStringLiteral("concentração"));
        const QStringList hits = cm.completeTag(QStringLiteral("co"));
        QCOMPARE(hits.size(), 2);
        QVERIFY(cm.completeTag(QStringLiteral("zzz")).isEmpty());
    }

    void removingTheLastUseDropsTheOrphanTag()
    {
        CollectionManager cm;
        QVERIFY(cm.addTagToTrack(1, QStringLiteral("efêmera")));
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tags WHERE name = 'efêmera'")), 1);
        QVERIFY(cm.removeTagFromTrack(1, QStringLiteral("efêmera")));
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tags WHERE name = 'efêmera'")), 0);
    }
};

QTEST_MAIN(TstCollections)
#include "tst_collections.moc"
```

- [ ] verificação mecânica da task:
      `cmake --build build && ctest --test-dir build -R tst_collections --output-on-failure`
      → `100% tests passed`
- [ ] commit:

```bash
git add tests/tst_collections.cpp tests/CMakeLists.txt
git commit -m "test(collections): multi-collection membership, ordering and tag dedupe"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec "is not a type|ReferenceError"` → `0`
- **Decisão humana:** o Pedro cria duas coleções, põe **a mesma faixa nas duas**, e confirma
  que o gesto é um clique só. É o diferencial inteiro do produto num teste de trinta segundos —
  se parecer trabalhoso aqui, a fatia falhou mesmo com todos os testes verdes.

## Fora de escopo

- **Energia, humor e contexto por faixa** — cortado na entrevista e registrado no spec: "campo
  que ninguém preenche duas vezes igual. Contexto já é o nome da coleção." Não reabrir.
- **Pasta exclusiva** (faixa num lugar só) — "Coleção múltipla ganhou".
- Análise automática que sugere coleção (BPM, humor): o spec exclui.
- Arrastar e soltar para reordenar: `moveTrackInCollection` já existe e é testável, mas a
  interação de arrastar entra só se a ordem manual se mostrar usada de fato.
- Coleção inteligente (regra salva que se atualiza sozinha) — as quatro listas automáticas já
  cobrem o caso comum.
- Exportar coleção como M3U.
