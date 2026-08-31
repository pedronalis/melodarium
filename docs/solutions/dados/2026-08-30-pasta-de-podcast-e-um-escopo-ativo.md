---
title: A pasta de podcast é um escopo ativo, não só uma origem de importação
category: dados
module: src/podcastscope.h, src/podcastlibrary.cpp, src/librarybrowser.cpp
symptoms:
  - "trocar a pasta de podcasts mantém programas e episódios da pasta anterior"
  - "a busca encontra episódios fora da pasta atualmente selecionada"
tags: [qt, qsettings, sqlite, podcast, escopo, persistencia]
---

## O sintoma

A preferência `podcast/path` apontava corretamente para a pasta nova, e a varredura encontrava
os arquivos certos. Mesmo assim, a tela continuava mostrando programas da raiz anterior.

No caso real, a pasta ativa era `/home/pedro/Podcasts/episodios`, com 8 áudios, enquanto o banco
ainda guardava 9 programas locais: 8 da antiga `/home/pedro/Podcasts` e 1 da raiz atual.

## A causa

`setPodcastPath()` apenas salvava a preferência. `scanPodcastFolder()` era aditivo: inseria os
novos programas e episódios, mas preservava os anteriores para não perder posição e histórico.
As consultas de tela, modelo, “Continuar ouvindo” e busca global, porém, liam o banco inteiro.

Portanto, o app não estava varrendo fora da pasta atual; estava exibindo registros persistidos
por varreduras antigas.

## A regra que resolve

Há duas origens com contratos diferentes:

- programa local só fica visível quando `folder_path` é a raiz ativa ou um descendente dela;
- feed RSS (`feed_url IS NOT NULL`) independe da pasta local e continua sempre visível.

O predicado compartilhado vive em `src/podcastscope.h`. Ele usa um prefixo terminado em `/`,
para que selecionar `/p` inclua `/p/programa`, mas nunca confunda `/podcast` com um filho.
Os registros antigos ficam preservados e reaparecem com seu progresso se aquela raiz for
selecionada novamente.

## A prova

- regressões RED confirmaram vazamento na tela, em “Continuar ouvindo”, no modelo e na busca;
- depois do filtro compartilhado, `tst_podcast` passou 13/13 e `tst_librarybrowser` 21/21;
- uma cópia SQLite consistente do banco real renderizou `1 feed · 8 episódios`;
- tamanho e timestamp do banco original permaneceram idênticos durante a prova.

## Armadilhas

- apagar todos os registros fora da raiz resolveria a tela, mas destruiria progresso e histórico;
- filtrar apenas `shows()` deixa episódios antigos reaparecerem na busca e em outros modelos;
- usar `folder_path LIKE raiz || '%'` sem fronteira de diretório mistura caminhos irmãos.
