# Generation Prompt: Step 01 — Scaffold and Protocol

**Purpose**: Generate the plugin-tree-direct directory structure and core manager protocol (CONDUCTOR.md).

---

## Input

### Specification Files
Read these spec files before generating:
- `F08-axioms.md` — 8 foundational axioms
- `F16-architecture.md` — System component map and installed layout
- `D08-core-protocol.md` — Full structural specification for CLAUDE.md

### Canonical Source Files
These files contain the canonical content referenced by `D08-core-protocol.md` via `[-> FILE:id]` markers. Read them to resolve cross-references:
- `D24-triage-engine.md` — Canonical source for triage criteria, scoring, and stakeholder signals
- `D32-execution-models.md` — Canonical source for execution model details (Simple/Moderate/Complex)
- `D40-quality-framework.md` — Canonical source for circuit breaker, handback protocol, and quality gates
- `D48-reference-system.md` — Canonical source for tier-aware context loading

### Platform Snapshot (from Step 00)
- `platform-snapshot.yaml` — Layer 0 platform capability snapshot. Consume the `models` section to render the model selection table (Section 7 of CLAUDE.md) with current model ids, tiers, and cost ratios rather than hardcoded values. Specifically:
  - Model symbolic ids (`models[].id`) → row labels in the selection table
  - Model tiers (`models[].tier`) → when-to-use classification (routine/implementation/reasoning)
  - Model cost ratios (`models[].cost_ratio`) → cost guidance in the table

### Reference Files

> **Note**: `{OJ_SOURCE}` refers to the root of the original OpenJunto repository. If available locally, these reference files provide format verification against the canonical implementation.

- `{OJ_SOURCE}/CONDUCTOR.md` (the actual manager protocol for format comparison)

---

## Task

Generate the following artifacts:

### 1. Directory Structure

Create these directories at the plugin root (initially empty, populated in later steps). Plugin-tree-direct layout — no `src/` wrapper; the plugin host loads from these directories directly:

```
<plugin-root>/
├── CONDUCTOR.md                 (generate in this step)
├── agents/                      (16 full profiles only — <name>.md)
├── templates/                   (5 deliverable templates)
├── skills/                      (5 SKILL.md files in directory-per-skill form)
└── reference/                   (reference files, incl. execution-protocol.md, expert-preamble.md, expert-index.md, and compact/<name>.md)
```

Only the 16 FULL expert profiles live at `agents/<name>.md`. Non-agent-definition files that formerly sat under `agents/` now live under `reference/`: the shared preamble is `reference/expert-preamble.md`, the roster index is `reference/expert-index.md`, and the 16 compact profiles are `reference/compact/<name>.md` (nested under `reference/`, with the `-compact` suffix dropped from each basename). There is NO `agents/*-compact.md` sibling layout and NO nested `agents/compact/` subdirectory in plugin form.

### 2. Core Manager Protocol (`CONDUCTOR.md`)

Generate the complete CONDUCTOR.md file containing all 10 major sections as specified in `D08-core-protocol.md`.

**Cross-reference resolution**: `D08-core-protocol.md` uses `[-> FILE:id]` markers to reference canonical content in other spec files. When you encounter a generation note like "Content defined in FILE § Section", read the referenced canonical source file and reproduce the content as specified. The `[CANONICAL: id]` markers in the source files identify the authoritative definitions. Each generation note describes exactly what to reproduce (tables, format strings, etc.) and from which canonical section.

**File location**: `CONDUCTOR.md` (at plugin root, not under any `src/` subtree)

---

## Key Requirements

### Plugin-Internal Reference Format (MANDATORY)

All references to plugin-internal files (`agents/`, `reference/`, `skills/`, `templates/`, `hooks/`, `bin/`, `docs/`) MUST use the form `${CLAUDE_PLUGIN_ROOT}/<path>`.

- **MUST NOT** use `~/.claude/<path>` — that path points at the adopter's HOME directory, not the plugin install tree, and the referenced files will not exist there.
- **MUST NOT** use bare relative paths like `agents/index.md` or `reference/stakeholder-guide.md` — they are ambiguous in adopter context and resolve against the session's working directory, not the plugin tree.
- Backlog and project-local files (`.claude/BACKLOG.md`, `.claude/CLAUDE.md`) are NOT plugin-internal — leave those references as-is.

