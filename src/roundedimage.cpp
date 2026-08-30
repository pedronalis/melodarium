#include "roundedimage.h"

#include "dominantcolor.h"

#include <QImageReader>
#include <QPainter>
#include <QPainterPath>

RoundedImage::RoundedImage(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    // Sem isto o canto arredondado sai serrilhado: o item é desenhado direto na cena, e a
    // borda curva não ganha as amostras extras que a moldura precisa.
    setRenderTarget(QQuickPaintedItem::FramebufferObject);

    m_resizeTimer.setSingleShot(true);
    m_resizeTimer.setInterval(120);
    connect(&m_resizeTimer, &QTimer::timeout, this, [this] {
        const int side = qCeil(qMax(width(), height()));
        if (side > m_loadedFor)
            reload();
    });
}

void RoundedImage::setSource(const QUrl &url)
{
    if (m_source == url)
        return;
    m_resizeTimer.stop();
    m_source = url;
    emit sourceChanged();
    reload();
}

void RoundedImage::setRadius(qreal r)
{
    if (qFuzzyCompare(m_radius, r))
        return;
    m_radius = r;
    emit radiusChanged();
    update();
}

void RoundedImage::setAnalyzeColors(bool analyze)
{
    if (m_analyzeColors == analyze)
        return;
    m_analyzeColors = analyze;
    emit analyzeColorsChanged();
    updateColorAnalysis();
}

void RoundedImage::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
    // Keep the finished texture visible through a configure burst. Decoding every intermediate
    // size blocks the GUI thread and briefly clears the artwork; the final exact decode happens
    // once after geometry settles.
    const int side = qCeil(qMax(newGeometry.width(), newGeometry.height()));
    if (side > m_loadedFor && m_image.isNull())
        reload();
    else if (side > m_loadedFor) {
        m_resizeTimer.start();
        update();
    } else {
        m_resizeTimer.stop();
        update();
    }
}

void RoundedImage::reload()
{
    const bool tinha = ready();
    m_image = QImage();
    m_loadedFor = 0;

    const QString caminho = m_source.isLocalFile() ? m_source.toLocalFile() : QString();
    const int lado = qCeil(qMax(width(), height()));
    if (!caminho.isEmpty() && lado > 0) {
        QImageReader reader(caminho);
        const QSize original = reader.size();
        if (original.isValid() && !original.isEmpty()) {
            // Lê já na medida em que vai ser mostrada: uma capa de 1400 px decodificada
            // inteira para caber num quadrado de 62 é o custo que a tirinha da fila paga 5
            // vezes a cada troca de faixa.
            const qreal fator = qMax(qreal(lado) / original.width(), qreal(lado) / original.height());
            reader.setScaledSize(QSize(qMax(1, qRound(original.width() * fator)),
                                       qMax(1, qRound(original.height() * fator))));
        }
        reader.setAutoTransform(true);
        m_image = reader.read();
        m_loadedFor = lado;
    }

    updateColorAnalysis();

    if (tinha != ready())
        emit readyChanged();
    update();
}

void RoundedImage::updateColorAnalysis()
{
    const ColorAnalysis analysis = m_analyzeColors
                                       ? analyzeImageColors(m_image, 4)
                                       : ColorAnalysis();

    const QColor antes = m_dominant;
    m_dominant = analysis.dominant;
    if (m_dominant != antes)
        emit dominantColorChanged();

    QVariantList spots;
    for (const ColorSpot &foco : analysis.spots) {
        QVariantMap m;
        m.insert(QStringLiteral("color"), foco.color);
        m.insert(QStringLiteral("x"), foco.x);
        m.insert(QStringLiteral("y"), foco.y);
        m.insert(QStringLiteral("weight"), foco.weight);
        spots.append(m);
    }
    if (m_spots != spots) {
        m_spots = spots;
        emit colorSpotsChanged();
    }
}

void RoundedImage::paint(QPainter *painter)
{
    if (m_image.isNull())
        return;

    const QRectF caixa(0, 0, width(), height());
    painter->setRenderHint(QPainter::Antialiasing, true);
    painter->setRenderHint(QPainter::SmoothPixmapTransform, true);

    QPainterPath moldura;
    moldura.addRoundedRect(caixa, m_radius, m_radius);
    painter->setClipPath(moldura);

    // PreserveAspectCrop: a capa preenche o quadrado e o excedente sai pelas bordas, em vez de
    // deformar a arte ou deixar faixa vazia.
    const QSizeF imagem(m_image.size());
    const qreal fator = qMax(caixa.width() / imagem.width(), caixa.height() / imagem.height());
    const QSizeF destino(imagem.width() * fator, imagem.height() * fator);
    const QRectF alvo(caixa.center().x() - destino.width() / 2.0,
                      caixa.center().y() - destino.height() / 2.0,
                      destino.width(), destino.height());
    painter->drawImage(alvo, m_image);
}
