#!/usr/bin/env bash
#
# structural-diff-test.sh — BL-025-m.1 negative-control harness for
# structural-diff.sh.
#
# PURPOSE: Lock detection branches of structural-diff.sh's Layer 4
#          (referential-integrity) against regressions. Each scenario
#          builds an isolated tempdir from the live plugin tree, plants a
#          targeted mutation, invokes structural-diff.sh, and asserts on
#          (exit code, structured-stderr substring presence/absence).
#
# WHY (Phase 3 adversarial finding — silent-coverage gap): the original L4
#   CONDUCTOR.md check greps for `@agents/...` but the live reference shape
#   is `${CLAUDE_PLUGIN_ROOT}/agents/...`. Zero matches meant L4 ALWAYS
#   passed regardless of input. The fix (multi-shape regex + backtick
#   anchoring + documentation-form skips) needs negative-control coverage
#   so future regressions surface, not hide.
#
# Scenarios:
#   1. live-tree-positive   — unmodified live tree                          -> exit 0
#   2. conductor-unresolved — Phase 3 reviewer's exact sed mutation         -> exit 1,
#                              referential-integrity-conductor-ref-unresolved
#   3. conditional-ref-skip — confirm "If `<path>` exists" prose is skipped
#                              (documentation pattern for optional refs)    -> exit 0
#   4. glob-pattern-skip    — `${CLAUDE_PLUGIN_ROOT}/agents/*-compact.md`
#                              is a glob, NOT a literal path                -> exit 0
#   5. l5-positive-emit-tree — emit-derived tree (NOT live tree); all 4
#                              DATA-class files have baseline-matching
#                              sha256                                       -> L5 PASS
#   6. l5-mutated-plugin-json — single-byte mutation in plugin.json after
#                              emit; L5 reports byte-diff-data-drift        -> L5 FAIL
#   7. l5-missing-data-file — delete one DATA file after emit; L5 reports
#                              byte-diff-data-drift                         -> L5 FAIL
#   8. l5-prose-mutation-ignored — mutate README.md after emit; L5 does
#                              NOT report it (PROSE-class is out of scope
#                              of byte-diff)                                -> L5 PASS
#
# Test isolation: each scenario copies the live oj-claude tree to its own
# tempdir, mutates only that copy, runs structural-diff.sh against it.
# Cleanup uses a single-arg `trap 'rm -rf "${TMPROOT}"' EXIT` (avoids the
# BL-025-e.2 cleanup-trap exit-code-leak bug).
#
# Exit codes:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error (missing dependency, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFF="${SCRIPT_DIR}/structural-diff.sh"
LIVE_TREE="${OJ_OUTPUT_DIR:-/Users/brenton/workspace/github.com/openjunto/oj-claude}"

