#!/usr/bin/env bash
#
# vocabulary-audit-test.sh — BL-025-e negative+positive fixture harness.
#
# Runs every fixture under
#   {juntogen}/claude/validation/fixtures/vocabulary-bleed/{negative,positive,hash-drift}/
# against vocabulary-audit.sh and asserts:
#   - audit exit code matches expected.yaml `exit_code:`
#   - audit stderr contains every substring in `must_contain_stderr:` (if any)
#   - audit stderr contains NONE of the substrings in `must_not_contain_stderr:`
#
# Each fixture lives in a temp directory with `<target>.md` (renamed from
# spec.md per fixture's `<!-- target: NAME.md -->` directive on its first
# line) and `platform-contract.yaml` (copied from contract.yaml).
#
# Exit codes:
#   0 — all fixtures pass
#   1 — one or more fixtures failed
#   2 — driver error (missing yaml helper, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# BL-025-f: fixtures/ now lives in juntogen next to the test harness (the
# historical pre-BL-025-f layout was under juntospec). FIX_ROOT is
# juntogen-internal and resolves from SCRIPT_DIR. The harness invokes the
# audit against per-fixture tempdirs (each fixture writes its own
# contract+spec before audit runs), so the live SPEC_ROOT is NOT required
# for fixture execution — only useful for documentation/diagnostics when set.
AUDIT="${SCRIPT_DIR}/vocabulary-audit.sh"
FIX_ROOT="$(cd "${SCRIPT_DIR}/../fixtures/vocabulary-bleed" && pwd)"

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

PASS_COUNT=0
FAIL_COUNT=0
FAILED_NAMES=""

[ -x "${AUDIT}" ]   || { echo -e "${RED}ERROR${NC} audit script missing or not executable: ${AUDIT}" >&2; exit 2; }
[ -d "${FIX_ROOT}" ] || { echo -e "${RED}ERROR${NC} fixture root missing: ${FIX_ROOT}" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}ERROR${NC} python3 not on PATH" >&2; exit 2; }

# expected.yaml parsers — each returns a single field on stdout.
parse_expected_field() {
    # $1 = expected.yaml path; $2 = field name (exit_code | must_contain_stderr | must_not_contain_stderr)
    # exit_code returns an int; list fields return one entry per line.
    python3 - "$1" "$2" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f) or {}
field = sys.argv[2]
if field == "exit_code":
    print(int(d.get("exit_code", 0)))
elif field == "must_contain_stderr":
    for s in (d.get("must_contain_stderr") or []):
        print(s)
elif field == "must_not_contain_stderr":
    for s in (d.get("must_not_contain_stderr") or []):
        print(s)
else:
    sys.stderr.write(f"unknown field: {field}\n")
    sys.exit(2)
PY
}

