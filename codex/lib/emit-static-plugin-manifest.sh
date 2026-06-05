#!/usr/bin/env bash
#
# emit-static-plugin-manifest.sh — Codex platform static-manifest emitter.
#
# PURPOSE: Emit the deterministic DATA-class files that the Codex plugin host
# loads at install time: .codex-plugin/plugin.json, marketplace.json,
# hooks/hooks.json, bin/lib/contracts.sh, and platform-defaults.yaml.
# Re-emitting on the same inputs produces byte-identical output (output_classes:
# data, per juntospec/platform-contract.yaml).
#
# This is the Codex sibling of juntogen/claude/lib/emit-static-plugin-manifest.sh.
# The Codex plugin layout is near-identical to the Claude layout; the deltas are:
#   .claude-plugin/        -> .codex-plugin/
#   ${CLAUDE_PLUGIN_ROOT}  -> ${PLUGIN_ROOT}
#   hooks SubagentStart matcher "general-purpose" -> "" ([VERIFY]; Codex subagents
#                                                     are named, not a single agent class)
#   repository/homepage    -> openjunto/oj-codex
# Codex auto-detects ./hooks/hooks.json with no manifest entry, exactly like Claude.
#
# USAGE:
#   . emit-static-plugin-manifest.sh
#   emit_plugin_json <output_dir> <version>
#   emit_marketplace_json <output_dir>
#   emit_hooks_json <output_dir>
#   emit_contracts_sh <output_dir>
#   emit_platform_defaults <output_dir>
#
# STANDALONE:
#   bash emit-static-plugin-manifest.sh --all <output_dir> <version>

set -euo pipefail

_eatpm_die() {
    echo "ERROR: emit-static-plugin-manifest(codex): $*" >&2
    exit 1
}

# emit_plugin_json <output_dir> <version>
#
# Writes <output_dir>/.codex-plugin/plugin.json. The Codex plugin manifest lives
# in .codex-plugin/ (only plugin.json belongs there; skills/, hooks/, .mcp.json
# stay at the plugin root).
emit_plugin_json() {
    local output_dir="${1:-}"
    local version="${2:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_plugin_json requires output_dir"
    [ -n "${version}" ]    || _eatpm_die "emit_plugin_json requires version"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local plugin_dir="${output_dir}/.codex-plugin"
    mkdir -p "${plugin_dir}"

    command -v jq >/dev/null 2>&1 || _eatpm_die "jq required (install: brew install jq)"

    # [VERIFY] Confirm the exact required-field set of the Codex plugin.json schema
    # against developers.openai.com/codex/plugins/build. The shape below mirrors the
    # Claude manifest (name/version/description/author/license/repository/homepage/
    # keywords), which Codex's manifest is documented to closely parallel.
    # name MUST be kebab-case. skills/hooks reference bundled components per the
    # documented manifest schema (developers.openai.com/codex/plugins/build):
    #   "skills": "./skills/"        — bundled Agent Skills directory
    #   "hooks":  "./hooks/hooks.json" — lifecycle hooks (also auto-detected at the
    #                                    default path, but declared here for explicitness)
    # NOTE: agent definitions (.codex/agents/*.toml) are NOT a bundled plugin component —
    # Codex discovers agents only from ~/.codex/agents or <repo>/.codex/agents, so they
    # require an install step (see ROADMAP). They are intentionally not referenced here.
    cat > "${plugin_dir}/plugin.json" <<EOF
{
  "name": "oj",
  "version": "${version}",
  "description": "Mandatory adversarial review for Codex CLI — 16 expert subagents that push back",
  "author": {"name": "OpenJunto authors"},
  "license": "MIT",
  "repository": "https://github.com/openjunto/oj-codex",
  "homepage": "https://github.com/openjunto/oj-codex",
  "keywords": ["openjunto", "coordination", "multi-agent", "deliberation", "codex"],
  "skills": "./skills/",
  "hooks": "./hooks/hooks.json"
}
EOF

    jq -e . "${plugin_dir}/plugin.json" >/dev/null 2>&1 \
        || _eatpm_die "emit_plugin_json produced invalid JSON at ${plugin_dir}/plugin.json"

    echo "wrote: ${plugin_dir}/plugin.json (version=${version})"
}

# emit_marketplace_json <output_dir>
#
# Writes <output_dir>/.codex-plugin/marketplace.json — the single-plugin
# marketplace manifest. Codex supports `codex plugin marketplace add <path>`
# then `codex plugin install oj@openjunto`, mirroring the Claude flow.
# [VERIFY] Confirm the Codex marketplace.json schema (owner/plugins keys) against
# developers.openai.com/codex/plugins; shape below mirrors the Claude marketplace.
emit_marketplace_json() {
    local output_dir="${1:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_marketplace_json requires output_dir"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local plugin_dir="${output_dir}/.codex-plugin"
    mkdir -p "${plugin_dir}"

    command -v jq >/dev/null 2>&1 || _eatpm_die "jq required (install: brew install jq)"

    cat > "${plugin_dir}/marketplace.json" <<'EOF'
{
  "name": "openjunto",
  "owner": {
    "name": "openjunto"
  },
  "plugins": [
    { "name": "oj", "source": "./" }
  ]
}
EOF

    jq -e . "${plugin_dir}/marketplace.json" >/dev/null 2>&1 \
        || _eatpm_die "emit_marketplace_json produced invalid JSON at ${plugin_dir}/marketplace.json"

    echo "wrote: ${plugin_dir}/marketplace.json"
}

