#include <QtTest/QtTest>
#include <QTemporaryDir>
#include <QPainter>

#include "dominantcolor.h"
#include "roundedimage.h"

namespace {

QImage paintRoundedImage(RoundedImage &image, const QSize &size)
{
    QImage output(size, QImage::Format_ARGB32_Premultiplied);
    output.fill(Qt::transparent);
    QPainter painter(&output);
    image.paint(&painter);
    return output;
}

QImage scaleImage(const QImage &source, const QSize &size)
{
    QImage output(size, QImage::Format_ARGB32_Premultiplied);
    output.fill(Qt::transparent);
    QPainter painter(&output);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    painter.drawImage(QRectF(QPointF(0, 0), QSizeF(size)), source);
    return output;
}

} // namespace

class TstRoundedImage : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;
    QString m_coverPath;
    QString m_patternPath;
    QImage m_cover;

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        m_cover = QImage(64, 64, QImage::Format_RGB32);
        m_cover.fill(QColor(200, 30, 30));
        m_coverPath = m_dir.filePath(QStringLiteral("cover.png"));
        QVERIFY(m_cover.save(m_coverPath));

        QImage pattern(600, 600, QImage::Format_RGB32);
        for (int y = 0; y < pattern.height(); ++y) {
            for (int x = 0; x < pattern.width(); ++x) {
                pattern.setPixelColor(x, y,
                                      QColor((x * 17 + y * 3) % 256,
                                             (x * 5 + y * 19) % 256,
                                             (x * 13 + y * 11) % 256));
            }
        }
        m_patternPath = m_dir.filePath(QStringLiteral("pattern.png"));
        QVERIFY(pattern.save(m_patternPath));
    }

    void colorAnalysisIsDisabledByDefault()
    {
        RoundedImage image;
        image.setWidth(64);
        image.setHeight(64);
        image.setSource(QUrl::fromLocalFile(m_coverPath));

        QCOMPARE(image.dominantColor().alpha(), 0);
        QVERIFY(image.colorSpots().isEmpty());
        QVERIFY(image.ready());
    }

    void optInPreservesTheExistingColorContract()
    {
        RoundedImage image;
        image.setWidth(64);
        image.setHeight(64);
        QVERIFY(image.setProperty("analyzeColors", true));
        image.setSource(QUrl::fromLocalFile(m_coverPath));

        QCOMPARE(image.dominantColor(), dominantColorOf(m_cover));
        const QVector<ColorSpot> expected = paletteOf(m_cover, 4);
        QCOMPARE(image.colorSpots().size(), expected.size());
        for (int i = 0; i < expected.size(); ++i) {
            const QVariantMap actual = image.colorSpots().at(i).toMap();
            QCOMPARE(actual.value(QStringLiteral("color")).value<QColor>(), expected.at(i).color);
            QCOMPARE(actual.value(QStringLiteral("x")).toReal(), expected.at(i).x);
            QCOMPARE(actual.value(QStringLiteral("y")).toReal(), expected.at(i).y);
            QCOMPARE(actual.value(QStringLiteral("weight")).toReal(), expected.at(i).weight);
        }
    }

    void resizeBurstKeepsTheLoadedArtworkUntilGeometrySettles()
    {
        RoundedImage image;
        image.setRadius(0);
        image.setWidth(64);
        image.setHeight(64);
        image.setSource(QUrl::fromLocalFile(m_patternPath));

        const QImage initial = paintRoundedImage(image, QSize(64, 64));
        QVERIFY(image.ready());

        for (int side = 80; side <= 300; side += 20) {
            image.setWidth(side);
            image.setHeight(side);
        }

        const QImage duringResize = paintRoundedImage(image, QSize(300, 300));
        const QImage scaledInitial = scaleImage(initial, QSize(300, 300));
        QCOMPARE(duringResize, scaledInitial);

        QTest::qWait(180);
        const QImage settled = paintRoundedImage(image, QSize(300, 300));
        QVERIFY(settled != scaledInitial);
        QVERIFY(image.ready());
    }
};

QTEST_MAIN(TstRoundedImage)
#include "tst_roundedimage.moc"
