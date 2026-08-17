# Generation Prompt: Step 07 — Helper Script

## Input

Read these specification files before generating:

1. **Primary spec**: [FILE: D64-tooling.md] — defines oj-helper architecture, all subcommands, helper functions, graceful degradation philosophy
2. **Supporting specs** (consult only if the primary spec leaves a question open; these are juntospec corpus files under `${SPEC_DIR}/`, resolved by file basename — DO NOT walk the filesystem with `find` to locate them):
   - `D56-commands-automation.md` (juntospec corpus) — shows how commands invoke oj-helper subcommands
   - `D48-reference-system.md` (juntospec corpus) § Dev Mode — explains feedback-path mechanism

Also examine the actual OpenJunto source file for reference:
- `bin/oj-helper` (first 300 lines showing structure, inject-profile, issue-tracker-check, issue-tracker-list)
- `bin/oj-helper` — the `workstream-new` block (the `# workstream-new` banner comment through `cmd_workstream_new`, plus the `_workstream_resolve_workspace` / `_workstream_link_one` / `_workstream_link_all` helper functions it depends on); this subcommand lives well past the first 300 lines, so read it explicitly when generating § 13
- `bin/oj-helper` — the `resolve-path` block (the `# resolve-path` banner comment through `cmd_resolve_path`); like `workstream-new`, this subcommand lives well past the first 300 lines, so read it explicitly when generating § 15 (its banner comment fully documents the keys, layout, and per-key override mechanism). The `install-hooks` block (`cmd_install_hooks`) sits just after `feedback-path` and is likewise past the first 300 lines, so read it explicitly when generating § 14

### Platform Snapshot (from Step 00)
- `platform-snapshot.yaml` — Layer 0 platform capability snapshot. Consume one section:
  - `hooks` — use `hooks[point="SubagentStart"].matchers[0]` as the agent type string used in the `inject-profile` subcommand to filter which agents receive profile injection (currently `"general-purpose"`). This captures the agent type taxonomy as a platform fact rather than a hardcoded string.

## Task

Generate the **oj-helper bash script** as a complete, executable file. Create at path: `bin/oj-helper`

This is a bash script using dispatcher pattern — a case statement on `$1` routes to subcommand functions. Each subcommand is a self-contained function with argument parsing, validation, and error handling.

## Key Requirements

### Script Header

```bash
#!/usr/bin/env bash
# oj-helper — dispatcher for OpenJunto utility subcommands
set -euo pipefail

# Source the pinned-string contracts library. Load-bearing: the
# CONDUCTOR.md-missing stderr literal (OJ_STDERR_CONDUCTOR_MISSING)
# lives in lib/contracts.sh and is pattern-matched by the test harness
# AND grep-asserted by the structural validator (drift canary). If
# sourcing fails, die loudly — silent fallback to a hardcoded literal
# would defeat the entire centralization.
_OJ_SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
if [[ ! -r "${_OJ_SCRIPT_DIR}/lib/contracts.sh" ]]; then
  echo "ERROR: oj-helper: required contracts library missing at ${_OJ_SCRIPT_DIR}/lib/contracts.sh" >&2
  exit 2
fi
# shellcheck source=lib/contracts.sh
source "${_OJ_SCRIPT_DIR}/lib/contracts.sh"

# Base path for the plugin tree. inject-profile resolves three distinct
# locations under this root:
#   - shared preamble:  ${PLUGIN_BASE}/reference/expert-preamble.md
#   - full profile:     ${PLUGIN_BASE}/agents/<name>.md
#   - compact fallback: ${PLUGIN_BASE}/reference/compact/<name>.md
# NOTE: the full profiles are the ONLY files under agents/. The preamble,
# index, and compact profiles were relocated under reference/. AGENTS_DIR
# still points at agents/ (full profiles); the preamble and compact paths
# are derived from PLUGIN_BASE, NOT from AGENTS_DIR.
PLUGIN_BASE="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude}"
AGENTS_DIR="${PLUGIN_BASE}/agents"

debug() { [[ "${OJ_HOOK_DEBUG:-${JUNTO_HOOK_DEBUG:-0}}" == "1" ]] && echo "[oj-helper] $*" >&2 || true; }
die()   { echo "ERROR: $*" >&2; exit 1; }
die_usage() { echo "ERROR: $*" >&2; exit 2; }
```

**Core conventions**:
- `set -euo pipefail` — fail fast on errors, unset variables, pipe failures
- **Contracts source (load-bearing)**: ALL subcommands MUST be able to reference shared pinned-string constants (e.g., `OJ_STDERR_CONDUCTOR_MISSING`) from `bin/lib/contracts.sh`. The script header MUST `source` `lib/contracts.sh` with die-on-fail (see header block above). The contracts file is statically emitted by the generator — DO NOT inline-redefine the constants; sourcing failure must be fatal so drift is caught immediately.
- `debug()` function — controlled by `OJ_HOOK_DEBUG=1` env var (legacy `JUNTO_HOOK_DEBUG` accepted as fallback), writes to stderr
- `die()` function — fatal error with message to stderr, exits with code 1
- `die_usage()` function — fatal USAGE error with message to stderr, exits with code 2. Distinct from `die()` (exit 1, driver/runtime errors). Currently used by `workstream-new`'s argument-validation paths (missing WSID, missing REPO, unknown flag, unexpected positional) so usage errors are distinguishable from driver errors by exit code.
- **Shared version helper `_oj_plugin_version()`** (define once, near the top after `die`): resolves the plugin version string for the SessionStart banner AND the migrate-legacy sentinel. Resolution: prefer `${CLAUDE_PLUGIN_ROOT}/VERSION`; fall back to script-relative `../VERSION` (`$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/../VERSION`) for non-plugin-host invocations; fall back to the literal `unknown` if no readable VERSION file is found. Read with `head -1 ... | tr -d '[:space:]'`. DO NOT read the Makefile-era `~/.claude/.oj-version` file — that artifact belongs to the pre-plugin era and is what `migrate-legacy` detects. `migrate-legacy`'s `_migrate_plugin_version` MUST delegate to this shared helper (thin alias) rather than duplicate the resolution logic.

### Subcommand Functions

Implement these subcommands (in order). The list below enumerates ALL 18 subcommands; the generated `oj-helper` MUST implement every one. Each subcommand listed here corresponds to exactly one `^cmd_NAME(` function definition AND one case-branch in the dispatcher. The static-emitted `hooks/hooks.json` wires three of these (`inject-profile`, `conductor-inject`, `migrate-legacy`) as hook commands — if any of the three is missing from the generated helper, SessionStart/SubagentStart hooks will fire and exit with "Unknown subcommand", silently breaking the plugin at runtime.

**MANDATORY enumeration (15 specced functions)**:

1. `cmd_inject_profile`         — SubagentStart hook (§1)
2. `cmd_conductor_inject`       — SessionStart hook (§2)
3. `cmd_migrate_legacy`         — SessionStart hook (§3)
4. `cmd_feedback_path`          — dev-mode feedback (§4)
5. `cmd_issue_tracker_check`    — issue tracker preflight (§5)
6. `cmd_issue_tracker_list`     — list issues (§6)
7. `cmd_issue_tracker_create`   — create issue (§7)
8. `cmd_issue_tracker_view`     — view issue (§8)
9. `cmd_issue_tracker_transition` — transition state (§9)
10. `cmd_issue_tracker_comment` — comment on issue (§10)
11. `cmd_issue_tracker_link_list` — list cross-references (§11)
12. `cmd_agent_teams_check`     — agent-teams capability probe (§12)
13. `cmd_workstream_new`        — scaffold a parallel-workstream directory (§13)
14. `cmd_install_hooks`         — opt-in .githooks installer (§14)
15. `cmd_resolve_path`          — canonical state-path resolver (§15)
16. `cmd_model_policy`          — effective model policy as JSON (§16)
17. `cmd_backlog_list`          — enumerate every backlog file (§17)
18. `cmd_backlog_lint`          — backlog structural integrity checks (§18)

