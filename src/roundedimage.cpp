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
}

void RoundedImage::setSource(const QUrl &url)
{
    if (m_source == url)
        return;
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

void RoundedImage::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
    // Só relê quando a imagem em memória ficou pequena demais para a caixa: crescer uma capa
    // lida a 62 px até 340 borra, encolher não.
    if (newGeometry.width() > m_loadedFor)
        reload();
    else
        update();
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

    const QColor antes = m_dominant;
    m_dominant = dominantColorOf(m_image);
    if (m_dominant != antes)
        emit dominantColorChanged();

    if (tinha != ready())
        emit readyChanged();
    update();
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
