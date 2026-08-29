#include "dominantcolor.h"

#include <QtMath>

#include <algorithm>

namespace {

// 48x48 basta: a cor de uma capa não muda por reamostrar, e uma capa de 1000x1000 custaria
// um milhão de leituras a cada troca de faixa. É múltiplo de 3, que é o lado da grade dos
// focos — assim cada célula tem exatamente 16x16 e nenhuma sobra de pixel muda de dono.
constexpr int kAmostra = 48;

// Abaixo do primeiro e acima do segundo o pixel não tem cor, tem luminosidade: é sombra,
// moldura ou brilho estourado.
constexpr int kValorMin = 40;
constexpr int kValorMax = 245;

// O halo vive num painel quase preto. Abaixo desta saturação ele lê como sujeira cinza;
// acima deste brilho ele apaga a capa que deveria emoldurar.
constexpr qreal kSatMin = 0.35;
constexpr qreal kSatMax = 0.85;
constexpr qreal kValorAlvo = 0.55;

// O lado da grade de focos: 3x3 = nove pedaços da capa. Menos que isso e um céu que ocupa a
// faixa de cima se mistura com o chão; mais e cada pedaço fica pequeno demais para ter cor
// própria, e os nove viram nove versões da mesma média.
constexpr int kGrade = 3;

// Dois focos precisam ser cores DIFERENTES para valer a pena. Abaixo desta distância de matiz
// o segundo não acrescenta cor nenhuma à luz, só peso de um lado.
constexpr int kDistanciaMinimaDeMatiz = 28;

// Menos cor que isto no pedaço inteiro e ele não tem voz: uma célula de 16x16 quase cinza
// acenderia uma luz que a arte não tem.
constexpr qreal kPesoMinimo = 8.0;

// O acumulador de uma região: soma vetorial do matiz (circular), soma da saturação e peso.
struct Acumulador
{
    qreal x = 0.0;
    qreal y = 0.0;
    qreal somaSat = 0.0;
    qreal peso = 0.0;

    void votar(int h, int s)
    {
        const qreal p = s / 255.0;
        const qreal rad = qDegreesToRadians(qreal(h));
        x += qCos(rad) * p;
        y += qSin(rad) * p;
        somaSat += p * p;
        peso += p;
    }

    int matiz() const
    {
        qreal hue = qRadiansToDegrees(qAtan2(y, x));
        if (hue < 0.0)
            hue += 360.0;
        return qRound(hue) % 360;
    }

    QColor cor() const
    {
        const qreal sat = qBound(kSatMin, somaSat / peso, kSatMax);
        return QColor::fromHsvF(qBound(0.0, matiz() / 360.0, 0.9999), sat, kValorAlvo);
    }
};

QImage amostraDe(const QImage &image)
{
    return image.scaled(kAmostra, kAmostra, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
        .convertToFormat(QImage::Format_RGB32);
}

int distanciaDeMatiz(int a, int b)
{
    const int d = qAbs(a - b) % 360;
    return d > 180 ? 360 - d : d;
}

} // namespace

QColor dominantColorOf(const QImage &image)
{
    if (image.isNull())
        return QColor(0, 0, 0, 0);

    const QImage amostra = amostraDe(image);
    Acumulador acc;

    for (int y = 0; y < amostra.height(); ++y) {
        for (int x = 0; x < amostra.width(); ++x) {
            int h = 0;
            int s = 0;
            int v = 0;
            amostra.pixelColor(x, y).getHsv(&h, &s, &v);
            // h == -1 é o acromático do Qt: cinza puro, sem matiz nenhum para votar.
            if (h < 0 || v < kValorMin || v > kValorMax)
                continue;
            acc.votar(h, s);
        }
    }

    // Peso desprezível = capa sem cor (escala de cinza, quase preta ou quase branca).
    if (acc.peso < 1.0)
        return QColor(0, 0, 0, 0);

    return acc.cor();
}

QVector<ColorSpot> paletteOf(const QImage &image, int maxSpots)
{
    if (image.isNull() || maxSpots <= 0)
        return {};

    const QImage amostra = amostraDe(image);
    const int lado = amostra.width() / kGrade;
    if (lado <= 0)
        return {};

    struct Candidato
    {
        Acumulador acc;
        int celulaX = 0;
        int celulaY = 0;
    };

    QVector<Candidato> candidatos;
    candidatos.reserve(kGrade * kGrade);

    for (int cy = 0; cy < kGrade; ++cy) {
        for (int cx = 0; cx < kGrade; ++cx) {
            Candidato c;
            c.celulaX = cx;
            c.celulaY = cy;
            for (int y = cy * lado; y < (cy + 1) * lado; ++y) {
                for (int x = cx * lado; x < (cx + 1) * lado; ++x) {
                    int h = 0;
                    int s = 0;
                    int v = 0;
                    amostra.pixelColor(x, y).getHsv(&h, &s, &v);
                    if (h < 0 || v < kValorMin || v > kValorMax)
                        continue;
                    c.acc.votar(h, s);
                }
            }
            if (c.acc.peso >= kPesoMinimo)
                candidatos.append(c);
        }
    }

    if (candidatos.isEmpty())
        return {};

    // Do pedaço mais colorido para o menos: quem tem mais cor acende primeiro, e é dele que
    // sai o foco mais forte.
    std::sort(candidatos.begin(), candidatos.end(),
              [](const Candidato &a, const Candidato &b) { return a.acc.peso > b.acc.peso; });

    const qreal pesoMaior = candidatos.first().acc.peso;

    QVector<ColorSpot> escolhidos;
    for (const Candidato &c : std::as_const(candidatos)) {
        if (escolhidos.size() >= maxSpots)
            break;

        const int matiz = c.acc.matiz();
        const bool repetido =
            std::any_of(escolhidos.cbegin(), escolhidos.cend(), [matiz](const ColorSpot &e) {
                return distanciaDeMatiz(e.color.hsvHue(), matiz) < kDistanciaMinimaDeMatiz;
            });
        if (repetido)
            continue;

        ColorSpot spot;
        spot.color = c.acc.cor();
        // O centro da célula, em fração do lado da capa: é onde a luz daquele pedaço nasce.
        spot.x = (c.celulaX + 0.5) / kGrade;
        spot.y = (c.celulaY + 0.5) / kGrade;
        spot.weight = qBound(0.0, c.acc.peso / pesoMaior, 1.0);
        escolhidos.append(spot);
    }

    return escolhidos;
}
