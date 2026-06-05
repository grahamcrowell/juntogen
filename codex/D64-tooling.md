---
id: D64
title: Tooling (Codex binding)
layer: domain
platform: codex
depends-on: [D16, D56]
consumers:
  - juntogen/codex/steps/step-03
  - juntogen/codex/steps/step-07
---
# D64: Tooling — Codex CLI Binding

This is the Codex-platform binding of the D64 Tooling domain spec. It is the sibling
of `juntogen/claude/D64-tooling.md`. The abstract coordination primitives are defined
in `juntospec`; this file binds them to concrete OpenAI Codex CLI mechanisms.

> **Status: scaffold.** `[VERIFY]` markers flag facts not yet confirmed against the
> live Codex CLI. Confirm before this binding graduates from scaffold to validated.

## Primitive → Codex binding (summary)

| Primitive | Claude Code | Codex CLI binding |
|---|---|---|
| `Consult` | Agent/Task tool | A single Codex **subagent** (agent-definition file), invoked via `/agent` or auto-orchestration |
| `Convene` | `TeamCreate` | **Parallel subagents** — Codex spawns, waits for all, returns a consolidated response (`agents.max_threads`=6) |
| `Inform` | `SendMessage` | **Unavailable** — no agent↔agent messaging → degrades to handback-only synthesis (Axiom 8) |
| `Onboard` | `SubagentStart` hook | **Native agent-definition `developer_instructions`** (primary); `SubagentStart` hook (fallback) |
| `CONDUCTOR.md` | `CLAUDE.md` + SessionStart inject | `CONDUCTOR.md` shipped + injected via `SessionStart` hook (user's `AGENTS.md` untouched) |
| `install-root` | `~/.claude/` | `~/.codex/` (`$CODEX_HOME`) |
| `model-tier` | haiku/sonnet/opus | gpt-5.4-mini / gpt-5.3-codex / gpt-5.5 (+ `model_reasoning_effort`) |
| `operational-namespace` | state/ evolution/ archive/ | same, under `~/.codex/` |

---

## oj-helper — CLI Dispatcher Script

**Location (in plugin tree)**: `${PLUGIN_ROOT}/bin/oj-helper`

**Architecture**: Bash dispatcher (case statement on `$1`). Identical conventions to the
Claude binding (`set -euo pipefail`, `debug()` gated by `OJ_HOOK_DEBUG=1`, `die()`,
graceful degradation when `jq`/`gh` missing). The subcommands below are the ones whose
behavior differs from, or is newly required by, the Codex platform. All other subcommands
(`feedback-path`, `tracker-*`) are platform-agnostic and reused verbatim from the Claude
helper.

### conductor-inject — SessionStart Hook

<a id="hook-conductor-inject"></a>
[CANONICAL: hook-conductor-inject]

**Purpose**: Inject the manager protocol file (`CONDUCTOR.md`) at session start without
overwriting the adopter's `AGENTS.md`. This is why OpenJunto ships `CONDUCTOR.md` and
injects it via a hook rather than writing `AGENTS.md` directly — the same non-destructive
design as the Claude binding.

**Invocation**: Codex `SessionStart` hook (`hooks/hooks.json`, matcher `""`). Reads hook
JSON from stdin.

**Protocol**:
1. Read hook JSON from stdin (`session_id`, `hook_event_name`, `cwd`, `model`, …).
2. Read `${PLUGIN_ROOT}/CONDUCTOR.md`.
3. Emit context injection on stdout:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "CONDUCTOR_MD_CONTENTS"
  }
}
```
4. Emit a version banner to **stderr only**: `OpenJunto v${version} active — OpenJunto coordination system` (`${version}` from `${PLUGIN_ROOT}/VERSION`, fallback `unknown`). stdout carries only the JSON payload.

**Fallback**: If `CONDUCTOR.md` is absent/unreadable, exit 0 and emit the pinned advisory
`OJ_STDERR_CONDUCTOR_MISSING` (see `bin/lib/contracts.sh`) to stderr; the session proceeds.

> **Codex parity note**: Codex `SessionStart` also adds plain stdout text as developer
> context, so a degraded helper that just `cat`s CONDUCTOR.md to stdout still works. The
> structured `additionalContext` form is preferred for parity with the Claude helper.

### inject-profile — SubagentStart Hook (Onboard FALLBACK)

<a id="hook-inject-profile"></a>
[CANONICAL: hook-inject-profile]

**Purpose**: Inject expert preamble + full profile into a spawned subagent. On Codex this
is the **fallback** path — the **primary** Onboard binding is the native agent-definition
file (see below), which carries the profile as `developer_instructions` with no hook needed.

**Invocation**: Codex `SubagentStart` hook. Reads hook JSON from stdin; outputs
`hookSpecificOutput.additionalContext` (preamble + profile), exactly like the Claude helper.

[OBSERVABLE] inject-profile MUST exit 0 with no output (graceful degradation) when
dependencies are missing or no expert marker is detected; the spawn proceeds without injection.

> **[VERIFY]** Codex `SubagentStart` matcher semantics for named subagents, and whether the
> spawn prompt / agent name is available in the hook stdin (the Claude helper must read the
> subagent transcript because Claude does not pass the prompt; Codex may pass the agent name
> directly, simplifying identification).

### subagents-check — Capability Probe (Convene gate)

**Purpose**: Codex analog of `agent-teams-check`. Reports whether parallel subagents are
available so skills can branch. Always exits 0 (Axiom 8: never block on the probe).
Output: `{"ok":true,"available":true|false,"reason":"..."}`.
On Codex, subagents are generally available, so the Convene→Consult→inline degradation is
rarely taken — but the gate is preserved for environments where `agents.max_threads` is 0
or subagents are policy-disabled.

---

## Onboard — Native Agent-Definition Files (PRIMARY)

Codex subagents are defined as standalone TOML files. This is the **primary** Onboard binding:
each OpenJunto expert is emitted as an agent definition whose `developer_instructions` carry
the preamble + profile. No hook is required for static experts.

**Location**: `${PLUGIN_ROOT}/.codex/agents/<expert>.toml` (or copied to
`~/.codex/agents/` at install). [VERIFY] exact discovery path for plugin-bundled agents.

**Definition shape** (per developers.openai.com/codex/subagents):
```toml
name = "security-engineer"
description = "Use for security/compliance review and threat modeling."
developer_instructions = """
<preamble + full expert profile, generated by step-03>
"""
model = "gpt-5.3-codex"          # per-expert model (model-tier binding)
model_reasoning_effort = "high"  # per-expert effort — see note below
```

Required fields: `name`, `description`, `developer_instructions`. Optional: `model`,
`model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, `skills.config`, `nickname_candidates`.

