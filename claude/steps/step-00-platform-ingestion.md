# Generation Prompt: Step 00 — Platform Capability Ingestion

**Purpose**: Ingest Layer 0 platform capabilities and produce a `platform-snapshot.yaml` file consumed by all downstream generation steps.

---

## Input

### Specification Files
Read this spec file before generating:
- `M16-derivation-architecture.md` — Section 3 (Platform Capability Ingestion) defines the required capability schema, ingestion modes, and fallback behavior

### Reference Files
- `juntogen/claude/platform-defaults.yaml` — Curated offline fallback representing the current Claude Code platform. Used as fallback when no declaration file is provided and introspection is unavailable.

### Optional Declaration File
- `platform-declaration.yaml` — If this file exists in the generation working directory, use it as the capability source (static declaration mode). Declaration has highest priority — it represents explicit operator intent and overrides all other modes.

---

## Task

Produce a **`platform-snapshot.yaml`** file in the generation working directory.

This file captures the platform capabilities that derivation chains require as Layer 0 inputs (per spec M16 §3). It is consumed by all downstream generation prompts that reference [EXTERNAL] elements — platform facts that are fetched or declared, not derived from axioms.

**File location**: `platform-snapshot.yaml` (generation working directory root)

**Pre-step — Introspection** (optional, runs before mode selection):
If the generation session is a live Claude Code session and no `platform-declaration.yaml` already exists, the introspection sub-step runs first. It enumerates tools, models, and capabilities from the running session's system prompt and tool definitions, fills unobservable fields from `platform-defaults.yaml`, and writes the result as `platform-declaration.yaml` in the generation working directory. See Introspection Sub-Step below. This sub-step emits a CI-safety warning to stdout: `"WARNING: introspection-produced platform-declaration.yaml is environment-dependent and not reproducible across sessions — use a hand-authored declaration for CI pipelines"`

**Mode selection** (in priority order):
1. If `platform-declaration.yaml` exists (whether hand-authored or produced by the introspection sub-step) → **declaration mode**: copy its contents into `platform-snapshot.yaml`, adding `_meta.mode: declaration` and `_meta.generated_at`. If the declaration was produced by introspection, also include `_meta.introspection_coverage` (see schema below).
2. If `platform-declaration.yaml` does not exist but `platform-defaults.yaml` exists → **defaults mode**: copy `platform-defaults.yaml` into `platform-snapshot.yaml`, adding `_meta.mode: defaults` and `_meta.generated_at`
3. If neither file exists → **inline defaults mode**: emit the hardcoded constants below directly into `platform-snapshot.yaml`, set `_meta.mode: inline-defaults`, emit a warning to stdout: `"WARNING: platform-defaults.yaml not found — using inline hardcoded defaults. Pipeline will continue but defaults may be stale."` The inline constants are identical to `platform-defaults.yaml` version 1.0.0 and must be kept in sync if that file is updated.

---

## Key Requirements

### EXTERNAL Elements (Platform Facts — Must Reflect Actual Platform)

#### Capability Schema

The `platform-snapshot.yaml` must conform to this schema (per spec M16 §3, with additions from stakeholder synthesis):

