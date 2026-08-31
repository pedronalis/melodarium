#pragma once

#include <QDBusConnection>
#include <QDBusObjectPath>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class AudioEngine;
class CoverCache;

class MprisService final : public QObject
{
    Q_OBJECT

public:
    static constexpr auto kObjectPath = "/org/mpris/MediaPlayer2";
    static constexpr auto kRootInterface = "org.mpris.MediaPlayer2";
    static constexpr auto kPlayerInterface = "org.mpris.MediaPlayer2.Player";
    static constexpr auto kServiceName = "org.mpris.MediaPlayer2.melodarium";

    explicit MprisService(AudioEngine *engine, QObject *parent = nullptr);
    ~MprisService() override;

    bool isRegistered() const { return m_serviceRegistered && m_objectRegistered; }

    QString playbackStatus() const;
    QString loopStatus() const;
    void setLoopStatus(const QString &status);
    double rate() const;
    void setRate(double rate);
    bool shuffle() const;
    void setShuffle(bool shuffle);
    QVariantMap metadata() const;
    double volume() const;
    void setVolume(double volume);
    qlonglong position() const;
    bool canGoNext() const;
    bool canGoPrevious() const;
    bool canPlay() const;
    bool canPause() const;
    bool canSeek() const;
    bool canControl() const;

    void next();
    void previous();
    void pause();
    void playPause();
    void stop();
    void play();
    void seek(qlonglong offsetMicroseconds);
    void setPosition(const QDBusObjectPath &trackId, qlonglong positionMicroseconds);
    void openUri(const QString &uri);

signals:
    void Seeked(qlonglong positionMicroseconds);

private:
    void connectEngineSignals();
    void refreshMetadataSource();
    void refreshArtwork();
    void emitPlayerProperties(const QVariantMap &changed);
    void emitCapabilities();
    QString displayFile() const;
    QDBusObjectPath trackId() const;

    AudioEngine *m_engine = nullptr;
    CoverCache *m_coverCache = nullptr;
    QDBusConnection m_connection;
    QString m_title;
    QString m_artist;
    QString m_album;
    QString m_artUrl;
    qint64 m_tagDurationMs = 0;
    bool m_serviceRegistered = false;
    bool m_objectRegistered = false;
};
