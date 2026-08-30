#include <QtTest/QtTest>
#include <QTemporaryDir>

#include "dominantcolor.h"
#include "roundedimage.h"

class TstRoundedImage : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;
    QString m_coverPath;
    QImage m_cover;

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        m_cover = QImage(64, 64, QImage::Format_RGB32);
        m_cover.fill(QColor(200, 30, 30));
        m_coverPath = m_dir.filePath(QStringLiteral("cover.png"));
        QVERIFY(m_cover.save(m_coverPath));
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
};

QTEST_MAIN(TstRoundedImage)
#include "tst_roundedimage.moc"
