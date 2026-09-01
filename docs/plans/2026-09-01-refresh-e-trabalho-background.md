---
slug: refresh-e-trabalho-background
feature: melodarium
status: pendente
depende-de: [confiabilidade-playback-banco, perf-render-fila]
decisao-humana: nao
spec: docs/plans/2026-09-01-refresh-e-trabalho-background.md
---

# Refresh e trabalho em background Implementation Plan

> **Para execução agentic:** executar inline com TDD depois de concluir `perf-render-fila`.

**Goal:** manter biblioteca e podcasts atualizados sem botão manual nem bloqueio perceptível da
thread da interface.

**Architecture:** um watcher recursivo com debounce observa diretórios, agenda a infraestrutura
de scan já existente e se rearma após mudanças. A leitura de tags de podcasts locais roda em
worker e publica resultados em uma transação curta na conexão writer.

**Tech Stack:** Qt 6 Core/Concurrent/Sql, QFileSystemWatcher, QThread, SQLite e Qt Test.

## Global Constraints

- Eventos em rajada produzem uma única varredura; mudanças durante scan produzem no máximo uma
  repetição posterior.
- Nenhuma leitura TagLib ou caminhada recursiva roda na GUI thread.
- Feeds RSS permanecem visíveis e independentes da raiz de podcasts local.
- O watcher nunca abre o banco do usuário em testes: XDG e raízes são temporários.

## File Map

- Create: `src/librarywatcher.h`, `src/librarywatcher.cpp` — watcher recursivo e debounce.
- Create: `tests/tst_librarywatcher.cpp` — criação, rename, remoção e rajadas.
- Modify: `src/database.h`, `src/database.cpp` — integrar watcher ao ciclo do scanner.
- Modify: `src/podcastlibrary.h`, `src/podcastlibrary.cpp` — scan local assíncrono e transação.
- Modify: `tests/tst_podcast.cpp`, `CMakeLists.txt`, `tests/CMakeLists.txt` — registro e regressões.
- Create: `docs/solutions/perf/2026-09-01-refresh-sem-travar-ui.md` — medições.

---

### Task 1: Concluir render e fila leves

- [x] Executar integralmente Tasks 1, 3 e 4 de `docs/plans/2026-08-30-perf-render-fila.md`, com
  RED/GREEN, medições e commits previstos naquele ledger.

### Task 2: Atualizar biblioteca automaticamente

- [ ] Escrever `tst_librarywatcher` exigindo debounce de rajada, inclusão de subdiretório novo,
  rearm após rename e nenhuma emissão depois de trocar/desativar a raiz.
- [ ] Rodar o novo alvo e confirmar RED por tipo ausente.
- [ ] Implementar `LibraryWatcher`, conectar `scanRequested` a `Database::startScan()` e manter
  `rescanPending` quando já houver scan; rearmar árvore somente após o scan terminar.
- [ ] Rodar o alvo e uma prova real com arquivos temporários; marcar e commitar com
  `feat(library): refresh watched folders automatically`.

### Task 3: Tirar scan de podcast da GUI thread

- [ ] Criar teste com centenas de fixtures e um heartbeat no thread principal; exigir heartbeat
  durante scan, uma única atualização de modelos e rollback em falha.
- [ ] Confirmar RED no comportamento síncrono atual.
- [ ] Mover caminhada/TagReader para worker, aplicar lote numa transação writer e voltar sinais
  ao thread do `PodcastLibrary` por conexão queued.
- [ ] Rodar `tst_podcast`, medir wall-clock/heartbeat e commitar com
  `perf(podcast): scan local episodes off the ui thread`.

### Task 4: Gate da fatia

- [ ] Rodar configure/build, piso de testes, suíte, gates de performance e medições antes/depois.
- [ ] Rodar `gitnexus detect-changes`, registrar a solução e concluir os dois ledgers.
