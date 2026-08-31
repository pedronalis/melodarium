---
title: Crossfade assíncrono precisa de destino explícito
category: ui
module: src/NowPlayingPanel.qml
symptoms:
  - "a música muda mas a capa continua sendo a do álbum anterior"
  - "a capa nova aparece e volta para a antiga depois de um instante"
tags: [qml, async, timer, crossfade, capa, corrida]
---

O painel usa duas camadas de capa. A que está atrás recebe a nova fonte; quando fica pronta,
vai para a frente. Um timer de 350 ms é o fallback para capas ausentes.

O defeito estava no verbo do timer: ele fazia
`capaAnaFrente = !capaAnaFrente`. Durante uma carga fria, a fonte podia passar por
`antiga → vazia → nova`. O callback `ready` colocava a camada nova na frente e parava o timer,
mas o handler da fonte retomava o mesmo timer logo depois. Quando ele disparava, invertia o
estado já correto e devolvia a capa antiga.

## Correção

Cada transição escolhe `alvoAnaFrente` **antes** de atribuir a fonte e arma o timer antes da
atribuição, porque uma capa em cache pode ficar pronta de forma síncrona. `ready` e timeout
chamam a mesma função e escrevem o destino explícito. Nenhum caminho usa inversão cega.

Há duas provas complementares:

- `tools/check-cover-crossfade.sh` rejeita a inversão `!capaAnaFrente` e exige destino comum;
- `tools/check-cover-switch.sh` abre dois arquivos reais com capas sólidas vermelha e azul,
  troca de álbum dentro do app e inspeciona a captura final.

No run de 31/08/2026, a área da capa terminou com **107.522 pixels azuis e zero vermelhos**.

## Regra para mudanças futuras

Quando evento assíncrono e timeout podem finalizar a mesma transição, ambos precisam ser
idempotentes e convergir para um estado nomeado. “Alternar o estado atual” não é uma
finalização: é uma segunda transição cuja correção depende da ordem dos callbacks.
