# Smoke Tests

Manual functional test procedures for critical system paths in an OpenJunto system generated from the juntospec specification.

---

## Test 1: Installation

**Preconditions**:
- Clean system with no existing `~/.claude/` installation
- Make available on PATH

**Steps**:
1. Run `make install` from the generated OpenJunto repository
2. When prompted for GH workspace path, provide a test path (or accept default)
3. When prompted for dependency installation, answer appropriately for your system

**Expected Results**:
- [ ] No fatal errors during installation
- [ ] Version banner prints: "✓ OpenJunto v{VERSION} installed."
- [ ] `~/.claude/CLAUDE.md` exists
- [ ] `~/.claude/agents/` contains exactly 16 full profiles + `_preamble.md` + `index.md`
- [ ] `~/.claude/agents/compact/` contains exactly 16 compact profiles
- [ ] `~/.claude/templates/` contains exactly 5 templates
- [ ] `~/.claude/commands/` contains exactly 3 core commands
- [ ] `~/.claude/reference/` contains exactly 8 core reference files
- [ ] `~/.claude/settings.json` exists with correct structure
- [ ] `~/.local/bin/oj-helper` exists and is executable
- [ ] `~/.claude/.oj-version` exists with correct version string
- [ ] If jq was already installed, merge completed successfully (no duplicate env vars or permissions)

**Pass Criteria**: All expected results satisfied. Installation completes without errors.

---

## Test 2: Session Start Hook

**Preconditions**:
- OpenJunto installed successfully (Test 1 passed)
- Claude Code CLI available

**Steps**:
1. Start a new Claude Code session: `claude` (or `npx @claude/cli`)
2. Observe stderr output before first prompt

> The banner is emitted by `oj-helper conductor-inject` (the SessionStart hook), which also injects CONDUCTOR.md on stdout. `{VERSION}` is read from the plugin package's `VERSION` file. The SessionStart hook fires on session start (startup/resume/`/clear`/compaction) — NOT on `/reload-plugins` or `/plugin reload`. To re-observe the banner after a plugin reload, start a new session.

**Expected Results**:
- [ ] Version banner displays: "OpenJunto v{VERSION} active — OpenJunto coordination system" (where `{VERSION}` matches the plugin `VERSION` file)
- [ ] Banner appears on stderr (not in conversation, not on stdout)
- [ ] stdout carries valid SessionStart JSON with non-empty `additionalContext` (the injected CONDUCTOR.md)
- [ ] Claude Code prompt appears normally after banner
- [ ] No error messages

**Direct hook check** (independent of a live session):
```bash
CLAUDE_PLUGIN_ROOT=/path/to/oj-claude /path/to/oj-claude/bin/oj-helper conductor-inject 2>/tmp/banner.err | jq -e '.hookSpecificOutput.additionalContext | length > 0'
cat /tmp/banner.err   # → OpenJunto v<version> active — OpenJunto coordination system
```

**Pass Criteria**: Version banner displays correctly on stderr with the real plugin version, stdout remains valid JSON with non-empty additionalContext, no errors.

---

## Test 3: Simple Tier Flow (Inline Perspective Rotation)

**Preconditions**:
- Claude Code session active with OpenJunto loaded

**Steps**:
1. Create a test project with `.claude/BACKLOG.md` containing a trivial task
2. Submit request: "Add a simple health check endpoint that returns 200 OK"
3. Observe manager's triage decision
4. Observe perspective rotation
5. Check final output

**Expected Results**:

**Triage**:
- [ ] Manager performs two-dimensional triage
- [ ] Execution Model assessment shows 4 criteria with checkboxes
- [ ] 0-1 criteria checked (Simple tier)
- [ ] Stakeholder identification: Product + Tech + Implementation (3 total, within Simple tier limit)
- [ ] Manager confirms tier with user via AskUserQuestion

