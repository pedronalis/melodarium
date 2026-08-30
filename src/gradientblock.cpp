#include "gradientblock.h"

#include <QLinearGradient>
#include <QPainter>
#include <QPainterPath>
#include <QRandomGenerator>

#include <array>
#include <QtMath>

GradientBlock::GradientBlock(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    // Sem isto o canto arredondado sai serrilhado — mesma razão do RoundedImage.
    // Alvo em IMAGEM, não em FBO: este app rasteriza por software (sem GPU aberta), e o FBO
    // faz a cena redesenhar a cada quadro — 99 ticks de CPU por segundo com o app parado,
    // medido em 2026-08-29. Em imagem, o item é desenhado uma vez e fica.
    setRenderTarget(QQuickPaintedItem::Image);

    m_resizeTimer.setSingleShot(true);
    m_resizeTimer.setInterval(120);
    connect(&m_resizeTimer, &QTimer::timeout, this, [this] {
        m_resizeSettled = true;
        update();
    });
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

    if (!m_cache.isNull()) {
        m_resizeSettled = false;
        m_resizeTimer.start();
    }
    update();
}

namespace {

// Interpola as três paradas do desenho em PONTO FLUTUANTE: top em 0, mid em 0,45, bottom em 1.
// É por existir em float que o dithering abaixo tem o que arredondar.
inline void corEm(qreal t, const QColor &top, const QColor &mid, const QColor &bottom,
                  qreal *r, qreal *g, qreal *b)
{
    if (t <= 0.45) {
        const qreal k = t / 0.45;
        *r = top.redF() + (mid.redF() - top.redF()) * k;
        *g = top.greenF() + (mid.greenF() - top.greenF()) * k;
        *b = top.blueF() + (mid.blueF() - top.blueF()) * k;
    } else {
        const qreal k = (t - 0.45) / 0.55;
        *r = mid.redF() + (bottom.redF() - mid.redF()) * k;
        *g = mid.greenF() + (bottom.greenF() - mid.greenF()) * k;
        *b = mid.blueF() + (bottom.blueF() - mid.blueF()) * k;
    }
}

// A tabela de ruído, calculada uma vez. Duas chamadas ao gerador aleatório POR PIXEL custam
// caro num bloco de 340x340 que o Qt repinta mais de uma vez; uma leitura de tabela não custa
// nada. 64x64 é grande o bastante para o padrão não se ver: a repetição cai a cada 64 px e o
// olho não acha periodicidade em ruído de um nível.
constexpr int kRuidoLado = 64;

const float *tabelaDeRuido()
{
    static const std::array<float, kRuidoLado * kRuidoLado> tabela = [] {
        std::array<float, kRuidoLado * kRuidoLado> t{};
        auto *rng = QRandomGenerator::global();
        for (auto &v : t) {
            // Ruído TRIANGULAR (soma de dois uniformes): é o que a literatura de áudio e
            // imagem usa para dithering, porque espalha o erro sem deixar padrão no grão.
            v = float(rng->generateDouble() + rng->generateDouble() - 1.0);
        }
        return t;
    }();
    return tabela.data();
}

} // namespace

void GradientBlock::paint(QPainter *painter)
{
    const QSize currentSize(qCeil(width()), qCeil(height()));
    const bool colorsChanged = m_cache.isNull() || m_cacheTop != m_top || m_cacheMid != m_mid
                               || m_cacheBottom != m_bottom;
    const bool settledRasterChanged = m_cacheSize != currentSize
                                      || !qFuzzyCompare(m_cacheRadius, m_radius);
    if (colorsChanged || (m_resizeSettled && settledRasterChanged))
        rebuild();

    if (!m_cache.isNull()) {
        painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
        painter->drawImage(QRectF(0, 0, width(), height()), m_cache);
    }
}

void GradientBlock::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);

    const QSize nextSize(qCeil(newGeometry.width()), qCeil(newGeometry.height()));
    if (m_cache.isNull() || nextSize == m_cacheSize) {
        m_resizeTimer.stop();
        m_resizeSettled = true;
        return;
    }

    // Keep stretching the finished dithered raster while configure events arrive. Rebuilding
    // it for every intermediate pixel runs the per-pixel gradient and mask on the GUI thread.
    m_resizeSettled = false;
    m_resizeTimer.start();
}

