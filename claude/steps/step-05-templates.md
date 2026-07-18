# Generation Prompt: Step 05 — Templates

## Input

Read these specification files before generating:

1. **Primary spec**: `D48-reference-system.md` § Template Inventory — defines the 9 templates, when to use each, and essential sections
2. **Supporting context**: Review Template Evolution and Template Selection notes in spec D48. The three front-half templates (requirements/design/implementation-plan) are consumed by the spec skill (`D56-commands-automation.md` § Spec Authoring Command); `implementation-plan.md` carries the `T-<subject>-NN` task shape that `D56` § Backlog Graduation reads. The `backlog.md` template encodes `D56` § Backlog Item Schema and Single-Source Discipline — the workstream-first, single-sourced item shape that graduation writes, the task lifecycle delivers into, save-session audits, and backlog-compact rewrites; read that D56 section before generating it.

Also examine the actual OpenJunto source files for reference:
- `templates/technical-analysis.md`
- `templates/architecture-decision-record.md`
- `templates/retrospective.md`
- `templates/session-state.md`
- `templates/communications-playbook.md`
- `templates/requirements.md`
- `templates/design.md`
- `templates/implementation-plan.md`
- `templates/backlog.md`

## Task

Generate **9 deliverable templates** in markdown format. Create each file at the path specified:

1. `templates/technical-analysis.md`
2. `templates/architecture-decision-record.md`
3. `templates/retrospective.md`
4. `templates/session-state.md`
5. `templates/communications-playbook.md`
6. `templates/requirements.md`
7. `templates/design.md`
8. `templates/implementation-plan.md`
9. `templates/backlog.md`

Each template is a structured format for a common deliverable type. Templates are starting points — projects copy to `.claude/` and customize as needed.

## Key Requirements

### 1. technical-analysis.md

**When to use**: Investigations, evaluations, technical deep dives.

**Essential sections**:
1. **Summary**: 2-3 sentences (what was analyzed, key finding, recommendation)
2. **Context**: Objective, Scope, Constraints
3. **Methodology**: Approach, Data Sources, Assumptions
4. **Findings**: Per finding: Observation, Evidence, Confidence (H/M/L), Implication
5. **Options Analysis**: Comparison table with criteria as rows, options as columns
6. **Recommendation**: Recommended option with rationale, Next Steps with owners
7. **Risks**: Table with columns: Risk | Likelihood | Impact | Mitigation
8. **Dissenting Views**: Document disagreements from reviewers (even if overruled)
9. **Metadata**: Author, Reviewer, Date, Tier (Simple/Moderate/Complex)

