# Generation Prompt: Step 00 — Platform Capability Ingestion (Codex)

**Purpose**: Ingest Layer 0 Codex platform capabilities and produce a `platform-snapshot.yaml`
consumed by all downstream generation steps.

This is the Codex sibling of `juntogen/claude/steps/step-00-platform-ingestion.md`. The
mode-selection logic (declaration → defaults → inline-defaults), the `_meta` block, and the
graceful-degradation contract (Axiom 8) are **identical** to the Claude step. The deltas are:
the reference defaults file, the schema's concrete tool/model/hook contents, and the
introspection sub-step (a live Codex session, not a Claude session).

---

## Input

### Specification Files
- `M16-derivation-architecture.md` — §3 (Platform Capability Ingestion) defines the schema, ingestion modes, and fallback behavior (platform-agnostic).

### Reference Files
- `juntogen/codex/platform-defaults.yaml` — Curated offline fallback representing the current OpenAI Codex CLI platform. Used as fallback when no declaration file is provided and introspection is unavailable.

### Optional Declaration File
- `platform-declaration.yaml` — If present in the working directory, use it as the capability source (declaration mode, highest priority).

---

## Task

Produce **`platform-snapshot.yaml`** in the generation working directory, conforming to the
M16 §3 schema. Mode selection (priority order) is identical to the Claude step:
1. `platform-declaration.yaml` exists → **declaration mode**.
2. Else `juntogen/codex/platform-defaults.yaml` exists → **defaults mode**.
3. Else → **inline-defaults mode** (emit the constants from `platform-defaults.yaml` v0.0.1 inline; emit the stale-defaults warning).

The `_meta` block (`schema_version`, `mode`, `generated_at`, `defaults_version`,
`defaults_version_date`, optional `introspection_coverage`) and the top-of-file mode/source
comment are required exactly as in the Claude step.

---

## Key Requirements

### EXTERNAL Elements — Codex Capability Schema

The snapshot must reflect the **Codex** platform. The schema is the same as the Claude step's,
but the contents differ. Authoritative contents are in `juntogen/codex/platform-defaults.yaml`;
the salient Codex-specific points:

- **`platform.identity`** (Codex extension): `platform_id: codex`, `install_root: ~/.codex`,
  `plugin_root_token: ${PLUGIN_ROOT}`, `plugin_manifest_dir: .codex-plugin`,
  `manager_protocol_native_file: AGENTS.md`. Downstream steps consume these for path/token binding.
- **`platform.tools`**: Codex tool surface — `subagents` (the Consult/Convene substrate;
  parameters include `developer_instructions`, `model`, `model_reasoning_effort`), `read_file`,
  `apply_patch`, `shell`, `update_plan`, `web_search`, `mcp`, `skills`, `custom_prompts`.
- **`platform.models`**: exactly 3 tier-mapped models — `gpt-5.4-mini` (routine),
  `gpt-5.3-codex` (implementation), `gpt-5.5` (reasoning) — each with `id`, `api_id`, `tier`,
  `reasoning_effort`, `context_window`, `max_output_tokens`, `cost_ratio`. The `api_id` is the
  exact string for `config.toml` `model = "..."`.
- **`platform.reasoning_effort_levels`**: `[minimal, low, medium, high, xhigh]` (Codex extension;
  enables per-expert effort binding in step-03 — a capability the Claude platform lacks).
- **`platform.hooks`**: `SessionStart` and `SubagentStart` (capabilities include `add_context` via
  `hookSpecificOutput.additionalContext`). Other points (SubagentStop, PreToolUse, …) recorded as
  comments.
- **`platform.constraints`**: `max_concurrent_agents: 6` (`agents.max_threads`), type `configured`;
  `max_agent_depth: 1` (`agents.max_depth`).

### Introspection Sub-Step (live Codex session)

When running inside a live Codex session with no pre-existing `platform-declaration.yaml`, the
introspection sub-step runs before mode selection and writes `platform-declaration.yaml`:
1. Enumerate tool names + parameter schemas from the session's tool definitions.
2. Read the running model identity and `model_reasoning_effort` from the session.
3. Fill unobservable fields (other models' context windows, cost ratios, hooks, constraints)
   from `juntogen/codex/platform-defaults.yaml`.
4. Emit the CI-safety warning (introspection output is environment-dependent, not reproducible).
5. Completeness guard: if fewer tools than expected are found, skip writing the declaration and
   fall through to defaults mode.

[VERIFY] Codex session introspection surface (whether tool schemas and the model roster are
enumerable from a Codex session the way they are from a Claude session).

---

## Verification

- [ ] `platform-snapshot.yaml` exists; begins with the mode/source comment; `_meta` is first key.
- [ ] `_meta.mode` ∈ {declaration, defaults, inline-defaults}; `generated_at` ISO 8601.
- [ ] `platform.identity.platform_id == "codex"`.
- [ ] `platform.models` has exactly 3 entries with Codex `api_id` strings (gpt-5.x), each with a `tier`.
- [ ] `platform.tools` includes `subagents` (Consult/Convene substrate).
- [ ] `platform.hooks` includes `SessionStart` and `SubagentStart`.
- [ ] `platform.constraints.max_concurrent_agents` present (6, configured).
- [ ] Staleness check applied for defaults/inline-defaults modes.

---

## Dependencies

**None** — new root generation step.

## Output

- `platform-snapshot.yaml` — Layer 0 Codex capability snapshot. Required by step-01 (model
  table), step-03 (per-expert model + effort on agent definitions), and step-07 (hooks).