# emit_hooks_json <output_dir>
#
# Writes <output_dir>/hooks/hooks.json. Codex auto-detects this default path with
# no manifest entry. The hook JSON contract (matcher + hooks[] + {type,command,timeout})
# and the additionalContext injection mechanism match Claude Code's, so oj-helper's
# conductor-inject / inject-profile subcommands port directly.
#
#   SessionStart matcher="" : conductor-inject (loads CONDUCTOR.md) + migrate-legacy
#   SubagentStart matcher="": inject-profile (PRIMARY Onboard path — plugin-bundleable; native
#                             .codex/agents/*.toml are an enhancement installed by bootstrap.sh)
emit_hooks_json() {
    local output_dir="${1:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_hooks_json requires output_dir"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local hooks_dir="${output_dir}/hooks"
    mkdir -p "${hooks_dir}"

    command -v jq >/dev/null 2>&1 || _eatpm_die "jq required (install: brew install jq)"

    # [VERIFY] SubagentStart matcher value for Codex named subagents (using "" = all).
    jq -n '{
        description: "OpenJunto coordination hooks",
        hooks: {
            SessionStart: [
                {
                    matcher: "",
                    hooks: [
                        {
                            type: "command",
                            command: "${PLUGIN_ROOT}/bin/oj-helper conductor-inject",
                            timeout: 5
                        },
                        {
                            type: "command",
                            command: "${PLUGIN_ROOT}/bin/oj-helper migrate-legacy",
                            timeout: 5
                        }
                    ]
                }
            ],
            SubagentStart: [
                {
                    matcher: "",
                    hooks: [
                        {
                            type: "command",
                            command: "${PLUGIN_ROOT}/bin/oj-helper inject-profile",
                            timeout: 5
                        }
                    ]
                }
            ]
        }
    }' > "${hooks_dir}/hooks.json"

    echo "wrote: ${hooks_dir}/hooks.json"
}

# emit_contracts_sh <output_dir>
#
# Writes <output_dir>/bin/lib/contracts.sh. Platform-agnostic: the pinned advisory
# is about CONDUCTOR.md, which OpenJunto ships on Codex too — reused verbatim from
# the Claude baseline so the helper + test harness share one source of truth.
emit_contracts_sh() {
    local output_dir="${1:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_contracts_sh requires output_dir"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local lib_dir="${output_dir}/bin/lib"
    mkdir -p "${lib_dir}"

    cat > "${lib_dir}/contracts.sh" <<'EOF'
#!/usr/bin/env bash
# contracts.sh — pinned-string CONTRACTS shared between oj-helper and tests.
#
# Each constant below is a CONTRACT: it appears in user-visible output AND is
# pattern-matched by the test harness, the structural validator, and the
# /oj:health-check skill. Edits MUST be coordinated:
#
#   1. Update the constant here.
#   2. Run scripts/validate-plugin.sh (drift canary greps bin/oj-helper for the
#      literal — fails loudly if the helper has not been updated).
#   3. Run scripts/tests/oj-helper-hook-test.sh + plugin-validate-test.sh.
#
# This file is sourced (not executed). It must remain side-effect-free at the
# top level: declare constants only.

# ────────────────────────────────────────────────────────────────────
# OJ_STDERR_CONDUCTOR_MISSING
# ────────────────────────────────────────────────────────────────────
# Stable stderr advisory emitted by `oj-helper conductor-inject` when
# CONDUCTOR.md is absent or unreadable. The em-dash is intentional.
readonly OJ_STDERR_CONDUCTOR_MISSING="OpenJunto: CONDUCTOR.md missing — manager protocol will not be injected this session"
EOF

    echo "wrote: ${lib_dir}/contracts.sh"
}

# emit_platform_defaults <output_dir>
#
# Byte-exact copy of the Codex platform-defaults.yaml source-of-truth
# (juntogen/codex/platform-defaults.yaml) into the generated plugin tree.
emit_platform_defaults() {
    local output_dir="${1:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_platform_defaults requires output_dir"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local source_file="${script_dir}/../platform-defaults.yaml"

    [ -f "${source_file}" ] \
        || _eatpm_die "emit_platform_defaults: source not found: ${source_file}"

    cat "${source_file}" > "${output_dir}/platform-defaults.yaml"

    echo "wrote: ${output_dir}/platform-defaults.yaml"
}

