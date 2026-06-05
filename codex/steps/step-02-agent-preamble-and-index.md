# Generation Prompt: Step 02 — Agent Preamble and Index (Codex)

Adaptation of `/path/to/juntogen/claude/steps/step-02-agent-preamble-and-index.md` for Codex.
Read that prompt and the spec inputs it lists, then produce the SAME artifacts into the working
directory, applying the Codex substitutions below.

## Inputs (read these)
- `/path/to/juntogen/claude/steps/step-02-agent-preamble-and-index.md` — authoritative structure + EXACT blocks.
- `/path/to/juntospec/D16-agent-system.md` — agent roster, profile template, compact variants.
- `CONDUCTOR.md` (from step-01, in the working dir) — for cross-reference format.

## Codex substitutions (the only deltas)
- Replace every `${CLAUDE_PLUGIN_ROOT}` with `${PLUGIN_ROOT}`. Never use `~/.codex/` for plugin-internal paths.
- The expert roster is the same 16 roles. Note in `index.md` that each expert ALSO materializes as a
  native subagent definition at `${PLUGIN_ROOT}/.codex/agents/<role>.toml` (emitted in step-03);
  the `agents/*.md` profile remains the human-readable source of truth.
- `_preamble.md` content (shared expert infrastructure, adversarial-stance framing) is platform-agnostic — reproduce verbatim.

## Output
- `agents/_preamble.md`
- `agents/index.md` (the 16-expert selection index)

## Verify
- Both files exist and are non-empty.
- `index.md` lists all 16 experts with selection signals.
- Zero `${CLAUDE_PLUGIN_ROOT}` / `~/.claude/` references.
