#include <QtTest/QtTest>

#include <QPainter>

#include "gradientblock.h"

namespace {

QImage paintBlock(GradientBlock &block, const QSize &size)
{
    QImage output(size, QImage::Format_ARGB32_Premultiplied);
    output.fill(Qt::transparent);
    QPainter painter(&output);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    block.paint(&painter);
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

class TstGradientBlock : public QObject
{
    Q_OBJECT

private slots:
    void resizeBurstKeepsTheFinishedRasterUntilGeometrySettles()
    {
        GradientBlock block;
        block.setTopColor(QColor(QStringLiteral("#3a3a3a")));
        block.setMidColor(QColor(QStringLiteral("#262626")));
        block.setBottomColor(QColor(QStringLiteral("#191919")));
        block.setRadius(16);
        block.setWidth(100);
        block.setHeight(100);

        const QImage initial = paintBlock(block, QSize(100, 100));
        QVERIFY(!initial.isNull());
        QCOMPARE(initial.pixelColor(50, 50).alpha(), 255);

        for (int width = 120; width <= 300; width += 20) {
            block.setWidth(width);
            block.setRadius(16.0 * width / 100.0);
        }

        const QImage duringResize = paintBlock(block, QSize(300, 100));
        const QImage scaledInitial = scaleImage(initial, QSize(300, 100));
        QCOMPARE(duringResize, scaledInitial);
        QCOMPARE(duringResize.pixelColor(299, 50).alpha(), 255);

        QTest::qWait(180);
        const QImage settled = paintBlock(block, QSize(300, 100));
        QVERIFY(settled != scaledInitial);
        QCOMPARE(settled.pixelColor(299, 50).alpha(), 255);
    }
};

QTEST_MAIN(TstGradientBlock)
#include "tst_gradientblock.moc"
