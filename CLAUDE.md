# melodia — instruções do projeto

Player de música local em Qt6/QML + libmpv, com a estética do Noctalia. Fedora, Wayland/Hyprland.

## Antes de planejar

- Consultar `docs/solutions/` (lições deste repo) e a seção `## Perigos` do `handoff.md`.
- O trabalho é fatiado: os planos vivem em `docs/plans/`, um por fatia, com frontmatter
  (`status`, `depende-de`, `decisao-humana`). Ler o lote com
  `python3 ~/.claude/scripts/planos-lote.py listar melodia --dir docs/plans`.

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

## Fronteiras

- Commits locais. **Nunca push, nunca PR** — o repo ainda não foi publicado (é decisão do Pedro).
- Código, commits e comentários em inglês; conversa e documentos em pt-BR.
