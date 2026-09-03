# Handoff — melodarium

> Atualizado: 2026-09-03 · branch: `wip/2026-08-31-ui-contextual-fecho` · lançamento público em preparação

## Estado

- O GitHub `pedronalis/melodarium` já está público, mas `origin/main` ainda aponta para a versão
  antiga. O lançamento preparado localmente é ancestral direto desse `main` e será publicado sem
  PR, conforme a regra do projeto.
- A superfície pública está bilíngue: `README.md` em inglês, `README.pt-BR.md` em português,
  documentação de contribuição nos dois idiomas, arquivos de comunidade, issue forms, changelog,
  notas da `v0.1.0` e workflow de release Flatpak.
- O projeto foi licenciado por decisão explícita do Pedro sob `GPL-3.0-only`; o texto canônico está
  em `LICENSE` e o AppStream usa o mesmo SPDX.
- Cinco prints de 1100×700 vieram do binário/QML real via `grabToImage`, usando XDG, banco, FLACs e
  capas sintéticas descartáveis. O hero 1280×640 compõe três dessas capturas reais.
- Seis mudanças locais de outra fatia continuam preservadas e fora de todos os commits do
  lançamento: `src/audioengine.{h,cpp}`, `tests/CMakeLists.txt`, `tests/tst_audioengine.cpp`,
  `docs/solutions/ui/2026-09-02-recarregar-a-mesma-fila-nao-notifica.md` e
  `tools/check-track-click.sh`.

## Commits do lançamento

- `2453f07` — gate da superfície pública ligado à CI.
- `8716196` — capturador reproduzível e cinco prints reais.
- `aec2f1d` — filosofia “Arquivo Noturno” e hero público.
- `edff3a8` — READMEs bilíngues e contrato de comunidade.
- `bb5070d` — workflow e notas da release Flatpak.
- `353c073` — GPL-3.0-only, AppStream e documentação legal/distribuição.

## Verificação do candidato

- Auditoria Gitleaks da árvore e do histórico: 304 commits e aproximadamente 5,97 MB examinados,
  zero vazamentos encontrados.
- Worktree destacado em `353c073`: configure PASS; build Ninja PASS (285 passos); piso PASS com
  36 testes descobertos; CTest 36/36 PASS em 136,89 s.
- `all_qmllint`, `check-orfaos.sh`, `check-fidelidade.sh`, verificação da galeria,
  `check-public-release.sh`, `check-package.sh`, AppStream pedantic e `actionlint` passaram.
- Flatpak limpo: quatro dependências fixadas e o app compilaram em 151 s. Bundle de 3.633.208
  bytes, checksum SHA-256 verificado e reimportação OSTree confirmada em
  `app/io.github.pedronalis.melodarium/x86_64/0.1.0`, com binário executável e runtime KDE 6.9.
- GitNexus contra `main`: risco `critical` por causa do grande lote acumulado — 503 símbolos e 16
  fluxos afetados em 50 commits. Não é risco introduzido pela documentação; todo o produto novo
  desde o `main` público faz parte do lançamento e passou pelos gates acima.

## Gates humanos ainda abertos

- `2026-08-30-perf-render-fila`: Pedro valida o halo em reprodução na tela.
- `2026-09-01-erros-acessibilidade-preferencias`: percurso só por teclado, avisos, contraste e
  movimento reduzido.
- `2026-09-01-fila-timer-e-entrada`: reordenar fila tocando, timer e drops reais.
- `2026-09-01-podcast-e-portabilidade`: OPML, M3U e backup/restore sobre XDG descartável.
- Também continuam abertos os gates visuais anteriores de `contexto-podcast`,
  `contexto-colecoes` e `mini-player-completo`.

## Próxima ação única

- Publicar o checkpoint em `main`, configurar metadados e segurança do GitHub, criar `v0.1.0`,
  observar CI/release e registrar aqui os URLs e resultados finais.

## Perigos

- Não remover `migrarDoNomeAntigo()` de `main.cpp`; ele ainda protege dados criados sob o nome
  antigo `melodia`.
- Nunca usar `pkill -f 'build/melodarium'`: ele casa com o próprio shell e pode matar trabalho
  alheio. Fechar janela pelo PID exato.
- Sempre compilar antes do `ctest` e exigir o piso; `ctest` pode sair 0 com `Total Tests: 0`.
- Todo redesenho QML precisa passar contextual, órfãos, layout e fidelidade; geometria verde não
  prova cor correta.
- Cores de tela vêm de `Theme` pelos nomes de papel (`cRowAlt`, `cPill`, `cTitle`, …), e toda
  dimensão visual deve respeitar `Theme.uiScale`.
- Não copiar/restaurar o banco real à mão; usar o bundle verificado e XDG temporário em provas.