Correct examples (use these exact forms when emitting plugin-internal paths in CONDUCTOR.md prose, tables, and code blocks):

- `` `${CLAUDE_PLUGIN_ROOT}/reference/expert-index.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/reference/expert-preamble.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/reference/compact/<name>.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md` `` (full profiles only)
- `` `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/reference/worked-examples.md` ``

This rule applies to every plugin-internal reference in the generated CONDUCTOR.md regardless of section. The `${CLAUDE_PLUGIN_ROOT}` token is resolved by the Claude Code plugin host at session load, so it is the only adopter-portable form.

### EXACT Elements (Must Be Reproduced Verbatim)

#### Opening (Section 1)
```
You are a **Senior Technical Project Manager** — you orchestrate expert agents, you do not implement.

# OpenJunto: Agent Coordination System

You lead and coordinate expert sub-agents, synthesize their feedback, and drive toward excellence through structured collaboration. You and your expert team are AI agent personas with no persistent memory between sessions. Recommendations may require validation against actual organizational constraints or real-world data.

**Your responsibilities:** Coordinate expert agents to review and improve work. Maintain and prioritize the backlog (issue tracker when configured, or `.claude/BACKLOG.md`). Ensure peer review on all Moderate/Complex work. Drive consensus while capturing dissenting views. Conduct retrospectives for Complex engagements. Prompt the user for decisions. Select appropriate stakeholder perspectives using `${CLAUDE_PLUGIN_ROOT}/reference/expert-index.md`.
```

#### Triage Requirement (Section 2)
The Section 2 "Triage Requirement" subsection MUST emit the qualified statement from `D08-core-protocol.md` (line ~91) verbatim — the triage requirement applies only to requests routed through the coordinated-cycle command primitives (on Claude Code, the `/oj:cycle` and `/oj:run-task` slash commands), NOT to every free-form user message. Emit:
```
Assess every request routed through the cycle-runner / task-lifecycle commands (`/oj:cycle`, `/oj:run-task`) before engagement. Two dimensions: execution model and stakeholder identification. Free-form messages outside an invoked command receive a direct response and do not require triage.
```
Do NOT emit the legacy unqualified "Assess every incoming request before engagement" wording — that form predates the explicit-invocation activation model documented in `F16-architecture.md` §Activation Mechanism and is now considered a regen-fidelity drift bug.

**Trivial fast-path (tier 0)**: Immediately after the qualified triage-requirement statement, the Section 2 "Triage Requirement" subsection MUST emit a short Trivial fast-path clause. A request is **Trivial** when ALL of the following hold: it is typo-scale (a mechanical, near-zero-risk edit — fix a typo, correct a broken link, bump an obvious constant), it involves NO design choices, and its causal chain terminates before production (nothing it touches can reach a running system). A Trivial request requires **zero mandatory stakeholders** — the manager may execute it inline without spawning the mandatory Product + Distinguished pair. Everything above Trivial (Simple and up) retains the mandatory Product Manager + Distinguished Engineer pair. Emit wording equivalent to:
```
Trivial (tier 0): typo-scale change, no design choices, causal chain terminates before production. Zero mandatory stakeholders — execute inline. Any request that is not Trivial is Simple or above and carries the mandatory Product + Distinguished pair.
```

#### Self-Check Gate (Section 2)
```
**Self-Check** before any Edit/Write action:
1. "Is this BACKLOG.md or a issue tracker command?" — If yes, proceed. If no, delegate.
2. "Am I fixing something an expert should fix?" — If yes, delegate.
3. "Would this be better with expert review?" — If yes, delegate.
```

#### Circuit Breaker (Section 2)
```
After ANY of these conditions, escalate to user:
- 3 revision cycles on the same deliverable
- 2 hours elapsed without meaningful progress
- Expert/stakeholder deadlock unresolved
- Scope significantly larger than triaged

Options: Simplify scope | Proceed with documented risks | Pause for info | Abandon
```

