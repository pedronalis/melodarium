---
title: Renomear o app no Qt move a casa inteira do usuário
category: dados
module: src/main.cpp (migrarDoNomeAntigo), src/database.cpp
symptoms:
  - "app abre com a biblioteca vazia depois de renomear o projeto"
  - "a pasta de música escolhida foi esquecida"
  - "as capas somem e o scanner reprocessa tudo"
  - "QSettings antigo aparece com allKeys() vazio, mesmo com o arquivo no disco"
tags: [qt, qsettings, qstandardpaths, migracao, rename]
---

O projeto foi rebatizado de `melodia` para `melodarium`. No Qt, **todo caminho de dados sai do
`applicationName`/`organizationName`** — então a troca do nome move, de uma vez:

| O quê               | De                                          | Para                                                 |
| ------------------- | ------------------------------------------- | ---------------------------------------------------- |
| banco da biblioteca | `~/.local/share/melodia/melodia/melodia.db` | `~/.local/share/melodarium/melodarium/melodarium.db` |
| capas em cache      | `~/.cache/melodia/melodia/covers`           | `~/.cache/melodarium/melodarium/covers`              |
| preferências        | `~/.config/melodia/melodia.conf`            | `~/.config/melodarium/melodarium.conf`               |

Nada disso falha: o app sobe limpo, sem erro, **mostrando a tela de primeira abertura para
quem já tinha a biblioteca inteira varrida**. É o pior formato de defeito — silencioso e
indistinguível de um app novo.

`migrarDoNomeAntigo()` em `main.cpp` roda antes de qualquer leitura de disco e traz tudo junto
na primeira abertura com o nome novo.

## A armadilha que custou meia hora

Dados e cache migram movendo o diretório. **Preferências, não** — e por dois motivos que só
aparecem tentando:

**1. `QSettings::IniFormat` não é o formato nativo.** Pedir Ini explicitamente faz o Qt
procurar `melodia.ini`; o arquivo que existe no disco é `melodia.conf`, porque o formato
**nativo** no Unix é esse. O construtor não reclama: devolve um `QSettings` válido apontando
para um arquivo que não existe, e `allKeys()` volta **vazio**. A correção é uma palavra:

```cpp
QSettings velhas(QSettings::NativeFormat, QSettings::UserScope, antigo, antigo);
```

**2. "Mover se o destino não existe" nunca dispara para config.** O `QSettings` novo cria o
arquivo na primeira gravação — e alguma tela grava logo na abertura. Quando a migração roda, o
destino já existe. A saída é copiar **chave a chave**, pulando o que já tem valor: idempotente,
e não atropela escolha que o usuário já fez com o nome novo.

## O que NÃO funcionou

- **`strings build/melodarium | grep melodia` para conferir se o binário era o novo** — devolve
  zero mesmo com a string lá. `QStringLiteral` guarda UTF-16, e `strings` lê ASCII por padrão.
  O teste honesto é `strings -el`, ou o timestamp do `.o`.
- **`qWarning()` para depurar** — não apareceu no terminal. Neste Fedora o log do Qt vai para o
  journald, e só `QT_FORCE_STDERR_LOGGING=1` traz de volta (é por isso que `check-layout.sh` já
  exportava a variável). Meia hora se foi achando que a função não era chamada, quando ela era
  chamada e falava sozinha.
- **Fixar o nome do arquivo do banco à mão** (`"/melodia.db"`) — foi o que deixou o nome do
  arquivo e o nome do projeto poderem divergir em silêncio. Agora ele deriva de
  `QCoreApplication::applicationName()`, com fallback para os testes, que sobem sem app nomeada.

## Se acontecer de novo

Rebatizar o app é barato no código e caro no disco do usuário. Antes de trocar o nome:
faça o inventário dos três caminhos da tabela acima, escreva a migração **antes** do rename, e
verifique com dados reais — aqui, 27 faixas e 17 capas, conferidas depois da migração.
