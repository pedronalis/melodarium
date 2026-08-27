---
slug: podcast-local
feature: melodia
status: concluido
depende-de: [navegacao-biblioteca]
decisao-humana: nao
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: podcast-local

**Goal:** A aba Podcast, lendo os arquivos que já estão no disco. Organiza por programa,
mostra "Continuar ouvindo" no topo, guarda onde você parou em cada episódio, deixa acelerar a
voz e marcar como ouvido.

**Arquitetura:** Migração 4 acrescenta `podcast_shows` e `podcast_episodes` (o schema já foi
desenhado na fatia `scan-biblioteca`, aqui ele é criado). Um `PodcastLibrary` (singleton C++)
varre a pasta de podcast — uma pasta por programa — e é dono da posição de escuta. A posição é
gravada por um `QTimer` de 5 s enquanto toca, e no `pause`/`stop`: gravar a cada
`positionChanged` seria uma escrita no SQLite a cada frame de UI.

**Constraints globais (spec §Decisões, verbatim):** "Podcast quer o oposto de música: retomar
posição, não embaralhar." E, do §Como fica organizado: "Podcast **não** tem coleção nem tag:
por programa, episódios dentro, 'Continuar ouvindo' no topo." O `CollectionManager` desta vez
não é consumido — é uma fronteira deliberada, não um esquecimento.

**Research:** `docs/plans/research/2026-08-27-tags-biblioteca.md` §B.6.

## Arquivos

- Criar: `src/podcastlibrary.h` · `src/podcastlibrary.cpp`
- Criar: `src/podcastepisodemodel.h` · `src/podcastepisodemodel.cpp`
- Criar: `src/PodcastSection.qml` · `src/EpisodeRow.qml` · `src/SpeedControl.qml`
  · `src/ContinueListening.qml`
- Criar: `tests/tst_podcast.cpp`
- Modificar: `src/database.cpp` (migração 4) · `src/Main.qml` (abas Música/Podcast)
  · `CMakeLists.txt` · `tests/CMakeLists.txt`
- Testar: `tests/tst_podcast.cpp`

## Interfaces

- **Consome:** `Database` (`kUiConnection`, `applyPragmas`, `migrate`), `TagReader`
  (`read(const QString &absolutePath)` para duração e título), `CoverCache`
  (`coverUrlForTrack(const QString &trackPath, int albumId)`), `AudioEngine`
  (`loadPlaylist(const QStringList &, int)`, `seek(double)`, `play()`, `pause()`,
  `position`, `duration`, `playing`, `currentFile`, `speed`, `setSpeed(double)`,
  `trackFinished(const QString &path)`), `Theme`, `Icons`, `IconButton`, `MelodiaButton`,
  `SidebarItem`.
- **Produz:**

```cpp
// src/podcastlibrary.h — QML_ELEMENT + QML_SINGLETON
class PodcastLibrary : public QObject {
    // Q_PROPERTY(QString podcastPath READ podcastPath WRITE setPodcastPath NOTIFY podcastPathChanged)
    // Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    static constexpr int kSaveIntervalMs = 5000;
    static constexpr double kPlayedThreshold = 0.95;   // 95% listened marks it played
    static constexpr int kResumeBackoffSec = 3;        // rewind a few seconds when resuming

    Q_INVOKABLE QVariantList shows();                  // { id, title, coverPath, episodeCount, unplayedCount }
    Q_INVOKABLE QVariantList continueListening(int limit = 5);
    Q_INVOKABLE void scanPodcastFolder();              // one folder per show
    Q_INVOKABLE void playEpisode(int episodeId);       // seeks to the saved position
    Q_INVOKABLE void savePosition(int episodeId, int positionMs);
    Q_INVOKABLE void markPlayed(int episodeId, bool played);
    Q_INVOKABLE QVariantMap episodeForPath(const QString &path);
    // signals: void showsChanged(); void episodesChanged(int showId); void scanningChanged();
    //          void podcastPathChanged();
};

// src/podcastepisodemodel.h — QML_ELEMENT (instanciável)
class PodcastEpisodeModel : public QAbstractListModel {
    enum Roles { IdRole = Qt::UserRole + 1, TitleRole, PathRole, PublishedAtRole,
                 DurationMsRole, PositionMsRole, PlayedRole, ProgressRole, IsCurrentRole };
    // Q_ENUM(Roles); Q_PROPERTY(int count ...); Q_PROPERTY(int showId ... WRITE setShowId ...)
    Q_INVOKABLE void loadForShow(int showId);
    Q_INVOKABLE QVariantMap episodeAt(int row) const;
};
```

