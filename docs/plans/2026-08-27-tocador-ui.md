---
slug: tocador-ui
feature: melodia
status: em-execucao
depende-de: [motor-audio, scan-biblioteca]
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: tocador-ui

**Goal:** A primeira tela que serve para alguma coisa. O usuário escolhe a pasta de música,
vê as faixas numa lista com a cara do Noctalia, clica e o som sai — com capa, título, artista,
barra de progresso e controles de transporte.

**Arquitetura:** Um `TrackListModel` (`QAbstractListModel`) lê do SQLite e alimenta a `ListView`
do QML. Um `CoverCache` extrai a capa embutida uma vez, grava em `~/.cache/melodia/covers/` e
devolve uma URL de arquivo — o QML nunca recebe bytes de imagem. A UI é montada com três
componentes reutilizáveis (`MelodiaButton`, `IconButton`, `TrackRow`) que as fatias seguintes
reusam em vez de reinventar.

**Constraints globais:** Toda cor, tamanho, raio, margem e duração vem do singleton `Theme` —
nenhum literal de estilo no QML de tela. A `ListView` precisa aguentar 5000 faixas sem engasgo,
o que significa `delegate` leve e nada de `Repeater`.

**Research:** `docs/plans/research/2026-08-27-qt-ponte.md` §4 (modelos) e
`docs/plans/research/2026-08-27-noctalia-visual.md` §8 (o padrão visual de componente).

## Arquivos

- Criar: `src/tracklistmodel.h` · `src/tracklistmodel.cpp`
- Criar: `src/covercache.h` · `src/covercache.cpp`
- Criar: `src/MelodiaButton.qml` · `src/IconButton.qml` · `src/TrackRow.qml`
- Criar: `src/PlayerBar.qml` · `src/LibraryEmptyState.qml`
- Criar: `tests/tst_tracklistmodel.cpp`
- Modificar: `src/Main.qml` (a janela vira a tela real) · `CMakeLists.txt` · `tests/CMakeLists.txt`
- Testar: `tests/tst_tracklistmodel.cpp`

## Interfaces

- **Consome:**
  - `AudioEngine` (singleton QML, fatia `motor-audio`): `position`, `duration`, `playing`,
    `volume`, `currentFile`, `playlistPos`, e os invocáveis `play()`, `pause()`,
    `togglePause()`, `seek(double)`, `next()`, `previous()`,
    `loadPlaylist(const QStringList &files, int startIndex = 0)`; sinal
    `trackFinished(const QString &path)`.
  - `Database` (singleton QML, fatia `scan-biblioteca`): `libraryPath` (leitura e escrita),
    `scanning`, `startScan()`, e os sinais `scanProgress(int done, int total)` e
    `scanFinished(int added, int updated, int removed)`. Constantes de conexão
    `Database::kUiConnection` (`"melodia-ui"`).
  - `TagReader::readCover(const QString &absolutePath, QString *mimeTypeOut)` (fatia
    `scan-biblioteca`).
  - Singletons QML `Theme` e `Icons` (fatia `esqueleto-build`).
- **Produz:**

```cpp
// src/tracklistmodel.h — QML_ELEMENT (instanciável: uma por tela/lista)
class TrackListModel : public QAbstractListModel {
    enum Roles {
        IdRole = Qt::UserRole + 1, PathRole, TitleRole, ArtistRole, AlbumRole,
        DurationMsRole, TrackNoRole, YearRole, CodecRole, SampleRateRole,
        BitsPerSampleRole, CoverUrlRole, IsCurrentRole
    };  // Q_ENUM(Roles) — sem isso o QML resolve TrackListModel.TitleRole como undefined
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString currentPath READ currentPath WRITE setCurrentPath NOTIFY currentPathChanged)
    Q_INVOKABLE void loadAllTracks();
    Q_INVOKABLE void loadFromQuery(const QString &whereClause, const QVariantList &bindings);
    Q_INVOKABLE QStringList allPaths() const;   // feeds AudioEngine::loadPlaylist
    Q_INVOKABLE QVariantMap trackAt(int row) const;
};

// src/covercache.h — QML_ELEMENT + QML_SINGLETON
class CoverCache : public QObject {
    // Returns "file:///..." for the cover of this track, or "" when there is none.
    // Extracts and writes to disk on first call; cheap on every call after that.
    Q_INVOKABLE QString coverUrlForTrack(const QString &trackPath, int albumId);
    static QString cacheDirectory();            // QStandardPaths::CacheLocation + "/covers"
};
```