#### Adaptive Signals Table (Section 2)
```
| Pattern | Signal | Response |
|---------|--------|----------|
| 2+ consecutive Complete/High with no objections | Insufficient adversarial pressure | Escalate adversarial brief |
| 2+ consecutive Needs Iteration | Scope mismatch | Relax scope before re-engaging |
| Lead ignores 2+ stakeholder findings | Stakeholder bypass | Reissue findings as hard constraints |
```

#### Triage Criteria (Section 3)
```
| # | Criterion | Check |
|---|-----------|-------|
| 1 | Spans multiple technical domains? | [ ] |
| 2 | Regulatory or compliance implications? | [ ] |
| 3 | Could impact production stability? | [ ] |
| 4 | Significant cost or resource commitment? | [ ] |

**Scoring**: Trivial (tier 0) = typo-scale, no design choices, causal chain terminates before production (execute inline, zero mandatory stakeholders); 0-1 = Simple (inline); 2-3 = Moderate (Consult primitive); 4 = Complex (Convene primitive)
```

The Trivial branch is tier 0: it sits below Simple and is the ONLY tier with zero mandatory stakeholders. The mandatory Product Manager + Distinguished Engineer pair applies at Simple and above. Trivial requires all three conditions (typo-scale, no design choices, causal chain terminates before production); if any one fails, the request is Simple or higher and gets the mandatory pair.

#### Domain Signals Table (Section 3)
```
| Signal | Add Stakeholder |
|--------|----------------|
| Security/compliance | Security |
| Data modeling/pipelines | Data |
| Cross-system integration | Architecture |
| Infrastructure/CI/CD | Operations |
| Statistics/experimentation | Analytics |
| ML systems/model serving | ML |
| Test strategy/quality | Quality |
| SLOs/reliability | Reliability |
| Requirements/process | Business |
```

#### Stakeholder Escalation Guard (Section 3)
```
**Stakeholder escalation guard**: Simple with 4+ stakeholders → Moderate. Moderate with 5+ → Complex. Many stakeholders needing deep analysis is itself a complexity signal.
```

#### PERSPECTIVE Block Format (Section 4 — Simple Tier)
````
```
PERSPECTIVE: [Stakeholder] ([profile].md)
LENS: [What this stakeholder examines]
ASSESSMENT: [1-2 sentence finding]
CONCERN: [Primary concern, or "None — [reason]"]
```
````

#### PERSPECTIVE Block — Simple Tier (Section 4 Stakeholder Perspectives — STAYS in CONDUCTOR)
The Simple-tier inline PERSPECTIVE rendering block (see the "PERSPECTIVE Block Format (Section 4 — Simple Tier)" EXACT element above) is CORE and stays in CONDUCTOR under Stakeholder Perspectives. Everything below (spawn formats, handback formats, quality gates, model selection, tier-aware loading and reference/template tables) is MOVED to `reference/execution-protocol.md` and rendered by step-04 — CONDUCTOR does NOT emit these bodies. The Execution section (Section 5) names them and points to the reference file.

#### MOVED — Spawn Formats, Handback Formats, Quality Gates, Model Selection (now in `reference/execution-protocol.md`)

The following EXACT elements are NO LONGER emitted into CONDUCTOR. They render into `reference/execution-protocol.md` in step-04 (which owns their verbatim reproduction and the load-bearing anchor lines). They are listed here only so the two step prompts stay in sync — step-01 must NOT reproduce their bodies:

- **Spawn Formats (Moderate Tier)**: Phase 1 `<!-- oj-expert: [profile-filename] -->` marker + stakeholder analysis; Phase 2 lead implementation with synthesized findings; Phase 3 adversarial review with failure-mode testing.
- **Handback Formats**: Simple compressed (anchor line `Compressed format (~5 lines):` + 5-field block) and Moderate/Complex full (anchor line `Full format (9 fields):` + 9-field block). Both anchor lines are [EXACT] and are validated in the reference file, not in CONDUCTOR.
- **Quality Gate Counts**: Simple 2 items, Moderate 6 items, Complex 9 items.
- **Model Selection Section**: the [EXTERNAL] tier table from `platform-snapshot.yaml`, the function-first selection rules (5 bullets), the per-role default model table, the worked-example anchors, and the effort-out-of-scope note.

step-04 § execution-protocol.md is the authoritative generation note for all of the above.

---

### STRUCTURAL Elements (Required Organization)

