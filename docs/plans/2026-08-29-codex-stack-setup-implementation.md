# Codex Stack Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` when tasks are independent, or `executing-plans` for inline batch execution. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Codex reliably stack-aware across Pedro's active repositories with repository guidance, current documentation access, reusable stack workflows, reasoning profiles, and indexed code intelligence.

**Architecture:** Keep personal behavior and integrations under `~/.codex`, while each repository owns its durable engineering constraints in `AGENTS.md`. Reusable verification methods live in focused personal skills; GitNexus supplies code-graph context and Context7 supplies current library documentation.

**Tech Stack:** Codex CLI/Desktop, Markdown, TOML, MCP, GitNexus, Python helper scripts, C++/Qt/QML, Next.js/React/TypeScript, Tauri/Rust, FastAPI/Pytest.

## Global Constraints

- Do not edit `~/.claude`; treat it as historical source and backup.
- Preserve all unrelated modified and untracked files in every repository.
- Do not commit, push, open PRs, publish repositories, or connect third-party accounts.
- Use English for code-facing technical names and skill instructions; use pt-BR for project/session documentation where the repository already does so.
- Read each repository's existing `AGENTS.md`, `CLAUDE.md`, manifests, README, and relevant `docs/solutions/` before changing its guidance.
- Preserve GitNexus-managed blocks verbatim when merging repository instructions.
- Never place credentials, tokens, cache contents, transcripts, or generated histories in version control.
- Verify installations, configuration parsing, skill validation, AGENTS discovery, and GitNexus status with fresh commands before reporting completion.

---

## File Map

- `~/.codex/config.toml`: global Codex defaults and MCP registration.
- `~/.codex/routine.config.toml`: faster routine-work reasoning profile.
- `~/.codex/deep.config.toml`: explicit high-reasoning profile for difficult work.
- `~/.codex/skills/{migrate-to-codex,playwright,playwright-interactive}/`: curated skills installed from `openai/skills`.
- `~/.codex/skills/{qt-qml-visual-verification,next-feature-gate,tauri-cross-boundary-debug,fastapi-endpoint-change}/`: focused personal stack workflows.
- `/home/pedro/dev/active/*/AGENTS.md`: repository-specific guidance, merging existing GitNexus context with durable project rules.
- `/home/pedro/dev/active/*/.gitnexus/`: generated, gitignored code-intelligence indexes for active repositories.
- `docs/plans/2026-08-29-codex-stack-setup-implementation.md`: execution ledger for this setup.

### Task 1: Install curated skills and Context7

**Files:**
- Create: `~/.codex/skills/migrate-to-codex/`
- Create: `~/.codex/skills/playwright/`
- Create: `~/.codex/skills/playwright-interactive/`
- Modify: `~/.codex/config.toml`

**Interfaces:**
- Consumes: `openai/skills` curated catalog and the existing Codex configuration.
- Produces: three discoverable skills and an enabled `context7` MCP server.

- [x] **Step 1: Verify the initial absence/state**

Run: `python3 ~/.codex/skills/.system/skill-installer/scripts/list-skills.py --format json && codex mcp list`

Expected: curated entries report their current installation state; `context7` is absent before registration.

- [x] **Step 2: Install the curated skills**

Run: `python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py --repo openai/skills --path skills/.curated/migrate-to-codex skills/.curated/playwright skills/.curated/playwright-interactive`

Expected: each skill is installed once under `~/.codex/skills` without overwriting an existing directory.

- [x] **Step 3: Register Context7**

Run: `codex mcp add context7 -- npx -y @upstash/context7-mcp`

Expected: `context7` is added as an enabled STDIO MCP server.

- [x] **Step 4: Verify installation and MCP startup configuration**

Run: `python3 ~/.codex/skills/.system/skill-installer/scripts/list-skills.py --format json && codex mcp list`

Expected: the three skills report `installed: true` and `context7` reports enabled.

- [x] **Step 5: Checkpoint**

Record the exact installed paths and MCP list output in the final handoff; do not commit home-directory configuration.

### Task 2: Add routine and deep reasoning profiles

**Files:**
- Create: `~/.codex/routine.config.toml`
- Create: `~/.codex/deep.config.toml`
- Preserve: `~/.codex/config.toml`

**Interfaces:**
- Consumes: the existing `gpt-5.6-sol` global model choice.
- Produces: a `medium` routine profile and an `xhigh` deep profile, without changing the current default.

- [x] **Step 1: Verify profile files do not already contain user configuration**

Run: `for f in ~/.codex/routine.config.toml ~/.codex/deep.config.toml; do test ! -e "$f" || sed -n '1,120p' "$f"; done`

Expected: files are absent or their contents are inspected and preserved before any edit.

- [x] **Step 2: Create minimal profile overrides**

```toml
# routine.config.toml
model = "gpt-5.6-sol"
model_reasoning_effort = "medium"
plan_mode_reasoning_effort = "high"
```

