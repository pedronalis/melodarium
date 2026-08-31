# melodarium — instruções do projeto

Player de música local em Qt6/QML + libmpv, com a estética do Noctalia. Fedora, Wayland/Hyprland.

## Antes de planejar

- Consultar `docs/solutions/` (lições deste repo) e a seção `## Perigos` do `handoff.md`.
- O trabalho é fatiado: os planos vivem em `docs/plans/`, um por fatia, com frontmatter
  (`status`, `depende-de`, `decisao-humana`). Ler o lote com
  `python3 ~/.claude/scripts/planos-lote.py listar melodarium --dir docs/plans`.

## O plano é o ledger

- Ao concluir uma task, trocar `- [ ]` por `- [x]` **no mesmo commit** do trabalho dela.
- Ao concluir a fatia, `planos-lote.py set-status <plano> concluido`; ao travar, `travado` +
  diagnóstico no fim do próprio plano.
- Fatia com `decisao-humana: sim` não fecha sem o Pedro ver na tela.

## Build e teste

```bash
cmake -B build -G Ninja && cmake --build build
ctest --test-dir build --output-on-failure
```

Rodar sempre por `quiet-run <cmd>`. `ctest` sai **0** com `Total Tests: 0` — todo gate precisa do
piso de contagem de alvos, senão lê verde num repo sem teste nenhum.

Todo redesenho de tela roda **dois** gates antes do commit final:
`bash tools/check-orfaos.sh` (componente QML sem quem o instancie e `Q_INVOKABLE` sem quem o
chame compilam verdes e somem da tela) e `bash tools/check-fidelidade.sh` (mede a COR da tela
contra os hex do desenho). Gate de geometria passa verde com a paleta inteira errada — foi
assim que a tela deixou de ser o desenho sem nada reprovar.

Cor de tela sai de `Theme`, pela escada de nomes de PAPEL (`cRowAlt`, `cPill`, `cTitle`, …),
nunca das 16 chaves do tema do sistema: elas não têm os degraus que o desenho usa.

## Fronteiras

- Repo em `pedronalis/melodarium`, **privado**. Push em `main` liberado; **abrir ao público
  continua sendo decisão do Pedro** — o spec pede aberto, e o nome já saiu do `/batiza`
  (melodarium, 2026-08-28), então o que faltava para abrir já não falta.
- O nome anterior era `melodia`. `migrarDoNomeAntigo()` em `main.cpp` traz biblioteca, capas,
  downloads e podcasts do caminho antigo na primeira abertura — **não remova** enquanto houver
  chance de alguém abrir com dados velhos. Nome de lote histórico (`melodia-religa`,
  `melodia-capa-manda`) fica como está: é registro do que aconteceu.
- **Nunca PR** sem ele pedir: o repo é de um dono só, e PR aqui é cerimônia sem revisor.
- Código, commits e comentários em inglês; conversa e documentos em pt-BR.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **melodarium** (2440 symbols, 3488 relationships, 43 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/melodarium/context` | Codebase overview, check index freshness |
| `gitnexus://repo/melodarium/clusters` | All functional areas |
| `gitnexus://repo/melodarium/processes` | All execution flows |
| `gitnexus://repo/melodarium/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
