---
slug: navegacao-biblioteca
feature: melodia
status: em-execucao
depende-de: [tocador-ui]
decisao-humana: nao
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: navegacao-biblioteca

**Goal:** A biblioteca deixa de ser uma lista única. Barra lateral com Artistas, Álbuns,
Gêneros e Todas as faixas; busca que acha no meio do título; fila visível; e as quatro listas
que o app monta sozinho — Recentes, Mais tocadas, Esquecidas, Nunca ouvi — alimentadas por
estatísticas de escuta que passam a ser gravadas.

**Arquitetura:** Um `LibraryBrowser` (singleton C++) responde às consultas de navegação
devolvendo `QVariantList` para o QML; o `TrackListModel` da fatia anterior é reusado como
destino de qualquer seleção. A busca usa **FTS5** com tabela externa mantida por triggers. As
estatísticas são gravadas por um `PlayStatsRecorder` que escuta `AudioEngine::trackFinished`.

**Constraints globais:** Migração de schema é **aditiva**: esta fatia acrescenta a entrada de
índice 1 ao vetor `migrations()` (levando `user_version` de 1 para 2) e nunca edita a de índice 0. O limiar de "Esquecidas" é uma constante nomeada, não número mágico espalhado.

**Research:** `docs/plans/research/2026-08-27-tags-biblioteca.md` §B.7 (FTS5 e triggers) e
§B.8 (as quatro consultas literais).

## Arquivos

- Criar: `src/librarybrowser.h` · `src/librarybrowser.cpp`
- Criar: `src/playstatsrecorder.h` · `src/playstatsrecorder.cpp`
- Criar: `src/Sidebar.qml` · `src/SidebarItem.qml` · `src/SearchField.qml` · `src/QueuePanel.qml`
- Criar: `tests/tst_librarybrowser.cpp`
- Modificar: `src/database.cpp` (migração 2 + FTS5) · `src/Main.qml` · `CMakeLists.txt`
  · `tests/CMakeLists.txt`
- Testar: `tests/tst_librarybrowser.cpp`

## Interfaces

- **Consome:** `Database` (`kUiConnection`, `startScan()`, `scanFinished`), `TrackListModel`
  (`loadFromQuery(const QString &whereClause, const QVariantList &bindings)`, `allPaths()`,
  `count`, `currentPath`), `AudioEngine` (`loadPlaylist(const QStringList &, int)`,
  `trackFinished(const QString &path)`, `playlistPos`), `Theme`, `Icons`, `TrackRow`,
  `IconButton`, `MelodiaButton`.
- **Produz:**

```cpp
// src/librarybrowser.h — QML_ELEMENT + QML_SINGLETON
class LibraryBrowser : public QObject {
    // Each entry: { "id": int, "name": QString, "count": int, "subtitle": QString }
    Q_INVOKABLE QVariantList artists();
    Q_INVOKABLE QVariantList albums(int artistId = 0);
    Q_INVOKABLE QVariantList genres();

    // WHERE clauses ready for TrackListModel::loadFromQuery. Each returns the clause;
    // the matching bindings come from the *Bindings twin.
    Q_INVOKABLE QString clauseForArtist(int artistId);
    Q_INVOKABLE QString clauseForAlbum(int albumId);
    Q_INVOKABLE QString clauseForGenre(int genreId);
    Q_INVOKABLE QString clauseForAll();
    Q_INVOKABLE QString clauseForSearch(const QString &text);
    Q_INVOKABLE QVariantList bindingsFor(int id);          // {id} or {} for clauseForAll
    Q_INVOKABLE QVariantList bindingsForSearch(const QString &text);

    // The four automatic lists (spec: "Recentes · Mais tocadas · Esquecidas · Nunca ouvi").
    Q_INVOKABLE QString clauseRecent();
    Q_INVOKABLE QString clauseMostPlayed();
    Q_INVOKABLE QString clauseForgotten();
    Q_INVOKABLE QString clauseNeverPlayed();

    static constexpr int kForgottenMinPlays = 5;
    static constexpr int kForgottenDays = 90;
};

// src/playstatsrecorder.h — QML_ELEMENT + QML_SINGLETON
class PlayStatsRecorder : public QObject {
    // Connect once at startup: AudioEngine::trackFinished -> recordPlay.
    Q_INVOKABLE void recordPlay(const QString &path);
    Q_INVOKABLE void recordSkip(const QString &path);
};
```

