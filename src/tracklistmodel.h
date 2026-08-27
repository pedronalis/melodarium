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
    // Where this file came from. The spec is explicit that compressed YouTube audio must not
    // pass itself off as the lossless files sitting next to it.
    QString sourceKind = QStringLiteral("local_file");
    QString sourceNote;
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
        SourceKindRole,
        SourceNoteRole,
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