**Perspective Rotation**:
- [ ] Manager produces PERSPECTIVE block for each stakeholder (3 blocks)
- [ ] Each block has exactly 4 lines: PERSPECTIVE, LENS, ASSESSMENT, CONCERN
- [ ] Format matches spec exactly (including "([profile].md)" in first line)
- [ ] CONCERN line either states concern OR says "None — [reason]"

**Synthesis**:
- [ ] Manager synthesizes findings into unified action
- [ ] If code changes needed, delegates to implementation expert via Task tool (not implemented inline)

**Quality Gates (Simple Tier - 2 items)**:
- [ ] Directly addresses the original question
- [ ] All identified stakeholder perspectives documented (PERSPECTIVE blocks)

**Pass Criteria**: Manager triages correctly (0-1 criteria), produces exactly 3 PERSPECTIVE blocks with correct format, synthesizes, delegates implementation if needed, checks quality gates.

---

## Test 4: Moderate Tier Flow (Task Tool Engagement)

**Preconditions**:
- Claude Code session active with OpenJunto loaded

**Steps**:
1. Submit request: "Add rate limiting to the public API (100 requests/min per user)"
2. Observe manager's triage decision
3. Observe 3-phase execution

**Expected Results**:

**Triage**:
- [ ] Manager performs two-dimensional triage
- [ ] Execution Model assessment shows 2-3 criteria checked (Moderate tier)
- [ ] Stakeholder identification: Product + Tech + Security + Operations (4 total)
- [ ] Manager confirms tier with user

**Phase 1 — Stakeholder Analysis**:
- [ ] Manager reads `~/.claude/reference/workflow-stages.md` and `~/.claude/reference/stakeholder-guide.md`
- [ ] Manager spawns 2 stakeholder agents in parallel (Security, Operations) using Task tool
- [ ] Spawn prompts include `<!-- oj-expert: [profile-filename] -->` marker
- [ ] Spawn prompts say "Do NOT implement — analysis only"
- [ ] Each expert produces analysis (not implementation)

**Synthesis Gate**:
- [ ] Manager synthesizes Phase 1 findings before Phase 2
- [ ] Synthesis identifies Hard vs Soft constraints
- [ ] If tensions exist, documented in TENSION format

**Phase 2 — Lead Implementation**:
- [ ] Manager spawns lead implementation agent (Software Engineer profile)
- [ ] Spawn prompt includes `<!-- oj-expert: senior-software-engineer -->`
- [ ] Spawn prompt includes synthesized findings (not raw stakeholder output)
- [ ] Lead agent produces pre-mortem (identifies at least 2 failure scenarios)
- [ ] Lead agent produces work product
- [ ] Lead agent produces handback (full 9-field format for Moderate tier)

**Phase 3 — Adversarial Review**:
- [ ] Manager spawns cross-domain reviewer (Distinguished Engineer or different domain than lead)
- [ ] Reviewer prompt says "Find the single most important problem"
- [ ] Reviewer prompt includes specific failure modes to test
- [ ] Reviewer produces adversarial review with format: FAILURE MODES TESTED, #1 PROBLEM FOUND, VERDICT
- [ ] If no problems found, reviewer explains why resistant to tested failure modes

**Quality Gates (Moderate Tier - 6 items)**:
- [ ] Directly addresses the original question
- [ ] All identified stakeholder perspectives represented
- [ ] Assumptions explicitly stated
- [ ] At least one risk identified (or adversarial analysis finding no material concerns)
- [ ] Adversarial review completed (failure modes tested and documented)
- [ ] Pre-mortem conducted

**Pass Criteria**: Manager triages correctly (2-3 criteria), executes all 3 phases in sequence, synthesis gate between phases, pre-mortem conducted, adversarial review with specific failure modes tested, all 6 quality gates checked.

---

## Test 5: Complex Tier Flow (Parallel Team)

**Preconditions**:
- Claude Code session active with OpenJunto loaded
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable set

**Steps**:
1. Submit request: "Migrate authentication system from session-based to JWT"
2. Observe manager's triage decision
3. Observe team formation and execution

**Expected Results**:

**Triage**:
- [ ] Manager performs two-dimensional triage
- [ ] Execution Model assessment shows 4 criteria checked OR mandatory escalation trigger (security vulnerability)
- [ ] Stakeholder identification: 7+ stakeholders (Product, Tech, Security, Operations, Architecture, Quality, Reliability)
- [ ] Manager confirms tier with user

**Team Formation**:
- [ ] Manager reads all reference files (8 core + enterprise overlay if present)
- [ ] Manager uses `TeamCreate` tool to spawn team
- [ ] Team includes coordinator agent + stakeholder agents
- [ ] Coordinator is general-purpose (not domain expert)
- [ ] Team size: 3-5 teammates (per spec target)

**Task Planning**:
- [ ] Coordinator creates task graph with declarative dependencies
- [ ] Analysis tasks unblocked (run in parallel)
- [ ] Implementation tasks `blockedBy` analysis tasks
- [ ] Review tasks `blockedBy` implementation tasks
- [ ] Task count: ~5-6 tasks per teammate (per spec target)

**Parallel Execution**:
- [ ] Analysis tasks execute in parallel
- [ ] Teammates self-claim unassigned, unblocked tasks via TaskUpdate
- [ ] Peers communicate via SendMessage for coordination
- [ ] Coordinator synthesizes findings (not routing every message)

**Quality Gates (Complex Tier - 9 items)**:
- [ ] Directly addresses the original question
- [ ] All identified stakeholder perspectives represented
- [ ] Assumptions explicitly stated with risks and mitigations
- [ ] Adversarial review by cross-functional stakeholders (failure modes tested)
- [ ] Dissenting views documented (even if overruled)
- [ ] Success criteria defined
- [ ] Pre-mortem conducted (3+ failure scenarios)
- [ ] Rejected alternatives steelmanned
- [ ] Retrospective completed

**Shutdown**:
- [ ] Manager or coordinator conducts retrospective
- [ ] Retrospective uses `~/.claude/templates/retrospective.md` structure
- [ ] Coordinator sends `shutdown_request` to each teammate
- [ ] Awaits `shutdown_response` (approve/reject) from each
- [ ] Manager calls `TeamDelete` after all teammates shut down

**Pass Criteria**: Manager triages correctly (4 criteria or mandatory trigger), creates team, coordinator manages task graph, parallel execution with declarative dependencies, all 9 quality gates checked, structured shutdown with retrospective.

---

## Test 6: SubagentStart Hook (Profile Injection)

**Preconditions**:
- Claude Code session active with OpenJunto loaded
- `oj-helper` script on PATH
- jq installed

**Steps**:
1. Submit request that triggers Moderate tier with Software Engineer implementation
2. Observe Task tool spawn for Software Engineer
3. Check if expert receives profile automatically
4. Observe expert's first output line

**Expected Results**:

**Hook Execution**:
- [ ] SubagentStart hook fires when Task tool creates sub-agent
- [ ] Hook calls `oj-helper inject-profile`
- [ ] Hook reads SubagentStart JSON from stdin
- [ ] Hook identifies agent_type as "general-purpose" (proceeds)
- [ ] Hook derives transcript path from hook JSON
- [ ] Hook waits up to 500ms for transcript file to appear
- [ ] Hook reads first line of transcript (spawn prompt)
- [ ] Hook detects `<!-- oj-expert: senior-software-engineer -->` marker
- [ ] Hook reads `~/.claude/agents/_preamble.md`
- [ ] Hook reads `~/.claude/agents/senior-software-engineer.md` (or compact fallback)
- [ ] Hook outputs JSON with `hookSpecificOutput.additionalContext` field
- [ ] additionalContext contains preamble + profile separated by `---`

**Expert Behavior**:
- [ ] Expert produces orientation statement as first output line
- [ ] Orientation matches role type (Implementer: "Highest-risk constraint: [X]")
- [ ] Expert demonstrates domain knowledge from profile (e.g., red flags from Software Engineer profile)
- [ ] Expert follows handback protocol (produces full 9-field handback for Moderate tier)

