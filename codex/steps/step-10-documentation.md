# Generation Prompt: Step 10 — Documentation (Codex)

Adaptation of `/path/to/juntogen/claude/steps/step-10-documentation.md`.

## Inputs (read these)
- `/path/to/juntogen/claude/steps/step-10-documentation.md` — authoritative doc structure.
- The generated plugin tree in the working dir (CONDUCTOR.md, agents/, skills/, hooks/, .codex-plugin/).
- `/path/to/juntogen/codex/D64-tooling.md` and `/path/to/juntogen/codex/README.md` — Codex bindings + status.

## Codex substitutions
- Install flow: `codex plugin marketplace add <path-to-oj-codex>` then `codex plugin install oj@openjunto`
  (NOT the Claude `claude plugin …` flow). Plugin installs into `~/.codex/plugins/cache/...`.
- Paths: `~/.codex/` (`$CODEX_HOME`); plugin-internal token `${PLUGIN_ROOT}`.
- Explain that OpenJunto ships `CONDUCTOR.md` (injected via the SessionStart hook) and leaves the user's
  `AGENTS.md` untouched.
- Model table uses the Codex roster (gpt-5.4-mini / gpt-5.3-codex / gpt-5.5) and notes per-expert
  `model_reasoning_effort` on the native agent definitions.

## Output
- `README.md` (overwrite the seed), `WHY.md`, `docs/onboarding.md`.

## Verify
- All three exist and are non-empty; install instructions reference `codex plugin …`; zero `claude plugin` references.
