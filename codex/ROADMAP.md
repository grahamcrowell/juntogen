# juntogen/codex — Build Roadmap

Plan to take the Codex generator from **scaffold** (current state) to a **validated**
pipeline that produces an installable `oj-codex` plugin. Ordered by dependency and risk.

---

## 1. Orchestrator: refactor `generate` into a shared core (do NOT fork)

**Decision (recommended).** Do not copy `juntogen/claude/generate` (2070 lines) into
`juntogen/codex/generate`. ~95% of it — argument parsing, SPEC_DIR resolution, contract
loading, per-run sentinel cache, concurrency lock, watchdog/heartbeat, LLM invocation,
verify dispatch — is platform-agnostic. Forking it creates an immediate maintenance fork
that this roadmap would then have to un-fork.

**Plan:** extract the shared driver into `juntogen/lib/generate-core` (or
`juntogen/generate --platform <p>`), parameterized by a small per-platform manifest:
- `PLATFORM_ID`, `STEPS_DIR`, `PLATFORM_DEFAULTS`, default `MODEL`
- `PLUGIN_ROOT_TOKEN` (`${CLAUDE_PLUGIN_ROOT}` / `${PLUGIN_ROOT}`)
- `STATIC_EMITTER` (the platform's `lib/emit-static-plugin-manifest.sh`)
- the per-step tables (`step_desc`, `step_max_turns`, `step_prompt`, `verify_step_*`)
- `GENERATION_MODE_PROMPT` (wording mentions the platform + its protocol file)

Keep the Claude pipeline working throughout (it is the regression oracle). The Codex
`generate` becomes a thin wrapper that sources the shared core with the Codex manifest.

**Generation engine note:** the *compiler* engine (the LLM that runs the step prompts) can
remain the `claude` CLI even when the *target* is Codex — the prompts emit Codex artifacts
regardless of which model executes them. Whether to additionally support running the pipeline
under the `codex` CLI is an independent, lower-priority option; default to the existing engine.

**Verification reuse:** most `verify_step_*` functions are already platform-neutral because
the manager-protocol primitive is `CONDUCTOR.md` on **both** platforms. Deltas: step-07 checks
`.codex-plugin/plugin.json` (not `.claude-plugin/`); step-03 additionally checks
`.codex/agents/*.toml`; step-06 adds a `name:` frontmatter check.

---

## 2. Remaining step prompts (02–11)

Each is an adaptation of the corresponding `juntogen/claude/steps/` prompt. Platform-agnostic
`[EXACT]` and structural content is reused verbatim; only the listed deltas change.

| Step | Adaptation deltas for Codex |
|---|---|
| **02** preamble + index | `${PLUGIN_ROOT}` token; otherwise platform-agnostic. |
| **03** agent profiles (16 full + 16 compact) | **Highest-value Codex divergence.** In addition to `agents/*.md` profiles, emit native subagent definitions `.codex/agents/<expert>.toml` (`name`, `description`, `developer_instructions` = preamble+profile, `model`, `model_reasoning_effort` per the D32 §6 function-first rules). This is the PRIMARY Onboard binding and unlocks per-expert effort. |
| **04** reference files (8) | `${PLUGIN_ROOT}`; replace Claude tool names in examples with Codex bindings. |
| **05** templates (5) | Platform-agnostic; token swap only. |
| **06** skills (5 × SKILL.md) | Add `name:` to frontmatter (Codex requires `name` + `description`). Confirm skill discovery path (plugin `skills/` vs `.agents/skills`). Replace `/oj:*` command references with Codex slash-command/skill invocation. |
| **07** oj-helper + static manifests | oj-helper subcommands rebind to Codex hooks (`conductor-inject`, `inject-profile`, `subagents-check`, `migrate-legacy`). Static emit calls `juntogen/codex/lib/emit-static-plugin-manifest.sh`. inject-profile may be simpler than Claude's (Codex may pass the agent name in hook stdin — `[VERIFY]`). |
| **08** | retired (numeric gap preserved, as in Claude). |
| **09** settings | retired — Codex `config.toml` is user-owned, not shipped (same rationale as Claude step-09). |
| **10** documentation (README/WHY/onboarding) | Codex install flow (`codex plugin marketplace add` / `install`), `~/.codex` paths, AGENTS.md-vs-CONDUCTOR.md explanation. |
| **11** org scaffold | Platform-agnostic; token/path swaps. |

---

## 3. Validation suite

Port `juntogen/claude/validation/` → `juntogen/codex/validation/`. Most is reusable:
- **vocabulary audit** — runs against `juntospec` (platform-agnostic); the banned-terms list
  already bans Claude-isms. Optionally extend `banned_terms` to also ban Codex-isms
  (`AGENTS.md`, `~/.codex/`, `gpt-5`, `config.toml`) from the genome — defensive; the genome
  is already abstract. (This is a `juntospec` change — see §4.)
- **structural-diff / byte-diff** — retarget the snapshot to the `oj-codex` plugin tree;
  `output_classes` (data/prose) is reused from the contract unchanged.
- **tier-a assertions** — the platform-literal assertions (s13–s16) are about keeping the
  *spec* clean; reused as-is.
- **fixtures / synthetic problems** — platform-agnostic; reused.
- New: a static-determinism test for the Codex emitter (mirror
  `emit-static-plugin-manifest-test.sh`).

---

## 4. juntospec follow-ups (cosmetic; out of scaffold scope)

The contract is functionally reused as-is. Optional polish, to land when Codex graduates:
- `platform-contract.yaml`: generalize `generated_for: "claude"` (cosmetic only — not consumed
  by `load-contract.py`; verify no other reader depends on it before changing).
- `README.md`: update "has not yet been validated against a second platform" once Codex is validated.
- Optionally add Codex-isms to `banned_terms` (see §3).

Deliberately NOT done in the scaffold to keep the change inside `juntogen` and avoid premature
edits to the genome.

---

## 5. [VERIFY] status — resolved against OpenAI Codex docs (mid-2026)

Resolved during the validation pass via the OpenAI Codex docs. Two are correctness-affecting and
need a generator sweep + regeneration (ideally confirmed against a live `codex` CLI first).

1. ✅ **Plugin-bundled agent discovery** — RESOLVED + DONE: agent definitions are not a bundled plugin
   component (Codex loads agents only from `~/.codex/agents/` or `<repo>/.codex/agents/`), and
   plugin-bundled hooks are not yet reliably loaded by the runtime (openai/codex#16430, #17331).
   `bootstrap.sh` (emitted into the plugin) installs `.codex/agents/*.toml` → `~/.codex/agents/` and
   merges `hooks/hooks.json` → `~/.codex/hooks.json`. The `SubagentStart` inject-profile hook is the
   always-available PRIMARY Onboard path; native agent defs are the per-agent model/effort enhancement.
2. ✅ **`SubagentStart` matcher** — RESOLVED: `matcher` is a regex applied to `agent_type`; hook
   stdin carries `agent_id` + `agent_type`, so `inject-profile` can identify the profile directly
   (simpler than Claude's transcript-reading). `matcher: ""` (all) is valid.
3. ✅ **`plugin.json` schema** — RESOLVED: required `name` (kebab-case) + `version` + `description`;
   components referenced via `skills`/`hooks`/`mcpServers`/`apps`. Emitter now writes
   `"skills": "./skills/"` + `"hooks": "./hooks/hooks.json"`.
4. ✅ **Plugin-root token** — RESOLVED + DONE: the documented token is **`${PLUGIN_ROOT}`** (Codex-native
   env var + inline substitution; `${CLAUDE_PLUGIN_ROOT}` also works as a compat shim). The undocumented
   `${CODEX_PLUGIN_ROOT}` used by the first generation has been swept to `${PLUGIN_ROOT}` across the
   generator (step prompts, `generate` preamble, `lib/emit-static-plugin-manifest.sh`, `D64-tooling.md`,
   `platform-defaults.yaml`) and the plugin regenerated.
5. ✅ **Skills discovery** — plugin `skills/` referenced via the `skills` manifest field (added);
   loose skills also load from `~/.agents/skills` / `<repo>/.agents/skills`.
6. ⬜ **Model facts** — still placeholders; confirm per-model `context_window`, `max_output_tokens`,
   and cost ratios for gpt-5.5 / gpt-5.3-codex / gpt-5.4-mini against the live models doc.
7. **Backlog location** — Codex project-local convention for `BACKLOG.md` / `.codex/`.

---

## 6. Suggested sequencing

1. §1 shared-core refactor (unblocks running any Codex step).
2. Resolve §5 Q1–Q4 (load-bearing for step-03 + step-07).
3. step-03 (agent profiles + native agent defs) — the signature Codex divergence.
4. step-07 (oj-helper + static emit) — wire the hooks.
5. steps 02, 04, 05, 06, 10, 11 (mostly token swaps).
6. §3 validation port + first full `generate` run into `oj-codex`.
7. §4 juntospec polish; flip `platform-defaults.yaml` `[VERIFY]` values to confirmed.
