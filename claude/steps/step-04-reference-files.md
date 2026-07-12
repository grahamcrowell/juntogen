# Generation Prompt: Step 04 — Reference Files

## Input

Read these specification files before generating:

1. **Primary spec**: `D48-reference-system.md` — defines the reference files, their purpose, content structure, and why they're separate from CONDUCTOR.md
2. **Supporting specs**:
   - `D08-core-protocol.md` — manager protocol structure; source for the Reference-and-Operations detail and definition-of-done moved into `reference/execution-protocol.md`
   - `D32-execution-models.md` — workflow stages by tier, synthesis gate format, pre-mortem format, adversarial review protocol, execution models full mechanics, agent spawning + model selection
   - `D40-quality-framework.md` — handback protocol, STRONGEST OBJECTION, FALSIFIER, calibration challenge, quality gates, anti-patterns

Also examine the actual OpenJunto source files for reference:
- `reference/workflow-stages.md`
- `reference/stakeholder-guide.md`
- `reference/worked-examples.md`
- `reference/file-patterns.md`
- `reference/project-scaffolding.md`
- `reference/communication-standards.md`
- `reference/failure-protocol.md`
- `reference/dev-mode.md`

## Task

Generate **9 reference files** in markdown format. Create each file at the path specified:

1. `reference/workflow-stages.md`
2. `reference/stakeholder-guide.md`
3. `reference/worked-examples.md`
4. `reference/dev-mode.md`
5. `reference/failure-protocol.md`
6. `reference/file-patterns.md`
7. `reference/project-scaffolding.md`
8. `reference/communication-standards.md`
9. `reference/execution-protocol.md` (NEW — holds the execution mechanics moved out of the slim CONDUCTOR; see § 9 below)

Each file is a standalone markdown reference document loaded on-demand by tier.

## Key Requirements

### 1. workflow-stages.md

**Purpose**: Tier workflows, pre-mortem gate, adversarial review protocol, output compression, deputy coordinator pattern.

**Must include**:
- **Workflow Stages by Tier**: Three tables (Simple, Moderate, Complex) with columns: Stage | Activity | Weight
  - Simple: 5 stages (Intake → Load Perspectives → Perspective Rotation → Synthesize + Execute → Verify)
  - Moderate: 7 stages (Intake → Stakeholder Analysis → Pre-Mortem → Implementation → Adversarial Review → Synthesis → Deliver)
  - Complex: 9 stages (Intake → Team Formation → Task Planning → Pre-Mortem → Parallel Execution → Adversarial Review → Synthesis → User Checkpoint → Retrospective)
- **Synthesis Gate** (between Stakeholder Analysis and Implementation in Moderate tier):
  - Findings ledger format: `FINDING: [text] | SOURCE: [role] | CONFIDENCE: [H/M/L]` and `TENSION: [text] | SOURCES: [role1, role2] | STATUS: [unresolved]`
  - TENSION items are PROTECTED — cannot be removed during synthesis
  - Constraint classification table: Hard (2+ stakeholders OR domain authority → must address) | Soft (single stakeholder → should address, explain if deferred) | Context (background → informs approach)
