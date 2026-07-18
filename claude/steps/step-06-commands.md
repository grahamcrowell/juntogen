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
- `{OJ_SOURCE}/skills/spec/SKILL.md`         — front-half authoring (reqs/design/plan/refresh) + backlog graduation
- `{OJ_SOURCE}/skills/backlog-compact/SKILL.md` — size-triggered backlog compaction (pin to a git blob, then rewrite active items into the compact single-sourced schema)
- `{OJ_SOURCE}/skills/workstream-new/SKILL.md` — scaffold a parallel-workstream execution thread (git worktree + symlinked shared state) via the `oj-helper workstream-new` subcommand

The pre-plugin form of these protocols lived at `~/.claude/commands/*.md` (legacy `run-task.md`, `save-session.md`, `show-backlog.md`). The plugin tree retains the same operational content but reshapes it into the SKILL.md contract documented below. New `cycle`, `health-check`, `backlog-compact`, and `workstream-new` skills have no pre-plugin command equivalent — read the `{OJ_SOURCE}` skill bodies for their canonical content.

## Task

Generate **8 skill files** in plugin form. The Claude plugin host loads skills from `skills/<name>/SKILL.md` (directory-per-skill, not flat-file). Create each file at the path specified below:

1. `skills/cycle/SKILL.md`        — autonomous backlog cycle skill
2. `skills/health-check/SKILL.md` — runtime health probe skill
3. `skills/run-task/SKILL.md`     — single-item task lifecycle skill
4. `skills/save-session/SKILL.md` — session-state persistence skill
5. `skills/show-backlog/SKILL.md` — read-only backlog summary skill
6. `skills/spec/SKILL.md`         — front-half authoring + backlog graduation skill
7. `skills/backlog-compact/SKILL.md` — size-triggered backlog compaction skill
8. `skills/workstream-new/SKILL.md` — parallel-workstream scaffolding skill

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
disable-model-invocation: true
---
```

`disable-model-invocation: true` is REQUIRED on `cycle` — it is a side-effecting skill (commits, backlog mutation, retrospectives) and must only run when the user explicitly invokes `/cycle`, never on model-initiated invocation.

**Body**: Reproduce the protocol structure from `{OJ_SOURCE}/skills/cycle/SKILL.md`:

- 11-step protocol headed by "Cycle Protocol" section with subsections "Step 1 — Read Context" through "Step 11 — Notify"
- Two-dimensional triage section reproducing the 4-criterion checklist (Execution Model A) and stakeholder identification (B), with the escalation guard. **Trivial fast-path (tier 0, Item 2)**: the reproduced triage MUST include the tier-0 Trivial branch matching CONDUCTOR — a request is Trivial when it is typo-scale, involves NO design choices, AND its causal chain terminates before production; a Trivial item carries ZERO mandatory stakeholders and the manager executes it inline (no Product + Distinguished pair spawned). The mandatory Product Manager + Distinguished Engineer pair applies at Simple and above (any request that is not Trivial). Emit the tier-0 branch in the cycle's triage reproduction and its scoring ladder (Trivial → 0-1 Simple → 2-3 Moderate → 4 Complex).
- Execution-model branches: Simple (inline perspective rotation), Moderate (3-phase Task tool engagement), Complex (parallel team via Convene primitive, with teardown via the platform's team-disposal call — `shutdown_request` to each teammate then TeamDelete on the team handle)
- **Per-spawn `model` directive (Moderate + Complex branches)**: BOTH the Moderate (3-phase) branch and the Complex branch MUST instruct the skill to set the Task tool `model` parameter on every spawn per `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` § Agent Spawning + Model Selection. Emit a terse blockquote at each branch that names the function rules concretely (Moderate: Phase-1 analysts → `sonnet`; Phase-2 lead → `opus[1m]`, escalate to `fable` for high-risk / unresolved TENSION; Phase-3 adversarial reviewer → always `fable`. Complex: lead → `fable`; adversarial reviewer slot → always `fable`; deputy coordinator → `opus[1m]`, escalate to `fable` if it carries synthesis weight; stakeholder analysts → `sonnet`; specialists on a domain trigger → `opus[1m]`, escalate to `fable` when the domain is the decisive risk). Point readers to `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` § Agent Spawning + Model Selection for the per-role default fallback table; do NOT duplicate the full table in the skill body.
- **Complex fallback (Convene→Consult, Axiom 8)**: the generated Complex branch MUST instruct the skill — after tier classification confirms Complex — to invoke `oj-helper agent-teams-check`, parse `.available` from stdout, and:
  - when `.available == true`: proceed with TeamCreate exactly as the existing Complex branch describes.
  - when `.available == false`: follow the deputy-coordinator parallel-Consult fan-out pattern documented in `juntospec/D32-execution-models.md` §3 Fallback — spawn ONE general-purpose deputy coordinator via the Task tool, brief it with the full stakeholder plan, have it spawn the stakeholder analyses as parallel Task-tool calls, and synthesize via the handback protocol only (no SendMessage / Inform — that primitive is gated by the same capability as Convene). User Checkpoint, pre-mortem, and adversarial review remain mandatory. NO TeamCreate, NO TeamDelete, NO `shutdown_request` in this branch (those tools are unavailable when the probe reports `available:false`).
  - The skill MUST treat the probe's exit code as informational only: `agent-teams-check` always exits 0 (it is a report, not a gate); the branch selector reads `.available` from JSON.
  - **Runtime backstop (probe is a hint, not a guarantee)**: the generated Complex branch MUST further instruct the skill that `agent-teams-check` inspects only the env var, so an environment where the var is set but `TeamCreate` is actually disabled at runtime (enterprise policy, future flag retirement) will steer the skill onto the team branch incorrectly. If the team branch is taken and the first `TeamCreate` call — or any agent-teams-gated tool (`TeamCreate`, `TeamDelete`, `SendMessage`, `shutdown_request`) — raises "Unknown tool" / "tool unavailable" at runtime, the skill MUST NOT abort the loop iteration; it MUST fall through to the deputy-coordinator parallel-Task-tool fan-out (handback-only synthesis, no Inform). The runtime signal is authoritative over the probe; the User Checkpoint promised at triage MUST still fire before the iteration commits.
- PERSPECTIVE block format reproduced verbatim
- **Reviewer scope (Item 3)**: in the Moderate (Phase-3) and Complex adversarial-review steps, the reviewer flags ONLY correctness/requirements-affecting gaps; "no material concerns" is an acceptable review outcome at all tiers (do NOT force the reviewer to manufacture an objection). The mandatory **FAILURE MODES TESTED** section requirement is retained regardless of verdict — a clean review must still document the failure modes probed. Point to `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md` (adversarial review protocol) for the full output format rather than duplicating it.
- Dev-mode feedback step invoking `oj-helper feedback-path` with the timestamped feedback-file format
- Constraints section: multi-item loop semantics with a per-iteration single-item scope (one item per loop iteration, NOT one item per cycle invocation); atomic per-item commits with Step-7a clean-tree gate BEFORE the loop advances; stop on blocking review; ask when blocked; explicit budget/safety-gate stop conditions (token/context budget low, next item triages Complex, irreversible / one-way-door action required, user-only decision reached) — the runner surfaces control to the user when any of these trip
- Cycle-vs-run-task asymmetry directive: the cycle skill LOOPS over multiple items per invocation under the budget/safety-gate stop; the run-task skill does NOT loop — it executes exactly one item per invocation. Generators MUST NOT copy cycle-skill multi-item language into run-task, and MUST NOT copy run-task single-invocation language into cycle. Loop & Stop Conditions belong only in the cycle skill body.

Cross-references must use `${CLAUDE_PLUGIN_ROOT}/reference/expert-index.md` (the relocated roster index — NOT `agents/index.md`), `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`, and `${CLAUDE_PLUGIN_ROOT}/reference/compact/<name>.md` for compact profiles (NOT `agents/*-compact.md`, NOT `agents/compact/*`). Full profiles are `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md`.

### 2. health-check skill — `skills/health-check/SKILL.md`

**Purpose**: Empirical runtime probe of the OpenJunto plugin install. Invokes real `oj-helper` subprocesses, captures stdout/stderr/exit codes, reports liveness rather than file-layout structure. Distinguishes broken wiring from misconfigured environment.

**YAML frontmatter** (verbatim):
```yaml
---
name: health-check
description: Diagnose OpenJunto plugin runtime health — verify CONDUCTOR.md injection, oj-helper availability, jq dependency, plugin manifest, SubagentStart hook wiring.
allowed-tools: [Bash, Read, Grep, Glob]
context: fork
---
```

(Note: this is the only skill whose frontmatter includes an explicit `name:` field. The host derives `name` from the directory when absent; the explicit form is preserved for the health-check baseline.)

`health-check` is a read-only diagnostic (it runs `oj-helper` probes and inspects files, but makes no changes), so it gets `allowed-tools: [Bash, Read, Grep, Glob]` — a read-only tool set sufficient for the 5 probes (Bash to run `oj-helper` subprocesses and `jq`, Read/Grep/Glob to inspect the manifest and hooks wiring) and NO write/edit tools — and `context: fork` so the diagnostic runs in a forked context without polluting the main session.

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
disable-model-invocation: true
---
```

`disable-model-invocation: true` is REQUIRED on `run-task` — it is a side-effecting skill (commits, backlog mutation) and must only run on explicit `/run-task` invocation.

**Body**: Reproduce the 5-phase protocol from `{OJ_SOURCE}/skills/run-task/SKILL.md`:

- Phase 1 — Initialize (Discover): Backlog source detection via `oj-helper issue-tracker-check`, exit-code + JSON parse to determine issue-tracker mode vs. BACKLOG.md mode; read context from `.claude/CLAUDE.md`; load backlog
- Phase 2 — Classify (Triage): 4-criterion execution model + stakeholder identification with the escalation guard; mandatory escalation triggers (security/regulatory/production-stability/irreversible); confirm tier with user via the platform's interactive-question primitive; issue-tracker transition to "In Progress" (issue-tracker mode only). **Trivial fast-path (tier 0, Item 2)**: the reproduced triage MUST include the tier-0 Trivial branch matching CONDUCTOR — Trivial = typo-scale, no design choices, causal chain terminates before production; zero mandatory stakeholders, execute inline. The mandatory Product Manager + Distinguished Engineer pair applies at Simple and above. Emit the tier-0 branch in run-task's triage reproduction and its scoring ladder (Trivial → 0-1 Simple → 2-3 Moderate → 4 Complex).
- Phase 3 — Plan & Execute: Stakeholder engagement plan; execution by tier (Simple inline / Moderate 3-phase / Complex Convene). **Per-spawn `model` directive (Moderate + Complex branches)**: BOTH the Moderate (3-phase) branch and the Complex branch MUST instruct the skill to set the Task tool `model` parameter on every spawn per `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` § Agent Spawning + Model Selection. Emit a terse blockquote at each branch that names the function rules concretely (Moderate: Phase-1 analysts → `sonnet`; Phase-2 lead → `opus[1m]`, escalate to `fable` for high-risk / unresolved TENSION; Phase-3 adversarial reviewer → always `fable`. Complex: lead → `fable`; adversarial reviewer slot → always `fable`; deputy coordinator → `opus[1m]`, escalate to `fable` if it carries synthesis weight; stakeholder analysts → `sonnet`; specialists on a domain trigger → `opus[1m]`, escalate to `fable` when the domain is the decisive risk). Point readers to `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` § Agent Spawning + Model Selection for the per-role default fallback table; do NOT duplicate the full table in the skill body. **Complex fallback (Convene→Consult, Axiom 8)**: the generated Complex branch MUST invoke `oj-helper agent-teams-check` after tier classification confirms Complex, parse `.available` from the JSON stdout, and branch — `.available == true` proceeds with TeamCreate, `.available == false` follows the deputy-coordinator parallel-Consult fan-out (one general-purpose deputy spawned via Task tool, briefed with the full stakeholder plan; fans out parallel Task-tool Consults; handback-only synthesis — no SendMessage / Inform, no TeamCreate, no TeamDelete). User Checkpoint, pre-mortem, and adversarial review remain mandatory. The probe always exits 0; the branch selector reads `.available` from JSON, not the exit code. **Runtime backstop**: the generated branch MUST also instruct the skill that `agent-teams-check` inspects only the env var, so an environment where the var is set but `TeamCreate` is actually disabled at runtime (enterprise policy, future flag retirement) will steer onto the team branch incorrectly; if the team branch is taken and the first `TeamCreate` call — or any agent-teams-gated tool (`TeamCreate`, `TeamDelete`, `SendMessage`, `shutdown_request`) — raises "Unknown tool" / "tool unavailable" at runtime, the skill MUST NOT abort the task; it MUST fall through to the deputy-coordinator parallel-Task-tool fan-out (handback-only synthesis, no Inform). The runtime signal is authoritative over the probe; the User Checkpoint promised at triage MUST still fire before Phase 4. **Reviewer scope (Item 3)**: the Moderate Phase-3 and Complex adversarial-review steps instruct the reviewer to flag ONLY correctness/requirements-affecting gaps; "no material concerns" is an acceptable outcome at all tiers, and the mandatory FAILURE MODES TESTED section is retained regardless of verdict. Point to `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md` for the full review output format.
- Phase 4 — Deliver: Test, commit (no Co-Authored-By lines, no AI attribution), git-status verification gate, update backlog (issue-tracker or BACKLOG.md mode)
- Phase 5 — Learn: Retrospective, dev-mode feedback path via `oj-helper feedback-path`, artifacts to `.claude/artifacts/`, notify user
- **Verification-command execution as evidence (Phase 4 Test / Step 6 Test)**: generators MUST emit the verification-command-execution behavior into BOTH the run-task Phase-4 Test subsection AND the cycle Step-6 Test subsection. The emitted prose MUST instruct the skill to: (1) execute the selected item's graduated verification command verbatim - the command written into the item's acceptance by graduation (D56 § Backlog Graduation field mapping + the graduation INVARIANT); (2) report the command invoked plus its actual output / exit code as the evidence of completion, never a bare "tests pass" assertion; (3) run the item's verification command FIRST, then the existing balanced-suite / no-regressions check second, with both appearing in the evidence (ADD, do not replace); (4) treat a non-zero exit as a hard block on the commit - stop and surface to the user via the existing stop-and-ask-if-blocked-or-uncertain constraint, do NOT rationalize the failure and proceed; (5) when the item carries no verification command, fall back to the balanced-suite / no-regressions check and state explicitly that no item-specific verification command was present. This consumer half pairs with the graduation producer half in step-05 / D56; without this directive a regen would silently revert the two SKILL.md Test edits. Preserve process-noun hygiene per the directive below (run-task says "invocation"/"task", cycle says "THIS item").

- **Live-state reconciliation at kickoff (Phase 3 top / Step 4 top)**: this directive is the deliberate paired bookend of the "Verification-command execution as evidence" directive above - that one is the EXIT gate at Deliver (verify the item's definition-of-done before commit); this one is the ENTRY gate to Execute (re-verify the item's cited live state before any planning or code). Generators MUST emit the reconciliation behavior into BOTH the run-task Phase-3 top (a new `#### Reconcile Live State` subsection placed BEFORE `#### Plan Stakeholder Engagement`) AND the cycle Step-4 top (folded in as the FIRST content of `### Step 4 — Plan Stakeholder Engagement`, scoped "for THIS item"). The emitted prose MUST instruct the skill to: (1) determine whether the selected item cites live external state - a `Source:` back-reference to an originating plan task, references to external artifacts with an independent lifecycle (reviewable changes / prior work products / external resources / tickets / commits), or a `Blocked By` dependency on another item; (2) when it cites external state, re-verify each cited reference against current reality before stakeholder-engagement planning begins - for cited reviewable changes use the platform's change-state query (e.g. `gh pr view <n> --json state,mergedAt,mergeable`, reusing the pattern save-session already uses), for a `Blocked By` predecessor re-read its backlog status, for a cited file/resource run a targeted existence/shape check, and for a `Source:` plan task diff the plan task against the graduated item; (3) report for each reconciliation: what was cited (or "nothing cited"), the exact check run, a verdict of `CURRENT` | `DRIFTED` | `UNCHECKABLE`, and the action taken; (4) on `DRIFTED` (cited change merged/closed, dependency actually still open, resource gone/changed, plan task diverged) STOP and surface to the user rather than proceeding on the stale premise and rather than auto-adjusting - tie this to the existing "stop and ask if blocked or uncertain" constraint, and for cycle present it as a concrete instance of the existing gate 4 (User-only decision), "a decision only the user can make", stop condition in the Loop & Stop Conditions block (do NOT add a new numbered stop-gate); (5) treat `UNCHECKABLE` (e.g. the check tool is unreachable) as non-blocking but state it explicitly, matching the existing "issue tracker failures are non-blocking" pattern; (6) when the item cites nothing external, state explicitly "no live-state cited - reconciliation is a no-op" rather than omitting the step or emitting a hollow always-passes check. Without this directive a regen would silently drop the two SKILL.md Reconcile-Live-State edits. Preserve process-noun hygiene per the directive below (run-task says "invocation"/"task" and reserves "cycle" for the sibling `/cycle` command; cycle says "THIS item").
- **Cross-reference refresh at Update Backlog (Deliver single-source enforcement)**: the write-side companion to the § Backlog Item Schema single-source discipline (D56). Generators MUST emit this behavior into BOTH the run-task Phase-4 `#### Update Backlog` (BACKLOG.md-mode sub-bullets) AND the cycle Step-8 `Update Backlog`. The emitted prose MUST instruct the skill to: (1) stamp any `Status` line it writes or touches that asserts external state (a PR/branch/ticket) with `verified <today>` — an un-dated external-state assertion is unverified by construction; (2) when the delivered item changed the state of a PR, branch, or ticket the backlog references, grep the resolved backlog (and `session.md` if present) for EVERY other mention of that token — `grep -n "<pr-number-or-ticket-key>" <backlog-file> session.md` — and refresh every hit within the same commit (run-task: this invocation's commit; cycle: THIS item's per-item commit), not just the item the work started from, because a fact about an external artifact's state lives in exactly one place (the owning item's `Status` line) and every other table references it by id; (3) tie this to D56 § Backlog Item Schema (single-source INVARIANT) and the Phase-4 Deliver cross-reference-refresh OBSERVABLE. Without this directive a regen would silently drop the two SKILL.md Update-Backlog edits. Preserve process-noun hygiene (run-task says "invocation"/"task"; cycle says "THIS item").
- **Process-noun consistency (run-task is single-shot, NOT a cycle)**: across ALL run-task sub-sections — the Phase-4 verification gate, and the Phase-5 Feedback, Artifacts, and Notify sub-sections — generators MUST refer to run-task's OWN process as an "invocation" / "run-task" / "task lifecycle", NEVER as a "cycle". The word "cycle" in run-task is reserved exclusively for referencing the sibling `/cycle` command (the multi-item loop); it MUST NOT name run-task's own single-shot process. Concretely: "during this run-task invocation" (not "during the cycle"); "Each run-task invocation produces exactly one new file" (not "Each cycle produces…"); "the run-task is complete … the next run-task invocation" (not "the cycle is complete … the next cycle"); "mid-run" / "mid-invocation" (not "mid-cycle"). This complements the Constraints directive below and the cycle-vs-run-task asymmetry directive in the cycle-skill section — keep the live artifact and a regen in agreement.

Constraints section (stated INDEPENDENTLY of the cycle skill — do NOT reuse cycle-skill multi-item loop language here): exactly one backlog item per invocation (run-task does NOT loop); atomic commits; do not proceed past blocking peer review; stop and ask when blocked or uncertain; issue tracker failures are non-blocking. Reentry on the next item requires a fresh user invocation of run-task.

Cross-references use `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md`, `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`, `.claude/CLAUDE.md` (the user's project-local manager protocol).

### 4. save-session skill — `skills/save-session/SKILL.md`

**Purpose**: Persist session state before `/clear` so context carries into the next session. All proposed changes are presented to the user for **approval before writing** — this skill never auto-writes.

**YAML frontmatter** (verbatim):
```yaml
---
description: Persist session state and compress carry-over before /clear; requires user approval before writing
disable-model-invocation: true
---
```

`disable-model-invocation: true` is REQUIRED on `save-session` — it writes session state (only after user approval, but still a side-effecting persistence skill) and must only run on explicit `/save-session` invocation.

**Body**: Reproduce the 7-step protocol (plus the cadence-gated Step 4b) from `{OJ_SOURCE}/skills/save-session/SKILL.md`:

- Step 1 — Read Current State: `.claude/state/session.md` (if exists), `.claude/CLAUDE.md`; offer to create from template at `${CLAUDE_PLUGIN_ROOT}/templates/session-state.md` if missing
- Step 2 — Scan Working State: `git status` per repo (multi-repo aware); record branch + dirty/clean status
- Step 3 — Check In-Flight PRs: `gh pr view` for each listed PR; update status fields
- Step 4 — Verify Backlog Consistency: read `.claude/BACKLOG.md`, check header count, flag "Blocked By" → completed-item unblock candidates, AND run the **self-consistency scan** (see directive below)
- Step 4b — Reconcile External State (cadence-gated): see directive below
- Step 5 — Check for Unprocessed Input: scan repo root for `tasks.md`, `notes.md`, `TODO.md`
- Step 6 — Draft Session Update: compose updated `state/session.md` with session number, date, In-Flight PRs, workspace state, carry-over compression rules (older than 2 sessions → single-line; older than 14 days → drop)
- Step 7 — Present and Apply: present diff-style summary, apply only after user approval

- **Backlog self-consistency scan + external reconciliation (Step 4 / Step 4b)**: generators MUST emit BOTH behaviors into save-session, tied to D56 § Backlog Item Schema (single-source discipline) and § Session State Command. (a) **Self-consistency scan** (fold into Step 4): instruct the skill to extract every `#<N>` / `<PREFIX>-<N>` / ticket-key token appearing more than once across `<backlog-file>` and `<session-file>`, diff the surrounding status word (`OPEN`/`MERGED`/`CLOSED`/`DONE`/etc.) across occurrences, and flag any divergence as candidate drift — a PURE file-internal check with NO live `gh` / issue-tracker calls, the cheap complement to a full audit that catches duplicate-copy staleness. (b) **Step 4b reconcile** (a new subsection between Step 4 and Step 5): instruct the skill to inbound-reconcile external state on a cadence (references whose `verified <date>` is older than a few days, or an item the save is about to record a decision on) — reuse Step 3's `gh pr view` results for in-flight PRs, and in issue-tracker mode run `oj-helper issue-tracker-list` to compare live status against what each referencing item asserts (platform-neutral via the `issue-tracker-*` abstraction); report drift as a flagged inconsistency for the user to confirm, do NOT auto-rewrite item scope/status from an externally-made transition (re-opening is a user decision), and state a no-op explicitly when nothing is stale enough to re-poll. Without this directive a regen would drop the Step 4 scan and the Step 4b subsection.

Constraints: approval required, non-destructive, graceful degradation, no network calls beyond git/gh.

Cross-references use `${CLAUDE_PLUGIN_ROOT}/templates/session-state.md`, `.claude/CLAUDE.md`.

### 5. show-backlog skill — `skills/show-backlog/SKILL.md`

**Purpose**: Display a concise read-only summary of the current backlog state. Read-only — no modifications, no transitions, no work started.

**YAML frontmatter** (verbatim):
```yaml
---
description: Display a read-only summary of the current backlog grouped by priority
allowed-tools: [Bash, Read, Grep, Glob]
context: fork
---
```

`show-backlog` is read-only (it detects the backlog source and prints a summary; no modifications, transitions, or work started), so it gets `allowed-tools: [Bash, Read, Grep, Glob]` — Bash for `oj-helper issue-tracker-check`/`issue-tracker-list`, Read/Grep/Glob for the `.claude/BACKLOG.md` markdown parse, and NO write/edit tools — and `context: fork` so the summary runs in a forked context.

**Body**: Reproduce the 3-step protocol from `{OJ_SOURCE}/skills/show-backlog/SKILL.md`:

- Step 1 — Backlog source detection (identical to /run-task)
- Step 2 — Load backlog items via `oj-helper issue-tracker-list --project PROJECT_KEY` (issue-tracker mode) OR markdown parse of `.claude/BACKLOG.md` (BACKLOG.md mode)
- Step 3 — Present summary: header (source + total open count), items grouped by priority with ID / Title / Status, omit empty priority groups, highlight next-cycle candidate (single highest-priority unblocked item; tiebreak by oldest creation date)

Constraints: read-only, concise output, empty-backlog handling.

Cross-references use `/run-task` for the full task lifecycle that consumes the backlog and `.claude/CLAUDE.md` for project-specific backlog conventions.

### 6. spec skill — `skills/spec/SKILL.md`

**Purpose**: Author the front-half specification artifacts (requirements → design → implementation-plan) for a Moderate/Complex subject, then **graduate** the plan's tasks into the backlog so `/run-task` and `/cycle` can execute them. Canonical spec: `D56-commands-automation.md` § Spec Authoring Command (front-half) and § Backlog Graduation.

**YAML frontmatter** (verbatim):
```yaml
---
description: Author front-half specs (reqs/design/plan) and graduate plan tasks into the backlog
disable-model-invocation: true
---
```

`spec` is side-effecting (it writes durable spec docs AND mutates the backlog / issue tracker during graduation), so it carries `disable-model-invocation: true` and gets NO `context: fork` or `allowed-tools` — same invocation-control class as `cycle`, `run-task`, and `save-session` (Item 7).

**Body**: Reproduce the protocol structure from `{OJ_SOURCE}/skills/spec/SKILL.md`:

- A one-argument mode selector: `reqs | design | plan | refresh`. Ceremony scales to tier (Trivial none, Simple plan-only, Moderate design+plan, Complex all three), consistent with the CONDUCTOR two-dimensional triage. The `reqs` mode uses the interview-first pattern (`AskUserQuestion`) before drafting; `refresh` re-aligns downstream artifacts and re-runs graduation idempotently.
- The `reqs`/`design`/`plan` modes author against the step-05 front-half templates — `${CLAUDE_PLUGIN_ROOT}/templates/requirements.md`, `${CLAUDE_PLUGIN_ROOT}/templates/design.md`, `${CLAUDE_PLUGIN_ROOT}/templates/implementation-plan.md` respectively. The templates carry the required sections (stable `FR-N`/`NFR-N`/`T-<subject>-NN` IDs, out-of-scope, per-task `verify:` command, open-questions, live-state reconciliation, graduation record); the skill body references them rather than duplicating the section lists.
- **Plan-mode graduation (Step G)** — the fully-specified substance; reproduce it verbatim from the baseline and keep it faithful to `D56` § Backlog Graduation. The generated Step G MUST emit:
  - **G1 backlog-source branch**: `oj-helper issue-tracker-check` → issue-tracker mode, else `oj-helper resolve-path backlog` → file-backed mode (identical detection to `/run-task`, `/show-backlog`).
  - **G2 priority derivation**: critical-path default (on-path → higher band, off-path → one lower, security/one-way-door → top); an explicit per-task `priority:` field overrides the derived band and breaks ties.
  - **G3 match**: topological sort by `blockedBy`; match existing items by `Source: <plan-doc>#T-<subject>-NN`; classify create / update / hold (in-progress or done — never modified) / cancel.
  - **G4 build + validate, NO writes**: build every item in memory **in the § Backlog Item Schema shape** (`${CLAUDE_PLUGIN_ROOT}/templates/backlog.md`) — title; `AC` = the task's verification command verbatim; `Links` = graduated predecessor ids as `Blocked By` plus any cited external artifact as a reference (never a restated status); `Source:` back-ref; priority; and per the single-source discipline, any `Status` asserting external state carries a `verified <today>` stamp and graduation adds NO second copy of an external-state fact (it links, it does not cache). Then validate the whole set (predecessors resolve, no id/`Source:` collision, required fields present). If any task fails validation, ABORT in prepare — write nothing, present nothing.
  - **G5 whole-set confirmation gate**: present the full create/update/hold/cancel set via `AskUserQuestion`; batch approval only (no per-item); write nothing until approved; nothing written on rejection.
  - **G6 atomic commit (all-or-none per plan)**: file-backed mode applies all changes to an in-memory copy and writes the whole backlog document in a single replace (temp-file-then-move); issue-tracker mode emulates a transaction — track every key created this invocation, and on ANY create/link failure ROLL BACK (close or delete the created keys, discard staged sidecar entries) leaving the tracker byte-identical to its pre-graduation state; commit the sidecar map `<plan-doc>.map` only after all creates+links succeed.
  - **G7 backlink the plan** — only after G6 commits; if G6 rolled back, do NOT touch the plan.
  - **External-id hygiene**: in issue-tracker mode, no `T-<subject>-NN` or local backlog id appears in externally visible tracker fields; the `T ↔ key` correspondence lives only in the local sidecar map `<plan-doc>.map`.
- Constraints: graduation is idempotent (keyed on `Source:`), all-or-none per plan, gated by explicit confirmation, and warns (does not block) on tasks estimated over ~1.5–2 dev-days.
- **Verification-command emptiness warning (plan mode, alongside the oversized-task warn)**: the generated Step 2 of plan mode (critical-path computation) MUST also emit a SHOULD-warn, advisory-only check: if a task's `verify:` command contains no assertion-bearing invocation - only `true`, `:`, `echo ...`, `exit 0`, or comments, with no test-runner/build/lint/validate call - warn the author and recommend a real check. This is a sibling warning to the oversized-task warn (same step, same "warn, do not block" register) and MUST NOT gate or alter graduation's verbatim copy of the verification command (G4/`D56` § Backlog Graduation invariant). Reproduce this from `{OJ_SOURCE}/skills/spec/SKILL.md` plan mode, where it is stated concretely with the trivially-green forms named. Without this directive a regen would drop the SKILL edit.

> The graduation step reads and writes the same backlog surface as `/run-task` and `/cycle`; keep its source-detection and item schema identical so the three skills interoperate. Cross-reference `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` for tier mechanics and `.claude/CLAUDE.md` for project-specific backlog conventions.

### 7. backlog-compact skill — `skills/backlog-compact/SKILL.md`

**Purpose**: Size-triggered backlog hygiene. Keep the file-backed backlog small enough that a single read holds it in view, so drift stays catchable by routine edits rather than a dedicated audit. Pin the current file to a retrievable git snapshot, then rewrite active items into the compact § Backlog Item Schema shape, relocating implementation narrative to its existing home (commits, PR descriptions, session state). All changes presented for approval before writing. Canonical spec: `D56-commands-automation.md` § Backlog Compaction Command + § Backlog Item Schema and Single-Source Discipline.

**YAML frontmatter** (verbatim):
```yaml
---
description: Size-triggered backlog hygiene -- pin the current backlog to a git blob, then rewrite active items into the compact single-sourced schema; requires user approval before writing
disable-model-invocation: true
---
```

`disable-model-invocation: true` is REQUIRED on `backlog-compact` — it rewrites the backlog file (only after user approval, but still a side-effecting persistence skill), same invocation-control class as `cycle`, `run-task`, `save-session`, and `spec`. It gets NO `context: fork` or `allowed-tools`.

**Body**: Reproduce the protocol from `{OJ_SOURCE}/skills/backlog-compact/SKILL.md`:

- **Step 0 — Resolve path**: `oj-helper resolve-path backlog` (fallback `.claude/BACKLOG.md`). In issue-tracker mode there is no large local file to compact — report and stop.
- **Step 1 — Measure and gate**: read the backlog; trigger at roughly 500-600 lines OR when a single read needs more than one page; below the threshold report the size and stop unless the user forces a run.
- **Step 2 — Pin (non-destructive, BEFORE any rewrite)**: `git hash-object -w <backlog-file>` (or record the committed blob/commit SHA for a clean tracked file); capture the pin reference for the rewritten header's history line.
- **Step 3 — Rewrite compact**: in memory against `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md` — preserve item ids exactly (never renumber) and workstream structure; keep only status + blocker per open item (`Status` with `verified <date>`, `Urgency`, `AC`, `Links`, `Context` only when load-bearing); move narrative out to its existing home (promote + link first if it lives nowhere else); collapse closed items to one-line markers; update the header history line to the Step 2 pin.
- **Step 4 — Self-consistency scan**: run the same duplicate-token status-divergence scan the save-session skill runs (§ Session State Command Step 4), so the rewrite does not carry a stale duplicate forward.
- **Step 5 — Present and apply**: diff-style summary (line count before/after, pin reference, items compacted, narrative relocated + where, drift found); apply only after approval; write atomically (single-replace: temp file then move).

Constraints: approval required; non-destructive (pin before rewrite; never drop content without preserving it in the pin or relocating load-bearing substance to a linked home); preserve ids exactly; single-sourced output; atomic write; graceful degradation (issue-tracker mode / missing `git` → stop, do not rewrite without a snapshot).

Cross-references use `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md` (target schema) and `/save-session` (the session-state analog of the same non-destructive, approval-gated, compaction pattern).

### 8. workstream-new skill — `skills/workstream-new/SKILL.md`

**Purpose**: Scaffold an isolated parallel `/cycle` execution thread — its own directory, its own git worktree on its own branch, and a per-workstream `.claude/CLAUDE.md` enforcing a `[ws: <wsid>]` tagging discipline — while SHARING the workspace's canonical `.claude/BACKLOG.md`, session state, and artifacts with every other concurrent workstream. The scaffolding filesystem work is done by the `oj-helper workstream-new` subcommand (step-07); the skill elicits inputs, invokes the helper, and surfaces the helper's next-steps block to the user. Canonical spec: `D56-commands-automation.md` § Workstream Scaffolding Command.

**YAML frontmatter** (verbatim):
```yaml
---
description: Scaffold a parallel-workstream directory (git worktree + linked .claude/ state) for running an isolated /oj:cycle thread against a shared workspace
disable-model-invocation: true
---
```

`disable-model-invocation: true` is REQUIRED on `workstream-new` — it triggers side-effecting scaffolding (a new worktree + linked state) via the helper, same invocation-control class as `cycle`, `run-task`, `save-session`, `spec`, and `backlog-compact`. NO `context: fork` or `allowed-tools`.

**Body**: Reproduce the protocol from `{OJ_SOURCE}/skills/workstream-new/SKILL.md`:

- **One workstream concept, two surfaces** (emit near the top): the execution workstream this skill scaffolds is the same workstream the shared backlog groups items under — the `WS-<X>` blocks (goal / sequencing / current bottleneck) of `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md` (D56 § Backlog Item Schema). A parallel `/cycle` thread should have a declared home in that backlog so its work is visible and single-sourced.
- **Step 1 — Elicit args**: `WSID` (workstream id; directory + default branch name; prefer one that maps to a `WS-<X>` backlog block, and if no such block exists flag to the user to add one per `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md` — the skill does not edit the backlog itself) and `REPO` (repo dir inside the workspace); optional `BRANCH` (default `<wsid>`) and `--workspace PATH` (else the helper walks up from `$PWD` for `.claude/state/session.md`). If WSID or REPO is missing, ask before proceeding.
- **Step 2 — Invoke the helper**: `oj-helper workstream-new <wsid> <repo> [branch] [--workspace <path>]`; capture stdout/stderr and the exit code; on non-zero exit, surface the helper's stderr verbatim and stop.
- **Step 3 — Surface next steps**: on exit 0, present the helper's "Next steps:" block verbatim and explain that the `cd` + `claude` launch must be run by the user in their terminal, not by this session.

Constraints: do NOT execute the `cd` or launch `claude` on the user's behalf; do NOT modify `.claude/BACKLOG.md`, session state, or workspace files (the helper does all filesystem work); on non-zero helper exit, quote stderr verbatim and stop.

Cross-references use `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md` (the `WS-<X>` workstream schema) and the `oj-helper workstream-new` subcommand (step-07).

## Format Requirements

Each SKILL.md must:

1. **Start with YAML frontmatter** delimited by `---` on line 1 and `---` after the description field. The `description:` field is REQUIRED (the plugin host scans for it and skips skills that lack it). Quoting is optional — the live baseline uses both quoted and unquoted forms.
2. **Use consistent heading levels** — `#` for the skill title (e.g., `# /run-task`), `##` for major sections (Protocol, Constraints, Format Notes), `###` for steps or phases.
3. **Use fenced code blocks** with triple backticks for command examples and verbatim format strings.
4. **Use blockquotes** (`>`) for important notes and cross-references to other plugin-tree files.
5. **Use bold text** (`**`) for critical requirements and constraints.
6. **Brand Identity**: Use **"OpenJunto"** as the product/system name in all user-facing prose. Do NOT emit bare "Junto" as a product name (preserved only in historical references to Franklin's Junto). Technical identifiers use the lowercase `oj-` prefix (`oj-helper`, `oj-expert`, `OJ_DEVMODE`, `${CLAUDE_PLUGIN_ROOT}`) and MUST be preserved verbatim — these are part of the tool contract. Legacy `junto-*` identifier forms are accepted by the helper for one release as backward-compat fallbacks.
7. **Plugin-tree references** use `${CLAUDE_PLUGIN_ROOT}/<subdir>/<file>` for files inside the plugin install (NOT `~/.claude/...` — that path form is reserved for user-installed CLAUDE.md and per-user configuration). Reference `${CLAUDE_PLUGIN_ROOT}/reference/compact/<name>.md` for compact profiles (NOT `agents/*-compact.md`, NOT `agents/compact/*.md`), `${CLAUDE_PLUGIN_ROOT}/reference/expert-index.md` for the roster index, and `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md` for full profiles.
8. **Body length** must exceed 5 lines (`verify_step_06` asserts this; an empty or near-empty skill is treated as a generation failure).

## Verification

After generation, verify each SKILL.md:

1. **Path**: file exists at `skills/<name>/SKILL.md` (directory-per-skill, not flat). All 8 directories present: `skills/cycle/`, `skills/health-check/`, `skills/run-task/`, `skills/save-session/`, `skills/show-backlog/`, `skills/spec/`, `skills/backlog-compact/`, `skills/workstream-new/`.
2. **Frontmatter**: file begins with `---` on line 1, contains a `description:` line, closes with `---` before the body. **Invocation controls (Item 7)**: the side-effecting skills (`cycle`, `run-task`, `save-session`, `spec`, `backlog-compact`, `workstream-new`) each carry `disable-model-invocation: true`; the read-only skills (`show-backlog`, `health-check`) each carry `allowed-tools: [Bash, Read, Grep, Glob]` (a read-only set — no write/edit tools) and `context: fork`. The side-effecting skills do NOT get `context: fork` or `allowed-tools`; the read-only skills do NOT get `disable-model-invocation`.
3. **Body**: more than 5 lines of markdown content after the frontmatter.
4. **Phase/step completeness**: each skill reproduces the steps documented in the corresponding `{OJ_SOURCE}/skills/<name>/SKILL.md` baseline.
5. **Decision logic**: backlog source detection logic appears identical in both /run-task and /show-backlog (both call `oj-helper issue-tracker-check` and parse exit code + JSON `.project` field).
6. **Format strings**: PERSPECTIVE block format, feedback-file format, and the `HEALTH: OK | DEGRADED — ...` summary line match the baselines verbatim.
7. **Cross-references**: every `${CLAUDE_PLUGIN_ROOT}/<subdir>/<file>` reference points to a file the plugin tree will actually contain (the structural-diff Layer 4 check resolves these against the live tree).
8. **No legacy paths**: no `~/.claude/commands/`, no legacy `src/`-rooted output forms (commands previously lived under that wrapper; they now live in plugin-tree-direct `skills/` directories), no nested `agents/compact/` subdirectory, and no `agents/*-compact.md` siblings (compact profiles live at `reference/compact/<name>.md`); no `agents/index.md` reference (use `reference/expert-index.md`).
9. **Graduation contract (spec skill)**: `skills/spec/SKILL.md` reproduces Step G with the four hard guarantees from `D56` § Backlog Graduation — (a) prepare/validate with NO writes before the confirmation gate; (b) whole-set confirmation gate before any write; (c) all-or-none commit (single-replace write for file-backed; tracked-key rollback for issue-tracker); (d) issue-tracker external-id hygiene (no `T-` / local backlog id in tracker-visible fields; correspondence in `<plan-doc>.map`). Backlog source-detection and item schema match `/run-task` and `/show-backlog` verbatim.

## Dependencies

- **Step 01** (CONDUCTOR.md) must be complete — defines the slim two-dimensional triage (incl. the Trivial fast-path) and tier overview referenced by each skill body
- **Step 04** (reference files) must be complete — skills cross-reference `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`, `workflow-stages.md`, and the full execution mechanics / model-selection table in `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md`
- **Step 05** (templates) must be complete — skills cross-reference `${CLAUDE_PLUGIN_ROOT}/templates/session-state.md`, `retrospective.md`; the `spec` skill additionally references the front-half templates `${CLAUDE_PLUGIN_ROOT}/templates/{requirements,design,implementation-plan}.md`; the `backlog-compact` skill (and graduation's item-build) reference `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md`
- **Step 07** (oj-helper script) must be complete — skills invoke `oj-helper` subcommands (`issue-tracker-check`, `issue-tracker-list`, `issue-tracker-transition`, `feedback-path`, `conductor-inject`); the `spec` skill additionally invokes `resolve-path backlog`, `issue-tracker-create`, and `issue-tracker-link-list` during graduation; the `workstream-new` skill invokes the `workstream-new` subcommand (step-07 § 13), and `backlog-compact` invokes `resolve-path backlog`
- **D56** § Spec Authoring Command (front-half) + § Backlog Graduation — canonical source for the `spec` skill's modes and the Step G graduation protocol (identity/back-reference, field mapping, priority derivation, dependency translation, idempotent upsert, atomicity, external-id hygiene, confirmation/decomposition)