```toml
# deep.config.toml
model = "gpt-5.6-sol"
model_reasoning_effort = "xhigh"
plan_mode_reasoning_effort = "xhigh"
```

- [x] **Step 3: Verify both profiles load**

Run: `codex --profile routine --version && codex --profile deep --version`

Expected: both commands exit 0 without TOML or configuration errors.

- [x] **Step 4: Checkpoint**

Record the profile paths and parser verification; do not change the user's global `xhigh` default.

### Task 3: Create four focused stack skills

**Files:**
- Create: `~/.codex/skills/qt-qml-visual-verification/SKILL.md`
- Create: `~/.codex/skills/qt-qml-visual-verification/agents/openai.yaml`
- Create: `~/.codex/skills/next-feature-gate/SKILL.md`
- Create: `~/.codex/skills/next-feature-gate/agents/openai.yaml`
- Create: `~/.codex/skills/tauri-cross-boundary-debug/SKILL.md`
- Create: `~/.codex/skills/tauri-cross-boundary-debug/agents/openai.yaml`
- Create: `~/.codex/skills/fastapi-endpoint-change/SKILL.md`
- Create: `~/.codex/skills/fastapi-endpoint-change/agents/openai.yaml`

**Interfaces:**
- Consumes: real commands and failure modes observed in active repositories.
- Produces: automatically discoverable, narrowly routed workflows with explicit verification gates.

- [x] **Step 1: Initialize each skill with the official initializer**

Run:

```bash
python3 ~/.codex/skills/.system/skill-creator/scripts/init_skill.py qt-qml-visual-verification --path ~/.codex/skills
python3 ~/.codex/skills/.system/skill-creator/scripts/init_skill.py next-feature-gate --path ~/.codex/skills
python3 ~/.codex/skills/.system/skill-creator/scripts/init_skill.py tauri-cross-boundary-debug --path ~/.codex/skills
python3 ~/.codex/skills/.system/skill-creator/scripts/init_skill.py fastapi-endpoint-change --path ~/.codex/skills
```

Expected: each named directory contains `SKILL.md` and `agents/openai.yaml` with no extra placeholder resources.

- [x] **Step 2: Write discriminating instructions**

Implement the following observable boundaries:

- `qt-qml-visual-verification`: only Qt/QML desktop behavior or visual validation; require build, non-zero CTest discovery, relevant repository visual gates, and real/offscreen rendering evidence.
- `next-feature-gate`: only Next.js/React feature verification; read installed Next docs when present and select typecheck/lint/unit/build/Playwright gates from actual package scripts.
- `tauri-cross-boundary-debug`: only failures crossing React/TypeScript, Tauri IPC/capabilities, Rust, or native runtime; distinguish jsdom/browser checks from real Tauri validation.
- `fastapi-endpoint-change`: only FastAPI endpoint/schema/auth/dependency changes; map request/response contracts, async boundaries, validation, and real Ruff/Pytest commands from `pyproject.toml`.

- [x] **Step 3: Run structural validation**

Run: `for d in qt-qml-visual-verification next-feature-gate tauri-cross-boundary-debug fastapi-endpoint-change; do python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py ~/.codex/skills/$d; done`

Expected: all four validations exit 0 with no unfinished scaffold placeholders.

- [x] **Step 4: Run behavior-oriented static checks**

Run: `rg -n 'build|test|verification|scope|boundary|runtime|Playwright|CTest|Ruff|Pytest' ~/.codex/skills/{qt-qml-visual-verification,next-feature-gate,tauri-cross-boundary-debug,fastapi-endpoint-change}/SKILL.md`

Expected: each skill exposes its distinguishing workflow and verification signals.

- [x] **Step 5: Checkpoint**

Record validator output and note that automatic discovery starts in a new Codex turn/session.

### Task 4: Migrate durable repository guidance into AGENTS.md

**Files:**
- Create: `/home/pedro/dev/active/{comic-translate-pt,melodarium,meta-capi-server-side,parede,pomodoro}/AGENTS.md`
- Modify only when necessary: existing root `AGENTS.md` files in `/home/pedro/dev/active/{becam-mail,becam-pesquisa,becam-referencias,deep-research-sota,duolingo-clone,estanteca,hermes,hermes-research,mangavault,nexus,pomodorolist,slides_becam,sussurro,taskweb,translator,veste,vibezap}`
- Preserve: all `/home/pedro/dev/active/*/CLAUDE.md` files and every `<!-- gitnexus:start -->...<!-- gitnexus:end -->` block.

**Interfaces:**
- Consumes: each repository's existing guidance, manifests, README, `handoff.md`, solution notes, and generated GitNexus block.
- Produces: one non-empty root `AGENTS.md` per active Git repository, with commands, architecture/invariants, verification, language, and safety boundaries appropriate to that repository.

- [x] **Step 1: Establish a per-repository baseline**