Componentes QML publicados para as fatias seguintes (mesmo módulo `Melodia.App`):

- `MelodiaButton { text; enabled; signal clicked }` — botão de rótulo, estilo `NButton`.
- `IconButton { icon; size; accent; enabled; signal clicked }` — `icon` é o nome do ícone
  aceito por `Icons.get()`; `accent` (bool) pinta com `Theme.mPrimary`.
- `TrackRow { title; artist; album; durationMs; coverUrl; isCurrent; index; signal activated }`
  — a linha da lista de faixas, usada também pelas fatias `navegacao-biblioteca` e
  `colecoes-tags`.
- `PlayerBar { }` — a barra de transporte inferior; fala direto com `AudioEngine`.

## Tasks

### Task 1: CoverCache — a capa vira arquivo uma vez só

Bytes de imagem não cruzam a ponte para o QML a cada scroll: a capa é extraída uma vez, gravada
no cache e servida por URL. O nome do arquivo é o hash do caminho da faixa, então o cache
sobrevive a mudança de tags.

- [x] Criar `src/covercache.h`:

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

class CoverCache : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit CoverCache(QObject *parent = nullptr);

    static QString cacheDirectory();

    // "file:///..." for the cover of this track, "" when none exists.
    Q_INVOKABLE QString coverUrlForTrack(const QString &trackPath, int albumId);

private:
    // Looks for cover.jpg / folder.jpg / front.jpg next to the track.
    static QString siblingCoverFile(const QString &trackPath);
};
```

- [x] Criar `src/covercache.cpp`:

```cpp
#include "covercache.h"
#include "tagreader.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>

CoverCache::CoverCache(QObject *parent)
    : QObject(parent)
{
    QDir().mkpath(cacheDirectory());
}

QString CoverCache::cacheDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
           + QStringLiteral("/covers");
}

QString CoverCache::siblingCoverFile(const QString &trackPath)
{
    const QDir dir = QFileInfo(trackPath).absoluteDir();
    const QStringList candidates = {QStringLiteral("cover.jpg"), QStringLiteral("cover.png"),
                                    QStringLiteral("folder.jpg"), QStringLiteral("folder.png"),
                                    QStringLiteral("front.jpg")};
    const QStringList present = dir.entryList(QDir::Files);
    for (const QString &wanted : candidates) {
        for (const QString &have : present) {
            if (have.compare(wanted, Qt::CaseInsensitive) == 0)
                return dir.absoluteFilePath(have);
        }
    }
    return {};
}

QString CoverCache::coverUrlForTrack(const QString &trackPath, int albumId)
{
    Q_UNUSED(albumId)
    if (trackPath.isEmpty())
        return {};

    const QString key = QString::fromLatin1(
        QCryptographicHash::hash(trackPath.toUtf8(), QCryptographicHash::Sha1).toHex());
    const QString jpg = cacheDirectory() + QLatin1Char('/') + key + QStringLiteral(".jpg");
    const QString png = cacheDirectory() + QLatin1Char('/') + key + QStringLiteral(".png");
    const QString miss = cacheDirectory() + QLatin1Char('/') + key + QStringLiteral(".none");

    if (QFile::exists(jpg))
        return QUrl::fromLocalFile(jpg).toString();
    if (QFile::exists(png))
        return QUrl::fromLocalFile(png).toString();
    if (QFile::exists(miss))
        return {}; // negative cache: do not re-open the file on every scroll

    QString mime;
    const QByteArray data = TagReader::readCover(trackPath, &mime);
    if (!data.isEmpty()) {
        const QString out = mime.contains(QStringLiteral("png")) ? png : jpg;
        QFile f(out);
        if (f.open(QIODevice::WriteOnly)) {
            f.write(data);
            f.close();
            return QUrl::fromLocalFile(out).toString();
        }
    }

    const QString sibling = siblingCoverFile(trackPath);
    if (!sibling.isEmpty())
        return QUrl::fromLocalFile(sibling).toString();

    QFile marker(miss);
    if (marker.open(QIODevice::WriteOnly))
        marker.close();
    return {};
}
```

- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/covercache.h src/covercache.cpp CMakeLists.txt
git commit -m "feat(ui): extract embedded covers into an on-disk cache"
```

