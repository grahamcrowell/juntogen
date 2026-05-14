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
├── agents/                      (16 full + 16 *-compact.md profiles; flat layout)
├── templates/                   (5 deliverable templates)
├── skills/                      (5 SKILL.md files in directory-per-skill form)
└── reference/                   (8 reference files)
```

Compact profiles use the flat `*-compact.md` suffix at `agents/` root — there is no nested `agents/compact/` subdirectory in plugin form.

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

- `` `${CLAUDE_PLUGIN_ROOT}/agents/index.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/agents/_preamble.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/agents/*-compact.md` ``
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

**Your responsibilities:** Coordinate expert agents to review and improve work. Maintain and prioritize the backlog (issue tracker when configured, or `.claude/BACKLOG.md`). Ensure peer review on all Moderate/Complex work. Drive consensus while capturing dissenting views. Conduct retrospectives for Complex engagements. Prompt the user for decisions. Select appropriate stakeholder perspectives using `${CLAUDE_PLUGIN_ROOT}/agents/index.md`.
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

**Scoring**: 0-1 = Simple (inline), 2-3 = Moderate (Consult primitive), 4 = Complex (Convene primitive)
```

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

#### Spawn Formats (Section 4 — Moderate Tier)
All three phase formats must match specification exactly:
- Phase 1: `<!-- oj-expert: [profile-filename] -->` marker + stakeholder analysis instructions
- Phase 2: Lead implementation with synthesized findings
- Phase 3: Adversarial review with failure mode testing

#### Handback Formats (Section 5)

Each format is preceded by a section header and a [EXACT] anchor line (the literal text immediately before the fenced code block). These anchors are load-bearing — validation scripts locate the handback fenced blocks by matching these anchors, so the generator MUST emit them verbatim.

**Simple Tier Format**:

Under `### Simple Tier Format`, emit this anchor line verbatim (character-for-character, including the tilde and trailing colon):

```
Compressed format (~5 lines):
```

Immediately after the anchor line (with one blank line between), emit a fenced code block containing the 5-field compressed handback:

````
```
HANDBACK: [Role] | STATUS: [Complete|Iterate|Blocked|Escalate] | CONFIDENCE: [High|Med|Low]
DELIVERABLE: [What was produced]
RECOMMENDATION: [1-2 sentences including rationale]
STRONGEST OBJECTION: [Best counterargument]
NEXT: [Actions]
```
````

**Moderate/Complex Tier Format**:

Under `### Moderate/Complex Tier Format`, emit this anchor line verbatim (character-for-character, including the parenthesized field count and trailing colon):

```
Full format (9 fields):
```

Immediately after the anchor line (with one blank line between), emit a fenced code block containing the 9-field full handback (HANDBACK, STATUS, DELIVERABLE, RECOMMENDATION, RATIONALE, STRONGEST OBJECTION, FALSIFIER, CONFIDENCE, CAVEATS, NEXT ACTIONS — exactly as specified in `D40-quality-framework.md` § Handback Protocol).

**Both anchor lines are [EXACT]**: "Compressed format (~5 lines):" and "Full format (9 fields):" must appear verbatim in the generated CLAUDE.md. Do not paraphrase to "5-line compressed format" or "9-field full format" — validation scans the literal anchor text before the fenced block.

#### Quality Gate Counts (Section 6)
- Simple Tier: **2 items**
- Moderate Tier: **6 items**
- Complex Tier: **9 items**

#### Model Selection Table (Section 7)
Three models with exact when-to-use criteria and examples. **[EXTERNAL]** — render from `platform-snapshot.yaml` `models` section rather than hardcoding model names and cost ratios. The symbolic ids (`haiku`, `sonnet`, `opus`) and their tier mappings (`routine`, `implementation`, `reasoning`) are platform facts from Layer 0. The human-readable when-to-use descriptions and task examples are [DERIVED] from Chain 7 (capability-cost optimization) and may be authored inline.

#### Tier-Aware Context Loading Table (Section 9)
Three tiers with exact loading instructions.

#### Reference Files Table (Section 9)
8 reference files with exact names and content descriptions.

#### Templates Table (Section 9)
5 templates with exact names and when-to-use descriptions.

---

### STRUCTURAL Elements (Required Organization)

#### Section Organization
CLAUDE.md must contain these 10 major sections in order:
1. Role Declaration
2. Absolute Constraints (4 subsections: Delegation Boundary, Triage Requirement, Circuit Breaker, External Artifact Hygiene)
3. Two-Dimensional Triage (2 subsections: A. Execution Model, B. Stakeholder Identification)
4. Execution Models (3 subsections: Simple, Moderate, Complex)
5. Handback Protocol (formats, status, confidence, calibration)
6. Quality Gates (3 subsections: Simple/Moderate/Complex tiers)
7. Agent Spawning (2 subsections: Spawning Pattern, Model Selection)
8. Stakeholder Perspectives (mandatory pair + domain stakeholders)
9. Reference and Operations (3 subsections: issue tracker Bootstrap, Tier-Aware Context Loading, Reference Files, Templates)
10. Definition of Done (4 subsections: Simple/Moderate/Complex tiers, Verifying Deliverables, Incorporating Lessons)

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

---

## Verification

After generation, verify:

### File Structure
- [ ] `CONDUCTOR.md` exists at plugin root
- [ ] `agents/` directory exists at plugin root (empty at this stage)
- [ ] `templates/` directory exists at plugin root (empty at this stage)
- [ ] `skills/` directory exists at plugin root (empty at this stage)
- [ ] `reference/` directory exists at plugin root (empty at this stage)
- [ ] NO `src/` wrapper directory exists (plugin host loads directly from plugin root)
- [ ] NO `agents/compact/` subdirectory exists (compact profiles use flat `*-compact.md` suffix at `agents/` root)

### CONDUCTOR.md Structure
- [ ] Contains all 10 major sections in correct order
- [ ] Opening lines match specification exactly (role declaration)
- [ ] Self-Check questions present verbatim (3 questions)
- [ ] Circuit breaker triggers present (3 revisions, 2 hours, deadlock, scope)
- [ ] Adaptive signals table present (3 rows)
- [ ] Triage criteria table present (4 criteria with checkboxes)
- [ ] Domain signals table present (9 rows)
- [ ] PERSPECTIVE block format present verbatim
- [ ] All three spawn formats present (Phase 1/2/3 for Moderate tier)
- [ ] Both handback formats present (Simple compressed + Moderate/Complex full)
- [ ] Quality gate counts correct: Simple (2), Moderate (6), Complex (9)
- [ ] Model selection table present with entries matching `platform-snapshot.yaml` model roster (verify symbolic ids, tiers, and cost ratios — do not hardcode haiku/sonnet/opus as pass criteria)
- [ ] Tier-aware context loading table present (3 tiers)
- [ ] Reference files table present (8 files)
- [ ] Templates table present (5 templates)

### Format String Accuracy
- [ ] All [EXACT] items from specification reproduced character-for-character
- [ ] Thresholds match: 0-1/2-3/4 scoring, 4+/5+ stakeholder escalation
- [ ] Quality gate item counts match exactly

### Cross-References
- [ ] Generated CONDUCTOR.md contains ≥1 reference using `${CLAUDE_PLUGIN_ROOT}/` syntax for plugin-internal files (`agents/`, `reference/`, `skills/`, `templates/`, `hooks/`, `bin/`, `docs/`)
- [ ] Generated CONDUCTOR.md contains ZERO `~/.claude/` references (legacy adopter-HOME form is banned for plugin-internal paths)
- [ ] Generated CONDUCTOR.md contains ZERO bare relative plugin-internal paths (e.g., `` `agents/index.md` ``, `` `reference/stakeholder-guide.md` `` without the `${CLAUDE_PLUGIN_ROOT}/` prefix)
- [ ] References to `${CLAUDE_PLUGIN_ROOT}/agents/index.md` present
- [ ] References to `${CLAUDE_PLUGIN_ROOT}/reference/` files present
- [ ] References to `.claude/BACKLOG.md` present (project-local — keep as-is, not plugin-internal)
- [ ] References to `oj-helper` commands present

---

## Dependencies

**Requires**: Step 00 complete (`platform-snapshot.yaml` available for model selection table rendering)

---

## Output

After completing this step, you will have:
- Plugin-tree-direct directory structure (`agents/`, `templates/`, `skills/`, `reference/` at plugin root)
- Complete manager protocol (`CONDUCTOR.md` at plugin root, ~10KB)

These outputs are required inputs for steps 02 and 03.