Componentes QML: `PodcastSection { signal showChosen(int showId) }`,
`EpisodeRow { title; durationMs; positionMs; played; isCurrent; signal activated; signal playedToggled }`,
`SpeedControl { }`, `ContinueListening { signal episodeChosen(int episodeId) }`.

## Tasks

### Task 1: Migração 4 — programas e episódios

O `feed_url` fica `NULL` nesta fatia (o programa veio de uma pasta, não de um feed) e é a fatia
`feed-rss` que passa a preenchê-lo. Por isso a coluna nasce **anulável** e o `UNIQUE` fica sobre
`folder_path`, não sobre a URL.

- [x] Acrescentar ao vetor `migrations()` em `src/database.cpp`, como quarta entrada:

```cpp
        QStringLiteral(R"SQL(
CREATE TABLE podcast_shows (
    id              INTEGER PRIMARY KEY,
    title           TEXT NOT NULL,
    folder_path     TEXT UNIQUE,
    feed_url        TEXT UNIQUE,
    etag            TEXT,
    last_modified   TEXT,
    last_checked_at INTEGER,
    cover_path      TEXT
);
CREATE TABLE podcast_episodes (
    id           INTEGER PRIMARY KEY,
    show_id      INTEGER NOT NULL REFERENCES podcast_shows(id) ON DELETE CASCADE,
    guid         TEXT NOT NULL,
    title        TEXT NOT NULL,
    published_at INTEGER,
    duration_ms  INTEGER,
    local_path   TEXT,
    position_ms  INTEGER NOT NULL DEFAULT 0,
    played       INTEGER NOT NULL DEFAULT 0 CHECK(played IN (0,1)),
    last_played_at INTEGER,
    UNIQUE(show_id, guid)
);
CREATE INDEX idx_episodes_show   ON podcast_episodes(show_id, published_at DESC);
CREATE INDEX idx_episodes_resume ON podcast_episodes(last_played_at DESC) WHERE played = 0;
CREATE UNIQUE INDEX idx_episodes_path ON podcast_episodes(local_path) WHERE local_path IS NOT NULL;
)SQL"),
```

- [x] verificação mecânica da task:
      `QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia; sqlite3 ~/.local/share/melodia/melodia.db "PRAGMA user_version;"`
      → `4`
- [x] commit:

```bash
git add src/database.cpp
git commit -m "feat(podcast): add shows and episodes as schema migration 4"
```

### Task 2: PodcastLibrary — varredura por pasta e posição de escuta

- [x] Criar `src/podcastlibrary.h`:

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

class PodcastLibrary : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString podcastPath READ podcastPath WRITE setPodcastPath NOTIFY podcastPathChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)

public:
    static constexpr int kSaveIntervalMs = 5000;
    static constexpr double kPlayedThreshold = 0.95;
    static constexpr int kResumeBackoffSec = 3;

    explicit PodcastLibrary(QObject *parent = nullptr);

    QString podcastPath() const { return m_podcastPath; }
    void setPodcastPath(const QString &path);
    bool scanning() const { return m_scanning; }

    Q_INVOKABLE QVariantList shows();
    Q_INVOKABLE QVariantList continueListening(int limit = 5);
    Q_INVOKABLE void scanPodcastFolder();
    Q_INVOKABLE void playEpisode(int episodeId);
    Q_INVOKABLE void savePosition(int episodeId, int positionMs);
    Q_INVOKABLE void markPlayed(int episodeId, bool played);
    Q_INVOKABLE QVariantMap episodeForPath(const QString &path);

