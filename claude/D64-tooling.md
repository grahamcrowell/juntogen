---
id: D64
title: Tooling
layer: domain
depends-on: [D16, D56]
consumers:
  - juntogen/claude/steps/step-07
  - juntogen/claude/steps/step-09
---
# D64: Tooling

## oj-helper — CLI Dispatcher Script

**Location**: `~/.local/bin/oj-helper`

**Architecture**: Bash script using dispatcher pattern — a case statement on `$1` routes to subcommand functions. Each subcommand is a self-contained function with argument parsing, validation, and error handling.

**Core Conventions**:
- `set -euo pipefail` — fail fast on errors, unset variables, pipe failures
- `debug()` function — controlled by `OJ_HOOK_DEBUG=1` env var, writes to stderr
- `die()` function — fatal error with message to stderr, exits with code 1
- Graceful degradation — if tools missing (jq, gh), exit cleanly rather than crash

---

### Subcommands

#### inject-profile — SubagentStart Hook

<a id="hook-inject-profile"></a>

[CANONICAL: hook-inject-profile]

**Purpose**: Automatically inject expert preamble + full profile into spawned sub-agents at creation time.

**Invocation**: Called by Claude Code's SubagentStart hook (see settings.json). Reads hook JSON from stdin.

**Protocol**:
1. Read hook JSON from stdin, extract `agent_type`, `transcript_path`, `agent_id`
2. Only process `general-purpose` agents — skip `Bash`, `Explore`, `Plan`, custom types (exit 0, no output)
   [EXTERNAL] `general-purpose` — platform fact; resolve from `platform-snapshot.yaml` → `hooks[point="SubagentStart"].matchers[0]`
3. Derive subagent transcript path: `{session_dir}/subagents/agent-{agent_id}.jsonl`
   - `session_dir` = `transcript_path` minus `.jsonl` extension
4. Wait up to 500ms for transcript file to appear (5 iterations of 100ms sleep)
5. Read first line of transcript (the spawn prompt)
6. Extract spawn prompt text from JSONL message:
   - If content is string: use directly
   - If content is array of `{type, text}` blocks: join all `type=="text"` blocks
7. Expert identification (two strategies, tried in order):
   - **HTML marker**: `<!-- oj-expert: PROFILE_NAME -->` in spawn prompt
   - **Path pattern**: `~/.claude/agents/PROFILE_NAME.md` reference in spawn prompt
8. Path traversal guard: reject profile names containing `..` or `/`
9. Load profile files:
   - Read `~/.claude/agents/_preamble.md`
   - Read `~/.claude/agents/{PROFILE_NAME}.md` (full profile)
   - If full profile not found, fallback to `~/.claude/agents/compact/{PROFILE_NAME}.md`
10. Output hook response JSON:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStart",
    "additionalContext": "PREAMBLE\n\n---\n\nPROFILE_CONTENT"
  }
}
```

**CRITICAL DESIGN NOTE**: Claude Code does NOT pass the spawn prompt to hooks in the input JSON. The hook must read the subagent's transcript file to find the spawn prompt. This is based on runtime behavior, not documented API. The hook degrades gracefully if the convention changes (exits 0 with no output, spawn proceeds without profile injection).

**Fallback behavior**: If jq missing, transcript unavailable, profile not found, or no expert marker detected → exit 0 with no output. The spawn proceeds without profile injection. The manager's spawn prompt should include fallback instructions: "**FIRST**: Read `~/.claude/agents/_preamble.md` and your full profile..."

[OBSERVABLE] inject-profile hook MUST exit 0 with no output (graceful degradation) when dependencies are missing (jq unavailable, transcript not found, profile not found, or no expert marker detected).
  FALSIFIER: inject-profile hook exits with non-zero code or produces error output when a dependency is missing, causing the spawn to fail
  TEST: TOOL-001, TOOL-002, TOOL-003

[OBSERVABLE] inject-profile hook MUST only process `general-purpose` [EXTERNAL] agent types; all other agent types (Bash, Explore, Plan, custom) MUST be skipped with exit 0.
  `general-purpose` — platform fact; resolve from `platform-snapshot.yaml` → `hooks[point="SubagentStart"].matchers[0]`
  FALSIFIER: inject-profile hook attempts to inject a profile into a non-general-purpose agent type (e.g., Bash or Explore agent receives profile injection)
  TEST: TOOL-004, TOOL-005

**Debug mode**: Set `OJ_HOOK_DEBUG=1` (legacy `JUNTO_HOOK_DEBUG=1` accepted as fallback) to see diagnostic output on stderr (transcript path, profile identification, bytes loaded).

---

#### feedback-path — Dev Mode Feedback Path

**Purpose**: Output timestamped file path for dev mode feedback collection.

**Invocation**: `oj-helper feedback-path` (no arguments)

**Protocol**:
1. Check `$OJ_DEVMODE` (falling back to legacy `$JUNTO_DEVMODE`) — if not "1", exit 0 with no output (feedback disabled)
2. Extract org/repo from git remote origin URL:
   - Handles SSH (`git@host:org/repo.git`) and HTTPS (`https://host/org/repo.git`)
   - Strips `.git` suffix, extracts last two path components
