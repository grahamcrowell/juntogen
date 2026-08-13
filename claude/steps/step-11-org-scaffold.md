<!-- TODO(BL-025-l.1): org-scaffold tree placement deferred — the
     `org-scaffold/` directory currently lives at the plugin root in
     this prompt's output paths (the legacy `src/` wrapper has been
     mechanically dropped per the BL-025-m.2 sweep). Final placement
     (plugin-internal vs. user-repo-local vs. separate distribution)
     is open and deferred to BL-025-l.1. -->

# Generation Prompt: Step 11 — Org Scaffold

**Purpose**: Generate the org-level `.claude` coordination repo scaffold for org coordination.

> **Note on spec dependency**: This prompt references `D80-org-coordination.md`. If spec D80 is unavailable, draft the scaffold based on this prompt's Key Requirements — the spec defines the same model.

---

## Input

### Specification Files

Read these spec files before generating:

1. `D80-org-coordination.md` — Authoritative source for org coordination concept, three-tier inheritance model, reference file scoping rules, org/project boundary definitions, and scaffold content requirements
2. `F16-architecture.md` — Installed layout (global `~/.claude/` structure, source→target mapping) — org coordination extends this, does not replace it
3. `D48-reference-system.md` — Reference file scoping and tier-aware loading — org coordination extends scoping to org level
4. `D72-enterprise-overlay.md` — Enterprise overlay pattern (additive files, separation principle) — org coordination is a distinct but related concept

### Context Files

These files provide generatable content that the scaffold files can reference or adapt:

- `juntogen/claude/steps/step-04-reference-files.md` — Reference file format conventions (topic coverage, structure)
- `juntogen/claude/steps/step-06-commands.md` — Command file format conventions (YAML frontmatter, section headings)

---

## Task

Generate the **org-level scaffold**: a set of seed files for a new git repository that will serve as an org-level coordination hub across multiple projects.

**What this step produces**: Files for a standalone git repo (the "org `.claude` repo"), not files for any individual developer's `~/.claude/` directory and not per-project `.claude/` files.

**What this step does NOT produce**:
- Per-project `.claude/` files (those are seeded by steps 01-10 per project)
- Developer-global `~/.claude/` files (those are installed by `make install`)
- Generated code or org-specific content (Axiom 7 — scaffold must be generic)

### Output Target

All generated files go into a single output directory: `org-scaffold/`. The installer (`make org-scaffold`) copies these files into a user-specified target directory (the org git repo root).

### Files to Generate

```
org-scaffold/
├── .gitignore                          # Excludes volatile state from version control
├── README.md                           # Orientation: what this repo is, how to use it
├── BACKLOG.md                          # Org-level backlog (aggregate cross-project view)
├── llms.txt                            # Org context map (cross-project navigation index)
├── reference/
│   ├── validated-facts-org.md          # Template for org-validated facts (services, baselines)
│   └── org-coordination-guide.md       # How to use the org .claude repo day-to-day
├── commands/
│   ├── health-check.md                 # Org-scope health check command
│   └── intake.md                       # Inbound task intake command (org scope)
├── state/
│   └── .gitkeep                        # Ensures state/ directory exists; contents gitignored
├── artifacts/
│   ├── analysis/
│   │   └── .gitkeep
│   └── adr/
│       └── .gitkeep
└── profiles/                           # Layout profiles for a per-project .claude/
    ├── README.md                       # flat vs hierarchy: comparison, choosing, switching cost
    └── hierarchy/                      # The type-based profile, ready to copy into a project
        ├── oj-paths.env                # layout=hierarchy + backlog-glob= (the activating file)
        ├── backlog.md                  # Root-node backlog (one file in a set)
        ├── decisions.md                # Root-node decision log
        ├── open-questions.md           # Root-node open questions
        ├── facts/
        │   └── README.md               # The provenance rule (MEASURED/DERIVED/ASSERTED-UNVERIFIED)
        └── [PROJECT_NODE]/             # One example node showing the four typed files
            ├── README.md               # What the node carries; nesting guidance
            ├── requirements.md
            ├── design.md
            ├── plan.md                 # Also this node's backlog (reached by backlog-glob)
            └── decisions.md
```