Run: `for repo in /home/pedro/dev/active/*; do test -d "$repo/.git" || continue; printf '%s\t' "$repo"; test -s "$repo/AGENTS.md" && echo present || echo missing; done`

Expected: exactly the five inventoried repositories report missing before migration.

- [x] **Step 2: Apply the installed migration workflow repository by repository**

For repositories with a `CLAUDE.md`, merge project-owned instructions into root `AGENTS.md`; do not copy Claude-specific invocation syntax when an equivalent Codex skill or command exists. For repositories without a `CLAUDE.md`, derive concise instructions from README, manifests, tests, and operational documentation.

- [x] **Step 3: Preserve generated code-intelligence blocks**

Run: `for f in /home/pedro/dev/active/*/AGENTS.md; do before_or_after=$(rg -c '<!-- gitnexus:start -->|<!-- gitnexus:end -->' "$f" || true); test "$before_or_after" = 0 || test "$before_or_after" = 2; done`

Expected: every GitNexus-managed file has one balanced marker pair; non-indexed repositories have none.

- [x] **Step 4: Verify instruction coverage and discovery**

Run: `for repo in /home/pedro/dev/active/*; do test -d "$repo/.git" || continue; test -s "$repo/AGENTS.md" || exit 1; done`

Expected: all active repositories have a non-empty root `AGENTS.md`.

Run from representative Qt, Next.js, Tauri, and FastAPI repositories: `codex --ask-for-approval never "Summarize the active repository instructions and verification commands."`

Expected: each response reports stack-appropriate commands and constraints from the root `AGENTS.md`.

- [x] **Step 5: Checkpoint**

Use `git -C <repo> diff -- AGENTS.md` and `git -C <repo> status --short` to prove only intended instruction files were added or changed; do not stage or commit.

### Task 5: Index active repositories with GitNexus

**Files:**
- Create or refresh: `/home/pedro/dev/active/*/.gitnexus/`
- Create or refresh when GitNexus owns them: root `AGENTS.md` managed marker blocks.

**Interfaces:**
- Consumes: repository source files and existing Git history.
- Produces: current knowledge graphs registered with the GitNexus MCP.

- [x] **Step 1: List the current registry and repository status**

Run: `gitnexus list` and, where `.gitnexus/run.cjs` exists, `node .gitnexus/run.cjs status` from each active repository.

Expected: existing indexes and stale/unindexed repositories are identified before refresh.

- [x] **Step 2: Analyze each active source repository sequentially**

Run from each active Git root: `gitnexus analyze`

Expected: analysis exits 0, writes or refreshes `.gitnexus/`, and registers the repository. Do not enable embeddings or PDG by default because they add time and external model cost beyond the requested baseline.

- [x] **Step 3: Reconcile generated AGENTS blocks**

If analysis updates the GitNexus marker block, retain project-owned instructions outside the marker and verify the marker remains balanced.

- [x] **Step 4: Verify registry and freshness**

Run: `gitnexus list`; then run `node .gitnexus/run.cjs status` from each successfully indexed repository.

Expected: every analyzed repository is registered and reports a readable status; failures are reported individually rather than hidden.

- [x] **Step 5: Checkpoint**

Record indexed, skipped, and failed repositories explicitly. Do not publish a wiki or Gist and do not use API-backed embeddings.

### Task 6: Final configuration and scope audit

**Files:**
- Verify: all files and directories produced by Tasks 1-5.
- Modify: this plan only to check completed steps after their corresponding evidence exists.

**Interfaces:**
- Consumes: installation output, config parser results, skill validator output, AGENTS diffs, and GitNexus statuses.
- Produces: an evidence-backed handoff with exact changes, remaining restart requirements, and any repository-specific failures.

- [x] **Step 1: Run the complete verification matrix**

Run:

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/list-skills.py --format json
codex mcp list
codex --profile routine --version
codex --profile deep --version
for d in qt-qml-visual-verification next-feature-gate tauri-cross-boundary-debug fastapi-endpoint-change; do
  python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py ~/.codex/skills/$d
done
for repo in /home/pedro/dev/active/*; do
  test -d "$repo/.git" || continue
  test -s "$repo/AGENTS.md" || exit 1
done
gitnexus list
```

Expected: all configured components are present and parseable; any incomplete index is isolated and named.

- [x] **Step 2: Audit changed files and preservation constraints**

Run: `git -C /home/pedro/dev/active/melodarium diff -- docs/plans/2026-08-29-codex-stack-setup-implementation.md AGENTS.md` and equivalent `git diff -- AGENTS.md` for every touched repository.

Expected: no source code, credentials, `CLAUDE.md`, or unrelated user files were changed by this setup.

- [x] **Step 3: Mark the ledger and hand off**

Check only steps with fresh evidence. Report that newly installed and created skills become automatically discoverable in the next Codex turn/session, and that MCP additions may require restarting the current client.