// Refaz o degradê só quando alguma coisa que o define mudou. Sem esta guarda, `paint()` é o
// caminho quente da cena e o bloco é recalculado a cada quadro.
void GradientBlock::rebuild()
{
    const int w = qCeil(width());
    const int h = qCeil(height());
    if (w <= 0 || h <= 0 || !m_top.isValid()) {
        m_cache = QImage();
        return;
    }

    const QSize tamanho(w, h);
    if (!m_cache.isNull() && m_cacheSize == tamanho && m_cacheTop == m_top
        && m_cacheMid == m_mid && m_cacheBottom == m_bottom
        && qFuzzyCompare(m_cacheRadius, m_radius))
        return;

    m_cacheSize = tamanho;
    m_cacheTop = m_top;
    m_cacheMid = m_mid;
    m_cacheBottom = m_bottom;
    m_cacheRadius = m_radius;

    // O degradê é calculado pixel a pixel, e não com QLinearGradient, por um motivo só: o
    // gradiente do Qt já entrega a cor QUANTIZADA em 8 bits. Somar ruído depois disso mexe
    // pixels aleatórios e não reconstrói rampa nenhuma — as listras continuam onde estavam
    // (tentado e medido em 2026-08-29: as faixas planas caíram de 58% para 11% das amostras e
    // o Pedro continuou vendo escada na tela).
    //
    // Dithering de verdade acontece NA HORA DE ARREDONDAR: a cor exata existe em ponto
    // flutuante, soma-se ruído de ~1 nível, e só então se corta para inteiro. Onde a rampa
    // está no meio de dois níveis, os pixels vizinhos caem metade para cada lado, e o olho
    // integra de volta o degrau que 8 bits não sabem representar.
    QImage buffer(w, h, QImage::Format_ARGB32_Premultiplied);
    buffer.fill(Qt::transparent);

    // O ângulo do CSS conta a partir do "para cima" e cresce no sentido horário, e a linha do
    // degradê é centrada na caixa — por isso o vetor sai do centro para os dois lados, e não
    // de canto a canto: em 145° num quadrado ela mede 473 px numa caixa de 340, e cortar isso
    // nos cantos deslocaria as paradas de cor.
    const qreal a = qDegreesToRadians(145.0);
    const qreal dx = qSin(a);
    const qreal dy = -qCos(a);
    const qreal comprimento = qAbs(w * dx) + qAbs(h * dy);
    const qreal cx = w / 2.0;
    const qreal cy = h / 2.0;
    const qreal x0 = cx - dx * comprimento / 2;
    const qreal y0 = cy - dy * comprimento / 2;

    const float *ruidoTab = tabelaDeRuido();

    for (int y = 0; y < h; ++y) {
        const int ry = (y % kRuidoLado) * kRuidoLado;
        auto *linha = reinterpret_cast<QRgb *>(buffer.scanLine(y));
        for (int x = 0; x < w; ++x) {
            // Onde este pixel cai ao longo do eixo do degradê.
            const qreal t = qBound(0.0, ((x + 0.5 - x0) * dx + (y + 0.5 - y0) * dy) / comprimento,
                                   1.0);
            qreal r = 0;
            qreal g = 0;
            qreal b = 0;
            corEm(t, m_top, m_mid, m_bottom, &r, &g, &b);

            // Ruído TRIANGULAR (a soma de dois uniformes), que é o que a literatura de áudio e
            // imagem usa para dithering: ele espalha o erro sem deixar o grão com padrão. A
            // amplitude é de ~1 nível — abaixo disso não quebra a faixa, acima começa a virar
            // textura visível.
            const qreal ruido = ruidoTab[ry + (x % kRuidoLado)];
            const int ri = qBound(0, int(r * 255.0 + ruido + 0.5), 255);
            const int gi = qBound(0, int(g * 255.0 + ruido + 0.5), 255);
            const int bi = qBound(0, int(b * 255.0 + ruido + 0.5), 255);
            linha[x] = qRgb(ri, gi, bi);
        }
    }

    // O canto arredondado é recortado depois: desenhar o degradê já dentro de um path faria o
    // Qt antialiar a borda ANTES do dithering, e a borda voltaria a ser um degrau duro.
    QImage mascara(w, h, QImage::Format_ARGB32_Premultiplied);
    mascara.fill(Qt::transparent);
    {
        QPainter mp(&mascara);
        mp.setRenderHint(QPainter::Antialiasing, true);
        QPainterPath moldura;
        moldura.addRoundedRect(QRectF(0, 0, w, h), m_radius, m_radius);
        mp.fillPath(moldura, Qt::white);
    }
    {
        QPainter bp(&buffer);
        bp.setCompositionMode(QPainter::CompositionMode_DestinationIn);
        bp.drawImage(0, 0, mascara);
    }

    m_cache = buffer;
}
