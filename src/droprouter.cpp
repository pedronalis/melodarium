#include "droprouter.h"

#include "audioformats.h"

#include <QFileInfo>

namespace {

bool isYoutubeHost(const QString &host)
{
    const QString lowered = host.toLower();
    return lowered == QStringLiteral("youtu.be")
           || lowered == QStringLiteral("youtube.com")
           || lowered.endsWith(QStringLiteral(".youtube.com"))
           || lowered == QStringLiteral("youtube-nocookie.com")
           || lowered.endsWith(QStringLiteral(".youtube-nocookie.com"));
}

DropRouting::Decision rejected(const QString &reason)
{
    return {DropRouting::Action::Reject, {}, {}, reason};
}

} // namespace

DropRouting::Decision DropRouting::classify(const QList<QUrl> &urls)
{
    if (urls.isEmpty())
        return rejected(QStringLiteral("nothing to import"));

    if (urls.size() > 1) {
        QStringList paths;
        paths.reserve(urls.size());
        for (const QUrl &url : urls) {
            if (!url.isLocalFile() || !url.host().isEmpty())
                return rejected(QStringLiteral("mixed or remote batches are not supported"));
            const QFileInfo info(url.toLocalFile());
            if (!info.exists() || !info.isFile()
                || !AudioFormats::supportsSuffix(info.suffix()))
                return rejected(QStringLiteral("the batch contains an unsupported entry"));
            paths.append(info.absoluteFilePath());
        }
        return {Action::QueueFiles, paths, {}, {}};
    }

    const QUrl url = urls.constFirst();
    if (url.isLocalFile() && url.host().isEmpty()) {
        const QFileInfo info(url.toLocalFile());
        if (!info.exists())
            return rejected(QStringLiteral("the local path does not exist"));
        if (info.isDir())
            return {Action::ScanFolder, {info.absoluteFilePath()}, {}, {}};
        if (info.isFile() && AudioFormats::supportsSuffix(info.suffix()))
            return {Action::QueueFiles, {info.absoluteFilePath()}, {}, {}};
        return rejected(QStringLiteral("unsupported local file"));
    }

    const QString scheme = url.scheme().toLower();
    if ((scheme != QStringLiteral("http") && scheme != QStringLiteral("https"))
        || !url.isValid() || url.host().isEmpty() || !url.userName().isEmpty()
        || !url.password().isEmpty())
        return rejected(QStringLiteral("unsafe or unsupported URL"));

    if (isYoutubeHost(url.host()))
        return {Action::ConfirmYoutube, {}, url, {}};
    if (AudioFormats::supportsSuffix(QFileInfo(url.path()).suffix()))
        return {Action::QueueStream, {}, url, {}};
    return {Action::SubscribeFeed, {}, url, {}};
}

QString DropRouting::actionName(Action action)
{
    switch (action) {
    case Action::QueueFiles: return QStringLiteral("queue-files");
    case Action::QueueStream: return QStringLiteral("queue-stream");
    case Action::ScanFolder: return QStringLiteral("scan-folder");
    case Action::SubscribeFeed: return QStringLiteral("subscribe-feed");
    case Action::ConfirmYoutube: return QStringLiteral("confirm-youtube");
    case Action::Reject: return QStringLiteral("reject");
    }
    return QStringLiteral("reject");
}

DropRouter::DropRouter(QObject *parent)
    : QObject(parent)
{
}

QVariantMap DropRouter::classify(const QVariantList &values) const
{
    QList<QUrl> urls;
    urls.reserve(values.size());
    for (const QVariant &value : values)
        urls.append(value.toUrl());

    const DropRouting::Decision decision = DropRouting::classify(urls);
    QVariantMap result = {
        {QStringLiteral("action"), DropRouting::actionName(decision.action)},
        {QStringLiteral("accepted"), decision.action != DropRouting::Action::Reject},
        {QStringLiteral("paths"), decision.paths},
        {QStringLiteral("url"), decision.url},
        {QStringLiteral("reason"), decision.reason},
    };
    return result;
}
