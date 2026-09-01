#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

class QIODevice;

namespace Portability {

struct OpmlSubscription
{
    QString title;
    QUrl feedUrl;
};

struct OpmlParseResult
{
    QList<OpmlSubscription> subscriptions;
    int duplicateCount = 0;
    int invalidCount = 0;
    QString error;
};

OpmlParseResult parseOpml(QIODevice *device);
bool writeOpml(QIODevice *device, QList<OpmlSubscription> subscriptions,
               QString *error = nullptr);

} // namespace Portability

class PortabilityService : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit PortabilityService(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap importOpml(const QUrl &fileUrl);
    Q_INVOKABLE QVariantMap exportOpml(const QUrl &fileUrl);

signals:
    void subscriptionRequested(const QUrl &feedUrl);
};
