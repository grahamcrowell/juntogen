# Generation Prompt: Step 05 — Templates (Codex)

Adaptation of `/path/to/juntogen/claude/steps/step-05-templates.md`. The 5 deliverable templates are
platform-agnostic — this step is essentially a path-token swap.

## Inputs (read these)
- `/path/to/juntogen/claude/steps/step-05-templates.md` — authoritative template structure for all 5.

## Codex substitutions
- `${CLAUDE_PLUGIN_ROOT}` → `${PLUGIN_ROOT}`; `~/.claude/` → `~/.codex/` if present.
- Any model/tool references use Codex bindings (see step-04).

## Output (5 files in `templates/`)
`technical-analysis.md`, `architecture-decision-record.md`, `retrospective.md`, `session-state.md`,
`communications-playbook.md`.

## Verify
- All 5 files exist and are non-empty; zero `${CLAUDE_PLUGIN_ROOT}` references.