3. Create directory: `~/.claude/dev/feedback/{org}/{repo}/`
4. Output timestamped path: `~/.claude/dev/feedback/{org}/{repo}/YYYY-MM-DDTHHMMSS.md`

**Usage**: Called by task lifecycle Phase 5 (Learn). If output empty, feedback skipped. If output non-empty, write feedback file to that path.

---

#### Issue Tracker Subcommands

> **Design principle**: These subcommands define a **generic interface** for issue tracking. The default implementation uses GitHub Issues via `gh` CLI. Organizations using other tools (e.g., Linear, GitLab) can replace these via the enterprise overlay pattern (spec D72).

**tracker-check** — Validate prerequisites and discover project:
- Check `gh` installed and authenticated, `jq` installed
- Discover project (priority order): `--project` flag → `$ISSUE_TRACKER_PROJECT` env → current `gh` repo
- Output JSON: `{"ok":true,"project":"owner/repo"}` or `{"ok":false,"errors":[...]}`
- **Usage**: First tracker operation in any session. Determines issue tracker vs BACKLOG.md mode.

| Subcommand | Invocation | Behavior | Usage |
|---|---|---|---|
| `tracker-list` | `[--project REPO] [--status open] [--limit 50]` | List open issues, output JSON array | Phase 1 backlog visibility |
| `tracker-create` | `--title "..." [--body "..."] [--label "..."]` | Create issue, output JSON | Phase 4 discovered work |
| `tracker-view` | `NUMBER [--project REPO]` | View issue details as JSON | Debugging, manual inspection |
| `tracker-transition` | `NUMBER --status open\|closed` | Change issue state | Phase 2 and Phase 4 |
| `tracker-comment` | `NUMBER --body "..."` | Add comment to issue | Phase 4 completion |
| `tracker-link-list` | `NUMBER` | List cross-references for an issue | Dependency tracking |

> **Note**: Issue linking capabilities vary by tracker. The default GitHub implementation extracts cross-references from issue bodies/comments. Orgs needing richer linking can override via overlay.

### Helper Functions

| Function | Purpose | Called By |
|---|---|---|
| `tracker_require_auth` | Validates `gh` installed and authenticated; dies with actionable error if not | All tracker-* subcommands |
| `tracker_require_jq` | Validates `jq` installed; dies with actionable error if not | tracker-list |

---

## settings.json — Claude Code Configuration

**Location**: `~/.claude/settings.json`

**Purpose**: Configure Claude Code environment, permissions, hooks, and model selection.

**Structure**:
```json
{
  "env": { /* environment variables */ },
  "permissions": { "allow": [...], "deny": [...] },
  "hooks": { "SessionStart": [...], "SubagentStart": [...] },
  "model": "opus",
  /* other Claude Code settings */
}
```

---

### Key Sections

#### env

Environment variables set for all Claude Code sessions.

**OpenJunto-specific env vars**:
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — Enables TeamCreate/TeamDelete tools (required for Complex tier)
- `CLAUDE_CODE_ENABLE_UNIFIED_READ_TOOL=1` — Unified read capability across file types
- `CLAUDE_CODE_EXPERIMENTAL_ADAPTIVE_THINKING=1` — Adaptive thinking mode

