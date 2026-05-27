#!/usr/bin/env bash
#
# emit-static-plugin-manifest.sh — BL-025-m.1 Deliverable 5
#
# PURPOSE: Emit the two static manifest files that the Claude plugin host
# loads at install time: .claude-plugin/plugin.json and hooks/hooks.json.
# Both files are deterministic templates — re-emitting on the same inputs
# produces byte-identical output. They belong to the DATA output class
# (per platform-contract.yaml output_classes), so the layered convergence
# gate (BL-025-m.3) will byte-diff them against the frozen snapshot.
#
# RATIONALE (BL-025-m TENSION-A adjudication): plugin.json is a 9-key
# static structure (name/version/description/author/license/repository/
# homepage/keywords); hooks.json is 2 SessionStart handlers + 1
# SubagentStart matcher. Neither needs LLM creativity. Routing them
# through a generation step trades determinism for an entire turn budget
# AND introduces non-deterministic DATA (defeats output-class invariant).
# Step-08 (Makefile installer) deleted; this helper now emits the plugin-
# host manifests directly from step-07 alongside the LLM-generated
# bin/oj-helper.
#
# DESIGN:
#   - Two functions, sourceable by step-07's verify path (and by m.2's
#     prompt-driven invocation, once rewired).
#   - Reference shapes: oj-claude/.claude-plugin/plugin.json and
#     oj-claude/hooks/hooks.json (the canonical hand-cut baseline).
#   - jq used for clean indented JSON output (8/0 PASS on validate-plugin).
#   - VERSION is read from juntospec/VERSION (m.1 ships at 0.0.1).
#     Fallback path: oj-claude/VERSION (kept in lockstep until juntogen
#     owns the source-of-truth in m.3).
#
# USAGE:
#   . emit-static-plugin-manifest.sh
#   emit_plugin_json <output_dir> <version>
#   emit_hooks_json <output_dir>
#
# STANDALONE:
#   bash emit-static-plugin-manifest.sh --plugin-json <output_dir> <version>
#   bash emit-static-plugin-manifest.sh --hooks-json <output_dir>
#
# Wiring into step-07 is m.2 mechanical work (synthesis Deliverable 5
# note). For m.1 the functions exist with unit-testable signatures; the
# step-07 invocation is deferred so the spike (Deliverable 9) can run
# the dry-run pipeline without depending on the wiring.

set -euo pipefail

# Internal: die with message on stderr, exit 1.
_eatpm_die() {
    echo "ERROR: emit-static-plugin-manifest: $*" >&2
    exit 1
}

# emit_plugin_json <output_dir> <version>
#
# Writes <output_dir>/.claude-plugin/plugin.json with the 9-key static
# template. The plugin host requires name+version+description for valid
# loading; the remaining keys (author, license, repository, homepage,
# keywords) are emitted unconditionally so this function always produces
# the canonical shape.
#
# Idempotency: same inputs => byte-identical output (jq deterministic
# pretty-print + fixed key order).
emit_plugin_json() {
    local output_dir="${1:-}"
    local version="${2:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_plugin_json requires output_dir"
    [ -n "${version}" ]    || _eatpm_die "emit_plugin_json requires version"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local plugin_dir="${output_dir}/.claude-plugin"
    mkdir -p "${plugin_dir}"

    # Canonical static template — mirrors oj-claude/.claude-plugin/plugin.json
    # at the BL-025-m.1 hand-cut baseline.
    # name="oj" (required by validate-plugin C2).
    # author / license / repository / homepage / keywords are static.
    command -v jq >/dev/null 2>&1 || _eatpm_die "jq required (install: brew install jq)"

    # Byte-exact match to oj-claude/.claude-plugin/plugin.json (hand-cut
    # baseline). Author/keywords on single inline lines — jq's default
    # multi-line output would diff against the hand-cut and break the
    # m.3 byte-diff gate. We write the file as a heredoc with the version
    # substituted; correctness validated by validate-plugin.sh:C2 (jq parse +
    # required-field check).
    #
    # Description string: matches the live oj-claude baseline. This is the
    # adopter-facing one-liner shown by the plugin host; it stays in lockstep
    # with oj-claude/.claude-plugin/plugin.json under the m.2 byte-diff gate.
    cat > "${plugin_dir}/plugin.json" <<EOF
{
  "name": "oj",
  "version": "${version}",
  "description": "Mandatory adversarial review for Claude Code — 16 expert sub-agents that push back",
  "author": {"name": "OpenJunto authors"},
  "license": "MIT",
  "repository": "https://github.com/openjunto/oj-claude",
  "homepage": "https://github.com/openjunto/oj-claude",
  "keywords": ["openjunto", "coordination", "multi-agent", "deliberation"]
}
EOF

    # Parse sanity (jq must accept the file). Catches accidental edits that
    # break JSON.
    jq -e . "${plugin_dir}/plugin.json" >/dev/null 2>&1 \
        || _eatpm_die "emit_plugin_json produced invalid JSON at ${plugin_dir}/plugin.json"

    echo "wrote: ${plugin_dir}/plugin.json (version=${version})"
}

