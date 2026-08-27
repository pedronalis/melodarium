#include "audioengine.h"

#include <QtGlobal>
#include <QMetaObject>
#include <QVarLengthArray>
#include <clocale>
#include <mpv/client.h>

namespace {
enum PropertyId : uint64_t {
    PROP_TIME_POS = 1,
    PROP_DURATION = 2,
    PROP_PAUSE = 3,
    PROP_PATH = 4,
    PROP_PLAYLIST_POS = 5,
    PROP_SPEED = 6,
};
} // namespace

AudioEngine::AudioEngine(QObject *parent, bool headlessAo)
    : QObject(parent)
{
    // MANDATORY before mpv_create(): libmpv requires LC_NUMERIC="C". Under pt_BR.UTF-8
    // (decimal comma) mpv_create() fails and the symptom does not point at the cause.
    std::setlocale(LC_NUMERIC, "C");

    m_mpv = mpv_create();
    if (!m_mpv) {
        emit engineUnavailable(QStringLiteral("mpv_create failed"));
        return;
    }

    setOptionString("video", "no");
    setOptionString("vo", "null");
    setOptionString("audio-display", "no");
    // MELODIA_NULL_AO existe para rodar o app inteiro onde não há placa de som (o gate roda
    // em offscreen): sem isto o mpv falha ao abrir o device e nada chega a tocar.
    if (headlessAo || qEnvironmentVariableIsSet("MELODIA_NULL_AO"))
        setOptionString("ao", "null");

    // Quality contract (spec: no conversion in the path).
    // The sample-rate and sample-format options are deliberately left UNSET: giving either
    // of them a value forces swresample to convert every track to it, which is exactly what
    // the quality requirement forbids. Their literal names are kept out of this file on
    // purpose so the grep guard in the plan stays meaningful.
    setOptionString("gapless-audio", "weak");
    setOptionString("replaygain", "no");
    setOptionString("replaygain-clip", "no");
    setOptionString("hr-seek", "yes");
    setOptionString("keep-open", "no");

    const int status = mpv_initialize(m_mpv);
    if (status < 0) {
        emit engineUnavailable(QString::fromUtf8(mpv_error_string(status)));
        mpv_destroy(m_mpv);
        m_mpv = nullptr;
        return;
    }

    mpv_observe_property(m_mpv, PROP_TIME_POS, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, PROP_DURATION, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, PROP_PAUSE, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, PROP_PATH, "path", MPV_FORMAT_STRING);
    mpv_observe_property(m_mpv, PROP_PLAYLIST_POS, "playlist-pos", MPV_FORMAT_INT64);
    mpv_observe_property(m_mpv, PROP_SPEED, "speed", MPV_FORMAT_DOUBLE);
    mpv_set_wakeup_callback(m_mpv, &AudioEngine::wakeup, this);
}

AudioEngine::~AudioEngine()
{
    if (m_mpv) {
        mpv_set_wakeup_callback(m_mpv, nullptr, nullptr); // stop waking us before tearing down
        mpv_terminate_destroy(m_mpv);
        m_mpv = nullptr;
    }
}

void AudioEngine::setOptionString(const char *name, const char *value)
{
    if (m_mpv)
        mpv_set_option_string(m_mpv, name, value);
}

void AudioEngine::setPropertyString(const char *name, const char *value)
{
    if (m_mpv)
        mpv_set_property_string(m_mpv, name, value);
}

void AudioEngine::command(const QStringList &args)
{
    if (!m_mpv)
        return;
    QList<QByteArray> owned;
    owned.reserve(args.size());
    for (const QString &a : args)
        owned.append(a.toUtf8());

    QVarLengthArray<const char *, 8> argv;
    for (const QByteArray &b : owned)
        argv.append(b.constData());
    argv.append(nullptr);

    mpv_command(m_mpv, argv.data());
}

void AudioEngine::play()
{
    if (!m_mpv)
        return;
    int flag = 0;
    mpv_set_property(m_mpv, "pause", MPV_FORMAT_FLAG, &flag);
}

void AudioEngine::pause()
{
    if (!m_mpv)
        return;
    int flag = 1;
    mpv_set_property(m_mpv, "pause", MPV_FORMAT_FLAG, &flag);
}

void AudioEngine::togglePause()
{
    m_playing ? pause() : play();
}

void AudioEngine::stop()
{
    command({QStringLiteral("stop")});
}

void AudioEngine::seek(double seconds)
{
    command({QStringLiteral("seek"), QString::number(seconds), QStringLiteral("absolute")});
}

void AudioEngine::next()
{
    command({QStringLiteral("playlist-next"), QStringLiteral("weak")});
}

void AudioEngine::previous()
{
    command({QStringLiteral("playlist-prev"), QStringLiteral("weak")});
}

