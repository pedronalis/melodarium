#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <atomic>

class LibraryScanner : public QObject
{
    Q_OBJECT

public:
    explicit LibraryScanner(QObject *parent = nullptr);

    // The suffixes that count as music, in one place. The folder picker needs the same list to
    // say "12 músicas" under a folder; a second copy of it would drift the day a format is
    // added and nobody would see the drift — the picker would just undercount, quietly.
    static const QStringList &audioSuffixes();

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
