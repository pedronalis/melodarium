#include "audioengine.h"

#include <QDir>
#include <QtGlobal>
#include <QMetaObject>
#include <QHash>
#include <QQueue>
#include <QRandomGenerator>
#include <QSettings>
#include <QTemporaryFile>
#include <QUrl>
#include <QVarLengthArray>
#include <QFileInfo>
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
    PROP_PLAYLIST_COUNT = 7,
};

constexpr auto kSavedQueueKey = "playback/queue";
constexpr auto kSavedQueueIndexKey = "playback/currentIndex";
constexpr auto kVolumeKey = "playback/volume";
constexpr auto kPodcastSpeedKey = "playback/podcastSpeed";
constexpr auto kReplayGainModeKey = "audio/replayGainMode";
constexpr auto kLegacyReplayGainKey = "audio/replayGain";
constexpr auto kGaplessAggressiveKey = "audio/gaplessAggressive";
constexpr auto kExclusiveOutputKey = "audio/exclusiveOutput";
} // namespace

std::optional<QVector<AudioQueue::PlaylistMove>> AudioQueue::planMoves(
    const QStringList &current, const QStringList &target)
{
    if (current.size() != target.size())
        return std::nullopt;

    QHash<QString, QQueue<int>> occurrences;
    for (int i = 0; i < current.size(); ++i)
        occurrences[current.at(i)].enqueue(i);

    QVector<int> targetOccurrences;
    targetOccurrences.reserve(target.size());
    for (const QString &path : target) {
        auto it = occurrences.find(path);
        if (it == occurrences.end() || it->isEmpty())
            return std::nullopt;
        targetOccurrences.append(it->dequeue());
    }

    QVector<int> fenwick(current.size() + 1);
    const auto add = [&fenwick](int index, int delta) {
        for (int i = index + 1; i < fenwick.size(); i += i & -i)
            fenwick[i] += delta;
    };
    const auto prefixSum = [&fenwick](int index) {
        int sum = 0;
        for (int i = index + 1; i > 0; i -= i & -i)
            sum += fenwick.at(i);
        return sum;
    };
    for (int i = 0; i < current.size(); ++i)
        add(i, 1);

    QVector<PlaylistMove> moves;
    moves.reserve(current.size());
    for (int targetIndex = 0; targetIndex < targetOccurrences.size(); ++targetIndex) {
        const int originalIndex = targetOccurrences.at(targetIndex);
        const int from = targetIndex + prefixSum(originalIndex) - 1;
        if (from != targetIndex)
            moves.append({from, targetIndex});
        add(originalIndex, -1);
    }
    return moves;
}

