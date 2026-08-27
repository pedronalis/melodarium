#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QHash>
#include <QObject>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

class ColorSchemeProvider : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QColor mPrimary READ mPrimary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnPrimary READ mOnPrimary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mSecondary READ mSecondary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnSecondary READ mOnSecondary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mTertiary READ mTertiary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnTertiary READ mOnTertiary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mError READ mError NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnError READ mOnError NOTIFY colorsChanged)
    Q_PROPERTY(QColor mSurface READ mSurface NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnSurface READ mOnSurface NOTIFY colorsChanged)
    Q_PROPERTY(QColor mSurfaceVariant READ mSurfaceVariant NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnSurfaceVariant READ mOnSurfaceVariant NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOutline READ mOutline NOTIFY colorsChanged)
    Q_PROPERTY(QColor mShadow READ mShadow NOTIFY colorsChanged)
    Q_PROPERTY(QColor mHover READ mHover NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnHover READ mOnHover NOTIFY colorsChanged)
    Q_PROPERTY(bool usingNoctalia READ usingNoctalia NOTIFY colorsChanged)

public:
    explicit ColorSchemeProvider(QObject *parent = nullptr);

    // Test seam: pass an explicit path instead of the user's Noctalia config.
    static ColorSchemeProvider *createForPath(const QString &path, QObject *parent = nullptr);

    QColor mPrimary() const { return at(QStringLiteral("mPrimary"), QColor("#fff59b")); }
    QColor mOnPrimary() const { return at(QStringLiteral("mOnPrimary"), QColor("#0e0e43")); }
    QColor mSecondary() const { return at(QStringLiteral("mSecondary"), QColor("#a9aefe")); }
    QColor mOnSecondary() const { return at(QStringLiteral("mOnSecondary"), QColor("#0e0e43")); }
    QColor mTertiary() const { return at(QStringLiteral("mTertiary"), QColor("#9bfece")); }
    QColor mOnTertiary() const { return at(QStringLiteral("mOnTertiary"), QColor("#0e0e43")); }
    QColor mError() const { return at(QStringLiteral("mError"), QColor("#fd4663")); }
    QColor mOnError() const { return at(QStringLiteral("mOnError"), QColor("#0e0e43")); }
    QColor mSurface() const { return at(QStringLiteral("mSurface"), QColor("#070722")); }
    QColor mOnSurface() const { return at(QStringLiteral("mOnSurface"), QColor("#f3edf7")); }
    QColor mSurfaceVariant() const { return at(QStringLiteral("mSurfaceVariant"), QColor("#11112d")); }
    QColor mOnSurfaceVariant() const { return at(QStringLiteral("mOnSurfaceVariant"), QColor("#7c80b4")); }
    QColor mOutline() const { return at(QStringLiteral("mOutline"), QColor("#21215f")); }
    QColor mShadow() const { return at(QStringLiteral("mShadow"), QColor("#070722")); }
    QColor mHover() const { return at(QStringLiteral("mHover"), QColor("#9bfece")); }
    QColor mOnHover() const { return at(QStringLiteral("mOnHover"), QColor("#0e0e43")); }

    bool usingNoctalia() const { return !m_colors.isEmpty(); }

signals:
    void colorsChanged();

private:
    QColor at(const QString &key, const QColor &fallback) const
    {
        return m_colors.value(key, fallback);
    }
    ColorSchemeProvider(QObject *parent, const QString &path);
    void reload();
    void armWatch();

    QHash<QString, QColor> m_colors;
    QFileSystemWatcher m_watcher;
    QString m_path;
};