if [ -t 1 ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[ -r "${DIFF}" ] || {
    echo "${RED}ERROR${NC} structural-diff.sh missing/unreadable: ${DIFF}" >&2
    exit 2
}
[ -d "${LIVE_TREE}" ] || {
    echo "${RED}ERROR${NC} live plugin tree missing: ${LIVE_TREE}" >&2
    exit 2
}
[ -d "${LIVE_TREE}/.git" ] || {
    echo "${RED}ERROR${NC} live plugin tree is not a git checkout (L1 file-set depends on git ls-files): ${LIVE_TREE}" >&2
    exit 2
}

PASS_COUNT=0
FAIL_COUNT=0

# Single cleanup root for all scenarios. Single-arg trap to avoid exit-code
# leak (BL-025-e.2 lesson). Scenarios create subdirs inside this root.
TMPROOT=$(mktemp -d -t structural-diff-test-XXXXXX)
trap 'rm -rf "${TMPROOT}"' EXIT

# Build an isolated copy of the live plugin tree inside TMPROOT.
# Args: $1 = scenario tag. Returns absolute path on stdout.
clone_live_tree() {
    local tag="$1"
    local td="${TMPROOT}/${tag}"
    mkdir -p "${td}"
    # Use cp -R to preserve symlinks/permissions. The .git directory must
    # come along because L1 uses `git ls-files`.
    cp -R "${LIVE_TREE}/." "${td}/"
    printf '%s' "${td}"
}

# Run structural-diff.sh, capture exit + stdout + stderr.
# $RUN_EXIT, $RUN_STDOUT, $RUN_STDERR set on return.
run_diff() {
    local tree="$1"
    local stdout_log stderr_log
    stdout_log=$(mktemp -p "${TMPROOT}" stdout-XXXXXX)
    stderr_log=$(mktemp -p "${TMPROOT}" stderr-XXXXXX)
    local rc=0
    bash "${DIFF}" "${tree}" >"${stdout_log}" 2>"${stderr_log}" || rc=$?
    RUN_EXIT="${rc}"
    RUN_STDOUT=$(cat "${stdout_log}")
    RUN_STDERR=$(cat "${stderr_log}")
    rm -f "${stdout_log}" "${stderr_log}"
}

# Assert: $RUN_EXIT matches expected; stderr contains/absents requested
# substrings.
# Usage: assert_pass <scenario> <expected_exit> [contains|absent|stdout_contains|stdout_absent] <needle> ...
assert_pass() {
    local scenario="$1" expected_exit="$2"
    local errors=""
    # expected_exit="any" — don't bind on exit; useful for L5-only assertions
    # where other layers may concurrently FAIL on synthetic trees.
    if [ "${expected_exit}" != "any" ] && [ "${RUN_EXIT}" != "${expected_exit}" ]; then
        errors="${errors}    expected exit=${expected_exit}, got ${RUN_EXIT}"$'\n'
    fi
    shift 2
    while [ $# -ge 2 ]; do
        local mode="$1"; local needle="$2"; shift 2
        case "${mode}" in
            contains)
                if ! printf '%s' "${RUN_STDERR}" | grep -qF -- "${needle}"; then
                    errors="${errors}    stderr missing required substring: ${needle}"$'\n'
                fi
                ;;
            absent)
                if printf '%s' "${RUN_STDERR}" | grep -qF -- "${needle}"; then
                    errors="${errors}    stderr unexpectedly contains: ${needle}"$'\n'
                fi
                ;;
            stdout_contains)
                if ! printf '%s' "${RUN_STDOUT}" | grep -qF -- "${needle}"; then
                    errors="${errors}    stdout missing required substring: ${needle}"$'\n'
                fi
                ;;
            stdout_absent)
                if printf '%s' "${RUN_STDOUT}" | grep -qF -- "${needle}"; then
                    errors="${errors}    stdout unexpectedly contains: ${needle}"$'\n'
                fi
                ;;
            *)
                errors="${errors}    INTERNAL: unknown assert mode: ${mode}"$'\n'
                ;;
        esac
    done
    if [ -z "${errors}" ]; then
        echo "${GREEN}PASS${NC} ${scenario}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "${RED}FAIL${NC} ${scenario}"
        printf '%s' "${errors}"
        echo "${CYAN}    actual exit=${RUN_EXIT}${NC}"
        echo "${CYAN}    actual stderr (head -20):${NC}"
        printf '%s\n' "${RUN_STDERR}" | head -20 | sed 's/^/      /'
        echo "${CYAN}    actual stdout (head -20):${NC}"
        printf '%s\n' "${RUN_STDOUT}" | head -20 | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ── Layer 5 prep (BL-025-m.3) ───────────────────────────────────────────
# All scenarios overlay v0.0.2 emit output onto the cloned live tree so
# L1 file-set (snapshot now lists platform-defaults.yaml) and L5 byte-diff
# (snapshot baseline expects v0.0.2 plugin.json sha256) both PASS by
# construction. Without the overlay, the live tree's v0.0.1 plugin.json
# would fail L5 and the missing platform-defaults.yaml would fail L1
# during the iteration window where oj-claude has not yet been regen'd.
HELPER_SH="${SCRIPT_DIR}/../../lib/emit-static-plugin-manifest.sh"
BASELINE_VERSION="0.0.2"