Componentes QML publicados: `Sidebar { currentSection; signal sectionChosen(string section, int id) }`,
`SidebarItem { icon; label; selected; signal clicked }`, `SearchField { text; signal searchChanged(string text) }`,
`QueuePanel { }`.

## Tasks

### Task 1: Migração 2 — FTS5 e o índice de busca

Cada migração é uma entrada nova no vetor; a de índice 0 fica intocada. O FTS5 usa
`content=''` (índice sem cópia dos dados) e triggers para nunca ficar desatualizado.

- [x] Acrescentar ao vetor `migrations()` em `src/database.cpp`, **depois** da entrada
      existente, uma segunda entrada:

```cpp
        QStringLiteral(R"SQL(
CREATE VIRTUAL TABLE tracks_fts USING fts5(
    title, artist_name, album_title,
    content='',
    tokenize='unicode61 remove_diacritics 2'
);
CREATE TRIGGER trg_tracks_ai AFTER INSERT ON tracks BEGIN
    INSERT INTO tracks_fts(rowid, title, artist_name, album_title)
    SELECT new.id, IFNULL(new.title,''),
           IFNULL((SELECT name FROM artists WHERE id = new.artist_id),''),
           IFNULL((SELECT title FROM albums WHERE id = new.album_id),'');
END;
CREATE TRIGGER trg_tracks_ad AFTER DELETE ON tracks BEGIN
    INSERT INTO tracks_fts(tracks_fts, rowid, title, artist_name, album_title)
    VALUES('delete', old.id, IFNULL(old.title,''), '', '');
END;
CREATE TRIGGER trg_tracks_au AFTER UPDATE ON tracks BEGIN
    INSERT INTO tracks_fts(tracks_fts, rowid, title, artist_name, album_title)
    VALUES('delete', old.id, IFNULL(old.title,''), '', '');
    INSERT INTO tracks_fts(rowid, title, artist_name, album_title)
    SELECT new.id, IFNULL(new.title,''),
           IFNULL((SELECT name FROM artists WHERE id = new.artist_id),''),
           IFNULL((SELECT title FROM albums WHERE id = new.album_id),'');
END;
INSERT INTO tracks_fts(rowid, title, artist_name, album_title)
SELECT t.id, IFNULL(t.title,''), IFNULL(ar.name,''), IFNULL(al.title,'')
FROM tracks t
LEFT JOIN artists ar ON ar.id = t.artist_id
LEFT JOIN albums al ON al.id = t.album_id;
)SQL"),
```

- [x] verificação mecânica da task: rodar o app uma vez e conferir a versão do schema —
      `QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia; sqlite3 "$(ls ~/.local/share/melodia/melodia.db)" "PRAGMA user_version; SELECT COUNT(*) FROM sqlite_master WHERE name='tracks_fts';"`
      → `2` e `1`
- [x] commit:

```bash
git add src/database.cpp
git commit -m "feat(library): add FTS5 search index as schema migration 2"
```

### Task 2: LibraryBrowser — as consultas de navegação

- [ ] Criar `src/librarybrowser.h`:

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