AudioEngine::AudioEngine(QObject *parent, bool headlessAo)
    : QObject(parent)
{
    m_sleepTimer.setInterval(1000);
    connect(&m_sleepTimer, &QTimer::timeout, this, &AudioEngine::onSleepTimerTick);

    // Session state is useful even when mpv cannot start: the empty pane can still explain
    // what would be restored. Loading it does not feed anything to mpv until the user clicks.
    loadSavedSession();

    QSettings settings;
    m_volume = qBound(0.0, settings.value(QLatin1String(kVolumeKey), 100.0).toDouble(), 100.0);
    m_podcastSpeed = qBound(0.25,
                            settings.value(QLatin1String(kPodcastSpeedKey), 1.0).toDouble(),
                            4.0);
    QString replayGainMode = settings.value(QLatin1String(kReplayGainModeKey)).toString();
    if (replayGainMode.isEmpty()) {
        replayGainMode = settings.value(QLatin1String(kLegacyReplayGainKey), false).toBool()
                             ? QStringLiteral("track") : QStringLiteral("no");
        settings.setValue(QLatin1String(kReplayGainModeKey), replayGainMode);
    }
    if (replayGainMode != QStringLiteral("track")
        && replayGainMode != QStringLiteral("album"))
        replayGainMode = QStringLiteral("no");
    const bool gaplessAggressive =
        settings.value(QLatin1String(kGaplessAggressiveKey), false).toBool();
    const bool exclusiveOutput =
        settings.value(QLatin1String(kExclusiveOutputKey), false).toBool();

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
    setOptionString("gapless-audio", gaplessAggressive ? "yes" : "weak");
    setOptionString("replaygain", replayGainMode.toUtf8().constData());
    setOptionString("replaygain-clip", "no");
    setOptionString("audio-exclusive", exclusiveOutput ? "yes" : "no");
    setOptionString("hr-seek", "yes");
    setOptionString("keep-open", "no");

    const int status = mpv_initialize(m_mpv);
    if (status < 0) {
        emit engineUnavailable(QString::fromUtf8(mpv_error_string(status)));
        mpv_destroy(m_mpv);
        m_mpv = nullptr;
        return;
    }

    mpv_set_property(m_mpv, "volume", MPV_FORMAT_DOUBLE, &m_volume);

    mpv_observe_property(m_mpv, PROP_TIME_POS, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, PROP_DURATION, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, PROP_PAUSE, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, PROP_PATH, "path", MPV_FORMAT_STRING);
    mpv_observe_property(m_mpv, PROP_PLAYLIST_POS, "playlist-pos", MPV_FORMAT_INT64);
    mpv_observe_property(m_mpv, PROP_SPEED, "speed", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, PROP_PLAYLIST_COUNT, "playlist-count", MPV_FORMAT_INT64);
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

bool AudioEngine::command(const QStringList &args)
{
    if (!m_mpv)
        return false;
    QList<QByteArray> owned;
    owned.reserve(args.size());
    for (const QString &a : args)
        owned.append(a.toUtf8());

    QVarLengthArray<const char *, 8> argv;
    for (const QByteArray &b : owned)
        argv.append(b.constData());
    argv.append(nullptr);

    return mpv_command(m_mpv, argv.data()) >= 0;
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
    cancelSleepTimer();
    setStopAfterCurrent(false);
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

QString AudioEngine::savedCurrentFile() const
{
    if (m_savedQueueIndex < 0 || m_savedQueueIndex >= m_savedQueue.size())
        return {};
    return m_savedQueue.at(m_savedQueueIndex);
}

void AudioEngine::loadSavedSession()
{
    QSettings settings;
    m_savedQueue = settings.value(QLatin1String(kSavedQueueKey)).toStringList();
    m_savedQueueIndex = m_savedQueue.isEmpty()
                            ? -1
                            : qBound(0, settings.value(QLatin1String(kSavedQueueIndexKey), 0)
                                              .toInt(),
                                     m_savedQueue.size() - 1);
}

void AudioEngine::saveSession(const QStringList &queue, int currentIndex)
{
    if (queue.isEmpty())
        return;

    const int boundedIndex = qBound(0, currentIndex, queue.size() - 1);
    const bool changed = queue != m_savedQueue || boundedIndex != m_savedQueueIndex;
    m_savedQueue = queue;
    m_savedQueueIndex = boundedIndex;

    QSettings settings;
    settings.setValue(QLatin1String(kSavedQueueKey), m_savedQueue);
    settings.setValue(QLatin1String(kSavedQueueIndexKey), m_savedQueueIndex);
    // Queue mutations and track transitions are rare. Sync here makes the session survive a
    // crash without introducing the per-position writes that made the old resume expensive.
    settings.sync();

    if (changed)
        emit savedSessionChanged();
}

bool AudioEngine::restoreSavedQueue()
{
    if (!m_mpv || m_savedQueue.isEmpty())
        return false;

    QStringList validQueue;
    int validIndex = -1;
    for (int i = 0; i < m_savedQueue.size(); ++i) {
        if (!QFileInfo::exists(m_savedQueue.at(i)))
            continue;
        if (i == m_savedQueueIndex)
            validIndex = validQueue.size();
        else if (validIndex < 0 && i > m_savedQueueIndex)
            validIndex = validQueue.size();
        validQueue.append(m_savedQueue.at(i));
    }
    if (validQueue.isEmpty())
        return false;
    if (validIndex < 0)
        validIndex = validQueue.size() - 1;

    loadPlaylist(validQueue, validIndex, true);
    return true;
}

void AudioEngine::loadPlaylist(const QStringList &files, int startIndex, bool rememberSession)
{
    if (!m_mpv || files.isEmpty())
        return;
    m_podcastMode = !rememberSession;
    const double desiredSpeed = m_podcastMode ? m_podcastSpeed : 1.0;
    if (!qFuzzyCompare(m_speed, desiredSpeed)) {
        m_speed = desiredSpeed;
        mpv_set_property(m_mpv, "speed", MPV_FORMAT_DOUBLE, &m_speed);
        emit speedChanged();
    }
    const int boundedStart = qBound(0, startIndex, files.size() - 1);

    QTemporaryFile playlist(QDir::tempPath()
                            + QStringLiteral("/melodarium-queue-XXXXXX.m3u8"));
    QByteArray contents("#EXTM3U\n");
    for (const QString &file : files) {
        QUrl url(file);
        if (url.scheme().isEmpty())
            url = QUrl::fromLocalFile(QFileInfo(file).absoluteFilePath());
        contents += url.toEncoded(QUrl::FullyEncoded);
        contents += '\n';
    }

    bool loadedAsPlaylist = false;
    m_pendingStartIndex = boundedStart > 0 ? boundedStart : -1;
    if (playlist.open()
        && playlist.write(contents) == contents.size()
        && playlist.flush()) {
        loadedAsPlaylist = command({QStringLiteral("loadlist"), playlist.fileName(),
                                    QStringLiteral("replace")});
    }

    // A temporary directory can be unavailable under an unusually restricted runtime.
    // Preserve correctness there; the normal path remains a single validated mpv command.
    if (!loadedAsPlaylist) {
        m_pendingStartIndex = -1;
        for (int i = 0; i < files.size(); ++i) {
            const QString mode = i == 0 ? QStringLiteral("replace")
                                        : QStringLiteral("append");
            command({QStringLiteral("loadfile"), files.at(i), mode});
        }
        if (boundedStart > 0)
            setPropertyString("playlist-pos", QByteArray::number(boundedStart).constData());
    }

    m_queue = files;
    m_queueOccurrenceIds.clear();
    m_queueOccurrenceIds.reserve(files.size());
    for (qsizetype i = 0; i < files.size(); ++i)
        m_queueOccurrenceIds.append(m_nextQueueOccurrenceId++);
    m_rememberCurrentQueue = rememberSession;
    // A ordem guardada era da fila que acabou de sair; restaurá-la sobre esta devolveria
    // faixas que não estão mais aqui.
    if (m_shuffle) {
        m_shuffle = false;
        emit shuffleChanged();
    }
    m_queueOriginal.clear();
    m_queueOriginalOccurrenceIds.clear();
    emit queueChanged();
    if (m_rememberCurrentQueue)
        saveSession(m_queue, boundedStart);
}

void AudioEngine::appendToQueue(const QString &file)
{
    if (!m_mpv || file.isEmpty())
        return;
    // "append" e não "append-play": pôr no fim é um gesto de organizar a fila, não de
    // mandar tocar. Quem quiser tocar chama play().
    if (!command({QStringLiteral("loadfile"), file, QStringLiteral("append")}))
        return;
    const quint64 occurrenceId = m_nextQueueOccurrenceId++;
    m_queue.append(file);
    m_queueOccurrenceIds.append(occurrenceId);
    if (m_shuffle) {
        m_queueOriginal.append(file);
        m_queueOriginalOccurrenceIds.append(occurrenceId);
    }
    emit queueChanged();
    if (m_rememberCurrentQueue)
        saveSession(m_queue, m_playlistPos >= 0 ? m_playlistPos : 0);
}

bool AudioEngine::playNext(const QString &file)
{
    if (!m_mpv || file.isEmpty() || m_playlistPos < 0
        || m_playlistPos >= m_queue.size())
        return false;

    const int insertionIndex = m_playlistPos + 1;
    if (!command({QStringLiteral("loadfile"), file, QStringLiteral("insert-at"),
                  QString::number(insertionIndex)}))
        return false;

    const quint64 currentId = m_queueOccurrenceIds.at(m_playlistPos);
    const quint64 occurrenceId = m_nextQueueOccurrenceId++;
    m_queue.insert(insertionIndex, file);
    m_queueOccurrenceIds.insert(insertionIndex, occurrenceId);
    if (m_shuffle) {
        const int originalCurrent = m_queueOriginalOccurrenceIds.indexOf(currentId);
        const int originalInsertion = originalCurrent >= 0
                                          ? originalCurrent + 1
                                          : m_queueOriginal.size();
        m_queueOriginal.insert(originalInsertion, file);
        m_queueOriginalOccurrenceIds.insert(originalInsertion, occurrenceId);
    }

    emit queueChanged();
    if (m_rememberCurrentQueue)
        saveSession(m_queue, m_playlistPos);
    return true;
}

bool AudioEngine::removeQueueItem(int index)
{
    if (!m_mpv || index < 0 || index >= m_queue.size() || index == m_playlistPos)
        return false;
    if (!command({QStringLiteral("playlist-remove"), QString::number(index)}))
        return false;

    const quint64 occurrenceId = m_queueOccurrenceIds.at(index);
    m_queue.removeAt(index);
    m_queueOccurrenceIds.removeAt(index);
    if (m_shuffle) {
        const int originalIndex = m_queueOriginalOccurrenceIds.indexOf(occurrenceId);
        if (originalIndex >= 0) {
            m_queueOriginal.removeAt(originalIndex);
            m_queueOriginalOccurrenceIds.removeAt(originalIndex);
        }
    }

    if (index < m_playlistPos) {
        --m_playlistPos;
        emit playlistPosChanged();
    }
    emit queueChanged();
    if (m_rememberCurrentQueue)
        saveSession(m_queue, m_playlistPos >= 0 ? m_playlistPos : 0);
    return true;
}

bool AudioEngine::moveQueueItem(int from, int to)
{
    if (!m_mpv || from < 0 || from >= m_queue.size()
        || to < 0 || to >= m_queue.size())
        return false;
    if (from == to)
        return true;

    // mpv's destination is the entry to insert before, not the final index. Moving an
    // occurrence towards the tail is therefore expressed as adjacent moves so the public
    // contract remains the same as QStringList::move(), including the last position.
    if (from < to) {
        for (int index = from + 1; index <= to; ++index) {
            if (!command({QStringLiteral("playlist-move"), QString::number(index),
                          QString::number(index - 1)}))
                return false;
        }
    } else if (!command({QStringLiteral("playlist-move"), QString::number(from),
                         QString::number(to)})) {
        return false;
    }

    const quint64 occurrenceId = m_queueOccurrenceIds.at(from);
    m_queue.move(from, to);
    m_queueOccurrenceIds.move(from, to);
    if (m_shuffle) {
        const int originalIndex = m_queueOriginalOccurrenceIds.indexOf(occurrenceId);
        if (originalIndex >= 0) {
            const QString path = m_queueOriginal.takeAt(originalIndex);
            m_queueOriginalOccurrenceIds.removeAt(originalIndex);

            int originalInsertion = m_queueOriginal.size();
            if (to > 0) {
                const quint64 previousId = m_queueOccurrenceIds.at(to - 1);
                const int previousOriginal =
                    m_queueOriginalOccurrenceIds.indexOf(previousId);
                if (previousOriginal >= 0)
                    originalInsertion = previousOriginal + 1;
            } else if (m_queueOccurrenceIds.size() > 1) {
                const quint64 nextId = m_queueOccurrenceIds.at(1);
                const int nextOriginal = m_queueOriginalOccurrenceIds.indexOf(nextId);
                if (nextOriginal >= 0)
                    originalInsertion = nextOriginal;
            } else {
                originalInsertion = 0;
            }
            m_queueOriginal.insert(originalInsertion, path);
            m_queueOriginalOccurrenceIds.insert(originalInsertion, occurrenceId);
        }
    }

    const int oldPlaylistPos = m_playlistPos;
    if (m_playlistPos == from)
        m_playlistPos = to;
    else if (from < m_playlistPos && to >= m_playlistPos)
        --m_playlistPos;
    else if (from > m_playlistPos && to <= m_playlistPos)
        ++m_playlistPos;
    if (m_playlistPos != oldPlaylistPos)
        emit playlistPosChanged();

    emit queueChanged();
    if (m_rememberCurrentQueue)
        saveSession(m_queue, m_playlistPos >= 0 ? m_playlistPos : 0);
    return true;
}

bool AudioEngine::clearUpcoming()
{
    if (!m_mpv || m_playlistPos < 0 || m_playlistPos >= m_queue.size())
        return false;
    if (!command({QStringLiteral("playlist-clear")}))
        return false;

    const QString currentPath = m_queue.at(m_playlistPos);
    const quint64 currentId = m_queueOccurrenceIds.at(m_playlistPos);
    m_queue = {currentPath};
    m_queueOccurrenceIds = {currentId};
    if (m_shuffle) {
        m_queueOriginal = m_queue;
        m_queueOriginalOccurrenceIds = m_queueOccurrenceIds;
    }

    const bool indexChanged = m_playlistPos != 0;
    m_playlistPos = 0;
    if (indexChanged)
        emit playlistPosChanged();
    emit queueChanged();
    if (m_rememberCurrentQueue)
        saveSession(m_queue, 0);
    return true;
}

void AudioEngine::startSleepTimer(int seconds)
{
    if (seconds <= 0) {
        cancelSleepTimer();
        return;
    }
    m_sleepRemainingSeconds = seconds;
    m_sleepTimer.start();
    emit sleepTimerChanged();
}

void AudioEngine::cancelSleepTimer()
{
    if (!m_sleepTimer.isActive() && m_sleepRemainingSeconds == 0)
        return;
    m_sleepTimer.stop();
    m_sleepRemainingSeconds = 0;
    emit sleepTimerChanged();
}

void AudioEngine::setStopAfterCurrent(bool on)
{
    if (m_stopAfterCurrent == on)
        return;
    m_stopAfterCurrent = on;
    emit stopAfterCurrentChanged();
}

void AudioEngine::onSleepTimerTick()
{
    if (m_sleepRemainingSeconds <= 0) {
        cancelSleepTimer();
        return;
    }

    --m_sleepRemainingSeconds;
    if (m_sleepRemainingSeconds == 0)
        m_sleepTimer.stop();
    emit sleepTimerChanged();
    if (m_sleepRemainingSeconds == 0)
        stop();
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
        m_queueOriginalOccurrenceIds = m_queueOccurrenceIds;
        const int atual = m_playlistPos < 0 ? -1 : m_playlistPos;
        // Fisher-Yates a partir da PRÓXIMA entrada: embaralhar o que já está tocando
        // faria o mpv recarregar o arquivo no meio da faixa.
        for (int i = m_queue.size() - 1; i > atual + 1; --i) {
            const int j = atual + 1
                          + int(QRandomGenerator::global()->bounded(i - atual));
            m_queue.swapItemsAt(i, j);
            m_queueOccurrenceIds.swapItemsAt(i, j);
        }
    } else {
        if (m_queueOriginal.isEmpty())
            return;
        m_queue = m_queueOriginal;
        m_queueOccurrenceIds = m_queueOriginalOccurrenceIds;
        m_queueOriginal.clear();
        m_queueOriginalOccurrenceIds.clear();
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
    if (m_rememberCurrentQueue)
        saveSession(m_queue, m_playlistPos >= 0 ? m_playlistPos : 0);
}

// Leva a playlist do mpv da ordem `atual` para a de m_queue, uma entrada por vez.
// Reconstruir a lista com `loadfile … replace` daria a mesma ordem final e reiniciaria a
// faixa do zero — medido no teste shuffleDoesNotRestartWhatIsPlaying: 3,0 s viravam 0,7 s.
// `playlist-move` só troca entradas de lugar, e o mpv leva o índice do que toca junto.
void AudioEngine::reorderMpvPlaylist(const QStringList &atual)
{
    if (!m_mpv || m_queue.size() != atual.size())
        return;

    const auto moves = AudioQueue::planMoves(atual, m_queue);
    if (!moves)
        return;
    for (const auto &move : *moves)
        command({QStringLiteral("playlist-move"), QString::number(move.first),
                 QString::number(move.second)});
}

void AudioEngine::setVolume(double v)
{
    const double clamped = qBound(0.0, v, 100.0);
    if (qFuzzyCompare(m_volume, clamped) || !m_mpv)
        return;
    m_volume = clamped;
    mpv_set_property(m_mpv, "volume", MPV_FORMAT_DOUBLE, &m_volume);
    QSettings().setValue(QLatin1String(kVolumeKey), m_volume);
    emit volumeChanged();
}

void AudioEngine::setSpeed(double s)
{
    const double clamped = qBound(0.25, s, 4.0);
    if (qFuzzyCompare(m_speed, clamped) || !m_mpv)
        return;
    m_speed = clamped;
    mpv_set_property(m_mpv, "speed", MPV_FORMAT_DOUBLE, &m_speed);
    if (m_podcastMode) {
        m_podcastSpeed = m_speed;
        QSettings().setValue(QLatin1String(kPodcastSpeedKey), m_podcastSpeed);
    }
    emit speedChanged();
}

void AudioEngine::setGaplessAggressive(bool on)
{
    // "yes" keeps the device open across entries but resamples tracks whose format differs
    // from the first one. "weak" (default) only goes gapless when the format matches.
    setPropertyString("gapless-audio", on ? "yes" : "weak");
    QSettings().setValue(QLatin1String(kGaplessAggressiveKey), on);
}

void AudioEngine::setReplayGainMode(const QString &mode)
{
    const QByteArray value = (mode == QStringLiteral("track") || mode == QStringLiteral("album"))
                                 ? mode.toUtf8()
                                 : QByteArrayLiteral("no");
    setPropertyString("replaygain", value.constData());
    QSettings settings;
    settings.setValue(QLatin1String(kReplayGainModeKey), QString::fromUtf8(value));
    settings.setValue(QLatin1String(kLegacyReplayGainKey), value != QByteArrayLiteral("no"));
}

void AudioEngine::setExclusiveOutput(bool on)
{
    // Exclusive mode silences every other application on the system while a file is loaded.
    setPropertyString("audio-exclusive", on ? "yes" : "no");
    QSettings().setValue(QLatin1String(kExclusiveOutputKey), on);
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
            if (m_rememberCurrentQueue && m_playlistPos >= 0
                && m_playlistPos < m_queue.size())
                saveSession(m_queue, m_playlistPos);
            break;
        case PROP_SPEED:
            m_speed = *static_cast<double *>(prop->data);
            emit speedChanged();
            break;
        case PROP_PLAYLIST_COUNT: {
            const int count = static_cast<int>(*static_cast<int64_t *>(prop->data));
            if (m_pendingStartIndex >= 0 && count > m_pendingStartIndex) {
                const int target = m_pendingStartIndex;
                m_pendingStartIndex = -1;
                command({QStringLiteral("playlist-play-index"), QString::number(target)});
            }
            break;
        }
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
            if (m_stopAfterCurrent)
                stop();
        }
        break;
    }
    case MPV_EVENT_IDLE:
        m_playlistPos = -1;
        m_currentFile.clear();
        if (m_playing) {
            m_playing = false;
            emit playingChanged();
        }
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
