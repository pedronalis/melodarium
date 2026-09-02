#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
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
    Q_INVOKABLE QVariantList bindingsFor(int id);

    Q_INVOKABLE QString clauseRecent();
    Q_INVOKABLE QString clauseRecentlyPlayed();
    Q_INVOKABLE QString clauseMostPlayed();
    Q_INVOKABLE QString clauseForgotten();
    Q_INVOKABLE QString clauseNeverPlayed();

    Q_INVOKABLE bool toggleLike(int trackId);
    Q_INVOKABLE bool isLiked(int trackId);
    Q_INVOKABLE QString clauseForLiked();
    Q_INVOKABLE int likedCount();

    // O que o estado "nada tocando" oferece: a última faixa, e o tamanho das duas listas que
    // valem um convite.
    Q_INVOKABLE QVariantMap lastPlayed();
    Q_INVOKABLE int neverPlayedCount();
    Q_INVOKABLE int forgottenCount();

    // Uma chamada só para a busca inteira: o QML não monta SQL nem decide a ordem dos tipos.
    Q_INVOKABLE QVariantList searchGrouped(const QString &text, int limitPerKind = 4);

    // The panel only knows the file mpv has open; this turns it back into a library row.
    Q_INVOKABLE QVariantMap trackForPath(const QString &path);

signals:
    void likedChanged(int trackId, bool liked);

public:

    // Turns free user input into a safe FTS5 prefix query: "jo mal" -> "jo* mal*".
    static QString toFtsPrefixQuery(const QString &text);
};