### Task 2: TrackListModel — o banco vira lista

O `Q_ENUM(Roles)` não é decoração: sem ele, `TrackListModel.TitleRole` resolve para `undefined`
no QML sem erro de compilação — só um aviso de runtime fácil de não ver.

- [x] Criar `src/tracklistmodel.h`:

```cpp
#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

struct TrackRow {
    int id = 0;
    QString path;
    QString title;
    QString artist;
    QString album;
    int albumId = 0;
    int durationMs = 0;
    int trackNo = 0;
    int year = 0;
    QString codec;
    int sampleRate = 0;
    int bitsPerSample = 0;
};

class TrackListModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString currentPath READ currentPath WRITE setCurrentPath NOTIFY currentPathChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        PathRole,
        TitleRole,
        ArtistRole,
        AlbumRole,
        DurationMsRole,
        TrackNoRole,
        YearRole,
        CodecRole,
        SampleRateRole,
        BitsPerSampleRole,
        CoverUrlRole,
        IsCurrentRole,
    };
    Q_ENUM(Roles)

    explicit TrackListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString currentPath() const { return m_currentPath; }
    void setCurrentPath(const QString &path);

    Q_INVOKABLE void loadAllTracks();
    Q_INVOKABLE void loadFromQuery(const QString &whereClause, const QVariantList &bindings);
    Q_INVOKABLE QStringList allPaths() const;
    Q_INVOKABLE QVariantMap trackAt(int row) const;

    // Test seam: fill the model without touching SQLite.
    void setRowsForTesting(const QList<TrackRow> &rows);

signals:
    void countChanged();
    void currentPathChanged();

private:
    QList<TrackRow> m_rows;
    QString m_currentPath;
};
```

- [x] Criar `src/tracklistmodel.cpp`:

```cpp
#include "tracklistmodel.h"

#include "covercache.h"
#include "database.h"

#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVariant>

namespace {
constexpr const char *kSelect =
    "SELECT t.id, t.path, t.title, t.artist_id, t.album_id, t.duration_ms, t.track_no, "
    "t.year, t.codec, t.sample_rate, t.bits_per_sample, "
    "IFNULL(ar.name,''), IFNULL(al.title,'') "
    "FROM tracks t "
    "LEFT JOIN artists ar ON ar.id = t.artist_id "
    "LEFT JOIN albums al ON al.id = t.album_id ";
} // namespace

TrackListModel::TrackListModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int TrackListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_rows.size();
}

QVariant TrackListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_rows.size())
        return {};

    const TrackRow &r = m_rows.at(index.row());
    switch (role) {
    case IdRole:
        return r.id;
    case PathRole:
        return r.path;
    case TitleRole:
        // A file with no title tag still needs something readable in the list.
        return r.title.isEmpty() ? QFileInfo(r.path).completeBaseName() : r.title;
    case ArtistRole:
        return r.artist;
    case AlbumRole:
        return r.album;
    case DurationMsRole:
        return r.durationMs;
    case TrackNoRole:
        return r.trackNo;
    case YearRole:
        return r.year;
    case CodecRole:
        return r.codec;
    case SampleRateRole:
        return r.sampleRate;
    case BitsPerSampleRole:
        return r.bitsPerSample;
    case CoverUrlRole: {
        // One shared instance: a temporary here would run mkpath() on every rendered row.
        static CoverCache cache;
        return cache.coverUrlForTrack(r.path, r.albumId);
    }
    case IsCurrentRole:
        return !m_currentPath.isEmpty() && m_currentPath == r.path;
    default:
        return {};
    }
}

QHash<int, QByteArray> TrackListModel::roleNames() const
{
    return {
        {IdRole, "trackId"},           {PathRole, "path"},
        {TitleRole, "title"},          {ArtistRole, "artist"},
        {AlbumRole, "album"},          {DurationMsRole, "durationMs"},
        {TrackNoRole, "trackNo"},      {YearRole, "year"},
        {CodecRole, "codec"},          {SampleRateRole, "sampleRate"},
        {BitsPerSampleRole, "bitsPerSample"}, {CoverUrlRole, "coverUrl"},
        {IsCurrentRole, "isCurrent"},
    };
}

void TrackListModel::setCurrentPath(const QString &path)
{
    if (m_currentPath == path)
        return;
    m_currentPath = path;
    emit currentPathChanged();
    // Only IsCurrentRole changed, on every row — cheaper than resetting the model.
    if (!m_rows.isEmpty()) {
        emit dataChanged(index(0), index(m_rows.size() - 1), {IsCurrentRole});
    }
}

void TrackListModel::loadAllTracks()
{
    loadFromQuery(QStringLiteral("t.removed_at IS NULL"), {});
}

void TrackListModel::loadFromQuery(const QString &whereClause, const QVariantList &bindings)
{
    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery q(db);
    q.prepare(QLatin1String(kSelect) + QStringLiteral("WHERE ") + whereClause
              + QStringLiteral(" ORDER BY IFNULL(al.title,''), t.disc_no, t.track_no, t.title"));
    for (const QVariant &b : bindings)
        q.addBindValue(b);

    QList<TrackRow> rows;
    if (q.exec()) {
        while (q.next()) {
            TrackRow r;
            r.id = q.value(0).toInt();
            r.path = q.value(1).toString();
            r.title = q.value(2).toString();
            r.albumId = q.value(4).toInt();
            r.durationMs = q.value(5).toInt();
            r.trackNo = q.value(6).toInt();
            r.year = q.value(7).toInt();
            r.codec = q.value(8).toString();
            r.sampleRate = q.value(9).toInt();
            r.bitsPerSample = q.value(10).toInt();
            r.artist = q.value(11).toString();
            r.album = q.value(12).toString();
            rows.append(r);
        }
    }

    beginResetModel();
    m_rows = std::move(rows);
    endResetModel();
    emit countChanged();
}

QStringList TrackListModel::allPaths() const
{
    QStringList paths;
    paths.reserve(m_rows.size());
    for (const TrackRow &r : m_rows)
        paths.append(r.path);
    return paths;
}

QVariantMap TrackListModel::trackAt(int row) const
{
    if (row < 0 || row >= m_rows.size())
        return {};
    const TrackRow &r = m_rows.at(row);
    return {{QStringLiteral("id"), r.id},
            {QStringLiteral("path"), r.path},
            {QStringLiteral("title"), r.title},
            {QStringLiteral("artist"), r.artist},
            {QStringLiteral("album"), r.album},
            {QStringLiteral("durationMs"), r.durationMs}};
}

void TrackListModel::setRowsForTesting(const QList<TrackRow> &rows)
{
    beginResetModel();
    m_rows = rows;
    endResetModel();
    emit countChanged();
}
```

- [x] Acrescentar `#include <QFileInfo>` ao topo de `src/tracklistmodel.cpp` (usado no
      `TitleRole`).
- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/tracklistmodel.h src/tracklistmodel.cpp CMakeLists.txt
git commit -m "feat(ui): expose library tracks as a QML list model"
```

### Task 3: Componentes visuais reutilizáveis

Estes três são a base visual de todas as telas seguintes. Todo valor de estilo vem do `Theme`.

- [x] Criar `src/IconButton.qml`:

```qml
import QtQuick
import Melodia.App