overlay_v002_data_files() {
    # Overlay v0.0.2 emit outputs into ${1} (a cloned live tree). git-adds
    # the newly-emitted platform-defaults.yaml so the cloned git index
    # reflects the snapshot's expected file set (L1 check uses git ls-files).
    local td="$1"
    bash "${HELPER_SH}" --all "${td}" "${BASELINE_VERSION}" >/dev/null
    # platform-defaults.yaml is the only new path post-overlay; the others
    # (plugin.json, hooks.json, contracts.sh) already existed in the clone.
    (cd "${td}" && git add platform-defaults.yaml 2>/dev/null) || true
}

# ── Scenario 1: live-tree-positive ───────────────────────────────────────
# Unmodified clone of live tree (+ v0.0.2 DATA overlay) must pass all 5
# layers cleanly.
scenario_live_tree_positive() {
    local td
    td=$(clone_live_tree "positive")
    overlay_v002_data_files "${td}"
    run_diff "${td}"
    assert_pass "1. live-tree-positive (unmodified live tree + v0.0.2 overlay, all 5 layers pass)" "0" \
        stdout_contains "PASS L1" \
        stdout_contains "PASS L2" \
        stdout_contains "PASS L3" \
        stdout_contains "PASS L4" \
        stdout_contains "PASS L5" \
        absent "FAIL CATEGORY:"
}

# ── Scenario 2: conductor-unresolved (Phase 3 reviewer's reproduction) ──
# Plant the exact mutation from the Phase 3 adversarial review:
#   replace ${CLAUDE_PLUGIN_ROOT}/agents/index.md with a nonexistent path.
# Expect exit 1 with referential-integrity-conductor-ref-unresolved.
scenario_conductor_unresolved() {
    local td
    td=$(clone_live_tree "unresolved")
    overlay_v002_data_files "${td}"
    sed -i.bak 's|${CLAUDE_PLUGIN_ROOT}/agents/index.md|${CLAUDE_PLUGIN_ROOT}/agents/THIS-FILE-DOES-NOT-EXIST.md|g' \
        "${td}/CONDUCTOR.md"
    run_diff "${td}"
    assert_pass "2. conductor-unresolved (Phase 3 reviewer's planted bad ref)" "1" \
        contains "referential-integrity-conductor-ref-unresolved" \
        contains "THIS-FILE-DOES-NOT-EXIST.md"
}

# ── Scenario 3: conditional-ref-skip ─────────────────────────────────────
# Plant a "If `<bad>` exists" conditional ref. The documentation convention
# marks the ref as optional/overlay-supplied, so L4 must NOT fail on it.
# This protects the enterprise-overlay pattern from a false-positive.
scenario_conditional_ref_skip() {
    local td
    td=$(clone_live_tree "conditional")
    overlay_v002_data_files "${td}"
    # Append a synthetic conditional reference at end of CONDUCTOR.md.
    cat >>"${td}/CONDUCTOR.md" <<'EOF'

If `${CLAUDE_PLUGIN_ROOT}/reference/nonexistent-overlay-doc.md` exists, read it before proceeding.
EOF
    run_diff "${td}"
    assert_pass "3. conditional-ref-skip (documented \"If \`<path>\` exists\" pattern)" "0" \
        absent "nonexistent-overlay-doc.md" \
        absent "referential-integrity-conductor-ref-unresolved"
}

# ── Scenario 4: glob-pattern-skip ────────────────────────────────────────
# Plant a glob reference. Globs are documentation forms (not literal paths
# to resolve), so L4 must skip them.
scenario_glob_pattern_skip() {
    local td
    td=$(clone_live_tree "glob")
    overlay_v002_data_files "${td}"
    # The live tree already has `${CLAUDE_PLUGIN_ROOT}/agents/*-compact.md`
    # at line 113; verify L4 didn't false-positive on it.
    run_diff "${td}"
    assert_pass "4. glob-pattern-skip (\`*-compact.md\` is doc-form, not literal)" "0" \
        absent "-compact.md" \
        absent "referential-integrity-conductor-ref-unresolved"
}

