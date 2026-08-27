#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQmlIntegration/qqmlintegration.h>

struct mpv_handle;
struct mpv_event;

class AudioEngine : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(int playlistPos READ playlistPos NOTIFY playlistPosChanged)
    Q_PROPERTY(double speed READ speed WRITE setSpeed NOTIFY speedChanged)

public:
    // headlessAo = true forces --ao=null: never opens a real device, for automated tests.
    explicit AudioEngine(QObject *parent = nullptr, bool headlessAo = false);
    ~AudioEngine() override;

    double position() const { return m_position; }
    double duration() const { return m_duration; }
    bool playing() const { return m_playing; }
    double volume() const { return m_volume; }
    QString currentFile() const { return m_currentFile; }
    int playlistPos() const { return m_playlistPos; }
    double speed() const { return m_speed; }

    // Q_INVOKABLE and not just a Q_PROPERTY WRITE: the podcast slice calls
    // AudioEngine.setSpeed(x) as a function. A bare WRITE method is invisible to QML.
    Q_INVOKABLE void setVolume(double v);
    Q_INVOKABLE void setSpeed(double s);

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(double seconds);
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void loadPlaylist(const QStringList &files, int startIndex = 0);
    Q_INVOKABLE void setGaplessAggressive(bool on);
    Q_INVOKABLE void setReplayGainMode(const QString &mode);
    Q_INVOKABLE void setExclusiveOutput(bool on);

    bool isAvailable() const { return m_mpv != nullptr; }

signals:
    void positionChanged();
    void durationChanged();
    void playingChanged();
    void volumeChanged();
    void currentFileChanged();
    void playlistPosChanged();
    void speedChanged();
    void trackFinished(const QString &path);
    void playbackError(const QString &path, const QString &message);
    void engineUnavailable(const QString &message);

private slots:
    void onMpvEvents();

private:
    static void wakeup(void *ctx);
    void handleEvent(mpv_event *event);
    void setOptionString(const char *name, const char *value);
    void setPropertyString(const char *name, const char *value);
    void command(const QStringList &args);

    mpv_handle *m_mpv = nullptr;
    double m_position = 0.0;
    double m_duration = 0.0;
    bool m_playing = false;
    double m_volume = 100.0;
    QString m_currentFile;
    int m_playlistPos = -1;
    double m_speed = 1.0;
};
