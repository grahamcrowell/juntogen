# Generation Prompt: Step 01 — Scaffold and Protocol (Codex)

**Purpose**: Generate the plugin-tree directory structure and the core manager protocol
(`CONDUCTOR.md`) for the Codex platform.

This prompt is an **adaptation** of `juntogen/claude/steps/step-01-scaffold-and-protocol.md`.
Every `[EXACT]` block in that prompt is platform-agnostic and MUST be reproduced verbatim
(role declaration, Triage Requirement, Self-Check, Circuit Breaker, Adaptive Signals,
Triage Criteria, Domain Signals, Stakeholder Escalation Guard, PERSPECTIVE block, spawn
formats, both Handback formats, Quality Gate counts 2/6/9, the 10-section organization).
Only the **platform bindings** below change. Treat this file as: "the Claude step-01, with
the following substitutions."

---

## Input

Same spec inputs as the Claude step (`F08-axioms.md`, `F16-architecture.md`,
`D08-core-protocol.md`, plus canonical sources `D24`, `D32`, `D40`, `D48`), plus:
- `platform-snapshot.yaml` (from Codex step-00) — consume `models` for the selection table
  and `platform.identity` for path/token binding.
- `juntogen/codex/D64-tooling.md` — Codex tooling binding.
- `{OJ_SOURCE}/CONDUCTOR.md` — format reference (an existing oj-claude or oj-codex CONDUCTOR.md).

---

## Task

### 1. Directory Structure

Plugin-tree-direct layout at the plugin root (same as Claude), plus the Codex-native
agent-definition directory:

```
<plugin-root>/
├── CONDUCTOR.md                 (generate in this step)
├── agents/                      (16 full + 16 *-compact.md profiles; step-03)
├── .codex/agents/               (native subagent definition TOMLs; step-03; [VERIFY] bundling path)
├── templates/                   (step-05)
├── skills/                      (step-06)
└── reference/                   (step-04)
```

### 2. Core Manager Protocol (`CONDUCTOR.md`)

Generate the complete `CONDUCTOR.md` (all 10 major sections per `D08-core-protocol.md`),
applying the substitutions below.

---

## Codex Substitutions (the ONLY platform deltas)

### S1 — Plugin-internal path token

Replace every `${CLAUDE_PLUGIN_ROOT}` with **`${PLUGIN_ROOT}`**. All plugin-internal
references (`agents/`, `reference/`, `skills/`, `templates/`, `hooks/`, `bin/`) MUST use
`${PLUGIN_ROOT}/<path>`.
- **MUST NOT** use `~/.codex/<path>` for plugin-internal files (that is the adopter HOME, not
  the plugin cache install path).
- **MUST NOT** use bare relative paths.
- Project-local files (`.codex/BACKLOG.md` — [VERIFY] backlog location convention) are not
  plugin-internal; leave as-is.

### S2 — Manager protocol activation

`CONDUCTOR.md` is injected at session start by the `SessionStart` hook
(`oj-helper conductor-inject`), NOT by writing the adopter's `AGENTS.md`. The protocol prose
must assume injection-as-developer-context. Do not instruct the adopter to paste protocol into
`AGENTS.md`; the hook handles it (see `D64-tooling.md` § conductor-inject).

### S3 — Model Selection (Section 7) — render from the Codex snapshot

Render the tier table from `platform-snapshot.yaml` `models`: substitute
`{tier-routine}` → `gpt-5.4-mini`, `{tier-implementation}` → `gpt-5.3-codex`,
`{tier-reasoning}` → `gpt-5.5`. Emit the function-first selection rules and the per-role
default table from `D32 §6` exactly as the Claude step requires, with these concrete ids.

### S4 — Per-expert effort IS controllable (replaces the Claude "effort out-of-scope" note)

The Claude step-01 emits an "effort is not controllable" note. On Codex, **delete that note**
and instead emit a short subsection stating that per-expert `model` AND
`model_reasoning_effort` are bound on each native agent-definition file (step-03,
`.codex/agents/<expert>.toml`). The function-first rules therefore bind effort per expert —
e.g. the adversarial-reviewer slot runs at `model_reasoning_effort = "xhigh"`. Effort is no
longer only session-level. (This is a genuine capability gain over the Claude binding.)

### S5 — Complex tier fallback (Axiom 8) — Codex form

Replace the Claude `TeamCreate`-unavailable clause with the Codex degradation chain:
- **Primary**: Complex tier uses **parallel Codex subagents** — the manager (or a deputy
  coordinator subagent) spawns stakeholder analyses in parallel; Codex waits for all and
  returns a consolidated response. `agents.max_threads` (default 6) bounds concurrency.
- **No `Inform`**: Codex has no agent↔agent messaging, so synthesis is **handback-only** in
  ALL tiers (there is no "teams" mode with peer relay to fall back FROM — Codex starts where
  the Claude degraded path lands). Document this as the steady state, not a fallback.
- **Degraded**: if subagents are unavailable (`agents.max_threads = 0` or policy-disabled),
  detected via `oj-helper subagents-check` (`.available` from its JSON, always exit 0), Complex
  degrades to inline manager-driven perspective rotation. User Checkpoint, pre-mortem (≥3
  scenarios), and adversarial review remain mandatory.

---

## Verification

All Claude step-01 verification items apply, with these Codex-specific changes:
- [ ] `CONDUCTOR.md` contains ≥1 `${PLUGIN_ROOT}/` reference and ZERO `${CLAUDE_PLUGIN_ROOT}` / `~/.claude/` references.
- [ ] `.codex/agents/` directory exists at plugin root (empty at this stage).
- [ ] Model selection table reflects gpt-5.4-mini / gpt-5.3-codex / gpt-5.5 with tiers routine/implementation/reasoning.
- [ ] Section 7 emits the per-expert-effort-IS-controllable note (NOT the Claude out-of-scope note).
- [ ] Complex-tier fallback documents parallel-subagents + handback-only synthesis + subagents-check degradation.
- [ ] All platform-agnostic `[EXACT]` blocks reproduced verbatim (2/6/9 gates, handback anchors, PERSPECTIVE format, etc.).

## Dependencies

**Requires**: Codex step-00 (`platform-snapshot.yaml`).

## Output

- Plugin-tree directory structure (incl. `.codex/agents/`).
- Complete `CONDUCTOR.md` at plugin root. Required by steps 02 and 03.