run_fixture() {
    local fixture_dir="$1"
    local rel="${fixture_dir#${FIX_ROOT}/}"

    local spec_file="${fixture_dir}/spec.md"
    local contract_file="${fixture_dir}/contract.yaml"
    local expected_file="${fixture_dir}/expected.yaml"

    for required in "${spec_file}" "${contract_file}" "${expected_file}"; do
        if [ ! -f "${required}" ]; then
            echo -e "${RED}FAIL${NC} ${rel}: missing required file $(basename "${required}")"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_NAMES="${FAILED_NAMES}${rel}"$'\n'
            return
        fi
    done

    # Read target name from first line of spec.md: <!-- target: NAME.md -->
    local target_name
    target_name=$(awk 'NR==1{ if (match($0, /target:[[:space:]]*[^[:space:]]+/)) { s = substr($0, RSTART, RLENGTH); sub(/^target:[[:space:]]*/, "", s); print s; } exit }' "${spec_file}")
    if [ -z "${target_name}" ]; then
        echo -e "${RED}FAIL${NC} ${rel}: spec.md first line lacks <!-- target: NAME.md --> directive"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_NAMES="${FAILED_NAMES}${rel}"$'\n'
        return
    fi

    # Build temp spec root.
    local tmp
    tmp=$(mktemp -d -t vocab-audit-fixture-XXXXXX)
    trap 'rm -rf "${tmp}"' RETURN

    cp "${spec_file}" "${tmp}/${target_name}"
    cp "${contract_file}" "${tmp}/platform-contract.yaml"

    # Run audit. Capture exit code, stderr.
    local stderr_log="${tmp}/.stderr"
    local actual_exit=0
    "${AUDIT}" "${tmp}" >/dev/null 2>"${stderr_log}" || actual_exit=$?

    # Parse expected.yaml fields.
    local exp_exit
    exp_exit=$(parse_expected_field "${expected_file}" exit_code)

    local must=() must_not=()
    while IFS= read -r line; do [ -n "${line}" ] && must+=("${line}"); done < <(parse_expected_field "${expected_file}" must_contain_stderr)
    while IFS= read -r line; do [ -n "${line}" ] && must_not+=("${line}"); done < <(parse_expected_field "${expected_file}" must_not_contain_stderr)

    local stderr_text
    stderr_text=$(cat "${stderr_log}")

    local errors=""

    if [ "${actual_exit}" -ne "${exp_exit}" ]; then
        errors="${errors}    exit code mismatch: expected ${exp_exit}, got ${actual_exit}"$'\n'
    fi

    local s
    if [ "${#must[@]}" -gt 0 ]; then
        for s in "${must[@]}"; do
            if ! printf '%s' "${stderr_text}" | grep -qF -- "${s}"; then
                errors="${errors}    missing required stderr substring: ${s}"$'\n'
            fi
        done
    fi
    if [ "${#must_not[@]}" -gt 0 ]; then
        for s in "${must_not[@]}"; do
            if printf '%s' "${stderr_text}" | grep -qF -- "${s}"; then
                errors="${errors}    forbidden stderr substring present: ${s}"$'\n'
            fi
        done
    fi

    if [ -z "${errors}" ]; then
        echo -e "${GREEN}PASS${NC} ${rel}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} ${rel}"
        printf '%s' "${errors}"
        echo -e "${CYAN}    actual exit=${actual_exit}${NC}"
        # Indent stderr for readability
        if [ -n "${stderr_text}" ]; then
            echo -e "${CYAN}    actual stderr:${NC}"
            printf '%s\n' "${stderr_text}" | sed 's/^/      /'
        fi
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_NAMES="${FAILED_NAMES}${rel}"$'\n'
    fi
}

# BL-028 schema-drift guard: run the parse-contract.py column-count snapshot
# test before any fixture work. If parse-contract.py's TSV schema has drifted
# from what vocabulary-audit.sh's consumer `read` loops expect, every fixture
# below would silently misinterpret one column — so we fail fast here with a
# specific schema-drift error rather than a confused fixture cascade.
SCHEMA_TEST="${SCRIPT_DIR}/parse-contract-schema-test.sh"
if [ -x "${SCHEMA_TEST}" ]; then
    echo -e "${YELLOW}[INFO]${NC} Pre-flight: parse-contract.py schema-drift guard (BL-028)"
    if ! "${SCHEMA_TEST}"; then
        echo -e "${RED}ABORT${NC} schema-drift guard failed — fixture run skipped." >&2
        exit 1
    fi
    echo
fi

echo -e "${YELLOW}[INFO]${NC} Running BL-025-e vocabulary-audit fixtures from: ${FIX_ROOT}"
echo

# Discover fixtures: any dir with all three required files.
fixture_dirs=$(find "${FIX_ROOT}" -mindepth 2 -maxdepth 2 -type d \( -path "*/_shared" -prune -o -print \) | sort)

while IFS= read -r d; do
    [ -z "${d}" ] && continue
    [ "$(basename "${d}")" = "_shared" ] && continue
    if [ -f "${d}/spec.md" ] && [ -f "${d}/contract.yaml" ] && [ -f "${d}/expected.yaml" ]; then
        run_fixture "${d}"
    fi
done <<< "${fixture_dirs}"

echo
echo "================================"
echo -e "${GREEN}PASSED${NC}: ${PASS_COUNT}"
echo -e "${RED}FAILED${NC}: ${FAIL_COUNT}"
echo "================================"

if [ "${FAIL_COUNT}" -gt 0 ]; then
    echo
    echo "Failed fixtures:"
    printf '%s' "${FAILED_NAMES}" | while IFS= read -r n; do [ -n "${n}" ] && echo "  ${n}"; done
    exit 1
fi
exit 0