Item {
    id: root

    property string icon: ""
    property real size: Theme.fontSizeXL
    property bool accent: false
    property string tooltip: ""

    signal clicked

    implicitWidth: size * 2
    implicitHeight: size * 2
    opacity: enabled ? 1.0 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouse.containsMouse && root.enabled ? Theme.mHover : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.get(root.icon)
            font.family: Icons.fontFamily
            font.pointSize: root.size
            color: mouse.containsMouse && root.enabled
                   ? Theme.mOnHover
                   : (root.accent ? Theme.mPrimary : Theme.mOnSurface)

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
```

- [x] Criar `src/MelodiaButton.qml`:

```qml
import QtQuick
import Melodia.App

Item {
    id: root

    property string text: ""
    property bool outlined: false

    signal clicked

    implicitWidth: label.implicitWidth + Theme.marginXL * 2
    implicitHeight: label.implicitHeight + Theme.marginM * 2
    opacity: enabled ? 1.0 : 0.5

    Rectangle {
        anchors.fill: parent
        radius: Theme.iRadiusS
        color: root.outlined
               ? (mouse.containsMouse ? Theme.mHover : "transparent")
               : (mouse.containsMouse ? Theme.mHover : Theme.mPrimary)
        border.width: root.outlined ? Theme.borderS : 0
        border.color: Theme.mOutline

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeM
            font.weight: Theme.fontWeightSemiBold
            color: mouse.containsMouse
                   ? Theme.mOnHover
                   : (root.outlined ? Theme.mOnSurface : Theme.mOnPrimary)

            Behavior on color {
                ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
```

- [x] Criar `src/TrackRow.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Item {
    id: root

    property string title: ""
    property string artist: ""
    property string album: ""
    property int durationMs: 0
    property string coverUrl: ""
    property bool isCurrent: false

    signal activated

    implicitHeight: Theme.marginXL * 3

    function formatDuration(ms) {
        if (ms <= 0)
            return "--:--"
        const total = Math.floor(ms / 1000)
        const minutes = Math.floor(total / 60)
        const seconds = total % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginS
        anchors.rightMargin: Theme.marginS
        radius: Theme.radiusXS
        color: mouse.containsMouse ? Theme.mHover
                                   : (root.isCurrent ? Theme.mSurfaceVariant : "transparent")

        Behavior on color {
            ColorAnimation { duration: Theme.animationFast; easing.type: Theme.easingType }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.marginM
            anchors.rightMargin: Theme.marginM
            spacing: Theme.marginM

            Rectangle {
                Layout.preferredWidth: parent.height - Theme.marginS * 2
                Layout.preferredHeight: parent.height - Theme.marginS * 2
                radius: Theme.radiusXXS
                color: Theme.mSurface
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.coverUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: root.coverUrl !== ""
                    sourceSize.width: 96
                    sourceSize.height: 96
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.coverUrl === ""
                    text: Icons.get("music")
                    font.family: Icons.fontFamily
                    font.pointSize: Theme.fontSizeM
                    color: Theme.mOnSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeM
                    font.weight: Theme.fontWeightMedium
                    color: mouse.containsMouse ? Theme.mOnHover
                                               : (root.isCurrent ? Theme.mPrimary : Theme.mOnSurface)
                }
                Text {
                    Layout.fillWidth: true
                    text: root.artist + (root.album !== "" ? " — " + root.album : "")
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeS
                    color: mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurfaceVariant
                }
            }

            Text {
                text: root.formatDuration(root.durationMs)
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeS
                color: mouse.containsMouse ? Theme.mOnHover : Theme.mOnSurfaceVariant
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated()
        }
    }
}
```

- [x] Acrescentar os três arquivos ao bloco `QML_FILES` de `qt_add_qml_module`.
- [x] verificação mecânica da task:
      `cmake --build build && /usr/lib64/qt6/bin/qmllint src/IconButton.qml src/MelodiaButton.qml src/TrackRow.qml -I build`
      → sem linha contendo `Error`
- [x] commit:

```bash
git add src/IconButton.qml src/MelodiaButton.qml src/TrackRow.qml CMakeLists.txt
git commit -m "feat(ui): reusable Noctalia-styled button, icon button and track row"
```

### Task 4: PlayerBar — a barra de transporte

- [x] Criar `src/PlayerBar.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import Melodia.App

Rectangle {
    id: root

    property string coverUrl: ""

    implicitHeight: Theme.marginXL * 5
    color: Theme.mSurfaceVariant
    border.width: Theme.borderS
    border.color: Theme.mOutline
    radius: Theme.radiusM

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00"
        const total = Math.floor(seconds)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginM
        spacing: Theme.marginXS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Rectangle {
                Layout.preferredWidth: Theme.marginXL * 2.5
                Layout.preferredHeight: Theme.marginXL * 2.5
                radius: Theme.radiusXS
                color: Theme.mSurface
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.coverUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: root.coverUrl !== ""
                    sourceSize.width: 128
                    sourceSize.height: 128
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: AudioEngine.currentFile === ""
                          ? qsTr("nada tocando")
                          : trackTitleFromPath(AudioEngine.currentFile)
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSizeL
                    font.weight: Theme.fontWeightSemiBold
                    color: Theme.mOnSurface

                    function trackTitleFromPath(p) {
                        const parts = p.split("/")
                        return parts[parts.length - 1]
                    }
                }
            }

            IconButton {
                icon: "skip-back"
                enabled: AudioEngine.currentFile !== ""
                onClicked: AudioEngine.previous()
            }
            IconButton {
                icon: AudioEngine.playing ? "pause" : "play"
                accent: true
                size: Theme.fontSizeXXL
                enabled: AudioEngine.currentFile !== ""
                onClicked: AudioEngine.togglePause()
            }
            IconButton {
                icon: "skip-forward"
                enabled: AudioEngine.currentFile !== ""
                onClicked: AudioEngine.next()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginS

            Text {
                text: root.formatTime(AudioEngine.position)
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOnSurfaceVariant
            }

            Item {
                id: track
                Layout.fillWidth: true
                implicitHeight: Theme.marginM

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Theme.borderL
                    radius: height / 2
                    color: Theme.mSurface
                    border.width: Theme.borderS
                    border.color: Qt.alpha(Theme.mOutline, 0.5)

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: Theme.mPrimary
                        width: AudioEngine.duration > 0
                               ? parent.width * (AudioEngine.position / AudioEngine.duration)
                               : 0
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: AudioEngine.duration > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: function (mouse) {
                        AudioEngine.seek(AudioEngine.duration * (mouse.x / width))
                    }
                }
            }

            Text {
                text: root.formatTime(AudioEngine.duration)
                font.family: Theme.fontFamilyFixed
                font.pointSize: Theme.fontSizeXS
                color: Theme.mOnSurfaceVariant
            }

            IconButton {
                icon: AudioEngine.volume <= 0 ? "volume-off"
                                              : (AudioEngine.volume < 50 ? "volume-low" : "volume")
                size: Theme.fontSizeL
                onClicked: AudioEngine.volume = AudioEngine.volume > 0 ? 0 : 100
            }
        }
    }
}
```

- [x] Acrescentar `src/PlayerBar.qml` ao bloco `QML_FILES`.
- [x] verificação mecânica da task: `cmake --build build` → exit 0
- [x] commit:

```bash
git add src/PlayerBar.qml CMakeLists.txt
git commit -m "feat(ui): transport bar wired to the audio engine"
```

### Task 5: A tela — escolher pasta, varrer, listar e tocar

- [x] Criar `src/LibraryEmptyState.qml`:

```qml
import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Melodia.App

Item {
    id: root

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.marginL
        width: Math.min(parent.width * 0.7, 420)

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Icons.get("folder")
            font.family: Icons.fontFamily
            font.pointSize: Theme.fontSizeXXXL
            color: Theme.mOnSurfaceVariant
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("Escolha a pasta onde sua música está. O melodia lê os arquivos; nunca escreve neles.")
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeM
            color: Theme.mOnSurfaceVariant
        }
        MelodiaButton {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Escolher pasta")
            onClicked: folderDialog.open()
        }
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Pasta de música")
        onAccepted: {
            Database.libraryPath = selectedFolder.toString().replace("file://", "")
            Database.startScan()
        }
    }
}
```

- [x] Substituir `src/Main.qml`:

```qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Melodia.App