---

## Key Requirements

### 1. `.gitignore`

Must exclude volatile state while preserving directory structure:

```
# Volatile session state — not shared across team members
state/*
!state/.gitkeep

# Local editor artifacts
.DS_Store
*.swp
```

**Rationale**: `state/session.md` is per-session, per-developer working memory. Committing it creates merge conflicts and leaks individual session context into shared history. The `.gitkeep` preserves the directory for first-time cloners.

### 2. `README.md`

**Purpose**: Answer the three questions a new team member asks when they first clone this repo.

**Required sections** (structure may vary; content must cover all three):

1. **What this repo is**: One paragraph. This is the org-level coordination hub for the OpenJunto Claude Code configuration. It holds shared reference material, org-level backlog, context maps, and slash commands that span across the individual project repos the org manages. It is NOT a per-developer Claude Code installation — those live in `~/.claude/`.

2. **How it relates to per-project `.claude/` directories**: Brief explanation of the three-tier inheritance model (global `~/.claude/` → org repo → per-project `.claude/`). The org repo is a source of shared reference, not a config directory that Claude Code reads automatically. Developers load org reference files explicitly (via Read tool or by copying to `~/.claude/reference/`).

3. **How to use it**: Practical quick-start — where to find the backlog, how to run org-level commands (if using Claude Code pointed at this repo), how per-project teams reference org content. Include one concrete example (e.g., "to run the org health check: point Claude Code at this directory and run `/health-check`").

**Tone**: Concise, orientation-focused. Not a spec document. Target: a developer who just cloned the repo for the first time.

### 3. `BACKLOG.md`

Seed with the standard OpenJunto BACKLOG.md structure but scoped to org-level concerns.

**Required structure**:

```markdown
# Backlog

<!-- Org-level coordination backlog. For per-project backlogs, see each project's .claude/BACKLOG.md -->

## Active

<!-- Add org-level items here. Format:
### BACK-NNN: [Title]
**Priority**: High | Medium | Low
**Status**: Open | In Progress
**Created**: YYYY-MM-DD
**Description**: [What and why]
-->

## Completed

<!-- Completed items archived here. Keep for reference. -->
```

The scope comment at the top is required — it makes the org/project boundary explicit for future users.

### 4. `llms.txt`

**Purpose**: Cross-project context map — a lightweight index of all repos and their `.claude/` entry points.

**Format**: Plain text, following the established `llms.txt` convention (one entry per repo, relative paths or absolute, with a one-line description).

**Required sections**:

```
# Org Context Map
# This file lists the repos this org coordinates and their .claude/ entry points.
# Update when repos are added or removed from the org.

## Org Coordination (this repo)
[description of what this repo contains]

## Projects
[REPO_NAME_1]: [path or URL] — [one-line description]
[REPO_NAME_2]: [path or URL] — [one-line description]
# Add entries as repos join the org

## Shared Reference
[path to key reference files in this repo]
```

**Design intent**: The placeholder entries make the maintenance contract visible — the file is meant to be kept current. Use `[REPO_NAME_N]` placeholders, not real org repo names (Axiom 7).

### 5. `reference/validated-facts-org.md`

**Purpose**: Template for org-validated facts — authenticated services, shared API baselines, infrastructure constants that are true across all projects.

**STRUCTURAL** — must contain these sections:

```markdown
# Org Validated Facts

<!-- Org-level facts validated against authoritative sources.
     Evidence required for each entry. Per-project facts belong in each project's .claude/reference/.
     See D80-org-coordination.md § Reference File Scoping for the org/project boundary rule. -->

## Authenticated Services
<!-- Org-wide service registry: APIs, databases, messaging platforms that all projects may interact with.
     Format: Service Name | Base URL/endpoint | Auth method | Validated date -->

## Shared Infrastructure Constants
<!-- Values that are true across all deployments: region, cluster names, shared config keys.
     Format: Key | Value | Source | Validated date -->

## API Baselines
<!-- Known-good API behaviors, rate limits, pagination patterns validated empirically.
     Format: Service | Endpoint | Behavior | Validated date | Evidence -->
```

