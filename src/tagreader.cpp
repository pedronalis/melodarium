#include "tagreader.h"

#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>

#include <attachedpictureframe.h>
#include <fileref.h>
#include <flacfile.h>
#include <flacproperties.h>
#include <id3v2tag.h>
#include <mp4coverart.h>
#include <mp4file.h>
#include <mp4properties.h>
#include <mp4tag.h>
#include <mpegfile.h>
#include <opusfile.h>
#include <tag.h>
#include <tpropertymap.h>
#include <vorbisfile.h>
#include <wavproperties.h>
#include <xiphcomment.h>

namespace {

QString qs(const TagLib::String &s)
{
    // toCString(true) = UTF-8. Passing false silently mangles accented characters.
    return s.isEmpty() ? QString() : QString::fromUtf8(s.toCString(true));
}

QString firstValue(const TagLib::PropertyMap &pm, const char *key)
{
    const TagLib::StringList values = pm.value(key);
    return values.isEmpty() ? QString() : qs(values.front());
}

// "-7.15 dB" -> -7.15. strtod stops at the first invalid character, so the suffix is ignored.
bool parseGainDb(const QString &raw, double *out)
{
    if (raw.isEmpty())
        return false;
    bool ok = false;
    const double v = raw.trimmed().split(QLatin1Char(' ')).first().toDouble(&ok);
    if (ok)
        *out = v;
    return ok;
}

QString codecFromSuffix(const QString &path)
{
    const QString s = QFileInfo(path).suffix().toLower();
    if (s == QLatin1String("m4a") || s == QLatin1String("mp4"))
        return QStringLiteral("aac");
    if (s == QLatin1String("ogg") || s == QLatin1String("oga"))
        return QStringLiteral("vorbis");
    return s;
}

} // namespace

QString TagReader::computeContentHash(const QString &absolutePath)
{
    QFile f(absolutePath);
    if (!f.open(QIODevice::ReadOnly))
        return {};

    // Sampled hash: first 64KB + last 64KB + size. Hashing whole FLAC files would cost
    // minutes over a 5000-file library; this is enough to pair a moved file with its row.
    constexpr qint64 kChunk = 64 * 1024;
    QCryptographicHash hash(QCryptographicHash::Sha1);
    hash.addData(f.read(kChunk));
    const qint64 total = f.size();
    if (total > 2 * kChunk) {
        f.seek(total - kChunk);
        hash.addData(f.read(kChunk));
    }
    hash.addData(QByteArray::number(total));
    return QString::fromLatin1(hash.result().toHex());
}

QString TagReader::primaryName(const QString &raw)
{
    const QString name = raw.trimmed();
    if (name.isEmpty())
        return name;

    // Only separators that cannot mean anything else. "&" and "," are deliberately absent:
    // cutting there turns "Earth, Wind & Fire" into "Earth" and "Simon & Garfunkel" into
    // "Simon" — an ambiguous separator destroys more real names than it repairs. "/" is out
    // for the same reason, even though old ID3 used it to list artists: it would cut "AC/DC"
    // down to "AC".
    static const QRegularExpression guest(
        QStringLiteral(R"(\s+(?:feat|ft|featuring|vs)\.?(?:\s|$))"),
        QRegularExpression::CaseInsensitiveOption);

    int cut = name.size();
    const int semicolon = name.indexOf(QLatin1Char(';'));
    if (semicolon >= 0)
        cut = semicolon;
    const QRegularExpressionMatch m = guest.match(name);
    if (m.hasMatch() && m.capturedStart() < cut)
        cut = m.capturedStart();

    const QString primary = name.left(cut).trimmed();
    return primary.isEmpty() ? name : primary; // a cut must never leave the field empty
}

