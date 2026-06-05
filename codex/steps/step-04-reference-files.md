# Generation Prompt: Step 04 — Reference Files (Codex)

Adaptation of `/path/to/juntogen/claude/steps/step-04-reference-files.md`.

## Inputs (read these)
- `/path/to/juntogen/claude/steps/step-04-reference-files.md` — authoritative topic coverage for all 8 files.
- `/path/to/juntospec/D48-reference-system.md`, `D24-triage-engine.md`, `D32-execution-models.md`, `D40-quality-framework.md` — canonical sources referenced by the reference files.

## Codex substitutions
- `${CLAUDE_PLUGIN_ROOT}` → `${PLUGIN_ROOT}`; `~/.claude/` → `~/.codex/`.
- In examples, replace Claude platform-tool names with Codex bindings: delegation/teams → **Codex subagents**
  (parallel, consolidated handback); `SubagentStart`/`SessionStart` hooks keep their names (Codex has them);
  peer messaging is **unavailable** (handback-only synthesis).
- Model references use the Codex roster (gpt-5.4-mini / gpt-5.3-codex / gpt-5.5) where concrete ids appear.

## Output (8 files in `reference/`)
`workflow-stages.md`, `stakeholder-guide.md`, `worked-examples.md`, `dev-mode.md`, `failure-protocol.md`,
`file-patterns.md`, `project-scaffolding.md`, `communication-standards.md`.

## Verify
- All 8 files exist and are non-empty.
- Zero `${CLAUDE_PLUGIN_ROOT}` / `~/.claude/` references.
