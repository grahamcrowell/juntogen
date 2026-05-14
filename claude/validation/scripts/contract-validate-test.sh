#!/usr/bin/env bash
#
# contract-validate-test.sh — BL-025-g fixture harness for contract-validate.sh.
#
# PURPOSE: Lock all detection branches of contract-validate.sh against
#          regressions. Each scenario constructs an isolated tempdir
#          containing a synthetic platform-contract.yaml plus minimal
#          stub spec files, invokes contract-validate.sh, and asserts on
#          (exit code, structured-stderr substring presence/absence).
#
# WHY (FINDING-6 — negative-control discipline): the live corpus is clean
#   today; without fixtures, every detection branch is dead code from the
#   audit's point of view. This harness proves each branch fires when
#   triggered, and remains silent when not.
#
# Scenarios (mapping detection branches to fixtures):
#   a. good                  — id declared and marker present                     -> exit 0
#   b. missing-marker        — file exists, marker absent                         -> exit 1, canonical-id-missing-marker
#   c. file-missing          — file path doesn't resolve                          -> exit 1, canonical-id-file-missing
#   d. orphan-marker         — corpus marker not declared in contract             -> exit 1, canonical-id-orphan-marker
#   e. multi-id-line         — one line carrying two markers, both declared       -> exit 0 (catches head -1 regression)
#   f. meta-id-skip          — corpus literal `[CANONICAL: id]` (meta documentation) -> exit 0 (no orphan reported)
#   g. cross-repo            — file_repo: juntogen entry resolved against tempdir -> exit 0 if marker present, 1 if absent
#   h. schema-extra-key      — contract row carries a benign optional key         -> exit 0 (loader ignores unknown keys)
#
# Test isolation: each scenario builds an isolated tempdir for both the
# spec_dir and (when needed) the juntogen-root override; cleans up at
# end-of-scenario. Mirrors canonical-id-closure-test.sh:65 idiom.
#
# Exit codes:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error (missing dependency, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="${SCRIPT_DIR}/contract-validate.sh"

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[ -x "${VALIDATE}" ] || {
    echo -e "${RED}ERROR${NC} contract-validate.sh missing/not executable: ${VALIDATE}" >&2
    exit 2
}
command -v python3 >/dev/null 2>&1 || {
    echo -e "${RED}ERROR${NC} python3 not on PATH" >&2; exit 2
}

PASS_COUNT=0
FAIL_COUNT=0

