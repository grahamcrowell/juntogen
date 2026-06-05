# Generation Prompt: Step 07 — oj-helper (Codex)

Adaptation of `/path/to/juntogen/claude/steps/step-07-helper-script.md`. Generate the `bin/oj-helper`
dispatcher rebound to Codex hooks. The static DATA-class manifests (`.codex-plugin/plugin.json`,
`marketplace.json`, `hooks/hooks.json`, `bin/lib/contracts.sh`, `platform-defaults.yaml`) are emitted by
the orchestrator's static-emit step — **do NOT generate those**; generate only `bin/oj-helper`.

## Inputs (read these)
- `/path/to/juntogen/claude/steps/step-07-helper-script.md` — authoritative dispatcher architecture + tracker subcommands.
- `/path/to/juntogen/codex/D64-tooling.md` — Codex hook contract + subcommand bindings.
- `platform-snapshot.yaml` (working dir) — hook points + matchers.

## bin/oj-helper subcommands (Codex bindings)
- `conductor-inject` — SessionStart hook: read hook JSON from stdin; emit
  `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<CONDUCTOR.md contents>"}}` on stdout;
  print `OpenJunto v${version} active …` banner to **stderr only** (version from `${PLUGIN_ROOT}/VERSION`).
  If CONDUCTOR.md missing, exit 0 and emit the `OJ_STDERR_CONDUCTOR_MISSING` advisory (source `bin/lib/contracts.sh`).
- `inject-profile` — SubagentStart hook (Onboard fallback): emit preamble + profile as `additionalContext`;
  graceful-degrade to exit 0 / no output when no expert marker or deps missing.
- `subagents-check` — Convene gate: always exit 0; print `{"ok":true,"available":true|false,"reason":"..."}`.
- `migrate-legacy`, `feedback-path`, and the `tracker-*` GitHub subcommands — platform-agnostic; port from the Claude helper.

## Requirements
- `set -euo pipefail`; `debug()` gated by `OJ_HOOK_DEBUG=1`; `die()`; graceful degradation if `jq`/`gh` missing.
- Use `${PLUGIN_ROOT}/…` for all plugin-internal paths. Source `${PLUGIN_ROOT}/bin/lib/contracts.sh`.
- Make `bin/oj-helper` executable.

## Output
- `bin/oj-helper` (the orchestrator emits `bin/lib/contracts.sh` + manifests alongside).

## Verify
- `bin/oj-helper` exists, is executable, sources `bin/lib/contracts.sh`, and defines `conductor-inject`,
  `inject-profile`, `subagents-check`.
