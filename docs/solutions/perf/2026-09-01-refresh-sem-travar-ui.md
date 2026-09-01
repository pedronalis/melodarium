# Refresh automático sem travar a interface — 2026-09-01

## Sintoma

A biblioteca só percebia arquivos novos quando alguém acionava “reler a pasta”. O scan local
de podcasts fazia caminhada, leitura TagLib e inserts na conexão da interface, tudo dentro da
chamada QML. Centenas de episódios bloqueavam o event loop e uma falha no meio deixava show
parcial no banco.

## Solução

### Biblioteca

`LibraryWatcher` observa recursivamente diretórios e arquivos da raiz configurada. Eventos são
debounçados por 250 ms e viram `Database::startScan()`. O `Database` continua dono do scanner e
mantém um único `m_rescanPending`: qualquer quantidade de mudanças enquanto um scan está ativo
produz no máximo um scan posterior.

O watcher também publica `changeDetected` imediatamente. Isso permite armar a repetição antes
do debounce. Quando a thread termina, `scanFinished()` consome o timer já coberto, rearma a
árvore após renames/subdiretórios novos e só então o `Database` inicia a repetição. Sem essa
separação, um timer sobrevivente podia iniciar um terceiro scan.

Trocar ou desativar a raiz para o timer, remove todos os watches e rejeita eventos enfileirados
da raiz antiga. Os testes usam somente raízes e XDG temporários.

### Podcasts locais

`scanPodcastFolder()` agora retorna com `scanning=true` e despacha `runLocalPodcastScan()` via
`QtConcurrent`. A função worker:

1. abre `melodarium-podcast-writer`, uma conexão SQLite exclusiva da thread;
2. lê os caminhos já catalogados;
3. caminha pelas pastas e executa TagLib fora de qualquer transação;
4. aplica shows e episódios numa única transação curta;
5. fecha e remove a conexão na própria thread;
6. devolve sucesso/erro ao `QFutureWatcher` no thread do `PodcastLibrary`.

O commit inteiro emite somente `showsChanged()` uma vez. `PodcastPane` e os painéis de contexto
recarregam shows e episódios a partir desse sinal, então emitir também `episodesChanged()` seria
duas atualizações do mesmo modelo. Em erro, a transação é revertida integralmente e nenhum sinal
de modelo é emitido. Feeds RSS não são apagados nem escopados pela raiz local.

## Provas RED → GREEN

| Prova | RED | GREEN |
|---|---|---|
| Tipo do watcher | build falhou: `librarywatcher.h` ausente | alvo compila |
| Rajada durante scan | 1 conclusão, esperadas 2 | exatamente 2, sem terceira |
| Debounce residual | `changeDetected` ausente | timer coberto é consumido |
| Podcast não bloqueante | `scanning()` já era falso ao retornar | retorna ativo; event loop pulsa |
| Rollback | 6 shows após falha, esperados 5 | contagens pré/pós idênticas |

Medições no gate:

```text
tst_librarywatcher: 8 passed, 0 failed, 0 skipped, 2059 ms
integração watcher + 100 fixtures: 823 ms no alvo isolado
PODCAST_PERF fixtures=301 wall_ms=50 heartbeat=4
tst_podcast: 15 passed, 0 failed, 0 skipped, 132 ms
heartbeat repetido 5 vezes: 71, 73, 72, 71, 73 ms de processo
```

O RED síncrono de 301 fixtures encerrou em 54 ms com `scanning=false` no retorno; o tempo não era
o problema isolado, e sim que durante toda essa janela o event loop não podia executar. O GREEN
tem tempo de parede parecido, mas quatro heartbeats observados e retorno imediato.

## Gates finais

```text
cmake -B build -G Ninja                         exit 0
cmake --build build                             exit 0
ctest -N                                       27 testes (piso >= 27)
ctest --test-dir build --output-on-failure      27/27, 0 falhas, 89,06 s
bash tools/check-halo-activity.sh               exit 0
bash tools/check-list-reuse.sh                  exit 0
```

## Limites e decisões

- O watcher acompanha todos os arquivos, não apenas extensões de áudio, para detectar troca de
  tags e renames sem duplicar a lista de sufixos do scanner. Em bibliotecas enormes, o limite de
  watches do kernel ainda é um limite externo; falha de `addPaths()` não derruba o app.
- O scan de podcast preserva a semântica anterior: uma pasta diretamente abaixo da raiz é um
  show e arquivos soltos viram “Avulsos”. Ele continua insert-only; remoção/reconciliação de
  episódios locais não foi inventada nesta fatia.
- O writer usa WAL e `busy_timeout` herdados de `Database::openConnection`; TagLib e caminhada
  nunca seguram a transação.
- A falha local hoje vai para o log e mantém o banco íntegro. A superfície visual de erros é uma
  fatia posterior, não motivo para voltar a escrever parcialmente.
