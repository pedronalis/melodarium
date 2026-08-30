#include "audioengine.h"

#include <QtGlobal>
#include <QMetaObject>
#include <QRandomGenerator>
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
    // libmpv 0.40 starts a clipboard thread even for a player with no video and no window,
    // and its Wayland backend spins on ppoll instead of blocking: `mpv --idle --vo=null
    // --ao=null` burns 99.7 CPU ticks/s on this machine, and 0.0 with the backend list empty.
    // That was the whole "the app redraws 60 times a second while idle" bill — the renderer
    // was never the payer. A music player neither reads nor writes the clipboard, so the
    // right list is the empty one. Unknown option names are ignored by libmpv, so an older
    // libmpv without this option keeps working.
    setOptionString("clipboard-backends", "");
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

    m_queue = files;
    // A ordem guardada era da fila que acabou de sair; restaurá-la sobre esta devolveria
    // faixas que não estão mais aqui.
    if (m_shuffle) {
        m_shuffle = false;
        emit shuffleChanged();
    }
    m_queueOriginal.clear();
    emit queueChanged();
}

void AudioEngine::appendToQueue(const QString &file)
{
    if (!m_mpv || file.isEmpty())
        return;
    // "append" e não "append-play": pôr no fim é um gesto de organizar a fila, não de
    // mandar tocar. Quem quiser tocar chama play().
    command({QStringLiteral("loadfile"), file, QStringLiteral("append")});
    m_queue.append(file);
    emit queueChanged();
}

QStringList AudioEngine::upcoming(int limit) const
{
    if (limit <= 0 || m_queue.isEmpty())
        return {};
    const int first = m_playlistPos < 0 ? 0 : m_playlistPos + 1;
    if (first >= m_queue.size())
        return {};
    return m_queue.mid(first, limit);
}

void AudioEngine::cycleRepeat()
{
    switch (m_repeatMode) {
    case RepeatOff:  m_repeatMode = RepeatAll; break;
    case RepeatAll:  m_repeatMode = RepeatOne; break;
    case RepeatOne:  m_repeatMode = RepeatOff; break;
    }

    // As duas propriedades são escritas sempre, as duas: deixar a anterior ligada faria
    // "repetir a faixa" e "repetir a fila" valerem ao mesmo tempo.
    setPropertyString("loop-playlist", m_repeatMode == RepeatAll ? "inf" : "no");
    setPropertyString("loop-file", m_repeatMode == RepeatOne ? "inf" : "no");

    emit repeatModeChanged();
}

void AudioEngine::setShuffle(bool on)
{
    if (!m_mpv || m_shuffle == on)
        return;

    // A ordem que o mpv tem agora é exatamente a que estamos prestes a substituir.
    const QStringList ordemNoMpv = m_queue;

    if (on) {
        m_queueOriginal = m_queue;
        const int atual = m_playlistPos < 0 ? -1 : m_playlistPos;
        // Fisher-Yates a partir da PRÓXIMA entrada: embaralhar o que já está tocando
        // faria o mpv recarregar o arquivo no meio da faixa.
        for (int i = m_queue.size() - 1; i > atual + 1; --i) {
            const int j = atual + 1
                          + int(QRandomGenerator::global()->bounded(i - atual));
            m_queue.swapItemsAt(i, j);
        }
    } else {
        if (m_queueOriginal.isEmpty())
            return;
        m_queue = m_queueOriginal;
        m_queueOriginal.clear();
    }

    m_shuffle = on;
    reorderMpvPlaylist(ordemNoMpv);

    // Quando NADA tinha começado a tocar (m_playlistPos < 0), o embaralhamento incluiu a
    // primeira entrada — e o mpv, que já havia carregado a antiga, sai andando junto com
    // ela para o lugar novo. Medido no app com 27 faixas: a entrada original parava no
    // índice 24, e "tocar tudo em ordem aleatória" tocava três faixas em vez de tudo.
    // Voltar ao topo só é certo neste caso; com música tocando, mexer aqui interromperia.
    if (on && m_playlistPos < 0)
        setPropertyString("playlist-pos", "0");

    emit shuffleChanged();
    emit queueChanged();
}

// Leva a playlist do mpv da ordem `atual` para a de m_queue, uma entrada por vez.
// Reconstruir a lista com `loadfile … replace` daria a mesma ordem final e reiniciaria a
// faixa do zero — medido no teste shuffleDoesNotRestartWhatIsPlaying: 3,0 s viravam 0,7 s.
// `playlist-move` só troca entradas de lugar, e o mpv leva o índice do que toca junto.
void AudioEngine::reorderMpvPlaylist(const QStringList &atual)
{
    if (!m_mpv || m_queue.size() != atual.size())
        return;

    QStringList ordem = atual;
    for (int alvo = 0; alvo < m_queue.size(); ++alvo) {
        // A busca começa em `alvo` porque tudo antes dele já está no lugar certo. É também
        // o que mantém isto correto quando a mesma faixa aparece duas vezes na fila.
        const int de = ordem.indexOf(m_queue.at(alvo), alvo);
        if (de < 0 || de == alvo)
            continue;
        command({QStringLiteral("playlist-move"), QString::number(de),
                 QString::number(alvo)});
        ordem.move(de, alvo);
    }
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
