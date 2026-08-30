#pragma once

#include <QHash>
#include <QObject>
#include <QSet>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

class CoverCache : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(quint64 revision READ revision NOTIFY revisionChanged)

public:
    explicit CoverCache(QObject *parent = nullptr);

    static QString cacheDirectory();
    quint64 revision() const { return m_revision; }

    // "file:///..." for the cover of this track, "" when none exists.
    Q_INVOKABLE QString coverUrlForTrack(const QString &trackPath, int albumId);

signals:
    void revisionChanged();

private:
    // Looks for cover.jpg / folder.jpg / front.jpg next to the track.
    static QString siblingCoverFile(const QString &trackPath);
    static QString resolveCover(const QString &trackPath, const QString &key,
                                const QString &legacyPath);
    void scheduleResolution(const QString &trackPath, const QString &key,
                            const QString &legacyPath = QString());

    QHash<QString, QString> m_resolved;
    QSet<QString> m_pending;
    quint64 m_revision = 0;
};
