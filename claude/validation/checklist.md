# Validation Checklist

Per-component verification criteria for an OpenJunto system generated from the juntospec specification.

---

## Project Structure

- [ ] Source directory exists at `src/` with correct subdirectories
- [ ] `src/CLAUDE.md` exists (global manager instructions)
- [ ] `src/agents/` directory contains exactly 16 full profiles + `_preamble.md` + `index.md`
- [ ] `src/agents/compact/` directory contains exactly 16 compact profiles
- [ ] `src/templates/` directory contains exactly 5 templates
- [ ] `src/commands/` directory contains exactly 3 core commands
- [ ] `src/reference/` directory contains exactly 8 core reference files
- [ ] `src/enterprise/` directory exists (optional enterprise overlay)
- [ ] `src/enterprise/reference/` contains org-specific reference files (if overlay present)
- [ ] `src/enterprise/commands/` contains org-specific commands (if overlay present)
- [ ] `src/settings.json` exists with correct structure
- [ ] `bin/oj-helper` exists and is executable
- [ ] `Makefile` exists with installation targets
- [ ] `VERSION` file exists with semantic version (e.g., "1.0.0")

---

## CLAUDE.md Structure

### Role Declaration
- [ ] Opens with exact line: `You are a **Senior Technical Project Manager** — you orchestrate expert agents, you do not implement.`
- [ ] Header: `# OpenJunto: Agent Coordination System`
- [ ] Second paragraph present verbatim
- [ ] Responsibilities paragraph present verbatim

### Section Headers (all present in order)
- [ ] `## Absolute Constraints`
- [ ] `## Two-Dimensional Triage`
- [ ] `## Execution Models`
- [ ] `## Handback Protocol`
- [ ] `## Quality Gates`
- [ ] `## Agent Spawning`
- [ ] `## Stakeholder Perspectives`
- [ ] `## Reference and Operations`
- [ ] `## Definition of Done`

### Absolute Constraints Section
- [ ] `### Delegation Boundary` subsection present
- [ ] Three components (DO, EXCEPTION, DO NOT) present verbatim
- [ ] Manager permissions listed verbatim
- [ ] Self-Check gate has exactly 3 questions with exact wording
- [ ] `### Triage Requirement` subsection present
- [ ] `### Circuit Breaker` subsection present
- [ ] Circuit breaker has exactly 4 trigger conditions
- [ ] Options line: `Options: Simplify scope | Proceed with documented risks | Pause for info | Abandon`
- [ ] Adaptive signals table has exactly 3 rows
- [ ] `### External Artifact Hygiene` subsection present
- [ ] Prohibition statement about BACKLOG.md identifiers present
- [ ] issue tracker ID exception statement present

### Two-Dimensional Triage Section
- [ ] `### A. Execution Model` subsection present
- [ ] Criteria table has exactly 4 rows with checkboxes
- [ ] Scoring rule: `0-1 = Simple (inline), 2-3 = Moderate (Task tool), 4 = Complex (Team/Swarm)`
- [ ] Mandatory escalation statement present verbatim
- [ ] `### B. Stakeholder Identification` subsection present
- [ ] Mandatory pair: `Product + Tech` (exact wording)
- [ ] Domain signals table has exactly 9 rows
- [ ] Stakeholder escalation guard thresholds: 4+ (Simple→Moderate), 5+ (Moderate→Complex)

### Execution Models Section
- [ ] `### Simple: Inline Perspective Rotation` subsection present
- [ ] PERSPECTIVE block format exactly as specified (4 lines: PERSPECTIVE, LENS, ASSESSMENT, CONCERN)
- [ ] `### Moderate: Task Tool Engagement` subsection present
- [ ] Phase 1, Phase 2, Phase 3 headers present
- [ ] Spawn format marker `<!-- oj-expert: [profile-filename] -->` present in all three phases
- [ ] `### Complex: Parallel Team (Swarm)` subsection present
- [ ] Seven numbered elements present (Team Formation, Deputy Coordinator, Task Structure, Plan Approval, Quality Gate Hooks, Structured Shutdown, File Conflict Avoidance)