TrackRecord TagReader::read(const QString &absolutePath)
{
    TrackRecord r;
    r.path = absolutePath;

    const QFileInfo info(absolutePath);
    if (!info.exists() || !info.isReadable())
        return r; // r.valid stays false

    r.mtime = info.lastModified().toSecsSinceEpoch();
    r.size = info.size();

    const QByteArray pathBytes = absolutePath.toUtf8();
    TagLib::FileRef ref(pathBytes.constData());
    if (ref.isNull() || ref.tag() == nullptr)
        return r; // unsupported or corrupt: caller skips this file, never aborts the batch

    TagLib::Tag *tag = ref.tag();
    r.title = qs(tag->title());
    r.artist = qs(tag->artist());
    r.album = qs(tag->album());
    r.genre = qs(tag->genre());
    r.trackNo = static_cast<int>(tag->track());
    r.year = static_cast<int>(tag->year());

    TagLib::AudioProperties *props = ref.audioProperties();
    // TagLib 1.13.1 happily hands back a non-null tag and non-null properties for a file
    // that merely has an audio extension: garbage named *.mp3 parses with every property
    // at zero. Decodable audio always reports a rate and a channel count, so that is the
    // real validity test — without it the scanner would import junk as playable tracks.
    if (!props || props->sampleRate() <= 0 || props->channels() <= 0)
        return r; // r.valid stays false: the caller skips this file

    {
        r.durationMs = props->lengthInMilliseconds();
        r.sampleRate = props->sampleRate();
        r.channels = props->channels();
        r.bitrateKbps = props->bitrate();

        // bitsPerSample lives only on concrete subclasses (research §A.2).
        if (auto *p = dynamic_cast<TagLib::FLAC::Properties *>(props))
            r.bitsPerSample = p->bitsPerSample();
        else if (auto *p = dynamic_cast<TagLib::MP4::Properties *>(props))
            r.bitsPerSample = p->bitsPerSample();
        else if (auto *p = dynamic_cast<TagLib::RIFF::WAV::Properties *>(props))
            r.bitsPerSample = p->bitsPerSample();
    }

    if (TagLib::File *file = ref.file()) {
        const TagLib::PropertyMap pm = file->properties();

        // A file with two ARTIST fields ("Daft Punk", "Julian Casablancas") is correctly
        // tagged, but tag->artist() glues the list into one string with no separator and
        // invents a band that never existed. The PropertyMap keeps the values apart, so the
        // first one — the main artist, the primary genre — is what the library gets. Formats
        // with no usable PropertyMap keep whatever tag-> returned: fallback, not regression.
        {
            const QString first = firstValue(pm, "ARTIST");
            if (!first.isEmpty())
                r.artist = first;
        }
        {
            const QString first = firstValue(pm, "GENRE");
            if (!first.isEmpty())
                r.genre = first;
        }

        r.albumArtist = firstValue(pm, "ALBUMARTIST");
        r.composer = firstValue(pm, "COMPOSER");
        r.musicBrainzTrackId = firstValue(pm, "MUSICBRAINZ_TRACKID");
        r.discNo = firstValue(pm, "DISCNUMBER").split(QLatin1Char('/')).first().toInt();

        double gain = 0.0;
        if (parseGainDb(firstValue(pm, "REPLAYGAIN_TRACK_GAIN"), &gain)) {
            r.replayGainTrackDb = gain;
            r.hasReplayGain = true;
        } else {
            // Opus stores R128_TRACK_GAIN as an integer in Q7.8 units (1/256 dB).
            const QString r128 = firstValue(pm, "R128_TRACK_GAIN");
            bool ok = false;
            const int q78 = r128.toInt(&ok);
            if (ok) {
                r.replayGainTrackDb = q78 / 256.0;
                r.hasReplayGain = true;
            }
        }
        if (parseGainDb(firstValue(pm, "REPLAYGAIN_ALBUM_GAIN"), &gain))
            r.replayGainAlbumDb = gain;
    }

    // Badly tagged files keep the guests inside a single field; the genre never does, and
    // firstValue already handled the multi-value case there.
    r.artist = primaryName(r.artist);
    r.albumArtist = primaryName(r.albumArtist);
    if (r.albumArtist.isEmpty())
        r.albumArtist = r.artist;
    r.codec = codecFromSuffix(absolutePath);
    r.valid = true;
    return r;
}

QByteArray TagReader::readCover(const QString &absolutePath, QString *mimeTypeOut)
{
    const QByteArray pathBytes = absolutePath.toUtf8();
    const QString suffix = QFileInfo(absolutePath).suffix().toLower();
    if (mimeTypeOut)
        mimeTypeOut->clear();

    auto fromFlacPicture = [mimeTypeOut](const TagLib::List<TagLib::FLAC::Picture *> &pics) -> QByteArray {
        const TagLib::FLAC::Picture *best = nullptr;
        for (auto *pic : pics) {
            if (pic->type() == TagLib::FLAC::Picture::FrontCover) {
                best = pic;
                break;
            }
            if (!best)
                best = pic;
        }
        if (!best)
            return {};
        if (mimeTypeOut)
            *mimeTypeOut = qs(best->mimeType());
        return QByteArray(best->data().data(), static_cast<int>(best->data().size()));
    };

    if (suffix == QLatin1String("mp3")) {
        TagLib::MPEG::File mp3(pathBytes.constData());
        if (mp3.isValid() && mp3.ID3v2Tag()) {
            const TagLib::ID3v2::FrameList &frames = mp3.ID3v2Tag()->frameList("APIC");
            const TagLib::ID3v2::AttachedPictureFrame *best = nullptr;
            for (auto *frame : frames) {
                auto *pic = static_cast<TagLib::ID3v2::AttachedPictureFrame *>(frame);
                if (pic->type() == TagLib::ID3v2::AttachedPictureFrame::FrontCover) {
                    best = pic;
                    break;
                }
                if (!best)
                    best = pic;
            }
            if (best) {
                if (mimeTypeOut)
                    *mimeTypeOut = qs(best->mimeType());
                return QByteArray(best->picture().data(), static_cast<int>(best->picture().size()));
            }
        }
        return {};
    }

    if (suffix == QLatin1String("flac")) {
        TagLib::FLAC::File flac(pathBytes.constData());
        return flac.isValid() ? fromFlacPicture(flac.pictureList()) : QByteArray();
    }

    if (suffix == QLatin1String("m4a") || suffix == QLatin1String("mp4")) {
        TagLib::MP4::File m4a(pathBytes.constData());
        if (m4a.isValid() && m4a.tag() && m4a.tag()->itemMap().contains("covr")) {
            const TagLib::MP4::CoverArtList arts = m4a.tag()->itemMap()["covr"].toCoverArtList();
            if (!arts.isEmpty()) {
                if (mimeTypeOut) {
                    *mimeTypeOut = arts.front().format() == TagLib::MP4::CoverArt::PNG
                                       ? QStringLiteral("image/png")
                                       : QStringLiteral("image/jpeg");
                }
                return QByteArray(arts.front().data().data(),
                                  static_cast<int>(arts.front().data().size()));
            }
        }
        return {};
    }

    if (suffix == QLatin1String("opus")) {
        TagLib::Ogg::Opus::File opus(pathBytes.constData());
        if (opus.isValid() && opus.tag())
            return fromFlacPicture(opus.tag()->pictureList());
        return {};
    }

    if (suffix == QLatin1String("ogg") || suffix == QLatin1String("oga")) {
        TagLib::Ogg::Vorbis::File ogg(pathBytes.constData());
        if (ogg.isValid() && ogg.tag())
            return fromFlacPicture(ogg.tag()->pictureList());
        return {};
    }

    return {};
}
