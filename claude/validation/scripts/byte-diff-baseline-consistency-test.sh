#!/usr/bin/env bash
#
# byte-diff-baseline-consistency-test.sh — BL-025-m.3 M1 amendment.
#
# PURPOSE: Assert the three-way invariant per entry in
#   juntogen/claude/validation/snapshots/byte-diff-baseline.yaml:
#
#     (a) recorded sha in baseline yaml          (intent)
#     (b) sha of frozen fixture for the path     (lockfile)
#     (c) sha of live emit-helper output         (helper truth)
#
# If all three agree per entry, the baseline is anchored to the helper
# (not to today's oj-claude tree). This closes the chicken-and-egg in the
# m.3 plan's FALSIFIER (b): a baseline generated from the live oj-claude
# tree would silently re-encode today's defects; a baseline anchored to
# the helper cannot.
#
# Failure modes covered:
#   - helper edit changes a DATA-class file's bytes -> fixture lags
#   - fixture refresh forgot to update baseline sha
#   - baseline sha edited by hand (not regenerated)
#
# EXIT CODES:
#   0 — all entries' 3-way shas agree
#   1 — at least one entry has a mismatch
#   2 — driver error (missing files, missing python3+yaml, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${SCRIPT_DIR}/../../lib/emit-static-plugin-manifest.sh"
FIXTURE_DIR="${SCRIPT_DIR}/../fixtures/plugin-manifest"
BASELINE="${SCRIPT_DIR}/../snapshots/byte-diff-baseline.yaml"

# Version used by emit_plugin_json (the only emit fn that takes a version).
# Must match the version captured in the frozen plugin.json fixture and
# in the baseline yaml. Bumped in lockstep with juntospec/VERSION.
BASELINE_VERSION="${BASELINE_VERSION:-0.0.2}"

if [ -t 1 ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[ -f "${HELPER}" ]   || { echo "${RED}ERROR${NC} emit helper missing: ${HELPER}" >&2; exit 2; }
[ -d "${FIXTURE_DIR}" ] || { echo "${RED}ERROR${NC} fixture dir missing: ${FIXTURE_DIR}" >&2; exit 2; }
[ -f "${BASELINE}" ] || { echo "${RED}ERROR${NC} baseline yaml missing: ${BASELINE}" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || { echo "${RED}ERROR${NC} python3 required" >&2; exit 2; }
python3 -c 'import yaml' >/dev/null 2>&1 || { echo "${RED}ERROR${NC} python3 yaml module required" >&2; exit 2; }
command -v shasum  >/dev/null 2>&1 || { echo "${RED}ERROR${NC} shasum required" >&2; exit 2; }

PASS_COUNT=0
FAIL_COUNT=0

TMPROOT=$(mktemp -d -t byte-diff-consistency-XXXXXX)
trap 'rm -rf "${TMPROOT}"' EXIT

# Emit DATA-class files to TMPROOT once; reuse for every entry.
bash "${HELPER}" --all "${TMPROOT}" "${BASELINE_VERSION}" >/dev/null

sha_of() {
    shasum -a 256 "$1" | awk '{print $1}'
}

# Read baseline entries as tab-delimited: path \t sha \t provenance.
ENTRIES_TSV=$(mktemp -p "${TMPROOT}" entries-XXXXXX)
python3 - "${BASELINE}" <<'PYEOF' > "${ENTRIES_TSV}"
import sys, yaml
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = yaml.safe_load(f)
for e in (data or {}).get("entries") or []:
    p = e.get("path", "")
    s = e.get("sha256", "")
    pv = e.get("provenance", "")
    if p and s:
        print(f"{p}\t{s}\t{pv}")
PYEOF

echo "${YELLOW}[INFO]${NC} BL-025-m.3 byte-diff-baseline consistency test"
echo "${YELLOW}[INFO]${NC} helper:   ${HELPER}"
echo "${YELLOW}[INFO]${NC} baseline: ${BASELINE}"
echo "${YELLOW}[INFO]${NC} fixtures: ${FIXTURE_DIR}"
echo

assert_three_way() {
    local path="$1" expected="$2" provenance="$3"
    local fixture_path="${FIXTURE_DIR}/$(basename "${path}")"
    local live_path="${TMPROOT}/${path}"

    if [ ! -f "${fixture_path}" ]; then
        echo "${RED}FAIL${NC} ${path}: fixture missing at ${fixture_path}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi
    if [ ! -f "${live_path}" ]; then
        echo "${RED}FAIL${NC} ${path}: live emit output missing at ${live_path}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    local sha_fixture sha_live
    sha_fixture=$(sha_of "${fixture_path}")
    sha_live=$(sha_of "${live_path}")

    if [ "${expected}" = "${sha_fixture}" ] && [ "${expected}" = "${sha_live}" ]; then
        echo "${GREEN}PASS${NC} ${path} (sha256 ${expected:0:12}..., provenance=${provenance})"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "${RED}FAIL${NC} ${path} (provenance=${provenance})"
        echo "${CYAN}    baseline sha256: ${expected}${NC}"
        echo "${CYAN}    fixture  sha256: ${sha_fixture}${NC}"
        echo "${CYAN}    live     sha256: ${sha_live}${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

while IFS=$'\t' read -r path expected provenance; do
    [ -z "${path}" ] && continue
    assert_three_way "${path}" "${expected}" "${provenance}"
done < "${ENTRIES_TSV}"

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo "${GREEN}PASS${NC} byte-diff-baseline consistency: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
fi
echo "${RED}FAIL${NC} byte-diff-baseline consistency: ${FAIL_COUNT}/${TOTAL} entry mismatch(es)"
echo "================================"
exit 1
