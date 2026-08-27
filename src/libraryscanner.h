#pragma once

#include <QObject>
#include <QString>
#include <atomic>

class LibraryScanner : public QObject
{
    Q_OBJECT

public:
    explicit LibraryScanner(QObject *parent = nullptr);

    void cancel(); // thread-safe

public slots:
    void run(const QString &rootPath, const QString &dbPath);

signals:
    void progress(int done, int total);
    void finished(int added, int updated, int removed);
    void failed(const QString &message);

private:
    std::atomic_bool m_cancelled{false};
};