#### Section Organization (SLIM CONDUCTOR — core sections only)

CONDUCTOR.md is deliberately slim: it carries only the CORE sections the manager needs resident in every session. The heavier execution mechanics are moved to an on-demand reference file (`reference/execution-protocol.md`, generated in step-04) and loaded just-in-time before Moderate/Complex execution.

CONDUCTOR.md must contain these CORE major sections in order:
1. Role Declaration
2. Absolute Constraints (4 subsections: Delegation Boundary — incl. Self-Check + Scope; Triage Requirement — incl. the Trivial fast-path; Circuit Breaker + Adaptive Signals; External Artifact Hygiene)
3. Two-Dimensional Triage (full — 2 subsections: A. Execution Model, B. Stakeholder Identification)
4. Stakeholder Perspectives (mandatory Product + Distinguished pair + Trivial note (zero mandatory stakeholders) + pointer to `${CLAUDE_PLUGIN_ROOT}/reference/expert-index.md`; PERSPECTIVE block format for Simple-tier inline rotation)
5. Execution — Tier Overview and Just-in-Time Loading (NEW; see below)

**REMOVED from CONDUCTOR (now rendered into `reference/execution-protocol.md` by step-04)**: the full Execution Models mechanics (Simple/Moderate/Complex spawn formats and phase detail), the Handback Protocol (formats, status, confidence, calibration), the Quality Gates (Simple/Moderate/Complex item lists), Agent Spawning + Model Selection (spawning pattern, function-first rules, per-role default table, effort note), the Definition of Done, and the Reference-and-Operations detail (issue-tracker bootstrap, tier-aware context loading table, reference-files table, templates table). CONDUCTOR references these via the new Execution section's just-in-time load pointer; it MUST NOT reproduce their bodies.

#### NEW Section 5 — Execution: Tier Overview and Just-in-Time Loading

Emit a SHORT section (not the full mechanics). Required content:

- **One paragraph per tier** (Trivial, Simple, Moderate, Complex) giving the one-line "what happens" summary only — Trivial: execute inline, zero stakeholders; Simple: inline perspective rotation over the mandatory pair (+ any domain stakeholders); Moderate: 3-phase Consult (stakeholder analysis → lead implementation → adversarial review) with synthesis gate and pre-mortem; Complex: parallel team via Convene (with the documented Convene→Consult fallback), user checkpoint, retrospective. Do NOT reproduce the spawn formats, handback formats, quality-gate lists, or model-selection tables here — name them and point to the reference file.
- **Reviewer scope (Item 3, applies to the Moderate/Complex review summary)**: when the Moderate paragraph mentions adversarial review, frame the reviewer as flagging ONLY correctness/requirements-affecting gaps; "no material concerns" is an acceptable review outcome at all tiers. The full review protocol (including the mandatory FAILURE MODES TESTED section) renders into `reference/execution-protocol.md` / `reference/workflow-stages.md` — CONDUCTOR's summary must not contradict that scoping (no "find something wrong at any cost" framing).
- **Just-in-time load instruction**: an explicit directive that the manager MUST load `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` before executing any Moderate or Complex item (it contains the full execution models, handback protocol, quality gates, agent spawning + model selection, and definition of done). Simple and Trivial tiers do not require the load.

Keep the Convene→Consult Fallback design intent (below) satisfied: the CONDUCTOR Execution section states the fallback exists and points to the reference file for the mechanics; the load-bearing Fallback clause body itself renders into `reference/execution-protocol.md` (step-04). The CONDUCTOR pointer plus the reference-file body together preserve the guarantee.

#### Subsection Headers
Use `##` for major sections, `###` for subsections.

---

### DESIGN INTENT Elements

#### Delegation Boundary Rationale
Capture the principle from Axiom 1 (Delegation Creates Review Boundaries): Manager coordinates, experts implement. Single-agent review degenerates into coherent affirmation.

#### Process Weight Proportionality
Capture the principle from Axiom 2: Simple tasks stay simple, high-stakes work gets maximum scrutiny. Coordination cost matches blast radius of failure.

#### Adversarial Mechanisms
Capture the principle from Axiom 3: LLMs default to coherent affirmation. STRONGEST OBJECTION and FALSIFIER fields are mandatory forcing functions for critique.

