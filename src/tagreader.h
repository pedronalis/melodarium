#pragma once

#include <QByteArray>
#include <QString>

struct TrackRecord {
    QString path;
    qint64 mtime = 0;
    qint64 size = 0;
    QString contentHash;
    int durationMs = 0;
    int sampleRate = 0;
    int bitsPerSample = 0;
    int channels = 0;
    int bitrateKbps = 0;
    QString codec;
    QString title;
    QString artist;
    QString albumArtist;
    QString album;
    QString genre;
    int trackNo = 0;
    int discNo = 0;
    int year = 0;
    QString composer;
    double replayGainTrackDb = 0.0;
    double replayGainAlbumDb = 0.0;
    bool hasReplayGain = false;
    QString musicBrainzTrackId;
    bool valid = false;
};

namespace TagReader {
QString computeContentHash(const QString &absolutePath);
TrackRecord read(const QString &absolutePath);
QByteArray readCover(const QString &absolutePath, QString *mimeTypeOut);
} // namespace TagReader
