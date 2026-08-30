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
