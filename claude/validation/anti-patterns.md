# Anti-Patterns

Common LLM generation failures to detect and correct in an OpenJunto system generated from the juntospec specification.

---

## 1. Generic Profiles

### Description
All agent profiles sound the same. Missing domain-specific red flags. No differentiation between analyst/implementer/reviewer roles. Generic advice that could apply to any expert.

### Why It Happens
- LLM defaults to coherent but generic expertise
- Profile template applied mechanically without domain customization
- Red flags copied between profiles with light rewording
- "When Supporting" sections lack adversarial behaviors

### How to Detect

**Symptom 1: Identical Red Flags Across Domains**

Check 3-5 profiles randomly. If Security Engineer, DevOps Engineer, and Data Architect all have the same red flags (e.g., "Watch for performance issues", "Check scalability"), profiles are generic.

**Symptom 2: Passive Red Flags**

Red flags say "look for", "watch for", "be aware of" without active probing language. Example:
- ❌ "Watch for security vulnerabilities"
- ✅ "Actively hunt for authentication bypass via parameter tampering"

**Symptom 3: Missing Adversarial Language in "When Supporting"**

The "When Supporting" section should include adversarial behaviors. Example:
- ❌ "Review the proposal and provide feedback"
- ✅ "Actively probe for distributed bypass vectors the lead may have missed"

**Symptom 4: Generic Common Patterns**

Common Patterns section has generic advice instead of domain-specific reusable solutions. Example:
- ❌ "Use best practices" (generic)
- ✅ "Token bucket algorithm with Redis-backed counters for distributed rate limiting" (specific)

### How to Fix

**Step 1: Differentiate Red Flags by Domain**

For each profile, identify 6-8 domain-specific failure modes the expert actively hunts for.

Security Engineer example:
- Actively hunt for authentication bypass via JWT tampering
- Actively probe for SQL injection in all dynamic query construction
- Actively trace all paths that touch PII for encryption status
- Actively verify all external inputs are validated before reaching business logic

DevOps Engineer example (completely different):
- Actively hunt for single points of failure in deployment pipeline
- Actively probe for configuration drift between environments
- Actively trace all secret references to verify rotation is automated
- Actively verify all manual steps in runbooks can be eliminated

**Step 2: Add Adversarial Behaviors to "When Supporting"**

When Supporting section must include "actively probe" language:

```
When supporting another lead expert, I:
- Actively probe for [domain-specific failure mode]
- Challenge assumptions about [domain-specific risk]
- Test edge cases in [domain-specific area]
```

**Step 3: Populate Common Patterns with Specific Solutions**

Each profile should list 8-12 specific, reusable patterns from that domain:

Software Engineer example:
- Circuit breaker pattern (Hystrix, Resilience4j) for external service calls
- Saga pattern for distributed transactions
- CQRS with event sourcing for audit trails
- Blue/green deployment for zero-downtime releases

Data Architect example (completely different):
- Star schema for OLAP workloads with dimension tables
- Lambda architecture for batch + streaming data processing
- Change data capture (CDC) for real-time replication
- Slowly changing dimensions (Type 2) for historical tracking

**Step 4: Role-Specific Orientation Statements**

Verify orientation statement matches role type:
- **Analyst**: "Primary concern from my domain: [X]" (focus on domain risk)
- **Implementer**: "Highest-risk constraint: [X]" (focus on implementation risk)
- **Reviewer**: "Weakest current claim: [X]" (focus on adversarial angle)

### Test

After fix, compare 3 profiles side-by-side. Red flags should have ZERO overlap. Common patterns should be entirely domain-specific. "When Supporting" should include adversarial language unique to that domain.

---

## 2. Format Drift

### Description
PERSPECTIVE blocks, HANDBACK fields, quality gate formats vary from specification. Field names change. Line counts differ. Format becomes inconsistent across files.

### Why It Happens
- LLM paraphrases instead of copying format exactly
- Format templates split across multiple spec sections, LLM synthesizes incorrectly
- Inconsistent format strings in spec (spec bug, not generation bug)
- LLM "improves" format by adding fields or renaming for clarity

### How to Detect

**Symptom 1: PERSPECTIVE Block Format Variations**

Spec requires exactly 4 lines:
```
PERSPECTIVE: [Stakeholder] ([profile].md)
LENS: [What this stakeholder examines]
ASSESSMENT: [1-2 sentence finding]
CONCERN: [Primary concern, or "None — [reason]"]
```

Check CLAUDE.md, preamble, workflow-stages. If any variation exists (e.g., "FOCUS:" instead of "LENS:", or 3 lines instead of 4), format has drifted.

**Symptom 2: HANDBACK Field Name Changes**

Spec requires specific field names. If generated system has:
- "NEXT STEPS" instead of "NEXT ACTIONS"
- "FAILURE MODE" instead of "FALSIFIER"
- "OBJECTION" instead of "STRONGEST OBJECTION"
- Fields in different order
- Extra fields added

Format has drifted.

**Symptom 3: Quality Gate Count Mismatch**

Spec requires exact counts: Simple (2 items), Moderate (6 items), Complex (9 items).

Check:
- CLAUDE.md Quality Gates section
- quality-framework.md (if standalone reference file)
- worked-examples.md
- Retrospective template

If any location shows different counts (e.g., Moderate has 5 items instead of 6), format has drifted.

**Symptom 4: Triage Criteria Count Mismatch**

Spec requires exactly 4 criteria in execution model table. If CLAUDE.md has 3 or 5 criteria, format has drifted.

### How to Fix

**Step 1: Create Format Reference Card**

Extract exact format strings from spec into a reference document:

```
PERSPECTIVE Block (4 lines, exactly):
PERSPECTIVE: [Stakeholder] ([profile].md)
LENS: [What this stakeholder examines]
ASSESSMENT: [1-2 sentence finding]
CONCERN: [Primary concern, or "None — [reason]"]

Handback Simple Tier (5 fields):
HANDBACK: [Role] | STATUS: [Complete|Iterate|Blocked|Escalate] | CONFIDENCE: [High|Med|Low]
DELIVERABLE: [What was produced]
RECOMMENDATION: [1-2 sentences including rationale]
STRONGEST OBJECTION: [Best counterargument]
NEXT: [Actions]

Handback Moderate/Complex Tier (9 fields):
HANDBACK: [Expert Role]
STATUS: [Complete | Needs Iteration | Blocked | Escalate]
DELIVERABLE: [What was produced]
RECOMMENDATION: [Primary recommendation in 1-2 sentences]
RATIONALE: [Key reasoning]
STRONGEST OBJECTION: [Best argument against this recommendation]
FALSIFIER: "Fails if [condition] because [mechanism]."
CONFIDENCE: [High | Medium | Low]
CAVEATS: [Assumptions, limitations]
NEXT ACTIONS: [Actionable items]

Quality Gate Counts:
Simple: 2 items
Moderate: 6 items
Complex: 9 items

Triage Criteria: exactly 4
```

**Step 2: Search and Replace**

Use exact string matching to find all format references and replace with canonical format:

```bash
# Find all PERSPECTIVE format references
grep -r "PERSPECTIVE:" src/

# Find all HANDBACK format references
grep -r "HANDBACK:" src/

# Find all quality gate sections
grep -r "Quality Gates" src/
```

For each match, verify format matches reference card exactly. Replace if drifted.

**Step 3: Cross-Reference Validation**

After fixing, verify format consistency:

```bash
# PERSPECTIVE format should appear in:
# - CLAUDE.md (Execution Models section)
# - reference/expert-preamble.md (Inline Perspective Context section)
# - workflow-stages.md (Simple Tier workflow)

# HANDBACK format should appear in:
# - CLAUDE.md (Handback Protocol section)
# - reference/expert-preamble.md (Handback Protocol Reference section)
# - quality-framework.md (Handback Protocol section) if standalone file

# Quality gate counts should match in:
# - CLAUDE.md (Quality Gates section)
# - quality-framework.md if standalone
# - worked-examples.md (each example should verify correct count)
```

**Step 4: Add Format Verification to Checklist**

Update `validation/checklist.md` with character-exact format verification:

```markdown
### PERSPECTIVE Block Format
- [ ] Exactly 4 lines
- [ ] Line 1: `PERSPECTIVE: [Stakeholder] ([profile].md)`
- [ ] Line 2: `LENS: [What this stakeholder examines]`
- [ ] Line 3: `ASSESSMENT: [1-2 sentence finding]`
- [ ] Line 4: `CONCERN: [Primary concern, or "None — [reason]"]`
- [ ] No variations (FOCUS, FINDING, etc.)
```

### Test

After fix, extract all format blocks from generated system and compare character-by-character to reference card. Zero variations allowed.

---

## 3. Tier Confusion

### Description
Same process applied to all tiers. Simple tier spawning sub-agents instead of inline rotation. Moderate tier skipping adversarial review. Complex tier not using TeamCreate.

### Why It Happens
- LLM doesn't distinguish between tier-specific workflows
- Defaults to most complex tier pattern for all work
- Skips lightweight patterns (inline rotation) in favor of agent spawning
- Tier-specific behavior tables in profiles ignored

### How to Detect

**Symptom 1: Simple Tier Agent Spawning**

Simple tier should use inline perspective rotation (manager applies lenses directly, no sub-agent spawns). If CLAUDE.md or worked-examples show Simple tier spawning Task tool agents, tier is confused.

Check CLAUDE.md "Simple: Inline Perspective Rotation" section:
- ✅ "The manager applies each identified stakeholder lens directly"
- ❌ "Spawn stakeholder agents via Task tool"

**Symptom 2: Moderate Tier Missing Phases**

Moderate tier requires 3 phases (Stakeholder Analysis → Lead Implementation → Adversarial Review). If CLAUDE.md or workflow-stages shows Moderate tier skipping any phase, tier is confused.

Check for:
- Phase 1: Parallel stakeholder analysis (required)
- Phase 2: Lead implementation with synthesis (required)
- Phase 3: Adversarial review (required)

**Symptom 3: Complex Tier Using Task Tool Instead of TeamCreate**

