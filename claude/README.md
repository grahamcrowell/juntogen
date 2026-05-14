# Generation Prompts

This directory contains structured prompts for generating the OpenJunto system from the specification files.

## Purpose

Each prompt corresponds to a phase of system generation. The prompts are self-contained (include all required inputs) but sequenced (later prompts depend on outputs from earlier prompts).

## Sequencing

The generation prompts are numbered for sequential execution:

0. **step-00-platform-ingestion.md** — Ingest Layer 0 platform capabilities → `platform-snapshot.yaml`
1. **step-01-scaffold-and-protocol.md** — Generate project structure + CLAUDE.md (core manager protocol)
2. **step-02-agent-preamble-and-index.md** — Generate _preamble.md + index.md (shared agent infrastructure)
3. **step-03-agent-profiles.md** — Generate 16 full profiles + 16 compact profiles
4. **step-04-reference-files.md** — Generate 8 reference documents (workflow-stages.md, stakeholder-guide.md, etc.)
5. **step-05-templates.md** — Generate 5 deliverable templates (technical-analysis.md, architecture-decision-record.md, etc.)
6. **step-06-commands.md** — Generate 3 core slash commands (/run-task, /show-backlog, /save-session)
7. **step-07-helper-script.md** — Generate oj-helper bash script (profile injection, issue tracker integration) + static `.claude-plugin/plugin.json` + `hooks/hooks.json` (BL-025-m.1)
8. _step-08 retired (BL-025-m.1) — Makefile installer obsolete in plugin form. Numeric gap preserved so log/sentinel history stays comparable._
9. **step-09-settings-and-hooks.md** — Generate settings.json (VS Code configuration and SubagentStart hook)
10. **step-10-documentation.md** — Generate README.md + WHY.md (system documentation)
11. **step-11-org-scaffold.md** — Generate org scaffold (`src/org-scaffold/`) — seed files for an org-level coordination repo

### Dependencies

```
step-00 (no dependencies — new root)
  ↓
step-01 (requires: platform-snapshot.yaml from step-00)
  ↓
step-02 (requires: project structure from step-01)
  ↓
step-03 (requires: preamble from step-02, CLAUDE.md from step-01)

step-04 (requires: CLAUDE.md from step-01 for format references)
step-05 (requires: reference files from step-04 for template alignment)
step-06 (requires: CLAUDE.md from step-01 for triage/tier references)

step-07 (requires: step-06 for command references to oj-helper)
step-08 (retired — BL-025-m.1)
step-09 (requires: step-00 for platform snapshot; step-07 for hook references to oj-helper)
step-10 (requires: steps 01-09 for documentation of complete system)
step-11 (requires: spec D80 only; independent of steps 00-10)
```

**Parallelization**: Step 00 runs first and is fast (file copy + metadata). Once `platform-snapshot.yaml` exists, steps 01 and 09 can consume it. Steps 04, 05, and 06 can run in parallel — they are independent of each other and only depend on step-01. Steps 07 and 09 have sequential dependencies on prior steps. Step 10 should be last (documents the complete per-developer install). Step 11 is independent — it can run any time spec D80 is available, in parallel with steps 00-10. (Step 08 retired per BL-025-m.1; numeric gap preserved.)

## Levels of Specificity

The specification operates at six levels, and the generation prompts respect these distinctions:

| Level | Intent | Examples | How Prompts Handle |
|-------|--------|----------|-------------------|
| **Derived** | Computed from axioms/platform/measurements via derivation chains | PERSPECTIVE block format, HANDBACK format, triage criteria/scoring, quality gate counts (2/6/9), model selection table, stakeholder thresholds | Prompts include derivation chain outputs; validated by property checking (chain produces same output given current inputs) |
| **Exact** | Reproduce precisely — identity matters | `<!-- oj-expert: -->` marker, role declaration opening line, "OpenJunto" header, hook names/parameters | Prompts explicitly list exact strings that must be copied verbatim |
| **External** | Platform fact — fetched or declared | Model `api_id` strings, tool availability, context window sizes, cost ratios, hook matcher values | Prompts consume `platform-snapshot.yaml` produced by Step 00. Annotated **[EXTERNAL]** in Key Requirements sections. Current values in `platform-defaults.yaml`. |
| **Structural** | Structure must match, prose varies | CLAUDE.md section organization, 16-section profile template, reference file topic coverage | Prompts specify required sections, tables, and organization without prescribing exact wording |
| **Design intent** | Principle only, LLM implements | Domain-specific expert profile content, stakeholder key questions, worked example scenarios | Prompts describe the principle and desired outcome, allowing LLM to generate appropriate content |
| **Axiom** | Foundational principle from spec F08 | The 8 axioms in `F08-axioms.md` | Prompts reference axioms as derivation chain inputs, not as content to generate |

