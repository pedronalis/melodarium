---
slug: retomar-fila-capa
feature: melodarium
status: concluido
depende-de: [fila-motor]
decisao-humana: nao
---

# Retomar a fila e estabilizar a troca de capa

**Goal:** Fazer “Continuar de onde parou” restaurar a fila e a faixa correntes, sempre a
partir de `0:00`, e impedir que uma capa carregada de forma assíncrona volte para a arte da
faixa anterior.

**Arquitetura:** A fila ordenada e seu índice corrente são estado leve de sessão e ficam em
`QSettings`, atualizados somente quando a fila ou o índice muda. O `AudioEngine` continua
sendo a fonte única da fila viva e passa a expor a última sessão sem carregá-la até o clique.
O cartão usa a faixa corrente dessa sessão, não a última faixa contabilizada como concluída.
Na capa, a transição passa a guardar explicitamente qual camada é o destino; nenhum callback
inverte o estado às cegas.

**Qualidade:** Nenhuma opção do caminho de áudio, imagem, escala, cor, geometria ou animação é
reduzida. A persistência não escreve por frame nem por posição de reprodução.

## Arquivos

- Modificar: `src/audioengine.h`, `src/audioengine.cpp`, `src/Main.qml`,
  `src/EmptyPane.qml`, `src/NowPlayingPanel.qml`, `src/librarybrowser.cpp`.
- Modificar: `tests/tst_audioengine.cpp`, `tests/tst_librarybrowser.cpp`,
  `tests/CMakeLists.txt`.
- Criar: `tools/check-cover-crossfade.sh`, solução durável em `docs/solutions/`.

## Tasks

### Task 1: Contrato vermelho da sessão

- [x] Isolar o `QSettings` do teste do motor.
- [x] Provar que fila e índice sobrevivem a uma nova instância.
- [x] Provar que restaurar abre a faixa corrente no início, mesmo depois de ela ter tocado
      perto do fim na instância anterior.
- [x] Provar que caminho removido é descartado sem perder as entradas válidas.

### Task 2: Persistência e convite corretos

- [x] Expor sessão salva e `restoreSavedQueue()` no `AudioEngine`.
- [x] Persistir em carga, append, shuffle e mudança real de índice.
- [x] Fazer o cartão ler a faixa/contagem da sessão e o clique restaurar sem seek.
- [x] Manter o resume por timestamp exclusivo dos podcasts.

### Task 3: Crossfade determinístico

- [x] Criar e ver falhar um gate que rejeite inversão cega da camada.
- [x] Guardar a camada-alvo no timer e finalizar nela tanto por timeout quanto por `ready`.
- [x] Reproduzir a troca entre álbuns distintos no app e confirmar a capa final.

### Task 4: Gates e registro

- [x] Rodar build, piso de testes, suíte completa, órfãos e fidelidade.
- [x] Registrar a causa e a solução em `docs/solutions/`.
- [x] Rodar `gitnexus detect-changes`, commitar, enviar `main` e reabrir o app.

## Fora de escopo

- Retomar música no timestamp anterior: o contrato pedido é sempre começar a faixa em `0:00`.
- Alterar o resume de episódios de podcast, que continua retomando a posição salva.
- Mudar visual, intensidade, duração ou resolução da capa e do halo.
