#pragma once

#include <QObject>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

class PlayStatsRecorder : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit PlayStatsRecorder(QObject *parent = nullptr);

    Q_INVOKABLE void recordPlay(const QString &path);
    Q_INVOKABLE void recordSkip(const QString &path);
    // Onde a faixa parou, para o convite "continuar de onde parou" ter um minuto para retomar.
    Q_INVOKABLE void savePosition(const QString &path, int positionMs);

signals:
    void statsChanged(const QString &path);
};
