#pragma once

#include <QDir>
#include <QSettings>
#include <QSqlQuery>
#include <QString>

namespace PodcastScope {

inline QString normaliseRoot(const QString &path)
{
    const QString trimmed = path.trimmed();
    return trimmed.isEmpty() ? QString() : QDir::cleanPath(QDir(trimmed).absolutePath());
}

inline QString currentRoot()
{
    return normaliseRoot(QSettings().value(QStringLiteral("podcast/path")).toString());
}

// A selected folder is the active local library root. RSS shows remain independent from it,
// while the slash-terminated prefix keeps sibling paths such as /podcast out of /p.
inline QString visibleShowClause(const QString &alias)
{
    const QString prefix = alias.isEmpty() ? QString() : alias + QLatin1Char('.');
    return QStringLiteral(
               "(%1feed_url IS NOT NULL OR "
               "(? <> '' AND (%1folder_path = ? OR instr(%1folder_path, ?) = 1)))")
        .arg(prefix);
}

inline void bindVisibleShow(QSqlQuery &query, const QString &root)
{
    const QString clean = normaliseRoot(root);
    const QString descendantPrefix = clean.isEmpty()
                                         ? QString()
                                         : (clean == QLatin1String("/")
                                                ? clean
                                                : clean + QLatin1Char('/'));
    query.addBindValue(clean);
    query.addBindValue(clean);
    query.addBindValue(descendantPrefix);
}

} // namespace PodcastScope