# emit_marketplace_json <output_dir>
#
# Writes <output_dir>/.claude-plugin/marketplace.json — the single-plugin
# marketplace manifest that turns a plugin repo into a self-installable
# local marketplace. With this file in place, adopters can run
#   git clone <repo> /path/to/oj-claude
#   claude plugin marketplace add /path/to/oj-claude
#   claude plugin install oj@openjunto --scope user
# without hand-crafting any intermediate manifest.
#
# Reference shape: minimal valid single-plugin marketplace. The `owner.name`
# field is required by the marketplace schema (validated at
# `claude plugin marketplace add` time — its absence triggers a Zod-style
# "owner: Invalid input: expected object, received undefined" error).
#
# This file is DATA-class: deterministic, no LLM creativity needed.
# Re-emitting on the same inputs produces byte-identical output.
#
# Note: the marketplace `name` ("openjunto") is the namespace adopters
# reference at install time (`claude plugin install oj@openjunto`); the
# plugin `name` ("oj") matches the value in plugin.json.
emit_marketplace_json() {
    local output_dir="${1:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_marketplace_json requires output_dir"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local plugin_dir="${output_dir}/.claude-plugin"
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

    # Parse sanity (jq must accept the file). Catches accidental edits that
    # break JSON.
    jq -e . "${plugin_dir}/marketplace.json" >/dev/null 2>&1 \
        || _eatpm_die "emit_marketplace_json produced invalid JSON at ${plugin_dir}/marketplace.json"

    echo "wrote: ${plugin_dir}/marketplace.json"
}

# emit_hooks_json <output_dir>
#
# Writes <output_dir>/hooks/hooks.json with the deterministic 2-handler
# SessionStart + 1-matcher SubagentStart structure. Reference shape:
# oj-claude/hooks/hooks.json at the BL-025-m.1 hand-cut baseline.
#
# Hook commands assume the plugin host expands ${CLAUDE_PLUGIN_ROOT} to
# the install root at hook-invocation time (validate-plugin C3 enforces
# the substitution sanity).
emit_hooks_json() {
    local output_dir="${1:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_hooks_json requires output_dir"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local hooks_dir="${output_dir}/hooks"
    mkdir -p "${hooks_dir}"

    command -v jq >/dev/null 2>&1 || _eatpm_die "jq required (install: brew install jq)"

    # Canonical static template:
    #   SessionStart matcher="" with two command handlers:
    #     - conductor-inject  (loads CONDUCTOR.md into session)
    #     - migrate-legacy    (detects legacy .junto-* dotfiles on first run)
    #   SubagentStart matcher="general-purpose" with one command handler:
    #     - inject-profile    (injects expert profile per oj-expert: marker)
    #
    # Timeout 5s for each hook — matches the hand-cut baseline.
    jq -n '{
        description: "OpenJunto coordination hooks",
        hooks: {
            SessionStart: [
                {
                    matcher: "",
                    hooks: [
                        {
                            type: "command",
                            command: "${CLAUDE_PLUGIN_ROOT}/bin/oj-helper conductor-inject",
                            timeout: 5
                        },
                        {
                            type: "command",
                            command: "${CLAUDE_PLUGIN_ROOT}/bin/oj-helper migrate-legacy",
                            timeout: 5
                        }
                    ]
                }
            ],
            SubagentStart: [
                {
                    matcher: "general-purpose",
                    hooks: [
                        {
                            type: "command",
                            command: "${CLAUDE_PLUGIN_ROOT}/bin/oj-helper inject-profile",
                            timeout: 5
                        }
                    ]
                }
            ]
        }
    }' > "${hooks_dir}/hooks.json"

    echo "wrote: ${hooks_dir}/hooks.json"
}