- **Pre-Mortem Gate**: Prompt ("Imagine this shipped and failed. What went wrong?"), requirements by tier (Moderate: 2 scenarios, Complex: 3 scenarios spanning categories), output format
- **Adversarial Review Protocol**: Reviewer prompt ("find the single most important problem"), reviewer responsibilities (test failure modes, identify #1 problem, explain absence), output format with sections (FAILURE MODES TESTED, #1 PROBLEM FOUND, ADDITIONAL CONCERNS, CONFIDENCE CALIBRATION, VERDICT).
  - **Reviewer scope (Item 3)**: the reviewer flags ONLY correctness and requirements-affecting gaps — not stylistic preferences, speculative nice-to-haves, or manufactured objections. "No material concerns" is an acceptable review outcome at ALL tiers (Simple, Moderate, and Complex); the reviewer is NOT required to invent a problem to justify the review. The **FAILURE MODES TESTED** section remains mandatory regardless of verdict — even a clean review must document which failure modes were probed. State this scoping explicitly in the reviewer prompt and responsibilities so a clean "no material concerns" verdict (with FAILURE MODES TESTED populated) passes the quality gate rather than triggering a forced-objection loop.
- **Output Compression**: Table mapping expert roles to compression levels (Analyst: compressed | Implementer: standard | Reviewer: full)
- **Deputy Coordinator Pattern**: Coordinator responsibilities in Complex tier (receives full plan, creates tasks, synthesizes output, relays to manager)

**Plugin-Internal Reference Form (MANDATORY)**: The source `{OJ_SOURCE}/reference/workflow-stages.md` uses `~/.claude/agents/compact/` in the Load-Perspectives row of the Simple-tier workflow table. **During emission**, rewrite `~/.claude/agents/compact/<name>.md` to `${CLAUDE_PLUGIN_ROOT}/reference/compact/<name>.md` — the compact profiles now live under `reference/compact/` (nested under `reference/`, with the `-compact` suffix dropped from each basename). Do NOT emit `agents/compact/`, `agents/*-compact.md`, or any `~/.claude/` form. This is a transform-not-copy operation. Tier A Assertion 19 enforces a zero-`~/.claude/`-literal invariant across the scoped plugin tree; emitting the source literal causes the assertion to FAIL.

**Design intent**: This file is 8KB of tactical execution detail. Simple tier never needs pre-mortem or adversarial review formats. Moderate tier doesn't need team formation. Loading on-demand saves 5-7KB for 80% of work.

### 2. stakeholder-guide.md

**Purpose**: Stakeholder mapping, disagreement protocol, steelman.

**Must include**:
- **Mandatory Pair**: Product Manager + Distinguished Engineer (all tiers)
- **Domain Signal → Stakeholder Mapping**: Table with columns: Domain Signal | Stakeholder | Profile | Key Questions. 14 rows covering Security/compliance, Data modeling, Cross-system integration, Infrastructure/CI-CD, Statistics/experimentation, ML systems, Enterprise standards, Requirements/process, Documentation, Process improvement, Leadership, Test strategy, SLOs/reliability, Code/refactoring
- **Stakeholder Escalation Guard**: Simple with 4+ → Moderate, Moderate with 5+ → Complex
- **Common Task Patterns**: Table mapping 12 task patterns (System architecture, Security review, Data pipeline, etc.) to required stakeholders beyond mandatory pair
- **Conflict Classification**: Table with columns: Conflict Type | Primary Resolver | Escalation. 4 types: Technical (DE resolves), Business (PM resolves), Mixed (DE + PM joint → User if deadlock), Cross-Domain (stakeholders present trade-offs → User decides)
- **Tension Classification**: 3 types (Resolvable → apply resolver | Trade-off → User decides | Productive Tension → forward as constraint, do NOT resolve)
- **Resolution Steps**: 5-step protocol (Identify conflict type → Document positions → Apply resolver → Time-box → Escalate)
- **DISSENT Format**: `DISSENT: [Stakeholder] | [Position + Rationale] | [Resolution]`
- **Steelman Format**: Alternative → Strongest argument → Why rejected. By tier: Simple (note inline), Moderate (1 alternative), Complex (1-2 alternatives)
- **Example Conflicts**: 4 scenarios with conflict type and resolution path

**Design intent**: Stakeholder mapping is reference data looked up during triage. The disagreement resolution machinery is 5KB of edge-case handling triggered only when conflicts occur.

### 3. worked-examples.md

**Purpose**: End-to-end examples for all three tiers demonstrating triage → execution → verification.

**Must include**:
- **Example 1: Simple Tier** — Health check endpoint implementation
  - User request, triage result (0 criteria scored), stakeholder list (Product + Tech + Implementation)
  - Inline perspective rotation showing 3 PERSPECTIVE blocks with format: `PERSPECTIVE: [Role] ([profile].md)` then LENS, ASSESSMENT, CONCERN
  - Synthesis statement merging perspectives
  - Verification checklist
- **Example 2: Moderate Tier** — Rate limiting for public API
  - User request, triage result (2 criteria), stakeholder list (Product + Tech + Security + Operations)
  - Phase 1: 2 parallel stakeholder analysis spawn prompts with `<!-- oj-expert: profile-name -->` markers
  - Synthesis gate showing FINDING items and constraint classification
  - Phase 2: Lead implementation spawn prompt with synthesized findings
  - Phase 3: Adversarial reviewer spawn prompt with specific failure modes to test
- **Example 3: Complex Tier** — Authentication migration (session-based to JWT)
  - User request, triage result (5 criteria), stakeholder list (7 stakeholders)
  - Team formation structure: Manager → Coordinator → Stakeholders
  - 8-step execution flow with coordinator as deputy
  - Task graph showing declarative dependencies (blockedBy)

**Design intent**: Training material valuable for learning but unnecessary once fluent. Each example is 1-2KB. Loading on-demand means experienced operators pay no cost for reference material.

### 4. dev-mode.md

**Purpose**: Dev mode feedback collection mechanism.

**Must include**:
- **OJ_DEVMODE=1 flag**: Environment variable to activate dev mode (legacy `JUNTO_DEVMODE` accepted as fallback)
- **Feedback path convention**: `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/dev}/feedback/{org}/{repo}/{timestamp}.md`
- **Scope**: Local development only, not part of distribution, user-created directory
- **Trigger mechanism**: Phase 5 (Learn) of the task lifecycle calls `oj-helper feedback-path`
- **File format**: Frontmatter with date/item/tier, then sections for "What Worked", "What to Improve", "OpenJunto System Suggestions"

**Plugin-Internal Reference Form (MANDATORY)**: The source `{OJ_SOURCE}/reference/dev-mode.md` uses `~/.claude/dev/` literals for the feedback path. **During emission**, rewrite every `~/.claude/dev/` literal to `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/dev}/` (per the BL-025-i.2 precedent — the `$HOME/.claude/dev` fallback inside the parameter expansion is the legitimate user-home form and is exempt from the Assertion 19 regex). Additionally, the source file references promote-targets such as `` `~/.claude/CLAUDE.md` `` — rewrite those to `` `${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` `` (CONDUCTOR.md is the post-BL-025-d/i.1 manager-protocol-file name; CLAUDE.md is retired in the plugin tree). This is a transform-not-copy operation. Tier A Assertion 19 enforces a zero-`~/.claude/`-literal invariant across the scoped plugin tree; emitting the source literal causes the assertion to FAIL.

**Design intent**: Optional developer workflow. When OJ_DEVMODE is off (99% of users), loading this reference wastes tokens. When on (active contributors), it's a 780-byte file with negligible overhead.

### 5. failure-protocol.md

**Purpose**: Sub-agent failure handling protocol.

**Must include**:
- **3-Step Protocol**:
  - Step 1: Retry with variations — 5 strategies: exact retry, alternate working directory, background mode, simplified prompt, Bash subagent type
  - Step 2: Document failure details — error message, variations attempted, subagent types tried
  - Step 3: Escalate to user with 4 options: Fix environment, Supervised delegation, Emergency direct execution, Abort
- **Emergency Direct Execution Protocol**: 5 constraints (announce clearly, attribute work, retry each request, time-box to 1 request, document in deliverables)
- **Recovery Checklist**: 3 items before each new request

**Design intent**: Exception path logic. When the Consult primitive works (99% of spawns), this protocol is dead code. When failures occur, it's a 2.6KB troubleshooting guide. Loading on-demand keeps the happy path fast.

### 6. file-patterns.md

**Purpose**: Backlog management, LLM-optimized patterns, project structure.

**Must include**:
- **Backlog Management Guidelines**: Target size (<10KB), what belongs in BACKLOG.md vs CLAUDE.md, session handoff principles
- **Standard Project `.claude/` Structure**: 2 variants:
  - Minimum viable (day 1): CLAUDE.md + BACKLOG.md
  - Full structure (mature projects): Add state/, artifacts/ (with 4 subdirs: analysis, program, meetings, status), archive/
- **Persist Long-Running Context in CLAUDE.md**: What belongs in project CLAUDE.md (design constraints, architectural decisions, project-specific patterns)
- **Header/Detail Pattern**: Lightweight index + detail files for growing content
  - Structure: index.md (<5KB) + detail/YYYY-QN.md (full content)
  - Index format: table with ID/Title/Date/Summary
  - Size thresholds: <10KB single file, 10-25KB consider splitting, >25KB must split
  - Use cases: completed backlog items, session retrospectives, artifact collections

**Design intent**: File organization is structural guidance needed during project setup and occasional refactoring, not during execution. Loading on-demand keeps execution-focused protocol lean.

### 7. project-scaffolding.md

**Purpose**: Session state, carry-over, context maps, artifact org, caching, comms.

**Must include**:
- **Session State Separation**: Stable layer (CLAUDE.md) vs volatile layer (state/session.md)
- **Carry-Over Compression**: Aging policy table (current + 2 sessions full, 7-14 days compress, 14+ days remove)
- **Context Map (llms.txt)**: Index format for projects with 10+ `.claude/` files (Core Files table, Reference table, Loading Guide)
- **Artifact Organization**: 4 subdirectory purposes (analysis/, program/, meetings/, status/) with lifecycle guidance
- **Snapshot Caching Contract**: Convention for command-generated data with 2-hour TTL (bash snippet example)
- **Communications Playbook Pattern**: Signal gate (when to communicate), hierarchy rule (one event = one post), channel routing table, drafts queue, log
- **Session Lifecycle Pattern**: Health Check (pre-session validation with 5 checks), Intake Funnel (5-step external input processing), Session Save (session save command)

**Design intent**: Opt-in infrastructure for mature projects. New projects start with minimum viable structure. These patterns are discovered when pain points emerge (session state bloat, communication fatigue, artifact sprawl).

### 8. communication-standards.md

**Purpose**: Technical communication standards, anti-patterns, success metrics.

**Must include**:
- **6 Communication Standards**: Lead with impact, quantify everything, provide runnable examples, include failure scenarios, reference actual incidents, calculate TCO
- **Standard Response Format**: 7-section structure (RECOMMENDATION, IMPACT, IMPLEMENTATION, RISKS, MITIGATION, ROLLOUT, METRICS)
- **Anti-Patterns Table**: 9 anti-patterns with columns: Anti-Pattern | Why Harmful | Instead
  - Include: Unsubstantiated "no concerns", manufactured adversarial findings, skipping triage, endless revision, checkbox theater, echo chamber, direct execution bypass, premature workaround, struggling alone, incomplete delegation
- **Success Metrics Table**: 5 metrics with targets
  - First-response quality (>70%), Triage accuracy (>85%), Cycle time (Simple <30min, Moderate <2hr, Complex <8hr), Peer review value (>40%), Circuit breaker activations (monitor trend)
- **AI Agent Context Note**: Metrics are session-level indicators, not tracked cross-session (requires external tooling)

**Design intent**: Quality guidelines valuable for calibration and meta-review, not operational protocol. Anti-patterns table is remedial content most valuable when something goes wrong. Loading for Complex tier where communication complexity justifies explicit standards.

### 9. execution-protocol.md (NEW)

**Purpose**: Hold the execution mechanics moved out of the slim CONDUCTOR (step-01). CONDUCTOR carries only the core sections and a just-in-time load pointer to this file; the manager loads `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` before executing any Moderate or Complex item. This file is the authoritative render target for the content step-01 explicitly REMOVED from CONDUCTOR.

**Sources**: D08 (core-protocol — Reference-and-Operations detail, Definition of Done structure), D32 (execution-models — full Simple/Moderate/Complex mechanics, agent spawning + model selection), D40 (quality-framework — handback protocol, quality gates), D48 (reference-system — tier-aware context loading). Where D08 uses `[-> FILE:id]` markers, resolve them against the canonical source files exactly as step-01 previously did.

**Must include** (each is the content moved out of CONDUCTOR — reproduce the [EXACT] items verbatim here):

- **Execution Models (full mechanics)** — the three tiers with complete detail:
  - **Simple**: inline perspective rotation (the Simple-tier PERSPECTIVE block stays in CONDUCTOR under Stakeholder Perspectives; here give the full rotation-and-synthesize mechanics).
  - **Moderate**: the three phase spawn formats verbatim — Phase 1 `<!-- oj-expert: [profile-filename] -->` marker + stakeholder analysis instructions; Phase 2 lead implementation with synthesized findings; Phase 3 adversarial review with failure-mode testing.
  - **Complex**: parallel team via Convene, INCLUDING the load-bearing **Fallback** clause (Convene→Consult degradation, Axiom 8) exactly as specified in step-01 § Convene Fallback and `D32-execution-models.md` §3 Fallback — the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env gate, the `oj-helper agent-teams-check` probe (`.available` from JSON, always exits 0), the deputy-coordinator parallel-Task-tool fan-out with handback-only synthesis, and the **runtime backstop** (if any agent-teams-gated tool raises "Unknown tool"/"tool unavailable" at runtime, fall through to the deputy-coordinator fan-out; User Checkpoint still fires). This clause is load-bearing: CONDUCTOR's Section 5 pointer promises it lives here.
- **Handback Protocol** — both formats with their [EXACT] anchor lines (these anchors are validated HERE, not in CONDUCTOR):
  - **Simple Tier Format**: under `### Simple Tier Format`, emit the anchor line `Compressed format (~5 lines):` verbatim (including the tilde and trailing colon), one blank line, then the 5-field compressed handback fenced block (HANDBACK/STATUS/CONFIDENCE header line, DELIVERABLE, RECOMMENDATION, STRONGEST OBJECTION, NEXT).
  - **Moderate/Complex Tier Format**: under `### Moderate/Complex Tier Format`, emit the anchor line `Full format (9 fields):` verbatim (including the parenthesized field count and trailing colon), one blank line, then the 9-field full handback fenced block (HANDBACK, STATUS, DELIVERABLE, RECOMMENDATION, RATIONALE, STRONGEST OBJECTION, FALSIFIER, CONFIDENCE, CAVEATS, NEXT ACTIONS — per `D40-quality-framework.md` § Handback Protocol).
  - Both anchor lines are [EXACT] — emit verbatim, do not paraphrase to "5-line compressed format" / "9-field full format". Also include status semantics, confidence levels, and calibration guidance.
- **Quality Gates** — three subsections with exact item counts: Simple Tier **2 items**, Moderate Tier **6 items**, Complex Tier **9 items**. Apply the Item-3 reviewer-scope wording: the review gate accepts "no material concerns" at all tiers provided the FAILURE MODES TESTED section is populated; the gate flags only correctness/requirements-affecting gaps.
- **Agent Spawning + Model Selection** — the spawning pattern plus the full model-selection content moved from CONDUCTOR Section 7:
  - **[EXTERNAL]** tier table rendered from `platform-snapshot.yaml` `models` (symbolic ids, tiers, cost ratios — do not hardcode), plus "when in doubt" guidance.
  - **Function-first selection rules** (5 bullets, concrete model ids resolved `{tier-routine}`→`haiku`, `{tier-implementation}`→`sonnet`, `{tier-reasoning}`→`opus`): reviewer-slot → strongest (always wins); Complex-tier lead → strongest; Moderate-tier lead → implementation, escalate to reasoning for high-risk / unresolved TENSION; Phase-1 analysts → implementation (routine for bounded/docs-only); domain-trigger specialists → implementation, escalate to reasoning when their domain is the decisive risk.
  - **Per-Role Default Model (adjustable; function rules always win)** table: strongest tier (Distinguished Engineer, Security Engineer, Site Reliability Engineer, Engineering Consultant); implementation tier (Software Engineer, Solutions Architect, DevOps Engineer, Test Engineer, Data Architect, Data Scientist, ML Engineer, Enterprise Architect, Business Analyst, Product Manager, Executive Leadership Coach); routine tier (Technical Writer — with escalation when user-facing prose is the deliverable). Override qualifier: "the function rules above always take precedence when any of them applies (reviewer-slot, Complex-tier lead, Moderate-tier lead, Phase-1 analyst, or domain-trigger specialist); the per-role default below fires only when no function rule matches the spawn."
  - **Fan-Out Budget** — the per-invocation spawn/fan-out budget guidance from D32 §6.
  - **Worked-example anchors**: back-pointer to `${CLAUDE_PLUGIN_ROOT}/reference/worked-examples.md` Example 2 (analysts-on-`sonnet` / reviewer-on-`opus` is the general pattern), plus the reviewer-slot-override-on-a-non-opus-default-role anchor (a Senior Technical Writer default `haiku` or Senior Software Engineer default `sonnet` spawned as reviewer runs on `opus` — the reviewer slot is `opus` by function, not role; Example 2's Security-Engineer-on-`opus` reviewer is NOT that role's default).
  - **Effort out-of-scope note**: per-expert effort is not controllable today — profiles are injected into `general-purpose` Task spawns via the `SubagentStart` hook (`oj-helper inject-profile`); the Task tool does NOT read `${CLAUDE_PLUGIN_ROOT}/agents/*.md` as subagent definitions (so their frontmatter is a no-op for spawn config); there is no per-invocation effort knob on that surface. Effort is session-level (`/effort`). Defer per-expert effort tiering.
- **Definition of Done** — the 4 subsections moved from CONDUCTOR Section 10: Simple/Moderate/Complex tier done-criteria, Verifying Deliverables, Incorporating Lessons.
- **Reference and Operations** — the detail moved from CONDUCTOR Section 9: issue-tracker bootstrap, the **Tier-Aware Context Loading** table (3 tiers with exact loading instructions), the **Reference Files** table (list every reference file this step generates with content descriptions), and the **Templates** table (5 templates with when-to-use descriptions).

**Cross-reference resolution (MANDATORY)**: every `${CLAUDE_PLUGIN_ROOT}/...md` cross-reference emitted in this file MUST resolve to a real file the plugin tree will contain — e.g., `${CLAUDE_PLUGIN_ROOT}/reference/worked-examples.md`, `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`, `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md`, `${CLAUDE_PLUGIN_ROOT}/reference/compact/<name>.md`, `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md`. Do NOT reference `agents/index.md`, `agents/_preamble.md`, or `agents/*-compact.md` (retired paths — use `reference/expert-index.md`, `reference/expert-preamble.md`, `reference/compact/<name>.md`). Do NOT emit `~/.claude/` literals (Tier A Assertion 19).

**Design intent**: The slim CONDUCTOR keeps only what the manager needs resident every session (role, constraints, triage, stakeholder selection, tier overview). The heavy execution machinery — spawn formats, handback formats, quality gates, model selection, definition of done, ops detail — is 12-15KB that only matters once the manager is actually executing a Moderate/Complex item. Just-in-time loading keeps the always-resident CONDUCTOR small while preserving full fidelity when it counts.

## Format Requirements

Each file must:
1. Start with a level-1 heading with the file topic
2. Use markdown tables for structured data
3. Use code blocks with triple backticks for format examples
4. Include section headings at appropriate levels (##, ###)
5. Use blockquotes (>) for rationale/design notes where appropriate
6. Match the tone and style of the source files (instructional, concise, example-driven)
7. **Brand Identity**: Use **"OpenJunto"** as the product/system name in all user-facing prose (e.g., "the OpenJunto task lifecycle", "active OpenJunto contributors"). Do NOT emit bare "Junto" as a product name (preserved only in historical references to Franklin's Junto). Technical identifiers use the `oj-` prefix (`oj-helper`, `oj-expert`, `OJ_DEVMODE`, `{OJ_SOURCE}`) and MUST be preserved verbatim — these are part of the tool contract. Legacy `junto-*` identifier forms are accepted by the helper for one release as backward-compat fallbacks.

## Verification

After generation, verify each file:

1. **Completeness**: All required sections and tables present. All 9 files emitted, including the NEW `reference/execution-protocol.md`.
2. **Format accuracy**: FINDING/TENSION ledger syntax, PERSPECTIVE block format, adversarial review output format match specs. In execution-protocol.md: both handback anchor lines (`Compressed format (~5 lines):` and `Full format (9 fields):`) present verbatim, quality-gate counts 2/6/9, and the Convene→Consult Fallback clause (with runtime backstop) present.
3. **Cross-references**: References to other plugin-internal files use the `${CLAUDE_PLUGIN_ROOT}/...` form (e.g., `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`), NOT `~/.claude/...` — the latter resolves to the adopter's HOME, not the plugin tree, and FAILS Tier A Assertion 19. Compact-profile refs use `${CLAUDE_PLUGIN_ROOT}/reference/compact/<name>.md` (NOT `agents/*-compact.md` or `agents/compact/`); preamble/index refs use `reference/expert-preamble.md` / `reference/expert-index.md`. Every `${CLAUDE_PLUGIN_ROOT}/...md` cross-ref in execution-protocol.md resolves to a real generated file. The dev-feedback-path exception uses `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/dev}/...` per the BL-025-i.2 precedent.
4. **Size appropriateness**: Files are substantive but not bloated (workflow-stages ~8KB, stakeholder-guide ~5KB, execution-protocol ~12-15KB, etc.)
5. **Standalone clarity**: Each file is comprehensible without reading others (minimal forward references)
6. **Reviewer scope (Item 3)**: workflow-stages.md adversarial-review protocol and execution-protocol.md quality gates both state that "no material concerns" is acceptable at all tiers, the reviewer flags only correctness/requirements-affecting gaps, and the FAILURE MODES TESTED section remains mandatory.

## Dependencies

- **Step 01** (CLAUDE.md) must be complete — defines tier-aware loading, agent spawning pattern, quality gates
- **Step 02** (agent profiles) must be complete — referenced in examples and stakeholder mapping
- **Step 03** (compact profiles) must be complete — referenced in Simple tier workflow