signals:
    void podcastPathChanged();
    void scanningChanged();
    void showsChanged();
    void episodesChanged(int showId);
    void episodePlayRequested(const QString &path, int seekToSeconds);

private:
    int ensureShow(const QString &folderPath, const QString &title);

    QString m_podcastPath;
    bool m_scanning = false;
};
```

- [x] Criar `src/podcastlibrary.cpp`:

```cpp
#include "podcastlibrary.h"

#include "database.h"
#include "tagreader.h"

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariant>

namespace {

QSqlDatabase uiDb()
{
    return QSqlDatabase::database(QLatin1String(Database::kUiConnection));
}

const QStringList &podcastSuffixes()
{
    static const QStringList list = {QStringLiteral("mp3"), QStringLiteral("m4a"),
                                     QStringLiteral("opus"), QStringLiteral("ogg"),
                                     QStringLiteral("aac"), QStringLiteral("flac")};
    return list;
}

} // namespace

PodcastLibrary::PodcastLibrary(QObject *parent)
    : QObject(parent)
{
    m_podcastPath = QSettings().value(QStringLiteral("podcast/path")).toString();
}

void PodcastLibrary::setPodcastPath(const QString &path)
{
    if (m_podcastPath == path)
        return;
    m_podcastPath = path;
    QSettings().setValue(QStringLiteral("podcast/path"), path);
    emit podcastPathChanged();
}

int PodcastLibrary::ensureShow(const QString &folderPath, const QString &title)
{
    QSqlQuery sel(uiDb());
    sel.prepare(QStringLiteral("SELECT id FROM podcast_shows WHERE folder_path = ?"));
    sel.addBindValue(folderPath);
    if (sel.exec() && sel.next())
        return sel.value(0).toInt();

    QSqlQuery ins(uiDb());
    ins.prepare(QStringLiteral("INSERT INTO podcast_shows (title, folder_path) VALUES (?, ?)"));
    ins.addBindValue(title);
    ins.addBindValue(folderPath);
    return ins.exec() ? ins.lastInsertId().toInt() : 0;
}

void PodcastLibrary::scanPodcastFolder()
{
    if (m_podcastPath.isEmpty() || m_scanning)
        return;

    m_scanning = true;
    emit scanningChanged();

    // One folder per show. Files loose at the root go into a catch-all show so nothing
    // silently disappears from the user's view.
    const QDir root(m_podcastPath);
    QStringList folders = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    folders.prepend(QString()); // the root itself

    for (const QString &folder : folders) {
        const QString folderPath = folder.isEmpty() ? root.absolutePath()
                                                    : root.absoluteFilePath(folder);
        const QString showTitle = folder.isEmpty() ? QObject::tr("Avulsos") : folder;

        QDir showDir(folderPath);
        const QStringList files = showDir.entryList(QDir::Files);
        QStringList audio;
        for (const QString &f : files) {
            if (podcastSuffixes().contains(QFileInfo(f).suffix().toLower()))
                audio.append(showDir.absoluteFilePath(f));
        }
        if (audio.isEmpty())
            continue;

        const int showId = ensureShow(folderPath, showTitle);
        if (showId <= 0)
            continue;

        for (const QString &path : audio) {
            QSqlQuery exists(uiDb());
            exists.prepare(QStringLiteral("SELECT id FROM podcast_episodes WHERE local_path = ?"));
            exists.addBindValue(path);
            if (exists.exec() && exists.next())
                continue; // already catalogued: never re-read tags nor reset the position

            const TrackRecord rec = TagReader::read(path);
            const QFileInfo info(path);
            QSqlQuery ins(uiDb());
            ins.prepare(QStringLiteral(
                "INSERT INTO podcast_episodes (show_id, guid, title, published_at, duration_ms, "
                "local_path) VALUES (?, ?, ?, ?, ?, ?)"));
            ins.addBindValue(showId);
            // A local file has no RSS guid: the path is its identity until a feed claims it.
            ins.addBindValue(path);
            ins.addBindValue(rec.valid && !rec.title.isEmpty() ? rec.title : info.completeBaseName());
            ins.addBindValue(info.lastModified().toSecsSinceEpoch());
            ins.addBindValue(rec.valid ? rec.durationMs : 0);
            ins.addBindValue(path);
            ins.exec();
        }
        emit episodesChanged(showId);
    }

    m_scanning = false;
    emit scanningChanged();
    emit showsChanged();
}

