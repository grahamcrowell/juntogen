# Generation Prompt: Step 06 — Skills

## Input

Read these specification files before generating:

1. **Primary spec**: `D56-commands-automation.md` — defines capabilities (Discover, Triage, Execute, Deliver, Learn), activation modes, 5-phase task lifecycle, seed commands. Each "command" in the spec corresponds to one **skill** in plugin form.
2. **Supporting specs**:
   - `D08-core-protocol.md` — manager role, delegation boundary
   - `D24-triage-engine.md` — two-dimensional triage (execution model + stakeholder identification)
   - `D32-execution-models.md` — Simple/Moderate/Complex execution patterns
   - `D40-quality-framework.md` — quality gates, handback protocol

Also examine the actual OpenJunto source files for reference. These are the canonical skill bodies in plugin form — read them to extract the prose, format strings, and protocol instructions for each skill:

- `{OJ_SOURCE}/skills/cycle/SKILL.md`        — backlog cycle protocol (the autonomous backlog runner)
- `{OJ_SOURCE}/skills/health-check/SKILL.md` — runtime health probe for the OpenJunto plugin install
- `{OJ_SOURCE}/skills/run-task/SKILL.md`     — execute a single backlog item through the 5-phase lifecycle
- `{OJ_SOURCE}/skills/save-session/SKILL.md` — persist session state before `/clear`
- `{OJ_SOURCE}/skills/show-backlog/SKILL.md` — display a concise read-only summary of the backlog

The pre-plugin form of these protocols lived at `~/.claude/commands/*.md` (legacy `run-task.md`, `save-session.md`, `show-backlog.md`). The plugin tree retains the same operational content but reshapes it into the SKILL.md contract documented below. New `cycle` and `health-check` skills have no pre-plugin command equivalent — read the `{OJ_SOURCE}` skill bodies for their canonical content.

## Task

Generate **5 skill files** in plugin form. The Claude plugin host loads skills from `skills/<name>/SKILL.md` (directory-per-skill, not flat-file). Create each file at the path specified below:

1. `skills/cycle/SKILL.md`        — autonomous backlog cycle skill
2. `skills/health-check/SKILL.md` — runtime health probe skill
3. `skills/run-task/SKILL.md`     — single-item task lifecycle skill
4. `skills/save-session/SKILL.md` — session-state persistence skill
5. `skills/show-backlog/SKILL.md` — read-only backlog summary skill

Each SKILL.md is a markdown instruction set with YAML frontmatter (not an executable script). The plugin host activates a skill when the user invokes its slash-command surface (`/cycle`, `/health-check`, `/run-task`, `/save-session`, `/show-backlog`). Each skill defines a protocol — step-by-step instructions with decision points, constraints, and fallback behaviors that Claude follows when activated.

### Skill file contract (REQUIRED for every file)

The Claude plugin host enforces this contract — files that do not meet it are silently skipped at install time:

1. **Path**: `skills/<name>/SKILL.md` (directory-per-skill layout, NOT flat `skills/<name>.md`). The directory name `<name>` is the skill identifier and must match its slash-command surface (e.g., `skills/cycle/SKILL.md` → `/cycle`).
2. **YAML frontmatter**: Each file MUST begin with a YAML frontmatter block delimited by `---` on the first and (typically) third line. The block MUST contain a `description:` field. This is empirically confirmed by `{OJ_SOURCE}/skills/cycle/SKILL.md:1-3` — the live plugin baseline. Missing or empty `description:` fields cause the host to skip the skill silently.
3. **Body**: Markdown prose with headings, code blocks, and structured protocol instructions. Body MUST have more than 5 lines (verify_step_06 asserts this).
4. **Cross-reference convention**: When referencing plugin-tree files from skill bodies, use `${CLAUDE_PLUGIN_ROOT}/<subdir>/<file>` (the plugin host expands `${CLAUDE_PLUGIN_ROOT}` at runtime to the install root). This contract matches the `{OJ_SOURCE}/skills/cycle/SKILL.md` baseline; the structural-diff Layer 4 check resolves these references against the live plugin tree.