### Handback Protocol Section
- [ ] Simple tier format exactly 5 fields (HANDBACK, DELIVERABLE, RECOMMENDATION, STRONGEST OBJECTION, NEXT)
- [ ] Moderate/Complex tier format exactly 9 fields (HANDBACK, STATUS, DELIVERABLE, RECOMMENDATION, RATIONALE, STRONGEST OBJECTION, FALSIFIER, CONFIDENCE, CAVEATS, NEXT ACTIONS)
- [ ] Status table has exactly 4 rows (Complete, Needs Iteration, Blocked, Escalate)
- [ ] Confidence table has exactly 3 rows (High, Medium, Low)
- [ ] Calibration Challenge statement present verbatim

### Quality Gates Section
- [ ] `### Simple Tier (2 items)` header with count
- [ ] Exactly 2 checkbox items for Simple tier
- [ ] `### Moderate Tier (6 items)` header with count
- [ ] Exactly 6 checkbox items for Moderate tier
- [ ] `### Complex Tier (9 items)` header with count
- [ ] Exactly 9 checkbox items for Complex tier

### Agent Spawning Section
- [ ] `### Spawning Pattern` subsection present
- [ ] `<!-- oj-expert: [profile-filename] -->` marker documented
- [ ] Hook description mentions `oj-helper inject-profile`
- [ ] Context inheritance explanation present
- [ ] Fallback instructions present with self-loading pattern
- [ ] Expert orientation requirement present (3 role types: Analyst, Implementer, Reviewer)
- [ ] `### Model Selection` subsection present
- [ ] Model table has exactly 3 rows (haiku, sonnet, opus) with When to Use and Examples

### Stakeholder Perspectives Section
- [ ] Mandatory pair listed: `Product Manager` and `Distinguished Engineer` with filenames
- [ ] Domain stakeholders list present with 14 experts mentioned
- [ ] Two blockquote references to stakeholder-guide.md and worked-examples.md

### Reference and Operations Section
- [ ] `### issue tracker Bootstrap` subsection present
- [ ] `### Tier-Aware Context Loading` table with 3 rows (Simple, Moderate, Complex)
- [ ] `### Reference Files` table with exactly 8 files listed
- [ ] Organization-specific reference blockquote present
- [ ] `### Templates` table with exactly 5 templates listed

### Definition of Done Section
- [ ] `### Simple Tier` with exactly 3 items
- [ ] `### Moderate Tier` with exactly 3 items
- [ ] `### Complex Tier` with exactly 4 items
- [ ] `### Verifying Deliverables` subsection with 3 verification steps
- [ ] `### Incorporating Lessons` subsection with when/don't guidance

---

## Agent Profiles (Full)

Count verification:
- [ ] Exactly 16 full profiles exist in `src/agents/`
- [ ] `_preamble.md` exists
- [ ] `index.md` exists

### Profile Roster (all present with exact filenames)
- [ ] `senior-distinguished-engineer.md`
- [ ] `senior-product-manager.md`
- [ ] `senior-security-engineer.md`
- [ ] `senior-data-architect.md`
- [ ] `senior-solutions-architect.md`
- [ ] `senior-devops-engineer.md`
- [ ] `senior-data-scientist.md`
- [ ] `senior-ml-engineer.md`
- [ ] `senior-enterprise-architect.md`
- [ ] `senior-business-analyst.md`
- [ ] `senior-technical-writer.md`
- [ ] `senior-engineering-consultant.md`
- [ ] `senior-executive-leadership-coach.md`
- [ ] `senior-test-engineer.md`
- [ ] `senior-site-reliability-engineer.md`
- [ ] `senior-software-engineer.md`

### Per-Profile Structure (check 3-5 profiles as spot check)

For each profile checked:
- [ ] All 16 sections present in order (Role Identity → Success Indicators)
- [ ] Section 1: Role Identity includes AI agent caveats
- [ ] Section 4: Decision-Making Authority lists specific decision areas
- [ ] Section 5: Collaboration Style has "When Leading" and "When Supporting" subsections
- [ ] Section 5 "When Supporting" includes adversarial behaviors (uses "actively probe" language)
- [ ] Section 6: Inter-Expert Collaboration table has 6-8 rows + Escalation to Manager row
- [ ] Section 7: Tier-Specific Behavior table has 3 rows (Simple, Moderate, Complex)
- [ ] Section 10: Red Flags uses ACTIVE language ("actively probe", "hunt", "trace", "verify", "challenge")
- [ ] Section 10: Red Flags NOT passive ("look for", "watch for" without action verbs)
- [ ] Section 13: Common Patterns organized by 3-5 categories

