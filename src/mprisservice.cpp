#include "mprisservice.h"

#include "audioengine.h"
#include "covercache.h"
#include "tagreader.h"

#include <QCryptographicHash>
#include <QDBusAbstractAdaptor>
#include <QDBusMessage>
#include <QFileInfo>
#include <QUrl>

namespace {

class MprisRootAdaptor final : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit READ canQuit)
    Q_PROPERTY(bool Fullscreen READ fullscreen WRITE setFullscreen)
    Q_PROPERTY(bool CanSetFullscreen READ canSetFullscreen)
    Q_PROPERTY(bool CanRaise READ canRaise)
    Q_PROPERTY(bool HasTrackList READ hasTrackList)
    Q_PROPERTY(QString Identity READ identity)
    Q_PROPERTY(QString DesktopEntry READ desktopEntry)
    Q_PROPERTY(QStringList SupportedUriSchemes READ supportedUriSchemes)
    Q_PROPERTY(QStringList SupportedMimeTypes READ supportedMimeTypes)

public:
    explicit MprisRootAdaptor(MprisService *service)
        : QDBusAbstractAdaptor(service)
    {
    }

    bool canQuit() const { return false; }
    bool fullscreen() const { return false; }
    void setFullscreen(bool) {}
    bool canSetFullscreen() const { return false; }
    bool canRaise() const { return false; }
    bool hasTrackList() const { return false; }
    QString identity() const { return QStringLiteral("Melodarium"); }
    QString desktopEntry() const { return QStringLiteral("melodarium"); }
    QStringList supportedUriSchemes() const { return {QStringLiteral("file")}; }
    QStringList supportedMimeTypes() const
    {
        return {QStringLiteral("audio/flac"), QStringLiteral("audio/mpeg"),
                QStringLiteral("audio/mp4"), QStringLiteral("audio/ogg"),
                QStringLiteral("audio/opus"), QStringLiteral("audio/wav"),
                QStringLiteral("audio/x-wav")};
    }

public slots:
    void Raise() {}
    void Quit() {}
};

class MprisPlayerAdaptor final : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus)
    Q_PROPERTY(QString LoopStatus READ loopStatus WRITE setLoopStatus)
    Q_PROPERTY(double Rate READ rate WRITE setRate)
    Q_PROPERTY(bool Shuffle READ shuffle WRITE setShuffle)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(double Volume READ volume WRITE setVolume)
    Q_PROPERTY(qlonglong Position READ position)
    Q_PROPERTY(double MinimumRate READ minimumRate)
    Q_PROPERTY(double MaximumRate READ maximumRate)
    Q_PROPERTY(bool CanGoNext READ canGoNext)
    Q_PROPERTY(bool CanGoPrevious READ canGoPrevious)
    Q_PROPERTY(bool CanPlay READ canPlay)
    Q_PROPERTY(bool CanPause READ canPause)
    Q_PROPERTY(bool CanSeek READ canSeek)
    Q_PROPERTY(bool CanControl READ canControl)

public:
    explicit MprisPlayerAdaptor(MprisService *service)
        : QDBusAbstractAdaptor(service)
        , m_service(service)
    {
        connect(service, &MprisService::Seeked, this, &MprisPlayerAdaptor::Seeked);
    }

    QString playbackStatus() const { return m_service->playbackStatus(); }
    QString loopStatus() const { return m_service->loopStatus(); }
    void setLoopStatus(const QString &status) { m_service->setLoopStatus(status); }
    double rate() const { return m_service->rate(); }
    void setRate(double rate) { m_service->setRate(rate); }
    bool shuffle() const { return m_service->shuffle(); }
    void setShuffle(bool shuffle) { m_service->setShuffle(shuffle); }
    QVariantMap metadata() const { return m_service->metadata(); }
    double volume() const { return m_service->volume(); }
    void setVolume(double volume) { m_service->setVolume(volume); }
    qlonglong position() const { return m_service->position(); }
    double minimumRate() const { return 0.25; }
    double maximumRate() const { return 4.0; }
    bool canGoNext() const { return m_service->canGoNext(); }
    bool canGoPrevious() const { return m_service->canGoPrevious(); }
    bool canPlay() const { return m_service->canPlay(); }
    bool canPause() const { return m_service->canPause(); }
    bool canSeek() const { return m_service->canSeek(); }
    bool canControl() const { return m_service->canControl(); }