void AudioEngine::loadPlaylist(const QStringList &files, int startIndex)
{
    if (!m_mpv || files.isEmpty())
        return;
    for (int i = 0; i < files.size(); ++i) {
        // "replace" on the first entry clears whatever was queued; "append" keeps the
        // playlist internal to mpv, which is what preserves gapless between entries.
        const QString mode = (i == 0) ? QStringLiteral("replace") : QStringLiteral("append");
        command({QStringLiteral("loadfile"), files.at(i), mode});
    }
    if (startIndex > 0 && startIndex < files.size())
        setPropertyString("playlist-pos", QByteArray::number(startIndex).constData());
}

void AudioEngine::setVolume(double v)
{
    if (qFuzzyCompare(m_volume, v) || !m_mpv)
        return;
    m_volume = qBound(0.0, v, 100.0);
    mpv_set_property(m_mpv, "volume", MPV_FORMAT_DOUBLE, &m_volume);
    emit volumeChanged();
}

void AudioEngine::setSpeed(double s)
{
    const double clamped = qBound(0.25, s, 4.0);
    if (qFuzzyCompare(m_speed, clamped) || !m_mpv)
        return;
    m_speed = clamped;
    mpv_set_property(m_mpv, "speed", MPV_FORMAT_DOUBLE, &m_speed);
    emit speedChanged();
}

void AudioEngine::setGaplessAggressive(bool on)
{
    // "yes" keeps the device open across entries but resamples tracks whose format differs
    // from the first one. "weak" (default) only goes gapless when the format matches.
    setPropertyString("gapless-audio", on ? "yes" : "weak");
}

void AudioEngine::setReplayGainMode(const QString &mode)
{
    const QByteArray value = (mode == QStringLiteral("track") || mode == QStringLiteral("album"))
                                 ? mode.toUtf8()
                                 : QByteArrayLiteral("no");
    setPropertyString("replaygain", value.constData());
}

void AudioEngine::setExclusiveOutput(bool on)
{
    // Exclusive mode silences every other application on the system while a file is loaded.
    setPropertyString("audio-exclusive", on ? "yes" : "no");
}

void AudioEngine::wakeup(void *ctx)
{
    // Runs on an mpv thread. Must not touch QObject state nor call any mpv_* function:
    // it may only schedule work back on the Qt thread.
    QMetaObject::invokeMethod(static_cast<AudioEngine *>(ctx), "onMpvEvents",
                              Qt::QueuedConnection);
}

void AudioEngine::onMpvEvents()
{
    if (!m_mpv)
        return;
    while (true) {
        mpv_event *event = mpv_wait_event(m_mpv, 0); // timeout 0: drain, never block
        if (event->event_id == MPV_EVENT_NONE)
            break;
        handleEvent(event);
    }
}

void AudioEngine::handleEvent(mpv_event *event)
{
    switch (event->event_id) {
    case MPV_EVENT_PROPERTY_CHANGE: {
        auto *prop = static_cast<mpv_event_property *>(event->data);
        if (!prop->data)
            break;
        switch (event->reply_userdata) {
        case PROP_TIME_POS:
            m_position = *static_cast<double *>(prop->data);
            emit positionChanged();
            break;
        case PROP_DURATION:
            m_duration = *static_cast<double *>(prop->data);
            emit durationChanged();
            break;
        case PROP_PAUSE:
            m_playing = (*static_cast<int *>(prop->data)) == 0;
            emit playingChanged();
            break;
        case PROP_PATH: {
            const char *p = *static_cast<char **>(prop->data);
            m_currentFile = p ? QString::fromUtf8(p) : QString();
            emit currentFileChanged();
            break;
        }
        case PROP_PLAYLIST_POS:
            m_playlistPos = static_cast<int>(*static_cast<int64_t *>(prop->data));
            emit playlistPosChanged();
            break;
        case PROP_SPEED:
            m_speed = *static_cast<double *>(prop->data);
            emit speedChanged();
            break;
        default:
            break;
        }
        break;
    }
    case MPV_EVENT_END_FILE: {
        auto *ef = static_cast<mpv_event_end_file *>(event->data);
        if (ef->reason == MPV_END_FILE_REASON_ERROR) {
            emit playbackError(m_currentFile, QString::fromUtf8(mpv_error_string(ef->error)));
        } else if (ef->reason == MPV_END_FILE_REASON_EOF) {
            emit trackFinished(m_currentFile);
        }
        break;
    }
    case MPV_EVENT_IDLE:
        m_playlistPos = -1;
        m_currentFile.clear();
        emit playlistPosChanged();
        emit currentFileChanged();
        break;
    case MPV_EVENT_SHUTDOWN:
        m_mpv = nullptr;
        break;
    default:
        break;
    }
}
