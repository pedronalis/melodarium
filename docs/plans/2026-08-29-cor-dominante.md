---
slug: cor-dominante
feature: melodarium-anima
status: aprovado
depende-de: []
decisao-humana: nao
spec: docs/plans/research/2026-08-29-anima-varredura.md
---

# Plano: cor-dominante

**Goal:** Descobrir de que cor uma capa "é", para o halo que o painel vai projetar atrás dela.
Fatia inteiramente em C++, com teste próprio — é o único pedaço deste lote que pode ser
provado por máquina, e é de propósito que ele não encosta em QML.

**Arquitetura:** Uma função livre `dominantColorOf(const QImage&)` num par de arquivos próprio,
sem Qt Quick e sem estado — testável com imagens sintéticas. `RoundedImage` (que já mantém a
`QImage` da capa em memória) a chama ao terminar cada carga e expõe o resultado como
`Q_PROPERTY`. Nenhuma leitura de disco a mais: a imagem já está lá.

**Constraints globais:** A função NÃO pode devolver a média aritmética dos pixels — numa capa
colorida as cores se cancelam e o resultado tende ao cinza. Pesa por saturação e faz a média
do matiz **circularmente** (a média de 350° com 10° é 0°, não 180°).

## Arquivos

- Criar: `src/dominantcolor.h` · `src/dominantcolor.cpp` · `tests/tst_dominantcolor.cpp`
- Modificar: `src/roundedimage.h` · `src/roundedimage.cpp` · `CMakeLists.txt` ·
  `tests/CMakeLists.txt`
- Testar: `tests/tst_dominantcolor.cpp`

## Interfaces

- Consome: nada (fatia folha).
- Produz:
  - `QColor dominantColorOf(const QImage &image)` — declarada em `src/dominantcolor.h`.
    Devolve uma cor **opaca** (alpha 255) pronta para pintar sobre fundo escuro, ou
    `QColor(0, 0, 0, 0)` (**alpha 0**) quando a imagem é nula, cinza, quase preta ou quase
    branca. O alpha é o contrato: quem chama testa `alpha() == 0`, nunca `isValid()`.
  - `RoundedImage.dominantColor : color` — `Q_PROPERTY` só de leitura, com
    `NOTIFY dominantColorChanged()`. Vale `Qt::transparent` enquanto não há capa carregada.
    A fatia `painel-acompanha` a consome através de `RoundedCover`.

## Tasks

### Task 1: A função e o teste que a prova

- [x] Escrever o teste que falha, em `tests/tst_dominantcolor.cpp`:

```cpp
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
```

- [x] Registrar o alvo em `tests/CMakeLists.txt`, no fim do arquivo:

```cmake
qt_add_executable(tst_dominantcolor
    tst_dominantcolor.cpp
    ../src/dominantcolor.h ../src/dominantcolor.cpp
)
target_include_directories(tst_dominantcolor PRIVATE ../src)
target_link_libraries(tst_dominantcolor PRIVATE Qt6::Core Qt6::Gui Qt6::Test)

add_test(NAME tst_dominantcolor COMMAND tst_dominantcolor)
set_tests_properties(tst_dominantcolor PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
```

- [x] Rodar e confirmar que falha pelo motivo certo:
      `cmake -B build -G Ninja && cmake --build build` → erro de compilação
      `dominantcolor.h: No such file or directory`
- [x] Escrever `src/dominantcolor.h`:

```cpp
#pragma once

#include <QColor>
#include <QImage>

// De que cor uma capa "é", para o halo que o painel projeta atrás dela.
//
// Não é a média dos pixels: numa capa colorida as cores se cancelam e a média tende ao
// cinza — o halo nasceria morto. Esta função pesa cada pixel pela própria saturação (um
// pixel cinza quase não vota, um vermelho vota alto), descarta o que é quase preto ou quase
// branco (em capa isso é sombra e moldura, não cor) e faz a média do matiz CIRCULARMENTE,
// porque hue é um ângulo: a média de 350° com 10° é 0°, e a aritmética daria 180° — a cor
// exatamente oposta.
//
// Devolve cor opaca (alpha 255) já presa numa faixa de saturação e brilho que rende sobre o
// painel escuro, ou QColor(0, 0, 0, 0) — ALPHA ZERO, que é o contrato — quando não há cor
// alguma a extrair. Quem chama testa o alpha, não isValid().
QColor dominantColorOf(const QImage &image);
```

