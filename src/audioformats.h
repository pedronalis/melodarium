#pragma once

#include <QStringList>

namespace AudioFormats {

inline const QStringList &supportedSuffixes()
{
    static const QStringList suffixes = {
        QStringLiteral("flac"), QStringLiteral("mp3"),  QStringLiteral("m4a"),
        QStringLiteral("mp4"),  QStringLiteral("opus"), QStringLiteral("ogg"),
        QStringLiteral("oga"),  QStringLiteral("wav"),  QStringLiteral("aiff"),
    };
    return suffixes;
}

inline bool supportsSuffix(const QString &suffix)
{
    return supportedSuffixes().contains(suffix.toLower());
}

} // namespace AudioFormats