Complex tier should use TeamCreate for parallel team formation **when the agent-teams capability is available** (the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` substrate that binds the Convene primitive on Claude Code). If CLAUDE.md shows Complex tier using sequential Task tool spawns (the Moderate phased pattern) AND the documented Convene→Consult fallback is absent, tier is confused — the Complex Quality Gates (pre-mortem with ≥3 scenarios, adversarial review, User Checkpoint) are being skipped because the skill silently fell through to the Moderate execution model.

Check CLAUDE.md "Complex: Parallel Team (Swarm)" section:
- ✅ "Team Formation: `TeamCreate` → spawn coordinator + stakeholder agents"
- ✅ Documented **Fallback** clause (Axiom 8): when agent-teams unavailable, degrade to a deputy-coordinator parallel-Task-tool fan-out (one general-purpose deputy briefed with the full stakeholder plan; fans out parallel stakeholder Task-tool calls; handback-only synthesis; no SendMessage / Inform). User Checkpoint + pre-mortem + adversarial review remain mandatory.
- ❌ "Phase 1 — Stakeholder Analysis: Spawn agents via Task tool" **with no deputy coordinator and no User Checkpoint** (this is the bare Moderate pattern leaking into Complex — the Convene→Consult fallback explicitly keeps the deputy coordinator and the Complex quality gates; their absence is the tier-confusion signal, not the use of Task tool itself).

**Symptom 4: Profile Tier-Specific Behavior Table Missing or Wrong**

Each profile should have "Tier-Specific Behavior" table with 3 rows (Simple, Moderate, Complex) showing how behavior varies by tier. If table is absent or all rows say the same thing, tier behavior is confused.

### How to Fix

**Step 1: Clarify Tier Triggers in CLAUDE.md**

Two-Dimensional Triage section must clearly state:
- 0-1 criteria → Simple (inline)
- 2-3 criteria → Moderate (Task tool)
- 4 criteria OR mandatory trigger → Complex (Team/Swarm)

**Step 2: Document Tier-Specific Workflows**

For each tier, create distinct workflow description:

**Simple Tier Workflow**:
1. Manager reads compact profiles from `reference/compact/` (0.1.0: moved from `agents/compact/`)
2. Manager applies each stakeholder lens inline
3. Manager produces PERSPECTIVE block for each stakeholder
4. Manager synthesizes findings
5. Manager delegates implementation to expert (if code changes needed)
6. NO sub-agent spawning for stakeholder analysis
7. NO adversarial review phase
8. Quality gates: 2 items

**Moderate Tier Workflow**:
1. Manager spawns Phase 1 stakeholder agents in parallel (analysis only)
2. Manager synthesizes Phase 1 findings (synthesis gate)
3. Manager spawns Phase 2 lead implementation agent with synthesis
4. Lead conducts pre-mortem before implementation
5. Manager spawns Phase 3 adversarial reviewer
6. Reviewer tests specific failure modes
7. Quality gates: 6 items

**Complex Tier Workflow**:
1. Manager uses TeamCreate to spawn team (coordinator + stakeholders)
2. Coordinator creates task graph with declarative dependencies
3. Parallel execution (analysis tasks unblocked, implementation tasks blockedBy analysis)
4. Coordinator synthesizes findings for manager
5. Manager checkpoints with user
6. Adversarial review by cross-functional stakeholders
7. Retrospective (required)
8. Structured shutdown (shutdown_request → TeamDelete)
9. Quality gates: 9 items

**Step 3: Add Tier-Specific Behavior to All Profiles**

For each profile, populate Tier-Specific Behavior table with distinct behaviors per tier:

```
| Tier | Engagement Pattern | Output Compression | Quality Rigor |
|------|-------------------|-------------------|---------------|
| **Simple** | Manager applies lens inline using compact profile | PERSPECTIVE block (4 lines) | Red flags check only |
| **Moderate** | Spawned for analysis (Phase 1) or implementation (Phase 2) | Standard handback (9 fields) | Pre-mortem + adversarial review |
| **Complex** | Team member reporting to coordinator | Full handback + documented dissent | Cross-functional review + retrospective |
```

**Step 4: Validate Worked Examples**

Check `worked-examples.md`:
- Example 1 (Simple): Must show inline perspective rotation, NO agent spawns for stakeholder analysis
- Example 2 (Moderate): Must show 3 phases (analysis → implementation → review)
- Example 3 (Complex): Must show TeamCreate, coordinator, parallel execution

### Test

After fix, trace execution path for each tier:
- Simple tier test: Should produce 3 PERSPECTIVE blocks inline, delegate implementation only
- Moderate tier test: Should spawn 6+ agents (2 Phase 1 + 1 Phase 2 + 1 Phase 3 minimum)
- Complex tier test: Should call TeamCreate, create coordinator, execute in parallel

---

## 4. Missing Adversarial Framing

### Description
Reviews say "looks good" without specific failure modes tested. STRONGEST OBJECTION is weak or absent. Reviewers agree with lead instead of finding problems. No calibration challenge on high confidence claims.

### Why It Happens
- LLM defaults to coherent affirmation
- Reviewer profile lacks adversarial instructions
- Adversarial review prompt not used
- No forcing function for genuine objection

### How to Detect

**Symptom 1: "Looks Good" Reviews**

Adversarial review output says "This approach looks good" or "No concerns" without:
- Listing specific failure modes tested
- Explaining why resistant to those failure modes

**Symptom 2: Weak STRONGEST OBJECTION**

STRONGEST OBJECTION in handback is trivial. Examples:
- ❌ "This might be slightly slower" (not genuinely strong)
- ❌ "Could use more comments" (not an objection to recommendation)
- ❌ "Alternative approach exists but this is fine" (not engaging strongest counterargument)

**Symptom 3: Missing Calibration Challenge**

When lead claims High confidence, reviewer does NOT probe: "What would drop this to Medium?"

**Symptom 4: No Failure Mode Testing**

Adversarial review format missing "FAILURE MODES TESTED" field, or field is empty.

### How to Fix

**Step 1: Add Adversarial Review Prompt to workflow-stages.md**

Reviewer prompt must say:

```
"Your job is to find the single most important problem with this work. If you find none,
explain specifically why this work is resistant to the failure modes you tested."
```

NOT:

```
"Review this work and provide feedback."
```

**Step 2: Add Adversarial Review Output Format to workflow-stages.md**

Required format:

```
ADVERSARIAL REVIEW: [Reviewer Role]
FAILURE MODES TESTED: [List of specific failure modes probed]
#1 PROBLEM FOUND: [Description and severity, OR "None — resistant because..."]
ADDITIONAL CONCERNS: [Other issues, ranked by severity]
CONFIDENCE CALIBRATION: [For High-confidence: "Confidence would drop to Medium if..."]
VERDICT: [Accept | Accept with concerns | Revise required]
```

**Step 3: Populate Reviewer Profiles with Adversarial Behaviors**

All profiles used as reviewers (Distinguished Engineer, Security Engineer, SRE, Test Engineer, etc.) must have:

**In "When Supporting" Section**:
```
When supporting another lead expert, I:
- Actively probe for [specific failure mode 1]
- Challenge assumptions about [specific area 2]
- Test edge cases in [specific area 3]
- Success is measured by problems found, not agreement
```

**In "Red Flags You Watch For" Section**:
Use ACTIVE language:
- ✅ "Actively hunt for distributed race conditions in shared state"
- ❌ "Watch for race conditions"

**Step 4: Add STRONGEST OBJECTION Quality Bar**

In quality-framework.md or CLAUDE.md Handback Protocol section, add:

```
**Quality bar**: A good STRONGEST OBJECTION makes you briefly reconsider the
recommendation. If it doesn't, you haven't found the strongest counterargument.
```

With example:

```
RECOMMENDATION: Implement rate limiting at application layer with Redis-backed counters.
STRONGEST OBJECTION: This couples business logic to infrastructure state. If Redis fails,
all requests fail even if the application is healthy. A stateless approach (token bucket in
memory with cluster sync) would be more resilient.

**Why the recommendation still wins**: Despite the valid objection, the Redis approach
provides accurate rate limiting across instances, persistence across deployments, and lower
memory footprint. The requirements prioritize accuracy over resilience.
```

**Step 5: Add Calibration Challenge Protocol**

In quality-framework.md or workflow-stages.md, add:

```
**Calibration Challenge**: For High confidence claims in Moderate and Complex tiers,
reviewer probes: "What would drop this to Medium?"

Expert must answer with specific conditions. If expert cannot identify conditions that would
reduce confidence, claim is overconfident.
```

### Test

After fix, simulate Moderate tier engagement with implementation:
1. Lead produces handback with High confidence
2. Check STRONGEST OBJECTION: should make you reconsider (quality bar test)
3. Reviewer conducts adversarial review
4. Check FAILURE MODES TESTED: should list 3-5 specific failure modes
5. Check #1 PROBLEM FOUND: if "None", must explain why resistant
6. Check CONFIDENCE CALIBRATION: reviewer must ask "What would drop to Medium?"

---

## 5. Org Content Leaking

### Description
Org-specific terms in core files. Hardcoded project keys. Org-specific cli tool names in non-conditional references. Enterprise overlay content appearing in generic core.

### Why It Happens
- LLM trained on org-specific context in prompt
- Enterprise overlay files not properly separated from core
- Example prompts use org examples that leak into core files
- Conditional phrasing ("if installed") omitted

### How to Detect

**Symptom 1: Org References in Core Files**

Search core files for organization-specific terms:

```bash
grep -r "Org Example Name" src/CLAUDE.md src/agents/ src/reference/ src/commands/ src/templates/
grep -r "example-org/example-repo" src/CLAUDE.md src/agents/ src/reference/ src/commands/ src/templates/
grep -r "EXAMPLE-ORG-" src/CLAUDE.md src/agents/ src/reference/ src/commands/ src/templates/
```

Any matches in core files (not src/enterprise/) = org content leaking.

**Symptom 2: Hardcoded issue tracker Project Keys**

Search for project key patterns in core files:

```bash
grep -r "example-org/example-repo-" src/CLAUDE.md src/reference/ src/commands/
grep -r "EXAMPLE-ORG-" src/CLAUDE.md src/reference/ src/commands/
```

Core files should NEVER include hardcoded project keys. issue tracker integration should use variables or config files.

**Symptom 3: Unconditional Org Tool References**

Search core files for org-specific tools:

```bash
grep -r "gh" src/CLAUDE.md src/agents/ src/reference/ src/templates/
grep -r "org-repo" src/CLAUDE.md src/agents/ src/reference/ src/templates/
```

Allowed:
- ✅ "If `~/.claude/reference/issue-tracker-integration.md` exists (installed by enterprise overlay), read it..."
- ✅ In oj-helper script (enterprise overlay tooling)
- ✅ In src/enterprise/ files

Not allowed:
- ❌ "Use gh to fetch work items" in core CLAUDE.md
- ❌ "Clone org-repo repository" in core commands

**Symptom 4: GitHub Workspace Path Hardcoded**

Search for hardcoded paths:

```bash
grep -r "~/workspace" src/CLAUDE.md src/settings.json
```

Allowed:
- ✅ As default value that gets substituted during install (Makefile handles this)

Not allowed:
- ❌ As only option (no substitution mechanism)

### How to Fix

**Step 1: Audit Core vs Org Boundary**

Create boundary checklist:

**Core (src/):**
- Generic agent coordination protocol
- Triage model (4 criteria)
- Execution models (Simple/Moderate/Complex)
- Quality gates
- Handback protocol
- Generic oj-helper subcommands (inject-profile, feedback-path)

**Enterprise Overlay (src/enterprise/):**
- issue tracker integration (issue-tracker-check, issue-tracker-list, etc.)
- GitHub-specific patterns
- AWS CLI patterns
- Organizational standards

**Step 2: Move Org Content to src/enterprise/**

Move files:
- `src/reference/issue-tracker-integration.md` → `src/enterprise/reference/issue-tracker-integration.md`
- `src/commands/issue-tracker-crawl.md` → `src/enterprise/commands/issue-tracker-crawl.md`
- Any reference to "example-org", "example-org/example-repo", internal tools → src/enterprise/

**Step 3: Add Conditional References in Core**

Replace unconditional references with conditional:

Before:
```
Read `~/.claude/reference/issue-tracker-integration.md` for issue tracker integration.
```

After:
```
If `~/.claude/reference/issue-tracker-integration.md` exists (installed by enterprise overlay),
read it before any issue tracker operation.
```

**Step 4: Remove Hardcoded Values**

Replace:
```
PROJECT_KEY="example-org/example-repo"
```

With:
```
# Discover project key from config
PROJECT_KEY=$(cat .claude/issue-tracker-project 2>/dev/null || echo "")
```

**Step 5: Validate Separation**

After moving content, verify:

```bash
# Core files should have ZERO matches:
grep -r "example-org" src/CLAUDE.md src/agents/ src/reference/ src/commands/ src/templates/
grep -r "internal-tool-name" src/CLAUDE.md src/agents/ src/reference/ src/templates/  # except preamble conditional ref

# Org files CAN reference core:
grep -r "stakeholder-guide.md" src/enterprise/  # OK - enterprise overlay can depend on core

# Core files CANNOT reference org unconditionally:
grep -r "issue-tracker-integration.md" src/CLAUDE.md  # Must include "if installed" phrase
```

### Test

After fix:
1. Install core OpenJunto WITHOUT enterprise overlay → system works (no org-specific features)
2. Install core OpenJunto WITH enterprise overlay → org features available, referenced conditionally
3. Search core files for org-specific terms → zero matches

---

## 6. Tooling Failures

### Description
inject-profile reads spawn prompt instead of JSONL transcript. Settings overwrite instead of deep merge. Makefile hardcodes file lists instead of wildcards.

### Why It Happens
- Claude Code hook mechanism not well-documented, LLM guesses incorrectly
- Deep merge complexity, LLM defaults to simple overwrite
- Makefile written before understanding project will grow

### How to Detect

**Symptom 1: inject-profile Reads Wrong Source**

Check `bin/oj-helper` inject-profile function. If it tries to read profile from hook JSON directly (instead of reading transcript file), it's wrong.

Wrong:
```bash
# Extract profile name from hook JSON
PROFILE=$(echo "$HOOK_JSON" | jq -r '.spawnPrompt' | grep -o 'oj-expert: [a-z-]*')
```

Correct:
```bash
# Read transcript file to find spawn prompt
TRANSCRIPT_PATH="${SESSION_DIR}/subagents/agent-${AGENT_ID}.jsonl"
# Wait for transcript to appear (up to 500ms)
# Read first line of transcript
SPAWN_PROMPT=$(head -n1 "$TRANSCRIPT_PATH" | jq -r '.content')
# Extract profile name from spawn prompt (also accept legacy junto-expert marker)
PROFILE=$(echo "$SPAWN_PROMPT" | grep -oE '(oj|junto)-expert: [a-z-]*')
```

**Symptom 2: Settings Overwrite Instead of Merge**

Check Makefile `settings` target. If it uses `cp` or simple jq assignment, it's overwriting:

Wrong:
```makefile
settings:
	cp src/settings.json ~/.claude/settings.json
```

Correct:
```makefile
settings:
	# Deep merge with jq
	jq -s '.[0] * .[1]' ~/.claude/settings.json src/settings.json > ~/.claude/settings.json.tmp
	mv ~/.claude/settings.json.tmp ~/.claude/settings.json
```

Even better (with recursive merge function):
```makefile
settings:
	# Define deepmerge function, apply to both files
	jq -n --slurpfile a ~/.claude/settings.json --slurpfile b src/settings.json \
	  'def deepmerge: ... recursive merge logic ...; ($a[0] // {}) as $x | ($b[0] // {}) as $y | $x | deepmerge($y)'
```

**Symptom 3: Hardcoded File Lists in Makefile**

Check Makefile AGENT_SRCS, TEMPLATE_SRCS, etc. If they list individual files, it's hardcoded:

Wrong:
```makefile
AGENT_SRCS = src/agents/senior-distinguished-engineer.md \
             src/agents/senior-product-manager.md \
             src/agents/senior-security-engineer.md \
             ...
```

Correct:
```makefile
AGENT_SRCS := $(wildcard $(SRC_DIR)/agents/*.md)
AGENT_SRCS := $(filter-out %/_preamble.md %/index.md, $(AGENT_SRCS))
```

**Symptom 4: Settings Merge Not Idempotent**

Check if Makefile `settings` target uses content-hash gating. If running `make install` twice with unchanged source duplicates array entries, merge is not idempotent.

Correct approach:
```makefile
settings:
	# Compute source hash
	CURRENT_HASH=$$(md5 -q src/settings.json)
	# Read installed hash
	INSTALLED_HASH=$$(cat ~/.claude/.oj-settings-hash 2>/dev/null || echo "")
	# Skip if hashes match
	if [ "$$CURRENT_HASH" = "$$INSTALLED_HASH" ]; then exit 0; fi
	# Otherwise, deep merge and write new hash
	... merge logic ...
	echo "$$CURRENT_HASH" > ~/.claude/.oj-settings-hash
```

### How to Fix

**Step 1: Fix inject-profile Source**

Update `bin/oj-helper` inject-profile function:

```bash
inject_profile() {
  # Read hook JSON from stdin
  local HOOK_JSON
  HOOK_JSON=$(cat)

  # Extract agent metadata
  local AGENT_TYPE TRANSCRIPT_PATH AGENT_ID
  AGENT_TYPE=$(echo "$HOOK_JSON" | jq -r '.agent_type // "general-purpose"')
  TRANSCRIPT_PATH=$(echo "$HOOK_JSON" | jq -r '.transcript_path // ""')
  AGENT_ID=$(echo "$HOOK_JSON" | jq -r '.agent_id // ""')

  # Only process general-purpose agents
  [[ "$AGENT_TYPE" != "general-purpose" ]] && exit 0

  # Derive subagent transcript path
  local SESSION_DIR="${TRANSCRIPT_PATH%.jsonl}"
  local SUBAGENT_TRANSCRIPT="${SESSION_DIR}/subagents/agent-${AGENT_ID}.jsonl"

  # Wait up to 500ms for transcript file to appear
  for i in {1..5}; do
    [[ -f "$SUBAGENT_TRANSCRIPT" ]] && break
    sleep 0.1
  done
  [[ ! -f "$SUBAGENT_TRANSCRIPT" ]] && exit 0

  # Read first line of transcript (spawn prompt)
  local SPAWN_PROMPT
  SPAWN_PROMPT=$(head -n1 "$SUBAGENT_TRANSCRIPT" | jq -r '.content // ""')

  # Extract profile name via HTML marker or path pattern
  local PROFILE_NAME
  PROFILE_NAME=$(echo "$SPAWN_PROMPT" | grep -oE '(oj|junto)-expert: [a-z-]*' | cut -d: -f2 | tr -d ' ')
  [[ -z "$PROFILE_NAME" ]] && PROFILE_NAME=$(echo "$SPAWN_PROMPT" | grep -o '~/.claude/agents/[a-z-]*.md' | xargs basename .md)
  [[ -z "$PROFILE_NAME" ]] && exit 0

  # Path traversal guard
  [[ "$PROFILE_NAME" == *".."* ]] && exit 0
  [[ "$PROFILE_NAME" == *"/"* ]] && exit 0

  # Load profile files
  local PREAMBLE_PATH="$HOME/.claude/agents/_preamble.md"
  local PROFILE_PATH="$HOME/.claude/agents/${PROFILE_NAME}.md"
  local COMPACT_PATH="$HOME/.claude/agents/compact/${PROFILE_NAME}.md"

  [[ ! -f "$PREAMBLE_PATH" ]] && exit 0
  [[ ! -f "$PROFILE_PATH" ]] && PROFILE_PATH="$COMPACT_PATH"
  [[ ! -f "$PROFILE_PATH" ]] && exit 0

  # Construct additional context
  local PREAMBLE=$(<"$PREAMBLE_PATH")
  local PROFILE=$(<"$PROFILE_PATH")
  local ADDITIONAL_CONTEXT="${PREAMBLE}\n\n---\n\n${PROFILE}"

  # Output hook response JSON
  jq -n --arg ctx "$ADDITIONAL_CONTEXT" '{
    hookSpecificOutput: {
      hookEventName: "SubagentStart",
      additionalContext: $ctx
    }
  }'
}
```

**Step 2: Fix Settings Deep Merge**

Update Makefile `settings` target with jq deepmerge function:

```makefile
settings: $(TARGET_DIR)/settings.json

$(TARGET_DIR)/settings.json: $(SRC_DIR)/settings.json
	@echo "Merging settings.json..."
	@# Compute source hash
	@CURRENT_HASH=$$(md5 -q $(SRC_DIR)/settings.json); \
	INSTALLED_HASH=$$(cat $(TARGET_DIR)/.oj-settings-hash 2>/dev/null || echo ""); \
	if [ "$$CURRENT_HASH" = "$$INSTALLED_HASH" ]; then \
		echo "Settings unchanged (hash match), skipping merge."; \
		exit 0; \
	fi; \
	if [ -f $@ ]; then \
		cp $@ $@.backup.$$(date +%Y%m%d%H%M%S); \
	fi; \
	jq -n --slurpfile a $@ --slurpfile b $(SRC_DIR)/settings.json \
	  'def deepmerge(b): reduce (b | keys_unsorted[]) as $$k (.; if (.$$k | type) == "object" and ((b[$$k] | type) == "object") then .$$k |= deepmerge(b[$$k]) elif (.$$k | type) == "array" and ((b[$$k] | type) == "array") then .$$k = ((.$$k + b[$$k]) | unique) else .$$k = b[$$k] end); \
	  ($$a[0] // {}) as $$x | ($$b[0] // {}) as $$y | $$x | deepmerge($$y)' > $@.tmp; \
	mv $@.tmp $@; \
	echo "$$CURRENT_HASH" > $(TARGET_DIR)/.oj-settings-hash
```

**Step 3: Fix Makefile Wildcards**

Replace all hardcoded file lists with wildcards:

```makefile
AGENT_SRCS := $(wildcard $(SRC_DIR)/agents/*.md)
AGENT_SRCS := $(filter-out %/_preamble.md %/index.md, $(AGENT_SRCS))

COMPACT_AGENT_SRCS := $(wildcard $(SRC_DIR)/agents/compact/*.md)

TEMPLATE_SRCS := $(wildcard $(SRC_DIR)/templates/*.md)

COMMAND_SRCS := $(wildcard $(SRC_DIR)/commands/*.md)

REFERENCE_SRCS := $(wildcard $(SRC_DIR)/reference/*.md)

ORG_REFERENCE_SRCS := $(wildcard $(SRC_DIR)/org/reference/*.md)

ORG_COMMAND_SRCS := $(wildcard $(SRC_DIR)/org/commands/*.md)
```

**Step 4: Add Idempotence Tests**

Add test target to Makefile:

```makefile
test-idempotence:
	@echo "Testing install idempotence..."
	@make install > /tmp/install1.log 2>&1
	@make install > /tmp/install2.log 2>&1
	@diff /tmp/install1.log /tmp/install2.log && echo "PASS: Installs are idempotent" || echo "FAIL: Installs differ"
```

### Test

After fix:
1. Test inject-profile: spawn sub-agent, verify hook reads transcript file (not hook JSON)
2. Test settings merge: install twice, verify no duplicate array entries
3. Test Makefile wildcards: add new profile file, run `make install`, verify auto-discovered
4. Test idempotence: `make install && make install`, verify second run is no-op

---

## 7. Structural Gaps

### Description
Missing pre-mortem gate. Missing synthesis gate. Circuit breaker triggers missing. TENSION items resolvable (should be protected).

### Why It Happens
- LLM skips "optional" gates thinking they're not critical
- Synthesis gate not clearly separated from synthesis
- Circuit breaker triggers listed but not enforced
- TENSION format present but protection rule missing

### How to Detect

**Symptom 1: Pre-Mortem Gate Missing**

Check workflow-stages.md Moderate tier workflow. If pre-mortem is NOT listed as a gate (with explicit "before producing work product" language), it's missing.

Check worked-examples.md Moderate tier example. If lead agent produces work product WITHOUT first producing pre-mortem, gate is missing.

**Symptom 2: Synthesis Gate Omitted**

Check workflow-stages.md Moderate tier. If it shows:
```
Phase 1: Stakeholder Analysis
Phase 2: Lead Implementation (receives stakeholder analysis)
```

Instead of:
```
Phase 1: Stakeholder Analysis
[SYNTHESIS GATE]
Phase 2: Lead Implementation (receives synthesized findings)
```

Synthesis gate is omitted.

**Symptom 3: Circuit Breaker Not Enforced**

Check CLAUDE.md Circuit Breaker section. If triggers are listed but no instruction to "escalate to user" after trigger, it's not enforced.

Check if manager tracks revision cycles. If CLAUDE.md doesn't say "track revision count per deliverable", circuit breaker won't trigger.

**Symptom 4: TENSION Items Not Protected**

Check workflow-stages.md Synthesis Gate section. If TENSION format is defined but no statement that "TENSION items are PROTECTED — they cannot be removed during synthesis", items can be incorrectly resolved.

Check stakeholder-guide.md Tension Classification. If "Productive Tension" type doesn't say "Do NOT resolve — forward as constraint", items will be resolved instead of forwarded.

### How to Fix

**Step 1: Add Pre-Mortem Gate to Moderate Workflow**

In workflow-stages.md, insert pre-mortem gate between Phase 2 spawn and work product:

```
### Phase 2 — Lead Implementation

After synthesis, spawn lead agent with synthesized findings:

```
<!-- oj-expert: [lead-profile] -->
You are a [Lead Role].
**TASK**: Implement [deliverable]. Stakeholder analysis:
- [Stakeholder 1]: [synthesized findings]
- [Stakeholder 2]: [synthesized findings]

**PRE-MORTEM GATE**: Before producing work product, conduct pre-mortem.
```

**Pre-Mortem Gate Protocol**:
1. Lead agent answers: "Imagine this shipped and failed. What went wrong?"
2. Identifies at least 2 distinct failure scenarios (Moderate tier requirement)
3. For each scenario, states mitigation or accepted risk
4. If pre-mortem reveals critical blind spot, adjusts approach before proceeding

**Output Format**:
```
PRE-MORTEM:
1. [Failure scenario]: [Mitigated by X | Accepted risk because Y]
2. [Failure scenario]: [Mitigated by X | Accepted risk because Y]
```

**After pre-mortem gate passes**, lead produces work product.
```

**Step 2: Add Synthesis Gate to Moderate Workflow**

In workflow-stages.md, insert explicit synthesis gate section:

```
### Synthesis Gate (Between Stakeholder Analysis and Implementation)

After Phase 2 stakeholder analysis completes, the manager synthesizes findings before
spawning the implementer. This prevents information overload and ensures the implementer
receives structured, actionable constraints.

**Synthesis Protocol**:
1. Manager accumulates stakeholder output into Findings Ledger
2. Manager classifies each finding: Hard (must address), Soft (should address), Context (inform)
3. Manager identifies TENSION items (productive tensions that cannot be resolved)
4. Manager forwards synthesis to implementer (not raw stakeholder output)

**Findings Ledger Format** (cap 10 items):
```
FINDING: [finding text] | SOURCE: [stakeholder role] | CONFIDENCE: [H/M/L]
TENSION: [tension text] | SOURCES: [role1, role2] | STATUS: [unresolved]
```

**TENSION items are PROTECTED** — they cannot be removed during synthesis. They are
forwarded to implementer and reviewer spawn contexts.

**Constraint Classification**:
| Classification | Criteria | Implementer Obligation |
|----------------|----------|----------------------|
| **Hard** | 2+ stakeholders agree OR domain authority | Must address |
| **Soft** | Single stakeholder, no corroboration | Should address; explain if deferred |
| **Context** | Background information | Inform approach; no explicit reference required |

**After synthesis gate**, spawn Phase 2 lead implementation with synthesized findings.
```

**Step 3: Add Circuit Breaker Enforcement**

In CLAUDE.md Circuit Breaker section, add enforcement language:

```
### Circuit Breaker

**Manager MUST track** revision count per deliverable.

After ANY of these conditions, **STOP and escalate to user**:
- 3 revision cycles on the same deliverable (STOP)
- 2 hours elapsed without meaningful progress (STOP)
- Expert/stakeholder deadlock unresolved (STOP)
- Scope significantly larger than triaged (STOP)

**Escalation Protocol**:
1. Stop all work on current deliverable
2. Present situation to user with context
3. Offer 4 options:
   - Simplify scope (reduce to core requirement)
   - Proceed with documented risks (accept current state)
   - Pause for info (wait for external input)
   - Abandon (work not viable)
4. User selects option
5. Manager proceeds based on user selection

**Do NOT attempt 4th revision without user approval.**
```

**Step 4: Protect TENSION Items**

In workflow-stages.md Synthesis Gate section, add:

```
**TENSION items are PROTECTED** — they cannot be removed during synthesis. They must be
forwarded to implementer and reviewer spawn contexts.

TENSION items represent productive tensions where stakeholder interaction reveals a deeper
constraint. Resolving the tension prematurely loses valuable information. The implementer
must address the tension with clear rationale.
```

In stakeholder-guide.md Tension Classification table, update Productive Tension row:

```
| Type | Definition | Action |
|------|-----------|--------|
| **Productive Tension** | Interaction reveals deeper constraint | Do NOT resolve — forward as constraint. Implementer must address with rationale. |
```

### Test

After fix:
1. Test pre-mortem: Run Moderate tier engagement, verify pre-mortem occurs BEFORE work product
2. Test synthesis gate: Run Moderate tier, verify manager synthesizes Phase 1 findings before Phase 2 spawn
3. Test circuit breaker: Force 3 revisions, verify manager stops and escalates
4. Test TENSION protection: Create stakeholder disagreement, verify TENSION item forwarded (not resolved)

---

## 8. Incomplete Adversarial Review

### Description
Adversarial review format present but reviewer doesn't actually test failure modes. Review says "no concerns" without demonstrating resistance to specific failure scenarios.

### Why It Happens
- Format checklist satisfied without substance
- Reviewer role not genuinely adversarial
- No examples of strong adversarial reviews
- Failure mode list generic instead of specific

### How to Detect

**Symptom 1: Generic Failure Mode List**

Adversarial review says:
```
FAILURE MODES TESTED: Security, performance, scalability
```

Instead of specific failure modes:
```
FAILURE MODES TESTED: Distributed bypass via multiple IPs, cache poisoning of rate counters,
thundering herd on limit reset, storage cost at 10M users
```

**Symptom 2: "No Concerns" Without Explanation**

Review says:
```
#1 PROBLEM FOUND: None
```

Instead of:
```
#1 PROBLEM FOUND: None — resistant because rate limiting uses atomic Redis INCR operations
that prevent race conditions, sliding window algorithm prevents thundering herd, and storage
cost is O(active users) not O(total users)
```

**Symptom 3: Weak Confidence Calibration**

Review says:
```
CONFIDENCE CALIBRATION: N/A
```

Instead of:
```
CONFIDENCE CALIBRATION: Author claimed High confidence. Would drop to Medium if Redis
becomes a single point of failure without HA setup — ops plan includes Redis Sentinel.
```

### How to Fix

**Step 1: Add Failure Mode Examples by Domain**

In adversarial review protocol section, add domain-specific failure mode checklists:

**Security Domain**:
- Authentication bypass (JWT tampering, session fixation, CSRF)
- Authorization escalation (privilege elevation, resource enumeration)
- Input validation (SQL injection, XSS, command injection)
- Data exposure (PII leakage, error messages revealing topology)

**Performance Domain**:
- Distributed race conditions in shared state
- Lock contention under concurrent load
- Cache stampede / thundering herd
- Storage cost growth (O(n), O(n²), O(n!))

**Reliability Domain**:
- Single point of failure (SPOF) in critical path
- Cascading failures (one service down → all down)
- Degraded mode behavior (what works when X fails?)
- Recovery time from failure state

**Step 2: Add Adversarial Review Examples**

In worked-examples.md, add full adversarial review example:

```
**Phase 3 — Adversarial Review** (Distinguished Engineer):

ADVERSARIAL REVIEW: Senior Distinguished Engineer
FAILURE MODES TESTED:
- Distributed bypass: Can attacker use multiple IPs to circumvent rate limit?
- Cache poisoning: Can attacker pollute rate counter with invalid keys?
- Thundering herd: Do all requests retry simultaneously when limit resets?
- Storage cost: What's memory footprint at 1M users? 10M users?

#1 PROBLEM FOUND: None — resistant because:
- Distributed bypass: Rate limiting keys by user_id (not IP), requires authenticated requests
- Cache poisoning: Keys are hashed server-side, attacker cannot inject arbitrary keys
- Thundering herd: Sliding window algorithm spreads requests over interval, no reset cliff
- Storage cost: O(active users in last hour), ~100 bytes per user, 10M users = 1GB (acceptable)

ADDITIONAL CONCERNS:
- Redis latency spikes could cause false limit rejections (low severity — monitoring in place)
- Need runbook for Redis failover during peak traffic (low severity — ops plan includes this)

CONFIDENCE CALIBRATION: Author claimed High confidence for Redis-backed approach. Would drop
to Medium if Redis becomes SPOF without HA. Confirmed: ops plan includes Redis Sentinel with
automatic failover.

VERDICT: Accept
```

**Step 3: Add Forcing Function**

In adversarial review protocol, add:

```
**Forcing Function**: If reviewer finds no problems, they MUST:
1. List at least 3 specific failure modes tested (not generic categories)
2. Explain why the work is resistant to EACH failure mode
3. Identify the precondition that would make each failure mode occur
4. Confirm those preconditions are mitigated in the design

If reviewer cannot explain resistance, they haven't tested thoroughly enough.
```

**Step 4: Update Reviewer Profiles**

In profiles used as reviewers (Distinguished Engineer, Security Engineer, SRE, Test Engineer), add to "When Supporting" section:

```
When conducting adversarial review, I:
- Test at least 3 specific failure modes (not generic categories)
- Explain resistance to each failure mode with mechanism
- Challenge high confidence claims: "What would drop this to Medium?"
- Success measured by problems found OR demonstrated resistance, not agreement
```

### Test

After fix:
1. Run Moderate tier with implementation claiming High confidence
2. Verify adversarial review lists 3+ SPECIFIC failure modes (not "security, performance")
3. Verify review explains resistance to EACH failure mode
4. Verify confidence calibration challenges High confidence claim
5. If "no problems", verify reviewer demonstrated thorough testing

---

## End of Anti-Patterns

This document captures common generation failures for the OpenJunto system. For structural verification, see `checklist.md`. For functional validation, see `smoke-tests.md`.

**Usage**:
1. After generating OpenJunto system from spec, run all checks in this document
2. Fix failures using "How to Fix" guidance
3. Re-test with "Test" instructions
4. Update spec if anti-pattern reveals specification gap
5. Add detected anti-pattern to this document for future reference
