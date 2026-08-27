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