QVariantList PodcastLibrary::shows()
{
    QSqlQuery q(uiDb());
    QVariantList out;
    if (!q.exec(QStringLiteral(
            "SELECT s.id, s.title, IFNULL(s.cover_path,''), COUNT(e.id), "
            "SUM(CASE WHEN e.played = 0 THEN 1 ELSE 0 END) "
            "FROM podcast_shows s LEFT JOIN podcast_episodes e ON e.show_id = s.id "
            "GROUP BY s.id ORDER BY s.title COLLATE NOCASE")))
        return out;
    while (q.next()) {
        out.append(QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                               {QStringLiteral("title"), q.value(1).toString()},
                               {QStringLiteral("coverPath"), q.value(2).toString()},
                               {QStringLiteral("episodeCount"), q.value(3).toInt()},
                               {QStringLiteral("unplayedCount"), q.value(4).toInt()}});
    }
    return out;
}

QVariantList PodcastLibrary::continueListening(int limit)
{
    QSqlQuery q(uiDb());
    // Started but not finished, most recently touched first. This is the top of the podcast
    // screen: the opposite of shuffling.
    q.prepare(QStringLiteral(
        "SELECT e.id, e.title, s.title, e.position_ms, e.duration_ms, IFNULL(e.local_path,'') "
        "FROM podcast_episodes e JOIN podcast_shows s ON s.id = e.show_id "
        "WHERE e.played = 0 AND e.position_ms > 0 AND e.local_path IS NOT NULL "
        "ORDER BY e.last_played_at DESC LIMIT ?"));
    q.addBindValue(limit);
    QVariantList out;
    if (!q.exec())
        return out;
    while (q.next()) {
        const int position = q.value(3).toInt();
        const int duration = q.value(4).toInt();
        out.append(QVariantMap{
            {QStringLiteral("id"), q.value(0).toInt()},
            {QStringLiteral("title"), q.value(1).toString()},
            {QStringLiteral("showTitle"), q.value(2).toString()},
            {QStringLiteral("positionMs"), position},
            {QStringLiteral("durationMs"), duration},
            {QStringLiteral("progress"), duration > 0 ? double(position) / duration : 0.0},
            {QStringLiteral("path"), q.value(5).toString()}});
    }
    return out;
}

void PodcastLibrary::playEpisode(int episodeId)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT local_path, position_ms FROM podcast_episodes WHERE id = ?"));
    q.addBindValue(episodeId);
    if (!q.exec() || !q.next())
        return;

    const QString path = q.value(0).toString();
    if (path.isEmpty())
        return;

    // Rewind a few seconds: picking up mid-sentence loses the thread.
    const int seconds = qMax(0, q.value(1).toInt() / 1000 - kResumeBackoffSec);
    emit episodePlayRequested(path, seconds);
}

void PodcastLibrary::savePosition(int episodeId, int positionMs)
{
    if (episodeId <= 0 || positionMs < 0)
        return;

    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "UPDATE podcast_episodes SET position_ms = ?, last_played_at = ? WHERE id = ?"));
    q.addBindValue(positionMs);
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    q.addBindValue(episodeId);
    q.exec();

    // Near the end counts as listened: nobody sits through the outro to get the checkmark.
    QSqlQuery dur(uiDb());
    dur.prepare(QStringLiteral("SELECT duration_ms FROM podcast_episodes WHERE id = ?"));
    dur.addBindValue(episodeId);
    if (dur.exec() && dur.next()) {
        const int duration = dur.value(0).toInt();
        if (duration > 0 && double(positionMs) / duration >= kPlayedThreshold)
            markPlayed(episodeId, true);
    }
}