# Build an isolated spec tempdir with a minimal contract + stub spec files.
# Args: $1 = scenario tag; $2 = contract YAML body; rest = path:content pairs
#   for stub spec files inside the tempdir. Sets SPEC_TD on success.
make_spec_tempdir() {
    local tag="$1"; shift
    local contract_body="$1"; shift
    local td
    td=$(mktemp -d -t "cv-${tag}-XXXXXX")
    printf '%s' "${contract_body}" >"${td}/platform-contract.yaml"
    while [ $# -ge 2 ]; do
        local relpath="$1"; local content="$2"; shift 2
        local target="${td}/${relpath}"
        mkdir -p "$(dirname "${target}")"
        printf '%s' "${content}" >"${target}"
    done
    printf '%s' "${td}"
}

# Build an isolated juntogen-root tempdir. Sets JG_TD on success.
# A juntogen-root MUST contain claude/D64-tooling.md (sentinel) for the
# realpath sanity check to pass — we plant a stub.
make_juntogen_root_tempdir() {
    local tag="$1"; shift
    local sentinel_body="${1:-stub sentinel}"; shift || true
    local td
    td=$(mktemp -d -t "cv-${tag}-jg-XXXXXX")
    mkdir -p "${td}/claude"
    printf '%s' "${sentinel_body}" >"${td}/claude/D64-tooling.md"
    # Allow caller to plant additional files via subsequent path:content
    # pairs (the implementation passes them via env-vars below).
    printf '%s' "${td}"
}

# Run validate, capture exit code + stderr. On returns:
#   $RUN_EXIT = exit code
#   $RUN_STDERR = stderr capture (string)
run_validate() {
    local stderr_log
    stderr_log=$(mktemp -t cv-stderr-XXXXXX)
    local rc=0
    "${VALIDATE}" "$@" >/dev/null 2>"${stderr_log}" || rc=$?
    RUN_EXIT="${rc}"
    RUN_STDERR=$(cat "${stderr_log}")
    rm -f "${stderr_log}"
}

assert_pass() {
    local scenario="$1" expected_exit="$2"
    local errors=""
    if [ "${RUN_EXIT}" != "${expected_exit}" ]; then
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
            *)
                errors="${errors}    INTERNAL: unknown assert mode: ${mode}"$'\n'
                ;;
        esac
    done
    if [ -z "${errors}" ]; then
        echo -e "${GREEN}PASS${NC} ${scenario}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} ${scenario}"
        printf '%s' "${errors}"
        echo -e "${CYAN}    actual exit=${RUN_EXIT}${NC}"
        echo -e "${CYAN}    actual stderr (head -40):${NC}"
        printf '%s\n' "${RUN_STDERR}" | head -40 | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ── Scenario A: good ──────────────────────────────────────────────────────
scenario_a_good() {
    local td
    td=$(make_spec_tempdir "good" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fixture-good\"
    file: \"D99-fixture.md\"
    section: \"§stub\"
" \
        "D99-fixture.md" "# Fixture\n[CANONICAL: cv-fixture-good]\n")
    run_validate --spec-dir "${td}" --skip-marker-closure
    assert_pass "A. good (declared id with marker present)" "0"
    rm -rf "${td}"
}

# ── Scenario B: missing-marker ────────────────────────────────────────────
scenario_b_missing_marker() {
    local td
    td=$(make_spec_tempdir "missing" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fixture-missing\"
    file: \"D99-fixture.md\"
    section: \"§stub\"
" \
        "D99-fixture.md" "# Fixture without the required marker\n")
    run_validate --spec-dir "${td}" --skip-marker-closure
    assert_pass "B. missing-marker (file exists, marker absent)" "1" \
        contains "canonical-id-missing-marker" \
        contains "cv-fixture-missing"
    rm -rf "${td}"
}

# ── Scenario C: file-missing ──────────────────────────────────────────────
scenario_c_file_missing() {
    local td
    td=$(make_spec_tempdir "filemiss" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fixture-nofile\"
    file: \"D99-does-not-exist.md\"
    section: \"§stub\"
")
    # Note: no stub spec files planted.
    run_validate --spec-dir "${td}" --skip-marker-closure
    assert_pass "C. file-missing (contract path does not resolve)" "1" \
        contains "canonical-id-file-missing" \
        contains "cv-fixture-nofile"
    rm -rf "${td}"
}

# ── Scenario D: orphan-marker ─────────────────────────────────────────────
scenario_d_orphan_marker() {
    local td
    td=$(make_spec_tempdir "orphan" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fixture-declared\"
    file: \"D99-fixture.md\"
    section: \"§stub\"
" \
        "D99-fixture.md" "# Fixture\n[CANONICAL: cv-fixture-declared]\n[CANONICAL: cv-fixture-orphan]\n")
    run_validate --spec-dir "${td}" --skip-marker-closure
    assert_pass "D. orphan-marker (corpus marker not in contract)" "1" \
        contains "canonical-id-orphan-marker" \
        contains "cv-fixture-orphan"
    rm -rf "${td}"
}

# ── Scenario E: multi-id-line (regression for head -1 bug) ────────────────
scenario_e_multi_id_line() {
    local td
    td=$(make_spec_tempdir "multiid" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-a\"
    file: \"D99-fixture.md\"
    section: \"§stub\"
  - id: \"cv-fix-b\"
    file: \"D99-fixture.md\"
    section: \"§stub\"
" \
        "D99-fixture.md" "# Fixture\n[CANONICAL: cv-fix-a] [CANONICAL: cv-fix-b]\n")
    run_validate --spec-dir "${td}" --skip-marker-closure
    # Both declared, both present -> 0 violations. If the reverse scan
    # used `head -1`, it would extract only cv-fix-a and silently miss
    # cv-fix-b's verification — but the forward check would still find
    # cv-fix-b's marker, so this scenario alone doesn't catch the head-1
    # bug. The companion check is the no-orphan absence assertion: a
    # head-1 reverse scan that misses the second marker can't generate
    # spurious orphan reports either, so we additionally probe the
    # surface area by confirming both ids would be visible to the reverse
    # scan if they were undeclared. We do that in scenario E2 below.
    assert_pass "E1. multi-id-line (both declared, both present)" "0" \
        absent "canonical-id-orphan-marker" \
        absent "canonical-id-missing-marker"
    rm -rf "${td}"
}

# E2: same multi-id line, but only one declared -> reverse scan must surface
# the SECOND id as orphan (this is what catches a head -1 bug — head -1
# would return only the first id and silently drop the orphan detection
# for the second).
scenario_e2_multi_id_line_orphan() {
    local td
    td=$(make_spec_tempdir "multiid2" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-a\"
    file: \"D99-fixture.md\"
    section: \"§stub\"
" \
        "D99-fixture.md" "# Fixture\n[CANONICAL: cv-fix-a] [CANONICAL: cv-fix-b]\n")
    run_validate --spec-dir "${td}" --skip-marker-closure
    assert_pass "E2. multi-id-line (one declared, second is orphan -> head -1 regression catch)" "1" \
        contains "canonical-id-orphan-marker" \
        contains "cv-fix-b"
    rm -rf "${td}"
}

# ── Scenario F: meta-id-skip ──────────────────────────────────────────────
scenario_f_meta_id_skip() {
    local td
    td=$(make_spec_tempdir "metaid" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-real\"
    file: \"D99-fixture.md\"
    section: \"§stub\"
" \
        "D99-fixture.md" "# Fixture\n[CANONICAL: cv-fix-real]\n\nMeta documentation: [CANONICAL: id] markers identify canonical sections.\n")
    run_validate --spec-dir "${td}" --skip-marker-closure
    # The literal `[CANONICAL: id]` is the meta documentation form
    # (validate-dry-run.sh:179 precedent) and must NOT trigger an orphan.
    assert_pass "F. meta-id-skip (literal [CANONICAL: id] is documentation)" "0" \
        absent "canonical-id-orphan-marker"
    rm -rf "${td}"
}

# ── Scenario G: cross-repo ────────────────────────────────────────────────
scenario_g_cross_repo() {
    # Synthetic juntogen-root with a marker present.
    local jg_td
    jg_td=$(make_juntogen_root_tempdir "xrepo")
    # Plant the cross-repo source file with a marker.
    mkdir -p "${jg_td}/claude"
    printf '# Cross-repo fixture\n[CANONICAL: cv-fix-xrepo]\n' \
        >"${jg_td}/claude/D99-cross-repo.md"

    local td
    td=$(make_spec_tempdir "xrepo-spec" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-xrepo\"
    file: \"claude/D99-cross-repo.md\"
    file_repo: \"juntogen\"
    section: \"§stub\"
")
    run_validate --spec-dir "${td}" --skip-marker-closure --juntogen-root "${jg_td}"
    assert_pass "G1. cross-repo (file_repo=juntogen, marker present)" "0" \
        absent "canonical-id-missing-marker" \
        absent "canonical-id-file-missing"
    rm -rf "${td}"

    # Variant G2: marker absent in the cross-repo file -> missing-marker.
    printf '# Cross-repo fixture without marker\n' \
        >"${jg_td}/claude/D99-cross-repo.md"
    td=$(make_spec_tempdir "xrepo-spec2" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-xrepo\"
    file: \"claude/D99-cross-repo.md\"
    file_repo: \"juntogen\"
    section: \"§stub\"
")
    run_validate --spec-dir "${td}" --skip-marker-closure --juntogen-root "${jg_td}"
    assert_pass "G2. cross-repo (file_repo=juntogen, marker absent)" "1" \
        contains "canonical-id-missing-marker" \
        contains "cv-fix-xrepo"
    rm -rf "${td}" "${jg_td}"
}

# ── Scenario H: schema-extra-key ──────────────────────────────────────────
scenario_h_schema_extra_key() {
    local td
    td=$(make_spec_tempdir "extrakey" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-extra\"
    file: \"D99-fixture.md\"
    section: \"§stub\"
    refinement_notes: \"benign optional key — loader must ignore\"
" \
        "D99-fixture.md" "# Fixture\n[CANONICAL: cv-fix-extra]\n")
    run_validate --spec-dir "${td}" --skip-marker-closure
    assert_pass "H. schema-extra-key (loader ignores unknown keys)" "0" \
        absent "canonical-id-missing-marker" \
        absent "canonical-id-orphan-marker"
    rm -rf "${td}"
}

# ── Scenario I: unsupported-file-repo ─────────────────────────────────────
# Bonus: prove the F2 mitigation (allow-list) — an unrecognized file_repo
# value MUST surface a structured violation, not silently fall through.
#
# BL-025-h.1 F-05 update: load-contract.py now applies a parse-time enum
# guard (file_repo in {"", "juntospec", "juntogen"}). The guard fires
# BEFORE contract-validate.sh reaches its own runtime check, so the
# expected stderr signal is the loader's diagnostic. Either signal proves
# the F2 mitigation; this scenario now asserts on the loader's signal
# (which is stricter — refuses to even parse) plus the basename to ensure
# the diagnostic is informative.
scenario_i_unsupported_file_repo() {
    local td
    td=$(make_spec_tempdir "badrepo" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-badrepo\"
    file: \"some/path.md\"
    file_repo: \"oj-claude\"
    section: \"§stub\"
")
    run_validate --spec-dir "${td}" --skip-marker-closure
    # Exit code is 1 (loader dies, contract-validate.sh's set -e propagates
    # the substitution failure). The diagnostic comes from the loader and
    # contains both the bad value and the allow-list — proving the
    # diagnostic is actionable.
    assert_pass "I. unsupported-file-repo (F2/F-05 — enum guard rejects unknown repo)" "1" \
        contains "oj-claude" \
        contains "file_repo="
    rm -rf "${td}"
}

# ── Helper: build an isolated steps tempdir ──────────────────────────────
# Each step file is passed as a path:content pair. Returns dir path.
make_steps_tempdir() {
    local tag="$1"; shift
    local td
    td=$(mktemp -d -t "cv-${tag}-steps-XXXXXX")
    while [ $# -ge 2 ]; do
        local relpath="$1"; local content="$2"; shift 2
        printf '%s' "${content}" >"${td}/${relpath}"
    done
    printf '%s' "${td}"
}

# ── Scenario J: spec-file-missing (D3 — BL-025-h.1) ──────────────────────
# Contract.layout.spec_files declares a file that doesn't exist on disk.
# (canonical_ids non-empty to satisfy contract-validate.sh's "not empty"
# preflight check; the focus is the spec_files presence audit.)
scenario_j_spec_file_missing() {
    local td
    td=$(make_spec_tempdir "specfilemiss" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-anchor\"
    file: \"D98-anchor.md\"
    section: \"§stub\"
layout:
  spec_files:
    - file: \"D99-missing.md\"
      file_repo: \"juntospec\"
" \
        "D98-anchor.md" "# anchor\n[CANONICAL: cv-fix-anchor]\n")
    run_validate --spec-dir "${td}" --skip-marker-closure
    assert_pass "J. spec-file-missing (D3 — BL-025-h.1 spec_files presence)" "1" \
        contains "spec-file-missing" \
        contains "D99-missing.md"
    rm -rf "${td}"
}

# ── Scenario K: spec-file-marker-orphan (D4 — BL-025-h.1) ────────────────
# Step prompt uses [FILE: X] but no matching layout.spec_files[].file.
scenario_k_spec_file_marker_orphan() {
    local td steps_td
    td=$(make_spec_tempdir "specorphan" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-anchor\"
    file: \"D98-anchor.md\"
    section: \"§stub\"
layout:
  spec_files:
    - file: \"D99-known.md\"
      file_repo: \"juntospec\"
" \
        "D98-anchor.md" "# anchor\n[CANONICAL: cv-fix-anchor]\n" \
        "D99-known.md" "# stub\n")
    steps_td=$(make_steps_tempdir "specorphan" \
        "step-99-fixture.md" "# Fixture\nRead [FILE: D99-unknown.md] please.\n")
    run_validate --spec-dir "${td}" --steps-dir "${steps_td}"
    assert_pass "K. spec-file-marker-orphan (D4 — BL-025-h.1 step-prompt closure)" "1" \
        contains "spec-file-marker-orphan" \
        contains "D99-unknown.md"
    rm -rf "${td}" "${steps_td}"
}

# ── Scenario L: canonical-id-marker-orphan (D4 — BL-025-h.1) ─────────────
# Step prompt uses [CANONICAL: y] but no matching contract.canonical_ids[].id.
scenario_l_canonical_id_marker_orphan() {
    local td steps_td
    td=$(make_spec_tempdir "canorphan" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-known-id\"
    file: \"D99-known.md\"
    section: \"§stub\"
" \
        "D99-known.md" "# stub\n[CANONICAL: cv-fix-known-id]\n")
    steps_td=$(make_steps_tempdir "canorphan" \
        "step-99-fixture.md" "# Fixture\nSee [CANONICAL: cv-fix-not-in-contract] for context.\n")
    run_validate --spec-dir "${td}" --steps-dir "${steps_td}"
    assert_pass "L. canonical-id-marker-orphan (D4 — BL-025-h.1 step-prompt closure)" "1" \
        contains "canonical-id-marker-orphan" \
        contains "cv-fix-not-in-contract"
    rm -rf "${td}" "${steps_td}"
}

# ── Scenario M: marker-closure pass (D4 — BL-025-h.1) ────────────────────
# Step prompt uses [FILE: X] and [CANONICAL: y] both correctly resolved.
scenario_m_marker_closure_pass() {
    local td steps_td
    td=$(make_spec_tempdir "closurepass" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-real-id\"
    file: \"D99-known.md\"
    section: \"§stub\"
layout:
  spec_files:
    - file: \"D99-known.md\"
      file_repo: \"juntospec\"
" \
        "D99-known.md" "# stub\n[CANONICAL: cv-fix-real-id]\n")
    steps_td=$(make_steps_tempdir "closurepass" \
        "step-99-fixture.md" "# Fixture\nRead [FILE: D99-known.md] then cite [CANONICAL: cv-fix-real-id].\n")
    run_validate --spec-dir "${td}" --steps-dir "${steps_td}"
    assert_pass "M. marker-closure pass (D4 — BL-025-h.1 both markers resolve)" "0" \
        absent "spec-file-marker-orphan" \
        absent "canonical-id-marker-orphan"
    rm -rf "${td}" "${steps_td}"
}

# ── Scenario N: spec_files unsupported-file-repo ─────────────────────────
# Adversarial-review fix (BL-025-h.1 reviewer iteration 1): contract-validate.sh
# previously suppressed load-contract.py's spec-files diagnostics with
# `2>/dev/null || true`, swallowing the loader's enum guard and producing a
# cascade of false-positive `spec-file-marker-orphan` errors that misdirected
# the user. This scenario regression-tests the fix: an unsupported file_repo
# value on a layout.spec_files[] entry MUST surface the loader's diagnostic
# AND MUST NOT produce the marker-orphan cascade.
#
# Mirror of Scenario I (canonical_ids unsupported-file-repo) but on the
# spec_files axis. The step prompt references the legitimate basename via
# [FILE: ...]; before the fix, the loader's enum-failure left
# KNOWN_SPEC_FILES empty and D4 fired marker-orphan against that legitimate
# reference. Asserts the cascade is now suppressed.
scenario_n_spec_files_unsupported_file_repo() {
    local td steps_td
    td=$(make_spec_tempdir "specbadrepo" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-anchor\"
    file: \"D98-anchor.md\"
    section: \"§stub\"
layout:
  spec_files:
    - file: \"D99-known.md\"
      file_repo: \"oj-claude\"
" \
        "D98-anchor.md" "# anchor\n[CANONICAL: cv-fix-anchor]\n" \
        "D99-known.md" "# stub\n")
    steps_td=$(make_steps_tempdir "specbadrepo" \
        "step-99-fixture.md" "# Fixture\nRead [FILE: D99-known.md] please.\n")
    run_validate --spec-dir "${td}" --steps-dir "${steps_td}"
    # Loader's enum guard exits 1; under set -euo pipefail in
    # contract-validate.sh the substitution failure aborts the script. The
    # surfaced diagnostic must be the loader's (informative — names the
    # bad value and the basename), NOT a cascade of marker-orphan errors
    # against the legitimate [FILE: D99-known.md] reference.
    assert_pass "N. spec_files unsupported-file-repo (loader diagnostic surfaces; no marker-orphan cascade)" "1" \
        contains "oj-claude" \
        contains "D99-known.md" \
        contains "file_repo=" \
        absent "spec-file-marker-orphan"
    rm -rf "${td}" "${steps_td}"
}

# ── Scenario O: spec_files duplicate-basename ────────────────────────────
# Companion to Scenario N: the loader's `_spec_file_rows()` enforces
# basename uniqueness (lines 196-209 of load-contract.py) because
# [FILE: basename] resolution would be ambiguous otherwise. Before the
# stderr-suppression fix, this diagnostic was also swallowed. Verify the
# loader's `duplicate file basename` diagnostic now surfaces.
scenario_o_spec_files_duplicate_basename() {
    local td
    td=$(make_spec_tempdir "specduplicate" \
"version: \"0.0.1\"
canonical_ids:
  - id: \"cv-fix-anchor\"
    file: \"D98-anchor.md\"
    section: \"§stub\"
layout:
  spec_files:
    - file: \"F16-architecture.md\"
      file_repo: \"juntospec\"
    - file: \"F16-architecture.md\"
      file_repo: \"juntospec\"
" \
        "D98-anchor.md" "# anchor\n[CANONICAL: cv-fix-anchor]\n" \
        "F16-architecture.md" "# stub\n")
    run_validate --spec-dir "${td}" --skip-marker-closure
    assert_pass "O. spec_files duplicate basename (loader rejects ambiguous [FILE: ...] resolution)" "1" \
        contains "duplicate file basename" \
        contains "F16-architecture.md"
    rm -rf "${td}"
}

echo -e "${YELLOW}[INFO]${NC} BL-025-g/h.1 contract-validate.sh fixture harness"
echo -e "${YELLOW}[INFO]${NC} validator: ${VALIDATE}"
echo

scenario_a_good
scenario_b_missing_marker
scenario_c_file_missing
scenario_d_orphan_marker
scenario_e_multi_id_line
scenario_e2_multi_id_line_orphan
scenario_f_meta_id_skip
scenario_g_cross_repo
scenario_h_schema_extra_key
scenario_i_unsupported_file_repo
scenario_j_spec_file_missing
scenario_k_spec_file_marker_orphan
scenario_l_canonical_id_marker_orphan
scenario_m_marker_closure_pass
scenario_n_spec_files_unsupported_file_repo
scenario_o_spec_files_duplicate_basename

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} contract-validate fixture harness: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
fi
echo -e "${RED}FAIL${NC} contract-validate fixture harness: ${FAIL_COUNT}/${TOTAL} scenario(s) failed"
echo "================================"
exit 1