#### permissions

Fine-grained control over tool access.

**Structure**:
- `allow`: Array of allowed tool calls (glob patterns supported)
- `deny`: Array of explicitly denied tool calls (overrides allow)
- `defaultMode`: "default" (prompt user for unlisted tools)

**OpenJunto allow list**:
- Read access: `Read(~/workspace/...)`, `Read(~/.claude/agents/*)`, `Read(~/.claude/commands/*)`, `Read(~/.claude/templates/*)`, `Read(~/.claude/reference/*)`
- Bash commands: `Bash(cat:*)`, `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(git show:*)`, `Bash(git status:*)`, `Bash(grep:*)`, `Bash(ls:*)`, `Bash(oj-helper:*)`, diagnostic tools (df, du, wc, which, uname)
- No write restrictions — agent can Edit/Write any file (delegation boundary enforced by CLAUDE.md, not permissions)

**OpenJunto deny list**:
- `Bash(rm -rf /*)` — prevent catastrophic deletion
- `Bash(git push --force:*)` — prevent force push (unless explicitly requested)

Permissions are coarse-grained safety rails. Fine-grained control (don't edit code directly, delegate to experts) is protocol in CLAUDE.md, not enforced by permissions.

#### hooks

Lifecycle hooks called by Claude Code at specific events.

<a id="hook-conductor-inject"></a>

**SessionStart**:
- Matcher: `""` (matches all sessions)
- Command: `${CLAUDE_PLUGIN_ROOT}/bin/oj-helper conductor-inject` (the SessionStart hook fires only on session start — startup, resume, `/clear`, compaction — not on plugin reload)
- Timeout: 5 seconds
- Purpose: Inject the manager protocol file (`CONDUCTOR.md`) as `additionalContext` on stdout, AND print a version banner to stderr. The banner is emitted by `conductor-inject` itself (see the conductor-inject subcommand in step-07), not by an inline shell snippet.
  - Banner text (stable, user-facing): `OpenJunto v${version} active — OpenJunto coordination system`
  - `${version}` is read from the plugin package's `VERSION` file (`${CLAUDE_PLUGIN_ROOT}/VERSION`), falling back to `unknown`. The Makefile-era `~/.claude/.oj-version` file is **not** read — it is a legacy artifact detected by `migrate-legacy`.
  - The banner goes to **stderr only**; stdout carries the JSON `additionalContext` payload and must not be polluted.

**SubagentStart**:
- Matcher: `"general-purpose"` [EXTERNAL] (only general-purpose agents) — resolve from `platform-snapshot.yaml` → `hooks[point="SubagentStart"].matchers[0]`
- Command: `oj-helper inject-profile`
- Timeout: 5 seconds
- Purpose: Inject expert preamble + full profile as additionalContext

**Hook mechanics**: Hooks receive JSON on stdin (event data), output JSON on stdout (hook response). Hook failures are non-fatal — if hook times out or errors, the operation proceeds without hook output.

#### Other Settings

- `model: "opus"` — Default model for manager (sub-agents can override via Task tool's `model` parameter)
- `alwaysThinkingEnabled: true` — Enable thinking process visibility
- `effortLevel: "high"` — Request thorough responses
- `attribution.commit: ""` — No AI attribution in commits (enforced by protocol + empty string here)
- `attribution.pr: ""` — No AI attribution in PRs

---

### Installation and Merging

**Initial install**: If `~/.claude/settings.json` doesn't exist, installer copies `src/settings.json` directly.

**Merge on updates**: If `~/.claude/settings.json` exists, installer performs deep merge — objects recursively merged, arrays unioned (deduplicated), primitives: source wins. Preserves user customizations (additional permissions, custom env vars, non-OpenJunto hooks) while updating OpenJunto-specific settings. Uses jq with custom `deepmerge` function. See Makefile `settings` target for implementation.

**Content-hash gating**: Installer tracks source file hash in `~/.claude/.oj-settings-hash`. If source hash matches installed hash, merge is skipped (idempotent — fast no-op when source unchanged).

**Backup**: Installer backs up existing settings.json to `settings.json.backup.{timestamp}` before merging.

---

## Makefile — Installer

**Location**: `{junto_repo}/Makefile`

**Purpose**: Install OpenJunto system from source to `~/.claude/` and `~/.local/bin/`.

**Design Philosophy**: Standard GNU Make with wildcard file discovery, content-hash gating, dry-run mode, and graceful degradation. Wildcards discover all `*.md` files in `src/agents/` (and templates, commands, reference) — adding a new profile requires no Makefile change. Hash gating makes repeated installs fast (no-op when source unchanged). Enterprise overlay is optional — core OpenJunto works without it.

---

### Key Targets

#### install (default)

Runs all installation steps in sequence:
1. `prompt-workspace` — Resolve GitHub workspace path (interactive prompt or env var)
2. `deps` — Check/install CLI dependencies (jq, gh, yq via Homebrew)
3. `claude-md` — Install CLAUDE.md (with backup and GitHub path substitution)
4. `agents` — Install agent profiles (full + compact)
5. `templates` — Install templates
6. `commands` — Install commands
7. `reference` — Install reference files
8. `organization` — Install enterprise overlay files
9. `scripts` — Install scripts to `~/.local/bin/` (oj-helper)
10. `settings` — Merge settings.json (content-hash-gated)
11. `enterprise-setup` — Prompt to clone/update enterprise overlay repo (optional)
12. `clean-legacy` — Remove deprecated artifacts
13. `version` — Write `.oj-version` marker
14. `check-path` — Warn if `~/.local/bin` not in PATH

#### deps

Fast-path detection: If jq, gh, yq all on PATH, skip Homebrew checks entirely (quick).

Otherwise, check each formula:
- If not installed, prompt user: "Install via brew? [y/N]"
- If yes, `brew install {formula}` (not pinned — trust upstream supply chain)
- If no, skip with warning

One-time cleanup: Unpin jq, gh if pinned.

Homebrew checks are slow (~200ms per formula); fast-path detection skips them when tools are already available. Interactive prompts respect user autonomy — no forced installs.

#### settings

Content-hash-gated merge:
1. Compute source hash (`md5 -q src/settings.json`)
2. Read installed hash (`cat ~/.claude/.oj-settings-hash`)
3. If hashes match, skip (idempotent)
4. Otherwise:
   - Backup existing settings.json
   - Deep merge with jq
   - Substitute GitHub workspace path (if non-default)
   - Write new settings.json
   - Write new hash to `.oj-settings-hash`

#### organization

Copies enterprise overlay files from `src/enterprise/reference/*.md` and `src/enterprise/commands/*.md` to `~/.claude/reference/` and `~/.claude/commands/` (merged alongside core files, not in subdirectory). Org-specific files (issue tracker integration, GitHub patterns, AWS CLI patterns) extend core OpenJunto without modifying core files. The merge-alongside strategy means agent profiles and commands can reference org-specific files with standard paths (e.g., `~/.claude/reference/issue-tracker-integration.md`) — no special casing needed.

#### uninstall

Removes OpenJunto-installed files:
- CLAUDE.md
- All agents (full + compact)
- All templates, commands, reference files
- Enterprise overlay files
- Scripts (oj-helper)
- Version marker (`.oj-version`)
- Settings hash (`.oj-settings-hash`)
- Workspace config (`.oj-workspace`)
- Backups (`*.backup.*`)

**Preserves**:
- `settings.json` (user may have non-OpenJunto customizations; deep merge means it contains user changes — removing it would erase those)
- Directory structure (`~/.claude/`, `~/.local/bin/`)

#### status

Shows installed vs source file counts:
- Source section: CLAUDE.md presence, agent/template/command/reference counts, enterprise overlay counts, scripts count, settings.json presence
- Target section: Same counts for installed files, `.oj-version` content

Quick health check — verify installation is complete, identify missing files, check version.

#### help

Prints usage documentation: all targets, variables (DRY_RUN, TARGET_DIR, BIN_DIR, GitHub_WORKSPACE), examples.

---

### GitHub Workspace Path Substitution

CLAUDE.md and settings.json include hardcoded paths: `~/workspace`. On first install, installer prompts for GitHub workspace path (default: `~/workspace`); substitutes any non-default value into both files. Resolved path is saved to `~/.claude/.oj-workspace` and reused silently on subsequent installs.