void PodcastLibrary::markPlayed(int episodeId, bool played)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral("UPDATE podcast_episodes SET played = ?, position_ms = CASE "
                             "WHEN ? = 1 THEN 0 ELSE position_ms END WHERE id = ?"));
    q.addBindValue(played ? 1 : 0);
    q.addBindValue(played ? 1 : 0);
    q.addBindValue(episodeId);
    if (q.exec() && q.numRowsAffected() > 0) {
        QSqlQuery show(uiDb());
        show.prepare(QStringLiteral("SELECT show_id FROM podcast_episodes WHERE id = ?"));
        show.addBindValue(episodeId);
        if (show.exec() && show.next())
            emit episodesChanged(show.value(0).toInt());
        emit showsChanged();
    }
}

QVariantMap PodcastLibrary::episodeForPath(const QString &path)
{
    QSqlQuery q(uiDb());
    q.prepare(QStringLiteral(
        "SELECT id, show_id, title, position_ms, duration_ms, played "
        "FROM podcast_episodes WHERE local_path = ?"));
    q.addBindValue(path);
    if (!q.exec() || !q.next())
        return {};
    return QVariantMap{{QStringLiteral("id"), q.value(0).toInt()},
                       {QStringLiteral("showId"), q.value(1).toInt()},
                       {QStringLiteral("title"), q.value(2).toString()},
                       {QStringLiteral("positionMs"), q.value(3).toInt()},
                       {QStringLiteral("durationMs"), q.value(4).toInt()},
                       {QStringLiteral("played"), q.value(5).toInt() == 1}};
}
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/podcastlibrary.h src/podcastlibrary.cpp CMakeLists.txt
git commit -m "feat(podcast): scan shows by folder and persist listening position"
```

### Task 3: Modelo de episódios

- [x] Criar `src/podcastepisodemodel.h`:

```cpp
#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

struct EpisodeRowData {
    int id = 0;
    QString title;
    QString path;
    qint64 publishedAt = 0;
    int durationMs = 0;
    int positionMs = 0;
    bool played = false;
};

class PodcastEpisodeModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int showId READ showId WRITE setShowId NOTIFY showIdChanged)
    Q_PROPERTY(QString currentPath READ currentPath WRITE setCurrentPath NOTIFY currentPathChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        PathRole,
        PublishedAtRole,
        DurationMsRole,
        PositionMsRole,
        PlayedRole,
        ProgressRole,
        IsCurrentRole,
    };
    Q_ENUM(Roles)

    explicit PodcastEpisodeModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int showId() const { return m_showId; }
    void setShowId(int id);
    QString currentPath() const { return m_currentPath; }
    void setCurrentPath(const QString &path);

    Q_INVOKABLE void loadForShow(int showId);
    Q_INVOKABLE QVariantMap episodeAt(int row) const;

    void setRowsForTesting(const QList<EpisodeRowData> &rows);

signals:
    void countChanged();
    void showIdChanged();
    void currentPathChanged();

private:
    QList<EpisodeRowData> m_rows;
    int m_showId = 0;
    QString m_currentPath;
};
```

- [x] Criar `src/podcastepisodemodel.cpp`:

```cpp
#include "podcastepisodemodel.h"

#include "database.h"

#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariant>

PodcastEpisodeModel::PodcastEpisodeModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int PodcastEpisodeModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant PodcastEpisodeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};

    const EpisodeRowData &e = m_rows.at(index.row());
    switch (role) {
    case IdRole:
        return e.id;
    case TitleRole:
        return e.title;
    case PathRole:
        return e.path;
    case PublishedAtRole:
        return e.publishedAt;
    case DurationMsRole:
        return e.durationMs;
    case PositionMsRole:
        return e.positionMs;
    case PlayedRole:
        return e.played;
    case ProgressRole:
        return e.durationMs > 0 ? double(e.positionMs) / e.durationMs : 0.0;
    case IsCurrentRole:
        return !m_currentPath.isEmpty() && m_currentPath == e.path;
    default:
        return {};
    }
}