public slots:
    void Next() { m_service->next(); }
    void Previous() { m_service->previous(); }
    void Pause() { m_service->pause(); }
    void PlayPause() { m_service->playPause(); }
    void Stop() { m_service->stop(); }
    void Play() { m_service->play(); }
    void Seek(qlonglong offsetMicroseconds) { m_service->seek(offsetMicroseconds); }
    void SetPosition(const QDBusObjectPath &trackId, qlonglong positionMicroseconds)
    {
        m_service->setPosition(trackId, positionMicroseconds);
    }
    void OpenUri(const QString &uri) { m_service->openUri(uri); }

signals:
    void Seeked(qlonglong positionMicroseconds);

private:
    MprisService *m_service = nullptr;
};

QVariantMap propertyMap(std::initializer_list<std::pair<QString, QVariant>> values)
{
    QVariantMap result;
    for (const auto &[name, value] : values)
        result.insert(name, value);
    return result;
}

} // namespace

MprisService::MprisService(AudioEngine *engine, QObject *parent)
    : QObject(parent)
    , m_engine(engine)
    , m_coverCache(new CoverCache(this))
    , m_connection(QDBusConnection::sessionBus())
{
    new MprisRootAdaptor(this);
    new MprisPlayerAdaptor(this);

    if (m_connection.isConnected()) {
        m_serviceRegistered = m_connection.registerService(QLatin1String(kServiceName));
        if (m_serviceRegistered) {
            m_objectRegistered = m_connection.registerObject(
                QLatin1String(kObjectPath), this, QDBusConnection::ExportAdaptors);
            if (!m_objectRegistered) {
                m_connection.unregisterService(QLatin1String(kServiceName));
                m_serviceRegistered = false;
            }
        }
    }

    connectEngineSignals();
    refreshMetadataSource();
}

MprisService::~MprisService()
{
    if (m_objectRegistered)
        m_connection.unregisterObject(QLatin1String(kObjectPath));
    if (m_serviceRegistered)
        m_connection.unregisterService(QLatin1String(kServiceName));
}

void MprisService::connectEngineSignals()
{
    if (!m_engine)
        return;

    connect(m_engine, &AudioEngine::playingChanged, this, [this]() {
        emitPlayerProperties(propertyMap({
            {QStringLiteral("PlaybackStatus"), playbackStatus()},
            {QStringLiteral("CanPlay"), canPlay()},
            {QStringLiteral("CanPause"), canPause()},
        }));
    });
    connect(m_engine, &AudioEngine::currentFileChanged,
            this, &MprisService::refreshMetadataSource);
    connect(m_engine, &AudioEngine::durationChanged, this, [this]() {
        emitPlayerProperties(propertyMap({
            {QStringLiteral("Metadata"), metadata()},
        }));
    });
    connect(m_engine, &AudioEngine::volumeChanged, this, [this]() {
        emitPlayerProperties(propertyMap({
            {QStringLiteral("Volume"), volume()},
        }));
    });
    connect(m_engine, &AudioEngine::speedChanged, this, [this]() {
        emitPlayerProperties(propertyMap({
            {QStringLiteral("Rate"), rate()},
        }));
    });
    connect(m_engine, &AudioEngine::repeatModeChanged, this, [this]() {
        emitPlayerProperties(propertyMap({
            {QStringLiteral("LoopStatus"), loopStatus()},
        }));
    });
    connect(m_engine, &AudioEngine::shuffleChanged, this, [this]() {
        emitPlayerProperties(propertyMap({
            {QStringLiteral("Shuffle"), shuffle()},
        }));
    });
    connect(m_engine, &AudioEngine::queueChanged, this, &MprisService::emitCapabilities);
    connect(m_engine, &AudioEngine::playlistPosChanged,
            this, &MprisService::emitCapabilities);
    connect(m_engine, &AudioEngine::savedSessionChanged, this, [this]() {
        if (m_engine->currentFile().isEmpty())
            refreshMetadataSource();
        else
            emitCapabilities();
    });
    connect(m_coverCache, &CoverCache::revisionChanged,
            this, &MprisService::refreshArtwork);
}

QString MprisService::displayFile() const
{
    if (!m_engine)
        return {};
    return m_engine->currentFile().isEmpty() ? m_engine->savedCurrentFile()
                                             : m_engine->currentFile();
}

