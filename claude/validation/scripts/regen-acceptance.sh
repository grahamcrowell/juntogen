#!/usr/bin/env bash
#
# regen-acceptance.sh — BL-025-m.3 regen-tree acceptance wrapper.
#
# PURPOSE: Run the cycle's acceptance gates against a fresh regen tree
# (OUTPUT_DIR), in a fixed order, with each plugin-side suite invoked
# from ${OUTPUT_DIR}/scripts/, NOT from the live oj-claude tree. This
# closes the "path-coupling" failure mode (Phase 3 HIGH-2): if the
# suites resolved their PLUGIN_ROOT from the live tree, the harness
# would pass-by-coincidence regardless of regen-tree content.
#
# ORDER (BEFORE pristine plugin-side suite runs):
#   0. Sanity: OUTPUT_DIR is a regen tree (plugin.json + bin/oj-helper +
#      scripts/ present).
#   1. Mutation smoke-test: change name in
#      ${OUTPUT_DIR}/.claude-plugin/plugin.json from "oj" -> "BROKEN",
#      run validate-plugin from REGEN_OUT, ASSERT it FAILS mentioning
#      the bad name. Restore from .bak. Proves the harness reads the
#      regen tree (and not the live oj-claude tree's plugin.json).
#   2. structural-diff (L1-L5) against OUTPUT_DIR.
#   3. tier-a-assertions against OUTPUT_DIR.
#   4. validate-no-step-sentinel against OUTPUT_DIR.
#   5. Plugin-side suites against OUTPUT_DIR:
#      a. ${OUTPUT_DIR}/scripts/tests/oj-helper-hook-test.sh
#      b. ${OUTPUT_DIR}/scripts/tests/plugin-validate-test.sh
#      c. ${OUTPUT_DIR}/scripts/tests/plugin-e2e-test.sh
#      d. ${OUTPUT_DIR}/scripts/validate-plugin.sh --no-claude
#         (script resolves PLUGIN_ROOT from its own location)
#
# EXIT CODES:
#   0 - all gates GREEN
#   1 - any gate FAIL
#   2 - driver error (OUTPUT_DIR malformed, dependencies missing)
#
# USAGE:
#   bash regen-acceptance.sh /tmp/regen-final

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JUNTOGEN_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

OUTPUT_DIR="${1:-}"