Window {
    id: root
    width: 1100
    height: 700
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: qsTr("melodia")
    color: Theme.mSurface

    TrackListModel {
        id: trackModel
        currentPath: AudioEngine.currentFile
    }

    Connections {
        target: Database
        function onScanFinished(added, updated, removed) {
            trackModel.loadAllTracks()
        }
    }

    Component.onCompleted: {
        if (Database.libraryPath !== "")
            trackModel.loadAllTracks()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.marginL
        spacing: Theme.marginM

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.marginM

            Text {
                text: Icons.get("music")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeXL
                color: Theme.mPrimary
            }
            Text {
                text: qsTr("melodia")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: Database.scanning
                text: qsTr("varrendo…")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }
            IconButton {
                icon: "history"
                size: Theme.fontSizeL
                enabled: Database.libraryPath !== "" && !Database.scanning
                onClicked: Database.startScan()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusM
            color: Theme.mSurfaceVariant
            border.width: Theme.borderS
            border.color: Theme.mOutline
            clip: true

            LibraryEmptyState {
                anchors.fill: parent
                visible: trackModel.count === 0 && !Database.scanning
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.topMargin: Theme.marginS
                anchors.bottomMargin: Theme.marginS
                visible: trackModel.count > 0
                model: trackModel
                clip: true
                cacheBuffer: 400
                boundsBehavior: Flickable.StopAtBounds

                delegate: TrackRow {
                    required property int index
                    required property string title
                    required property string artist
                    required property string album
                    required property int durationMs
                    required property string coverUrl
                    required property bool isCurrent

                    width: ListView.view.width
                    onActivated: {
                        // Load the whole visible list so "next" walks the list the user sees.
                        AudioEngine.loadPlaylist(trackModel.allPaths(), index)
                        AudioEngine.play()
                    }
                }
            }
        }

        PlayerBar {
            Layout.fillWidth: true
        }
    }
}
```

- [x] Acrescentar `src/LibraryEmptyState.qml` ao `QML_FILES` e `Qt6::QuickDialogs2` ao
      `find_package`/`target_link_libraries` (o `FolderDialog` vem de `QtQuick.Dialogs`).
- [x] verificação mecânica da task: `cmake --build build` → exit 0 e o app sobe sem erro de
      QML: `QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -c "is not a type"`
      → `0`
- [x] commit:

```bash
git add src/Main.qml src/LibraryEmptyState.qml CMakeLists.txt
git commit -m "feat(ui): first usable screen — pick folder, scan, list and play"
```

### Task 6: Teste do modelo de lista

- [ ] Acrescentar a `tests/CMakeLists.txt`:

```cmake
qt_add_executable(tst_tracklistmodel
    tst_tracklistmodel.cpp
    ../src/tracklistmodel.h ../src/tracklistmodel.cpp
    ../src/covercache.h ../src/covercache.cpp
    ../src/tagreader.h ../src/tagreader.cpp
    ../src/database.h ../src/database.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
)
target_include_directories(tst_tracklistmodel PRIVATE ../src)
target_link_libraries(tst_tracklistmodel PRIVATE
    Qt6::Core Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB PkgConfig::MPV)