**Pass Criteria**: Hook executes successfully, profile injected automatically, expert receives full context without manager needing to paste profile, expert produces correct orientation statement.

---

## Test 7: Hook Fallback (Missing jq)

**Preconditions**:
- Claude Code session active with OpenJunto loaded
- `oj-helper` script on PATH
- jq NOT on PATH (temporarily renamed or removed)

**Steps**:
1. Submit request that triggers Task tool spawn
2. Observe spawn and expert behavior

**Expected Results**:

**Hook Behavior**:
- [ ] SubagentStart hook fires
- [ ] `oj-helper inject-profile` exits 0 (no error)
- [ ] No profile injection occurs (hook exits cleanly)
- [ ] Sub-agent spawn proceeds normally (not blocked by hook failure)

**Fallback Pattern**:
- [ ] Manager spawn prompt includes fallback instructions: "**FIRST**: Read `~/.claude/agents/_preamble.md` and your full profile..."
- [ ] Expert reads profile manually using Read tool
- [ ] Expert proceeds with task after reading profile

**Pass Criteria**: Hook fails gracefully (exit 0), spawn proceeds, manager provides fallback instructions, expert self-loads profile successfully.

---

## Test 8: Backlog Management (BACKLOG.md Mode)

**Preconditions**:
- Claude Code session active with OpenJunto loaded
- Test project with `.claude/BACKLOG.md` containing 3-5 prioritized items
- No issue tracker integration configured

**Steps**:
1. Run `/show-backlog` command
2. Observe output
3. Run `/run-task` command
4. Observe triage → execution → backlog update flow

**Expected Results**:

**/show-backlog Command**:
- [ ] Manager calls `oj-helper issue-tracker-check` first
- [ ] issue-tracker-check exits with code non-zero OR outputs `{"ok":true,"project":null}` (no issue tracker configured)
- [ ] Manager reads `.claude/BACKLOG.md` directly
- [ ] Displays backlog summary:
  - Source: "BACKLOG.md"
  - Total count of open items
  - Items grouped by priority (P0-P4)
  - Each item shows ID (BACK-NNN), Title, Status
- [ ] Highlights highest-priority unblocked item as next cycle candidate
- [ ] Output is read-only (no modifications to backlog)

**/run-task Command (BACKLOG.md mode)**:
- [ ] Manager calls `oj-helper issue-tracker-check` first (same detection logic)
- [ ] Reads `.claude/BACKLOG.md`
- [ ] Selects highest-priority unblocked item
- [ ] Performs triage (2 dimensions)
- [ ] Executes according to tier
- [ ] Updates `.claude/BACKLOG.md` after completion:
  - Marks completed item
  - Adds discovered work if any
- [ ] No issue tracker API calls made

**Pass Criteria**: Both commands detect BACKLOG.md mode correctly, read local file, operate without issue tracker dependency, display/update backlog correctly.

---

## Test 9: Circuit Breaker

**Preconditions**:
- Claude Code session active with OpenJunto loaded

**Steps**:
1. Submit request that intentionally leads to rework (e.g., ambiguous requirements)
2. Allow expert to iterate 3 times on same deliverable
3. Observe manager's response after 3rd iteration

**Expected Results**:

**Trigger Detection**:
- [ ] Manager tracks revision count per deliverable
- [ ] After 3rd revision cycle, manager escalates to user (doesn't attempt 4th)
- [ ] Escalation message presents 4 options:
  - Simplify scope
  - Proceed with documented risks
  - Pause for info
  - Abandon

**Adaptive Signals** (if applicable during test):
- [ ] If 2+ consecutive Complete/High with no objections: manager escalates adversarial brief
- [ ] If 2+ consecutive Needs Iteration: manager relaxes scope before re-engaging
- [ ] If lead ignores 2+ stakeholder findings: manager reissues findings as hard constraints

**Pass Criteria**: Circuit breaker triggers after exactly 3 revision cycles, presents 4 options, stops automatic iteration.

---

## Test 10: /run-task End-to-End (Simple Tier)

**Preconditions**:
- Claude Code session active with OpenJunto loaded
- Test project with `.claude/BACKLOG.md` containing simple task (e.g., "Add health check endpoint")
- git initialized, clean working directory

**Steps**:
1. Run `/run-task` command
2. Observe full task lifecycle execution through all 5 phases

**Expected Results**:

**Phase 1 — Initialize**:
- [ ] Manager reads `.claude/CLAUDE.md` if present
- [ ] Manager detects backlog source (BACKLOG.md mode for this test)
- [ ] Reads backlog, selects highest-priority unblocked item

**Phase 2 — Classify**:
- [ ] Manager performs 2D triage (4 criteria + stakeholder identification)
- [ ] Presents triage result to user with AskUserQuestion
- [ ] User confirms or adjusts tier

**Phase 3 — Plan & Execute**:
- [ ] Manager declares engagement plan (3 stakeholders for Simple tier)
- [ ] Maps to compact profiles
- [ ] States "inline" for Simple tier (no agent spawns planned)
- [ ] Manager applies inline perspective rotation
- [ ] Produces 3 PERSPECTIVE blocks (Product, Tech, Implementation)
- [ ] Synthesizes into unified action
- [ ] Delegates implementation to Software Engineer via Task tool
- [ ] Expert writes/runs tests (if applicable)

**Phase 4 — Deliver**:
- [ ] Manager (or delegated expert) creates atomic commit
- [ ] Commit message has NO "Co-Authored-By" lines or Claude ads
- [ ] Verification gate: runs `git status` after commit
- [ ] If uncommitted changes remain, stages and commits with descriptive message
- [ ] Performs only one verification pass
- [ ] Manager updates `.claude/BACKLOG.md` (marks item complete, adds discovered work if any)

**Phase 5 — Learn**:
- [ ] Manager conducts brief retrospective
- [ ] For Simple tier: brief inline retrospective (not full template)
- [ ] Notes what worked and what to improve
- [ ] **Dev Mode Feedback** (if OJ_DEVMODE=1):
  - Manager calls `oj-helper feedback-path`
  - If output empty, skips feedback
  - If output non-empty, writes feedback file to path
- [ ] If design documents produced, stored in `.claude/artifacts/`
- [ ] Manager notifies user task is complete
- [ ] Summarizes what was done
- [ ] Suggests `/clear` if context large

**Pass Criteria**: All 5 phases execute in order, no phases skipped, backlog updated correctly, commit created with clean message, task completes successfully.

---

## Test 11: Quality Gates Enforcement (Moderate Tier)

**Preconditions**:
- Claude Code session active with OpenJunto loaded
- Submit request that triggers Moderate tier

**Steps**:
1. Observe manager checking quality gates during execution
2. Observe manager's response if quality gate fails

**Expected Results**:

**Quality Gate Verification**:
- [ ] Manager explicitly references quality gates during synthesis
- [ ] Checks all 6 Moderate tier gates:
  1. Directly addresses the original question
  2. All identified stakeholder perspectives represented
  3. Assumptions explicitly stated
  4. At least one risk identified (or adversarial analysis finding no material concerns)
  5. Adversarial review completed (failure modes tested and documented)
  6. Pre-mortem conducted

**Quality Gate Failure Handling**:
- [ ] If gate fails (e.g., no adversarial review conducted), manager does NOT proceed to delivery
- [ ] Manager re-engages expert to complete missing gate
- [ ] After completion, re-checks gate before proceeding

**Pass Criteria**: Manager explicitly verifies all 6 quality gates, does not proceed past failed gate, re-engages to complete missing requirements.

---

## Test 12: Model Selection

**Preconditions**:
- Claude Code session active with OpenJunto loaded

**Steps**:
1. Submit request requiring multiple sub-agent spawns of varying complexity:
   - Routine doc update (haiku candidate)
   - Implementation with clear spec (sonnet candidate)
   - Novel architectural decision (opus candidate)
2. Observe Task tool spawn parameters

**Expected Results**:

**Model Parameter Usage**:
- [ ] Manager sets `model` parameter on Task tool spawns
- [ ] Routine task: `model: "haiku"`
- [ ] Implementation task: `model: "sonnet"`
- [ ] Architectural task: `model: "opus"`
- [ ] If uncertain, manager uses more capable model (sonnet > haiku, opus > sonnet)

**Sub-Agent Behavior**:
- [ ] Sub-agents execute with assigned model (verify via output characteristics or explicit model mention)
- [ ] Task quality matches model capability (haiku for simple, opus for complex)

**Pass Criteria**: Manager selects appropriate model for each task, uses more capable model when uncertain, tasks complete successfully.

---

## Test 13: STRONGEST OBJECTION and FALSIFIER

**Preconditions**:
- Claude Code session active with OpenJunto loaded
- Submit request that triggers Moderate tier with implementation

**Steps**:
1. Observe lead implementation agent's handback
2. Check STRONGEST OBJECTION field
3. Check FALSIFIER field

**Expected Results**:

**STRONGEST OBJECTION**:
- [ ] Present in handback (required for Moderate tier)
- [ ] Genuinely engages strongest counterargument
- [ ] Quality bar: makes you briefly reconsider the recommendation
- [ ] NOT weak (e.g., not just "might be slightly slower")

**FALSIFIER**:
- [ ] Present in handback (required for Moderate tier)
- [ ] Format: "Fails if [condition] because [mechanism]."
- [ ] Empirical (what breaks it in production), not rhetorical
- [ ] Different from STRONGEST OBJECTION (objection is rhetorical, falsifier is empirical)

**Example Good Handback**:
```
STRONGEST OBJECTION: This couples business logic to infrastructure state. If Redis fails,
all requests fail even if the application is healthy. A stateless approach would be more resilient.

FALSIFIER: "Fails if token volume exceeds 10K/sec because signature verification becomes
CPU-bound and response times exceed 200ms SLA."
```

**Pass Criteria**: Both fields present, STRONGEST OBJECTION is genuinely strong, FALSIFIER is empirical and specific, distinction between them clear.

---

## Test 14: Pre-Mortem Gate

**Preconditions**:
- Claude Code session active with OpenJunto loaded
- Submit request that triggers Moderate tier

**Steps**:
1. Observe lead implementation agent's pre-mortem execution
2. Check pre-mortem output format

**Expected Results**:

**Pre-Mortem Execution**:
- [ ] Pre-mortem conducted BEFORE work product (gate, not retrospective)
- [ ] Prompt: "Imagine this work shipped exactly as planned, and six months later it is considered a failure. What went wrong?"
- [ ] Agent identifies at least 2 distinct failure scenarios (Moderate tier requirement)
- [ ] Each scenario states mitigation or accepted risk

**Pre-Mortem Format**:
```
PRE-MORTEM:
1. [Failure scenario]: [Mitigated by X | Accepted risk because Y]
2. [Failure scenario]: [Mitigated by X | Accepted risk because Y]
```

**Quality**:
- [ ] Scenarios are distinct (not variations of same failure)
- [ ] Scenarios are realistic (could actually happen in production)
- [ ] Mitigations are specific (not vague "we'll monitor it")

**Pass Criteria**: Pre-mortem conducted before work product, at least 2 scenarios identified, format correct, mitigations or accepted risks stated.

---

## End of Smoke Tests

These tests cover critical functional paths for the OpenJunto system. For structural verification, see `checklist.md`. For common generation mistakes, see `anti-patterns.md`.

**Test Execution Notes**:
- Run tests in order (Test 1 must pass before others can run)
- Tests 3-5 can be run in any order after Test 1-2 pass
- Tests 6-7 require specific hook conditions (jq present/absent)
- Tests 8-14 validate specific protocol behaviors
- Each test should take 5-15 minutes to execute manually
- Document any failures with exact error messages and reproduction steps