class LibraryBrowser : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    static constexpr int kForgottenMinPlays = 5;
    static constexpr int kForgottenDays = 90;
    static constexpr int kAutoListLimit = 100;

    explicit LibraryBrowser(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList artists();
    Q_INVOKABLE QVariantList albums(int artistId = 0);
    Q_INVOKABLE QVariantList genres();

    Q_INVOKABLE QString clauseForArtist(int artistId);
    Q_INVOKABLE QString clauseForAlbum(int albumId);
    Q_INVOKABLE QString clauseForGenre(int genreId);
    Q_INVOKABLE QString clauseForAll();
    Q_INVOKABLE QString clauseForSearch(const QString &text);
    Q_INVOKABLE QVariantList bindingsFor(int id);
    Q_INVOKABLE QVariantList bindingsForSearch(const QString &text);

    Q_INVOKABLE QString clauseRecent();
    Q_INVOKABLE QString clauseMostPlayed();
    Q_INVOKABLE QString clauseForgotten();
    Q_INVOKABLE QString clauseNeverPlayed();

    // Turns free user input into a safe FTS5 prefix query: "jo mal" -> "jo* mal*".
    static QString toFtsPrefixQuery(const QString &text);
};
```

- [ ] Criar `src/librarybrowser.cpp`:

```cpp
#include "librarybrowser.h"

#include "database.h"

#include <QRegularExpression>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariantMap>

namespace {

QVariantList runLookup(const QString &sql)
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    QVariantList out;
    if (!q.exec(sql))
        return out;
    while (q.next()) {
        QVariantMap row;
        row.insert(QStringLiteral("id"), q.value(0).toInt());
        row.insert(QStringLiteral("name"), q.value(1).toString());
        row.insert(QStringLiteral("count"), q.value(2).toInt());
        row.insert(QStringLiteral("subtitle"), q.value(3).toString());
        out.append(row);
    }
    return out;
}

} // namespace

LibraryBrowser::LibraryBrowser(QObject *parent)
    : QObject(parent)
{
}

QVariantList LibraryBrowser::artists()
{
    return runLookup(QStringLiteral(
        "SELECT ar.id, ar.name, COUNT(t.id), '' "
        "FROM artists ar JOIN tracks t ON t.artist_id = ar.id AND t.removed_at IS NULL "
        "GROUP BY ar.id ORDER BY ar.name COLLATE NOCASE"));
}

QVariantList LibraryBrowser::albums(int artistId)
{
    const QString filter = artistId > 0
                               ? QStringLiteral("AND al.album_artist_id = %1").arg(artistId)
                               : QString();
    return runLookup(QStringLiteral(
                         "SELECT al.id, al.title, COUNT(t.id), IFNULL(ar.name,'') "
                         "FROM albums al "
                         "JOIN tracks t ON t.album_id = al.id AND t.removed_at IS NULL "
                         "LEFT JOIN artists ar ON ar.id = al.album_artist_id "
                         "WHERE 1=1 %1 "
                         "GROUP BY al.id ORDER BY al.title COLLATE NOCASE")
                         .arg(filter));
}

QVariantList LibraryBrowser::genres()
{
    return runLookup(QStringLiteral(
        "SELECT g.id, g.name, COUNT(t.id), '' "
        "FROM genres g JOIN tracks t ON t.genre_id = g.id AND t.removed_at IS NULL "
        "GROUP BY g.id ORDER BY g.name COLLATE NOCASE"));
}

QString LibraryBrowser::clauseForArtist(int)
{
    return QStringLiteral("t.removed_at IS NULL AND t.artist_id = ?");
}

QString LibraryBrowser::clauseForAlbum(int)
{
    return QStringLiteral("t.removed_at IS NULL AND t.album_id = ?");
}

QString LibraryBrowser::clauseForGenre(int)
{
    return QStringLiteral("t.removed_at IS NULL AND t.genre_id = ?");
}

QString LibraryBrowser::clauseForAll()
{
    return QStringLiteral("t.removed_at IS NULL");
}

QString LibraryBrowser::clauseForSearch(const QString &text)
{
    if (text.trimmed().isEmpty())
        return clauseForAll();
    return QStringLiteral(
        "t.removed_at IS NULL AND t.id IN (SELECT rowid FROM tracks_fts WHERE tracks_fts MATCH ?)");
}