> **Per-expert effort is controllable on Codex.** The Claude step-01 prompt documents that
> per-expert effort is *not* a controllable parameter (the Task tool does not read
> `agents/*.md` frontmatter; effort is session-level). On Codex this limitation is **lifted**:
> `model` and `model_reasoning_effort` are first-class agent-definition fields, so the
> function-first model-selection rules (D32 §6) can bind effort per expert (e.g. adversarial
> reviewer → `model_reasoning_effort = "xhigh"`). step-03 should exploit this.

---

## config.toml — Codex Configuration

**Location**: `~/.codex/config.toml` (`$CODEX_HOME/config.toml`); project scope `.codex/config.toml`
(trusted projects only). This is the Codex analog of Claude's `settings.json`.

As with the Claude binding, OpenJunto does **not** ship `config.toml` — it is user-owned
configuration outside the plugin distribution (the Claude step-09 settings.json step is
retired for the same reason). The plugin provides `hooks/hooks.json`, agent definitions,
skills, `bin/oj-helper`, and `CONDUCTOR.md`; the adopter wires model/approval/sandbox/MCP in
their own `config.toml`.

Relevant keys an adopter may set (documentation, not generated output):
- `model = "gpt-5.5"`, `model_reasoning_effort = "high"`
- `approval_policy`, `sandbox_mode`
- `[agents]` — `max_threads` (default 6), `max_depth` (default 1)
- `[mcp_servers.<id>]` — MCP servers (or bundle via plugin `.mcp.json`)
- `[[hooks.SessionStart]]` / `[[hooks.SubagentStart]]` — inline hooks (alternative to `hooks/hooks.json`)
- `notify` — external program on `agent-turn-complete`

---

## Plugin Packaging — Codex

The Codex plugin layout parallels the Claude plugin layout closely:

```
oj-codex/
├── .codex-plugin/
│   ├── plugin.json          (DATA — emit-static-plugin-manifest.sh)
│   └── marketplace.json     (DATA)
├── hooks/hooks.json         (DATA — auto-detected; no manifest entry needed)
├── bin/oj-helper            (PROSE — LLM-generated)
├── bin/lib/contracts.sh     (DATA)
├── CONDUCTOR.md             (PROSE — step-01)
├── agents/                  (PROSE — step-03 full + *-compact profiles)
├── .codex/agents/*.toml     (native subagent definitions — step-03; [VERIFY] bundling path)
├── skills/<name>/SKILL.md   (PROSE — step-06; frontmatter: name + description)
├── reference/               (PROSE — step-04)
├── templates/               (PROSE — step-05)
└── platform-defaults.yaml   (DATA)
```

**Install**: `codex plugin marketplace add <path>` then `codex plugin install oj@openjunto`.
Codex installs into `~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/` and resolves
`${PLUGIN_ROOT}` to that path at hook-invocation time. [VERIFY] exact CLI invocation
and whether `agents/` definitions are auto-discovered from the plugin or must be copied to
`~/.codex/agents/`.

## Skills

Codex Agent Skills use `SKILL.md` with `name` + `description` frontmatter (Claude requires
`description`; Codex requires both). Progressive disclosure (metadata first, body on selection).
The step-06 verifier's contract (`---` line 1, `description:` present, body > 5 lines) holds;
add a `name:` presence check for Codex. [VERIFY] discovery path — docs cite `.agents/skills`
and `~/.agents/skills` for loose skills; plugin-bundled skills live under the plugin's
`skills/` directory.