**Important**: Each section has a scope comment distinguishing it from per-project validated-facts. This enforces FINDING-6 (org/project boundary markers).

### 6. `reference/org-coordination-guide.md`

**Purpose**: Day-to-day usage guide for the org `.claude` repo. Not a spec — operational guidance.

**Required sections**:

1. **Repo anatomy**: One-sentence purpose for each file/directory (mirrors the scaffold structure)
2. **Updating shared reference**: When and how to update `validated-facts-org.md`, `llms.txt`, and other org reference files
3. **Org vs. project scope decision rule**: When does content belong in the org repo vs. a project's `.claude/`? Derived from spec D80 § Reference File Scoping:
   - **Org scope**: Facts and patterns that apply to 2+ projects, authenticated service registries, cross-project coordination commands
   - **Project scope**: Session state, project backlog, project-specific artifacts, per-environment configs
4. **Adding a new project to the org**: Checklist — create project `.claude/` scaffold, add entry to `llms.txt`, consider whether any project reference should graduate to org scope
5. **Health check cadence**: How often to run `/health-check`, what stale state looks like, what to do when found

### 7. `commands/health-check.md`

**Purpose**: Org-scope health check — verify the org `.claude` repo and all coordinated projects are in coherent state.

**YAML frontmatter**:
```yaml
---
description: "Org health check — verify coordination repo and all projects are in coherent state"
---
```

**Required checks (in order)**:

1. **Org repo state**: Is `llms.txt` present and non-empty? Is `BACKLOG.md` present? Is `state/` gitignored?
2. **Project inventory**: For each project listed in `llms.txt`, confirm the entry path/URL is reachable (local path check or note if remote)
3. **Stale state detection**: Check `state/` — if `session.md` is committed (not gitignored), flag as error
4. **Org backlog coherence**: Scan `BACKLOG.md` — any items blocked by completed items? Any items without owners that are marked In Progress?
5. **Reference freshness signal**: Report age of last modification to `validated-facts-org.md` (older than 30 days = advisory)

**Output format**: Structured report with PASS / WARN / FAIL per check. Example:

```
[PASS] llms.txt present (N projects listed)
[PASS] BACKLOG.md present (N open items)
[PASS] state/ gitignored
[WARN] validated-facts-org.md last updated 47 days ago — consider reviewing
[FAIL] state/session.md is tracked by git — add to .gitignore
```

**Constraints**: Read-only — no modifications. Observations only, no auto-fix.

### 8. `commands/intake.md`

**Purpose**: Inbound task intake at org scope — triage and route new work to the right project backlog or org backlog.

**YAML frontmatter**:
```yaml
---
description: "Org intake — triage inbound request and route to org or project backlog"
---
```

**Required steps**:

1. **Capture the request**: Ask the user for the inbound request if not provided. Read org `BACKLOG.md` and `llms.txt` for context.
2. **Scope triage**: Is this org-level work (affects 2+ projects, coordination concern) or single-project work? If single-project, identify which project from `llms.txt`.
3. **Standard OpenJunto triage**: Apply the two-dimensional triage (execution model + stakeholder identification) to the scoped request.
4. **Route**:
   - **Org scope**: Add to org `BACKLOG.md` with appropriate priority
   - **Project scope**: Provide the BACKLOG.md item text for the user to add to the target project's backlog (do not write to project repos directly — the org repo has no authority over project files)
5. **Confirm**: Present routing decision and backlog item draft to user before writing anything.

**Constraint**: The org intake command must NOT write to per-project `.claude/` files. Routing is advisory — the user carries the item to the right project. This enforces the org/project boundary.

---

## Structural Requirements

### Org/Project Boundary Markers

