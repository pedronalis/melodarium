---
slug: confiabilidade-playback-banco
feature: melodarium
status: em-execucao
depende-de: []
decisao-humana: nao
spec: docs/plans/2026-09-01-confiabilidade-playback-banco.md
---

# Confiabilidade de playback e banco Implementation Plan

> **Para execução agentic:** executar inline com TDD e `systematic-debugging`; cada mudança de
> símbolo exige `gitnexus impact` upstream antes da edição.

**Goal:** impedir que preferências de podcast contaminem música e transformar falhas de banco
em estados recuperáveis, diagnosticáveis e testados.

**Architecture:** `AudioEngine` passa a separar preferências persistidas por contexto e aplica o
perfil correto em toda troca de arquivo. `Database` valida a conexão e a integridade, configura
espera entre writers, cria uma cópia consistente antes de migrar e preserva o erro de startup
em propriedades consultáveis; a migração do nome antigo sai para uma unidade testável sem mudar
seu momento de execução.

**Tech Stack:** C++20, Qt 6 Core/Sql/Qml, libmpv, SQLite, QSettings, Qt Test e CTest.

## Global Constraints

- Não remover nem atrasar `migrarDoNomeAntigo()`; dados antigos continuam migrando antes da
  primeira abertura do banco.
- Música sempre usa velocidade `1.0`; podcast usa a velocidade de fala persistida.
- Volume, ReplayGain, gapless e saída exclusiva persistem sem mudar os defaults atuais.
- Um banco íntegro nunca é substituído; backup é anterior à migração e tem nome determinístico.
- Todos os comandos de build/test rodam por `quiet-run`; `ctest -N` deve descobrir ao menos 22
  alvos antes da suíte.

## File Map

- Modify: `src/audioengine.h`, `src/audioengine.cpp` — perfis persistidos e aplicação por mídia.
- Modify: `tests/tst_audioengine.cpp` — regressão de velocidade e preferências.
- Create: `src/legacymigration.h`, `src/legacymigration.cpp` — migração antiga testável.
- Modify: `src/main.cpp`, `CMakeLists.txt` — usar e registrar a unidade de migração.
- Create: `tests/tst_legacymigration.cpp` — dados, cache e QSettings antigos.
- Modify: `src/database.h`, `src/database.cpp` — estado de abertura, integridade, timeout e backup.
- Modify: `tests/tst_library.cpp`, `tests/CMakeLists.txt` — migração, corrupção e concorrência.
- Create: `tools/check-data-paths.sh` — rejeitar caminho fantasma de um nível em código/scripts.
- Create: `docs/solutions/dados/2026-09-01-banco-abre-com-prova-e-backup.md` — contrato durável.

---

### Task 1: Isolar e persistir preferências de reprodução

**Interfaces:**
- Consumes: `AudioEngine::setSpeed`, `loadPlaylist`, `handleEvent`, `QSettings`.
- Produces: chaves `playback/volume`, `playback/podcastSpeed`, `audio/replayGainMode`,
  `audio/gaplessAggressive`, `audio/exclusiveOutput`; método `setContentKind(ContentKind)`.

- [x] Escrever testes que criam dois motores sobre o mesmo QSettings e exigem volume/perfil
  restaurados, limites validados, ReplayGain `no|track|album` e velocidade musical `1.0` depois
  de tocar podcast em `1.5`.
- [x] Rodar `quiet-run cmake --build build && quiet-run ./build/tests/tst_audioengine` e registrar
  RED especificamente na restauração e no vazamento da velocidade.
- [x] Implementar o perfil mínimo; toda mudança de arquivo aplica a velocidade do contexto antes
  de iniciar a reprodução e `setSpeed` só atualiza `podcastSpeed` em modo podcast.
- [x] Rodar o alvo até GREEN e o gate real com duas mídias por libmpv, observando `speed` no motor.
- [x] Marcar a task e commitar com `fix(audio): isolate and persist playback preferences`.

### Task 2: Tornar abertura, integridade e migração observáveis

**Interfaces:**
- Consumes: `Database::openConnection`, `applyPragmas`, `migrate`, `defaultDatabasePath`.
- Produces: propriedades `ready`, `startupError`, `lastBackupPath`; `busy_timeout=5000` em toda
  conexão; `PRAGMA quick_check`; backup `<db>.pre-v<versao>.bak` antes de alterar schema.

- [ ] Acrescentar casos vermelhos para arquivo corrompido, erro de abertura, `busy_timeout`,
  lock temporário entre UI/scanner e backup restaurável de um schema antigo.
- [ ] Rodar `quiet-run cmake --build build && quiet-run ./build/tests/tst_library` e confirmar que
  cada caso falha pela ausência do contrato, não pelo fixture.
- [ ] Fazer cada pragma/transaction/commit retornar erro; propagar mensagem com caminho e erro
  SQLite, executar `quick_check` antes de migrar e criar backup consistente só quando a versão
  subir.
- [ ] Reexecutar o alvo, abrir o backup em nova conexão e exigir tabelas/dados anteriores.
- [ ] Marcar a task e commitar com `fix(database): validate startup and protect migrations`.

### Task 3: Provar a migração do nome antigo e eliminar o caminho fantasma do repo

**Interfaces:**
- Consumes: a implementação atual de `migrarDoNomeAntigo()`.
- Produces: `migrateLegacyApplicationData(oldName, newName)` e gate que só aceita
  `AppDataLocation/<app>.db`.

- [ ] Extrair um teste vermelho com XDG temporário contendo banco/WAL/cache e preferências
  `melodia`; exigir movimento, rename do banco, cópia chave a chave e idempotência.
- [ ] Rodar `quiet-run cmake --build build && quiet-run ./build/tests/tst_legacymigration` e
  confirmar RED antes de extrair a função.
- [ ] Extrair sem alterar a chamada anterior a qualquer acesso de dados em `main()`; criar
  `tools/check-data-paths.sh` que falha se scripts/docs executáveis abrirem o caminho de um nível.
- [ ] Rodar alvo, gate e `quiet-run ctest --test-dir build -R 'tst_library|tst_legacymigration'
  --output-on-failure`.
- [ ] Registrar a conclusão de causa: nenhum caminho de runtime cria o fantasma; aberturas
  manuais pelo caminho incorreto o criam. Marcar e commitar com
  `test(data): lock down legacy and database paths`.

### Task 4: Gate da fatia

- [ ] Rodar configure/build, piso de testes, suíte completa e `tools/check-data-paths.sh`.
- [ ] Rodar `gitnexus detect-changes --scope compare --base-ref main`; revisar símbolos/fluxos.
- [ ] Atualizar a solução, marcar esta task, definir o plano como `concluido` e commitar o ledger.