# emit_platform_defaults <output_dir>
#
# Writes <output_dir>/platform-defaults.yaml — the curated offline fallback
# representing the current Claude Code platform. The file is DATA-class
# (per platform-contract.yaml output_classes): the YAML is a structural
# template used by Step 00 of the generator and by the runtime when
# introspection is unavailable. Re-emitting on the same inputs produces
# byte-identical output.
#
# Source of truth: ${SCRIPT_DIR}/../platform-defaults.yaml
#                  (lives at juntogen/claude/platform-defaults.yaml).
# Reference shape: oj-claude/platform-defaults.yaml will land alongside
#                  this commit when the m.3 snapshot bump catalogs the file.
emit_platform_defaults() {
    local output_dir="${1:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_platform_defaults requires output_dir"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local source_file="${script_dir}/../platform-defaults.yaml"

    [ -f "${source_file}" ] \
        || _eatpm_die "emit_platform_defaults: source not found: ${source_file}"

    # Byte-exact copy from the canonical source-of-truth in juntogen/claude/.
    # cat (vs cp) keeps mode bits at the umask default and yields byte-
    # identical content regardless of source filesystem permissions.
    cat "${source_file}" > "${output_dir}/platform-defaults.yaml"

    echo "wrote: ${output_dir}/platform-defaults.yaml"
}

# emit_contracts_sh <output_dir>
#
# Writes <output_dir>/bin/lib/contracts.sh — a sourced (not executed)
# bash file declaring pinned-string CONTRACTS shared between oj-helper
# and the test harness. The file is DATA-class (per platform-contract.yaml
# output_classes): the constants are referenced literally by the test
# harness, the structural validator, and the /oj:health-check skill, so
# routing them through an LLM step would inject non-determinism into a
# strict identity invariant.
#
# Reference shape: oj-claude/bin/lib/contracts.sh at the BL-025-k synthesis
# baseline. Re-emitting on the same inputs produces byte-identical output.
#
# Coordination requirement (mirrors the live file's header comment):
#   1. Update the constant here.
#   2. Run scripts/validate-plugin.sh (drift canary C4 greps bin/oj-helper
#      for the literal — fails loudly if the helper has not been updated).
#   3. Run scripts/tests/oj-helper-hook-test.sh + plugin-validate-test.sh.
emit_contracts_sh() {
    local output_dir="${1:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_contracts_sh requires output_dir"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local lib_dir="${output_dir}/bin/lib"
    mkdir -p "${lib_dir}"

    # Canonical static template — mirrors oj-claude/bin/lib/contracts.sh
    # at the BL-025-k synthesis baseline. The em-dash in the advisory
    # string is intentional (matches the live string exactly).
    cat > "${lib_dir}/contracts.sh" <<'EOF'
#!/usr/bin/env bash
# contracts.sh — pinned-string CONTRACTS shared between oj-helper and tests.
#
# Each constant below is a CONTRACT: it appears in user-visible output AND is
# pattern-matched by the test harness, the structural validator, and the
# /oj:health-check skill. Edits MUST be coordinated:
#
#   1. Update the constant here.
#   2. Run scripts/validate-plugin.sh (drift canary C4 greps bin/oj-helper
#      for the literal — fails loudly if the helper has not been updated).
#   3. Run scripts/tests/oj-helper-hook-test.sh + plugin-validate-test.sh.
#
# This file is sourced (not executed). It must remain side-effect-free at
# the top level: declare constants only.
#
# Origin: BL-025-k synthesis 2026-05-11 (F5 — centralize pinned-string
# contract; both oj-helper AND tests source this; structural check C4
# greps bin/oj-helper for the literal as a drift canary).

# ────────────────────────────────────────────────────────────────────
# OJ_STDERR_CONDUCTOR_MISSING
# ────────────────────────────────────────────────────────────────────
# Stable stderr advisory emitted by `oj-helper conductor-inject` when
# CONDUCTOR.md is absent or unreadable. Health-check tooling and the
# oj-helper-hook-test harness pattern-match on this literal — DO NOT
# edit casually. The em-dash is intentional (matches the live string).
readonly OJ_STDERR_CONDUCTOR_MISSING="OpenJunto: CONDUCTOR.md missing — manager protocol will not be injected this session"
EOF

    echo "wrote: ${lib_dir}/contracts.sh"
}