## Using the Prompts

### For Each Step

1. **Read the Input section** — Load the specified spec files before proceeding
2. **Read the Task section** — Understand what to generate
3. **Review Key Requirements** — Pay special attention to exact format strings and structural requirements
4. **Generate** — Produce the artifacts
5. **Verify** — Use the verification checklist to confirm correctness

### Format of Each Prompt

Each prompt file contains:

- **Input**: Which specification files and reference files to read
- **Task**: Clear description of what to generate (files, counts, locations)
- **Key Requirements**: Exact format strings, structural requirements, and design intent to follow
- **Verification**: How to check the output is correct
- **Dependencies**: What must be complete before this step

### Self-Contained Design

Each prompt is fully self-contained — it lists all inputs (spec files, reference files) needed to complete the generation task. You do not need to maintain state between prompts beyond the generated artifacts themselves.

### Output Validation

After completing each step:
1. Check file counts (e.g., "16 full profiles" means exactly 16)
2. Verify exact format strings appear verbatim
3. Confirm section organization matches specification
4. Cross-reference dependencies between files resolve correctly
5. **[EXTERNAL] elements**: Verify values match `platform-snapshot.yaml`, not hardcoded strings from `platform-defaults.yaml` directly. If the snapshot differs from defaults (custom declaration), generated artifacts must reflect the snapshot values.

## Example: Generating step-00 (new root)

```bash
# 1. Read inputs
cat platform-defaults.yaml
# Optionally: provide platform-declaration.yaml for custom platform

# 2. Read the prompt
cat steps/step-00-platform-ingestion.md

# 3. Generate (via LLM or manual implementation)
# Creates:
#   platform-snapshot.yaml  (Layer 0 capability snapshot)

# 4. Verify
# - platform-snapshot.yaml exists
# - _meta.mode is "declaration" or "defaults"
# - models section has haiku/sonnet/opus with api_id fields
# - Step 01 can now consume models from snapshot
```

## Example: Generating step-01

```bash
# 1. Read inputs (platform snapshot first, then spec files)
cat platform-snapshot.yaml
cat F08-axioms.md F16-architecture.md D08-core-protocol.md

# 2. Read the prompt
cat steps/step-01-scaffold-and-protocol.md

# 3. Generate (via LLM or manual implementation)
# Creates:
#   src/CLAUDE.md
#   src/agents/ (directory)
#   src/agents/compact/ (directory)
#   src/templates/ (directory)
#   src/commands/ (directory)
#   src/reference/ (directory)

# 4. Verify
# - CLAUDE.md has 10 major sections
# - All EXACT format strings match spec
# - Circuit breaker thresholds (3 revisions, 2 hours) present
# - Quality gate counts (2/6/9) correct
# - Model selection table reflects platform-snapshot.yaml model roster
```

## Post-Generation Validation

After completing all generation steps, use the validation tools in `../validation/`:

- **checklist.md** — Manual structural verification
- **smoke-tests.md** — Functional tests for critical paths
- **anti-patterns.md** — Common generation mistakes to check for

## Notes

- **Organization-agnostic**: These prompts generate the core OpenJunto system only. Enterprise overlays are not covered here.
- **Token efficiency**: The prompts reference spec files rather than embedding full content, keeping token usage manageable.
- **Iterative refinement**: If a generation step produces incorrect output, review the Key Requirements section and regenerate.
- **Reference the source**: When in doubt about format or structure, refer back to the actual OpenJunto source files listed in each prompt's Input section.
