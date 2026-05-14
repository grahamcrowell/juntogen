#!/usr/bin/env bash
#
# validate-no-step-sentinel-test.sh — CI gate for the standalone
# sentinel-hygiene validator (validate-no-step-sentinel.sh).
#
# PURPOSE: Lock in the contract of validate-no-step-sentinel.sh across
# the five canonical inputs the Tier A Assertion-18 logic must handle.
# The standalone validator runs on partial trees (e.g. `--spike NN`
# outputs that stop before CONDUCTOR.md is emitted), so this gate must
# prove it operates correctly without depending on CONDUCTOR.md while
# still catching the deep-sentinel reproducer that motivated the
# unbounded-depth fix (m.2 H1).
#
# SCENARIOS:
#   P1 — empty OUTPUT_DIR (exists, no files at all).
#        Expected: exit 0 (no sentinels = no leak).
#   P2 — partial tree (no CONDUCTOR.md, no sentinels — mirrors a fresh
#        `--spike 07` output stopping before plugin-tree finalization).
#        Expected: exit 0. THIS IS THE BL-025-m.4 RAISON D'ÊTRE — Tier A
#        would die at the CONDUCTOR.md preflight; the standalone runs.
#   P3 — the live oj-claude/ baseline tree.
#        Expected: exit 0 (no regression against the canonical baseline).
#   N1 — sentinel `.step-07.done` at OUTPUT_DIR root.
#        Expected: exit 1, sentinel path surfaced.
#   N2 — sentinel `.step-04.done` at depth ≥ 3 (skills/<name>/foo/).
#        This is the m.2 H1 reproducer: a -maxdepth 2 cap silently passed
#        this leak. Expected: exit 1, sentinel path surfaced.
#
# OUTPUT FORMAT (mirrors emit-static-plugin-manifest-test.sh):
#   PASS <scenario name>
#   FAIL <scenario name> (with diagnostic)
#   Summary: ${PASS_COUNT}/${TOTAL}
#
# EXIT CODES:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error (script missing, baseline tree missing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="${SCRIPT_DIR}/validate-no-step-sentinel.sh"
LIVE_BASELINE="${OJ_LIVE_BASELINE:-/Users/brenton/workspace/github.com/openjunto/oj-claude}"

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[ -f "${VALIDATOR}" ] || { echo -e "${RED}ERROR${NC} validator not found: ${VALIDATOR}" >&2; exit 2; }
[ -x "${VALIDATOR}" ] || { echo -e "${RED}ERROR${NC} validator not executable: ${VALIDATOR}" >&2; exit 2; }
[ -d "${LIVE_BASELINE}" ] || { echo -e "${RED}ERROR${NC} live baseline not found: ${LIVE_BASELINE}" >&2; exit 2; }

PASS_COUNT=0
FAIL_COUNT=0

TMPDIRS=()
cleanup() {
    local td
    for td in "${TMPDIRS[@]:-}"; do
        if [ -n "${td}" ] && [ -d "${td}" ]; then
            rm -rf "${td}"
        fi
    done
}
trap cleanup EXIT

# Run the validator and capture exit code + combined output.
# Args: <output_dir>
# Sets globals: RUN_RC, RUN_OUT
run_validator() {
    local out_dir="$1"
    set +e
    RUN_OUT=$(bash "${VALIDATOR}" "${out_dir}" 2>&1)
    RUN_RC=$?
    set -e
}