### Distinguished Engineer & Product Manager (mandatory pair)
- [ ] `senior-distinguished-engineer.md` has tie-breaker authority on technical decisions
- [ ] `senior-product-manager.md` has tie-breaker authority on business priorities
- [ ] Both profiles have 25+ and 20+ years experience noted
- [ ] Both have Quality Standards section ending with adversarial probe question

### Security Engineer (spot check for active language)
- [ ] Red flags use "actively hunt" language
- [ ] Has security veto authority documented in Decision-Making Authority
- [ ] Mandatory escalation triggers listed (6 scenarios)
- [ ] Quality standards probe for exploitable weakness

### Software Engineer (spot check for implementation focus)
- [ ] Red flags use "actively probe" for error paths and edge cases
- [ ] Inter-expert collaboration table has 8 collaborators (largest roster)
- [ ] Common patterns grouped by 4 categories (Clean Code, Performance, Testing, Reliability)
- [ ] Quality standards probe for runtime failure modes

---

## Compact Profiles

Count verification:
- [ ] Exactly 16 compact profiles exist in `src/agents/compact/`
- [ ] Filenames match full profile filenames exactly

### Per-Compact-Profile Structure (check 3-5 as spot check)

For each compact profile checked:
- [ ] Role identity (1 sentence, bold title)
- [ ] Core expertise (bullet list, 4-6 items)
- [ ] Decision authority (bullet list, 3-4 items)
- [ ] Red flags (bullet list, 4-6 items) with ACTIVE language preserved
- [ ] Adversarial behaviors (2-3 bullets) from full profile "When Supporting"
- [ ] Handback format (Simple tier compressed format shown)
- [ ] Reference back to full profile with exact path
- [ ] Total size <2KB (approximately 30 lines)

---

## Preamble (_preamble.md)

- [ ] AI Agent Context section with 5 key implications
- [ ] Organizational Standards Reference section pointing to `organizational-standards.md`
- [ ] Inline Perspective Context section with PERSPECTIVE block format
- [ ] Standard Profile Structure section listing all 16 sections
- [ ] Handback Protocol Reference section pointing to CLAUDE.md
- [ ] All sections present and in correct order

---

## Index (index.md)

- [ ] Quick Reference section with two tables (Mandatory Stakeholders + Domain Experts)
- [ ] Mandatory Stakeholders table has 2 rows (Distinguished Engineer, Product Manager) with Tie-Breaker Authority column
- [ ] Domain Experts table has 14 rows with File, Primary Purpose, Engage When columns
- [ ] Expert Selection Guide section with problem type → expert mapping table
- [ ] Cross-Cutting Reviewer column populated (always different domain than lead)
- [ ] Stakeholder Engagement by Execution Model table with 3 rows (Simple, Moderate, Complex)
- [ ] Profile Structure Listing section enumerating all 16 sections
- [ ] Compact Profiles section with when to use / when NOT to use guidance
- [ ] Maintenance Guidelines section

---

## Reference Files

Count verification:
- [ ] Exactly 8 core reference files in `src/reference/`

### Reference File Roster (all present)
- [ ] `workflow-stages.md`
- [ ] `stakeholder-guide.md`
- [ ] `worked-examples.md`
- [ ] `dev-mode.md`
- [ ] `failure-protocol.md`
- [ ] `file-patterns.md`
- [ ] `project-scaffolding.md`
- [ ] `communication-standards.md`

### workflow-stages.md
- [ ] Workflow stages by tier (Simple: 5 stages, Moderate: 7 stages, Complex: 9 stages)
- [ ] Synthesis Gate section with FINDING/TENSION format and constraint classification table
- [ ] Pre-Mortem Gate section with prompt and requirements (2 scenarios Moderate, 3 Complex)
- [ ] Adversarial Review Protocol section with reviewer prompt and output format
- [ ] Output Compression table
- [ ] Deputy Coordinator Pattern section

