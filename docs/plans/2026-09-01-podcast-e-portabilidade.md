---
slug: podcast-e-portabilidade
feature: melodarium
status: pendente
depende-de: [confiabilidade-playback-banco, refresh-e-trabalho-background]
decisao-humana: sim
spec: docs/plans/2026-09-01-podcast-e-portabilidade.md
---

# Podcast e portabilidade Implementation Plan

> **Para execução agentic:** executar inline com TDD; operações destrutivas exigem confirmação e
> fixtures XDG descartáveis.

**Goal:** completar o ciclo de vida de podcasts e permitir exportar/mover coleções e estado do app.

**Architecture:** migração de schema adiciona políticas por feed; ingestão agenda downloads e
retenção depois de commit. Um serviço de portabilidade implementa OPML, M3U e um bundle próprio
versionado, escrito com `QSaveFile` e validado integralmente antes do restore.

**Tech Stack:** Qt 6 Core/Sql/Xml/Network/Qml, SQLite, JSON, QSaveFile e Qt Test.

## Global Constraints

- Unsubscribe remove assinatura/episódios remotos somente após confirmação; arquivos baixados
  oferecem escolha explícita de manter ou apagar.
- Auto-download nasce desligado; retenção `0` significa ilimitada.
- Restore nunca altera dados atuais antes de validar header, versão, hashes, SQLite `quick_check`
  e espaço disponível; cria backup de retorno antes da troca.
- M3U usa caminhos absolutos UTF-8 e ordem manual da coleção.

## File Map

- Modify: `src/database.cpp`, `tests/tst_podcast.cpp` — schema de políticas.
- Modify: `src/podcastlibrary.h`, `src/podcastlibrary.cpp`, `src/PodcastPane.qml`,
  `src/PodcastContextPanel.qml` — unsubscribe, auto-download e retenção.
- Create: `src/portabilityservice.h`, `src/portabilityservice.cpp` — OPML/M3U/bundle.
- Create: `tests/tst_portability.cpp`, `src/BackupRestoreDialog.qml`,
  `tools/check-portability.sh` — contratos e UI.
- Modify: `src/collectionmanager.h`, `src/collectionmanager.cpp`, `src/CollectionsPane.qml`,
  `src/SettingsDialog.qml`, `CMakeLists.txt`, `tests/CMakeLists.txt` — pontos de entrada.

---

### Task 1: Unsubscribe e políticas por feed

- [ ] Criar migração/testes RED para `auto_download` e `retention_count`, defaults e upgrade.
- [ ] Testar unsubscribe com manter/apagar arquivos, ingestão idempotente que agenda só episódios
  novos e retenção que nunca apaga episódio tocando/em download.
- [ ] Implementar transação, fila pós-commit e limpeza segura; commitar com
  `feat(podcast): manage subscriptions and retention`.

### Task 2: OPML import/export

- [ ] Escrever testes RED para namespaces, duplicatas, URL inválida, XML malformado e round-trip.
- [ ] Implementar parser streaming e export determinístico; assinatura usa `subscribe()` e retorna
  resumo importados/duplicados/falhos.
- [ ] Expor ações e mensagens na tela; commitar com `feat(podcast): import and export subscriptions`.

### Task 3: Exportar coleções M3U

- [ ] Escrever teste RED com ordem manual, Unicode, duplicata e faixa ausente.
- [ ] Implementar export por `QSaveFile`, cabeçalho `#EXTM3U` e caminhos válidos na ordem do banco.
- [ ] Ligar ação em Coleções e commitar com `feat(collections): export playlists as m3u`.

### Task 4: Backup e restore completo

- [ ] Escrever testes RED de round-trip de DB/QSettings, hash inválido, bundle truncado, versão
  futura e rollback quando a troca falha.
- [ ] Implementar bundle versionado com manifest, banco consistente e preferências; restore cria
  backup de retorno, fecha conexões, troca por rename atômico e solicita reinício.
- [ ] Expor em Preferências com seleção nativa e confirmação; commitar com
  `feat(data): add verified backup and restore bundles`.

### Task 5: Gate humano

- [ ] Pedro exporta/importa OPML, exporta M3U e testa backup/restore sobre XDG descartável.
- [ ] Rodar suíte, gate de portabilidade e gates QML; revisar `gitnexus detect-changes`, concluir.
