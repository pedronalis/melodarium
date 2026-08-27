#include <QtTest/QtTest>
#include <QTemporaryDir>
#include <QFile>

#include "colorschemeprovider.h"

class TstColorScheme : public QObject
{
    Q_OBJECT

private slots:
    void missingFileFallsBackToNoctaliaDefaults()
    {
        QScopedPointer<ColorSchemeProvider> p(
            ColorSchemeProvider::createForPath(QStringLiteral("/nonexistent/colors.json")));
        QCOMPARE(p->usingNoctalia(), false);
        QCOMPARE(p->mSurface(), QColor("#070722"));
        QCOMPARE(p->mPrimary(), QColor("#fff59b"));
    }

    void validFileOverridesDefaults()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString path = dir.filePath(QStringLiteral("colors.json"));
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        // Not a raw string literal: moc 6.10.3 treats a `#` inside R"(...)" as a
        // preprocessor directive, silently emits no meta-object, and the test fails
        // to link with "undefined reference to vtable".
        f.write("{\"mSurface\": \"#111111\", \"mPrimary\": \"#aaaaaa\"}");
        f.close();

        QScopedPointer<ColorSchemeProvider> p(ColorSchemeProvider::createForPath(path));
        QCOMPARE(p->usingNoctalia(), true);
        QCOMPARE(p->mSurface(), QColor("#111111"));
        QCOMPARE(p->mPrimary(), QColor("#aaaaaa"));
        // Key absent from the file must still fall back, not become invalid.
        QCOMPARE(p->mOnSurface(), QColor("#f3edf7"));
    }

    void malformedJsonIsTreatedAsMissing()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString path = dir.filePath(QStringLiteral("colors.json"));
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("{ this is not json");
        f.close();

        QScopedPointer<ColorSchemeProvider> p(ColorSchemeProvider::createForPath(path));
        QCOMPARE(p->usingNoctalia(), false);
        QCOMPARE(p->mSurface(), QColor("#070722"));
    }
};

QTEST_MAIN(TstColorScheme)
#include "tst_colorscheme.moc"