> **Enumeration is exact again.** All 18 shipped `^cmd_` subcommands are specced here - `install-hooks` and `resolve-path` were promoted from hand-cuts into §14 and §15, `model-policy` was added as §16, and the plural-backlog pair `backlog-list` / `backlog-lint` as §17 and §18. The generated helper therefore contains exactly 18 `^cmd_` functions, so `grep -cE "^cmd_" bin/oj-helper` MUST return `18`; the exact-count invariant is valid. A regen MUST implement every one; none may be dropped to hit a count.

#### 1. inject-profile — SubagentStart Hook

**Purpose**: Automatically inject expert preamble + full profile into spawned sub-agents at creation time.

**Invocation**: Called by Claude Code's SubagentStart hook. Reads hook JSON from stdin.

**Critical implementation details**:

> **[EXTERNAL]** — the agent type filter string (step 3 below) is a platform fact. Resolve from `platform-snapshot.yaml` → `hooks[point="SubagentStart"].matchers[0]` (currently `"general-purpose"`). Bake the resolved string into the generated script rather than hardcoding it.

1. **Require jq**: Exit 0 (no output) if jq missing (graceful degradation)
2. **Read hook JSON from stdin**: Extract `agent_type`, `transcript_path`, `agent_id`
3. **Filter agent type**: Only process agents matching the SubagentStart hook matcher. Resolve `hooks[point="SubagentStart"].matchers[0]` from `platform-snapshot.yaml` at generation time and bake that string into the generated script as the comparison value (currently `"general-purpose"`). For Bash, Explore, Plan, or custom types: exit 0 (no output)
4. **Derive subagent transcript path**: `{session_dir}/subagents/agent-{agent_id}.jsonl` where `session_dir = transcript_path minus .jsonl extension`
5. **Wait for transcript file**: Poll up to 500ms (5 iterations of 100ms sleep) for file to appear
6. **Read spawn prompt**: Read first line of transcript, extract spawn prompt text from JSONL message
   - If content is string: use directly
   - If content is array of `{type, text}` blocks: join all `type=="text"` blocks with jq
7. **Expert identification** (two strategies, tried in order):
   - **HTML marker**: `<!-- oj-expert: PROFILE_NAME -->` in spawn prompt (bash regex: `\<\!--\ oj-expert:\ ([a-z][a-z0-9-]+)\ --\>`). Also accept the legacy form `<!-- junto-expert: PROFILE_NAME -->` for one release as a backward-compat alias.
   - **Path pattern**: `~/.claude/agents/PROFILE_NAME.md` reference in spawn prompt (bash regex: `/\.claude/agents/([a-z][a-z0-9-]+)\.md`)
8. **Path traversal guard**: Reject profile names containing `..` or `/`
9. **Load profile files** (paths derived from `PLUGIN_BASE`; the preamble and compact profiles were relocated out of `agents/` — see the header note):
   - Read the shared preamble from `${PLUGIN_BASE}/reference/expert-preamble.md` (NOT `agents/_preamble.md`).
   - Read the full profile from `${AGENTS_DIR}/{PROFILE_NAME}.md` (i.e. `${PLUGIN_BASE}/agents/{PROFILE_NAME}.md`).
   - If the full profile is not found, fall back to the compact profile at `${PLUGIN_BASE}/reference/compact/{PROFILE_NAME}.md`. **BUG FIX**: earlier drafts read a nested `${AGENTS_DIR}/compact/{PROFILE_NAME}.md` (i.e. `agents/compact/{PROFILE_NAME}.md`) — that path never exists (compact profiles live under `reference/compact/`, not under `agents/`), so the fallback silently failed and no profile was injected. The compact fallback MUST read `${PLUGIN_BASE}/reference/compact/{PROFILE_NAME}.md`.
10. **Strip YAML frontmatter, then build context string**:
   - The full profile emitted by step-03 begins with a YAML frontmatter block (`---` … `name:` … `description:` … plus its model-class spawn keys … `---`). Strip this leading frontmatter block from `profile_content` BEFORE injection — it is spawn configuration read by the platform, not context the sub-agent should see. Remove only a frontmatter block that starts on line 1: if the first non-empty line is `---`, drop everything through the matching closing `---` line (and any immediately following blank line). If the file does not start with `---` (e.g. a compact profile, which carries no frontmatter), inject it unchanged. A robust awk/sed one-liner is acceptable; do NOT strip a `---` that appears later in the body (horizontal rules inside the profile must survive).
   - Build the context string from the stripped content: `preamble + "\n\n---\n\n" + profile_content_without_frontmatter`.