# ── Layer 5 scenarios (BL-025-m.3) ───────────────────────────────────────
# L5 scenarios reuse the v0.0.2 overlay shared with the L4 scenarios above.

# ── Scenario 5: l5-positive-emit-tree ───────────────────────────────────
# Tree with v0.0.2 emit overlay → all 4 DATA-class shas match baseline → L5 PASS.
scenario_l5_positive_emit_tree() {
    local td
    td=$(clone_live_tree "l5-positive")
    overlay_v002_data_files "${td}"
    run_diff "${td}"
    assert_pass "5. l5-positive-emit-tree (v0.0.2 emit overlay, L5 PASS)" "any" \
        stdout_contains "PASS L5" \
        absent "byte-diff-data-drift"
}

# ── Scenario 6: l5-mutated-plugin-json ──────────────────────────────────
# Mutate one byte in plugin.json after overlay → L5 reports drift.
scenario_l5_mutated_plugin_json() {
    local td
    td=$(clone_live_tree "l5-mutated")
    overlay_v002_data_files "${td}"
    # Single-byte mutation: append a trailing newline (harmless to JSON
    # parse but changes sha256).
    printf '\n' >> "${td}/.claude-plugin/plugin.json"
    run_diff "${td}"
    assert_pass "6. l5-mutated-plugin-json (single-byte drift in plugin.json)" "any" \
        contains "byte-diff-data-drift" \
        contains ".claude-plugin/plugin.json" \
        contains "emit_plugin_json"
}

# ── Scenario 7: l5-missing-data-file ─────────────────────────────────────
# Delete platform-defaults.yaml after overlay → L5 reports drift with
# "missing from plugin tree" detail.
scenario_l5_missing_data_file() {
    local td
    td=$(clone_live_tree "l5-missing")
    overlay_v002_data_files "${td}"
    rm -f "${td}/platform-defaults.yaml"
    run_diff "${td}"
    assert_pass "7. l5-missing-data-file (platform-defaults.yaml deleted)" "any" \
        contains "byte-diff-data-drift" \
        contains "platform-defaults.yaml" \
        contains "emit_platform_defaults"
}

# ── Scenario 8: l5-prose-mutation-ignored ────────────────────────────────
# Mutate README.md (PROSE-class). L5 only iterates baseline entries (all
# DATA-class), so a PROSE mutation must NOT surface as byte-diff-data-drift.
# This guards against the misconception that "L5 hashes everything."
scenario_l5_prose_mutation_ignored() {
    local td
    td=$(clone_live_tree "l5-prose")
    overlay_v002_data_files "${td}"
    printf '\n<!-- mutated by test -->\n' >> "${td}/README.md"
    run_diff "${td}"
    assert_pass "8. l5-prose-mutation-ignored (README.md mutation not flagged by L5)" "any" \
        stdout_contains "PASS L5" \
        absent "byte-diff-data-drift"
}

echo "${YELLOW}[INFO]${NC} BL-025-m.3 structural-diff.sh L4+L5 negative-control harness"
echo "${YELLOW}[INFO]${NC} validator: ${DIFF}"
echo "${YELLOW}[INFO]${NC} live tree: ${LIVE_TREE}"
echo

scenario_live_tree_positive
scenario_conductor_unresolved
scenario_conditional_ref_skip
scenario_glob_pattern_skip
scenario_l5_positive_emit_tree
scenario_l5_mutated_plugin_json
scenario_l5_missing_data_file
scenario_l5_prose_mutation_ignored

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo "${GREEN}PASS${NC} structural-diff fixture harness: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
fi
echo "${RED}FAIL${NC} structural-diff fixture harness: ${FAIL_COUNT}/${TOTAL} scenario(s) failed"
echo "================================"
exit 1
