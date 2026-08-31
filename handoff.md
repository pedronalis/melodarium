# Handoff — melodarium

> Atualizado: 2026-08-31 19:49 · branch: `wip/2026-08-31-ui-contextual-fecho` · via $fecho

## Estado

- A individualização de Podcast e Coleções está implementada em `main`: contextos próprios,
  player global completo em três zonas e seletor nativo de velocidade para episódios.
- A última correção está em `a7df90c`: a aba agora troca instantaneamente; somente o shell da
  barra sobe em 220 ms e o conteúdo do player entra depois em 180 ms.
- O gate temporal mediu, em Podcast e Coleções, página `1,000 → 1,000 → 1,000`, barra
  `0 → 67,32 → 82 px` e conteúdo do player `0 → 0,898 → 1`.
- `docs/plans/2026-08-31-contexto-podcast.md`, `docs/plans/2026-08-31-contexto-colecoes.md` e
  `docs/plans/2026-08-31-mini-player-completo.md` seguem `em-execucao` somente pelo gate humano.
- A build atual está aberta no workspace 10, PID `1823009`, para avaliação do Pedro.
- Mudanças locais de documentação GitNexus (`AGENTS.md`, `CLAUDE.md` e `.claude/codemap.md`)
  foram preservadas no commit WIP deste fecho; nenhum push foi feito.

## Próxima ação única

- Pedro alterna Biblioteca → Podcast → Coleções com música tocando, abre o seletor nativo de
  velocidade num episódio e confirma a hierarquia/movimento; depois fechar os três planos acima.

## Estacionamento (derivas)

- [ ] Retomar `docs/plans/2026-08-30-perf-render-fila.md` depois do gate humano da UI contextual.
- [ ] Decidir se o repositório privado deve ser aberto ao público; não mudar visibilidade sem
  autorização explícita.
- [ ] Investigar quem recria `~/.local/share/melodarium/melodarium.db` com 0 bytes; o banco real
  fica em `~/.local/share/melodarium/melodarium/melodarium.db`.
- [ ] Remover, quando conveniente, os worktrees já integrados `melodia-religa-run` e
  `melodarium-colecao-run` sem perder os resumos locais ignorados.
- [ ] Quatro peças continuam em reserva declarada no gate de órfãos: `collectionsForTrack`,
  `continueListening`, `setGaplessAggressive` e `unsubscribe`.

## Em voo

- Nenhum run autônomo. Não há `RUN_GATE` nem `.run_gate_count` no cwd.
- Aplicativo interativo aberto: `./build/melodarium`, PID `1823009`, workspace 10, `mapped=true`.

## Verificação

- `quiet-run ctest --test-dir build --output-on-failure` — PASS, 22/22 testes, 69,95 s ·
  2026-08-31 19:49.
- `quiet-run bash tools/check-contextual-ui.sh` — PASS; troca instantânea da página e entrada
  sequencial da barra/player em Podcast e Coleções · 2026-08-31.
- `quiet-run bash tools/check-orfaos.sh` — PASS, zero itens sem porta de entrada · 2026-08-31.
- `quiet-run bash tools/check-layout.sh` e `quiet-run bash tools/check-fidelidade.sh` — PASS;
  layout mínimo e fidelidade visual preservados · 2026-08-31.
- GitNexus `detect_changes(scope: staged)` antes de `a7df90c` — risco baixo, zero fluxos
  afetados · 2026-08-31.

## Perigos

- Não remover `migrarDoNomeAntigo()` de `main.cpp`; ele ainda protege dados criados sob o nome
  antigo `melodia`.
- Nunca usar `pkill -f 'build/melodarium'`: ele casa com o próprio shell e pode matar trabalho
  alheio. Fechar a janela pelo PID exato via Hyprland.
- Sempre compilar antes do `ctest` e exigir o piso de contagem; `ctest` pode sair 0 com binário
  velho ou com `Total Tests: 0`.
- Todo redesenho QML precisa passar `check-contextual-ui.sh`, `check-orfaos.sh`,
  `check-layout.sh` e `check-fidelidade.sh`; geometria verde não prova cor correta.
- Cores de tela vêm de `Theme` pelos nomes de papel (`cRowAlt`, `cPill`, `cTitle`, …), e toda
  dimensão visual deve respeitar `Theme.uiScale`.
