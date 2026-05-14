#!/usr/bin/env bash
#
# parse-contract-schema-test.sh — BL-028 schema-drift guard.
#
# PURPOSE: Lock the column count of parse-contract.py output for both
#          subcommands so that any future schema change fails this test
#          loudly at test time. The companion runtime defense lives in
#          vocabulary-audit.sh's `_extra` tail-var on each consumer read
#          loop; the two defenses are intentionally redundant.
#
# WHY: parse-contract.py grew the 5th `assertion` column for banned-terms
#      in BL-025-e.1, but two consumer `read` loops in vocabulary-audit.sh
#      still used 4-var counts. Bash silently absorbed the 5th column into
#      the last var (bregions / mb_regions), polluting it with an embedded
#      tab + the assertion value. The bug was masked by a coincidental
#      3-region exempt list and only unmasked when BL-025-f stripped a
#      dead label. Same shape will recur the next time someone grows
#      parse-contract.py — this test makes the recurrence loud.
#
# Runs against a frozen fixture under
#   {juntogen}/claude/validation/fixtures/parse-contract-schema/contract.yaml
# which exercises BOTH subcommands with multiple rows.
#
# Assertions per subcommand:
#   1. all output rows have the same column count (uniformity)
#   2. that uniform column count matches the expected value
#
# Expected counts (paired with COLUMN_COUNT comments in parse-contract.py):
#   keep-list    7
#   banned-terms 5
#
# When intentionally extending the schema:
#   1. update the printf in parse-contract.py
#   2. bump the COLUMN_COUNT comment in parse-contract.py
#   3. add the new var (and keep _extra last) to every consumer `read` loop
#      in vocabulary-audit.sh
#   4. bump KEEP_LIST_EXPECTED or BANNED_TERMS_EXPECTED below
#
# Exit codes:
#   0 — both schema assertions pass
#   1 — at least one schema assertion failed
#   2 — driver error (missing fixture, parse-contract.py error, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSE_PY="${SCRIPT_DIR}/lib/parse-contract.py"
FIXTURE="${SCRIPT_DIR}/../fixtures/parse-contract-schema/contract.yaml"

# Expected column counts — keep these in sync with parse-contract.py
# COLUMN_COUNT comments. Changing either of these without a corresponding
# parse-contract.py + vocabulary-audit.sh update is the bug this test catches.
KEEP_LIST_EXPECTED=7
BANNED_TERMS_EXPECTED=5

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi

[ -f "${PARSE_PY}" ] || { echo -e "${RED}ERROR${NC} parse-contract.py missing at ${PARSE_PY}" >&2; exit 2; }
[ -f "${FIXTURE}" ]  || { echo -e "${RED}ERROR${NC} schema fixture missing at ${FIXTURE}" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}ERROR${NC} python3 not on PATH" >&2; exit 2; }

FAIL_COUNT=0

# Assert uniform column count across all rows AND match expected.
# $1 = subcommand (keep-list | banned-terms)
# $2 = expected column count
assert_schema() {
    local subcmd="$1" expected="$2"
    local out
    if ! out=$(python3 "${PARSE_PY}" "${subcmd}" "${FIXTURE}" 2>&1); then
        echo -e "${RED}FAIL${NC} ${subcmd}: parse-contract.py exited non-zero"
        echo "  output: ${out}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi
    if [ -z "${out}" ]; then
        echo -e "${RED}FAIL${NC} ${subcmd}: parse-contract.py emitted no rows (fixture should produce at least one)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    # Column count distribution. BSD-awk compatible.
    local distribution
    distribution=$(printf '%s\n' "${out}" | awk -F'\t' '{print NF}' | sort -u)
    local distinct_counts
    distinct_counts=$(printf '%s\n' "${distribution}" | wc -l | tr -d '[:space:]')

    if [ "${distinct_counts}" != "1" ]; then
        echo -e "${RED}FAIL${NC} ${subcmd}: non-uniform column count across rows (got: ${distribution//$'\n'/, })"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    local actual="${distribution}"
    if [ "${actual}" != "${expected}" ]; then
        echo -e "${RED}FAIL${NC} ${subcmd}: column count drift — expected ${expected}, got ${actual}"
        echo "  If this is an intentional schema change, update:"
        echo "    1. parse-contract.py COLUMN_COUNT comment"
        echo "    2. vocabulary-audit.sh consumer \`read\` loops (add var, keep _extra last)"
        echo "    3. ${BASH_SOURCE[0]} expected count constant"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    echo -e "${GREEN}PASS${NC} ${subcmd}: ${actual} columns (uniform across all rows)"
}

echo -e "${YELLOW}[INFO]${NC} BL-028 parse-contract.py schema-drift guard"
echo -e "${YELLOW}[INFO]${NC} fixture: ${FIXTURE}"
echo

assert_schema "keep-list"    "${KEEP_LIST_EXPECTED}"
assert_schema "banned-terms" "${BANNED_TERMS_EXPECTED}"

echo
echo "================================"
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} parse-contract schema test: 2/2"
    echo "================================"
    exit 0
else
    echo -e "${RED}FAIL${NC} parse-contract schema test: ${FAIL_COUNT} assertion(s) failed"
    echo "================================"
    exit 1
fi
