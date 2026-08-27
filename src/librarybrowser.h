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
