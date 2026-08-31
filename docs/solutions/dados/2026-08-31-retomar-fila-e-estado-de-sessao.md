---
title: Retomar música é restaurar sessão, não consultar estatística
category: dados
module: src/audioengine.cpp, src/Main.qml, src/EmptyPane.qml
symptoms:
  - "continuar de onde parou abre somente uma faixa"
  - "a música retomada já começa perto do fim"
  - "a fila desaparece depois de fechar o app"
tags: [qt, qsettings, mpv, fila, persistencia, resume]
---

O convite “Continuar de onde parou” reconstruía a reprodução a partir de
`LibraryBrowser.lastPlayed()`. Essa consulta não descreve uma sessão: ela devolve a última
faixa cujo `last_played_at` foi atualizado, e esse campo só mudava no EOF. Em paralelo, um
timer salvava `last_position_ms` a cada 5 segundos. O resultado normal era exatamente o bug:
uma fila de uma faixa já concluída, com seek para perto do final.

## A separação que faltava

Há três estados diferentes:

- estatística: quantas vezes uma faixa tocou e quando terminou;
- sessão de música: fila ordenada + índice corrente;
- sessão de podcast: episódio + timestamp corrente.

Misturar os três fez uma estatística de reprodução se passar por fila. O contrato agora é:

- `AudioEngine` persiste `playback/queue` e `playback/currentIndex` em `QSettings` somente
  quando a fila ou o índice muda;
- `restoreSavedQueue()` filtra arquivos que desapareceram, carrega a fila no índice salvo e
  não executa seek;
- música sempre volta em `0:00` na faixa corrente;
- podcast continua carregado com `rememberSession=false` e retoma pelo timestamp do
  `PodcastLibrary`, sem substituir a última fila musical;
- a gravação periódica de posição de música saiu do runtime. Não há escrita por frame nem a
  cada cinco segundos para um dado que a interface não usa mais.

O `lastPlayed()` permanece como fallback de migração para quem atualiza sem ter ainda uma
sessão salva, mas esse fallback também começa em `0:00` e grava a fila a partir da próxima
carga normal.

## Prova que distingue o conserto do código antigo

`tools/check-resume-queue.sh` usa dois processos reais do app com diretórios XDG temporários.
O primeiro deixa duas faixas no índice 1. O banco diz deliberadamente que a segunda parou em
7 segundos. O segundo dispara o mesmo `startFromEmpty("resume")` do clique e exige:

```text
fila=2 queuepos=1 segundos<2 arquivo=<segunda faixa>
```

No run de 31/08/2026, a retomada ocorreu em **0,500 s**. A implementação antiga produziria
`fila=1` e buscaria aproximadamente 7 segundos, portanto o gate não consegue passar pelo
caminho errado.

## Regra para mudanças futuras

Estado necessário para reconstruir a intenção do usuário pertence a uma sessão explícita.
Estatística serve para ordenar, recomendar e contar; não deve ser usada como snapshot da fila.
