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

    // --- paletteOf: a luz de uma capa não é uma cor só ---

    void capaSemCorNaoTemPaleta()
    {
        QVERIFY(paletteOf(cheia(QColor(120, 120, 120))).isEmpty());
        QVERIFY(paletteOf(QImage()).isEmpty());
    }

    void capaDeUmaCorSoDaUmFocoSo()
    {
        // Nove pedaços da mesma cor: o segundo, o terceiro e o quarto não acrescentam luz
        // nenhuma, e entrar todos só deixaria o halo mais forte sem ficar mais rico.
        const QVector<ColorSpot> p = paletteOf(cheia(QColor(200, 30, 30)));
        QCOMPARE(p.size(), 1);
        QVERIFY(distanciaDeMatiz(p.first().color.hsvHue(), 0) < 12);
        QCOMPARE(p.first().weight, 1.0);
    }

    void ceuEmCimaAreiaEmbaixoDaoDoisFocos()
    {
        // O caso que a cor média estraga: azul em cima, laranja embaixo. A média das duas é
        // um bege que não existe na arte — a paleta precisa devolver as DUAS.
        QImage img(96, 96, QImage::Format_RGB32);
        QPainter pt(&img);
        pt.fillRect(0, 0, 96, 48, QColor(40, 90, 210));    // azul, hue ~215
        pt.fillRect(0, 48, 96, 48, QColor(220, 130, 30));  // laranja, hue ~31
        pt.end();

        const QVector<ColorSpot> p = paletteOf(img);
        // Dois focos no mínimo — e pode sair um terceiro: a faixa do meio da grade pega
        // metade de cada cor e tem matiz próprio. Isso é a capa, não um defeito: numa arte
        // de verdade a transição entre duas cores também acende luz.
        QVERIFY2(p.size() >= 2, qPrintable(QStringLiteral("focos = %1").arg(p.size())));

        // O que importa é que cada foco sabe de que metade da capa ele veio.
        const ColorSpot *azul = nullptr;
        const ColorSpot *laranja = nullptr;
        for (const ColorSpot &s : p) {
            if (distanciaDeMatiz(s.color.hsvHue(), 215) < 25)
                azul = &s;
            if (distanciaDeMatiz(s.color.hsvHue(), 31) < 25)
                laranja = &s;
        }
        QVERIFY2(azul, "o azul do topo não virou foco");
        QVERIFY2(laranja, "o laranja da base não virou foco");
        QVERIFY2(azul->y < 0.5, qPrintable(QStringLiteral("azul em y=%1").arg(azul->y)));
        QVERIFY2(laranja->y > 0.5, qPrintable(QStringLiteral("laranja em y=%1").arg(laranja->y)));
    }

    void oTetoDeFocosEhRespeitado()
    {
        // Quatro faixas de cores bem distantes numa capa: com teto 2, saem as duas mais
        // coloridas, nunca as quatro.
        QImage img(96, 96, QImage::Format_RGB32);
        QPainter pt(&img);
        pt.fillRect(0, 0, 96, 24, QColor::fromHsv(0, 220, 190));
        pt.fillRect(0, 24, 96, 24, QColor::fromHsv(90, 220, 190));
        pt.fillRect(0, 48, 96, 24, QColor::fromHsv(180, 220, 190));
        pt.fillRect(0, 72, 96, 24, QColor::fromHsv(270, 220, 190));
        pt.end();

        QVERIFY(paletteOf(img, 2).size() <= 2);
        QVERIFY(paletteOf(img, 4).size() >= 2);
    }

    void oPesoEhRelativoAoPedacoMaisColorido()
    {
        // Metade vermelho forte, metade verde apagado: o vermelho vale 1,0 e o verde vale
        // menos — é o peso que faz o foco fraco acender menos.
        QImage img(96, 96, QImage::Format_RGB32);
        QPainter pt(&img);
        pt.fillRect(0, 0, 96, 48, QColor::fromHsv(0, 240, 200));
        pt.fillRect(0, 48, 96, 48, QColor::fromHsv(120, 60, 140));
        pt.end();

        const QVector<ColorSpot> p = paletteOf(img);
        QVERIFY(p.size() >= 2);
        QCOMPARE(p.first().weight, 1.0);
        QVERIFY2(p.at(1).weight < 1.0,
                 qPrintable(QStringLiteral("peso do segundo = %1").arg(p.at(1).weight)));
        QVERIFY(p.at(1).weight > 0.0);
    }
};

QTEST_MAIN(TstDominantColor)
#include "tst_dominantcolor.moc"
