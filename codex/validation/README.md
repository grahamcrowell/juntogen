# juntogen/codex/validation

Validation + smoke-test suite for the generated `oj-codex` Codex plugin. The Codex sibling
of `juntogen/claude/validation`, scoped to the highest-value runnable checks.

> **Live-CLI note:** a real `codex` CLI run requires the `codex` binary + OpenAI auth, which
> are not present in the generation sandbox. These scripts are the strongest feasible
> substitute — they exercise the plugin's runtime hook contract directly (mock Codex hook
> JSON on stdin) and validate structure against Codex's documented plugin format, with **no
> dependency on the codex binary**. Run them in CI and, when a real Codex CLI is available,
> additionally do a live `codex plugin install` smoke test (see ROADMAP open items).

## Scripts

| Script | What it checks |
|---|---|
| `scripts/codex-vocabulary-audit.sh [PLUGIN_DIR]` | No Claude-platform vocabulary bleed in the generated tree (`${CLAUDE_PLUGIN_ROOT}`, `~/.claude/`, haiku/sonnet/opus, `Task tool`, `TeamCreate`, `SendMessage`, `CLAUDE.md`, `claude plugin`). Keeps `SessionStart`/`SubagentStart` (valid on Codex) and allows deliberate "Claude Code" comparative prose. This is the check that catches the regression that bit the first generation. |
| `scripts/validate-plugin.sh [PLUGIN_DIR]` | Structural: valid JSON manifests + `${PLUGIN_ROOT}` hooks; 16 `.codex/agents/*.toml` with required keys and valid `model`/`model_reasoning_effort` enums; 16 full + 16 compact profiles; skills frontmatter (`name`+`description`); `oj-helper` executable + `bash -n`; CONDUCTOR handback anchors + 2/6/9 gates. Calls the vocabulary audit. |
| `scripts/oj-helper-hook-test.sh [PLUGIN_DIR]` | Runtime hook contract: `conductor-inject` (present → byte-identical `additionalContext`; missing → `OJ_STDERR_CONDUCTOR_MISSING` + empty body + exit 0; empty file → silent), `inject-profile` graceful degradation, `subagents-check` JSON shape + always-exit-0 (Axiom 8). Isolated tempdir per scenario; rebinds `PLUGIN_ROOT`. |

## Run

```bash
PLUGIN=/path/to/oj-codex
juntogen/codex/validation/scripts/validate-plugin.sh        "$PLUGIN"
juntogen/codex/validation/scripts/oj-helper-hook-test.sh    "$PLUGIN"
# (validate-plugin.sh invokes codex-vocabulary-audit.sh itself)
```

PLUGIN_DIR resolution: positional arg → `$OJ_CODEX_DIR` → sibling probe (`../../../../oj-codex`).

## Port status / TODO

Ported (adapted) from `juntogen/claude/validation`: vocabulary-audit concept (retargeted from
the *spec corpus* to the *generated plugin*), plugin structural validator, oj-helper hook test.
Not yet ported: `structural-diff` byte-diff against a frozen snapshot, `tier-a-assertions`,
`regen-acceptance`, fixture-based mutation tests. Tracked in `juntogen/codex/ROADMAP.md` §3.