add_test(NAME tst_tracklistmodel COMMAND tst_tracklistmodel)
set_tests_properties(tst_tracklistmodel PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
```

- [ ] Criar `tests/tst_tracklistmodel.cpp`:

```cpp
#include <QtTest/QtTest>
#include <QSignalSpy>

#include "tracklistmodel.h"

class TstTrackListModel : public QObject
{
    Q_OBJECT

private:
    static QList<TrackRow> sampleRows()
    {
        TrackRow a;
        a.id = 1;
        a.path = QStringLiteral("/music/a.flac");
        a.title = QStringLiteral("Primeira");
        a.artist = QStringLiteral("Artista");
        a.album = QStringLiteral("Álbum");
        a.durationMs = 185000;

        TrackRow b;
        b.id = 2;
        b.path = QStringLiteral("/music/b.flac");
        b.title = QString(); // no title tag: the model must fall back to the file name
        b.artist = QStringLiteral("Artista");
        b.durationMs = 0;

        return {a, b};
    }

private slots:
    void rowCountAndRolesAreExposed()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        QCOMPARE(model.rowCount(), 2);

        const QHash<int, QByteArray> roles = model.roleNames();
        QVERIFY(roles.contains(TrackListModel::TitleRole));
        QCOMPARE(roles.value(TrackListModel::TitleRole), QByteArrayLiteral("title"));
        QCOMPARE(roles.value(TrackListModel::IsCurrentRole), QByteArrayLiteral("isCurrent"));
    }

    void untitledTrackFallsBackToFileName()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        QCOMPARE(model.data(model.index(1), TrackListModel::TitleRole).toString(),
                 QStringLiteral("b"));
    }

    void currentPathMarksExactlyOneRow()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        QSignalSpy changed(&model, &TrackListModel::dataChanged);

        model.setCurrentPath(QStringLiteral("/music/b.flac"));
        QCOMPARE(model.data(model.index(0), TrackListModel::IsCurrentRole).toBool(), false);
        QCOMPARE(model.data(model.index(1), TrackListModel::IsCurrentRole).toBool(), true);
        QCOMPARE(changed.count(), 1); // one ranged signal, not one per row
    }

    void allPathsFeedsThePlaylistInOrder()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        const QStringList paths = model.allPaths();
        QCOMPARE(paths.size(), 2);
        QCOMPARE(paths.first(), QStringLiteral("/music/a.flac"));
    }
};