### stakeholder-guide.md
- [ ] Mandatory Pair section (Product + Tech)
- [ ] Domain Signal → Stakeholder Mapping table with 14 rows
- [ ] Stakeholder Escalation Guard section with thresholds (4+, 5+)
- [ ] Common Task Patterns table with 12 rows
- [ ] Conflict Classification table with 4 conflict types
- [ ] Tension Classification table with 3 tension types
- [ ] Resolution Steps (5-step protocol)
- [ ] DISSENT Format documented
- [ ] Steelman Format documented
- [ ] Example Conflicts section

### worked-examples.md
- [ ] Example 1: Simple Tier (health check endpoint)
- [ ] Example 2: Moderate Tier (rate limiting)
- [ ] Example 3: Complex Tier (authentication migration)
- [ ] Each example includes triage result, stakeholder list, execution flow

### dev-mode.md
- [ ] OJ_DEVMODE=1 flag documented
- [ ] Feedback path convention documented
- [ ] Scope (local development only) stated
- [ ] Trigger mechanism (oj-helper feedback-path) documented

### failure-protocol.md
- [ ] 3-Step Protocol (Retry, Document, Escalate)
- [ ] 5 retry strategies listed
- [ ] Emergency Direct Execution Protocol with 5 constraints
- [ ] Recovery Checklist with 3 items

### file-patterns.md
- [ ] Backlog Management Guidelines section
- [ ] Standard Project `.claude/` Structure section (2 variants)
- [ ] Persist Long-Running Context section
- [ ] Header/Detail Pattern section with thresholds (<10KB, 10-25KB, >25KB)

### project-scaffolding.md
- [ ] Session State Separation section
- [ ] Carry-Over Compression section with aging policy table
- [ ] Context Map (llms.txt) section
- [ ] Artifact Organization section (4 subdirectories)
- [ ] Snapshot Caching Contract section
- [ ] Communications Playbook Pattern section
- [ ] Session Lifecycle Pattern section (Health Check, Intake Funnel, Session Save)

### communication-standards.md
- [ ] 6 Communication Standards listed
- [ ] Standard Response Format (7-section structure)
- [ ] Anti-Patterns Table with 9 anti-patterns
- [ ] Success Metrics Table with 5 metrics and targets
- [ ] AI Agent Context Note about session-level metrics

---

## Templates

Count verification:
- [ ] Exactly 5 templates in `src/templates/`

### Template Roster (all present)
- [ ] `technical-analysis.md`
- [ ] `architecture-decision-record.md`
- [ ] `retrospective.md`
- [ ] `session-state.md`
- [ ] `communications-playbook.md`

### Per-Template Structure (spot check 2-3)
- [ ] Essential sections listed in spec are present
- [ ] YAML frontmatter or markdown headers for section organization
- [ ] Template provides clear structure with placeholders

### technical-analysis.md
- [ ] Summary, Context, Methodology, Findings, Options Analysis, Recommendation, Risks, Dissenting Views, Metadata sections

### architecture-decision-record.md
- [ ] Status, Date, Context, Decision Drivers, Considered Options, Decision, Reversibility Assessment, Consequences, Validation, References, Metadata sections
- [ ] Reversibility Assessment has 4 levels (Easy/Moderate/Difficult/Irreversible)

### retrospective.md
- [ ] Engagement Summary, What Went Well, What Could Be Improved, Questions & Puzzles, Action Items, Metrics Review, Profile/Process Updates, Quality Checklist, Usage Notes sections
- [ ] Action Items categorized by Process/Profile/Template/Documentation

### session-state.md
- [ ] Updated date and session number, In-Flight PRs, Local Workspace State, Session Carry-Over, Next Actions sections
- [ ] Retention policy described (current + prior 2 sessions, compress older)

### communications-playbook.md
- [ ] Signal Gate (event table), Hierarchy Rule, Channel Routing, Drafts, Log sections

---

## Commands

Count verification:
- [ ] Exactly 3 core commands in `src/commands/`

### Command Roster (all present)
- [ ] `run-task.md`
- [ ] `show-backlog.md`
- [ ] `save-session.md`

