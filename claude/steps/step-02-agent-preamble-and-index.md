# Generation Prompt: Step 02 — Agent Preamble and Index

**Purpose**: Generate the shared agent infrastructure files (preamble and index).

---

## Input

### Specification Files
Read these spec files before generating:
- `D16-agent-system.md` — Complete specification for agent profile system

### Reference Files

> **Note**: `{OJ_SOURCE}` refers to the root of the original OpenJunto repository. If available locally, these reference files provide format verification against the canonical implementation.

- `{OJ_SOURCE}/agents/_preamble.md` (actual preamble for structure comparison)
- `{OJ_SOURCE}/agents/index.md` (actual index for structure comparison)

---

## Task

Generate the following artifacts:

### 1. Agent Preamble (`agents/_preamble.md`)

Generate the shared context file loaded before every full profile.

**File location**: `agents/_preamble.md` (at plugin root, plugin-tree-direct layout)

**Size**: ~2-3KB

### 2. Agent Index (`agents/index.md`)

Generate the central reference file containing the expert roster, selection guide, and profile structure documentation.

**File location**: `agents/index.md` (at plugin root, plugin-tree-direct layout)

**Size**: ~4-5KB

---

## Key Requirements

### EXACT Elements

#### Brand Identity (in preamble and index)
Use **"OpenJunto"** as the product/system name in all user-facing prose (e.g., "the OpenJunto coordination system", "OpenJunto Expert Agent Coordination System"). Do NOT emit bare "Junto" as a product name (preserved only in historical references to Franklin's Junto). Technical identifiers use the lowercase `oj-` prefix (`oj-helper`, `oj-expert` HTML marker, `OJ_DEVMODE`, `{OJ_SOURCE}`) and MUST be preserved verbatim. This distinction exists because the installed binary, hook markers, and env var names are part of the tool contract and are tracked separately from the human-readable product name. The generated helper accepts the legacy `junto-expert` HTML marker, `JUNTO_DEVMODE`, `JUNTO_HOOK_DEBUG`, and `{JUNTO_SOURCE}` placeholder as backward-compat fallbacks for one release.

#### Plugin-Internal Reference Form (MANDATORY for agents/index.md)

The source file `{OJ_SOURCE}/agents/index.md` uses `~/.claude/<path>` literals to reference other plugin-internal files (e.g., `` `~/.claude/reference/stakeholder-guide.md` ``). Those paths are correct for the manager-side authoring install, but they are WRONG for plugin-installed adopters — `~/.claude/` resolves to the adopter's HOME, not the plugin tree.

**During emission**, rewrite every `~/.claude/<path>` literal in the generated `agents/index.md` to `${CLAUDE_PLUGIN_ROOT}/<path>`. This is a transform-not-copy operation: do NOT preserve the source's `~/.claude/` form. The `${CLAUDE_PLUGIN_ROOT}` token is resolved by the Claude Code plugin host at session load and is the only adopter-portable form.

Correct emitted forms (rewrite `~/.claude/` source paths to these):

- `` `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/agents/_preamble.md` ``
- `` `${CLAUDE_PLUGIN_ROOT}/agents/*-compact.md` ``

This rule mirrors the canonical contract documented in step-01 (Plugin-Internal Reference Format). Tier A Assertion 19 enforces a zero-`~/.claude/`-literal invariant across the scoped plugin tree (CONDUCTOR.md, agents/*.md, reference/*.md, docs/**/*.md, skills/*/SKILL.md); failure to apply the transform causes the assertion to FAIL with FILE:LINE diagnostics.

#### PERSPECTIVE Block Format (in preamble)
Must appear verbatim:
````
```
PERSPECTIVE: [Stakeholder] ([profile].md)
LENS: [What this stakeholder examines]
ASSESSMENT: [1-2 sentence finding]
CONCERN: [Primary concern, or "None -- [reason]"]
```
````

#### AI Agent Context (in preamble)
Five key implications must be listed:
- No persistent memory between sessions
- Simultaneous availability for parallel engagement
- Consistent, deterministic behavior
- No real-world relationships or industry connections
- Bounded knowledge from training data, not lived experience

#### 16-Section Profile Template (in preamble)
Must list all 16 sections in order:
1. Role Identity
2. Core Expertise
3. Key Responsibilities
4. Decision-Making Authority
5. Collaboration Style
6. Inter-Expert Collaboration
7. Tier-Specific Behavior
8. Quality Standards
9. Communication Patterns
10. Red Flags You Watch For
11. Limitations & Blind Spots
12. Key Questions You Ask
13. Common Patterns You Recommend
14. When NOT to Engage
15. Engagement Triggers
16. Success Indicators

#### Mandatory Pair (in index)
Exact table with tie-breaker authority:

| Stakeholder Perspective | File | Primary Purpose | Tie-Breaker Authority |
|---|---|---|---|
| Senior Distinguished Engineer | senior-distinguished-engineer.md | Technical strategy, architecture, risk | Technical decisions |
| Senior Product Manager | senior-product-manager.md | Business alignment, prioritization, scope | Business priorities |

---

### STRUCTURAL Elements

#### Preamble Organization
Five major sections:
1. **AI Agent Context** — 5 key implications
2. **Organizational Standards Reference** — Points to organizational-standards.md (if present), lists 2 categories (Core Technical Principles, Fellow-Level Leadership Behaviors)
3. **Inline Perspective Context** — Explains Simple tier use case, includes PERSPECTIVE block format
4. **Standard Profile Structure** — Lists all 16 sections
5. **Handback Protocol Reference** — Points to CLAUDE.md for formats

#### Index Organization
Seven major sections:
1. **Overview** — Purpose and AI agent nature
2. **Quick Reference** — Two tables (Mandatory Stakeholders + Domain Experts)
3. **Expert Selection Guide** — Problem type mapping table
4. **Stakeholder Engagement by Execution Model** — Three-tier table
5. **Profile Structure** — Lists all 16 sections
6. **Compact Profiles** — When to use, structure, what's omitted
7. **Maintenance** — When and how to update profiles

#### Domain Experts Table (in index)
14 domain experts listed with:
- Expert name
- File name
- Primary purpose
- Engagement trigger

The 14 domain experts are:
1. Senior Security Engineer
2. Senior Data Architect
3. Senior Solutions Architect
4. Senior DevOps Engineer
5. Senior Data Scientist
6. Senior ML Engineer
7. Senior Enterprise Architect
8. Senior Business Analyst
9. Senior Technical Writer
10. Senior Engineering Consultant
11. Senior Executive Leadership Coach
12. Senior Test Engineer
13. Senior Site Reliability Engineer
14. Senior Software Engineer

#### Expert Selection Guide (in index)
Problem type mapping table with 4 columns:
- Problem Type
- Primary Expert
- Supporting Experts
- Cross-Cutting Reviewer

**CRITICAL**: Cross-cutting reviewer is ALWAYS from a different domain than the primary expert. Examples:
- Architecture decisions → Security Engineer reviews
- Security concerns → Solutions Architect reviews
- Data system design → Security Engineer reviews

---

### DESIGN INTENT Elements

#### AI Agent Caveats
Emphasize the limitations clearly:
- Agents are AI personas, not human consultants
- They provide consistent profile-driven guidance without persistent memory
- Recommendations may require validation against actual organizational constraints
- Expertise is bounded by training data

#### Organizational Standards
Reference organizational-standards.md gracefully:
- If present, provides quality bar (Core Technical Principles, Fellow-Level Leadership Behaviors)
- If absent, system degrades gracefully
- Standards are applied as quality bar, not memorized

#### Compact Profiles Rationale
Token optimization for Simple tier:
- 80% size reduction (~2KB vs. ~10KB)
- Retains essential adversarial elements
- Omits collaboration tables, detailed patterns, tier-specific behaviors
- When to use: Simple tier inline perspective rotation
- When NOT to use: Moderate/Complex tier (use full profiles)

#### Cross-Cutting Review Principle
Same-domain review creates echo chambers. Cross-domain review surfaces blind spots:
- Security reviewing architecture → surfaces trust boundaries
- SRE reviewing data pipelines → surfaces operational toil
- Test Engineer reviewing product features → surfaces testability gaps

#### Tie-Breaker Authority Principle
Deadlocks need deterministic resolution:
- Technical deadlock → Distinguished Engineer decides
- Business priority deadlock → Product Manager decides
- Mixed deadlock → Escalate to user with both positions

---

## Verification

After generation, verify:

### File Existence
- [ ] `agents/_preamble.md` exists at plugin root
- [ ] `agents/index.md` exists at plugin root

### Preamble Structure
- [ ] Contains 5 major sections
- [ ] AI Agent Context lists 5 key implications
- [ ] PERSPECTIVE block format present verbatim
- [ ] 16-section profile template listed in order
- [ ] Points to organizational-standards.md (graceful reference)
- [ ] Points to CLAUDE.md for handback protocol

### Index Structure
- [ ] Contains 7 major sections
- [ ] Mandatory stakeholder table present (2 rows with tie-breaker authority column)
- [ ] Domain experts table present (14 rows)
- [ ] Expert Selection Guide table present (problem type mappings with cross-cutting reviewers)
- [ ] Stakeholder Engagement by Execution Model table present (3 tiers)
- [ ] Profile structure section lists all 16 sections
- [ ] Compact profiles section explains when to use and what's omitted

### Content Accuracy
- [ ] 16 profile sections match specification exactly
- [ ] All 14 domain experts listed by name
- [ ] Mandatory pair (Distinguished Engineer + Product Manager) present
- [ ] Cross-cutting reviewer principle documented (different domain from primary)
- [ ] Tie-breaker authority documented for mandatory pair
- [ ] Compact profile structure documented (6 retained elements)

### Cross-References
- [ ] Preamble references organizational-standards.md
- [ ] Preamble references CLAUDE.md
- [ ] Index references stakeholder-guide.md
- [ ] Index references compact profiles via flat `${CLAUDE_PLUGIN_ROOT}/agents/*-compact.md` suffix (NO nested `agents/compact/` subdirectory; the flat layout is the post-BL-025-i.1 contract)
- [ ] All plugin-internal cross-references in index use `${CLAUDE_PLUGIN_ROOT}/...` form, NOT `~/.claude/...` (Tier A Assertion 19 invariant)

---

## Dependencies

**Requires**: Step 01 complete (project structure created)

---

## Output

After completing this step, you will have:
- Agent preamble (`agents/_preamble.md`, ~2-3KB)
- Agent index (`agents/index.md`, ~4-5KB)

These outputs are required inputs for step 03 (agent profile generation).