```yaml
_meta:
  schema_version: "1.0"
  mode: "declaration" | "defaults" | "inline-defaults"
  generated_at: "YYYY-MM-DDTHH:MM:SSZ"  # ISO 8601 timestamp
  defaults_version: "1.0.0"          # version of platform-defaults.yaml used (for staleness detection)
  defaults_version_date: "YYYY-MM-DD" # version_date from platform-defaults.yaml (for staleness check against current date)
  introspection_coverage:             # present when mode=declaration AND source was introspection sub-step
    tools: "full"                     # tool names enumerable from system prompt
    tool_parameters: "full"           # parameter schemas enumerable from tool definitions
    models_own: "full"                # own model ID + context window from system prompt
    models_roster: "partial"          # other models' IDs from system prompt; details from defaults
    hooks: "none"                     # not visible in system prompt; from defaults
    constraints: "none"               # not visible in system prompt; from defaults
    cost_ratios: "none"               # not in system prompt; from defaults

platform:
  tools:
    # Platform name: "Agent" | Spec vocabulary: "Task tool" (delegation primitive)
    - name: "Agent"
      available: true
      parameters: ["description", "model", "plan_mode_required", "subagent_type"]
    - name: "TeamCreate"
      available: true
      parameters: ["team_name", "description"]
    - name: "TeamDelete"
      available: true
      parameters: ["team_id"]
    - name: "SendMessage"
      available: true
      parameters: ["to", "message", "summary"]
    - name: "TaskCreate"
      available: true
      parameters: ["subject", "description", "activeForm", "metadata"]
    - name: "TaskUpdate"
      available: true
      parameters: ["taskId", "status", "owner", "description", "subject", "activeForm", "metadata", "addBlocks", "addBlockedBy"]
    - name: "TaskList"
      available: true
      parameters: []
    - name: "TaskGet"
      available: true
      parameters: ["taskId"]
    - name: "Read"
      available: true
      parameters: ["file_path", "limit", "offset", "pages"]
    - name: "Edit"
      available: true
      parameters: ["file_path", "old_string", "new_string", "replace_all"]
    - name: "Write"
      available: true
      parameters: ["file_path", "content"]
    - name: "NotebookEdit"
      available: true
      parameters: ["notebook_path", "new_source", "cell_id", "cell_type", "edit_mode"]
    - name: "Bash"
      available: true
      parameters: ["command", "description", "timeout", "run_in_background", "dangerouslyDisableSandbox"]
    - name: "Glob"
      available: true
      parameters: ["pattern", "path"]
    - name: "Grep"
      available: true
      parameters: ["pattern", "path", "glob", "type", "output_mode", "context", "head_limit", "offset", "multiline", "-A", "-B", "-C", "-i", "-n"]
    - name: "Skill"
      available: true
      parameters: ["skill", "args"]
    - name: "ToolSearch"
      available: true
      parameters: ["query", "max_results"]
    - name: "WebFetch"
      available: true
      parameters: ["url", "prompt"]
    - name: "WebSearch"
      available: true
      parameters: ["query", "allowed_domains", "blocked_domains"]
    - name: "EnterWorktree"
      available: true
      parameters: ["name"]
    - name: "ExitWorktree"
      available: true
      parameters: ["action", "discard_changes"]
    - name: "CronCreate"
      available: true
      parameters: ["cron", "prompt", "recurring"]
    - name: "CronDelete"
      available: true
      parameters: ["id"]
    - name: "CronList"
      available: true
      parameters: []
    - name: "AskUserQuestion"
      available: conditional   # available in direct sessions; not in team sub-agent context
      parameters: ["questions", "answers", "annotations", "metadata"]  # confirmed: ToolSearch schema (2026-04-08); primary param is "questions" (array of question objects)
  models:
    - id: "haiku"
      api_id: "claude-haiku-4-5-20251001"   # actual API model string
      tier: "routine"
      context_window: 200000
      max_output_tokens: 64000
      cost_ratio: 1.0   # baseline; relative input token cost
    - id: "sonnet"
      api_id: "claude-sonnet-4-6"
      tier: "implementation"
      context_window: 1000000
      max_output_tokens: 64000
      cost_ratio: 3.0
    - id: "opus"
      api_id: "claude-opus-4-6"
      tier: "reasoning"
      context_window: 1000000   # confirmed: system prompt states "1M context"
      max_output_tokens: 128000
      cost_ratio: 5.0
  hooks:
    - point: "SubagentStart"
      capabilities: ["modify_prompt", "add_context"]
      matchers:
        - "general-purpose"   # agent types this hook fires for
    - point: "SessionStart"
      capabilities: ["run_command"]
      matchers: []            # fires for all sessions (no agent type filtering)
  constraints:
    max_concurrent_agents: 5
    max_concurrent_agents_type: "configured"  # "hard" = platform-enforced, "configured" = tunable
```

