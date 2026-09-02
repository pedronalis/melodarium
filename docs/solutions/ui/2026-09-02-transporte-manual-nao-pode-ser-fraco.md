---
title: Transporte manual não pode usar o modo fraco do mpv
category: ui
module: src/audioengine.cpp, GlobalMiniPlayer.qml, NowPlayingPanel.qml
symptoms:
  - "anterior não faz nada na primeira faixa"
  - "próxima não faz nada na última faixa"
  - "os botões parecem falhar só às vezes"
tags: [qt, qml, libmpv, playlist, transport]
---

## O sintoma intermitente era uma borda determinística

Os botões chamavam `playlist-next weak` e `playlist-prev weak`. No mpv, `weak` não significa
“tente de forma segura”: significa explicitamente não fazer nada quando já se está no último ou
no primeiro item. Por isso o mesmo botão funcionava no meio da fila e ficava inerte nas bordas.
Uma fila unitária estava nas duas bordas ao mesmo tempo.

## O contrato correto para um gesto manual

Anterior e próxima agora leem `playlist-pos` diretamente do mpv e calculam o índice circular:

- próxima no último item seleciona o primeiro;
- anterior no primeiro seleciona o último;
- numa fila unitária, ambos reiniciam a faixa;
- sem item ativo, próxima começa pelo primeiro e anterior pelo último.

O salto usa `playlist-play-index`, que troca a entrada sem reconstruir a playlist. A leitura
síncrona do mpv é importante: `m_playlistPos` é um espelho atualizado por evento e pode ainda
estar atrasado quando dois gestos chegam próximos.

Isso não liga repetição. Com `RepeatOff`, o fim natural da fila continua encerrando a reprodução;
somente o gesto explícito do usuário é circular.

## Prova que cobre o defeito real

`tst_audioengine` usa libmpv com saída de áudio nula e cobre wrap nos dois extremos, ida/volta e
fila unitária. `tools/check-transport-controls.sh` acrescenta a fronteira que o teste de motor não
vê: monta duas faixas de 20 segundos sob XDG temporário, abre o mini-player em Xvfb e clica nos
dois `IconButton` reais. A linha `MEDIDA` precisa terminar em `0→1` para anterior e `1→0` para
próxima.

Ao testar transições do mpv, espere tanto `playlistPos` quanto `currentFile`. Os sinais são
assíncronos e podem chegar em ciclos diferentes; comparar o arquivo imediatamente depois de o
índice mudar cria um falso negativo sem provar falha de reprodução.
