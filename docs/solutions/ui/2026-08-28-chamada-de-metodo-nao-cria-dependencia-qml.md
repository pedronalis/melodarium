---
title: Chamada de método numa ligação QML não cria dependência — e ler sem usar também não
category: ui
module: QueueStrip.qml
symptoms:
  - "componente novo nasce vazio e nunca mais muda"
  - "ligação avaliada uma vez, na construção, e congelada"
  - "build verde, nenhum aviso, nenhum erro de tipo"
tags: [qml, binding, property-capture, qt-6.10, invokable]
---

## O sintoma

`QueueStrip.qml` lia a fila assim:

```qml
readonly property var proximos: AudioEngine.upcoming(root.lookahead)
```

A tirinha nunca aparecia. Build exit 0, zero erros de QML no gate, o motor com 27 faixas na
fila — e a tela vazia. Instrumentado, o sinal de mudança disparava **uma vez**, na construção
do componente, com `queueCount=0`.

## A causa

O QML captura dependência em **leitura de propriedade**, ligando a ligação ao sinal `NOTIFY`
dela. `upcoming()` é um `Q_INVOKABLE`: chamá-lo não registra nada. A ligação valia para
sempre o que valia ao nascer — e ao nascer a fila está vazia, porque o app ainda não tocou
nada.

## A segunda armadilha, dentro da primeira

A correção óbvia — tocar nas propriedades para criar a dependência — **também não funciona se
o valor lido for descartado**:

```qml
readonly property var proximos: {
    void AudioEngine.queueCount     // eliminado como código morto
    void AudioEngine.playlistPos    // idem
    return AudioEngine.upcoming(root.lookahead)
}
```

Medido: continuou disparando uma vez só. Expressão sem efeito é eliminada pelo compilador, e
a captura da dependência vai junto.

## O que funciona

O valor lido tem de ser **usado**:

```qml
readonly property var proximos: {
    const total = AudioEngine.queueCount
    const pos = AudioEngine.playlistPos
    if (total <= 0 || pos + 1 >= total)
        return []
    return AudioEngine.upcoming(root.lookahead)
}
```

Com a guarda comparando os dois, eles não podem ser eliminados. O log passou a mostrar a
sequência inteira: `queueCount=0` na abertura, depois `queueCount=27 pos=0 visible=true`.

Regra prática: numa ligação que chama um invocável, leia as propriedades que **decidem a
resposta** e faça o resultado depender delas de verdade.

## O que NÃO funcionou

- Confiar no `cmake --build`: não há erro nenhum a emitir.
- O gate de erros de QML: nenhuma das mensagens que ele procura é gerada — a ligação está
  correta, só é estática.
- `void <propriedade>` para criar dependência: eliminado antes de rodar.
- Rodar o app e olhar: um componente `visible: false` por dado vazio é indistinguível de um
  componente que não existe. Só a foto com a fila carregada DEPOIS da construção da tela
  denunciou.