#### Schema Field Notes

- **`tools[].name`**: Platform tool name. Note: the agent-spawning tool is named `Agent` on the platform; the spec corpus (02-12) refers to it as "Task tool." See M16-derivation-architecture.md §3 for the mapping note.
- **`tools[].available`**: `true` for unconditionally available tools; `conditional` for tools available only in specific contexts (e.g., `AskUserQuestion` is not available in team sub-agent sessions).
- **`models[].api_id`**: The actual string used in Claude Code's `model` parameter and `settings.json`. Distinct from the symbolic `id` used in derivation chains and human-readable references. Downstream prompts (step-09) use `api_id` when generating `settings.json`.
- **`models[].max_output_tokens`**: Maximum output tokens per response for this model. Used by derivation chains that need to account for output length constraints (e.g., compact profile sizing, reference file budget). These are [EXTERNAL] platform facts — update when model limits change.
- **`models[].cost_ratio`**: Relative input token cost with haiku as 1.0 baseline. Used by Chain 7 (model selection) and Chain 6 (stakeholder escalation). Not an absolute price — update when relative costs shift significantly.
- **`_meta.introspection_coverage`**: Present when `mode=declaration` and the declaration was produced by the introspection sub-step. Per-category markers (`full`, `partial`, `none`) documenting which fields were observed from the live session vs. filled from defaults. Enables downstream consumers to assess confidence in platform facts.
- **`constraints.max_concurrent_agents_type`**: `configured` means the value is a tunable recommendation, not a hard platform ceiling. Derivation chains that use this value should apply it differently depending on type.
- **`hooks[].matchers`**: Agent types that trigger this hook. SubagentStart fires for `general-purpose` agents; SessionStart has no matcher (fires for all sessions).

### STRUCTURAL Elements

#### Metadata Block
Every snapshot must include the `_meta` block as the first key. It must contain:
- `schema_version` — version of this schema definition (`"1.0"`)
- `mode` — which ingestion mode was used (`declaration`, `defaults`, or `inline-defaults`)
- `generated_at` — ISO 8601 timestamp of when the snapshot was produced
- `defaults_version` — version field from `platform-defaults.yaml`, carried forward for staleness detection
- `defaults_version_date` — version_date field from `platform-defaults.yaml` (YYYY-MM-DD), used for staleness comparison against current system date
- `introspection_coverage` — (present when `mode=declaration` AND declaration was produced by introspection sub-step) per-category coverage markers (`full`, `partial`, `none`) documenting which fields were introspected vs. filled from defaults

#### Mode Documentation
The snapshot file must include a comment at the top documenting which mode was used and the source file:

```yaml
# platform-snapshot.yaml
# Generated by Step 00 — Platform Capability Ingestion
# Mode: [declaration|defaults|inline-defaults]
# Source: [platform-declaration.yaml|platform-defaults.yaml|<inline>]
# Introspection: [yes — declaration produced by introspection sub-step | no]
# See: M16-derivation-architecture.md §3 for schema definition
```

### DESIGN INTENT Elements

#### Graceful Degradation (Axiom 8)
Step 00 never hard-fails on a missing file. The three-tier fallback ensures the pipeline always produces a usable snapshot: declaration (custom or introspection-produced) → defaults file (maintained) → inline defaults (hardcoded). The introspection sub-step, when available, runs before mode selection and produces a `platform-declaration.yaml` — if it fails, mode selection proceeds without it. The inline defaults tier is the ultimate safety net — it reproduces the pre-Phase-3 pipeline behavior exactly, satisfying Axiom 8's requirement that the system degrade to known-good output rather than undefined behavior. A warning is emitted when inline defaults are used so operators know the defaults file is missing, but the generation pipeline continues.

