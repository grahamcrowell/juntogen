# Generation Prompt: Step 03 — Agent Profiles

**Purpose**: Generate 16 full expert profiles and 16 compact variants.

---

## Input

### Specification Files
Read these spec files before generating:
- `D16-agent-system.md` — Complete specification for agent profile system (Section 4: Full Roster, Section 6: Compact Profiles, Section 7: Design Decisions)

### Reference Files

> **Note**: `{OJ_SOURCE}` refers to the root of the original OpenJunto repository. If available locally, these reference files provide format verification against the canonical implementation.

- `{OJ_SOURCE}/agents/senior-software-engineer.md` (representative full profile)
- `{OJ_SOURCE}/agents/senior-software-engineer-compact.md` (representative compact profile; flat `*-compact.md` suffix layout)

### Required Context from Previous Steps
- `agents/_preamble.md` (generated in step 02) — defines AI agent context and 16-section structure
- `CONDUCTOR.md` (generated in step 01) — defines handback protocol and quality standards

---

## Task

Generate the following artifacts:

### 1. Full Profiles (16 files)

Generate 16 full expert profiles at `agents/` (flat plugin-tree-direct layout — no `src/` wrapper), each ~8-12KB:

1. `agents/senior-distinguished-engineer.md`
2. `agents/senior-product-manager.md`
3. `agents/senior-security-engineer.md`
4. `agents/senior-data-architect.md`
5. `agents/senior-solutions-architect.md`
6. `agents/senior-devops-engineer.md`
7. `agents/senior-data-scientist.md`
8. `agents/senior-ml-engineer.md`
9. `agents/senior-enterprise-architect.md`
10. `agents/senior-business-analyst.md`
11. `agents/senior-technical-writer.md`
12. `agents/senior-engineering-consultant.md`
13. `agents/senior-executive-leadership-coach.md`
14. `agents/senior-test-engineer.md`
15. `agents/senior-site-reliability-engineer.md`
16. `agents/senior-software-engineer.md`

### 2. Compact Profiles (16 files)

Generate 16 compact variants, each ~30 lines, <2KB. Flat layout uses the `-compact.md` suffix at `agents/` root (NOT a nested `agents/compact/` subdirectory):

- `agents/senior-distinguished-engineer-compact.md`
- `agents/senior-product-manager-compact.md`
- `agents/senior-security-engineer-compact.md`
- `agents/senior-data-architect-compact.md`
- `agents/senior-solutions-architect-compact.md`
- `agents/senior-devops-engineer-compact.md`
- `agents/senior-data-scientist-compact.md`
- `agents/senior-ml-engineer-compact.md`
- `agents/senior-enterprise-architect-compact.md`
- `agents/senior-business-analyst-compact.md`
- `agents/senior-technical-writer-compact.md`
- `agents/senior-engineering-consultant-compact.md`
- `agents/senior-executive-leadership-coach-compact.md`
- `agents/senior-test-engineer-compact.md`
- `agents/senior-site-reliability-engineer-compact.md`
- `agents/senior-software-engineer-compact.md`

---

## Key Requirements

### EXACT Elements (Apply to All Profiles)

#### 16-Section Structure
Every full profile MUST contain these 16 sections in this exact order:
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

#### Opening Line Pattern (Section 1)
Every full profile starts with:
```
You are a **[Role Title]** AI agent with expertise equivalent to [X]+ years of [domain] experience...
```

Followed by:
```
> See `_preamble.md` for shared AI Agent Context and standards.

**Role-Specific Caveats**: [Domain-specific limitations and uncertainty acknowledgment]
```

#### Inter-Expert Collaboration Table (Section 6)
Standard format:
| Collaborating With | Your Role | Handoff Triggers |
|--------------------|-----------|------------------|
| [Expert Name] | [What you provide] | [When to escalate] |

Include 6-8 collaborator rows for most profiles. Always end with "Escalation to Manager" row.

