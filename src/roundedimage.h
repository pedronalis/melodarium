#pragma once

#include <QImage>
#include <QQuickPaintedItem>
#include <QUrl>
#include <QtQmlIntegration/qqmlintegration.h>

// Uma imagem com o canto arredondado do desenho, desenhada com QPainter.
//
// Por que não sai do QML: `radius` desenha o canto do Rectangle e `clip: true` recorta os
// filhos pelo RETÂNGULO, não pelo raio — a capa continuava de canto vivo por cima da moldura
// arredondada. A saída natural seria MultiEffect com máscara, e ela funciona na tela do
// usuário, mas é um shader: no adaptador de software (que é como o app é fotografado, e como
// ele roda numa máquina sem GPU) o efeito não desenha NADA e a capa some inteira. Medido em
// 2026-08-28. QPainter desenha igual nos dois mundos.
class RoundedImage : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

public:
    explicit RoundedImage(QQuickItem *parent = nullptr);

    QUrl source() const { return m_source; }
    void setSource(const QUrl &url);

    qreal radius() const { return m_radius; }
    void setRadius(qreal r);

    bool ready() const { return !m_image.isNull(); }

    void paint(QPainter *painter) override;

signals:
    void sourceChanged();
    void radiusChanged();
    void readyChanged();

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
    void reload();

    QUrl m_source;
    qreal m_radius = 0.0;
    QImage m_image;
    // A que largura a imagem em memória foi lida. Reler a cada pixel de redimensionamento
    // torraria o disco enquanto a janela é arrastada.
    int m_loadedFor = 0;
};
