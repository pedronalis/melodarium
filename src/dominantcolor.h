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