#### Self-Contained Downstream Prompts
The snapshot is a separate file artifact (not an injected preamble) so that each downstream generation prompt can list it explicitly in its Input section. This preserves the self-contained design principle: every prompt declares all its inputs.

#### Introspection Sub-Step

When running in a live Claude Code session without an existing `platform-declaration.yaml`, the introspection sub-step runs **before** mode selection. It produces a `platform-declaration.yaml` in the generation working directory, which Step 00 then ingests via the existing declaration mode path. This follows the extension point architecture documented in the Dependencies section: introspection produces a declaration file, leaving Step 00's mode-selection logic unchanged.

**What introspection enumerates:**

1. **Tools (full)**: Parse the system prompt tool definitions. Each tool's name and complete parameter list (from JSONSchema `required` and `properties` fields) are directly available. Deferred tools (listed in `<available-deferred-tools>` blocks) are enumerated by name, then their full schemas are fetched via `ToolSearch` before emitting.
2. **Own model identity (full)**: The system prompt contains the running model's name, model ID, and context window (e.g., "You are powered by the model named Opus 4.6 (with 1M context). The exact model ID is claude-opus-4-6[1m].").
3. **Model roster (partial)**: Other model family IDs are listed in the system prompt (e.g., "Sonnet 4.6: 'claude-sonnet-4-6'"). However, their context windows, output limits, and cost ratios are NOT stated — these fields fall back to `platform-defaults.yaml`.

**What introspection CANNOT observe (filled from defaults):**

- Other models' `context_window` and `max_output_tokens`
- All models' `cost_ratio`
- Hook system details (`hooks` section)
- Concurrency constraints (`constraints` section)

**Introspection procedure:**