Every generated file that has an org/project scope distinction MUST include a comment or callout making the boundary explicit. This is required by FINDING-6.

Pattern:
```markdown
<!-- Scope: org-level. Per-project equivalent: [project]/.claude/[filename] -->
```

### Generic Placeholders

All files must use generic placeholders, not org-specific names. Required substitutions:

| Placeholder | Meaning | Example usage |
|-------------|---------|---------------|
| `[ORG_NAME]` | Organization name | README.md title |
| `[REPO_NAME_N]` | Individual project repo name | llms.txt entries |
| `[ORG_REPO_PATH]` | Path to org `.claude` repo | README.md how-to-use |

**Axiom 7 enforcement**: No file may contain references to real organization names, internal tooling names, or org-specific service names. The scaffold must be generically applicable to any organization using OpenJunto.

### File Header Convention

Each generated file begins with a comment block identifying its scope and purpose:

```markdown
<!-- Org Scaffold: [filename]
     Scope: org-level coordination
     Source: generated by step-11-org-scaffold
     See: D80-org-coordination.md for full specification -->
```

This header enables `/health-check` to verify scaffold completeness (files with this header are scaffold-origin files; modified files have different headers or none).

---

### 9. `profiles/` — both layout profiles

**Purpose**: `org-scaffold/` is what OpenJunto **propagates**, so a scaffold that ships only one layout means every new project starts in that shape regardless of what `resolve-path` can express. Shipping both is what makes the target property real: *OpenJunto can express a layout it does not impose.*

**The flat profile is the existing scaffold tree, UNCHANGED.** Do not move `BACKLOG.md`, `artifacts/`, `state/`, `reference/`, or `llms.txt` into a `profiles/flat/` directory. Relocating them would be a breaking change for every adopter, to express something a paragraph in `profiles/README.md` already says. The flat profile is the root of the scaffold; `profiles/` holds only the alternative and the comparison.

#### `profiles/README.md`

A comparison table (`flat` vs `hierarchy`) across: how the profile is selected, backlog shape, where a produced document goes, what the category keys resolve to, and which project shape each suits. Then:

- **`flat` is the default and the right answer more often than not.** State plainly that a small project is well served by one `BACKLOG.md`, and that adopting the hierarchy because it *looks* more rigorous costs real filing effort per document and returns nothing. A generator that presents the hierarchy as the upgrade path has mis-stated the design.
- **The switch signal is not size alone** - it is when a single file has stopped answering a single question (a `BACKLOG.md` that has become several project plans wearing one filename).
- **What adopting `hierarchy` obliges you to maintain**: ids unique across the whole file set rather than per file (with `oj-helper backlog-lint` as the check); a filing decision per document (pointing at `${CLAUDE_PLUGIN_ROOT}/reference/file-patterns.md` § Filing Rule, and naming both tie-breaker rules); and `artifacts` left unset, because setting it re-creates the dump directory the taxonomy exists to remove.
- **Switching either way is cheap**: write or delete `.claude/oj-paths.env` and move files. The plugin keeps no state about the profile and re-reads it per call, so there is no migration and nothing to keep in sync. Say "start flat."

#### `profiles/hierarchy/`

A per-project `.claude/` template, copied in and de-placeholdered. Contents:

- **`oj-paths.env`** — the activating file. Carries `layout=hierarchy`, a `backlog-glob=` line, and comments explaining the `.claude/` prefix rule and the stderr warning for a relative value that escapes the state tree. Two comment blocks are load-bearing and MUST survive: (a) **anchor each glob pattern at a node** - a bare `.claude/**/plan.md` also matches archived plans under a history area, silently pulling retired work into every listing; (b) **`artifacts` and `id-index` are deliberately NOT set**, with the reason for each stated, so a reader does not "helpfully" fill them in.
- **`backlog.md`** — the root-node backlog, in the § Backlog Item Schema shape, carrying a prominent callout that it is **one file in a set**: read the whole set with `oj-helper backlog-list`, and ids are unique across the set rather than per file. Retains the single-source-discipline comment, noting it matters MORE under a split backlog because more files can now hold a stale copy of the same external state.
- **`decisions.md`** and **`open-questions.md`** — root-node logs, each stating what belongs in it versus the neighbouring types, and each with a real format block. `decisions.md` must state that the file ACCUMULATES and that superseded entries are marked, never edited or deleted - a log whose entries get rewritten cannot answer "why did we do it that way", which is the only question it exists to answer. `open-questions.md` must require a "what would settle it" field and must state that closing a question means moving the answer to `decisions.md` or `facts/`.
- **`facts/README.md`** — **the provenance rule**, stated as required rather than recommended, with the three-marker table (`MEASURED` naming the command/query, `DERIVED` naming its inputs, `ASSERTED-UNVERIFIED` naming the verification path). Must include: prefer `ASSERTED-UNVERIFIED` with a verification path over a bare number, because an unmarked number is indistinguishable from a measured one and quietly becomes load-bearing; and never upgrade a marker without running the check that justifies it (age is not evidence).
- **`[PROJECT_NODE]/`** — exactly ONE example node with `README.md`, `requirements.md`, `design.md`, `plan.md`, `decisions.md`, mapping each file to its `resolve-path` key. The node README shows the nesting form (a subdirectory per subject) and says to nest only when a file has stopped answering one question, not in advance. `design.md` must carry the **"this is not a review"** callout; `plan.md` must state that it is ALSO this node's backlog and must warn against a trivially-green `verify:` value (`true`, `:`, `echo`, `exit 0`), since that value is copied verbatim into the backlog item's `AC` on graduation.

**Placeholders**: `[PROJECT_NODE]`, `[SUBJECT]`, `[PREFIX]`, `[DOMAIN]` — Axiom 7 applies to this subtree exactly as it does to the rest of the scaffold.

**Verify the profile actually resolves.** After generation, copy `profiles/hierarchy/` into a scratch `.claude/`, rename `[PROJECT_NODE]`, substitute the token in `oj-paths.env`, then assert that all six category keys resolve at the root node, that `--node` resolves at both one and two levels deep, that `artifacts` still returns the flat default (the profile must not set it), that `backlog-list` finds every planted file with no placeholder leakage, and that `resolve-path` emits no prefix warning from the shipped `oj-paths.env`. A scaffold that documents a layout the helper cannot resolve is worse than no scaffold.

---

## Verification

After generation, verify:

### File Completeness
- [ ] All 11 flat-profile files/directories present (`.gitignore`, `README.md`, `BACKLOG.md`, `llms.txt`, `reference/validated-facts-org.md`, `reference/org-coordination-guide.md`, `commands/health-check.md`, `commands/intake.md`, `state/.gitkeep`, `artifacts/analysis/.gitkeep`, `artifacts/adr/.gitkeep`) — **at the scaffold ROOT, not relocated under `profiles/flat/`**
- [ ] All 11 `profiles/` files present (`profiles/README.md`; `profiles/hierarchy/` × `oj-paths.env`, `backlog.md`, `decisions.md`, `open-questions.md`, `facts/README.md`; `profiles/hierarchy/[PROJECT_NODE]/` × `README.md`, `requirements.md`, `design.md`, `plan.md`, `decisions.md`)
- [ ] `.gitignore` excludes `state/*` while preserving `state/.gitkeep`
- [ ] All `.gitkeep` files present in empty directories