- [x] Escrever `src/dominantcolor.cpp`:

```cpp
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
```

- [x] verificação mecânica da task:
      `cmake --build build && ctest --test-dir build -R tst_dominantcolor --output-on-failure`
      → `100% tests passed, 0 tests failed out of 1`
- [x] commit:

```bash
git add src/dominantcolor.h src/dominantcolor.cpp tests/tst_dominantcolor.cpp tests/CMakeLists.txt
git commit -m "feat(cover): saturation-weighted dominant color with circular hue mean"
```

### Task 2: A capa expõe a própria cor

- [ ] Em `src/roundedimage.h`, acrescentar o include `#include <QColor>` no topo, a
      propriedade abaixo do `Q_PROPERTY(bool ready ...)`, o getter, o sinal e o campo:

```cpp
    Q_PROPERTY(QColor dominantColor READ dominantColor NOTIFY dominantColorChanged)
```

```cpp
    // A cor que esta capa "é", para o halo do painel. Transparente (alpha 0) enquanto não há
    // arte carregada, ou quando a arte não tem cor a dar.
    QColor dominantColor() const { return m_dominant; }
```

```cpp
    void dominantColorChanged();
```

```cpp
    QColor m_dominant = QColor(0, 0, 0, 0);
```

- [ ] Em `src/roundedimage.cpp`, acrescentar `#include "dominantcolor.h"` aos includes do
      topo e, no fim de `reload()`, calcular a cor junto com o resto do estado. O bloco final
      da função passa a ser:

```cpp
    const QColor antes = m_dominant;
    m_dominant = dominantColorOf(m_image);
    if (m_dominant != antes)
        emit dominantColorChanged();

    if (tinha != ready())
        emit readyChanged();
    update();
```

- [ ] Registrar `src/dominantcolor.h` e `src/dominantcolor.cpp` na lista `SOURCES` do
      `qt_add_qml_module(melodarium ...)` em `CMakeLists.txt`, logo depois das duas linhas de
      `src/roundedimage.*`:

```cmake
        src/dominantcolor.h
        src/dominantcolor.cpp
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] verificação mecânica da task:
      `grep -c 'dominantColor' src/roundedimage.h` → `3`
- [ ] commit:

```bash
git add src/roundedimage.h src/roundedimage.cpp CMakeLists.txt
git commit -m "feat(cover): expose the loaded artwork's dominant color to QML"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → exit 0
- `ctest --test-dir build -N | awk '/Total Tests:/ {print $3}'` → `11` (piso de contagem: eram 10, esta
  fatia acrescenta 1; `ctest` sai 0 com `Total Tests: 0` e um gate sem piso lê verde num
  build sem teste nenhum)
- `ctest --test-dir build -R tst_dominantcolor --output-on-failure` → `100% tests passed`
- `bash tools/check-fidelidade.sh` → exit 0 (nada mudou na tela: ninguém consome a cor ainda)
- `bash tools/check-layout.sh` → exit 0
- `bash tools/check-orfaos.sh` → exit 0 (`dominantColor` é `Q_PROPERTY`, não `Q_INVOKABLE`:
  o detector de órfãos não a vê, e é a fatia `painel-acompanha` que a consome de verdade)

## Fora de escopo

- **Paleta com mais de uma cor** (dominante + acento, como o Material You faz). O halo usa
  uma cor só; extrair uma paleta é outra fatia, e sem consumidor seria código morto.
- **Cache da cor por álbum.** O cálculo roda sobre uma amostra de 48x48 e só quando uma capa
  termina de carregar — medir antes de otimizar.
- **Consumir a cor na tela.** É a fatia `painel-acompanha`.