QVariantList LibraryBrowser::bindingsFor(int id)
{
    return id > 0 ? QVariantList{id} : QVariantList{};
}

QVariantList LibraryBrowser::bindingsForSearch(const QString &text)
{
    if (text.trimmed().isEmpty())
        return {};
    return QVariantList{toFtsPrefixQuery(text)};
}

QString LibraryBrowser::toFtsPrefixQuery(const QString &text)
{
    // FTS5 treats quotes, '-', '*', ':' and friends as syntax. Strip everything that is not
    // a letter or a digit, then turn each remaining word into a prefix term.
    static const QRegularExpression nonWord(QStringLiteral("[^\\w]+"),
                                            QRegularExpression::UseUnicodePropertiesOption);
    const QStringList words = text.trimmed().split(nonWord, Qt::SkipEmptyParts);
    QStringList terms;
    terms.reserve(words.size());
    for (const QString &w : words)
        terms.append(w + QLatin1Char('*'));
    return terms.join(QLatin1Char(' '));
}

QString LibraryBrowser::clauseRecent()
{
    // Carries its own ORDER BY; TrackListModel::loadFromQuery detects that and does not
    // append its default ordering. No trailing "--" comment: it would swallow whatever the
    // query builder appends on the same line.
    return QStringLiteral("t.removed_at IS NULL ORDER BY t.added_at DESC LIMIT %1")
        .arg(kAutoListLimit);
}

QString LibraryBrowser::clauseMostPlayed()
{
    return QStringLiteral(
               "t.removed_at IS NULL AND t.id IN ("
               "SELECT track_id FROM track_stats WHERE play_count > 0 "
               "ORDER BY play_count DESC LIMIT %1)")
        .arg(kAutoListLimit);
}

QString LibraryBrowser::clauseForgotten()
{
    return QStringLiteral(
               "t.removed_at IS NULL AND t.id IN ("
               "SELECT track_id FROM track_stats "
               "WHERE play_count >= %1 AND last_played_at IS NOT NULL "
               "AND last_played_at < strftime('%s','now') - %2*86400 "
               "ORDER BY play_count DESC, last_played_at ASC LIMIT %3)")
        .arg(kForgottenMinPlays)
        .arg(kForgottenDays)
        .arg(kAutoListLimit);
}

QString LibraryBrowser::clauseNeverPlayed()
{
    return QStringLiteral(
               "t.removed_at IS NULL AND t.id IN ("
               "SELECT track_id FROM track_stats WHERE play_count = 0 LIMIT %1)")
        .arg(kAutoListLimit);
}
```

- [ ] **Ajuste necessário em `TrackListModel::loadFromQuery`** (fatia `tocador-ui`): a cláusula
      de "Recentes" precisa da própria ordenação. Trocar a montagem da query para respeitar uma
      cláusula que já traga `ORDER BY`:

```cpp
    const bool clauseHasOrder = whereClause.contains(QStringLiteral("ORDER BY"));
    q.prepare(QLatin1String(kSelect) + QStringLiteral("WHERE ") + whereClause
              + (clauseHasOrder
                     ? QString()
                     : QStringLiteral(" ORDER BY IFNULL(al.title,''), t.disc_no, t.track_no, t.title")));
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/librarybrowser.h src/librarybrowser.cpp src/tracklistmodel.cpp CMakeLists.txt
git commit -m "feat(library): browse by artist, album and genre plus FTS5 search"
```

### Task 3: PlayStatsRecorder — as estatísticas que alimentam as listas automáticas

Sem esta task, "Mais tocadas", "Esquecidas" e "Nunca ouvi" ficam vazias para sempre.

- [ ] Criar `src/playstatsrecorder.h`:

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

class PlayStatsRecorder : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit PlayStatsRecorder(QObject *parent = nullptr);

    Q_INVOKABLE void recordPlay(const QString &path);
    Q_INVOKABLE void recordSkip(const QString &path);

signals:
    void statsChanged(const QString &path);
};
```

