# Generation Prompt: Step 03 — Agent Profiles + Native Subagent Definitions (Codex)

Adaptation of `/path/to/juntogen/claude/steps/step-03-agent-profiles.md`. This is the **signature
Codex divergence**: in addition to the markdown profiles, emit native Codex subagent definition
files that carry the profile and bind per-expert model + reasoning effort.

## Inputs (read these)
- `/path/to/juntogen/claude/steps/step-03-agent-profiles.md` — authoritative 16-section profile template + roster.
- `/path/to/juntospec/D16-agent-system.md` — profile structure, compact variants.
- `/path/to/juntospec/D32-execution-models.md` — §6 function-first model-selection rules + per-role default tiers.
- `platform-snapshot.yaml` (working dir) — model roster + tiers.
- `/path/to/juntogen/codex/D64-tooling.md` — native agent-definition binding.

## Outputs
1. **16 full profiles** `agents/<role>.md` and **16 compact** `agents/<role>-compact.md` — authored per the
   Claude step-03 template (platform-agnostic content). Use `${PLUGIN_ROOT}` for any plugin-internal path.
2. **16 native subagent definitions** `.codex/agents/<role>.toml`, one per expert, each:
   ```toml
   name = "<role>"
   description = "<one-line when-to-use, from the profile's selection signal>"
   model = "<gpt-5.x per tier>"
   model_reasoning_effort = "<minimal|low|medium|high|xhigh>"
   developer_instructions = """
   <the expert preamble + full profile text>
   """
   ```

## Codex model + effort binding (from D32 §6, resolved to the Codex roster)
- Tier tokens → Codex models: routine → `gpt-5.4-mini`, implementation → `gpt-5.3-codex`, reasoning → `gpt-5.5`.
- Per-role default tier per D32 §6 (Distinguished Engineer / Security Engineer / Site Reliability Engineer /
  Engineering Consultant → reasoning; most others → implementation; Technical Writer → routine).
- **Effort binding (Codex capability gain — not possible on Claude):** set `model_reasoning_effort` per tier
  (routine→`low`, implementation→`medium`, reasoning→`high`). The **adversarial-reviewer slot** runs at
  `gpt-5.5` / `model_reasoning_effort = "xhigh"` regardless of role default (function rule wins).

## Verify
- 16 `agents/*.md` (excluding `_preamble.md`, `index.md`, `*-compact.md`) + 16 `agents/*-compact.md`.
- 16 `.codex/agents/*.toml`, each with `name`, `description`, `developer_instructions`, `model`, `model_reasoning_effort`.
- Reasoning-tier roles use `gpt-5.5`; routine uses `gpt-5.4-mini`.
