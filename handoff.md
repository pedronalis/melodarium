# Handoff — melodarium

> Atualizado: 2026-09-03 · branch: `wip/2026-08-31-ui-contextual-fecho` · lançamento público concluído

## Estado

- O repositório público está disponível em <https://github.com/pedronalis/melodarium>, com
  `main` como branch padrão, Issues e Discussions habilitados, descrição bilíngue, homepage para
  a release mais recente e tópicos de descoberta coerentes com Qt/QML, libmpv, Flatpak e Linux.
- A release estável `v0.1.0` foi publicada em
  <https://github.com/pedronalis/melodarium/releases/tag/v0.1.0>. A tag aponta para `b31586c` e
  entrega bundle Flatpak x86_64, checksum SHA-256 e provenance attestation pública.
- A superfície pública está bilíngue: `README.md` em inglês, `README.pt-BR.md` em português,
  documentação de contribuição nos dois idiomas, arquivos de comunidade, issue forms, changelog
  e notas de release bilíngues.
- O projeto está licenciado sob `GPL-3.0-only`; o texto canônico está em `LICENSE`, o AppStream usa
  o mesmo SPDX e o GitHub reconhece GNU GPLv3.
- Cinco prints de 1100×700 vieram do binário/QML real via `grabToImage`, usando XDG, banco, FLACs e
  capas sintéticas descartáveis. O hero 1280×640 compõe três dessas capturas reais e está
  versionado em `docs/assets/melodarium-hero.png`.
- Seis mudanças locais de outra fatia continuam preservadas e fora de todos os commits do
  lançamento: `src/audioengine.{h,cpp}`, `tests/CMakeLists.txt`, `tests/tst_audioengine.cpp`,
  `docs/solutions/ui/2026-09-02-recarregar-a-mesma-fila-nao-notifica.md` e
  `tools/check-track-click.sh`.

## Commits do lançamento

- `2453f07` — gate da superfície pública ligado à CI.
- `8716196` — capturador reproduzível e cinco prints reais.
- `aec2f1d` — filosofia “Arquivo Noturno” e hero público.
- `edff3a8` — READMEs bilíngues e contrato de comunidade.
- `bb5070d`, `353c073` — release Flatpak, GPL-3.0-only, AppStream e distribuição.
- `4aefece`, `a3bbf89`, `ef253e1` — checkout confiável em container e actions Node 24.
- `97572d6`, `03ffb55` — sincronização determinística dos gates de movimento e áudio.
- `d250d5e`, `b31586c` — preflight completo do release e prefixo Flatpak portátil em `/app/lib`.

## Evidência final

- Auditoria Gitleaks da árvore e do histórico: 304 commits e aproximadamente 5,97 MB examinados,
  zero vazamentos encontrados.
- Worktree limpo em `b31586c`: build Ninja PASS; piso PASS com 36 testes descobertos; CTest 36/36
  PASS; `all_qmllint`, órfãos, fidelidade, movimento, galeria, pacote, AppStream, superfície pública
  e `actionlint` verdes.
- CI da tag: <https://github.com/pedronalis/melodarium/actions/runs/33766580314>, sucesso com todos
  os 36 testes e gates determinísticos.
- Workflow de release: <https://github.com/pedronalis/melodarium/actions/runs/33766580177>, sucesso
  em 11m40s nas etapas de build, attestation e publicação.
- Asset publicado `melodarium-v0.1.0-x86_64.flatpak`: 3.594.040 bytes, SHA-256
  `914f0fbc2ca52e5220fa40ee4b43108fbfede5543e3a2caf71df5c312ffd10f6`; o `.sha256` baixado do
  GitHub retornou `OK` sobre o bundle baixado.
- `gh attestation verify` confirmou SLSA provenance assinada pelo workflow `Release Flatpak`, tag
  `refs/tags/v0.1.0`, commit `b31586c` e runner GitHub-hosted público. O bundle importou em um
  repositório OSTree vazio como `app/io.github.pedronalis.melodarium/x86_64/0.1.0` e foi
  reexportado com sucesso.
- GitNexus contra o `main` anterior indicou risco `critical` pelo lote histórico acumulado — 503
  símbolos e 16 fluxos em 50 commits. A compensação foi o conjunto integral de gates locais e
  remotos acima; a documentação final não altera símbolos do produto.

## Gates humanos ainda abertos

- `2026-08-30-perf-render-fila`: Pedro valida o halo em reprodução na tela.
- `2026-09-01-erros-acessibilidade-preferencias`: percurso só por teclado, avisos, contraste e
  movimento reduzido.
- `2026-09-01-fila-timer-e-entrada`: reordenar fila tocando, timer e drops reais.
- `2026-09-01-podcast-e-portabilidade`: OPML, M3U e backup/restore sobre XDG descartável.
- Também continuam abertos os gates visuais anteriores de `contexto-podcast`,
  `contexto-colecoes` e `mini-player-completo`.

## Próxima ação única

- Retomar separadamente a fatia local da fila/áudio já em andamento; o lançamento público não tem
  ação pendente.

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
- No release Ubuntu, manter `build-options.libdir: /app/lib`: o runtime Flatpak procura
  `pkg-config` e bibliotecas nesse prefixo, enquanto o padrão `/app/lib64` quebra o build do mpv.
