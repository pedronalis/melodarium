#pragma once

#include <QColor>
#include <QImage>
#include <QVector>

// De que cor uma capa "é", para o halo que o painel projeta atrás dela.
//
// Não é a média dos pixels: numa capa colorida as cores se cancelam e a média tende ao
// cinza — o halo nasceria morto. Estas funções pesam cada pixel pela própria saturação (um
// pixel cinza quase não vota, um vermelho vota alto), descartam o que é quase preto ou quase
// branco (em capa isso é sombra e moldura, não cor) e fazem a média do matiz CIRCULARMENTE,
// porque hue é um ângulo: a média de 350° com 10° é 0°, e a aritmética daria 180° — a cor
// exatamente oposta.
//
// Devolvem cor opaca (alpha 255) já presa numa faixa de saturação e brilho que rende sobre o
// painel escuro, ou QColor(0, 0, 0, 0) — ALPHA ZERO, que é o contrato — quando não há cor
// alguma a extrair. Quem chama testa o alpha, não isValid().
QColor dominantColorOf(const QImage &image);

// Um foco de luz do halo: a cor de um pedaço da capa e ONDE esse pedaço fica.
//
// Uma cor média só não é a luz que uma capa dá. Uma capa com céu azul em cima e areia laranja
// embaixo tem duas luzes, em dois lugares — e a média das duas é um bege que não existe na
// arte. `x` e `y` vão de 0 a 1 dentro do quadrado da capa, para que quem pinta saiba onde pôr
// cada foco; `weight` vai de 0 a 1 e diz quanta cor aquele pedaço tinha, comparado ao pedaço
// mais colorido de todos.
struct ColorSpot
{
    QColor color;
    qreal x = 0.5;
    qreal y = 0.5;
    qreal weight = 1.0;
};

// Até `maxSpots` focos de luz, tirados de uma grade 3x3 sobre a capa e ordenados do mais
// colorido para o menos. Dois focos de matiz vizinho não entram os dois: repetir a mesma cor
// em dois lugares não enriquece a luz, só a deixa mais forte de um lado. Capa sem cor nenhuma
// devolve lista vazia.
QVector<ColorSpot> paletteOf(const QImage &image, int maxSpots = 4);
