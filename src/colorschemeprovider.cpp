#include "colorschemeprovider.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

ColorSchemeProvider::ColorSchemeProvider(QObject *parent)
    : ColorSchemeProvider(parent, QDir::homePath() + QStringLiteral("/.config/noctalia/colors.json"))
{
}

ColorSchemeProvider *ColorSchemeProvider::createForPath(const QString &path, QObject *parent)
{
    // Straight to the two-argument constructor: building the default one first would arm the
    // watcher on the user's real Noctalia file before we swap the path.
    return new ColorSchemeProvider(parent, path);
}

void ColorSchemeProvider::armWatch()
{
    if (!m_path.isEmpty() && QFile::exists(m_path) && !m_watcher.files().contains(m_path))
        m_watcher.addPath(m_path);
}

void ColorSchemeProvider::reload()
{
    m_colors.clear();

    QFile f(m_path);
    if (!f.open(QIODevice::ReadOnly))
        return; // no Noctalia (or unreadable): every getter falls back.

    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject())
        return; // malformed JSON is treated exactly like a missing file.

    const QJsonObject obj = doc.object();
    for (auto it = obj.constBegin(); it != obj.constEnd(); ++it) {
        const QColor c(it.value().toString());
        if (c.isValid())
            m_colors.insert(it.key(), c); // partial file: absent keys keep the fallback.
    }
}

// Appended to colorschemeprovider.cpp — the delegating constructor above lands here.
ColorSchemeProvider::ColorSchemeProvider(QObject *parent, const QString &path)
    : QObject(parent), m_path(path)
{
    reload();
    armWatch();
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &) {
        reload();
        emit colorsChanged();
        // Editors replace the file atomically (unlink + rename), which drops the watch.
        armWatch();
    });
}