void MprisService::refreshMetadataSource()
{
    m_title.clear();
    m_artist.clear();
    m_album.clear();
    m_artUrl.clear();
    m_tagDurationMs = 0;

    const QString file = displayFile();
    if (!file.isEmpty()) {
        const TrackRecord track = TagReader::read(file);
        m_title = track.title.trimmed();
        m_artist = track.artist.trimmed();
        m_album = track.album.trimmed();
        m_tagDurationMs = track.durationMs;
        if (m_title.isEmpty())
            m_title = QFileInfo(file).completeBaseName();
        m_artUrl = m_coverCache->coverUrlForTrack(file, 0);
    }

    emitPlayerProperties(propertyMap({
        {QStringLiteral("Metadata"), metadata()},
        {QStringLiteral("PlaybackStatus"), playbackStatus()},
        {QStringLiteral("CanPlay"), canPlay()},
        {QStringLiteral("CanPause"), canPause()},
        {QStringLiteral("CanSeek"), canSeek()},
        {QStringLiteral("CanGoNext"), canGoNext()},
        {QStringLiteral("CanGoPrevious"), canGoPrevious()},
    }));
}

void MprisService::refreshArtwork()
{
    const QString file = displayFile();
    if (file.isEmpty())
        return;
    const QString artUrl = m_coverCache->coverUrlForTrack(file, 0);
    if (artUrl == m_artUrl)
        return;
    m_artUrl = artUrl;
    emitPlayerProperties(propertyMap({
        {QStringLiteral("Metadata"), metadata()},
    }));
}

void MprisService::emitPlayerProperties(const QVariantMap &changed)
{
    if (!isRegistered() || changed.isEmpty())
        return;
    QDBusMessage message = QDBusMessage::createSignal(
        QLatin1String(kObjectPath), QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("PropertiesChanged"));
    message << QLatin1String(kPlayerInterface) << changed << QStringList();
    m_connection.send(message);
}

void MprisService::emitCapabilities()
{
    emitPlayerProperties(propertyMap({
        {QStringLiteral("CanPlay"), canPlay()},
        {QStringLiteral("CanPause"), canPause()},
        {QStringLiteral("CanSeek"), canSeek()},
        {QStringLiteral("CanGoNext"), canGoNext()},
        {QStringLiteral("CanGoPrevious"), canGoPrevious()},
    }));
}

QString MprisService::playbackStatus() const
{
    if (!m_engine || m_engine->currentFile().isEmpty())
        return QStringLiteral("Stopped");
    return m_engine->playing() ? QStringLiteral("Playing") : QStringLiteral("Paused");
}

QString MprisService::loopStatus() const
{
    if (!m_engine || m_engine->repeatMode() == AudioEngine::RepeatOff)
        return QStringLiteral("None");
    return m_engine->repeatMode() == AudioEngine::RepeatOne ? QStringLiteral("Track")
                                                            : QStringLiteral("Playlist");
}

void MprisService::setLoopStatus(const QString &status)
{
    if (!m_engine)
        return;
    AudioEngine::RepeatMode target = AudioEngine::RepeatOff;
    if (status == QLatin1String("Track"))
        target = AudioEngine::RepeatOne;
    else if (status == QLatin1String("Playlist"))
        target = AudioEngine::RepeatAll;
    for (int i = 0; i < 3 && m_engine->repeatMode() != target; ++i)
        m_engine->cycleRepeat();
}

double MprisService::rate() const
{
    return m_engine ? m_engine->speed() : 1.0;
}

void MprisService::setRate(double rate)
{
    if (m_engine)
        m_engine->setSpeed(rate);
}

bool MprisService::shuffle() const
{
    return m_engine && m_engine->shuffle();
}

void MprisService::setShuffle(bool shuffle)
{
    if (m_engine)
        m_engine->setShuffle(shuffle);
}

QDBusObjectPath MprisService::trackId() const
{
    const QString file = displayFile();
    if (file.isEmpty())
        return QDBusObjectPath(QStringLiteral("/io/github/pedronalis/melodarium/NoTrack"));
    const QString digest = QString::fromLatin1(
        QCryptographicHash::hash(file.toUtf8(), QCryptographicHash::Sha1).toHex());
    return QDBusObjectPath(QStringLiteral("/io/github/pedronalis/melodarium/track/t_%1")
                               .arg(digest));
}

