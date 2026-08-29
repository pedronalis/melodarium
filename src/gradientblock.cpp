#include "gradientblock.h"

#include <QLinearGradient>
#include <QPainter>
#include <QPainterPath>
#include <QRandomGenerator>
#include <QtMath>

GradientBlock::GradientBlock(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    // Sem isto o canto arredondado sai serrilhado — mesma razão do RoundedImage.
    setRenderTarget(QQuickPaintedItem::FramebufferObject);
}

void GradientBlock::setTopColor(const QColor &c)
{
    if (m_top == c)
        return;
    m_top = c;
    emit topColorChanged();
    update();
}

void GradientBlock::setMidColor(const QColor &c)
{
    if (m_mid == c)
        return;
    m_mid = c;
    emit midColorChanged();
    update();
}

void GradientBlock::setBottomColor(const QColor &c)
{
    if (m_bottom == c)
        return;
    m_bottom = c;
    emit bottomColorChanged();
    update();
}

void GradientBlock::setRadius(qreal r)
{
    if (qFuzzyCompare(m_radius, r))
        return;
    m_radius = r;
    emit radiusChanged();
    update();
}

void GradientBlock::paint(QPainter *painter)
{
    const int w = qCeil(width());
    const int h = qCeil(height());
    if (w <= 0 || h <= 0 || !m_top.isValid())
        return;

    // O degradê é desenhado numa imagem própria porque o ruído precisa dos pixels na mão.
    QImage buffer(w, h, QImage::Format_ARGB32_Premultiplied);
    buffer.fill(Qt::transparent);

    {
        QPainter p(&buffer);
        p.setRenderHint(QPainter::Antialiasing, true);

        // O ângulo do CSS conta a partir do "para cima" e cresce no sentido horário, e a
        // linha do degradê é centrada na caixa — por isso o vetor sai do centro para os dois
        // lados, e não de canto a canto: em 145° num quadrado ela mede 473 px numa caixa de
        // 340, e cortar isso nos cantos deslocaria as paradas de cor.
        const qreal a = qDegreesToRadians(145.0);
        const qreal dx = qSin(a);
        const qreal dy = -qCos(a);
        const qreal comprimento = qAbs(w * dx) + qAbs(h * dy);
        const qreal cx = w / 2.0;
        const qreal cy = h / 2.0;

        QLinearGradient g(cx - dx * comprimento / 2, cy - dy * comprimento / 2,
                          cx + dx * comprimento / 2, cy + dy * comprimento / 2);
        g.setColorAt(0.0, m_top);
        g.setColorAt(0.45, m_mid);
        g.setColorAt(1.0, m_bottom);

        QPainterPath moldura;
        moldura.addRoundedRect(QRectF(0, 0, w, h), m_radius, m_radius);
        p.fillPath(moldura, g);
    }

    // O ruído: ±1 nível por pixel. Invisível como grão, decisivo como quebra de faixa — é o
    // que impede que 31 níveis de cinza espalhados por 340 px leiam como listras diagonais.
    // Pixel transparente fica de fora: fora do canto arredondado não há bloco, e mexer ali
    // desenharia um quadrado fantasma por cima da moldura tracejada.
    auto *rng = QRandomGenerator::global();
    for (int y = 0; y < h; ++y) {
        auto *linha = reinterpret_cast<QRgb *>(buffer.scanLine(y));
        for (int x = 0; x < w; ++x) {
            const QRgb px = linha[x];
            const int alfa = qAlpha(px);
            if (alfa == 0)
                continue;
            const int d = int(rng->bounded(3)) - 1;
            if (d == 0)
                continue;
            linha[x] = qRgba(qBound(0, qRed(px) + d, alfa),
                             qBound(0, qGreen(px) + d, alfa),
                             qBound(0, qBlue(px) + d, alfa),
                             alfa);
        }
    }

    painter->drawImage(0, 0, buffer);
}
