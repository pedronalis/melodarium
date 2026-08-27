---
title: Redeclarar uma propriedade FINAL derruba o tipo QML inteiro, em silêncio
category: ui
module: SearchOverlay.qml
symptoms:
  - "Type X unavailable no Main.qml, sem erro no build"
  - "componente novo simplesmente não aparece na tela"
  - "o grep de erros do gate passa, porque a mensagem não é 'is not a type'"
tags: [qml, qtquick-controls, popup, qt-6.10, final-property, gate]
---

## O sintoma

`SearchOverlay.qml` compilava, o `cmake --build` saía 0, o app subia sem uma linha de aviso —
e a linha do gate

```bash
QT_QPA_PLATFORM=offscreen ./build/appmelodia 2>&1 | grep -Ec 'is not a type|Unable to assign|ReferenceError'
```

devolvia `0`. O overlay, porém, nunca abria: o tipo inteiro não existia em tempo de execução.

## A causa

```qml
Popup {
    property bool opened: visible   // <- aqui
```

No Qt 6.10 o `Popup` já tem `opened` como propriedade **FINAL**. Redeclará-la faz o arquivo
inteiro falhar a compilação de QML, com a mensagem aparecendo só em duas linhas que ninguém
lê por padrão:

```
qt.qml.diskcache: "…/SearchOverlay.qml:14:5: Cannot override FINAL property"
…/Main.qml:347:5: Type SearchOverlay unavailable
```

`Cannot override` e `unavailable` não estão no filtro de erros que o gate usava — e o
conteúdo de um `Popup` só é construído na **primeira abertura**, então nem rodar o app pegava.

## O que funciona

1. Não redeclarar nomes que o tipo base já tem. Se precisar de "está aberto", use `visible`.
2. Alargar o filtro de erro do gate (`tools/check-layout.sh`):

```bash
grep -Ec 'is not a type|Unable to assign|ReferenceError|TypeError|unavailable|Cannot override|Cannot assign'
```

3. **Abrir os popups no modo de verificação.** O `--measure` do app abre o `SearchOverlay`
   antes de medir justamente por isso: componente que só nasce ao abrir precisa ser aberto
   por alguém, senão nenhuma verificação o alcança.

## O que NÃO funcionou

- Confiar no `cmake --build`: erro de QML não é erro de compilação de C++.
- Confiar em rodar o app: sem abrir o popup, o tipo nem é instanciado.
- O filtro antigo de três padrões: a mensagem real do Qt não estava em nenhum deles.
- `QT_LOGGING_RULES` desligado: sem `*.debug=true` a linha do disk cache nem aparece.