# emit_bootstrap <output_dir>
#
# Writes <output_dir>/bootstrap.sh — the installer for the bits Codex does NOT
# auto-discover from a plugin (resolved [VERIFY] findings):
#   1) native subagent definitions (.codex/agents/*.toml) — Codex loads agents only
#      from ~/.codex/agents or <repo>/.codex/agents, never from a plugin bundle.
#   2) lifecycle hooks — plugin-bundled hooks/hooks.json is not yet reliably loaded by
#      the Codex runtime (openai/codex#16430, #17331), so merge into ~/.codex/hooks.json
#      with ${PLUGIN_ROOT} resolved to the absolute plugin path. oj-helper then finds
#      CONDUCTOR.md via PLUGIN_ROOT or its script-relative fallback.
# DATA-class: deterministic template.
emit_bootstrap() {
    local output_dir="${1:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_bootstrap requires output_dir"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    cat > "${output_dir}/bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
# bootstrap.sh — install oj-codex components Codex does not auto-discover from a plugin.
#
#   1) native subagent definitions  .codex/agents/*.toml -> $CODEX_HOME/agents/
#   2) lifecycle hooks              hooks/hooks.json      -> $CODEX_HOME/hooks.json (merged)
#
# Codex discovers agents only from ~/.codex/agents (or <repo>/.codex/agents), and
# plugin-bundled hooks are not yet reliably loaded by the runtime — so we install both
# into $CODEX_HOME directly. Re-running replaces oj-* agents and de-dups hook entries.
set -euo pipefail
PLUGIN_ROOT="$(cd "$(dirname "$0")" && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$CODEX_HOME/agents"

# 1) agent definitions
n=0
for t in "$PLUGIN_ROOT"/.codex/agents/*.toml; do
  [ -e "$t" ] || continue
  cp -f "$t" "$CODEX_HOME/agents/"; n=$((n+1))
done
echo "oj-codex: installed $n agent definition(s) -> $CODEX_HOME/agents/"

# 2) hooks — merge with the absolute plugin path substituted for ${PLUGIN_ROOT}
if command -v jq >/dev/null 2>&1; then
  dst="$CODEX_HOME/hooks.json"
  [ -f "$dst" ] || echo '{"hooks":{}}' > "$dst"
  tmp="$(mktemp)"
  sed "s#\${PLUGIN_ROOT}#${PLUGIN_ROOT}#g" "$PLUGIN_ROOT/hooks/hooks.json" > "$tmp"
  # Deep-merge SessionStart/SubagentStart arrays, then de-dup by command so re-runs are idempotent.
  jq -s '
    def merge_event($d;$s;$k): ($d[$k] // []) + ($s[$k] // []) | unique_by(.hooks[0].command // tostring);
    .[0] as $d | .[1] as $s
    | $d * {hooks: ($d.hooks + $s.hooks
        + {SessionStart: merge_event($d.hooks;$s.hooks;"SessionStart"),
           SubagentStart: merge_event($d.hooks;$s.hooks;"SubagentStart")})}
  ' "$dst" "$tmp" > "$dst.new" && mv "$dst.new" "$dst"
  rm -f "$tmp"
  echo "oj-codex: merged hooks -> $dst"
else
  echo "oj-codex: jq not found — add $PLUGIN_ROOT/hooks/hooks.json to $CODEX_HOME/hooks.json manually." >&2
fi

echo "oj-codex: done. Restart Codex; run '/hooks' to confirm, and '/agent' to use the experts."
EOF
    chmod +x "${output_dir}/bootstrap.sh" 2>/dev/null || true
    echo "wrote: ${output_dir}/bootstrap.sh"
}

# Standalone dispatch.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-}" in
        --plugin-json)        shift; emit_plugin_json "$@" ;;
        --marketplace-json)   shift; emit_marketplace_json "$@" ;;
        --hooks-json)         shift; emit_hooks_json "$@" ;;
        --contracts-sh)       shift; emit_contracts_sh "$@" ;;
        --platform-defaults)  shift; emit_platform_defaults "$@" ;;
        --bootstrap)          shift; emit_bootstrap "$@" ;;
        --all)
            shift
            output_dir="${1:-}"
            version="${2:-}"
            [ -n "${output_dir}" ] || _eatpm_die "--all requires output_dir as 1st arg"
            [ -n "${version}" ]    || _eatpm_die "--all requires version as 2nd arg"
            emit_plugin_json "${output_dir}" "${version}"
            emit_marketplace_json "${output_dir}"
            emit_hooks_json "${output_dir}"
            emit_contracts_sh "${output_dir}"
            emit_platform_defaults "${output_dir}"
            emit_bootstrap "${output_dir}"
            ;;
        -h|--help|"")
            cat <<EOF
USAGE:
    emit-static-plugin-manifest.sh --plugin-json        <output_dir> <version>
    emit-static-plugin-manifest.sh --marketplace-json   <output_dir>
    emit-static-plugin-manifest.sh --hooks-json         <output_dir>
    emit-static-plugin-manifest.sh --contracts-sh       <output_dir>
    emit-static-plugin-manifest.sh --platform-defaults  <output_dir>
    emit-static-plugin-manifest.sh --all                <output_dir> <version>

Codex sibling of juntogen/claude/lib/emit-static-plugin-manifest.sh. Emits
DATA-class plugin manifests into the oj-codex plugin tree.
EOF
            ;;
        *) _eatpm_die "unknown flag: $1 (try --help)" ;;
    esac
fi