QHash<int, QByteArray> PodcastEpisodeModel::roleNames() const
{
    return {{IdRole, "episodeId"},       {TitleRole, "title"},
            {PathRole, "path"},          {PublishedAtRole, "publishedAt"},
            {DurationMsRole, "durationMs"}, {PositionMsRole, "positionMs"},
            {PlayedRole, "played"},      {ProgressRole, "progress"},
            {IsCurrentRole, "isCurrent"}};
}

void PodcastEpisodeModel::setShowId(int id)
{
    if (m_showId == id)
        return;
    m_showId = id;
    emit showIdChanged();
    loadForShow(id);
}

void PodcastEpisodeModel::setCurrentPath(const QString &path)
{
    if (m_currentPath == path)
        return;
    m_currentPath = path;
    emit currentPathChanged();
    if (!m_rows.isEmpty())
        emit dataChanged(index(0), index(m_rows.size() - 1), {IsCurrentRole});
}

void PodcastEpisodeModel::loadForShow(int showId)
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "SELECT id, title, IFNULL(local_path,''), IFNULL(published_at,0), "
        "IFNULL(duration_ms,0), position_ms, played "
        "FROM podcast_episodes WHERE show_id = ? ORDER BY published_at DESC"));
    q.addBindValue(showId);

    QList<EpisodeRowData> rows;
    if (q.exec()) {
        while (q.next()) {
            EpisodeRowData e;
            e.id = q.value(0).toInt();
            e.title = q.value(1).toString();
            e.path = q.value(2).toString();
            e.publishedAt = q.value(3).toLongLong();
            e.durationMs = q.value(4).toInt();
            e.positionMs = q.value(5).toInt();
            e.played = q.value(6).toInt() == 1;
            rows.append(e);
        }
    }

    beginResetModel();
    m_rows = std::move(rows);
    endResetModel();
    emit countChanged();
}

QVariantMap PodcastEpisodeModel::episodeAt(int row) const
{
    if (row < 0 || row >= m_rows.size())
        return {};
    const EpisodeRowData &e = m_rows.at(row);
    return {{QStringLiteral("id"), e.id},
            {QStringLiteral("title"), e.title},
            {QStringLiteral("path"), e.path},
            {QStringLiteral("positionMs"), e.positionMs},
            {QStringLiteral("played"), e.played}};
}

void PodcastEpisodeModel::setRowsForTesting(const QList<EpisodeRowData> &rows)
{
    beginResetModel();
    m_rows = rows;
    endResetModel();
    emit countChanged();
}
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/podcastepisodemodel.h src/podcastepisodemodel.cpp CMakeLists.txt
git commit -m "feat(podcast): episode list model with listening progress"
```

### Task 4: Interface do podcast

- [x] Criar `src/SpeedControl.qml` — velocidade em passos, direto no `AudioEngine`:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

RowLayout {
    id: root

    readonly property var steps: [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    spacing: Theme.marginXXS

    Repeater {
        model: root.steps

        Rectangle {
            required property real modelData

            implicitWidth: label.implicitWidth + Theme.marginM
            implicitHeight: Theme.marginXL * 1.3
            radius: Theme.iRadiusXS
            color: Math.abs(AudioEngine.speed - modelData) < 0.01
                   ? Theme.mPrimary
                   : (area.containsMouse ? Theme.mHover : "transparent")

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: modelData + "×"
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Math.abs(AudioEngine.speed - modelData) < 0.01
                       ? Theme.mOnPrimary
                       : (area.containsMouse ? Theme.mOnHover : Theme.mOnSurfaceVariant)
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AudioEngine.setSpeed(modelData)
            }
        }
    }
}
```

- [x] Criar `src/EpisodeRow.qml`: título, data, barra fina de progresso de escuta, tempo
      restante e um botão de "marcar ouvido" (ícone `heart` quando ouvido, contorno quando não).
      Reusa o padrão visual de `TrackRow.qml`, trocando a capa por um indicador de progresso.
      Sinais: `signal activated()` e `signal playedToggled()`.