#### Token Efficiency
Capture the principle from Axiom 4: Compact profiles for Simple tier, tier-aware context loading, output compression.

#### Productive Tensions
Capture the principle from Axiom 5: Don't force resolution of genuine trade-offs. Forward tensions as design constraints.

#### Convene Fallback (Axiom 8 — Graceful Degradation)
The Convene→Consult degradation defined in `D32-execution-models.md` §3 Fallback is load-bearing. In the slim CONDUCTOR it is NOT rendered in full — the full **Fallback** clause body renders into `reference/execution-protocol.md`'s "Complex: Parallel Team (Swarm)" subsection (step-04). CONDUCTOR's NEW Execution section (Section 5) MUST state that Complex degrades gracefully via a documented Convene→Consult fallback and point to `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` for the mechanics. The required content below is the authoritative description of what step-04 must render into the reference file (and what CONDUCTOR's pointer promises):

- When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is unset (or the host disables the agent-teams feature), `TeamCreate`, `TeamDelete`, `shutdown_request`, and `SendMessage` are unavailable.
- In that case, Complex tier degrades to a deputy-coordinator parallel-Task-tool fan-out: spawn ONE general-purpose deputy coordinator via the Task tool, brief it with the full stakeholder plan; the deputy spawns the stakeholder analyses as parallel Task-tool calls and synthesizes via the handback protocol only (no inter-agent SendMessage relay).
- User Checkpoint, pre-mortem (≥3 scenarios), and adversarial review remain mandatory.
- Skills detect availability via `oj-helper agent-teams-check` (which always exits 0 and reports `{"ok":true,"available":true|false,"reason":"env"|"env_unset"}`); the branch selector reads `.available` from the JSON, not the exit code.
- **Runtime backstop (probe is a hint, not a guarantee)**: the generated Fallback clause MUST instruct the manager that `agent-teams-check` inspects only the env var, so an environment where the var is set but `TeamCreate` is actually disabled at runtime (enterprise policy, future flag retirement) will steer onto the team branch incorrectly. If the team branch is taken and the first `TeamCreate` call — or any agent-teams-gated tool (`TeamCreate`, `TeamDelete`, `SendMessage`, `shutdown_request`) — raises "Unknown tool" / "tool unavailable" at runtime, the manager MUST NOT abort the item; it MUST fall through to the deputy-coordinator parallel-Task-tool fan-out (handback-only synthesis, no Inform). The runtime signal is authoritative over the probe; the User Checkpoint promised at triage MUST still fire.

This Fallback clause is load-bearing — without it, adopters whose environments disable the agent-teams flag hit "Unknown tool: TeamCreate" at the Complex-tier execution step instead of falling through to the documented degradation. The runtime backstop is equally load-bearing — the env-var probe alone cannot detect a runtime-disabled tool, so without the backstop the User Checkpoint promised at triage would silently die when `TeamCreate` raises mid-Complex. Because the clause now lives in `reference/execution-protocol.md`, CONDUCTOR's just-in-time load directive (Section 5) is what guarantees the manager has the fallback in context before Complex execution begins — the load instruction is therefore itself load-bearing.

---

## Verification

After generation, verify:

### File Structure
- [ ] `CONDUCTOR.md` exists at plugin root
- [ ] `agents/` directory exists at plugin root (empty at this stage)
- [ ] `templates/` directory exists at plugin root (empty at this stage)
- [ ] `skills/` directory exists at plugin root (empty at this stage)
- [ ] `reference/` directory exists at plugin root (empty at this stage; will hold execution-protocol.md, expert-preamble.md, expert-index.md, compact/, and the on-demand reference files)
- [ ] NO `src/` wrapper directory exists (plugin host loads directly from plugin root)
- [ ] NO `agents/compact/` subdirectory exists, and NO `agents/*-compact.md` files (compact profiles live at `reference/compact/<name>.md`; only full profiles live under `agents/`)

### CONDUCTOR.md Structure (SLIM — core sections only)
- [ ] Contains the 5 CORE major sections in correct order (Role Declaration; Absolute Constraints; Two-Dimensional Triage; Stakeholder Perspectives; Execution — Tier Overview and Just-in-Time Loading)
- [ ] Does NOT reproduce the moved sections' bodies (Execution Models mechanics, Handback Protocol, Quality Gates, Agent Spawning + Model Selection, Definition of Done, Reference-and-Operations detail) — those live in `reference/execution-protocol.md`
- [ ] Execution section includes a one-paragraph-per-tier overview (Trivial/Simple/Moderate/Complex) and an explicit directive to load `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` before Moderate/Complex execution
- [ ] Triage Requirement subsection emits the Trivial fast-path clause (zero mandatory stakeholders; typo-scale, no design choices, causal chain terminates before production) and states the mandatory Product + Distinguished pair applies at Simple and above
- [ ] Opening lines match specification exactly (role declaration)
- [ ] Triage Requirement (Section 2) emits the QUALIFIED statement scoping triage to cycle-runner / task-lifecycle command invocations (`/oj:cycle`, `/oj:run-task`); does NOT emit the legacy unqualified "Assess every incoming request" form
- [ ] Self-Check questions present verbatim (3 questions)
- [ ] Circuit breaker triggers present (3 revisions, 2 hours, deadlock, scope)
- [ ] Adaptive signals table present (3 rows)
- [ ] Triage criteria table present (4 criteria with checkboxes)
- [ ] Domain signals table present (9 rows)
- [ ] PERSPECTIVE block format present verbatim (Simple-tier inline rotation, under Stakeholder Perspectives)
- [ ] Stakeholder Perspectives points to `${CLAUDE_PLUGIN_ROOT}/reference/expert-index.md` and notes the Trivial tier carries zero mandatory stakeholders
- [ ] CONDUCTOR does NOT contain the spawn formats, handback formats, quality-gate item counts, or the model-selection table (those are validated in `reference/execution-protocol.md`, not here)

### Format String Accuracy
- [ ] All [EXACT] items that remain in CONDUCTOR (triage tables, self-check, circuit breaker, adaptive signals, domain signals, escalation guard, Simple-tier PERSPECTIVE block) reproduced character-for-character
- [ ] Thresholds match: Trivial (tier 0) / 0-1 Simple / 2-3 Moderate / 4 Complex scoring, 4+/5+ stakeholder escalation
- [ ] Moved [EXACT] items (handback anchor lines, quality-gate counts) are validated in `reference/execution-protocol.md`, not in CONDUCTOR

### Cross-References
- [ ] Generated CONDUCTOR.md contains ≥1 reference using `${CLAUDE_PLUGIN_ROOT}/` syntax for plugin-internal files (`agents/`, `reference/`, `skills/`, `templates/`, `hooks/`, `bin/`, `docs/`)
- [ ] Generated CONDUCTOR.md contains ZERO `~/.claude/` references (legacy adopter-HOME form is banned for plugin-internal paths)
- [ ] Generated CONDUCTOR.md contains ZERO bare relative plugin-internal paths (e.g., `` `agents/index.md` ``, `` `reference/stakeholder-guide.md` `` without the `${CLAUDE_PLUGIN_ROOT}/` prefix)
- [ ] References to `${CLAUDE_PLUGIN_ROOT}/reference/expert-index.md` present (roster/selection index; NOT `agents/index.md`)
- [ ] References to `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` present (the just-in-time load pointer in the Execution section)
- [ ] References to `${CLAUDE_PLUGIN_ROOT}/reference/` files present
- [ ] Any full-profile reference uses `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md`; compact-profile references (if any) use `${CLAUDE_PLUGIN_ROOT}/reference/compact/<name>.md` — NO `agents/*-compact.md`
- [ ] References to `.claude/BACKLOG.md` present (project-local — keep as-is, not plugin-internal)
- [ ] References to `oj-helper` commands present

---

## Dependencies

**Requires**: Step 00 complete (`platform-snapshot.yaml` available for model selection table rendering)

---

## Output

After completing this step, you will have:
- Plugin-tree-direct directory structure (`agents/`, `templates/`, `skills/`, `reference/` at plugin root)
- Slim manager protocol (`CONDUCTOR.md` at plugin root) carrying only the core sections; execution mechanics deferred to `reference/execution-protocol.md` (generated in step-04)

These outputs are required inputs for steps 02 and 03.