**Format notes**:
- Use markdown tables for Options Analysis and Risks
- Use subheadings (###) for each Finding
- Use bullet lists for Next Steps
- Include placeholder text in `[brackets]` to guide completion

### 2. architecture-decision-record.md

**When to use**: Significant technical decisions requiring documentation.

**Essential sections**:
1. **Status**: Proposed | Accepted | Deprecated | Superseded by ADR-XXX
2. **Date**: YYYY-MM-DD
3. **Context**: What situation or problem motivates this decision?
4. **Decision Drivers**: Bulleted list of factors influencing the decision
5. **Considered Options**: 3+ alternatives, each with brief description
6. **Decision**: Chosen option with rationale
7. **Reversibility Assessment**:
   - Reversibility level (Easy / Moderate / Difficult / Irreversible)
   - Reversal cost if wrong
   - One-way door? (Yes/No with additional scrutiny note if yes)
8. **Consequences**:
   - Positive: Benefits (bulleted)
   - Negative: Tradeoffs (bulleted)
   - Risks: Table with Risk | Likelihood | Impact | Mitigation
9. **Validation**: Success metrics, Review date
10. **References**: Related documents, ADRs, or resources
11. **Metadata**: Author, Reviewers, Approved by

**Format notes**:
- Use horizontal rules (---) to separate major sections
- Reversibility Assessment is critical for one-way doors — emphasize with formatting
- ADR number in title: `# ADR-[NUMBER]: [TITLE]`

### 3. retrospective.md

**When to use**: Complex tier post-engagement (required), optional for Moderate if issues arose.

**Essential sections**:
1. **Document Header**: Markdown blockquote with Date, Engagement Tier, Participants, Facilitator
2. **Engagement Summary**: Original Request, Delivered Outcome, Duration, Experts Engaged, Tier, Circuit Breaker Activated (Yes/No)
3. **What Went Well**: Table with columns: # | Item | Impact. Include Details subsection elaborating on key positives
4. **What Could Be Improved**: Table with columns: # | Item | Impact | Root Cause. Include Details subsection
5. **Questions & Puzzles**: Bulleted list of unresolved observations
6. **Action Items**: Table with columns: # | Action | Owner | Target | Priority (H/M/L). Include Action Categories subsection (Process, Profile, Template, Documentation)
7. **Metrics Review**: Table with columns: Metric | This Engagement | Notes. Include Rework cycles, Expert deadlocks, Tier classification accuracy, Quality gates passed, User checkpoints
8. **Profile/Process Updates Identified**: Two tables:
   - Profile Updates: Profile | Section | Proposed Change
   - Process Updates: Document | Section | Proposed Change

**Additional sections**:
- **Quality Checklist**: 5 verification items before finalizing
- **Usage Notes**: When to use, time target (15 minutes), follow-through guidance, AI agent context note about session-level vs cross-session tracking

**Format notes**:
- Use blockquote for document header (`> **Date**: ...`)
- Time target: 15 minutes per CLAUDE.md workflow
- AI agent context: Retrospectives serve to document learnings for user, identify immediate improvements, propose profile/process updates

### 4. session-state.md

**When to use**: `.claude/state/session.md` volatile layer, updated at session boundaries via session save command.

**Essential sections**:
1. **Header**: `> Updated: {YYYY-MM-DD}, session {N}`
2. **In-Flight PRs**: Table with columns: # | Repo | Title | Status | Notes
3. **Local Workspace State**: Table with columns: Repo | Branch | Dirty | Unpushed | Notes
4. **Session Carry-Over**:
   - HTML comment explaining retention policy (most recent 3 sessions full detail, >7 days compress to single-line, >14 days remove)
   - Current session entry: `*Completed this session ({date}, session {N}):*` with numbered list
   - Prior sessions: Similar format, compressed as appropriate
5. **Next Actions**: Numbered list of next steps

**Format notes**:
- Use blockquote for header (`> Updated: ...`)
- Use `clean / {FILES}` for Dirty column (shows either "clean" or list of dirty files)
- Use `{COUNT}` for Unpushed column
- Include HTML comment for retention policy (not rendered, documents the rule)
- Use italics with asterisks for session headings: `*Completed this session:*`

### 5. communications-playbook.md

**When to use**: `.claude/COMMS.md` signal gate + channel routing for projects with multiple stakeholder channels and communication fatigue risk.

**Essential sections**:
1. **Signal Gate**: Table with columns: Signal | Post to. Include note that gate prevents noise — communication warranted ONLY on change events, not elapsed time. List 7 signals (AC completed, blocker discovered/resolved, status transition, decision made, story/task completed, health status shift, ask/escalation needed). Include "Not a signal" list (elapsed time, internal housekeeping, current-state restatement, WIP without milestone)
2. **Hierarchy Rule**: Explanation of one event = one post at lowest level. Only roll up when aggregated picture changes. Don't echo same news at multiple levels.
3. **Channel Routing**: Table with columns: Channel | Purpose | Trigger | Format. Include 4+ channels (ticket system, team channel, stakeholder channel, status meeting/doc)
4. **Drafts**: Table with columns: Date | Channel | Draft | Status. Include note about expanding drafts inline for review with HTML comments showing format
5. **Log**: Per-channel sections with tables (Date | Summary columns) showing communication history

**Format notes**:
- Use HTML comments extensively for inline documentation (`<!-- ... -->`)
- Include example placeholders: `{Project Name}`, `{Channel}`, `{YYYY-MM-DD}`
- Signal gate is the most critical section — emphasize event-driven vs time-driven
- Hierarchy rule prevents duplication noise

### 6. requirements.md

**When to use**: Front-half authoring, spec `reqs` mode. Complex-tier subjects; interview-first (resolve open questions via `AskUserQuestion` before drafting the design).

**Essential sections**:
1. **Header**: blockquote with Tier, Author, Date, Status
2. **Summary**: 1-3 sentences (what this delivers and why)
3. **Functional Requirements**: stable `FR-N` bullet IDs — never renumber; referenced by the design doc and by plan tasks
4. **Non-Functional Requirements**: stable `NFR-N` IDs, with measurable targets where possible
5. **Out of Scope**: explicit exclusions
6. **Open Questions**: checkbox list with owner/decision; resolved by interview before the design is built on assumptions
7. **End-to-End Verification**: the single check that proves the finished feature works (feeds the plan's per-task verification commands)
8. **Metadata**: Author, Reviewer(s), Related links

**Format notes**:
- Stable IDs are load-bearing (graduation + cross-reference); emphasize "never renumber"
- Placeholders in `{BRACES}`; instructional `<!-- HTML comments -->`

### 7. design.md

**When to use**: Front-half authoring, spec `design` mode. Moderate/Complex; architecture derived from requirements (Complex) or design-first (Moderate).

**Essential sections**:
1. **Header**: blockquote with Tier, Author, Date, Requirements link
2. **Summary**: 2-3 sentences
3. **Requirements Satisfied**: trace each design element to the `FR-N`/`NFR-N` it satisfies; flag any requirement the design cannot meet back to reqs
4. **Architecture**: name concrete files/modules, interfaces/contracts, data/state; optional mermaid diagram
5. **Key Decisions**: table — Decision | Chosen | Alternatives rejected | Why
6. **Out of Scope**: exclusions
7. **Open Questions**: checkbox list
8. **Verification Approach**: how the implemented design is proven (source for the plan's per-task verify commands)

**Format notes**:
- Self-contained: a cold session must be able to act from the Architecture section
- Use a mermaid code block for the diagram; `{BRACES}` placeholders

### 8. implementation-plan.md

**When to use**: Front-half authoring, spec `plan` mode. Simple and above; decompose the design into review-sized tasks, then graduate to the backlog (Step G).

**Essential sections**:
1. **Header**: blockquote with Tier, Author, Date, Design link
2. **Summary**: 2-3 sentences
3. **Tasks**: `### T-<subject>-NN` entries — stable IDs (never renumber; they are the graduation keys). Each task carries `blockedBy`, `verify` (exact executable definition-of-done command), `size`, optional `priority`, one-line scope
4. **Critical Path**: ordered T-IDs — drives the derived priority band at graduation
5. **Risk Register**: table — Risk | Likelihood | Impact | Mitigation
6. **Live-State Reconciliation**: checkbox to re-verify cited PRs/live state at each task kickoff
7. **Graduation Record**: table — Task | Backlog id | Status — bidirectional `T <-> backlog id` link written by Step G; re-graduation (refresh) syncs it by `Source:` back-ref

**Format notes**:
- Every task MUST carry a `verify:` command (the definition-of-done); this is the single highest-leverage field
- Warn/split tasks over ~1.5-2 dev-days so each maps to one PR
- Task IDs and the Graduation Record are the wiring into `D56` § Backlog Graduation — keep the shape exact

### 9. backlog.md

**When to use**: Seed shape for a project's `.claude/BACKLOG.md` in file-backed mode — the canonical single-sourced, workstream-first item schema. Copied into `.claude/` and grown in place; graduation (spec skill), the task lifecycle (run-task/cycle Deliver), save-session (audit), and backlog-compact (rewrite) all read/write this exact shape. Canonical spec: `D56-commands-automation.md` § Backlog Item Schema and Single-Source Discipline — read it before generating.

**Essential sections**:
1. **Header**: blockquote stating the prefix scheme (`<PREFIX>-NNN`, stable, never renumbered), the item format, the `Urgency` vocabulary (`currently-blocking` / `eventual-blocker` / `aspirational` / `dated <YYYY-MM-DD>`), and the freshness rule (any external-state `Status` carries a `verified <YYYY-MM-DD>` stamp; un-dated is suspect)
2. **Single-source discipline note** (HTML comment): a fact about external state (PR/branch/ticket) is asserted in exactly ONE place — the owning item's `Status` line; every other table references the item by id, never restates the state. Point, do not duplicate. Narrative lives in commits/PR/session.md, not the item. Compaction trigger at ~500-600 lines
3. **Workstreams index**: table — WS (anchor link) | Goal | Current bottleneck | Items (id pointers only, NOT a status cache)
4. **Per-workstream sections**: `<a id="ws-x">` anchor + `### WS-X — {name}` + a `> Goal / Sequencing` blockquote, then the workstream's items
5. **Per open item**: `- **<PREFIX>-NNN** — {title} [subject: {tag}] (added {date})` with sub-bullets `Status` (single authoritative state + `verified <date>`), `Urgency` (vocabulary + one-line justification), `AC` (definition of done; graduated `verify:` command lands here), `Links` (deps + external artifacts as references), optional `Source:` (graduation back-ref), optional `Context`
6. **Open PR Register** (optional): dated-snapshot table for open PRs with NO owning item; header states it is a snapshot, not live-authoritative, and the owning item's Status wins on disagreement
7. **Completed / Retired**: closed items collapsed to one-line markers

**Format notes**:
- The single-source discipline and the `verified <date>` stamp are the load-bearing conventions — emphasize them; they are what make the file a source of truth rather than a drifting cache
- The template must MODEL the compact discipline it preaches — keep it tight, use `{BRACES}` placeholders and instructional `<!-- HTML comments -->`, no multi-paragraph example items
- Org-neutral: no org-specific repos, tracker keys, or URLs (Axiom 7); use generic `{org/repo#N}` / `<PREFIX>-NNN` placeholders
- Item ids and the workstream/single-source shape are the wiring into `D56` § Backlog Item Schema — keep it exact so graduation, delivery, audit, and compaction interoperate

## Format Requirements

Each template must:
1. Include instructional comments where helpful (using HTML comments or markdown blockquotes)
2. Use placeholder text in `{BRACES}` or `[BRACKETS]` to indicate user-customizable content
3. Use consistent heading levels (# for title, ## for major sections, ### for subsections)
4. Include example values where they clarify the format
5. Match the tone of the source files (instructional, clear structure, practical)

## Verification

After generation, verify each template:

1. **Section completeness**: All essential sections from spec present
2. **Format consistency**: Tables have correct columns, placeholders are clearly marked
3. **Practical usability**: Template can be copied and filled out without confusion
4. **Example quality**: Example values clarify without over-specifying
5. **Comment clarity**: Instructional comments add value without cluttering

## Dependencies

- **Step 01** (CLAUDE.md) must be complete — defines when templates are used (e.g., retrospective required for Complex tier)
- **Step 04** (reference files) must be complete — templates are referenced in workflow-stages.md and project-scaffolding.md

Consumers:
- **Step 06** (skills) consumes the three front-half templates — the spec skill's `reqs`/`design`/`plan` modes reference `${CLAUDE_PLUGIN_ROOT}/templates/{requirements,design,implementation-plan}.md`, and `implementation-plan.md`'s `T-<subject>-NN` task shape is what Backlog Graduation (Step G) reads. Step 06 also consumes `templates/backlog.md`: the `backlog-compact` skill rewrites to it, `workstream-new` scaffolds its workstream shape, and graduation writes items in it — all four skills that touch the backlog (`spec`, `cycle`, `run-task`, `backlog-compact`) share this schema.