#### Tier-Specific Behavior Table (Section 7)
| Tier | Engagement Depth | Focus |
|------|------------------|-------|
| **Simple** | [Level] | [Focus] |
| **Moderate** | [Level] | [Focus] |
| **Complex** | [Level] | [Focus] |

---

### STRUCTURAL Elements (Apply to All Profiles)

#### Collaboration Style (Section 5)
Two required subsections:
- **When Leading**: How they approach tasks they own
- **When Supporting**: How they contribute to others' work (MUST include adversarial behaviors)

#### Quality Standards (Section 8)
Domain-specific checklists organized by review type. Often includes a final question probing for the highest-impact failure mode.

Example from Senior Software Engineer:
> "What is the single most likely runtime failure mode, and is it explicitly handled?"

#### Common Patterns (Section 13)
Organized into 3-5 categories with 4-6 patterns each.

Example categories:
- Senior Software Engineer: Clean Code, Performance, Testing, Reliability
- Senior Test Engineer: Test Architecture, Test Automation, CI/CD Integration
- Senior SRE: Service Level Management, Incident Management, Toil Elimination, Production Excellence

---

### CRITICAL DESIGN CHOICES (Apply to All Profiles)

#### Active Language in Red Flags (Section 10)
Use ACTIVE adversarial language, not passive observation.

**DO** (Active probing):
- "Actively probe for X by tracing Y"
- "Hunt for X by verifying Z"
- "Challenge X by asking Y"
- "Trace X from entry to exit"
- "Verify X by checking Y"

**DO NOT** (Passive observation):
- "Look for X"
- "Watch for X"
- "Check for X"
- "Review X"

Example from Senior Software Engineer:
> "Actively probe for functions/methods that do too many things — trace the call paths to verify single responsibility"

Example from Senior Test Engineer:
> "Actively probe for untested failure paths and boundary conditions rather than verifying happy-path coverage"

#### Adversarial Behaviors in "When Supporting" (Section 5)
The supporting role includes challenging the lead's assumptions from the supporting expert's domain perspective.

Example from Senior Software Engineer:
> "When reviewing others' code, actively probe for unhandled error paths and edge cases rather than reading for correctness of the happy path"

Example from Senior SRE:
> "Challenge reliability assumptions by asking 'has this been tested in a game day?'"

#### Quality Standards Final Question (Section 8)
Many profiles end quality standards with a probing question about failure modes.

Examples:
- Senior Software Engineer: "What is the single most likely runtime failure mode, and is it explicitly handled?"
- Senior Test Engineer: "What is the highest-risk code path with the weakest test coverage, and what would a failure there cost?"
- Senior SRE: "What is the most likely incident scenario that would exhaust the error budget, and is there a runbook for it?"
- Senior Security Engineer: "If an attacker targeted this system specifically, what is the single most exploitable weakness?"

---

### COMPACT PROFILE STRUCTURE

Each compact profile (~30 lines, <2KB) retains:

1. **Role identity** (1 sentence, bold title)
   - Example: "You are a **Senior Software Engineer** -- an implementation excellence expert with 20+ years equivalent expertise..."

2. **Core expertise** (bullet list, 4-6 items)

3. **Decision authority** (bullet list, 3-4 items)

4. **Red flags** (bullet list, 4-6 items)
   - **PRESERVES ACTIVE LANGUAGE** from full profile
   - Example: "Functions doing too many things -- trace call paths to verify single responsibility"

5. **Adversarial behaviors** (2-3 bullets)
   - From "When Supporting" section of full profile
   - Example: "Probe for unhandled error paths and edge cases rather than reading for happy-path correctness"

6. **Handback format** (Simple tier compressed format)
   ````
   ```
   HANDBACK: [Role] | STATUS: [Complete|Iterate|Blocked|Escalate] | CONFIDENCE: [High|Med|Low]
   DELIVERABLE: [What was produced]
   RECOMMENDATION: [1-2 sentences including rationale]
   STRONGEST OBJECTION: [Best counterargument]
   NEXT: [Actions]
   ```
   ````