- [ ] Criar `src/playstatsrecorder.cpp`:

```cpp
#include "playstatsrecorder.h"

#include "database.h"

#include <QDateTime>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariant>

PlayStatsRecorder::PlayStatsRecorder(QObject *parent)
    : QObject(parent)
{
}

void PlayStatsRecorder::recordPlay(const QString &path)
{
    if (path.isEmpty())
        return;
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "UPDATE track_stats SET play_count = play_count + 1, last_played_at = ? "
        "WHERE track_id = (SELECT id FROM tracks WHERE path = ?)"));
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    q.addBindValue(path);
    if (q.exec() && q.numRowsAffected() > 0)
        emit statsChanged(path);
}

void PlayStatsRecorder::recordSkip(const QString &path)
{
    if (path.isEmpty())
        return;
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "UPDATE track_stats SET skip_count = skip_count + 1 "
        "WHERE track_id = (SELECT id FROM tracks WHERE path = ?)"));
    q.addBindValue(path);
    if (q.exec() && q.numRowsAffected() > 0)
        emit statsChanged(path);
}
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/playstatsrecorder.h src/playstatsrecorder.cpp CMakeLists.txt
git commit -m "feat(library): record play and skip counts per track"
```

### Task 4: Barra lateral, busca e fila

- [ ] Criar `src/SidebarItem.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool selected: false
    property int badge: 0

    signal clicked

    implicitHeight: Theme.marginXL * 2
    implicitWidth: parent ? parent.width : 200

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.marginXXS
        radius: Theme.radiusXS
        color: root.selected ? Theme.mPrimary
                             : (mouse.containsMouse ? Theme.mHover : "transparent")

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.marginM
            anchors.rightMargin: Theme.marginM
            spacing: Theme.marginS

            Text {
                text: Icons.get(root.icon)
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeM
                color: root.selected ? Theme.mOnPrimary
                                     : (mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurface)
            }
            Text {
                Layout.fillWidth: true
                text: root.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                font.weight: root.selected ? Theme.fontWeightSemiBold : Theme.fontWeightMedium
                color: root.selected ? Theme.mOnPrimary
                                     : (mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurface)
            }
            Text {
                visible: root.badge > 0
                text: root.badge
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: root.selected ? Theme.mOnPrimary : Theme.mOnSurfaceVariant
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

- [ ] Criar `src/Sidebar.qml` — a ordem das seções segue o desenho do spec (§Como fica
      organizado): as coleções vêm no topo (a fatia `colecoes-tags` preenche esse espaço),
      depois Artistas, Álbuns, Gêneros, Todas as faixas, e por fim as automáticas:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property string currentSection: "all"
    property int currentId: 0

    signal sectionChosen(string section, int id)

    implicitWidth: 220
    color: Theme.mSurfaceVariant
    radius: Theme.radiusM
    border.width: Theme.borderS
    border.color: Theme.mOutline

    function choose(section, id) {
        root.currentSection = section
        root.currentId = id
        root.sectionChosen(section, id)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginS
        spacing: Theme.marginXXS

        SidebarItem {
            Layout.fillWidth: true
            icon: "microphone"; label: qsTr("Artistas")
            selected: root.currentSection === "artists"
            onClicked: root.choose("artists", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "disc"; label: qsTr("Álbuns")
            selected: root.currentSection === "albums"
            onClicked: root.choose("albums", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "tags"; label: qsTr("Gêneros")
            selected: root.currentSection === "genres"
            onClicked: root.choose("genres", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "list"; label: qsTr("Todas as faixas")
            selected: root.currentSection === "all"
            onClicked: root.choose("all", 0)
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.marginS
            Layout.bottomMargin: Theme.marginS
            height: Theme.borderS
            color: Theme.mOutline
        }

        SidebarItem {
            Layout.fillWidth: true
            icon: "clock"; label: qsTr("Recentes")
            selected: root.currentSection === "recent"
            onClicked: root.choose("recent", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "star"; label: qsTr("Mais tocadas")
            selected: root.currentSection === "mostPlayed"
            onClicked: root.choose("mostPlayed", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "history"; label: qsTr("Esquecidas")
            selected: root.currentSection === "forgotten"
            onClicked: root.choose("forgotten", 0)
        }
        SidebarItem {
            Layout.fillWidth: true
            icon: "heart"; label: qsTr("Nunca ouvi")
            selected: root.currentSection === "never"
            onClicked: root.choose("never", 0)
        }

        Item { Layout.fillHeight: true }
    }
}
```