1. Parse system prompt tool definitions to enumerate all tool names and parameter schemas
2. Parse `<available-deferred-tools>` block to enumerate deferred tool names
3. Call `ToolSearch` to fetch full schemas for all deferred tools
4. Parse system prompt for model identity, model roster, and context window
5. Load `platform-defaults.yaml` for unobservable fields (hooks, constraints, cost ratios, other models' details)
6. Merge: introspected values override defaults for observable fields
7. Write `platform-declaration.yaml` with `introspection_coverage` block embedded (this block will be carried into `_meta` by Step 00's declaration mode). The output file must begin with:
    ```yaml
    # platform-declaration.yaml
    # INTROSPECTION-PRODUCED: {ISO 8601 timestamp}
    # Generated by Step 00 introspection sub-step — delete this file to fall back to defaults mode
    # See: juntogen/claude/steps/step-00-platform-ingestion.md for introspection procedure
    ```
8. Emit to stdout: `"Step 00 introspection: produced platform-declaration.yaml from system-prompt+platform-defaults.yaml"`
9. Emit CI-safety warning to stdout: `"WARNING: introspection-produced platform-declaration.yaml is environment-dependent and not reproducible across sessions — use a hand-authored declaration for CI pipelines"`

Step 00 mode selection then picks up the produced `platform-declaration.yaml` via declaration mode (priority 1).

**Completeness guard:** If the introspected tool count is less than 15, emit: `"WARNING: introspection may be incomplete — fewer tools than expected (found N, expected ≥15). Skipping introspection — mode selection will fall through to defaults."` Do not write `platform-declaration.yaml`; let mode selection proceed to defaults mode.

#### Dynamic Discovery Extension Point
Dynamic discovery (querying the Claude Code API at generation time for capabilities not visible in the system prompt) remains a future extension point. Unlike introspection (which parses the system prompt), discovery would query external APIs. When implemented, it would produce a `platform-declaration.yaml` that this prompt then ingests — leaving this step's logic unchanged.

---

## Verification

After producing `platform-snapshot.yaml`, verify:

### File Existence and Structure
- [ ] `platform-snapshot.yaml` exists in the generation working directory
- [ ] File begins with the mode/source comment block
- [ ] `_meta` block is the first YAML key
- [ ] `_meta.schema_version` is `"1.0"`
- [ ] `_meta.mode` is one of `declaration`, `defaults`, or `inline-defaults` (not blank)
- [ ] `_meta.generated_at` is a valid ISO 8601 timestamp
- [ ] `_meta.defaults_version` is present
- [ ] `_meta.defaults_version_date` is present (YYYY-MM-DD format)

### Schema Completeness
- [ ] `platform.tools` section present with at least 20 tool entries
- [ ] Each tool entry has `name`, `available`, and `parameters` fields
- [ ] `platform.models` section present with exactly 3 entries (haiku, sonnet, opus)
- [ ] Each model entry has `id`, `api_id`, `tier`, `context_window`, `max_output_tokens`, and `cost_ratio` fields
- [ ] `api_id` fields contain actual API model strings (not symbolic ids)
- [ ] `platform.hooks` section present with SubagentStart and SessionStart entries
- [ ] Each hook entry has `point`, `capabilities`, and `matchers` fields
- [ ] `platform.constraints` section present with `max_concurrent_agents` and `max_concurrent_agents_type`

### Mode Verification
- [ ] **Declaration mode**: If `platform-declaration.yaml` was present (hand-authored or introspection-produced), snapshot content reflects it (not just defaults)
- [ ] **Introspection sub-step**: If running in a live Claude session with no pre-existing declaration, introspection sub-step produced `platform-declaration.yaml`, CI-safety warning was emitted, and `_meta.introspection_coverage` is present in the resulting snapshot
- [ ] **Introspection completeness guard**: If introspected tool count < 15, a warning was emitted and `platform-declaration.yaml` was NOT written (mode selection falls through to defaults)
- [ ] **Defaults mode**: If no declaration file and no live session, but `platform-defaults.yaml` exists, snapshot content matches that file
- [ ] **Inline defaults mode**: If neither declaration nor defaults file exists, snapshot is produced (not an error), `_meta.mode` is `inline-defaults`, and a warning was emitted to stdout
- [ ] Mode is logged to stdout during generation: `"Step 00: mode=declaration, source=platform-declaration.yaml"` (or equivalent for each mode)

### Staleness Check
- [ ] `_meta.defaults_version` matches the `version` field in `platform-defaults.yaml`
- [ ] Staleness applies only when `_meta.mode` is `defaults` or `inline-defaults` (in declaration mode, the user or introspection explicitly provided platform facts — defaults staleness is irrelevant)
- [ ] If applicable mode: compare `_meta.defaults_version_date` against the **current system date** at pipeline run time. If more than 6 months old, emit a warning: `"WARNING: platform-defaults.yaml version X.Y.Z (dated YYYY-MM-DD) may be stale — verify model roster against current Claude Code platform"`

---

## Dependencies

**None** — This is the new root generation step. It has no dependencies on other generation steps.

Dynamic discovery (future): If implemented, would run before this step and produce `platform-declaration.yaml`.

### Platform Capability Audit Notes

- **Steps 02-06, 08**: No platform capability references found. These steps consume only axioms and spec-level inputs — no [EXTERNAL] platform facts.
- **Step 07** (oj-helper): Consumes `hooks[point="SubagentStart"].matchers[0]` from the platform snapshot. The `inject-profile` agent type filter string is resolved from the snapshot at generation time and baked into the generated script — aligned with the same pattern used by step-09.
- **Step 09**: Consumes `models[tier=reasoning].api_id` and `hooks` from the platform snapshot (documented in Output section below).

---

## Output

After completing this step, you will have:
- `platform-snapshot.yaml` — Layer 0 platform capability snapshot (~3KB)

This output is required by:
- **step-01** (consumes `models` section for model selection table rendering)
- **step-07** (consumes `hooks[point="SubagentStart"].matchers[0]` for inject-profile agent type filter)
- **step-09** (consumes `models[tier=reasoning].api_id` for `settings.json` model field; consumes `hooks` for SubagentStart hook configuration)