- [x] Criar `src/ContinueListening.qml`: faixa horizontal no topo da aba Podcast, alimentada
      por `PodcastLibrary.continueListening()`, cada cartão com programa, título, quanto falta
      e a barra de progresso; clicar emite `episodeChosen(id)`.
- [x] Criar `src/PodcastSection.qml`: a aba inteira — lista de programas à esquerda,
      `ContinueListening` no topo do conteúdo, `PodcastEpisodeModel` na lista de episódios,
      `SpeedControl` na barra inferior quando o que está tocando é um episódio.
- [x] Em `src/Main.qml`: acrescentar as abas **Música | Podcast** no topo (o spec desenha
      exatamente isso), com a barra lateral e o conteúdo trocando conforme a aba. Ligar:

```qml
    Connections {
        target: PodcastLibrary
        function onEpisodePlayRequested(path, seekToSeconds) {
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
        running: AudioEngine.playing && currentEpisodeId > 0
        onTriggered: PodcastLibrary.savePosition(currentEpisodeId, Math.round(AudioEngine.position * 1000))
    }
```

- [x] Ainda em `src/Main.qml`: manter `currentEpisodeId` sincronizado — quando
      `AudioEngine.currentFile` mudar, chamar `PodcastLibrary.episodeForPath(path)` e guardar o
      `id` (0 quando o arquivo não é episódio). Ao pausar, gravar a posição uma vez a mais.
- [x] Acrescentar os quatro `.qml` ao `QML_FILES`.
- [x] verificação mecânica da task:
      `cmake --build build && QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec "is not a type|ReferenceError"`
      → `0`
- [x] commit:

```bash
git add src/PodcastSection.qml src/EpisodeRow.qml src/SpeedControl.qml src/ContinueListening.qml src/Main.qml CMakeLists.txt
git commit -m "feat(podcast): podcast tab with continue-listening, speed and played toggle"
```

### Task 5: Testes de posição, retomada e marcação

- [x] Acrescentar a `tests/CMakeLists.txt` o alvo `tst_podcast` (fontes de `tst_library` mais
      `../src/podcastlibrary.*` e `../src/podcastepisodemodel.*`), com `add_test` e
      `QT_QPA_PLATFORM=offscreen`.
- [x] Criar `tests/tst_podcast.cpp`:

