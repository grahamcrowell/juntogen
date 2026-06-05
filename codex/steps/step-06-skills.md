# Generation Prompt: Step 06 — Skills (Codex)

Adaptation of `/path/to/juntogen/claude/steps/step-06-commands.md` (which emits plugin skills).

## Inputs (read these)
- `/path/to/juntogen/claude/steps/step-06-commands.md` — authoritative skill set + content.
- `/path/to/juntospec/D56-commands-automation.md` — cycle protocol, backlog management, task lifecycle.

## Codex substitutions
- Each `SKILL.md` frontmatter MUST include **both** `name:` and `description:` (Codex requires `name`;
  Claude only required `description`).
- `${CLAUDE_PLUGIN_ROOT}` → `${PLUGIN_ROOT}`.
- Invocation idiom: where the Claude skill references `/oj:<name>` slash commands, note the Codex idiom
  (`$<skillname>` or `/skills`) for invocation. Keep the skill names (`cycle`, `run-task`, `show-backlog`,
  `save-session`, `health-check`).
- `health-check` must probe the Codex bindings: `${PLUGIN_ROOT}/bin/oj-helper`, `jq`, `.codex-plugin/plugin.json`,
  `hooks/hooks.json`, and the `SubagentStart`/`SessionStart` hook wiring.

## Output
- `skills/<name>/SKILL.md` for each skill (directory-per-skill form).

## Verify
- Each `skills/*/SKILL.md` starts with `---`, and has `name:` and `description:` in frontmatter; body > 5 lines.
