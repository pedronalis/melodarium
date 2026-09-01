---
title: Banco SQLite só está pronto depois de pragmas, quick_check e migração protegida
category: dados
module: src/database.cpp, src/legacymigration.cpp
symptoms:
  - "aplicativo abre com biblioteca vazia quando o banco não pôde ser lido"
  - "writer da interface perde uma gravação enquanto o scanner escreve"
  - "upgrade de schema falha sem uma cópia anterior restaurável"
tags: [sqlite, wal, busy-timeout, integridade, migracao, backup]
---

# O contrato de abertura

`QSqlDatabase::open()` não prova que um arquivo é SQLite: um arquivo de texto arbitrário pode
ser aberto pelo driver e só falhar na primeira instrução. O estado `Database.ready` agora só
fica verdadeiro depois de quatro provas: conexão aberta, pragmas aplicados, `PRAGMA quick_check`
igual a `ok` e todas as migrações commitadas.

Toda conexão aplica `foreign_keys=ON`, WAL, `synchronous=NORMAL` e `busy_timeout=5000`. WAL
separa reader de writer, mas não elimina dois writers simultâneos; o timeout dá ao scanner e à
interface uma janela curta para serializar em vez de perder a gravação imediatamente.

Antes de subir um banco existente da versão N, `VACUUM INTO` cria
`<banco>.pre-vN.bak`. A cópia é consistente mesmo com WAL, e o cursor de `PRAGMA user_version`
e o de `wal_checkpoint` precisam ser finalizados antes do `VACUUM`: um statement de uma linha
ainda ativo produz `cannot VACUUM - SQL statements in progress`.

# O banco fantasma de zero byte

Em 01/09/2026, uma busca em todo conteúdo executável encontrou um único produtor de caminho:
`Database::defaultDatabasePath()`, derivado de `AppDataLocation`. Todos os gates que abrem o
banco usam os três níveis corretos. O arquivo de um nível
`~/.local/share/melodarium/melodarium.db` estava com 0 byte, mtime de 29/08 e nenhum processo o
mantinha aberto. Portanto não há evidência de que o runtime atual o recrie; a causa compatível
com os fatos é uma abertura externa/manual do caminho incorreto, que o SQLite cria vazio.

`tools/check-data-paths.sh` transforma essa conclusão em regressão: nenhum arquivo executável
pode codificar o caminho de um nível nem o nome do banco no C++.

# Migração do nome antigo

O wrapper `migrarDoNomeAntigo()` continua no mesmo lugar, antes do primeiro acesso a dados. A
lógica extraída agora também mescla uma origem `melodia` quando a pasta `melodarium` já existe
mas está vazia, sem sobrescrever arquivos novos. O gate executa o processo real com XDG
descartável e exige banco, cache e preferências preservados.
