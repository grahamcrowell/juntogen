# Generation Prompt: Step 11 — Org Scaffold (Codex)

Adaptation of `/path/to/juntogen/claude/steps/step-11-org-scaffold.md`. Independent of steps 00–10.

## Inputs (read these)
- `/path/to/juntogen/claude/steps/step-11-org-scaffold.md` — authoritative org-scaffold tree + file contents.
- `/path/to/juntospec/D80-org-coordination.md` — multi-repo coordination topology.

## Codex substitutions
- `${CLAUDE_PLUGIN_ROOT}` → `${PLUGIN_ROOT}`; `~/.claude/` → `~/.codex/`.
- Any command/skill invocation references use the Codex idiom (see step-06).

## Output
- `org-scaffold/` tree (seed files for an org-level coordination repo), per the Claude step-11 structure.

## Verify
- `org-scaffold/` exists with the expected seed files; zero `${CLAUDE_PLUGIN_ROOT}` / `~/.claude/` references.
