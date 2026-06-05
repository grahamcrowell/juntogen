# juntogen/codex — OpenAI Codex CLI generator

Platform generator that compiles the platform-agnostic `juntospec` corpus into an
installable **OpenAI Codex CLI** plugin (`oj-codex`). It is the Codex sibling of
`juntogen/claude/`.

```
{parent}/
  juntospec/    # spec corpus (the genome) — platform-agnostic, reused as-is
  juntogen/     # generators (this repo)
    claude/     # Claude Code generator (reference implementation)
    codex/      # Codex CLI generator (this directory)
      platform-defaults.yaml   # Layer 0 Codex capability snapshot
      D64-tooling.md           # Codex platform-binding spec (oj-helper, hooks, agent defs)
      steps/                   # generation prompts (step-NN-name.md)
      lib/                     # static DATA-class manifest emitter
      ROADMAP.md               # build plan for the remaining steps + open questions
  oj-codex/     # installable Codex plugin output (generated; not in this repo)
```

## Status: scaffold

This is a **scaffold + plan**, not a runnable end-to-end pipeline yet. What exists:

| Artifact | State |
|---|---|
| `platform-defaults.yaml` | ✅ Codex Layer 0 (models, tools, hooks, constraints) — some values `[VERIFY]` |
| `D64-tooling.md` | ✅ Codex binding spec (oj-helper, hooks, native agent defs, config.toml, packaging) |
| `lib/emit-static-plugin-manifest.sh` | ✅ emits `.codex-plugin/`, `hooks/hooks.json`, `contracts.sh`, defaults |
| `steps/step-00-platform-ingestion.md` | ✅ adapted (root, most platform-specific) |
| `steps/step-01-scaffold-and-protocol.md` | ✅ adapted (delta-style over the Claude step) |
| `steps/step-02 … step-11` | ⬜ planned — see `ROADMAP.md` |
| `generate` orchestrator | ⬜ deliberately not forked — see `ROADMAP.md` §1 (shared-core recommendation) |
| `validation/` | ⬜ planned — port from `juntogen/claude/validation/` |

The platform contract (`juntospec/platform-contract.yaml`) is **reused unchanged**:
`load-contract.py` consumes only the abstract primitives, version, and vocab regex — never
the cosmetic `generated_for` field — so the genome needs no edit to target a second platform.

## Why Codex is near-parity (not heavy degradation)

The Codex CLI (mid-2026) provides first-class subagents, lifecycle hooks, Agent Skills,
custom prompts, MCP, and a plugin system with a manifest + marketplace — closely paralleling
Claude Code. The OpenJunto plugin tree ports almost 1:1. Only one primitive truly degrades.

| Primitive | Codex binding | Notes |
|---|---|---|
| `Consult` | subagent (agent-definition file) | `/agent` or auto-orchestration |
| `Convene` | parallel subagents | Codex consolidates results; `max_threads`=6 |
| `Inform` | — | **no agent↔agent messaging → handback-only synthesis (Axiom 8)** |
| `Onboard` | native agent-def `developer_instructions` | + `SubagentStart` hook fallback; unlocks per-expert effort |
| `CONDUCTOR.md` | shipped + `SessionStart` hook inject | leaves user `AGENTS.md` untouched |
| `install-root` | `~/.codex` (`$CODEX_HOME`) | |
| `model-tier` | gpt-5.4-mini / gpt-5.3-codex / gpt-5.5 | + `model_reasoning_effort` |
| `operational-namespace` | `state/ evolution/ archive/` under `~/.codex` | |

Notable capability gain: Codex agent definitions carry per-agent `model` and
`model_reasoning_effort`, so per-expert effort tiering — explicitly impossible on Claude
Code (see `juntogen/claude/steps/step-01` effort note) — **is** controllable on Codex.

## Sources

Bindings derived from the OpenAI Codex docs (mid-2026):
[subagents](https://developers.openai.com/codex/subagents) ·
[hooks](https://developers.openai.com/codex/hooks) ·
[config reference](https://developers.openai.com/codex/config-reference) ·
[models](https://developers.openai.com/codex/models) ·
[skills](https://developers.openai.com/codex/skills) ·
[plugins](https://developers.openai.com/codex/plugins).
`[VERIFY]` markers throughout flag facts to confirm against the live CLI before this generator
graduates from scaffold to validated.
