#pragma once

#include <QColor>
#include <QImage>
#include <QQuickPaintedItem>
#include <QSize>
#include <QTimer>
#include <QtQmlIntegration/qqmlintegration.h>

// O bloco de degradê diagonal que faz as vezes de capa quando não há arte.
//
// Por que saiu do QML: o `Canvas` desenha o degradê certo e mesmo assim ele aparece em
// FAIXAS. A causa não é o desenho — são ~31 níveis de cinza espalhados por 340 px, o que dá
// um patamar plano a cada 9 px (medido em 2026-08-29). Um degradê sutil não cabe em 8 bits
// por canal, e nenhuma parada de cor a mais conserta isso.
//
// O remédio é ruído de ±1 nível, que quebra a borda entre um patamar e o próximo; o olho
// integra o ruído de volta num degradê liso. E ele não pode ser feito no Canvas do QML:
// `getImageData` devolve os pixels, mas `putImageData` não os aplica — verificado comparando
// fotos, que saíram idênticas ao pixel. Aqui, com QPainter e uma QImage na mão, é uma linha.
//
// QPainter, e não shader, pelo mesmo motivo do RoundedImage: a saída por shader some no
// adaptador de software e leva o desenho junto.
class GradientBlock : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QColor topColor READ topColor WRITE setTopColor NOTIFY topColorChanged)
    Q_PROPERTY(QColor midColor READ midColor WRITE setMidColor NOTIFY midColorChanged)
    Q_PROPERTY(QColor bottomColor READ bottomColor WRITE setBottomColor NOTIFY bottomColorChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)

public:
    explicit GradientBlock(QQuickItem *parent = nullptr);

    QColor topColor() const { return m_top; }
    void setTopColor(const QColor &c);

    QColor midColor() const { return m_mid; }
    void setMidColor(const QColor &c);

    QColor bottomColor() const { return m_bottom; }
    void setBottomColor(const QColor &c);

    qreal radius() const { return m_radius; }
    void setRadius(qreal r);

    void paint(QPainter *painter) override;

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

signals:
    void topColorChanged();
    void midColorChanged();
    void bottomColorChanged();
    void radiusChanged();

private:
    // O desenho pronto, guardado. `paint()` é chamado a cada quadro em que a cena redesenha, e
    // recalcular 115 mil pixels ali dentro saturava um núcleo inteiro — medido em 2026-08-29:
    // 103 ticks de CPU por segundo com o app parado. O degradê só muda quando o bloco muda de
    // tamanho ou de cor, que é o que estas duas chaves guardam.
    void rebuild();
    QImage m_cache;
    QSize m_cacheSize;
    QColor m_cacheTop;
    QColor m_cacheMid;
    QColor m_cacheBottom;
    qreal m_cacheRadius = -1.0;

    QColor m_top;
    QColor m_mid;
    QColor m_bottom;
    qreal m_radius = 0.0;
    QTimer m_resizeTimer;
    bool m_resizeSettled = true;
};