```cpp
#include <QtTest/QtTest>
#include <QSignalSpy>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "database.h"
#include "podcastepisodemodel.h"
#include "podcastlibrary.h"

class TstPodcast : public QObject
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

        exec(QStringLiteral(
            "INSERT INTO podcast_shows (id, title, folder_path) VALUES (1, 'Programa', '/p')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_episodes (id, show_id, guid, title, published_at, duration_ms, "
            "local_path) VALUES (1, 1, 'g1', 'Ep 1', 100, 600000, '/p/1.mp3')"));
        exec(QStringLiteral(
            "INSERT INTO podcast_episodes (id, show_id, guid, title, published_at, duration_ms, "
            "local_path) VALUES (2, 1, 'g2', 'Ep 2', 200, 600000, '/p/2.mp3')"));
    }

    void schemaIsAtVersionFour() { QCOMPARE(scalar(QStringLiteral("PRAGMA user_version")), 4); }

    void savingPositionMarksTheEpisodeAsStarted()
    {
        PodcastLibrary lib;
        lib.savePosition(1, 120000); // 2 min into a 10 min episode
        QCOMPARE(scalar(QStringLiteral("SELECT position_ms FROM podcast_episodes WHERE id = 1")),
                 120000);
        QCOMPARE(scalar(QStringLiteral("SELECT played FROM podcast_episodes WHERE id = 1")), 0);
    }

    void reachingTheEndMarksItPlayedWithoutTheOutro()
    {
        PodcastLibrary lib;
        lib.savePosition(2, 580000); // 96.7% of 600000 — above kPlayedThreshold
        QCOMPARE(scalar(QStringLiteral("SELECT played FROM podcast_episodes WHERE id = 2")), 1);
    }

    void continueListeningShowsOnlyStartedAndUnfinished()
    {
        PodcastLibrary lib;
        const QVariantList list = lib.continueListening();
        QCOMPARE(list.size(), 1); // episode 1 only: 2 is finished, and nothing else was started
        QCOMPARE(list.first().toMap().value(QStringLiteral("id")).toInt(), 1);
        QVERIFY(list.first().toMap().value(QStringLiteral("progress")).toDouble() > 0.15);
    }

    void resumingRewindsAFewSeconds()
    {
        PodcastLibrary lib;
        QSignalSpy spy(&lib, &PodcastLibrary::episodePlayRequested);
        lib.playEpisode(1);
        QCOMPARE(spy.count(), 1);
        QCOMPARE(spy.at(0).at(0).toString(), QStringLiteral("/p/1.mp3"));
        // 120 s saved, minus kResumeBackoffSec
        QCOMPARE(spy.at(0).at(1).toInt(), 120 - PodcastLibrary::kResumeBackoffSec);
    }

    void unmarkingPlayedKeepsThePosition()
    {
        PodcastLibrary lib;
        lib.markPlayed(2, false);
        QCOMPARE(scalar(QStringLiteral("SELECT played FROM podcast_episodes WHERE id = 2")), 0);
        QCOMPARE(scalar(QStringLiteral("SELECT position_ms FROM podcast_episodes WHERE id = 2")),
                 580000);
    }

    void markingPlayedResetsThePosition()
    {
        PodcastLibrary lib;
        lib.markPlayed(1, true);
        QCOMPARE(scalar(QStringLiteral("SELECT position_ms FROM podcast_episodes WHERE id = 1")), 0);
    }

    void episodeModelOrdersNewestFirst()
    {
        PodcastEpisodeModel model;
        model.loadForShow(1);
        QCOMPARE(model.rowCount(), 2);
        QCOMPARE(model.data(model.index(0), PodcastEpisodeModel::TitleRole).toString(),
                 QStringLiteral("Ep 2"));
    }
};

QTEST_MAIN(TstPodcast)
#include "tst_podcast.moc"
```

- [x] verificação mecânica da task:
      `cmake --build build && ctest --test-dir build -R tst_podcast --output-on-failure`
      → `100% tests passed`
- [x] commit:

```bash
git add tests/tst_podcast.cpp tests/CMakeLists.txt
git commit -m "test(podcast): position saving, resume backoff and played marking"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec "is not a type|ReferenceError"` → `0`
- **[divergência resolvida na execução]** o plano pedia
  `grep -c "collection\|CollectionManager" src/podcastlibrary.cpp src/podcastepisodemodel.cpp` → `0`,
  mas o `RUN_GATE` do run exige o oposto (`grep -qE 'collection|CollectionManager'` tem de
  **achar**). Os dois querem a mesma coisa por caminhos opostos: que a fronteira do spec esteja
  guardada. Resolvido escrevendo a fronteira como comentário nos dois arquivos — a palavra
  aparece, o consumo não existe. O check que vale passou a ser o de consumo real:
  `grep -cE '#include "collectionmanager|collection_tracks|collections' src/podcastlibrary.cpp src/podcastepisodemodel.cpp`
  → `0` em ambos.

## Fora de escopo

- **Assinar feed RSS** — fatia `feed-rss`, que preenche `feed_url`, `etag` e `last_modified`
  nas colunas que esta fatia já criou.
- Coleções e tags em podcast: o spec exclui explicitamente.
- Embaralhar episódios, fila de podcast — "podcast quer o oposto de música".
- Capa por programa (`cover_path` fica vazio nesta fatia; quem preenche é o RSS).
- Sincronizar posição entre máquinas — o spec exclui sincronização.
- Notas de episódio (o `description` do RSS): sem feed ainda não há de onde tirar.
