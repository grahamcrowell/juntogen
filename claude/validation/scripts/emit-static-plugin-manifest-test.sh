#!/usr/bin/env bash
#
# emit-static-plugin-manifest-test.sh — BL-025-m.2 CI gate for the
# static-emit DATA helper.
#
# PURPOSE: Freeze the byte-exact output of emit_plugin_json,
# emit_marketplace_json, emit_hooks_json, emit_contracts_sh, and
# emit_platform_defaults against fixtures stored at
# juntogen/claude/validation/fixtures/plugin-manifest/. Any drift in the
# emit helper — heredoc edit, jq invocation change, or wrong key order —
# fails this test loudly BEFORE the m.3 byte-diff gate runs.
#
# WHY: The three artifacts are DATA-class outputs per
# platform-contract.yaml output_classes — they must be byte-deterministic
# given the same inputs. Without this test, a silent drift would only
# surface during the layered convergence gate (BL-025-m.3) when comparing
# regen output against the oj-claude baseline. Locking the helper output
# at this gate makes the m.3 comparison redundant for these three files
# (a passing emit-test implies emit-helper ⇒ frozen-fixture ⇒ oj-claude
# baseline, since the fixtures themselves are byte-identical to the
# baseline at freeze time).
#
# FIXTURES (frozen 2026-05-12 BL-025-m.2 from oj-claude baseline;
# plugin.json + platform-defaults.yaml refreshed 2026-05-13 BL-025-m.3;
# marketplace.json frozen with regen-pipeline wiring at v0.0.2):
#   juntogen/claude/validation/fixtures/plugin-manifest/plugin.json
#   juntogen/claude/validation/fixtures/plugin-manifest/marketplace.json
#   juntogen/claude/validation/fixtures/plugin-manifest/hooks.json
#   juntogen/claude/validation/fixtures/plugin-manifest/contracts.sh
#   juntogen/claude/validation/fixtures/plugin-manifest/platform-defaults.yaml
#
# Test scenarios:
#   1. POSITIVE — emit_plugin_json /tmp/td 0.0.2 produces a file whose
#      sha256 equals the frozen plugin.json fixture's sha256.
#   2. POSITIVE — emit_marketplace_json /tmp/td produces a file whose sha256
#      equals the frozen marketplace.json fixture's sha256.
#   3. POSITIVE — emit_hooks_json /tmp/td produces a file whose sha256
#      equals the frozen hooks.json fixture's sha256.
#   4. POSITIVE — emit_contracts_sh /tmp/td produces a file whose sha256
#      equals the frozen contracts.sh fixture's sha256.
#   5. POSITIVE — emit_platform_defaults /tmp/td produces a file whose
#      sha256 equals the frozen platform-defaults.yaml fixture's sha256.
#   6-10. IDEMPOTENCY — running each emit twice into the same dir produces
#      the same sha256 (re-emit must be a no-op effectively).
#
# Output format (matches existing -test.sh harness pattern):
#   PASS <scenario name>
#   FAIL <scenario name> (with diagnostic)
#   Summary: ${PASS_COUNT}/${TOTAL}
#
# EXIT CODES:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error (helper missing, fixture missing, jq missing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${SCRIPT_DIR}/../../lib/emit-static-plugin-manifest.sh"
FIXTURE_DIR="${SCRIPT_DIR}/../fixtures/plugin-manifest"

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[ -f "${HELPER}" ]      || { echo -e "${RED}ERROR${NC} emit helper not found: ${HELPER}" >&2; exit 2; }
[ -d "${FIXTURE_DIR}" ] || { echo -e "${RED}ERROR${NC} fixture dir not found: ${FIXTURE_DIR}" >&2; exit 2; }
for f in plugin.json marketplace.json hooks.json contracts.sh platform-defaults.yaml; do
    [ -f "${FIXTURE_DIR}/${f}" ] || { echo -e "${RED}ERROR${NC} fixture missing: ${FIXTURE_DIR}/${f}" >&2; exit 2; }
done
command -v jq      >/dev/null 2>&1 || { echo -e "${RED}ERROR${NC} jq not on PATH (required by emit helper)" >&2; exit 2; }
command -v shasum  >/dev/null 2>&1 || { echo -e "${RED}ERROR${NC} shasum not on PATH" >&2; exit 2; }