# emit_plugin_scripts <output_dir>
#
# Copies the hand-cut plugin-side scripts/ directory into <output_dir>/scripts/.
# These are operator/CI-side validators and harnesses (validate-plugin.sh,
# plugin-validate-test.sh, oj-helper-hook-test.sh, plugin-e2e-test.sh, and
# their fixtures). They are NOT LLM-generated — they're infrastructure.
# Their source-of-truth lives at OJ_CLAUDE_DIR/scripts/, NOT in juntospec.
#
# Default OJ_CLAUDE_DIR resolution: ${SCRIPT_DIR}/../../oj-claude (sibling
# probe matching the spec-dir convention). Override with OJ_CLAUDE_DIR env.
#
# Re-emitting on the same inputs is byte-identical (cp -R preserves bytes).
# Intentionally NOT included in --all dispatch because the source path is
# brittle (depends on sibling-repo presence); the generator's static_artifacts_
# emit invokes it explicitly with the resolved path.
emit_plugin_scripts() {
    local output_dir="${1:-}"
    [ -n "${output_dir}" ] || _eatpm_die "emit_plugin_scripts requires output_dir"
    [ -d "${output_dir}" ] || mkdir -p "${output_dir}"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local default_oj_claude="${script_dir}/../../../oj-claude"
    local source_dir="${OJ_CLAUDE_DIR:-${default_oj_claude}}"

    [ -d "${source_dir}/scripts" ] \
        || _eatpm_die "emit_plugin_scripts: source not found: ${source_dir}/scripts (override via OJ_CLAUDE_DIR)"

    # Recursive copy preserving directory structure. Mode bits intentionally
    # left to the umask default; the only file requiring exec bit at copy
    # time is validate-plugin.sh, which the source already has set.
    rm -rf "${output_dir}/scripts"
    cp -R "${source_dir}/scripts" "${output_dir}/scripts"

    echo "wrote: ${output_dir}/scripts/ (copied from ${source_dir}/scripts)"
}

# Standalone invocation: `bash emit-static-plugin-manifest.sh --plugin-json ...`
# When sourced (default), the script exposes the three functions and exits 0
# implicitly. When invoked as a script, the dispatch below kicks in.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-}" in
        --plugin-json)
            shift
            emit_plugin_json "$@"
            ;;
        --hooks-json)
            shift
            emit_hooks_json "$@"
            ;;
        --contracts-sh)
            shift
            emit_contracts_sh "$@"
            ;;
        --platform-defaults)
            shift
            emit_platform_defaults "$@"
            ;;
        --plugin-scripts)
            shift
            emit_plugin_scripts "$@"
            ;;
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
            ;;
        --both)
            # Legacy alias for --all minus contracts.sh; retained for one
            # release of backward compatibility. New callers should use --all.
            shift
            output_dir="${1:-}"
            version="${2:-}"
            [ -n "${output_dir}" ] || _eatpm_die "--both requires output_dir as 1st arg"
            [ -n "${version}" ]    || _eatpm_die "--both requires version as 2nd arg"
            emit_plugin_json "${output_dir}" "${version}"
            emit_hooks_json "${output_dir}"
            ;;
        -h|--help|"")
            cat <<EOF
USAGE:
    emit-static-plugin-manifest.sh --plugin-json        <output_dir> <version>
    emit-static-plugin-manifest.sh --marketplace-json   <output_dir>
    emit-static-plugin-manifest.sh --hooks-json         <output_dir>
    emit-static-plugin-manifest.sh --contracts-sh       <output_dir>
    emit-static-plugin-manifest.sh --platform-defaults  <output_dir>
    emit-static-plugin-manifest.sh --plugin-scripts     <output_dir>  # OJ_CLAUDE_DIR-sourced
    emit-static-plugin-manifest.sh --all                <output_dir> <version>
    emit-static-plugin-manifest.sh --both               <output_dir> <version>  # legacy

When sourced, exposes emit_plugin_json(), emit_marketplace_json(),
emit_hooks_json(), emit_contracts_sh(), emit_platform_defaults(),
emit_plugin_scripts() functions.

The first four artifacts are DATA-class outputs (per platform-contract.yaml
output_classes); re-emitting on the same inputs produces byte-identical
output. Step-07 invokes these helpers after the LLM-generated bin/oj-helper
is written, via the generator's static_artifacts_emit dispatch hook.

emit_plugin_scripts() is intentionally separate: it copies hand-cut
plugin-side scripts (validate-plugin.sh, scripts/tests/*) from
\${OJ_CLAUDE_DIR:-../../oj-claude}/scripts/. Not included in --all
because the source path is brittle (sibling-repo dependency).
EOF
            ;;
        *)
            _eatpm_die "unknown flag: $1 (try --help)"
            ;;
    esac
fi