- [ ] Criar `src/SearchField.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property alias text: input.text

    signal searchChanged(string text)

    implicitHeight: Theme.marginXL * 2
    radius: Theme.iRadiusS
    color: Theme.mSurface
    border.width: Theme.borderS
    border.color: input.activeFocus ? Theme.mPrimary : Theme.mOutline

    Behavior on border.color {
        ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginM
        anchors.rightMargin: Theme.marginS
        spacing: Theme.marginS

        Text {
            text: Icons.get("search")
            font.family: Icons.fontFamily
            font.pointSize: Theme.fontSizeM
            color: Theme.mOnSurfaceVariant
        }

        TextInput {
            id: input
            Layout.fillWidth: true
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeM
            color: Theme.mOnSurface
            selectionColor: Theme.mPrimary
            selectedTextColor: Theme.mOnPrimary
            clip: true

            // Debounce: searching on every keystroke re-runs FTS5 for each letter typed.
            onTextChanged: debounce.restart()

            Timer {
                id: debounce
                interval: 180
                onTriggered: root.searchChanged(input.text)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === "" && !input.activeFocus
                text: qsTr("buscar…")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeM
                color: Theme.mOnSurfaceVariant
            }
        }

        IconButton {
            icon: "close"
            size: Theme.fontSizeS
            visible: input.text !== ""
            onClicked: {
                input.text = ""
                root.searchChanged("")
            }
        }
    }
}
```

- [ ] Criar `src/QueuePanel.qml` — mostra a playlist viva do mpv, com a entrada atual
      destacada por `AudioEngine.playlistPos`:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property var paths: []

    implicitWidth: 300
    color: Theme.mSurfaceVariant
    radius: Theme.radiusM
    border.width: Theme.borderS
    border.color: Theme.mOutline

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginM
        spacing: Theme.marginS

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: qsTr("Fila")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }
            Text {
                text: root.paths.length
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOnSurfaceVariant
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.paths
            clip: true
            spacing: Theme.marginXXS

            delegate: Item {
                required property int index
                required property string modelData

                width: ListView.view.width
                height: Theme.marginXL * 1.6

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusXXS
                    color: index === AudioEngine.playlistPos ? Theme.mSurface : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.marginS
                        anchors.rightMargin: Theme.marginS
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: modelData.split("/").pop()
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSizeS
                        color: index === AudioEngine.playlistPos ? Theme.mPrimary
                                                                 : Theme.mOnSurfaceVariant
                    }
                }
            }
        }
    }
}
```

- [ ] Acrescentar os quatro `.qml` ao bloco `QML_FILES`.
- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/Sidebar.qml src/SidebarItem.qml src/SearchField.qml src/QueuePanel.qml CMakeLists.txt
git commit -m "feat(ui): sidebar sections, debounced search field and queue panel"
```

### Task 5: Montar a tela de navegação

- [ ] Reescrever o corpo de `src/Main.qml` para o layout de três colunas (barra lateral ·
      conteúdo · fila), com a barra de transporte embaixo, ligando:
  - `Sidebar.sectionChosen(section, id)` → escolhe a cláusula em `LibraryBrowser` e chama
    `trackModel.loadFromQuery(clause, bindings)`;
  - `SearchField.searchChanged(text)` →
    `trackModel.loadFromQuery(LibraryBrowser.clauseForSearch(text), LibraryBrowser.bindingsForSearch(text))`;
  - `AudioEngine.trackFinished(path)` → `PlayStatsRecorder.recordPlay(path)`;
  - o `QueuePanel.paths` recebe o retorno de `trackModel.allPaths()` no momento em que uma
    faixa é ativada (a fila é o que foi carregado, não a lista visível de agora).

  O roteamento de seção fica assim:

```qml
    function clauseFor(section, id) {
        switch (section) {
        case "artists": return { clause: LibraryBrowser.clauseForArtist(id),
                                 bindings: LibraryBrowser.bindingsFor(id) }
        case "albums":  return { clause: LibraryBrowser.clauseForAlbum(id),
                                 bindings: LibraryBrowser.bindingsFor(id) }
        case "genres":  return { clause: LibraryBrowser.clauseForGenre(id),
                                 bindings: LibraryBrowser.bindingsFor(id) }
        case "recent":     return { clause: LibraryBrowser.clauseRecent(), bindings: [] }
        case "mostPlayed": return { clause: LibraryBrowser.clauseMostPlayed(), bindings: [] }
        case "forgotten":  return { clause: LibraryBrowser.clauseForgotten(), bindings: [] }
        case "never":      return { clause: LibraryBrowser.clauseNeverPlayed(), bindings: [] }
        default:           return { clause: LibraryBrowser.clauseForAll(), bindings: [] }
        }
    }

    Connections {
        target: AudioEngine
        function onTrackFinished(path) { PlayStatsRecorder.recordPlay(path) }
    }
```

- [ ] Quando a seção for `artists`, `albums` ou `genres` e `id === 0`, a área central mostra a
      **lista de grupos** (`LibraryBrowser.artists()` / `.albums()` / `.genres()`) num
      `ListView` de `SidebarItem`-like; clicar num grupo chama `choose(section, grupoId)` e aí
      sim carrega as faixas daquele grupo.
- [ ] verificação mecânica da task:
      `QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec "is not a type|ReferenceError|Unable to assign"`
      → `0`
- [ ] commit:

```bash
git add src/Main.qml
git commit -m "feat(ui): three-column library navigation with search and queue"
```

### Task 6: Testes das consultas e das estatísticas

- [ ] Acrescentar a `tests/CMakeLists.txt` um alvo `tst_librarybrowser` com as mesmas fontes de
      `tst_library` mais `../src/librarybrowser.*` e `../src/playstatsrecorder.*`, registrado
      com `add_test` e `QT_QPA_PLATFORM=offscreen`.
- [ ] Criar `tests/tst_librarybrowser.cpp`:

```cpp
#include <QtTest/QtTest>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "database.h"
#include "librarybrowser.h"
#include "playstatsrecorder.h"

class TstLibraryBrowser : public QObject
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

        exec(QStringLiteral("INSERT INTO artists (id, name) VALUES (1, 'João Malandro')"));
        exec(QStringLiteral("INSERT INTO albums (id, title, album_artist_id) VALUES (1, 'Coração', 1)"));
        exec(QStringLiteral(
            "INSERT INTO tracks (id, path, mtime, size, title, artist_id, album_id, added_at) "
            "VALUES (1, '/m/a.flac', 1, 1, 'Canção do Mar', 1, 1, 1000)"));
        exec(QStringLiteral(
            "INSERT INTO tracks (id, path, mtime, size, title, artist_id, album_id, added_at) "
            "VALUES (2, '/m/b.flac', 1, 1, 'Outra Coisa', 1, 1, 2000)"));
        exec(QStringLiteral("INSERT INTO track_stats (track_id, first_seen_at) VALUES (1, 1000)"));
        exec(QStringLiteral("INSERT INTO track_stats (track_id, first_seen_at) VALUES (2, 2000)"));
    }

    void schemaIsAtVersionTwo() { QCOMPARE(scalar(QStringLiteral("PRAGMA user_version")), 2); }

    void artistsAreCountedFromActiveTracks()
    {
        LibraryBrowser browser;
        const QVariantList list = browser.artists();
        QCOMPARE(list.size(), 1);
        QCOMPARE(list.first().toMap().value(QStringLiteral("count")).toInt(), 2);
    }

    void ftsIndexWasBackfilledByTheMigration()
    {
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks_fts")), 2);
    }

    void searchMatchesIgnoringDiacritics()
    {
        // tokenize='unicode61 remove_diacritics 2' means "cancao" must find "Canção".
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM tracks_fts WHERE tracks_fts MATCH 'cancao*'")),
                 1);
    }

    void searchQuerySanitisesUserInput()
    {
        // Raw FTS5 syntax in user input must not reach the engine as syntax.
        QCOMPARE(LibraryBrowser::toFtsPrefixQuery(QStringLiteral("jo\" OR x:")),
                 QStringLiteral("jo* OR* x*"));
        QCOMPARE(LibraryBrowser::toFtsPrefixQuery(QStringLiteral("  mar  ")),
                 QStringLiteral("mar*"));
    }

    void recordPlayIncrementsTheCounter()
    {
        PlayStatsRecorder recorder;
        recorder.recordPlay(QStringLiteral("/m/a.flac"));
        recorder.recordPlay(QStringLiteral("/m/a.flac"));
        QCOMPARE(scalar(QStringLiteral("SELECT play_count FROM track_stats WHERE track_id = 1")), 2);
        QVERIFY(scalar(QStringLiteral(
                    "SELECT last_played_at IS NOT NULL FROM track_stats WHERE track_id = 1")) == 1);
    }

    void neverPlayedExcludesWhatWasPlayed()
    {
        LibraryBrowser browser;
        const QString sql = QStringLiteral("SELECT COUNT(*) FROM tracks t WHERE ")
                            + browser.clauseNeverPlayed();
        QCOMPARE(scalar(sql), 1); // track 2 only: track 1 has plays now
    }

    void forgottenNeedsBothPlaysAndAge()
    {
        exec(QStringLiteral("UPDATE track_stats SET play_count = 9, "
                            "last_played_at = strftime('%s','now') - 200*86400 WHERE track_id = 2"));
        LibraryBrowser browser;
        const QString sql = QStringLiteral("SELECT COUNT(*) FROM tracks t WHERE ")
                            + browser.clauseForgotten();
        QCOMPARE(scalar(sql), 1); // track 2: many plays, none recently
    }
};

QTEST_MAIN(TstLibraryBrowser)
#include "tst_librarybrowser.moc"
```

- [ ] Acrescentar `#include <QSqlError>` ao topo do teste (usado no `QVERIFY2`).
- [ ] verificação mecânica da task:
      `cmake --build build && ctest --test-dir build -R tst_librarybrowser --output-on-failure`
      → `100% tests passed`
- [ ] commit:

```bash
git add tests/tst_librarybrowser.cpp tests/CMakeLists.txt
git commit -m "test(library): browse queries, FTS sanitising and play statistics"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec "is not a type|ReferenceError|Unable to assign"` → `0`
- `grep -c "kForgottenMinPlays" src/librarybrowser.h src/librarybrowser.cpp` → ao menos `1` em cada
  (o limiar tem de continuar sendo constante nomeada, nunca número solto na query)

## Fora de escopo

- Coleções e tags — fatia `colecoes-tags`, que reusa esta mesma barra lateral acrescentando as
  duas seções no topo, onde o spec as coloca.
- Podcast — fatia `podcast-local`.
- Ordenar a lista por coluna, agrupar por álbum com cabeçalho, capa em grade.
- Repetir e aleatório: o mpv tem `playlist-shuffle` e `loop-playlist`, mas nenhuma tela os
  expõe ainda; entram quando houver onde clicá-los sem poluir a barra.
- Limpar o cache de capas, tela de configurações, atalhos de teclado.