# Assert exit code matches expected and (when checking for FAIL) all
# expected substrings appear in output.
# Args: <scenario name> <expected_rc> [<expected_substring> ...]
assert_outcome() {
    local name="$1" expected_rc="$2"
    shift 2

    if [ "${RUN_RC}" -ne "${expected_rc}" ]; then
        echo -e "${RED}FAIL${NC} ${name}"
        echo -e "${CYAN}    expected exit ${expected_rc}, got ${RUN_RC}${NC}"
        echo -e "${CYAN}    output:${NC}"
        echo "${RUN_OUT}" | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    local sub
    for sub in "$@"; do
        if ! echo "${RUN_OUT}" | grep -qF -- "${sub}"; then
            echo -e "${RED}FAIL${NC} ${name}"
            echo -e "${CYAN}    expected substring not found: ${sub}${NC}"
            echo -e "${CYAN}    output:${NC}"
            echo "${RUN_OUT}" | sed 's/^/      /'
            FAIL_COUNT=$((FAIL_COUNT + 1))
            return
        fi
    done

    echo -e "${GREEN}PASS${NC} ${name} (exit ${RUN_RC})"
    PASS_COUNT=$((PASS_COUNT + 1))
}

echo -e "${YELLOW}[INFO]${NC} validate-no-step-sentinel test suite"
echo -e "${YELLOW}[INFO]${NC} validator:     ${VALIDATOR}"
echo -e "${YELLOW}[INFO]${NC} live baseline: ${LIVE_BASELINE}"
echo

# ---------------------------------------------------------------------------
# P1: empty OUTPUT_DIR
# ---------------------------------------------------------------------------
TD_P1=$(mktemp -d -t sentinel-p1-XXXXXX)
TMPDIRS+=("${TD_P1}")
run_validator "${TD_P1}"
assert_outcome "P1: empty OUTPUT_DIR -> exit 0" 0 "PASS"

# ---------------------------------------------------------------------------
# P2: partial tree (no CONDUCTOR.md, no sentinels — --spike 07 shape)
# ---------------------------------------------------------------------------
TD_P2=$(mktemp -d -t sentinel-p2-XXXXXX)
TMPDIRS+=("${TD_P2}")
# Mimic a partial generation: skills/ dir exists but no CONDUCTOR.md and
# no sentinel leak. This is the case Tier A could not check on its own.
mkdir -p "${TD_P2}/skills/consult"
mkdir -p "${TD_P2}/agents"
mkdir -p "${TD_P2}/reference"
echo "stub" > "${TD_P2}/skills/consult/SKILL.md"
run_validator "${TD_P2}"
assert_outcome "P2: partial tree (--spike 07 shape) -> exit 0" 0 "PASS"

# ---------------------------------------------------------------------------
# P3: live oj-claude/ baseline tree
# ---------------------------------------------------------------------------
run_validator "${LIVE_BASELINE}"
assert_outcome "P3: live oj-claude baseline -> exit 0" 0 "PASS"

# ---------------------------------------------------------------------------
# N1: sentinel at OUTPUT_DIR root
# ---------------------------------------------------------------------------
TD_N1=$(mktemp -d -t sentinel-n1-XXXXXX)
TMPDIRS+=("${TD_N1}")
touch "${TD_N1}/.step-07.done"
run_validator "${TD_N1}"
assert_outcome "N1: sentinel at OUTPUT_DIR root -> exit 1, path surfaced" 1 \
    "FAIL" \
    ".step-07.done"

# ---------------------------------------------------------------------------
# N2: sentinel at depth >= 3 (m.2 H1 reproducer)
# ---------------------------------------------------------------------------
TD_N2=$(mktemp -d -t sentinel-n2-XXXXXX)
TMPDIRS+=("${TD_N2}")
mkdir -p "${TD_N2}/skills/consult/foo"
touch "${TD_N2}/skills/consult/foo/.step-04.done"
run_validator "${TD_N2}"
assert_outcome "N2: deep sentinel (depth >= 3, m.2 H1 reproducer) -> exit 1, path surfaced" 1 \
    "FAIL" \
    ".step-04.done"

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} validate-no-step-sentinel-test: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
else
    echo -e "${RED}FAIL${NC} validate-no-step-sentinel-test: ${FAIL_COUNT}/${TOTAL} scenario(s) failed"
    echo "================================"
    exit 1
fi
