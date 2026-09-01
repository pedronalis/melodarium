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

public:
    // Três posições porque o mpv tem duas propriedades distintas: loop-playlist (a fila) e
    // loop-file (a faixa). Um par de booleanos deixaria as duas ligadas ao mesmo tempo.
    enum RepeatMode { RepeatOff, RepeatAll, RepeatOne };
    Q_ENUM(RepeatMode)

private:
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(int playlistPos READ playlistPos NOTIFY playlistPosChanged)
    Q_PROPERTY(double speed READ speed WRITE setSpeed NOTIFY speedChanged)
    Q_PROPERTY(QStringList queue READ queue NOTIFY queueChanged)
    Q_PROPERTY(int queueCount READ queueCount NOTIFY queueChanged)
    Q_PROPERTY(QStringList savedQueue READ savedQueue NOTIFY savedSessionChanged)
    Q_PROPERTY(int savedQueueIndex READ savedQueueIndex NOTIFY savedSessionChanged)
    Q_PROPERTY(int savedQueueCount READ savedQueueCount NOTIFY savedSessionChanged)
    Q_PROPERTY(QString savedCurrentFile READ savedCurrentFile NOTIFY savedSessionChanged)
    Q_PROPERTY(RepeatMode repeatMode READ repeatMode NOTIFY repeatModeChanged)
    Q_PROPERTY(bool shuffle READ shuffle NOTIFY shuffleChanged)

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
    QStringList queue() const { return m_queue; }
    int queueCount() const { return m_queue.size(); }
    QStringList savedQueue() const { return m_savedQueue; }
    int savedQueueIndex() const { return m_savedQueueIndex; }
    int savedQueueCount() const { return m_savedQueue.size(); }
    QString savedCurrentFile() const;
    RepeatMode repeatMode() const { return m_repeatMode; }
    bool shuffle() const { return m_shuffle; }

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
    Q_INVOKABLE void loadPlaylist(const QStringList &files, int startIndex = 0,
                                  bool rememberSession = true);
    // Restores only queue + current entry. Music deliberately starts at 0:00; podcast
    // timestamps remain the responsibility of PodcastLibrary.
    Q_INVOKABLE bool restoreSavedQueue();
    // Pôr no fim sem interromper o que toca. Com a fila vazia, carrega e NÃO começa a
    // tocar: o app só toca quando alguém pede.
    Q_INVOKABLE void appendToQueue(const QString &file);
    // Os próximos `limit` caminhos, sem incluir o que toca — é o que a tirinha desenha.
    Q_INVOKABLE QStringList upcoming(int limit) const;
    // Avança Off → All → One → Off. Um botão só, como no desenho.
    Q_INVOKABLE void cycleRepeat();
    // Embaralha a fila a partir da PRÓXIMA entrada (o que toca não muda de lugar), ou
    // devolve a ordem original.
    Q_INVOKABLE void setShuffle(bool on);
    Q_INVOKABLE void setGaplessAggressive(bool on);
    Q_INVOKABLE void setReplayGainMode(const QString &mode);
    Q_INVOKABLE void setExclusiveOutput(bool on);

    // Q_INVOKABLE: o sinal engineUnavailable é emitido dentro do construtor, quando ainda não
    // existe nenhum Connections para ouvi-lo. Quem quiser saber, pergunta.
    Q_INVOKABLE bool isAvailable() const { return m_mpv != nullptr; }

signals:
    void positionChanged();
    void durationChanged();
    void playingChanged();
    void volumeChanged();
    void currentFileChanged();
    void playlistPosChanged();
    void speedChanged();
    void queueChanged();
    void savedSessionChanged();
    void repeatModeChanged();
    void shuffleChanged();
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
    void reorderMpvPlaylist(const QStringList &atual);
    void loadSavedSession();
    void saveSession(const QStringList &queue, int currentIndex);

    mpv_handle *m_mpv = nullptr;
    double m_position = 0.0;
    double m_duration = 0.0;
    bool m_playing = false;
    double m_volume = 100.0;
    QString m_currentFile;
    int m_playlistPos = -1;
    double m_speed = 1.0;
    double m_podcastSpeed = 1.0;
    bool m_podcastMode = false;
    // Espelho do que foi mandado ao mpv. Ler playlist/N/filename seria uma consulta por
    // entrada a cada repintura da tirinha de capas.
    QStringList m_queue;
    QStringList m_savedQueue;
    int m_savedQueueIndex = -1;
    bool m_rememberCurrentQueue = true;
    RepeatMode m_repeatMode = RepeatOff;
    bool m_shuffle = false;
    // Sem isto, desligar o aleatório não tem para onde voltar.
    QStringList m_queueOriginal;
};