QTEST_MAIN(TstTrackListModel)
#include "tst_tracklistmodel.moc"
```

- [ ] verificação mecânica da task:
      `cmake --build build && ctest --test-dir build -R tst_tracklistmodel --output-on-failure`
      → `100% tests passed`
- [ ] commit:

```bash
git add tests/tst_tracklistmodel.cpp tests/CMakeLists.txt
git commit -m "test(ui): track list model roles, fallbacks and current-track marking"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `QT_QPA_PLATFORM=offscreen timeout 8 ./build/appmelodia 2>&1 | grep -Ec "is not a type|Unable to assign|ReferenceError"` → `0`
- **Decisão humana:** o Pedro roda o app numa sessão gráfica, aponta para a pasta de música
  dele, espera a varredura e **toca uma faixa**. Confirma: a lista tem a cara certa, o som sai,
  a barra de progresso anda, a capa aparece. É este o momento em que o app deixa de ser
  esqueleto — nenhum teste automatizado substitui esse olhar.

## Fora de escopo

- Navegação por artista/álbum/gênero, busca e fila visível — fatia `navegacao-biblioteca`.
- Coleções e tags — fatia `colecoes-tags`.
- Podcast — fatia `podcast-local`.
- Contagem de reprodução (`play_count`): o `AudioEngine` já emite `trackFinished`, mas quem
  escreve as estatísticas é a fatia `navegacao-biblioteca`, dona das listas que as consomem.
- Arrastar para reordenar, menu de contexto, atalhos de teclado.
- Barra de progresso da varredura com porcentagem: o `scanProgress` já existe, mas só ganha
  UI quando houver uma tela de biblioteca de verdade para hospedá-la.
