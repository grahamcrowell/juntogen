# Generation Prompt: Step 04 — Reference Files

## Input

Read these specification files before generating:

1. **Primary spec**: `D48-reference-system.md` — defines the 8 reference files, their purpose, content structure, and why they're separate from CLAUDE.md
2. **Supporting specs**:
   - `D32-execution-models.md` — workflow stages by tier, synthesis gate format, pre-mortem format, adversarial review protocol
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

Generate **8 reference files** in markdown format. Create each file at the path specified:

1. `reference/workflow-stages.md`
2. `reference/stakeholder-guide.md`
3. `reference/worked-examples.md`
4. `reference/dev-mode.md`
5. `reference/failure-protocol.md`
6. `reference/file-patterns.md`
7. `reference/project-scaffolding.md`
8. `reference/communication-standards.md`

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
- **Adversarial Review Protocol**: Reviewer prompt ("find the single most important problem"), reviewer responsibilities (test failure modes, identify #1 problem, explain absence), output format with sections (FAILURE MODES TESTED, #1 PROBLEM FOUND, ADDITIONAL CONCERNS, CONFIDENCE CALIBRATION, VERDICT)
- **Output Compression**: Table mapping expert roles to compression levels (Analyst: compressed | Implementer: standard | Reviewer: full)
- **Deputy Coordinator Pattern**: Coordinator responsibilities in Complex tier (receives full plan, creates tasks, synthesizes output, relays to manager)

**Plugin-Internal Reference Form (MANDATORY)**: The source `{OJ_SOURCE}/reference/workflow-stages.md` uses `~/.claude/agents/compact/` in the Load-Perspectives row of the Simple-tier workflow table. **During emission**, rewrite `~/.claude/agents/compact/` to `${CLAUDE_PLUGIN_ROOT}/agents/` and update the path to reflect the flat `-compact.md` suffix layout (post-BL-025-i.1, the nested `agents/compact/` subdirectory was retired in favor of `agents/*-compact.md` siblings at the same level as their full profiles). This is a transform-not-copy operation. Tier A Assertion 19 enforces a zero-`~/.claude/`-literal invariant across the scoped plugin tree; emitting the source literal causes the assertion to FAIL.

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

1. **Completeness**: All required sections and tables present
2. **Format accuracy**: FINDING/TENSION ledger syntax, PERSPECTIVE block format, adversarial review output format match specs
3. **Cross-references**: References to other plugin-internal files use the `${CLAUDE_PLUGIN_ROOT}/...` form (e.g., `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`), NOT `~/.claude/...` — the latter resolves to the adopter's HOME, not the plugin tree, and FAILS Tier A Assertion 19. The dev-feedback-path exception uses `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/dev}/...` per the BL-025-i.2 precedent.
4. **Size appropriateness**: Files are substantive but not bloated (workflow-stages ~8KB, stakeholder-guide ~5KB, etc.)
5. **Standalone clarity**: Each file is comprehensible without reading others (minimal forward references)

## Dependencies

- **Step 01** (CLAUDE.md) must be complete — defines tier-aware loading, agent spawning pattern, quality gates
- **Step 02** (agent profiles) must be complete — referenced in examples and stakeholder mapping
- **Step 03** (compact profiles) must be complete — referenced in Simple tier workflow