### Per-Command Structure
- [ ] YAML frontmatter with `description` field
- [ ] Markdown instructional content
- [ ] Step-by-step protocol
- [ ] Constraints section

### run-task.md
- [ ] 5-phase task lifecycle present (Initialize → Learn)
- [ ] Backlog Source Detection section (issue-tracker-check logic)
- [ ] Triage section with 4-criterion checklist and stakeholder identification
- [ ] Execute section with all three tier workflows (Simple, Moderate, Complex)
- [ ] Verification gate in Phase 4 (Deliver)
- [ ] Dev Mode Feedback in Phase 5 (Learn) with feedback-path call
- [ ] Constraints section (scope to ONE item, atomic commits, don't proceed past blocking review, stop and ask)

### show-backlog.md
- [ ] 3-step protocol (Backlog Source Detection → Load → Present)
- [ ] Backlog Source Detection identical to run-task.md
- [ ] Present Summary section with header format
- [ ] Next Cycle Candidate highlighted
- [ ] Constraints section (read-only, concise, empty backlog handling)

### save-session.md
- [ ] 7-step protocol (Read Current State → Present and Apply)
- [ ] Step 1 offers to create from template if session.md missing
- [ ] Step 6 drafts session update with compression rules (2 sessions detail, >14 days remove)
- [ ] Step 7 presents changes for approval before writing
- [ ] Constraints section (approval required, non-destructive, graceful degradation)

---

## oj-helper Script

### File Properties
- [ ] Located at `bin/oj-helper`
- [ ] Executable permissions set (`chmod +x`)
- [ ] Shebang line `#!/usr/bin/env bash`
- [ ] `set -euo pipefail` present

### Core Subcommands (generic, all present)
- [ ] `inject-profile` subcommand
- [ ] `feedback-path` subcommand

### inject-profile Subcommand
- [ ] Reads hook JSON from stdin
- [ ] Only processes `general-purpose` agents (skips Bash, Explore, Plan)
- [ ] Derives subagent transcript path from hook JSON
- [ ] Waits up to 500ms for transcript file to appear
- [ ] Reads first line of transcript (spawn prompt)
- [ ] Extracts profile name via HTML marker (`<!-- oj-expert: PROFILE -->`) or path pattern
- [ ] Path traversal guard (rejects `..` and `/` in profile names)
- [ ] Loads `_preamble.md` + full profile (or compact fallback)
- [ ] Outputs hook response JSON with `additionalContext` field
- [ ] Graceful exit 0 on failures (jq missing, transcript unavailable, profile not found)

### feedback-path Subcommand
- [ ] Checks `$OJ_DEVMODE` environment variable (with legacy `$JUNTO_DEVMODE` fallback)
- [ ] Exits 0 with no output if not "1"
- [ ] Extracts org/repo from git remote origin URL
- [ ] Creates directory `~/.claude/dev/feedback/{org}/{repo}/`
- [ ] Outputs timestamped path `YYYY-MM-DDTHHMMSS.md`

### Helper Functions
- [ ] `debug()` function controlled by `OJ_HOOK_DEBUG=1` (with legacy `JUNTO_HOOK_DEBUG` fallback)
- [ ] `die()` function for fatal errors
- [ ] Graceful degradation philosophy (missing tools → exit 0 or clear error)

---

## settings.json

### Structure
- [ ] Valid JSON
- [ ] `env` object present
- [ ] `permissions` object present with `allow`, `deny`, `defaultMode` keys
- [ ] `hooks` object present with `SessionStart` and `SubagentStart` arrays
- [ ] `model` field set to "opus"
- [ ] `attribution` object with empty `commit` and `pr` fields

### Environment Variables
- [ ] `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- [ ] `CLAUDE_CODE_ENABLE_UNIFIED_READ_TOOL=1`
- [ ] `CLAUDE_CODE_EXPERIMENTAL_ADAPTIVE_THINKING=1`

### Permissions
- [ ] Allow list includes Read access to workspace and ~/.claude/ subdirectories
- [ ] Allow list includes Bash commands (git, cat, grep, ls, oj-helper, diagnostic tools)
- [ ] Deny list includes `rm -rf /*` and `git push --force`

### Hooks
- [ ] SessionStart hook calls `oj-helper conductor-inject`, which injects CONDUCTOR.md as `additionalContext` (stdout JSON) AND prints the version banner to stderr (banner is stderr-only; version read from plugin `VERSION`, not `.oj-version`)
- [ ] SessionStart hook timeout: 5 seconds
- [ ] SubagentStart hook calls `oj-helper inject-profile`
- [ ] SubagentStart hook matcher: "general-purpose"
- [ ] SubagentStart hook timeout: 5 seconds

---

## Makefile

### Key Targets (all present)
- [ ] `install` (default target)
- [ ] `deps`
- [ ] `claude-md`
- [ ] `agents`
- [ ] `templates`
- [ ] `commands`
- [ ] `reference`
- [ ] `organization`
- [ ] `scripts`
- [ ] `settings`
- [ ] `version`
- [ ] `uninstall`
- [ ] `status`
- [ ] `help`

### Wildcard Discovery
- [ ] AGENT_SRCS uses wildcard: `$(wildcard $(SRC_DIR)/agents/*.md)`
- [ ] COMPACT_AGENT_SRCS uses wildcard
- [ ] TEMPLATE_SRCS, COMMAND_SRCS, REFERENCE_SRCS use wildcards
- [ ] No hardcoded file lists (except for special cases like CLAUDE.md, _preamble.md, index.md)

### Settings Merge
- [ ] `settings` target computes source hash (md5)
- [ ] Compares with installed hash (`.oj-settings-hash`)
- [ ] Skips merge if hashes match (idempotent)
- [ ] Deep merges with jq (recursive object merge, array union)
- [ ] Backs up existing settings.json before merge
- [ ] Writes new hash after successful merge

### Installation Flow
- [ ] `install` target runs all sub-targets in sequence
- [ ] `deps` target checks for jq, gh, yq (fast-path if all present)
- [ ] `claude-md` target backs up existing CLAUDE.md before overwrite
- [ ] `organization` target copies enterprise overlay files alongside core files (not in subdirectory)
- [ ] `scripts` target copies to `~/.local/bin/` with `chmod +x`
- [ ] `version` target writes VERSION file contents to `~/.claude/.oj-version`
- [ ] `check-path` target warns if `~/.local/bin` not in PATH

### Dry Run Support
- [ ] DRY_RUN variable supported
- [ ] `make -B DRY_RUN=1` previews changes without executing

---

## Cross-References

### Profile → Index
- [ ] All 16 full profile filenames in `agents/` match entries in `index.md` Domain Experts table
- [ ] All 16 compact profile filenames in `agents/compact/` match full profile names

### CLAUDE.md → Reference Files
- [ ] All 8 reference files listed in CLAUDE.md Reference Files table exist in `src/reference/`
- [ ] Reference file descriptions in CLAUDE.md match actual file contents

### CLAUDE.md → Templates
- [ ] All 5 templates listed in CLAUDE.md Templates table exist in `src/templates/`

### Commands → oj-helper
- [ ] `/run-task` references `oj-helper issue-tracker-check`, `issue-tracker-list`, `issue-tracker-transition`, `issue-tracker-comment`, `issue-tracker-create`, `feedback-path`
- [ ] `/show-backlog` references `oj-helper issue-tracker-check`, `issue-tracker-list`
- [ ] All referenced oj-helper subcommands exist in script

### Index → Profiles
- [ ] Expert Selection Guide references profile filenames that exist
- [ ] All profile references use correct filename format (lowercase, hyphenated)

---

## Enterprise Overlay (if present)

### Structure
- [ ] `src/enterprise/` directory exists
- [ ] `src/enterprise/reference/` subdirectory present
- [ ] `src/enterprise/commands/` subdirectory present

### Content Boundary
- [ ] No org-specific content in core files (src/CLAUDE.md, src/agents/, src/reference/, src/commands/)
- [ ] Core files only reference org files conditionally ("if installed by enterprise overlay")
- [ ] Org files can reference core files without qualification

### Installation
- [ ] Makefile `organization` target copies org files alongside core files (not in subdirectory)
- [ ] Enterprise overlay reference files → `~/.claude/reference/` (merged with core)
- [ ] Enterprise overlay commands → `~/.claude/commands/` (merged with core)

---

## Format String Verification (EXACT items)

### PERSPECTIVE Block (Simple tier)
- [ ] Exactly 4 lines: PERSPECTIVE, LENS, ASSESSMENT, CONCERN
- [ ] Format matches spec character-for-character

### Spawn Format Marker
- [ ] `<!-- oj-expert: [profile-filename] -->` appears in CLAUDE.md Phase 1, 2, 3 spawn patterns
- [ ] Marker documented in Agent Spawning section
- [ ] Marker extraction logic in oj-helper inject-profile

### Handback Formats
- [ ] Simple tier: 5 fields (HANDBACK, DELIVERABLE, RECOMMENDATION, STRONGEST OBJECTION, NEXT)
- [ ] Moderate/Complex tier: 9 fields (HANDBACK, STATUS, DELIVERABLE, RECOMMENDATION, RATIONALE, STRONGEST OBJECTION, FALSIFIER, CONFIDENCE, CAVEATS, NEXT ACTIONS)
- [ ] Field names match spec exactly

### Quality Gate Counts
- [ ] Simple tier: exactly 2 items
- [ ] Moderate tier: exactly 6 items
- [ ] Complex tier: exactly 9 items
- [ ] Header labels include counts (e.g., "### Simple Tier (2 items)")

### Triage Criteria
- [ ] Exactly 4 criteria in execution model table
- [ ] Checkboxes formatted as `[ ]`
- [ ] Scoring rule verbatim: `0-1 = Simple (inline), 2-3 = Moderate (Task tool), 4 = Complex (Team/Swarm)`

### Model Selection Table
- [ ] Exactly 3 rows: haiku, sonnet, opus
- [ ] Column headers: Model, When to Use, Examples
- [ ] Guidance: "When in doubt, use the more capable model (haiku < sonnet < opus)."

---

## Threshold Verification (EXACT values)

- [ ] Circuit breaker: 3 revision cycles, 2 hours
- [ ] Adaptive signals: 2+ consecutive patterns
- [ ] Triage scoring: 0-1 Simple, 2-3 Moderate, 4 Complex
- [ ] Stakeholder escalation: 4+ (Simple→Moderate), 5+ (Moderate→Complex)
- [ ] Team formation: 3-5 teammates, 5-6 tasks per teammate
- [ ] Pre-mortem scenarios: 2 for Moderate, 3 for Complex
- [ ] Lesson incorporation: 2-3 repetitions
- [ ] Compact profile size: ~30 lines, <2KB
- [ ] Profile count: exactly 16 full + 16 compact
- [ ] Reference file count: exactly 8 core
- [ ] Template count: exactly 5
- [ ] Command count: exactly 3 core
- [ ] inject-profile transcript wait: 500ms (5 iterations × 100ms)
- [ ] Hook timeout: 5 seconds
- [ ] Quality gate item counts: 2 / 6 / 9 (Simple / Moderate / Complex)
- [ ] Triage criterion count: exactly 4
- [ ] Domain signal count: 9 in CLAUDE.md, 14 in full stakeholder-guide.md
- [ ] 16-section profile template (all profiles)

---

## Common Generation Failures (Anti-Patterns to Check)

### Generic Profiles
- [ ] Check that 3 profiles have differentiated red flags (not all saying the same things)
- [ ] Check that adversarial language differs by domain (Security ≠ DevOps ≠ SRE)

### Format Drift
- [ ] PERSPECTIVE block format consistent across CLAUDE.md, preamble, workflow-stages
- [ ] HANDBACK field names identical in all references
- [ ] Quality gate counts match everywhere (CLAUDE.md, quality-framework, worked-examples)

### Missing Adversarial Framing
- [ ] Check 3 profiles: "When Supporting" section includes "actively probe" language
- [ ] Check adversarial review sections: must say "Find the single most important problem"
- [ ] STRONGEST OBJECTION fields: check that 2-3 example handbacks have genuine objections (not weak)

### TENSION Items
- [ ] Check workflow-stages: TENSION items described as protected (cannot be removed)
- [ ] Check stakeholder-guide: TENSION classification type present

---

## End of Checklist

This checklist covers structural verification of all components. For functional validation, see `smoke-tests.md`. For common generation mistakes, see `anti-patterns.md`.
