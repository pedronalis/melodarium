#include <QtTest/QtTest>
#include <QPainter>

#include "dominantcolor.h"

class TstDominantColor : public QObject
{
    Q_OBJECT

private:
    static QImage cheia(const QColor &c, int lado = 64)
    {
        QImage img(lado, lado, QImage::Format_RGB32);
        img.fill(c);
        return img;
    }

    // Matiz é um ângulo: a distância entre 350 e 10 é 20, não 340.
    static int distanciaDeMatiz(int a, int b)
    {
        const int d = qAbs(a - b) % 360;
        return d > 180 ? 360 - d : d;
    }

private slots:
    void imagemNulaNaoTemCor()
    {
        QCOMPARE(dominantColorOf(QImage()).alpha(), 0);
    }

    void capaEmEscalaDeCinzaNaoTemCor()
    {
        // Halo cinza num painel cinza é sujeira, não ambiente: melhor não pintar nada.
        QCOMPARE(dominantColorOf(cheia(QColor(120, 120, 120))).alpha(), 0);
    }

    void capaQuaseBrancaNaoTemCor()
    {
        QCOMPARE(dominantColorOf(cheia(QColor(252, 250, 250))).alpha(), 0);
    }

    void vermelhoSaiVermelho()
    {
        const QColor c = dominantColorOf(cheia(QColor(200, 30, 30)));
        QCOMPARE(c.alpha(), 255);
        QVERIFY2(distanciaDeMatiz(c.hsvHue(), 0) < 12,
                 qPrintable(QStringLiteral("hue = %1").arg(c.hsvHue())));
    }

    void azulSaiAzul()
    {
        const QColor c = dominantColorOf(cheia(QColor(30, 60, 210)));
        QCOMPARE(c.alpha(), 255);
        QVERIFY2(distanciaDeMatiz(c.hsvHue(), 230) < 20,
                 qPrintable(QStringLiteral("hue = %1").arg(c.hsvHue())));
    }

    void oPretoNaoVota()
    {
        // Capa quase toda preta com uma faixa verde: a capa "é" verde. Uma média crua
        // devolveria algo escuro demais para virar luz.
        QImage img(64, 64, QImage::Format_RGB32);
        img.fill(Qt::black);
        QPainter p(&img);
        p.fillRect(0, 0, 64, 8, QColor(20, 200, 90));
        p.end();

        const QColor c = dominantColorOf(img);
        QCOMPARE(c.alpha(), 255);
        QVERIFY2(distanciaDeMatiz(c.hsvHue(), 143) < 20,
                 qPrintable(QStringLiteral("hue = %1").arg(c.hsvHue())));
    }

    void oBrilhoFicaNaFaixaDoPainel()
    {
        // Uma capa clara não pode devolver um halo que apague a arte que ele emoldura.
        const QColor c = dominantColorOf(cheia(QColor(230, 220, 110)));
        QCOMPARE(c.alpha(), 255);
        QVERIFY2(c.valueF() > 0.5 && c.valueF() < 0.6,
                 qPrintable(QStringLiteral("value = %1").arg(c.valueF())));
    }

    void aMediaDoMatizEhCircular()
    {
        // Metade vermelho-alaranjado (hue 10), metade vermelho-arroxeado (hue 350). A média
        // certa é 0 (vermelho); a média aritmética daria 180 (ciano), que é a cor oposta.
        QImage img(64, 64, QImage::Format_RGB32);
        QPainter p(&img);
        p.fillRect(0, 0, 64, 32, QColor::fromHsv(10, 200, 180));
        p.fillRect(0, 32, 64, 32, QColor::fromHsv(350, 200, 180));
        p.end();

        const QColor c = dominantColorOf(img);
        QCOMPARE(c.alpha(), 255);
        QVERIFY2(distanciaDeMatiz(c.hsvHue(), 0) < 15,
                 qPrintable(QStringLiteral("hue = %1").arg(c.hsvHue())));
    }
};

QTEST_MAIN(TstDominantColor)
#include "tst_dominantcolor.moc"
