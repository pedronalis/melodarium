# handoff — melodia

**Atualizado:** 2026-08-27 · **Branch:** `main` · **Último commit:** `22ffff4`

## Onde está

Lote de **9 planos de fatia aprovado** em `docs/plans/`, todos com `status: aprovado`.
**Zero código de aplicação ainda** — o repo tem só o spec, os planos e o research.

Ordem de execução pelo grafo `depende-de:`:

```
esqueleto-build
   ├─ motor-audio ──────┐
   └─ scan-biblioteca ──┴─ tocador-ui ─ navegacao-biblioteca
                                            ├─ colecoes-tags ─ download-youtube
                                            └─ podcast-local ─ feed-rss
```

`motor-audio` e `scan-biblioteca` rodam em paralelo; `colecoes-tags` e `podcast-local` também.

Três fatias têm `decisao-humana: sim` e precisam do Pedro olhando a tela para serem dadas por
concluídas: **esqueleto-build** (a janela abre com a cara certa), **tocador-ui** (o som sai
clicando numa faixa), **colecoes-tags** (a mesma faixa em duas coleções, com um clique).

## Próximo passo

Executar a fatia `esqueleto-build` numa sessão fresca — contexto zero é o design, o plano
carrega o código. Ou `/executa` para rodar o lote, ou `/despacha` para background (o RUN_GATE
de cada fatia é a seção "Verificação da fatia (E2E)" do seu plano).

**Atualize o `status:` no frontmatter ao executar — o plano é o ledger.**
Os `- [ ]` das tasks são a outra metade: trocar por `- [x]` no mesmo commit do trabalho.

## Ambiente já preparado

Instalado nesta máquina: `qt6-qtbase-devel`, `qt6-qtdeclarative-devel`, `mpv-devel`,
`taglib-devel`, `mpvqt-devel`. Mais Qt 6.10.3, cmake 3.31, ninja, gcc 15.3.1, mpv 0.40,
taglib 1.13.1, sqlite 3.53 (FTS5 ativo), yt-dlp, fonte Inter.

## Armadilhas medidas ao vivo (já dentro dos planos — não redescobrir)

- `qt_add_qml_module` **não** honra `pragma Singleton`. Sem
  `set_source_files_properties(X.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)` o qmldir registra
  o arquivo como tipo comum e todo acesso resolve `undefined` — sem erro de compilação nem de
  runtime.
- `mpv_create()` falha sob locale `pt_BR.UTF-8`. `std::setlocale(LC_NUMERIC, "C")` antes dele.
- O Fedora instala `/usr/share/qt6/qtlogging.ini` com `*.debug=false` e manda o resto para o
  journald: `qDebug`/`console.log` somem. Religar com
  `QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1`.
- `target_include_directories(appmelodia PRIVATE src)` é obrigatório: sem ele o build morre
  numa cascata de ~15 erros de template que não apontam a causa.
- Há **dois `yt-dlp`**: o do PATH é o do Homebrew (2026.01.31), o do Fedora é `/usr/bin/yt-dlp`
  (2026.08.19).

## Estacionamento

- [ ] 2026-08-27 · Publicar o repo no GitHub (spec pede "aberto, sem instalador nem suporte") —
      fora dos planos de propósito: é ação manual, não código. Fazer quando o app existir.
- [ ] 2026-08-27 · Nome definitivo do projeto: "melodia" é provisório, o spec manda passar no
      `/batiza`. Trocar antes de publicar custa menos que depois.
- [ ] 2026-08-27 · Bit-perfect real depende do grafo do PipeWire (`default.clock.rate`), não só
      das opções do mpv. O plano documenta o limite; medir de verdade exige um FLAC 96 kHz e uma
      sonda no ponto ALSA.