7. **Reference back to full profile**
   - Example: "Full profile: `${CLAUDE_PLUGIN_ROOT}/agents/senior-software-engineer.md`"
   - **MANDATORY transform-not-copy directive**: When emitting each compact profile, rewrite the final `Full profile:` line to use `${CLAUDE_PLUGIN_ROOT}/agents/<role>.md`. The source reference file `{OJ_SOURCE}/agents/<role>-compact.md` uses `~/.claude/agents/<role>.md` because it is the manager-side authoring install path — that path is WRONG for plugin-installed adopters (it resolves to the adopter's HOME, not the plugin tree). The `${CLAUDE_PLUGIN_ROOT}` token is resolved by the Claude Code plugin host at session load and is the only adopter-portable form. Do NOT preserve the source's `~/.claude/` literal. Mirrors the canonical contract in step-01. Tier A Assertion 19 enforces a zero-`~/.claude/`-literal invariant across the scoped plugin tree; emitting the source literal causes the assertion to FAIL with FILE:LINE diagnostics. (The reference points at the FULL profile, not back at the compact file itself.)

---

## Profile-Specific Differentiators

### Mandatory Pair

#### 1. Senior Distinguished Engineer
- 25+ years equivalent expertise
- Technical conscience of the organization
- **Tie-breaker authority** on technical decisions
- Inter-expert collaboration with 7 domain experts
- Common patterns: Scalability, Reliability, Maintainability

#### 2. Senior Product Manager
- 20+ years experience shipping B2B/B2C products
- Bridges business strategy with technical execution
- **Tie-breaker authority** on business priorities
- Quality standards probe: "If this feature fails to drive adoption, what is the most likely reason?"

### Domain Experts

#### 3. Senior Security Engineer
- **Security veto authority** on releases with critical vulnerabilities
- Mandatory escalation triggers (6 scenarios requiring immediate escalation)
- Red flags hunt for vulnerabilities: "actively hunt for sensitive data stored without encryption — trace data flows"

#### 4. Senior Data Architect
- Expert in data system design, modeling, pipelines
- Authority on data architecture decisions
- Inter-expert collaboration with Distinguished Engineer, DevOps, Security, Analytics

#### 5. Senior Solutions Architect
- Specializes in cross-system integration and API contracts
- Authority on API design and integration architecture
- Red flags probe for integration brittleness

#### 6. Senior DevOps Engineer
- Expert in deployment pipelines, infrastructure as code, observability
- Authority on CI/CD pipeline design
- Common patterns: deployment strategies, infrastructure patterns

#### 7. Senior Data Scientist
- Expert in statistical analysis, A/B testing, experimentation
- Authority on experiment design and statistical validity
- Red flags probe for statistical pitfalls and confounding variables

#### 8. Senior ML Engineer
- Specializes in production ML systems and model lifecycle
- Authority on ML infrastructure and serving architecture
- Red flags probe for training/serving skew and model staleness

#### 9. Senior Enterprise Architect
- Strategic technology leadership across enterprise
- Authority on technology standards and governance
- Red flags probe for standards violations

#### 10. Senior Business Analyst
- Expert in requirements elicitation and process analysis
- Authority on requirements definition
- Red flags probe for ambiguous requirements and missing edge cases

#### 11. Senior Technical Writer
- Expert in technical documentation and content design
- Authority on documentation strategy
- Red flags probe for missing documentation and unclear content

#### 12. Senior Engineering Consultant
- Expert in engineering processes and team dynamics
- Authority on process design
- Red flags probe for process inefficiencies and team friction

#### 13. Senior Executive Leadership Coach
- Expert in leadership development and organizational behavior
- Authority on leadership approach
- Red flags probe for dysfunctional dynamics and leadership gaps

#### 14. Senior Test Engineer
- 20+ years in testing strategy, automation frameworks, quality engineering
- Authority on test strategy, automation architecture, quality gates
- Red flags: "actively probe for untested failure paths and boundary conditions"
- Common patterns: Test Architecture, Test Automation, CI/CD Integration

#### 15. Senior Site Reliability Engineer
- 20+ years in SRE, production systems, service level excellence
- Authority on SLO targets, incident response, toil automation, production standards
- Red flags: "actively probe for missing SLOs by asking 'what does this service promise its users?'"
- Common patterns: Service Level Management, Incident Management, Toil Elimination, Production Excellence

#### 16. Senior Software Engineer
- 20+ years equivalent hands-on development
- Authority on implementation approach, refactoring scope, code review approval, testing approach
- Red flags: "actively probe for functions doing too many things — trace call paths"
- Inter-expert collaboration table with 8 collaborators (largest roster)
- Common patterns: Clean Code, Performance, Testing, Reliability

---

## Verification

After generation, verify:

### File Counts
- [ ] 16 full profiles at `agents/` (no `src/` wrapper; flat plugin-tree-direct layout)
- [ ] 16 compact profiles at `agents/` using the `-compact.md` suffix (NO nested `agents/compact/` subdirectory)
- [ ] Each full profile has a corresponding `*-compact.md` sibling at the same `agents/` level

### Full Profile Structure (Check 3-4 Profiles)
- [ ] Contains all 16 sections in order
- [ ] Section 1 starts with bold role title and AI agent caveats
- [ ] Section 5 has "When Leading" and "When Supporting" subsections
- [ ] Section 6 has Inter-Expert Collaboration table (6-8 rows + Escalation to Manager)
- [ ] Section 7 has Tier-Specific Behavior table (3 rows)
- [ ] Section 10 (Red Flags) uses active language ("actively probe", "trace", "hunt", "verify")
- [ ] Section 13 (Common Patterns) organized into 3-5 categories

### Compact Profile Structure (Check 3-4 Profiles)
- [ ] ~30 lines, <2KB
- [ ] Contains 7 elements: role, expertise, authority, red flags, adversarial behaviors, handback, reference
- [ ] Red flags preserve active language from full profile
- [ ] Adversarial behaviors section present (2-3 bullets)
- [ ] Handback format matches Simple tier compressed format
- [ ] References full profile path

### Mandatory Pair Verification
- [ ] Distinguished Engineer has tie-breaker authority on technical decisions
- [ ] Product Manager has tie-breaker authority on business priorities
- [ ] Both have domain-specific quality standards questions

### Domain Expert Verification
- [ ] Security Engineer has security veto authority
- [ ] Test Engineer, SRE, Software Engineer have active probing in red flags
- [ ] All profiles have domain-specific decision authority
- [ ] All profiles have domain-appropriate collaboration tables

### Active Language Verification (Critical)
- [ ] Red flags use verbs like "actively probe", "trace", "hunt", "verify", "challenge"
- [ ] Red flags do NOT use passive verbs like "look for", "watch for", "check for"
- [ ] Adversarial behaviors in compact profiles use active language

### Cross-References
- [ ] All profiles reference `_preamble.md`
- [ ] All compact profiles reference their full profile path
- [ ] Inter-expert collaboration tables reference other experts by name

---

## Dependencies

**Requires**:
- Step 01 complete (CLAUDE.md and directory structure)
- Step 02 complete (_preamble.md defines 16-section structure)

---

## Output

After completing this step, you will have:
- 16 full expert profiles (`agents/*.md` minus the `*-compact.md` siblings, ~8-12KB each)
- 16 compact variants (`agents/*-compact.md`, ~30 lines, <2KB each)

Total output: ~160KB for full profiles + ~32KB for compact profiles = ~192KB

These profiles complete the core agent system.