if [ -t 1 ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

usage() {
    cat <<EOF
USAGE: regen-acceptance.sh <OUTPUT_DIR>

Runs the BL-025-m.3 acceptance gate against a fresh regen tree.
OUTPUT_DIR must contain .claude-plugin/plugin.json, bin/oj-helper, and
scripts/ (the latter copied by emit_plugin_scripts).
EOF
}

if [ -z "${OUTPUT_DIR}" ]; then
    echo "${RED}ERROR${NC} OUTPUT_DIR required as 1st arg" >&2
    usage >&2
    exit 2
fi
if [ ! -d "${OUTPUT_DIR}" ]; then
    echo "${RED}ERROR${NC} OUTPUT_DIR is not a directory: ${OUTPUT_DIR}" >&2
    exit 2
fi
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

# Sanity: tree shape.
if [ ! -f "${OUTPUT_DIR}/.claude-plugin/plugin.json" ]; then
    echo "${RED}ERROR${NC} regen tree missing .claude-plugin/plugin.json (not a regen tree?)" >&2
    exit 2
fi
if [ ! -x "${OUTPUT_DIR}/bin/oj-helper" ]; then
    echo "${RED}ERROR${NC} regen tree missing executable bin/oj-helper" >&2
    exit 2
fi
if [ ! -d "${OUTPUT_DIR}/scripts" ]; then
    echo "${RED}ERROR${NC} regen tree missing scripts/ (run emit_plugin_scripts first)" >&2
    exit 2
fi

PASS_COUNT=0
FAIL_COUNT=0

record_suite() {
    local name="$1" rc="$2"
    if [ "${rc}" -eq 0 ]; then
        echo "${GREEN}PASS${NC} ${name}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "${RED}FAIL${NC} ${name} (exit=${rc})"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_suite() {
    # $1 = suite name (display), $2+ = command + args
    local name="$1"; shift
    echo "${YELLOW}[INFO]${NC} ${name}: ${*}"
    local rc=0
    "$@" || rc=$?
    record_suite "${name}" "${rc}"
}

echo "${YELLOW}[INFO]${NC} BL-025-m.3 regen-acceptance gate"
echo "${YELLOW}[INFO]${NC} OUTPUT_DIR: ${OUTPUT_DIR}"
echo "${YELLOW}[INFO]${NC} JUNTOGEN:   ${JUNTOGEN_DIR}"
echo

# ─────────────────────────────────────────────────────────────────────
# 1. Mutation smoke-test — BEFORE pristine suite runs.
# ─────────────────────────────────────────────────────────────────────
# Mutate ${OUTPUT_DIR}/.claude-plugin/plugin.json (change name "oj" ->
# "BROKEN"); run validate-plugin from REGEN_OUT/scripts/; ASSERT it
# FAILS with a message mentioning the bad name (proves the harness
# reads the regen tree's plugin.json, NOT the live oj-claude tree's).
# Restore from .bak.
#
# Why plugin.json (not oj-helper sed-mutation): the prior cmd_inject_
# profile awk-mutation approach was fragile because the regen hook-test
# can fail early (missing VERSION sentinel under set -e) before the
# inject_profile scenarios run, masking whether the harness actually
# read the regen tree. Validate-plugin C2 (name == "oj") is a single
# deterministic check whose failure message is stable across regens,
# and it requires the regen tree's scripts/validate-plugin.sh to
# resolve PLUGIN_ROOT to OUTPUT_DIR via SCRIPT_DIR/.. — the path-
# coupling property this smoke-test exists to prove.
echo "${YELLOW}[INFO]${NC} mutation smoke-test: change plugin.json name oj -> BROKEN, expect validate-plugin to FAIL"
PJSON="${OUTPUT_DIR}/.claude-plugin/plugin.json"
cp "${PJSON}" "${PJSON}.bak"

# jq -S would re-sort keys (drift in regen tree); use --argjson + .name
# assignment to preserve key order in the in-place mutation.
TMP_PJSON=$(mktemp -t regen-acc-pjson-XXXXXX)
jq '.name = "BROKEN"' "${PJSON}" > "${TMP_PJSON}"
mv "${TMP_PJSON}" "${PJSON}"

# Run validate-plugin from REGEN_OUT/scripts/; expect FAIL with
# "name must be" message. --no-claude skips the optional `claude
# plugin validate` final stage (CLI not required for the path-
# coupling proof; structural C1-C7 checks suffice).
SMOKE_LOG=$(mktemp -t regen-acc-smoke-XXXXXX)
SMOKE_EXIT=0
bash "${OUTPUT_DIR}/scripts/validate-plugin.sh" --no-claude \
    >"${SMOKE_LOG}" 2>&1 \
    || SMOKE_EXIT=$?

# Restore pristine plugin.json.
mv "${PJSON}.bak" "${PJSON}"

if [ "${SMOKE_EXIT}" -ne 0 ]; then
    if grep -q "name must be\|BROKEN" "${SMOKE_LOG}" 2>/dev/null; then
        echo "${GREEN}PASS${NC} mutation-smoke-test (validate-plugin FAILed on mutated name; regen-tree coupling confirmed)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "${RED}FAIL${NC} mutation-smoke-test (validate-plugin FAILed, but stdout/stderr did NOT mention the bad name)"
        echo "${CYAN}    smoke log (head -20):${NC}"
        head -20 "${SMOKE_LOG}" | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "${RED}FAIL${NC} mutation-smoke-test (validate-plugin PASSed when plugin.json name was BROKEN; harness is NOT reading regen tree)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
rm -f "${SMOKE_LOG}"
echo

# ─────────────────────────────────────────────────────────────────────
# 2-4. juntogen-side suites against OUTPUT_DIR.
# ─────────────────────────────────────────────────────────────────────
run_suite "structural-diff (L1-L5)" \
    bash "${SCRIPT_DIR}/structural-diff.sh" "${OUTPUT_DIR}"

run_suite "tier-a-assertions" \
    bash "${SCRIPT_DIR}/tier-a-assertions.sh" "${OUTPUT_DIR}"

run_suite "validate-no-step-sentinel" \
    bash "${SCRIPT_DIR}/validate-no-step-sentinel.sh" "${OUTPUT_DIR}"
echo

# ─────────────────────────────────────────────────────────────────────
# 5. Plugin-side suites invoked from OUTPUT_DIR/scripts/.
# ─────────────────────────────────────────────────────────────────────
# Per HIGH-2 amendment: each invocation reads PLUGIN_ROOT from the
# script's own location (SCRIPT_DIR/../..), so invoking from
# OUTPUT_DIR/scripts/* yields PLUGIN_ROOT=OUTPUT_DIR — the regen tree.
run_suite "plugin: oj-helper-hook-test (regen tree)" \
    bash "${OUTPUT_DIR}/scripts/tests/oj-helper-hook-test.sh"

run_suite "plugin: plugin-validate-test (regen tree)" \
    bash "${OUTPUT_DIR}/scripts/tests/plugin-validate-test.sh"

run_suite "plugin: plugin-e2e-test (regen tree)" \
    bash "${OUTPUT_DIR}/scripts/tests/plugin-e2e-test.sh"

# validate-plugin.sh resolves PLUGIN_ROOT from ${SCRIPT_DIR}/.. — it
# does NOT accept a positional path argument. Path-coupling to the
# regen tree is guaranteed by invoking the regen tree's own copy of
# the script. --no-claude skips the optional `claude` CLI stage so
# this gate does not require the upstream CLI on PATH.
run_suite "plugin: validate-plugin (regen tree)" \
    bash "${OUTPUT_DIR}/scripts/validate-plugin.sh" --no-claude

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo "${GREEN}PASS${NC} regen-acceptance: ${PASS_COUNT}/${TOTAL} suite(s) green"
    echo "================================"
    exit 0
fi
echo "${RED}FAIL${NC} regen-acceptance: ${FAIL_COUNT}/${TOTAL} suite(s) red"
echo "================================"
exit 1
