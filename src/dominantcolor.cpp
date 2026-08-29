#include "dominantcolor.h"

#include <QtMath>

namespace {

// 48x48 basta: a cor de uma capa não muda por reamostrar, e uma capa de 1000x1000 custaria
// um milhão de leituras a cada troca de faixa.
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

} // namespace

QColor dominantColorOf(const QImage &image)
{
    if (image.isNull())
        return QColor(0, 0, 0, 0);

    const QImage amostra = image
                               .scaled(kAmostra, kAmostra, Qt::IgnoreAspectRatio,
                                       Qt::SmoothTransformation)
                               .convertToFormat(QImage::Format_RGB32);

    qreal somaX = 0.0;
    qreal somaY = 0.0;
    qreal somaSat = 0.0;
    qreal peso = 0.0;

    for (int y = 0; y < amostra.height(); ++y) {
        for (int x = 0; x < amostra.width(); ++x) {
            int h = 0;
            int s = 0;
            int v = 0;
            amostra.pixelColor(x, y).getHsv(&h, &s, &v);
            // h == -1 é o acromático do Qt: cinza puro, sem matiz nenhum para votar.
            if (h < 0 || v < kValorMin || v > kValorMax)
                continue;
            const qreal p = s / 255.0;
            const qreal rad = qDegreesToRadians(qreal(h));
            somaX += qCos(rad) * p;
            somaY += qSin(rad) * p;
            somaSat += p * p;
            peso += p;
        }
    }

    // Peso desprezível = capa sem cor (escala de cinza, quase preta ou quase branca).
    if (peso < 1.0)
        return QColor(0, 0, 0, 0);

    qreal hue = qRadiansToDegrees(qAtan2(somaY, somaX));
    if (hue < 0.0)
        hue += 360.0;

    const qreal sat = qBound(kSatMin, somaSat / peso, kSatMax);
    return QColor::fromHsvF(qBound(0.0, hue / 360.0, 0.9999), sat, kValorAlvo);
}