# shellcheck source=/dev/null
. "${HELPER}"

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

sha() {
    shasum -a 256 "$1" | awk '{print $1}'
}

assert_sha_match() {
    local name="$1" produced="$2" frozen="$3"
    if [ ! -f "${produced}" ]; then
        echo -e "${RED}FAIL${NC} ${name}: produced file does not exist: ${produced}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi
    local sha_p sha_f
    sha_p=$(sha "${produced}")
    sha_f=$(sha "${frozen}")
    if [ "${sha_p}" = "${sha_f}" ]; then
        echo -e "${GREEN}PASS${NC} ${name} (sha256 ${sha_p:0:12}...)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} ${name}"
        echo -e "${CYAN}    produced sha256: ${sha_p}${NC}"
        echo -e "${CYAN}    frozen   sha256: ${sha_f}${NC}"
        echo -e "${CYAN}    diff (truncated):${NC}"
        diff -u "${frozen}" "${produced}" 2>&1 | head -20 | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo -e "${YELLOW}[INFO]${NC} BL-025-m.2 emit-static-plugin-manifest fixture test"
echo -e "${YELLOW}[INFO]${NC} helper:   ${HELPER}"
echo -e "${YELLOW}[INFO]${NC} fixtures: ${FIXTURE_DIR}"
echo

# Scenario 1+2+3+4: first-emit byte-identity to fixtures.
TD=$(mktemp -d -t emit-fixture-XXXXXX)
TMPDIRS+=("${TD}")
emit_plugin_json        "${TD}" "0.0.2" >/dev/null
emit_marketplace_json   "${TD}"          >/dev/null
emit_hooks_json         "${TD}"          >/dev/null
emit_contracts_sh       "${TD}"          >/dev/null
emit_platform_defaults  "${TD}"          >/dev/null

assert_sha_match "plugin.json            (first emit)" "${TD}/.claude-plugin/plugin.json"      "${FIXTURE_DIR}/plugin.json"
assert_sha_match "marketplace.json       (first emit)" "${TD}/.claude-plugin/marketplace.json" "${FIXTURE_DIR}/marketplace.json"
assert_sha_match "hooks.json             (first emit)" "${TD}/hooks/hooks.json"                "${FIXTURE_DIR}/hooks.json"
assert_sha_match "contracts.sh           (first emit)" "${TD}/bin/lib/contracts.sh"            "${FIXTURE_DIR}/contracts.sh"
assert_sha_match "platform-defaults.yaml (first emit)" "${TD}/platform-defaults.yaml"          "${FIXTURE_DIR}/platform-defaults.yaml"

# Idempotency: re-emit into the same dir must produce the same sha. (Most
# failure modes here would be timestamps in heredocs or jq output reordering;
# the helper has none, but lock it.)
emit_plugin_json        "${TD}" "0.0.2" >/dev/null
emit_marketplace_json   "${TD}"          >/dev/null
emit_hooks_json         "${TD}"          >/dev/null
emit_contracts_sh       "${TD}"          >/dev/null
emit_platform_defaults  "${TD}"          >/dev/null

assert_sha_match "plugin.json            (re-emit idempotency)" "${TD}/.claude-plugin/plugin.json"      "${FIXTURE_DIR}/plugin.json"
assert_sha_match "marketplace.json       (re-emit idempotency)" "${TD}/.claude-plugin/marketplace.json" "${FIXTURE_DIR}/marketplace.json"
assert_sha_match "hooks.json             (re-emit idempotency)" "${TD}/hooks/hooks.json"                "${FIXTURE_DIR}/hooks.json"
assert_sha_match "contracts.sh           (re-emit idempotency)" "${TD}/bin/lib/contracts.sh"            "${FIXTURE_DIR}/contracts.sh"
assert_sha_match "platform-defaults.yaml (re-emit idempotency)" "${TD}/platform-defaults.yaml"          "${FIXTURE_DIR}/platform-defaults.yaml"

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} emit-static-plugin-manifest-test: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
else
    echo -e "${RED}FAIL${NC} emit-static-plugin-manifest-test: ${FAIL_COUNT}/${TOTAL} scenario(s) failed"
    echo "================================"
    exit 1
fi