### Layout Profiles
- [ ] `profiles/README.md` presents `flat` as the default and the common-case answer — NOT as a stage to graduate from
- [ ] `profiles/README.md` states what adopting `hierarchy` obliges the project to maintain (set-wide unique ids, a filing decision per document, `artifacts` left unset)
- [ ] `profiles/hierarchy/oj-paths.env` sets `layout=hierarchy` and a `backlog-glob=`, and does NOT set `artifacts` or `id-index` — each with its reason stated in a comment
- [ ] `profiles/hierarchy/oj-paths.env` warns that glob patterns must be anchored at a node, so an unanchored `**` does not pull in archived plans
- [ ] `profiles/hierarchy/facts/README.md` states the provenance rule as REQUIRED, with all three markers and the "prefer ASSERTED-UNVERIFIED with a verification path over a bare number" instruction
- [ ] `profiles/hierarchy/[PROJECT_NODE]/design.md` carries the "a review is not a design" callout
- [ ] `profiles/hierarchy/[PROJECT_NODE]/plan.md` states it is also the node's backlog and warns against a trivially-green `verify:` value
- [ ] `profiles/hierarchy/backlog.md` states it is one file in a set and that ids are unique across the set
- [ ] **Live resolution check**: the copied-and-de-placeholdered profile resolves — six category keys at the root node, `--node` at one and two levels deep, `artifacts` still the flat default, `backlog-list` finding every file with no placeholder leakage, and no prefix warning on stderr

### Axiom 7 (No Org-Specific Content)
- [ ] No real organization names in any file
- [ ] No real service names, URLs, or API endpoints in any file
- [ ] All org-specific values use `[PLACEHOLDER]` format
- [ ] Scope comments distinguish org/project boundary in every file that has a dual-scope equivalent

### Format Correctness
- [ ] Both command files have YAML frontmatter with `description` field
- [ ] `README.md` answers all three orientation questions (what/how-it-relates/how-to-use)
- [ ] `BACKLOG.md` has scope comment at top
- [ ] `llms.txt` has Update instruction comment (maintenance contract visible)
- [ ] `validated-facts-org.md` has all three sections with scope comments
- [ ] `health-check.md` produces structured PASS/WARN/FAIL output
- [ ] `intake.md` does NOT write to per-project files (constraint is explicit)

### Boundary Markers
- [ ] Every file with an org/project scope distinction has the boundary comment
- [ ] File header convention (Org Scaffold comment block) present in each generated file

---

## Dependencies

**Requires**:
- `D80-org-coordination.md` (spec D80) — defines the org coordination concept this prompt generates for
- Steps 01-10 do NOT need to be complete — step-11 generates an independent repo scaffold, not extensions of the per-developer install

**Does NOT require**:
- `platform-snapshot.yaml` — no platform-specific facts in the org scaffold
- Prior generation steps — the org scaffold is independent of the per-developer install

**Consumed by**:
- DEFERRED to BL-025-l.1 — the Makefile installer (formerly step-08) is retired in plugin form (BL-025-m.1). The org-scaffold install path (whether by plugin-host copy, by user-driven `git clone`, or by a separate `oj-helper org-scaffold-install` subcommand) is open and waiting on the L.1 tree-placement decision.

> **Open dependency**: The installer chain does not include an org-scaffold target post-Makefile-retirement. The decision (plugin-internal install copy vs. user-driven repo template vs. separate distribution) is deferred to BL-025-l.1. Flag for backlog.

---

## Output

After completing this step:

```
org-scaffold/
├── .gitignore
├── README.md
├── BACKLOG.md
├── llms.txt
├── reference/
│   ├── validated-facts-org.md
│   └── org-coordination-guide.md
├── commands/
│   ├── health-check.md
│   └── intake.md
├── state/
│   └── .gitkeep
├── artifacts/
│   ├── analysis/
│   │   └── .gitkeep
│   └── adr/
│       └── .gitkeep
└── profiles/
    ├── README.md
    └── hierarchy/
        ├── oj-paths.env
        ├── backlog.md
        ├── decisions.md
        ├── open-questions.md
        ├── facts/
        │   └── README.md
        └── [PROJECT_NODE]/
            ├── README.md
            ├── requirements.md
            ├── design.md
            ├── plan.md
            └── decisions.md
```

These files are the seed content for any new org `.claude` coordination repo. They are not installed by `make install` — they require the separate `make org-scaffold` operation with a user-specified target directory.

The scaffold root is the `flat` profile; `profiles/hierarchy/` is the alternative, copied into a per-project `.claude/` by a project that needs it. Both ship, and neither is imposed — that is the point of shipping both.