## Key Requirements

### 1. cycle skill — `skills/cycle/SKILL.md`

**Purpose**: Execute the autonomous backlog cycle as a multi-item loop within a single invocation — read context, then repeatedly (a) load backlog and select the highest-priority unblocked item, (b) triage, (c) plan stakeholder engagement, (d) execute, (e) test, (f) commit with per-item clean-tree verification, (g) update backlog, (h) brief per-item retrospective — re-entering the loop on the next highest-priority unblocked item until a budget/safety gate trips. Each iteration commits atomically per item; the loop never advances to a new item with a dirty working tree. At end of invocation, store artifacts, run a per-invocation dev-mode feedback write, and notify.

**YAML frontmatter** (verbatim):
```yaml
---
description: Execute the autonomous backlog cycle — triage, delegate, review, test, commit, retrospect
---
```

**Body**: Reproduce the protocol structure from `{OJ_SOURCE}/skills/cycle/SKILL.md`:

- 11-step protocol headed by "Cycle Protocol" section with subsections "Step 1 — Read Context" through "Step 11 — Notify"
- Two-dimensional triage section reproducing the 4-criterion checklist (Execution Model A) and stakeholder identification (B), with the escalation guard
- Execution-model branches: Simple (inline perspective rotation), Moderate (3-phase Task tool engagement), Complex (parallel team via Convene primitive, with teardown via the platform's team-disposal call — `shutdown_request` to each teammate then TeamDelete on the team handle)
- **Complex fallback (Convene→Consult, Axiom 8)**: the generated Complex branch MUST instruct the skill — after tier classification confirms Complex — to invoke `oj-helper agent-teams-check`, parse `.available` from stdout, and:
  - when `.available == true`: proceed with TeamCreate exactly as the existing Complex branch describes.
  - when `.available == false`: follow the deputy-coordinator parallel-Consult fan-out pattern documented in `juntospec/D32-execution-models.md` §3 Fallback — spawn ONE general-purpose deputy coordinator via the Task tool, brief it with the full stakeholder plan, have it spawn the stakeholder analyses as parallel Task-tool calls, and synthesize via the handback protocol only (no SendMessage / Inform — that primitive is gated by the same capability as Convene). User Checkpoint, pre-mortem, and adversarial review remain mandatory. NO TeamCreate, NO TeamDelete, NO `shutdown_request` in this branch (those tools are unavailable when the probe reports `available:false`).
  - The skill MUST treat the probe's exit code as informational only: `agent-teams-check` always exits 0 (it is a report, not a gate); the branch selector reads `.available` from JSON.
  - **Runtime backstop (probe is a hint, not a guarantee)**: the generated Complex branch MUST further instruct the skill that `agent-teams-check` inspects only the env var, so an environment where the var is set but `TeamCreate` is actually disabled at runtime (enterprise policy, future flag retirement) will steer the skill onto the team branch incorrectly. If the team branch is taken and the first `TeamCreate` call — or any agent-teams-gated tool (`TeamCreate`, `TeamDelete`, `SendMessage`, `shutdown_request`) — raises "Unknown tool" / "tool unavailable" at runtime, the skill MUST NOT abort the loop iteration; it MUST fall through to the deputy-coordinator parallel-Task-tool fan-out (handback-only synthesis, no Inform). The runtime signal is authoritative over the probe; the User Checkpoint promised at triage MUST still fire before the iteration commits.
- PERSPECTIVE block format reproduced verbatim
- Dev-mode feedback step invoking `oj-helper feedback-path` with the timestamped feedback-file format
- Constraints section: multi-item loop semantics with a per-iteration single-item scope (one item per loop iteration, NOT one item per cycle invocation); atomic per-item commits with Step-7a clean-tree gate BEFORE the loop advances; stop on blocking review; ask when blocked; explicit budget/safety-gate stop conditions (token/context budget low, next item triages Complex, irreversible / one-way-door action required, user-only decision reached) — the runner surfaces control to the user when any of these trip
- Cycle-vs-run-task asymmetry directive: the cycle skill LOOPS over multiple items per invocation under the budget/safety-gate stop; the run-task skill does NOT loop — it executes exactly one item per invocation. Generators MUST NOT copy cycle-skill multi-item language into run-task, and MUST NOT copy run-task single-invocation language into cycle. Loop & Stop Conditions belong only in the cycle skill body.

Cross-references must use `${CLAUDE_PLUGIN_ROOT}/agents/index.md`, `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`, `${CLAUDE_PLUGIN_ROOT}/agents/*-compact.md` (flat plugin layout — NOT `agents/compact/*`).

### 2. health-check skill — `skills/health-check/SKILL.md`

**Purpose**: Empirical runtime probe of the OpenJunto plugin install. Invokes real `oj-helper` subprocesses, captures stdout/stderr/exit codes, reports liveness rather than file-layout structure. Distinguishes broken wiring from misconfigured environment.

**YAML frontmatter** (verbatim):
```yaml
---
name: health-check
description: Diagnose OpenJunto plugin runtime health — verify CONDUCTOR.md injection, oj-helper availability, jq dependency, plugin manifest, SubagentStart hook wiring.
---
```

(Note: this is the only skill whose frontmatter includes an explicit `name:` field. The host derives `name` from the directory when absent; the explicit form is preserved for the health-check baseline.)

**Body**: Reproduce the 5-probe runtime protocol from `{OJ_SOURCE}/skills/health-check/SKILL.md`:

- Probe 1: CONDUCTOR.md injection via `oj-helper conductor-inject` — assertions on exit code, JSON hookSpecificOutput shape, and the OJ_STDERR_CONDUCTOR_MISSING advisory string
- Probe 2: oj-helper on PATH + executable
- Probe 3: jq dependency
- Probe 4: plugin manifest (`.claude-plugin/plugin.json` parse + key presence)
- Probe 5: SubagentStart hook wiring (`hooks/hooks.json` matcher inspection)

Final summary line: `HEALTH: OK` if every probe meets its assertion, otherwise `HEALTH: DEGRADED — <comma-separated probe IDs that failed>`.

### 3. run-task skill — `skills/run-task/SKILL.md`

**Purpose**: Execute one backlog item end-to-end through the 5-phase task lifecycle (Discover, Triage, Execute, Deliver, Learn). The manager coordinates expert agents per the delegation boundary; this skill does not relax that constraint.

**YAML frontmatter** (verbatim):
```yaml
---
description: Execute a single backlog item end-to-end through the 5-phase task lifecycle
---
```

**Body**: Reproduce the 5-phase protocol from `{OJ_SOURCE}/skills/run-task/SKILL.md`:

- Phase 1 — Initialize (Discover): Backlog source detection via `oj-helper issue-tracker-check`, exit-code + JSON parse to determine issue-tracker mode vs. BACKLOG.md mode; read context from `.claude/CLAUDE.md`; load backlog
- Phase 2 — Classify (Triage): 4-criterion execution model + stakeholder identification with the escalation guard; mandatory escalation triggers (security/regulatory/production-stability/irreversible); confirm tier with user via the platform's interactive-question primitive; issue-tracker transition to "In Progress" (issue-tracker mode only)
- Phase 3 — Plan & Execute: Stakeholder engagement plan; execution by tier (Simple inline / Moderate 3-phase / Complex Convene). **Complex fallback (Convene→Consult, Axiom 8)**: the generated Complex branch MUST invoke `oj-helper agent-teams-check` after tier classification confirms Complex, parse `.available` from the JSON stdout, and branch — `.available == true` proceeds with TeamCreate, `.available == false` follows the deputy-coordinator parallel-Consult fan-out (one general-purpose deputy spawned via Task tool, briefed with the full stakeholder plan; fans out parallel Task-tool Consults; handback-only synthesis — no SendMessage / Inform, no TeamCreate, no TeamDelete). User Checkpoint, pre-mortem, and adversarial review remain mandatory. The probe always exits 0; the branch selector reads `.available` from JSON, not the exit code. **Runtime backstop**: the generated branch MUST also instruct the skill that `agent-teams-check` inspects only the env var, so an environment where the var is set but `TeamCreate` is actually disabled at runtime (enterprise policy, future flag retirement) will steer onto the team branch incorrectly; if the team branch is taken and the first `TeamCreate` call — or any agent-teams-gated tool (`TeamCreate`, `TeamDelete`, `SendMessage`, `shutdown_request`) — raises "Unknown tool" / "tool unavailable" at runtime, the skill MUST NOT abort the task; it MUST fall through to the deputy-coordinator parallel-Task-tool fan-out (handback-only synthesis, no Inform). The runtime signal is authoritative over the probe; the User Checkpoint promised at triage MUST still fire before Phase 4.
- Phase 4 — Deliver: Test, commit (no Co-Authored-By lines, no AI attribution), git-status verification gate, update backlog (issue-tracker or BACKLOG.md mode)
- Phase 5 — Learn: Retrospective, dev-mode feedback path via `oj-helper feedback-path`, artifacts to `.claude/artifacts/`, notify user

Constraints section (stated INDEPENDENTLY of the cycle skill — do NOT reuse cycle-skill multi-item loop language here): exactly one backlog item per invocation (run-task does NOT loop); atomic commits; do not proceed past blocking peer review; stop and ask when blocked or uncertain; issue tracker failures are non-blocking. Reentry on the next item requires a fresh user invocation of run-task.

Cross-references use `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md`, `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`, `.claude/CLAUDE.md` (the user's project-local manager protocol).

### 4. save-session skill — `skills/save-session/SKILL.md`

**Purpose**: Persist session state before `/clear` so context carries into the next session. All proposed changes are presented to the user for **approval before writing** — this skill never auto-writes.

**YAML frontmatter** (verbatim):
```yaml
---
description: Persist session state and compress carry-over before /clear; requires user approval before writing
---
```

**Body**: Reproduce the 7-step protocol from `{OJ_SOURCE}/skills/save-session/SKILL.md`:

- Step 1 — Read Current State: `.claude/state/session.md` (if exists), `.claude/CLAUDE.md`; offer to create from template at `${CLAUDE_PLUGIN_ROOT}/templates/session-state.md` if missing
- Step 2 — Scan Working State: `git status` per repo (multi-repo aware); record branch + dirty/clean status
- Step 3 — Check In-Flight PRs: `gh pr view` for each listed PR; update status fields
- Step 4 — Verify Backlog Consistency: read `.claude/BACKLOG.md`, check header count, flag "Blocked By" → completed-item unblock candidates
- Step 5 — Check for Unprocessed Input: scan repo root for `tasks.md`, `notes.md`, `TODO.md`
- Step 6 — Draft Session Update: compose updated `state/session.md` with session number, date, In-Flight PRs, workspace state, carry-over compression rules (older than 2 sessions → single-line; older than 14 days → drop)
- Step 7 — Present and Apply: present diff-style summary, apply only after user approval

Constraints: approval required, non-destructive, graceful degradation, no network calls beyond git/gh.

Cross-references use `${CLAUDE_PLUGIN_ROOT}/templates/session-state.md`, `.claude/CLAUDE.md`.

### 5. show-backlog skill — `skills/show-backlog/SKILL.md`

**Purpose**: Display a concise read-only summary of the current backlog state. Read-only — no modifications, no transitions, no work started.

**YAML frontmatter** (verbatim):
```yaml
---
description: Display a read-only summary of the current backlog grouped by priority
---
```

**Body**: Reproduce the 3-step protocol from `{OJ_SOURCE}/skills/show-backlog/SKILL.md`:

- Step 1 — Backlog source detection (identical to /run-task)
- Step 2 — Load backlog items via `oj-helper issue-tracker-list --project PROJECT_KEY` (issue-tracker mode) OR markdown parse of `.claude/BACKLOG.md` (BACKLOG.md mode)
- Step 3 — Present summary: header (source + total open count), items grouped by priority with ID / Title / Status, omit empty priority groups, highlight next-cycle candidate (single highest-priority unblocked item; tiebreak by oldest creation date)

Constraints: read-only, concise output, empty-backlog handling.

Cross-references use `/run-task` for the full task lifecycle that consumes the backlog and `.claude/CLAUDE.md` for project-specific backlog conventions.

## Format Requirements

Each SKILL.md must:

1. **Start with YAML frontmatter** delimited by `---` on line 1 and `---` after the description field. The `description:` field is REQUIRED (the plugin host scans for it and skips skills that lack it). Quoting is optional — the live baseline uses both quoted and unquoted forms.
2. **Use consistent heading levels** — `#` for the skill title (e.g., `# /run-task`), `##` for major sections (Protocol, Constraints, Format Notes), `###` for steps or phases.
3. **Use fenced code blocks** with triple backticks for command examples and verbatim format strings.
4. **Use blockquotes** (`>`) for important notes and cross-references to other plugin-tree files.
5. **Use bold text** (`**`) for critical requirements and constraints.
6. **Brand Identity**: Use **"OpenJunto"** as the product/system name in all user-facing prose. Do NOT emit bare "Junto" as a product name (preserved only in historical references to Franklin's Junto). Technical identifiers use the lowercase `oj-` prefix (`oj-helper`, `oj-expert`, `OJ_DEVMODE`, `${CLAUDE_PLUGIN_ROOT}`) and MUST be preserved verbatim — these are part of the tool contract. Legacy `junto-*` identifier forms are accepted by the helper for one release as backward-compat fallbacks.
7. **Plugin-tree references** use `${CLAUDE_PLUGIN_ROOT}/<subdir>/<file>` for files inside the plugin install (NOT `~/.claude/...` — that path form is reserved for user-installed CLAUDE.md and per-user configuration). Reference `${CLAUDE_PLUGIN_ROOT}/agents/*-compact.md` for compact profiles (flat layout — NOT `agents/compact/*.md`).
8. **Body length** must exceed 5 lines (`verify_step_06` asserts this; an empty or near-empty skill is treated as a generation failure).

## Verification

After generation, verify each SKILL.md:

1. **Path**: file exists at `skills/<name>/SKILL.md` (directory-per-skill, not flat). All 5 directories present: `skills/cycle/`, `skills/health-check/`, `skills/run-task/`, `skills/save-session/`, `skills/show-backlog/`.
2. **Frontmatter**: file begins with `---` on line 1, contains a `description:` line, closes with `---` before the body.
3. **Body**: more than 5 lines of markdown content after the frontmatter.
4. **Phase/step completeness**: each skill reproduces the steps documented in the corresponding `{OJ_SOURCE}/skills/<name>/SKILL.md` baseline.
5. **Decision logic**: backlog source detection logic appears identical in both /run-task and /show-backlog (both call `oj-helper issue-tracker-check` and parse exit code + JSON `.project` field).
6. **Format strings**: PERSPECTIVE block format, feedback-file format, and the `HEALTH: OK | DEGRADED — ...` summary line match the baselines verbatim.
7. **Cross-references**: every `${CLAUDE_PLUGIN_ROOT}/<subdir>/<file>` reference points to a file the plugin tree will actually contain (the structural-diff Layer 4 check resolves these against the live tree).
8. **No legacy paths**: no `~/.claude/commands/`, no legacy `src/`-rooted output forms (commands previously lived under that wrapper; they now live in plugin-tree-direct `skills/` directories), no nested `agents/compact/` subdirectory (the flat `*-compact.md` suffix replaces it).

## Dependencies

- **Step 01** (CONDUCTOR.md) must be complete — defines two-dimensional triage, execution models, quality gates referenced by each skill body
- **Step 04** (reference files) must be complete — skills cross-reference `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`, `workflow-stages.md`
- **Step 05** (templates) must be complete — skills cross-reference `${CLAUDE_PLUGIN_ROOT}/templates/session-state.md`, `retrospective.md`
- **Step 07** (oj-helper script) must be complete — skills invoke `oj-helper` subcommands (`issue-tracker-check`, `issue-tracker-list`, `issue-tracker-transition`, `feedback-path`, `conductor-inject`)