QVariantMap MprisService::metadata() const
{
    QVariantMap result;
    const QString file = displayFile();
    if (file.isEmpty())
        return result;

    result.insert(QStringLiteral("mpris:trackid"), QVariant::fromValue(trackId()));
    result.insert(QStringLiteral("xesam:title"), m_title);
    if (!m_artist.isEmpty())
        result.insert(QStringLiteral("xesam:artist"), QStringList{m_artist});
    if (!m_album.isEmpty())
        result.insert(QStringLiteral("xesam:album"), m_album);
    result.insert(QStringLiteral("xesam:url"), QUrl::fromLocalFile(file).toString());

    const double currentDuration = m_engine && m_engine->currentFile() == file
                                       ? m_engine->duration()
                                       : 0.0;
    const qlonglong length = currentDuration > 0.0
                                 ? qRound64(currentDuration * 1000000.0)
                                 : m_tagDurationMs * 1000;
    if (length > 0)
        result.insert(QStringLiteral("mpris:length"), length);
    if (!m_artUrl.isEmpty())
        result.insert(QStringLiteral("mpris:artUrl"), m_artUrl);
    return result;
}

double MprisService::volume() const
{
    return m_engine ? m_engine->volume() / 100.0 : 0.0;
}

void MprisService::setVolume(double volume)
{
    if (m_engine)
        m_engine->setVolume(qMax(0.0, volume) * 100.0);
}

qlonglong MprisService::position() const
{
    return m_engine ? qRound64(m_engine->position() * 1000000.0) : 0;
}

bool MprisService::canGoNext() const
{
    if (!canControl() || m_engine->queueCount() < 2 || m_engine->playlistPos() < 0)
        return false;
    return m_engine->playlistPos() + 1 < m_engine->queueCount()
           || m_engine->repeatMode() == AudioEngine::RepeatAll;
}

bool MprisService::canGoPrevious() const
{
    if (!canControl() || m_engine->queueCount() < 2 || m_engine->playlistPos() < 0)
        return false;
    return m_engine->playlistPos() > 0
           || m_engine->repeatMode() == AudioEngine::RepeatAll;
}

bool MprisService::canPlay() const
{
    return canControl() && !displayFile().isEmpty();
}

bool MprisService::canPause() const
{
    return canPlay();
}

bool MprisService::canSeek() const
{
    return canControl() && m_engine && !m_engine->currentFile().isEmpty();
}

bool MprisService::canControl() const
{
    return m_engine && m_engine->isAvailable();
}

void MprisService::next()
{
    if (canGoNext())
        m_engine->next();
}

void MprisService::previous()
{
    if (canGoPrevious())
        m_engine->previous();
}

void MprisService::pause()
{
    if (canPause())
        m_engine->pause();
}

void MprisService::playPause()
{
    if (!m_engine)
        return;
    if (m_engine->currentFile().isEmpty())
        play();
    else
        m_engine->togglePause();
}

void MprisService::stop()
{
    if (canControl())
        m_engine->stop();
}

void MprisService::play()
{
    if (!canPlay())
        return;
    if (m_engine->currentFile().isEmpty() && !m_engine->restoreSavedQueue())
        return;
    m_engine->play();
}

void MprisService::seek(qlonglong offsetMicroseconds)
{
    if (!canSeek())
        return;
    const double target = qMax(0.0, m_engine->position() + offsetMicroseconds / 1000000.0);
    m_engine->seek(target);
    emit Seeked(qRound64(target * 1000000.0));
}

void MprisService::setPosition(const QDBusObjectPath &trackId,
                               qlonglong positionMicroseconds)
{
    if (!canSeek() || trackId.path() != this->trackId().path())
        return;
    const double target = qMax<qlonglong>(0, positionMicroseconds) / 1000000.0;
    m_engine->seek(target);
    emit Seeked(qRound64(target * 1000000.0));
}

void MprisService::openUri(const QString &uri)
{
    if (!canControl())
        return;
    const QUrl url(uri);
    const QString file = url.isLocalFile() ? url.toLocalFile() : QString();
    if (file.isEmpty() || !QFileInfo::exists(file))
        return;
    m_engine->loadPlaylist({file});
    m_engine->play();
}

#include "mprisservice.moc"