11. **Output hook response JSON**:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStart",
    "additionalContext": "CONTEXT_STRING"
  }
}
```

**CRITICAL DESIGN NOTE**: Claude Code does NOT pass the spawn prompt to hooks in the input JSON. The hook MUST read the subagent's transcript file to find the spawn prompt. This is based on runtime behavior, not documented API.

**Fallback behavior**: If jq missing, transcript unavailable, profile not found, or no expert marker detected → exit 0 with no output. The spawn proceeds without profile injection.

**Debug output** (when `OJ_HOOK_DEBUG=1`):
- "skipping agent_type='X' (not [resolved-matcher])" — where `[resolved-matcher]` is the value resolved from `platform-snapshot.yaml` → `hooks[point="SubagentStart"].matchers[0]` (currently `general-purpose`)
- "transcript not found after 500ms: PATH"
- "spawn prompt empty or unparseable for agent ID"
- "identified profile 'NAME' via HTML marker"
- "identified profile 'NAME' via path pattern"
- "loaded full profile: PATH" (from `${PLUGIN_BASE}/agents/NAME.md`)
- "loaded compact profile (full not found): PATH" (from `${PLUGIN_BASE}/reference/compact/NAME.md`)
- "no profile found for 'NAME' (checked full agents/ and reference/compact/)"
- "stripped YAML frontmatter from full profile 'NAME'"
- "injecting profile 'NAME' (~NNN bytes)"

#### 2. conductor-inject — SessionStart Hook

**Purpose**: Inject the manager protocol (CONDUCTOR.md) as `additionalContext` into the SessionStart hook response, so every Claude Code session starts with manager context loaded.

**Invocation**: Called by Claude Code's SessionStart hook (wired in static-emitted `hooks/hooks.json`). No stdin payload required.

**Reference implementation**: `oj-claude/bin/oj-helper:220-280` (the canonical hand-cut baseline).

**Critical implementation details**:

0. **Version banner (FIRST, stderr-only)**: Before the jq check, emit the SessionStart version banner via a small helper (`_conductor_emit_banner`). The banner confirms OpenJunto is active and MUST fire on EVERY conductor-inject path (including the degraded missing-jq and missing-CONDUCTOR paths), so adopters always get the "active" signal.
   - Exact text (stable, user-facing — keep byte-identical to F16-architecture.md § SessionStart Hook; the em-dash is intentional):
     ```
     OpenJunto v$(_oj_plugin_version) active — OpenJunto coordination system
     ```
   - Write to **stderr only** (`>&2`). The hook's stdout carries the JSON `additionalContext` payload; a stray stdout byte would corrupt it. jq is NOT required for the banner.
   - The version comes from the shared `_oj_plugin_version()` helper (plugin `VERSION`, `unknown` fallback) — NOT from the Makefile-era `~/.claude/.oj-version` file.
1. **jq is required for safe JSON encoding**. If `command -v jq` fails, emit an actionable stderr line AND a hardcoded empty JSON envelope, then `return 0`:
   ```
   "OpenJunto: jq required for CONDUCTOR injection; install via `brew install jq` or equivalent" >&2
   ```
2. **Path resolution precedence** (helper function `_conductor_resolve_path`):
   - **Primary**: `${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` when `CLAUDE_PLUGIN_ROOT` is non-empty.
   - **Fallback**: `$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/../CONDUCTOR.md` (script-relative).
3. **Empty-JSON helper** (`_conductor_emit_empty_json`): emit hardcoded `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}` so degraded paths work without jq.
4. **CONDUCTOR.md missing or unreadable**:
   - Emit `${OJ_STDERR_CONDUCTOR_MISSING}` to stderr (this variable is sourced from `lib/contracts.sh` — DO NOT inline-hardcode the literal; the contracts library is the source of truth, and the validator's drift canary greps `bin/oj-helper` for a reference to the variable name, not a copy of the string).
   - Emit hardcoded empty JSON envelope via `_conductor_emit_empty_json`.
   - `return 0`.
5. **CONDUCTOR.md present but empty** (`! -s`): emit empty JSON envelope; emit NO CONDUCTOR advisory (legitimate adopter state — manager protocol intentionally disabled). Note: the version banner from step 0 still fires on stderr (it is an active-confirmation signal, not a warning about CONDUCTOR); only the `OJ_STDERR_CONDUCTOR_MISSING` advisory is suppressed here.
6. **CONDUCTOR.md present and non-empty**: use `jq -n --rawfile body <path>` to load content safely:
   ```bash
   jq --rawfile body "$conductor_path" -n '{
     hookSpecificOutput: {
       hookEventName: "SessionStart",
       additionalContext: $body
     }
   }'
   ```
   For older jq versions lacking `--rawfile`, fall back to `jq -Rs '...' < "$conductor_path"`.

**Graceful degradation summary**: every path emits the version banner to stderr (step 0) and exits 0 with a valid JSON envelope on stdout. Never `die`. Never emit malformed JSON. Never write the banner (or any non-JSON) to stdout. The hook timeout is 5s; pathologically slow paths must not block past that.

**Why this matters**: `hooks/hooks.json` wires `${CLAUDE_PLUGIN_ROOT}/bin/oj-helper conductor-inject` on SessionStart. If the dispatcher does not recognize `conductor-inject`, every Claude Code session prints "Unknown subcommand" and starts without the manager protocol — silently broken.

#### 3. migrate-legacy — SessionStart Hook (Legacy Install Detection)

**Purpose**: Detect Makefile-era installs (pre-plugin OpenJunto) and write dual-sentinel migration markers. Scope is detect + log + write ONLY — no interactive prompts, no destructive cleanup.

**Invocation**: Called by Claude Code's SessionStart hook (wired in static-emitted `hooks/hooks.json`). No stdin payload required.

**Reference implementation**: `oj-claude/bin/oj-helper:390-510` (the canonical hand-cut baseline).

**Critical implementation details**:

1. **Dual-sentinel design**:
   - **Backup (authoritative)**: `${XDG_CONFIG_HOME:-$HOME/.config}/oj/.migration-done`
   - **Data-dir (soft hint)**: `${CLAUDE_PLUGIN_DATA}/.migration-done` (only when `CLAUDE_PLUGIN_DATA` is non-empty — guard with `[[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]`).
   - **Either-OR presence semantics**: if EITHER sentinel exists, migration is considered done.
   - **Backup-only is "already migrated"**: when only the backup is present (post `claude plugin uninstall && reinstall`), re-create the data-dir sentinel from the backup contents WITHOUT re-running legacy detection (self-healing path). Emit `[oj] migration: already complete (backup sentinel found)` to stderr.
2. **Write order**: backup-FIRST, then data-dir. The backup MUST land before any user-visible side effect so a crash between the two writes still leaves a recoverable record.
3. **Atomic writes**: use a helper (`_migrate_atomic_write`) that writes via `mktemp` + `mv` on the same filesystem. Sentinel body shape:
   ```
   schema_version=1
   plugin_version=<from VERSION file>
   migrated_at=<ISO-8601 UTC>
   migration_source=<makefile-era|clean-install|already-complete>
   ```
4. **Concurrency lock**: `mkdir ${xdg_root}/.migration.lock` (atomic per POSIX). On EEXIST, exit silently — another invocation will write the sentinels. Trap `rmdir` on EXIT.
5. **Stale-lock recovery**: a crashed prior invocation could permanently block migration. If `mkdir` fails AND the lock dir is older than 60s, reclaim it:
   ```bash
   if [[ -n "$(find "$lockdir" -maxdepth 0 -mmin +1 2>/dev/null)" ]]; then
     rm -rf "$lockdir" 2>/dev/null || true
     mkdir "$lockdir" || return 0
   fi
   ```
   `find -mmin +1` is supported on both BSD (macOS) and GNU `find`.
6. **Legacy detection** (helper function `_migrate_detect_legacy`, emits one finding per line; empty = clean install). Three signals:
   - `${HOME}/.claude/.oj-version` exists (Makefile-era version file).
   - `${HOME}/.local/bin/oj-helper` is a symlink (Makefile install).
   - `${HOME}/.claude/settings.json` references `oj-helper` (use `grep -q "oj-helper"` — keeps this path jq-independent).
7. **migration_source**:
   - findings non-empty → `makefile-era`; ALSO write a log file at `${xdg_root}/migration-<unix-ts>.log` with the findings and emit one stderr line: `[oj] Legacy install detected (see <log path>)`.
   - findings empty → `clean-install`.
   - self-healing path → label `already-complete` (effectively — the path returns early before writing a new sentinel; the existing backup is replayed verbatim into the data-dir).
8. **Graceful degradation**: jq is NOT required by `migrate-legacy` (detection uses `grep` against settings.json, not `jq`). The function must always `return 0` on success or silent-skip paths.

**Why this matters**: `hooks/hooks.json` wires `${CLAUDE_PLUGIN_ROOT}/bin/oj-helper migrate-legacy` on SessionStart. Missing dispatcher entry → "Unknown subcommand" → legacy installs never detected, adopters running parallel Makefile installs accumulate orphan symlinks.

#### 4. feedback-path — Dev Mode Feedback Path

**Purpose**: Output timestamped file path for dev mode feedback collection.

**Invocation**: `oj-helper feedback-path` (no arguments)

**Protocol**:
1. Check `$OJ_DEVMODE` (falling back to `$JUNTO_DEVMODE`) — if not "1", exit 0 with no output (feedback disabled)
2. Extract org/repo from git remote origin URL:
   - Handle SSH (`git@host:org/repo.git`) and HTTPS (`https://host/org/repo.git`)
   - Use sed to strip `.git` suffix and extract last two path components
3. Create directory: `~/.claude/dev/feedback/{org}/{repo}/`
4. Output timestamped path: `~/.claude/dev/feedback/{org}/{repo}/YYYY-MM-DDTHHMMSS.md`

**Example sed pipeline**:
```bash
orgrepo=$(git remote get-url origin | sed 's/\.git$//' | sed 's|.*[:/]\([^/]*/[^/]*\)$|\1|')
```

#### 5-11. Issue Tracker Subcommands

> **Design principle**: These subcommands define a **generic interface** for issue tracking operations. The default implementation uses GitHub Issues via `gh` CLI. Organizations using other tools (e.g., Linear, GitLab) can replace these subcommands via the enterprise overlay pattern (spec D72) without modifying core oj-helper.

**Helper functions** (before subcommands):

```bash
tracker_require_auth() {
  if ! command -v gh >/dev/null 2>&1; then
    die "gh not found. Install via: brew install gh"
  fi
  if ! gh auth status >/dev/null 2>&1; then
    die "GitHub auth required. Run: gh auth login"
  fi
}

tracker_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    die "jq is required but not found. Install via: brew install jq"
  fi
}
```

**Subcommands**:

**cmd_issue_tracker_check** — Validate issue tracker prerequisites:
- Check `gh` installed and authenticated, `jq` installed
- If any check fails, output JSON: `{"ok":false,"errors":[...],"project":null}` and exit 1
- Discover project context (priority order): `--project` flag → `$ISSUE_TRACKER_PROJECT` env → current `gh` repo
- Output JSON: `{"ok":true,"project":"owner/repo"}` if found, `{"ok":true,"project":null}` if not configured
- Exit 0

**cmd_issue_tracker_list** — List open issues:
- Parse flags: `--project` (optional, defaults to current repo), `--status` (default: open), `--limit` (default: 50), `--label` (optional filter)
- Use `gh issue list --repo {project} --state {status} --limit {limit} --json number,title,state,labels,assignees,body`
- Output JSON array of issues

**cmd_issue_tracker_create** — Create issue:
- Parse flags: `--project` (optional), `--title` (required), `--body` (optional), `--label` (optional, repeatable)
- Use `gh issue create --repo {project} --title {title} --body {body} --label {labels}`
- Output JSON of created issue

**cmd_issue_tracker_view** — View issue details:
- Parse flags: `NUMBER` (required), `--project` (optional)
- Use `gh issue view {number} --repo {project} --json number,title,state,body,comments,labels,assignees`
- Output JSON

**cmd_issue_tracker_transition** — Change issue state:
- Parse flags: `NUMBER` (required), `--status` (required: open|closed)
- Use `gh issue close {number}` or `gh issue reopen {number}`
- Exit 0 on success

**cmd_issue_tracker_comment** — Add comment to issue:
- Parse flags: `NUMBER` (required), `--body` (required)
- Use `gh issue comment {number} --body {body}`
- Exit 0 on success

**cmd_issue_tracker_link_list** — List cross-references (via GitHub issue body/comments):
- Parse flags: `NUMBER` (required)
- Use `gh issue view {number} --json body,comments` and extract `#NNN` or `owner/repo#NNN` references
- Output JSON array: `[{"key":"#42","summary":"..."}]`

> **Note**: GitHub Issues does not have first-class issue linking like some trackers. Cross-references are extracted from issue bodies and comments. Organizations needing richer linking can override via enterprise overlay.

#### 12. agent-teams-check — Agent Teams Capability Probe

**Purpose**: Report whether the host environment has the Claude Code experimental agent-teams feature enabled (the substrate that binds the Convene primitive on this platform). Consumed by the `/oj:cycle` and `/oj:run-task` skills at the tier-classification step: if the probe reports `available:false`, the Complex-tier branch follows the Convene→Consult fallback documented in `D32-execution-models.md` §3 ("Fallback (Axiom 8 — graceful degradation)") instead of issuing `TeamCreate`.

**Invocation**: `oj-helper agent-teams-check` (no arguments)

**Design principle (Axiom 8)**: This probe **always exits 0**, regardless of availability. It is a capability report, not a precondition gate — failing it would defeat the graceful-degradation path that justifies its existence (the cycle still proceeds, it just selects the degraded substrate). Modeled on `cmd_issue_tracker_check` in JSON-envelope shape, but inverts the exit-code contract: `issue-tracker-check` exits 1 on missing prereqs (the issue-tracker integration genuinely cannot proceed); `agent-teams-check` always exits 0 because the fallback IS the proceed path.

**Protocol**:

1. Read `${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}` once into a local variable.
2. Emit JSON to stdout:
   - When the value is exactly `"1"`: `{"ok":true,"available":true,"reason":"env"}`
   - Otherwise (unset, empty, `"0"`, or any other value): `{"ok":true,"available":false,"reason":"env_unset"}`
3. Exit 0 in every case.

**Implementation skeleton**:

```bash
cmd_agent_teams_check() {
  # No flags. Reject unknowns to mirror the other check-class subcommands.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      *) die "Unknown flag: $1" ;;
    esac
  done

  local val="${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}"
  if [[ "$val" == "1" ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n '{ok:true, available:true, reason:"env"}'
    else
      echo '{"ok":true,"available":true,"reason":"env"}'
    fi
  else
    if command -v jq >/dev/null 2>&1; then
      jq -n '{ok:true, available:false, reason:"env_unset"}'
    else
      echo '{"ok":true,"available":false,"reason":"env_unset"}'
    fi
  fi
  return 0
}
```

**jq dependency**: Use jq when present for safe JSON encoding (matches the other tracker subcommands); fall back to hardcoded JSON literals when jq is absent so the probe stays usable on degraded installs. Either path emits valid JSON.

**Why this matters**: Without an explicit probe, skills would have to inspect the env var themselves (duplicated logic across `/oj:cycle` and `/oj:run-task`) or assume Convene is available (the bug this subcommand exists to fix). Centralizing the check here makes the availability rule a single grep target and lets future host-feature detection (e.g., a `claude config get` form) replace the env-var heuristic without touching every skill.

#### 13. workstream-new — Scaffold a Parallel-Workstream Directory

**Purpose**: Scaffold `<workspace>/.workstreams/<wsid>/` for running an isolated `/oj:cycle` thread that SHARES the workspace's canonical `.claude/` state (BACKLOG.md, session, artifacts) with other concurrent workstreams. Consumed by the `workstream-new` skill (step-06 § 8) and specced platform-neutrally in `D56-commands-automation.md` § Workstream Scaffolding Command.

**Invocation**: `oj-helper workstream-new <wsid> <repo> [branch] [--workspace <path>]`

**Reference implementation**: the `workstream-new` block in `bin/oj-helper` (the `# workstream-new` banner through `cmd_workstream_new`, plus `_workstream_resolve_workspace` / `_workstream_link_one` / `_workstream_link_all`). Reproduce it faithfully.

**Critical implementation details**:

1. **Argument parsing**: positional `WSID` (required) and `REPO` (required), optional positional `BRANCH` (default `<wsid>`), and flag `--workspace <path>`. The FOUR usage-error paths - missing WSID, missing REPO, an unknown `--flag`, and an unexpected extra positional - MUST exit `2` via `die_usage` (NOT `die`), so a usage error is distinguishable from a driver error by exit code.
2. **Workspace resolution** (helper `_workstream_resolve_workspace`, in order): (a) explicit `--workspace <path>` (must exist); (b) `$OJ_STATE_ROOT` env var as the workspace root, tolerating and stripping a trailing `/.claude/local` or `/.claude` suffix, when `<root>/.claude/state/session.md` exists (lets a SessionStart hook pin the canonical workspace regardless of `$PWD`); (c) `$PWD` if `$PWD/.claude/state/session.md` exists; (d) walk up from `$PWD` to the first ancestor containing `.claude/state/session.md`. This is a driver error: `die` (exit 1, NOT `die_usage`) with an actionable message if none resolves. The helper's own `--workspace path does not exist` case is likewise a driver error (exit 1 via `die`).
3. **Repo validation**: driver error - `die` (exit 1) if `<workspace>/<repo>` is not a directory or is not a git repo (`.git` absent).
4. **Scaffold**: create `<workspace>/.workstreams/<wsid>/.claude/`; symlink the canonical shared-state paths into it via a link helper that backs up any pre-existing real file with a timestamp suffix before replacing it with a symlink, and is idempotent (a correct existing symlink is left as "already linked"); create a git worktree of `<repo>` at `./<repo>` on `<branch>`; and write a real (never-overwritten) per-workstream `.claude/CLAUDE.md` carrying the `[ws: <wsid>]` tagging directive and the don't-touch-other-workstreams rule.

   The link set, in order:
   - **`oj-paths.env`** (optional) - **MUST be linked, and linked first.** A workstream directory has its own `.claude/`, so `resolve-path`'s ancestor walk stops at the workstream rather than at the canonical workspace. Without this link, every per-key override AND the layout profile silently revert to the shipped defaults inside a workstream: the paths still resolve, just to the wrong files, which is precisely the failure mode `resolve-path` exists to prevent. A regen that drops this link reintroduces a silent-wrong-answer bug.
   - `state/session.md` (required), `BACKLOG.md` (required), `artifacts` (optional) - the original three.
   - **Root-level category files** (all optional): `decisions.md`, `open-questions.md`, `facts`. All optional means a `flat` workspace has none of them, each is a silent skip, and flat behavior is byte-identical to before the category keys existed. Link only the ROOT-level nodes: deeper nodes are project directories, and linking a whole taxonomy tree per workstream would be a scaffolding decision this subcommand has no basis to make.

   The generated `.claude/CLAUDE.md` body MUST describe the shared state as the resolved set rather than the old literal three, tell the reader to resolve paths with `oj-helper resolve-path <key>` rather than treating those paths as literal, name the linked `oj-paths.env` as what makes resolution identical in the workstream and the canonical workspace, and extend the tagging rule to appends into shared TYPED files (e.g. `.claude/decisions.md`) - which is where concurrent workstreams collide most easily.
5. **Idempotent**: re-running yields the same end state. `.claude/CLAUDE.md` is never overwritten; existing real state files are backed up before being linked.
6. **Output**: a human-readable summary plus a `Next steps:` block (the `cd` / `claude` / `/rename` / `/oj:cycle` lines the skill surfaces verbatim). **Exit codes**: `0` created-or-already-present; `1` driver error via `die` (workspace unresolvable, repo missing, not a git repo); `2` usage error via `die_usage` (missing WSID, missing REPO, unknown flag, unexpected positional). The distinction is load-bearing: usage errors (2 via `die_usage`) vs driver errors (1 via `die`) MUST be routed through the matching helper so the exit code is unambiguous.

**Why this matters**: the `workstream-new` skill's entire filesystem contract lives here — worktree creation, shared-state symlinking, and the tagging overlay that makes concurrent `/oj:cycle` threads safe against one shared backlog. A regen that omits this subcommand leaves the generated `workstream-new` skill calling a dispatcher branch that `die`s with "Unknown subcommand".

#### 14. install-hooks — Opt-In `.githooks` Installer

**Purpose**: Set `git config core.hooksPath .githooks` in the current repo so the repo's `.githooks/` gate (e.g. the commit-msg hook that enforces the Regen-Source trailer on snapshot-tracked edits) takes effect. Opt-in by design (a BL-025-m.5 PM constraint): auto-installing hooks at plugin-install time would be an onboarding speedbump for adopters whose workflow does not include regen.

**Invocation**: `oj-helper install-hooks` (no arguments; run from inside the target repo)

**Reference implementation**: the `install-hooks` block in `bin/oj-helper` (the `# install-hooks` banner comment through `cmd_install_hooks`). Reproduce it faithfully.

**Critical implementation details**:

1. **Git-work-tree guard**: verify `$PWD` is inside a git working tree via `git rev-parse --is-inside-work-tree` (suppress its stderr); `die` with an actionable message if not.
2. **Resolve top-level**: `git rev-parse --show-toplevel` gives the repo root; `die` if it cannot be resolved. `core.hooksPath` is repo-local (lives in `.git/config`); the canonical value `.githooks` is relative so the hook directory travels with the working tree.
3. **Require the hooks directory**: `die` if `<toplevel>/.githooks` does not exist.
4. **Require at least one executable hook**: count files under `.githooks/` that are both regular files and executable (`-f && -x`); `die` if the count is zero, so an empty `.githooks/` never silently appears "installed".
5. **Apply the config, repo-scoped only**: `git config core.hooksPath .githooks` writes to the current repo's `.git/config` only - never `--global`, never any other working tree. Idempotent: git overwrites any existing value, so re-running yields the same end state.
6. **Summary + exit codes**: on success print exactly `Installed: core.hooksPath -> .githooks (N hook(s) active)` to stdout. Exit 0 when installed or already installed (the summary prints either way); exit 1 (via `die`) on any driver error - not a git repo, `.githooks` missing, or no executable hooks.

**Why this matters**: the `.githooks/` commit-msg gate is what keeps snapshot-tracked edits carrying their Regen-Source trailer. Making installation opt-in and repo-scoped (rather than global or auto-install) honors the BL-025-m.5 PM constraint; a regen that dropped this subcommand would leave contributors with no supported way to arm the gate short of hand-running `git config`.

#### 15. resolve-path — Canonical State-Path Resolver

**Purpose**: Echo the absolute path OpenJunto should use for a canonical state file or directory, honoring per-project layout and overrides. The skills (save-session, show-backlog, run-task, cycle) and the CONDUCTOR templates historically hardcoded `.claude/state/session.md`, `.claude/BACKLOG.md`, and `.claude/artifacts/`; a project that relocated state (via `.claude/oj-paths.env`) had no way to redirect OpenJunto without forking every skill. resolve-path centralizes the decision: a skill asks for a key, oj-helper returns the path.

**Invocation**: `oj-helper resolve-path <key> [--workspace PATH] [--node RELPATH]`, where `<key>` is one of two families:

- **state keys** - `session | backlog | artifacts | state-dir | config | retros`
- **category keys** - `decisions | facts | open-questions | requirements | design | plan`

**Reference implementation**: the `resolve-path` block in `bin/oj-helper` (the `# resolve-path` banner comment through `cmd_resolve_path`, plus the `OJ_RESOLVE_PATH_*_KEYS` constants and the `_oj_paths_env_get` helper that sit between the banner and the function). This subcommand lives well past the first 300 lines, so read it explicitly when generating this section; its banner comment fully documents the keys, the layout profiles, and the override mechanism.

**Critical implementation details**:

1. **Argument parsing**: one positional `<key>` (required), plus optional `--workspace <path>` and `--node <relpath>` flags. `die` on a missing key, an unknown `--flag`, or an unexpected extra positional.
2. **Workspace-root resolution** (root = the directory that contains `.claude/`), in order: (1) `--workspace PATH` (must exist - `die` if not); (2) `$OJ_STATE_ROOT` (set by a SessionStart hook) as the root directly, tolerating and stripping a trailing `/.claude/local` or `/.claude` suffix for compatibility with older hooks, when the stripped directory exists; (3) the nearest ancestor of `$PWD` (including `$PWD`) containing a `.claude/` directory; (4) `$PWD` as the final fallback (the ancestor walk always resolves to something, so this path never `die`s on an unresolvable workspace).
3. **Layout profile**: read `layout=` from `<root>/.claude/oj-paths.env`. Two values are valid, `flat` and `hierarchy`; absent means `flat`. Any other value is a `die` (exit 1) - a typo'd profile MUST NOT degrade silently to `flat`, because that would resolve every category key to the wrong answer without a signal. **`flat` is the default and stays the default**: OpenJunto must be able to *express* a layout it does not *impose*, so promoting one project's taxonomy to the shipped default is out of scope by construction (and would be a breaking change for every existing adopter).
4. **Node prefix** (category keys only): `--node RELPATH` selects the owning node, defaulting to the state root `.claude`. Normalize RELPATH by stripping a leading `./`, a leading `/`, a trailing `/`, and a leading `.claude/`, so `--node proj/sub` and `--node .claude/proj/sub` name the same node; a RELPATH of exactly `.claude` means the root node. `--node` MUST be accepted-and-ignored where it does not apply (state keys, and `flat` layout) so a caller never has to branch on the active profile just to pass it.
5. **Per-key defaults** (workspace-relative; oj state lives directly under `.claude/` - there is no `.claude/local/` layout):
   - **State keys, both profiles** - `session` -> `.claude/state/session.md`, `backlog` -> `.claude/BACKLOG.md`, `artifacts` -> `.claude/artifacts`, `state-dir` -> `.claude/state`, `config` -> `.claude`, `retros` -> `.claude/archive/retros`. These are profile-INDEPENDENT: relocating them is an override's job, not a taxonomy's, so `hierarchy` must not silently move `session`.
   - **Category keys under `hierarchy`** - `<node>/<key>.md`, except `facts` -> `<node>/facts` (a directory). So `decisions` -> `.claude/decisions.md`, and `design --node proj/sub` -> `.claude/proj/sub/design.md`.
   - **Category keys under `flat`** - deliberately UNSET (see exit 3 below). A flat project has no per-type filing surface, and inventing one (`.claude/DECISIONS.md`) would aim skills at a file the project does not keep. An unset key that fails loudly beats a key that silently resolves somewhere wrong.
   - `die` on an unknown key.
6. **Per-key override**: `<root>/.claude/oj-paths.env` may set `key=workspace-relative-path` (with `#` comments and surrounding whitespace allowed); an override wins over the profile default for that key. Take the last matching assignment; an override value that is itself absolute is honored as-is. An override MUST also win over the `flat`-unset state, so a flat project can give a single category key a home without adopting the whole hierarchy.
7. **Override validation**: a RELATIVE override value that does not start with `.claude/` (bare `.claude` also counts as inside the tree) resolves OUTSIDE the state tree. Emit a `WARNING:` on **stderr** naming the key, the offending value, the file, and the path it actually resolves to - then honor the value anyway. This is the easiest misconfiguration to create and the hardest to notice, and it is a warning rather than a `die` because relocating outside `.claude/` is unusual but not forbidden. An ABSOLUTE override is honored silently: leaving the tree on purpose is a supported escape, so it must not nag.
8. **Emit and exit**: print exactly one absolute path on stdout (`$root/$rel`, or `$rel` unchanged when the resolved value is already absolute). The path is NOT created - resolve-path is pure resolution, safe to call before the file exists. Any warning goes to stderr ONLY; stdout must stay exactly one path, since callers consume it as such. Exit codes:
   - `0` - resolved.
   - `1` - unknown key, unknown flag, extra positional, bad layout profile, or a `--workspace` path that does not exist.
   - `3` - a KNOWN key that the active profile leaves unset (a category key under `flat`), with an advisory on stderr naming the key and both remedies (`layout=hierarchy`, or an explicit `<key>=.claude/...` override) and NOTHING on stdout. Exit 3 MUST stay distinct from exit 1: callers branch on that difference to tell "this project has no home for that document type, fall back" apart from "I asked for a key that does not exist, which is my bug".

**Why this matters**: resolve-path is on the hot path for the state-touching skills - cycle, run-task, save-session, spec, and backlog-compact all call it instead of hardcoding `.claude/...` paths, so a project can relocate its state via `.claude/oj-paths.env` without any skill being forked. A regen that omitted this subcommand would leave those skills resolving nothing (or reverting to stale hardcoded paths), silently breaking per-project state layout. The category keys are what let a skill **file** a document rather than merely produce one: without them, a skill that concludes "this is a decision" has nowhere to put it and falls back to dumping a document in `artifacts/`, which recreates the one-dump-directory pattern a type-based taxonomy exists to remove.

**Verification**: `scripts/tests/oj-helper-hook-test.sh` scenario S16 covers both profiles - state-key defaults, category keys exiting 3 under `flat`, category resolution under `hierarchy`, `--node` normalization across four spellings, the typo'd-profile falsifier, override precedence over both a flat-unset and a hierarchy default, and the missing-prefix warning landing on stderr without polluting stdout. Extend S16 rather than rewriting it: a harness that only knows one layout is how the next layout change breaks silently.

Note the `id-index` key alongside the two families: it has **no default under either profile** and is override-only. It names a project-authored file mapping item id -> owning backlog file, and the plugin cannot guess whether one exists or what it is called, so guessing would hand callers a path to a file that is not an index. It exits 3 when unset, and its advisory MUST NOT suggest `layout=hierarchy` - a profile switch cannot supply an override-only key, so that advice would be actively misleading.

#### 17. backlog-list — Enumerate Every Backlog File

**Purpose**: Echo every backlog file, one absolute path per line. `resolve-path backlog` answers "ONE path" and must keep doing so - nine call sites consume it as a single path - but a backlog is not always one file. A project large enough to carry several sub-projects splits its backlog per node, and a skill pointed at any single file then shows a fraction of the work while omitting the rest **without saying so**. That silence is the defect: nothing about successfully reading one file tells you four others exist. The plural question therefore gets its own subcommand rather than a changed contract:

- `resolve-path backlog` -> where to **write** (always exactly one path)
- `backlog-list` -> what exists to **read** (zero or more paths)

**Invocation**: `oj-helper backlog-list [--workspace PATH]`

**Critical implementation details**:

1. **Workspace-root resolution**: identical to `resolve-path` (see §15 detail 2).
2. **Source, in order**: (a) `backlog-glob=` in `<root>/.claude/oj-paths.env` - **one or more** workspace-relative glob patterns separated by whitespace (e.g. `backlog-glob=.claude/backlog.md .claude/proj/**/plan.md`). Several patterns are supported because the files making up one backlog need not share a filename. Multiple `backlog-glob=` LINES are not merged; the last wins, matching `resolve-path`'s `tail -n1` precedence. (b) otherwise the single `resolve-path backlog` answer, emitted only if that file exists.
3. **Globbing**: enable `nullglob` (so a pattern matching nothing expands to nothing rather than to the literal pattern, which would be emitted as a bogus path) AND `globstar` (so `**` spans directory levels - a type-based taxonomy nests nodes at varying depths and a single-level `*` cannot reach them). **Save and restore both options**: the function runs inside a long-lived dispatcher, and leaking shell options into unrelated subcommands is action at a distance.
4. **Split the pattern list WITHOUT pathname expansion** - use `read -ra`, never a bare `for pat in $glob`. This is a real regression, not a hypothetical: an unquoted expansion globs each word against `$PWD` first, and with `nullglob` on, a pattern that matches nothing in the *current* directory expands to nothing and is silently discarded before it is ever anchored to `$root`. The symptom is `backlog-list` printing nothing while the files plainly exist.
5. **Emit only existing regular files**, sorted and deduplicated (`LC_ALL=C sort -u`).
6. **Exit 0 even when the output is empty** - an empty backlog set is a legitimate answer, not an error, and callers count lines. Exit 1 only on a bad `--workspace` or a bad flag.

**Why this matters**: `show-backlog` aggregates across the returned set and `backlog-compact` operates per file. Without this subcommand a split backlog is invisible: the skills read one file, report success, and omit the majority of the work.

#### 18. backlog-lint — Backlog Structural Integrity Checks

**Purpose**: Report structural defects across the backlog set. Both classes below were found in a real 1,151-line backlog, and **neither was findable by reading** - they are invisible at human review and cheap for a machine, which is exactly the shape of check worth automating.

**Invocation**: `oj-helper backlog-lint [--workspace PATH]`

**Critical implementation details**:

1. **File set**: obtained from `backlog-list` (same workspace resolution). When it is empty, print a "nothing to check" line and exit 0 - do not treat an absent backlog as a failure.
2. **Item-id definitions** are read from the § Backlog Item Schema definition form only - a list item opening with a bold id, `- **<PREFIX>-<N>**` - **not** from every mention of an id. A cross-reference in prose MUST NOT be counted as a second definition, or the check cries wolf on every link and gets ignored.
3. **Checks**:
   - `DUPLICATE-ANCHOR` (per file): the same `<a id="x">` defined twice. Every inbound link resolves to the first; the second is unreachable.
   - `DUPLICATE-ID` (per file): the same item id defined twice, making the second unreachable.
   - `ID-COLLISION` (across files, only when more than one file is in the set): the same id defined in two different files, so two entirely different items answer to one id and inbound links silently resolve to whichever is read first. **Splitting one backlog into several creates this risk where none existed**, and two concurrent sessions creating items the same day is enough to trigger it. Name every owning file in the finding.
   - All three are `grep -o` plus `sort | uniq -d`; keep them that cheap.
4. **Output and exit**: one line per finding on stdout, then a summary. Exit 0 clean, **1 when any finding is reported** so a caller can gate on it, 2 on a driver error via `die_usage`.

**Why this matters**: this is the check that makes a plural backlog safe to adopt. It is wired into `/oj:health-check` as a probe, where exit 1 is reported as DEGRADED rather than FAIL - the plugin is working correctly and reporting a defect in the *project's* state, and the report must keep that distinction visible.

**Verification**: `scripts/tests/oj-helper-hook-test.sh` scenario S17 covers the single-file path, the empty-backlog path, plural listing via `backlog-glob`, all three defect classes, the multi-pattern + globstar case, and three falsifiers that matter: a prose mention is not a definition, a non-matching glob emits nothing rather than the literal pattern, and shell options do not leak to the caller.

### Dispatcher

At the end of the script, implement the dispatcher:

```bash
# ────────────────────────────────────────────────────────────────────
# Dispatcher
# ────────────────────────────────────────────────────────────────────

case "${1:-}" in
  inject-profile)      shift; cmd_inject_profile "$@" ;;
  conductor-inject)    shift; cmd_conductor_inject "$@" ;;
  migrate-legacy)      shift; cmd_migrate_legacy "$@" ;;
  feedback-path)       shift; cmd_feedback_path "$@" ;;
  resolve-path)        shift; cmd_resolve_path "$@" ;;
  backlog-list)        shift; cmd_backlog_list "$@" ;;
  backlog-lint)        shift; cmd_backlog_lint "$@" ;;
  install-hooks)       shift; cmd_install_hooks "$@" ;;
  issue-tracker-check)       shift; cmd_issue_tracker_check "$@" ;;
  issue-tracker-list)        shift; cmd_issue_tracker_list "$@" ;;
  issue-tracker-create)      shift; cmd_issue_tracker_create "$@" ;;
  issue-tracker-view)        shift; cmd_issue_tracker_view "$@" ;;
  issue-tracker-transition)  shift; cmd_issue_tracker_transition "$@" ;;
  issue-tracker-comment)     shift; cmd_issue_tracker_comment "$@" ;;
  issue-tracker-link-list)   shift; cmd_issue_tracker_link_list "$@" ;;
  agent-teams-check)         shift; cmd_agent_teams_check "$@" ;;
  workstream-new)            shift; cmd_workstream_new "$@" ;;
  help|--help|-h|"")
    cat <<'EOF'
oj-helper — dispatcher for OpenJunto utility subcommands

USAGE:
  oj-helper <subcommand> [args...]

SUBCOMMANDS:
  inject-profile       Inject expert profile into spawned sub-agents (SubagentStart hook)
  conductor-inject     Inject CONDUCTOR.md at session start (SessionStart hook)
  migrate-legacy       Detect Makefile-era install and write migration sentinels
  feedback-path        Output feedback file path for dev mode (OJ_DEVMODE=1)
  resolve-path         Echo the canonical path for a state key
                       state:    session|backlog|artifacts|state-dir|config|retros
                       category: decisions|facts|open-questions|requirements|design|plan
                       (category keys need layout=hierarchy in .claude/oj-paths.env; exit 3 if unset)
                       override-only: id-index
  backlog-list         List every backlog file, one absolute path per line (honors backlog-glob=)
  backlog-lint         Check the backlog set for duplicate anchors, duplicate ids, cross-file id collisions
  install-hooks        Set core.hooksPath to .githooks in current repo (opt-in)

  issue-tracker-check        Validate issue tracker prerequisites and discover project
  issue-tracker-list         List open issues
  issue-tracker-create       Create an issue
  issue-tracker-view         View issue details
  issue-tracker-transition   Change issue state (open/closed)
  issue-tracker-comment      Add comment to issue
  issue-tracker-link-list    List cross-references for an issue

  agent-teams-check          Probe agent-teams capability (Convene substrate); always exits 0

  workstream-new             Scaffold a parallel-workstream directory (git worktree + linked shared .claude/ state)

  help                 Show this help message

ENVIRONMENT:
  OJ_HOOK_DEBUG=1              Enable debug output to stderr (legacy JUNTO_HOOK_DEBUG accepted)
  OJ_DEVMODE=1                 Enable dev mode feedback collection (legacy JUNTO_DEVMODE accepted)
  ISSUE_TRACKER_PROJECT=KEY    Default project (owner/repo for GitHub)

EXAMPLES:
  oj-helper issue-tracker-check
  oj-helper issue-tracker-list --limit 20
  oj-helper feedback-path
EOF
    ;;
  *)
    die "Unknown subcommand: ${1:-}. Run 'oj-helper help' for usage."
    ;;
esac
```

## Format Requirements

The script must:
1. Be executable bash with shebang `#!/usr/bin/env bash`
2. Use consistent function naming: `cmd_*` for subcommands, `tracker_*` for helpers
3. Use consistent comment headers with horizontal rules: `# ────────────────────────────────────────────────────────────────────`
4. Use `debug()` for diagnostic output (stderr, controlled by `OJ_HOOK_DEBUG=1` with legacy `JUNTO_HOOK_DEBUG` fallback)
5. Use `die()` for fatal errors (stderr, exit 1)
6. Implement graceful degradation (exit 0 with no output when tools missing)
7. Use `local` for all function-scoped variables
8. Use `[[ ]]` for conditionals (not `[ ]`)
9. Use `${VAR:-default}` for variable defaults
10. Quote all variable expansions except in arithmetic contexts

## Verification

After generation, verify the script:

1. **Shebang**: Present and correct (`#!/usr/bin/env bash`)
2. **Core conventions**: `set -euo pipefail`, `debug()`, `die()` functions present
3. **Contracts sourced**: header contains `source "${_OJ_SCRIPT_DIR}/lib/contracts.sh"` (die-on-fail). Verify with: `grep -E "source.*contracts\.sh" bin/oj-helper` → ≥1 hit.
4. **All 15 specced subcommand functions present (exact count restored)**: each of the 15 functions in the MANDATORY enumeration MUST be present, and the count is now exact again - every shipped `^cmd_` subcommand is specced, so `grep -cE "^cmd_" bin/oj-helper` MUST return exactly `15` (a regen that adds a new `cmd_` or drops one of the 15 fails this check). Keep the name-based spot-checks for the easily-missed:
   - `grep -E "^cmd_conductor_inject\(\)" bin/oj-helper` → 1 hit
   - `grep -E "^cmd_migrate_legacy\(\)" bin/oj-helper` → 1 hit
   - `grep -E "^cmd_agent_teams_check\(\)" bin/oj-helper` → 1 hit (Convene-fallback probe; missing → Complex tier breaks when env var is unset)
   - `grep -E "^cmd_workstream_new\(\)" bin/oj-helper` → 1 hit (parallel-workstream scaffolding; missing → the workstream-new skill's dispatcher branch dies with "Unknown subcommand")
   - `grep -E "^cmd_install_hooks\(\)" bin/oj-helper` → 1 hit (opt-in .githooks installer)
   - `grep -E "^cmd_resolve_path\(\)" bin/oj-helper` → 1 hit (canonical state-path resolver; hot path for cycle / run-task / save-session / spec / backlog-compact, so a missing branch silently breaks per-project state layout)
5. **Pinned-string reference**: `grep "OJ_STDERR_CONDUCTOR_MISSING" bin/oj-helper` → ≥1 hit (used in `cmd_conductor_inject`).
5a. **Version banner**: `cmd_conductor_inject` emits `OpenJunto v<version> active — OpenJunto coordination system` to stderr on every path, sourcing the version from `_oj_plugin_version`. Verify the banner string and that it is stderr-only:
   - `grep -F 'active — OpenJunto coordination system' bin/oj-helper` → ≥1 hit
   - `grep -E '^_oj_plugin_version\(\)' bin/oj-helper` → 1 hit (shared helper defined)
   - Runtime: `CLAUDE_PLUGIN_ROOT=<plugin> bin/oj-helper conductor-inject 2>/dev/null | jq -e .` succeeds (stdout is pure JSON, no banner leakage) AND the banner appears when stderr is captured.
6. **Argument parsing**: Each subcommand correctly parses flags with `while [[ $# -gt 0 ]]` loop
7. **Error handling**: Calls `die()` on missing required flags or invalid input
8. **Graceful degradation**: inject-profile and conductor-inject exit 0 (with valid JSON envelope where applicable) when jq missing, transcript unavailable, profile not found, or CONDUCTOR.md missing
8a. **inject-profile relocated paths (Item 5)**: preamble read from `${PLUGIN_BASE}/reference/expert-preamble.md` (NOT `agents/_preamble.md`); full profile from `${PLUGIN_BASE}/agents/<name>.md`; compact fallback from `${PLUGIN_BASE}/reference/compact/<name>.md` (NOT the nonexistent `agents/compact/<name>.md`). Verify with `grep -F 'reference/expert-preamble.md' bin/oj-helper` → ≥1 hit and `grep -F 'reference/compact/' bin/oj-helper` → ≥1 hit; and `grep -F 'agents/compact/' bin/oj-helper` → 0 hits (the latent bug is gone).
8b. **Frontmatter stripping (Item 4)**: inject-profile strips the leading YAML frontmatter block from the full profile before building `additionalContext` (frontmatter starting on line 1 only; body horizontal rules survive). Runtime: injecting a full profile does NOT leak its frontmatter — `name:`, `description:`, or any spawn-configuration key — into `additionalContext`.
9. **JSON output**: issue-tracker-check, issue-tracker-list, conductor-inject output valid JSON
10. **Debug output**: debug() calls use descriptive messages, write to stderr
11. **Dispatcher**: Complete case statement listing ALL 15 specced subcommands + the `help` branch. Every `command` field in the static-emitted `hooks/hooks.json` (`conductor-inject`, `migrate-legacy`, `inject-profile`) MUST have a corresponding case-branch in the dispatcher. A regression-class check: for every `oj-helper <name>` invocation in `hooks/hooks.json`, `bin/oj-helper` MUST contain both a case-branch `<name>)` AND a function `cmd_<name_underscored>(`.
12. **Syntax-clean**: `bash -n bin/oj-helper` → exit 0.
13. **Executable**: Script is executable (`chmod +x`)

## Dependencies

- **Step 00**: `platform-snapshot.yaml` must be available (for SubagentStart hook matcher used in inject-profile agent type filter)
- **Step 02** (preamble/index) must be complete — inject-profile reads the preamble from `reference/expert-preamble.md`
- **Step 03** (agent profiles) must be complete — inject-profile reads full profiles from `agents/<name>.md` (whose frontmatter it strips) and compact fallbacks from `reference/compact/<name>.md`
- **Step 04** (reference files) must be complete — inject-profile references profile paths
- **Step 05** (templates) must be complete — feedback file format matches template structure
- **Step 06** (commands) must be complete — commands invoke oj-helper subcommands

---

## § 16 — `model-policy`

Echo the **effective** model policy as a single JSON object on stdout.

```
oj-helper model-policy [--workspace PATH]
oj-helper model-policy --check <api-id> [--workspace PATH]
```

**Why this subcommand exists.** `platform.model_policy` in `platform-defaults.yaml` is a *generation-time* input: nothing dereferences that YAML while a session runs, and the installed copy is a read-only marketplace cache that `/plugin` replaces on upgrade. So the file cannot be where an operator expresses policy. This subcommand is the runtime read path, and `<root>/.claude/oj-model-policy.env` is the write path - in the adopter's own repo, surviving upgrades.

**Why the shipped lists are empty.** The generated `platform-defaults.yaml` MUST emit `allowed_models: []` and `denied_models: []`. The plugin is installed by third parties; naming a model in the shipped defaults would impose one organization's procurement policy on every adopter, which Axiom 7 forbids. The knob is generic - every org has some model policy - but any value in it is org-specific. Generation MUST NOT bake a non-empty list in, and step-00's checklist asserts the lists are empty.

**Resolution order** (identical in shape to §15 `resolve-path`):
1. Workspace root from `--workspace`, else `$OJ_STATE_ROOT` (tolerating a trailing `/.claude` or `/.claude/local`), else the nearest ancestor containing `.claude/`, else `$PWD`.
2. Shipped defaults: `default_model=opus`, empty allow/deny lists, `min_effort_tier=routine`. These are literals in the script, deliberately NOT parsed from the YAML - parsing it would imply a runtime dereference that does not happen.
3. `<root>/.claude/oj-model-policy.env`, if present, overrides any of `default_model`, `allowed_models`, `denied_models`, `min_effort_tier`. Comma-separated lists. Last assignment wins, matching `resolve-path`'s `tail -n1` behavior.

**Output**: `{"default_model":..., "allowed_models":[...], "denied_models":[...], "min_effort_tier":..., "source":...}` where `source` is `plugin-defaults` or the absolute override path, so a caller can tell whether policy was configured or defaulted.

**`--check <api-id>`**: exits `0` when the model is permitted, `1` when denied, and emits `{"model":..., "permitted":bool, "reason":..., "source":...}`. **Denied wins over allowed** - a deny-list is a prohibition, not a preference, so a model in both lists is denied. An empty `allowed_models` means "no allowlist", not "nothing allowed".

**Exit code**: the plain form always exits `0` (Axiom 8 - never block on the probe itself). Only `--check` uses a non-zero exit, and it signals a policy verdict, not a failure.
