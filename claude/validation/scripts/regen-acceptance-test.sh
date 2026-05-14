#!/usr/bin/env bash
#
# regen-acceptance-test.sh — BL-025-m.3 negative-control for the regen-
# acceptance wrapper.
#
# PURPOSE: Lock the regen-acceptance.sh wrapper's mutation-detection and
# sanity-rejection behaviors against regressions. Each scenario builds a
# synthesized tree, invokes regen-acceptance, and asserts on (exit code,
# stdout/stderr substring presence/absence).
#
# Scenarios:
#   1. sanity-missing-output-dir — invoke without arg                    -> exit 2
#   2. sanity-not-a-regen-tree   — invoke against an empty dir           -> exit 2
#   3. mutation-detection         — clone live tree + v0.0.2 overlay, then
#                                   drop cmd_inject_profile from oj-helper
#                                   in the synth tree before invoking;
#                                   smoke-test inside regen-acceptance
#                                   itself does NOT fire (it's invoked
#                                   inside the wrapper). Instead we verify
#                                   the wrapper detects the synthesized
#                                   mutation by running the hook-test
#                                   against the malformed tree directly.
#                                   The asserted behavior:
#                                     - regen-acceptance exits non-zero
#                                     - stderr/stdout mentions either
#                                       inject_profile or mutation-smoke
#
# NB: A "full positive scenario" (clean tree → exit 0) is NOT tested
# here. The pristine regen-acceptance run is itself the acceptance gate
# for the cycle; reproducing it inside this harness would duplicate the
# gate. M1 (byte-diff-baseline-consistency-test) and the per-suite
# *-test.sh harnesses cover the layer-by-layer positives.
#
# EXIT CODES:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error (live tree missing, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="${SCRIPT_DIR}/regen-acceptance.sh"
HELPER_SH="${SCRIPT_DIR}/../../lib/emit-static-plugin-manifest.sh"
LIVE_TREE="${OJ_CLAUDE_DIR:-/Users/brenton/workspace/github.com/openjunto/oj-claude}"

