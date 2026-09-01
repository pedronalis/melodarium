#pragma once

#include <QObject>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

namespace DropRouting {

enum class Action {
    Reject,
    QueueFiles,
    QueueStream,
    ScanFolder,
    SubscribeFeed,
    ConfirmYoutube,
};

struct Decision {
    Action action = Action::Reject;
    QStringList paths;
    QUrl url;
    QString reason;
};

Decision classify(const QList<QUrl> &urls);
QString actionName(Action action);

} // namespace DropRouting

class DropRouter : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit DropRouter(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap classify(const QVariantList &values) const;
};
