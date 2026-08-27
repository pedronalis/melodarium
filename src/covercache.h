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