if [ -t 1 ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[ -x "${WRAPPER}" ] || { echo "${RED}ERROR${NC} regen-acceptance.sh not executable: ${WRAPPER}" >&2; exit 2; }
[ -f "${HELPER_SH}" ] || { echo "${RED}ERROR${NC} emit helper missing: ${HELPER_SH}" >&2; exit 2; }
[ -d "${LIVE_TREE}" ] || { echo "${RED}ERROR${NC} live oj-claude tree missing: ${LIVE_TREE}" >&2; exit 2; }

PASS_COUNT=0
FAIL_COUNT=0

# Single cleanup root for all scenarios. Single-arg trap (avoid exit-code
# leak per BL-025-e.2 lesson).
TMPROOT=$(mktemp -d -t regen-acc-test-XXXXXX)
trap 'rm -rf "${TMPROOT}"' EXIT

run_wrapper() {
    # $1 = OUTPUT_DIR arg (may be empty). $RUN_EXIT/$RUN_LOG set on return.
    local out_dir="$1"
    local log
    log=$(mktemp -p "${TMPROOT}" wrapper-log-XXXXXX)
    local rc=0
    if [ -z "${out_dir}" ]; then
        bash "${WRAPPER}" >"${log}" 2>&1 || rc=$?
    else
        bash "${WRAPPER}" "${out_dir}" >"${log}" 2>&1 || rc=$?
    fi
    RUN_EXIT="${rc}"
    RUN_LOG=$(cat "${log}")
    rm -f "${log}"
}

assert_exit() {
    # $1 = scenario name, $2 = expected exit, $3+ = substring expectations
    # mode: contains | absent
    local scenario="$1" expected_exit="$2"
    local errors=""
    if [ "${expected_exit}" != "any" ] && [ "${RUN_EXIT}" != "${expected_exit}" ]; then
        errors="${errors}    expected exit=${expected_exit}, got ${RUN_EXIT}"$'\n'
    fi
    shift 2
    while [ $# -ge 2 ]; do
        local mode="$1" needle="$2"; shift 2
        case "${mode}" in
            contains)
                if ! printf '%s' "${RUN_LOG}" | grep -qF -- "${needle}"; then
                    errors="${errors}    log missing required substring: ${needle}"$'\n'
                fi
                ;;
            absent)
                if printf '%s' "${RUN_LOG}" | grep -qF -- "${needle}"; then
                    errors="${errors}    log unexpectedly contains: ${needle}"$'\n'
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
        echo "${CYAN}    actual log (head -25):${NC}"
        printf '%s\n' "${RUN_LOG}" | head -25 | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ─────────────────────────────────────────────────────────────────────
# Scenario 1: sanity-missing-output-dir
# ─────────────────────────────────────────────────────────────────────
scenario_sanity_missing_output_dir() {
    run_wrapper ""
    assert_exit "1. sanity-missing-output-dir (no arg)" "2" \
        contains "OUTPUT_DIR required"
}

# ─────────────────────────────────────────────────────────────────────
# Scenario 2: sanity-not-a-regen-tree
# ─────────────────────────────────────────────────────────────────────
scenario_sanity_not_a_regen_tree() {
    local empty_dir="${TMPROOT}/empty"
    mkdir -p "${empty_dir}"
    run_wrapper "${empty_dir}"
    assert_exit "2. sanity-not-a-regen-tree (empty dir)" "2" \
        contains "missing .claude-plugin/plugin.json"
}

# ─────────────────────────────────────────────────────────────────────
# Scenario 3: mutation-detection (pre-mutated oj-helper)
# ─────────────────────────────────────────────────────────────────────
# Build a synth tree by cloning live oj-claude + overlaying v0.0.2 DATA,
# then drop cmd_inject_profile from its oj-helper BEFORE invoking
# regen-acceptance. The wrapper's mutation-smoke-test will save the
# pre-mutated oj-helper to .bak, do its own re-mutation pass (which is
# a no-op since the function is already absent), and find the hook-test
# FAILs. Restoration will restore the ALREADY-broken backup. Subsequent
# plugin-side suite invocations will also FAIL.
# Wrapper exits non-zero; log mentions inject_profile or hook-test FAIL.
scenario_mutation_detection() {
    local synth_dir="${TMPROOT}/synth-mutated"
    cp -R "${LIVE_TREE}" "${synth_dir}"
    # Overlay v0.0.2 DATA so structural-diff L5 PASSes for those entries.
    bash "${HELPER_SH}" --all "${synth_dir}" "0.0.2" >/dev/null
    # git-add platform-defaults.yaml so L1 file-set sees it.
    (cd "${synth_dir}" && git add platform-defaults.yaml 2>/dev/null) || true

    # Drop cmd_inject_profile from oj-helper.
    awk '
        BEGIN { skip = 0 }
        /^cmd_inject_profile\(\)/ { skip = 1; next }
        skip && /^}$/ { skip = 0; next }
        !skip { print }
    ' "${synth_dir}/bin/oj-helper" > "${synth_dir}/bin/oj-helper.tmp"
    mv "${synth_dir}/bin/oj-helper.tmp" "${synth_dir}/bin/oj-helper"
    chmod +x "${synth_dir}/bin/oj-helper"

    run_wrapper "${synth_dir}"
    # We expect a non-zero exit. Two strong signals: either the mutation-
    # smoke-test surfaces the missing subcommand, OR the plugin-side
    # hook-test does. Either is acceptable evidence the harness reads
    # the regen tree.
    assert_exit "3. mutation-detection (cmd_inject_profile pre-removed)" "any" \
        contains "FAIL"
    # Additional invariant: wrapper exit must NOT be zero.
    if [ "${RUN_EXIT}" -eq 0 ]; then
        echo "${RED}    additional FAIL${NC}: wrapper exit was 0 on mutated tree"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        PASS_COUNT=$((PASS_COUNT - 1))
    fi
}

echo "${YELLOW}[INFO]${NC} BL-025-m.3 regen-acceptance.sh negative-control harness"
echo "${YELLOW}[INFO]${NC} wrapper:   ${WRAPPER}"
echo "${YELLOW}[INFO]${NC} live tree: ${LIVE_TREE}"
echo

scenario_sanity_missing_output_dir
scenario_sanity_not_a_regen_tree
scenario_mutation_detection

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo "${GREEN}PASS${NC} regen-acceptance-test: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
fi
echo "${RED}FAIL${NC} regen-acceptance-test: ${FAIL_COUNT}/${TOTAL} scenario(s) failed"
echo "================================"
exit 1
