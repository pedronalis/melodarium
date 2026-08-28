---
title: Três jeitos de um teste verde não testar nada
category: test-failures
module: tests/tst_audioengine.cpp
symptoms:
  - "100% tests passed logo depois de um erro de compilação no teste"
  - "teste passa mesmo com a função sob teste desligada"
  - "teste passa e some do -functions"
tags: [ctest, qtest, qtry, mutacao, mpv]
---

Os três apareceram no MESMO arquivo, num run só. Todos davam verde.

## 1. O `ctest` roda o binário que existe, não o código do disco

Escrever o teste vermelho, ver a compilação falhar, implementar, e rodar
`ctest -R tst_audioengine` devolveu `100% tests passed` — do executável **anterior**. O teste
novo nem existia nele:

```
$ ./build/tests/tst_audioengine repeatCyclesThroughThreePositions -v1
Unknown test function: 'repeatCyclesThroughThreePositions'.
```

**Cuidado:** `cmake --build build` antes de todo `ctest`, e conferir o teste novo por nome
com `-functions`. Um `QSKIP` (ffmpeg ausente, mpv ausente) também sai verde — rodar com `-v1`
mostra `N passed, 0 skipped`.

## 2. `QTRY_*` numa janela maior que a fila passa por acidente

O teste queria provar que embaralhar reordena a playlist do mpv. Ele dava `next()` e esperava:

```cpp
QTRY_COMPARE_WITH_TIMEOUT(engine.currentFile(), esperado, 10000);
```

Com fixtures de 1 s e a fila andando sozinha, em 10 s o mpv toca **todos** os arquivos — então
esperar por qualquer um deles sempre acaba dando certo. Provado desligando a função sob teste
com um `return`: o teste passou assim mesmo.

**Cuidado:** `pause()` antes, esperar o índice (`QTRY_COMPARE(playlistPos(), 1)`) e comparar o
arquivo num instante só. Uma fila pausada não anda até o resultado esperado por acaso.

## 3. Fixture minúsculo não reproduz corrida que só existe com arquivo real

Ligar o aleatório com nada tocando deixava o mpv preso na entrada que já tinha começado a
carregar: no app, `pos=24` de 27 — "tocar tudo em ordem aleatória" tocava três faixas. O teste
com 5 tons de 1 s passava; **escalado para 26 entradas, ainda passava**. Tom de 1 s abre rápido
demais para a corrida acontecer.

**Cuidado:** quando o defeito depende de tempo de abertura de arquivo, a evidência boa é a
medição no app com o acervo real, não a suíte. Foi um `+21` que não fechava a conta numa
captura de tela que denunciou.

## A ferramenta que resolve os três

**Mutação:** desligar a função sob teste (um `return` no topo), recompilar, e exigir que o
teste FALHE. Se ele passar, ele não testa o que diz testar. Custa dois minutos e foi o que
pegou o nº 2 — e o que confirmou que os testes finais tinham dentes.

## O que NÃO funcionou

- Ler `100% tests passed` e seguir.
- Contar testes: os três estavam presentes e verdes.
- Aumentar o `qWait` para estabilizar: esconde a corrida em vez de esperar o evento certo.
- Escalar o fixture (5 → 26 entradas) para reproduzir o nº 3.
