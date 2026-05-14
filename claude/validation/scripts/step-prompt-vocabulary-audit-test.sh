#!/usr/bin/env bash
#
# step-prompt-vocabulary-audit-test.sh — BL-025-h.3 regression test for
# step-prompt-vocabulary-audit.sh Pass 3 (legacy-path-form ban).
#
# PURPOSE: Lock the success path of Pass 3 so that a regression
#          (e.g., the pass returning 0 unconditionally, the prefix
#          list being narrowed away, or the substring scan being
#          dropped altogether) fails this test loudly.
#
# WHY: The live step corpus today contains 0 occurrences of either
#      banned prefix. Without this fixture test, Pass 3's success path
#      is unverified: a future regression that re-introduces a literal
#      `/path/to/juntospec/F08-axioms.md` form in a step prompt would
#      silently bypass contract D4 closure (build_prompt's prefix-sed
#      substitutions resolve such literals before they reach the LLM)
#      and slip through the audit unnoticed.
#
# Scenarios exercised against step-prompt-vocabulary-audit.sh:
#   1. NEGATIVE — synthetic step file containing a literal
#      `/path/to/juntospec/F16-architecture.md` line MUST fire
#      `legacy-path-form` on stderr and exit non-zero, naming the
#      planted line and file.
#   2. NEGATIVE — synthetic step file containing a literal
#      `/path/to/juntogen/D64-tooling.md` line MUST fire
#      `legacy-path-form` on stderr and exit non-zero, naming the
#      planted line and file.
#   3. POSITIVE — synthetic step file containing only an in-prose
#      citation `(from spec juntogen/claude/D64-tooling.md, lines 1-5)`
#      (no `/path/to/` prefix) MUST NOT fire `legacy-path-form`. This
#      asserts that Pass 3's substring is anchored on the `/path/to/`
#      sentinel — a future broadening of the prefix list to bare repo
#      names would fail this test.
#
# Test isolation: each scenario builds an isolated tempdir STEPS_DIR
# whose only step-*.md file is the planted synthetic. A minimal
# `.steps-keep-list.yaml` is co-located. The real
# juntospec/platform-contract.yaml is used (Passes 1+2 need it for
# banned_terms[]) but the planted prefix-only fixtures don't contain
# any of the 5 narrowed banned terms (Task tool / TeamCreate / etc.),
# so Passes 1+2 emit 0 violations on every scenario — Pass 3 alone
# determines the outcome.
#
# Exit codes:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error (missing dependency, fixture, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="${SCRIPT_DIR}/step-prompt-vocabulary-audit.sh"

# SPEC_DIR resolution: the audit requires a real platform-contract.yaml
# to load banned_terms[]. The juntospec repo lives as a sibling of
# juntogen in the OpenJunto topology — from this script
# (juntogen/claude/validation/scripts) the org root is 4 levels up.
# Allow OJ_SPEC_DIR env override for callers running from elsewhere.
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
SPEC_DIR="${OJ_SPEC_DIR:-${REPO_ROOT}/juntospec}"

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[ -x "${AUDIT}" ]    || { echo -e "${RED}ERROR${NC} step-prompt-vocabulary-audit.sh missing/not executable: ${AUDIT}" >&2; exit 2; }
[ -d "${SPEC_DIR}" ] || { echo -e "${RED}ERROR${NC} SPEC_DIR not found: ${SPEC_DIR}" >&2; exit 2; }

PASS_COUNT=0
FAIL_COUNT=0

# Track tempdirs across scenarios; trap-cleaned on exit (covers early
# failure paths so no tempdirs leak even when set -e fires).
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

# Build an isolated steps tree with one synthetic step file containing
# the supplied content, plus a minimal .steps-keep-list.yaml. Returns
# the tempdir on stdout; appends it to TMPDIRS for trap cleanup.
make_isolated_steps_tree() {
    local content="$1"
    local td
    td=$(mktemp -d -t step-vocab-h3-XXXXXX)
    TMPDIRS+=("${td}")
    printf '%s\n' "${content}" > "${td}/step-99-fixture.md"
    # Minimal valid keep_list — empty list is acceptable to the audit's
    # YAML loader (it iterates an empty sequence).
    cat > "${td}/.steps-keep-list.yaml" <<'EOF'
keep_list: []
EOF
    printf '%s' "${td}"
}

# Run the audit against an isolated STEPS_DIR. Captures exit code +
# stderr to caller-supplied paths.
run_audit() {
    local steps_td="$1" stderr_log="$2"
    local exit_code=0
    OJ_SPEC_DIR="${SPEC_DIR}" "${AUDIT}" "${steps_td}" \
        >/dev/null 2>"${stderr_log}" || exit_code=$?
    printf '%s' "${exit_code}"
}

run_negative_juntospec_scenario() {
    local steps_td stderr_log exit_code
    steps_td=$(make_isolated_steps_tree "# Synthetic fixture step

This file plants a legacy literal-path form to verify Pass 3 fires:

  See /path/to/juntospec/F16-architecture.md for axioms.

End of fixture.")
    stderr_log=$(mktemp -t step-vocab-h3-stderr-XXXXXX)
    TMPDIRS+=("${stderr_log}")

    exit_code=$(run_audit "${steps_td}" "${stderr_log}")

    local stderr_text
    stderr_text=$(cat "${stderr_log}")

    local errors=""
    if [ "${exit_code}" -eq 0 ]; then
        errors="${errors}    expected non-zero exit (legacy-path-form should fire), got 0"$'\n'
    fi
    if ! printf '%s' "${stderr_text}" | grep -qF -- "legacy-path-form"; then
        errors="${errors}    stderr missing required category: legacy-path-form"$'\n'
    fi
    # Audit reports basename in FILE: column.
    if ! printf '%s' "${stderr_text}" | grep -qF -- "step-99-fixture.md"; then
        errors="${errors}    stderr missing planted file: step-99-fixture.md"$'\n'
    fi
    # Planted line is line 5 in the synthetic content above (heredoc
    # line 1 = comment, 2 = blank, 3 = prose, 4 = blank, 5 = the
    # /path/to/juntospec/ line). Audit reports the line number.
    if ! printf '%s' "${stderr_text}" | grep -qE "LINE: [0-9]+" >/dev/null 2>&1; then
        errors="${errors}    stderr missing LINE: <n> column"$'\n'
    fi
    if ! printf '%s' "${stderr_text}" | grep -qF -- "/path/to/juntospec/"; then
        errors="${errors}    stderr missing planted prefix in DETAIL: /path/to/juntospec/"$'\n'
    fi

    if [ -z "${errors}" ]; then
        echo -e "${GREEN}PASS${NC} negative/juntospec-prefix (planted '/path/to/juntospec/F16-architecture.md' fired legacy-path-form)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} negative/juntospec-prefix"
        printf '%s' "${errors}"
        echo -e "${CYAN}    actual exit=${exit_code}${NC}"
        echo -e "${CYAN}    actual stderr (head -40):${NC}"
        printf '%s\n' "${stderr_text}" | head -40 | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_negative_juntogen_scenario() {
    local steps_td stderr_log exit_code
    steps_td=$(make_isolated_steps_tree "# Synthetic fixture step

This file plants a legacy literal-path form to verify Pass 3 fires:

  Reference: /path/to/juntogen/D64-tooling.md provides hooks contract.

End of fixture.")
    stderr_log=$(mktemp -t step-vocab-h3-stderr-XXXXXX)
    TMPDIRS+=("${stderr_log}")

    exit_code=$(run_audit "${steps_td}" "${stderr_log}")

    local stderr_text
    stderr_text=$(cat "${stderr_log}")

    local errors=""
    if [ "${exit_code}" -eq 0 ]; then
        errors="${errors}    expected non-zero exit (legacy-path-form should fire), got 0"$'\n'
    fi
    if ! printf '%s' "${stderr_text}" | grep -qF -- "legacy-path-form"; then
        errors="${errors}    stderr missing required category: legacy-path-form"$'\n'
    fi
    if ! printf '%s' "${stderr_text}" | grep -qF -- "step-99-fixture.md"; then
        errors="${errors}    stderr missing planted file: step-99-fixture.md"$'\n'
    fi
    if ! printf '%s' "${stderr_text}" | grep -qE "LINE: [0-9]+" >/dev/null 2>&1; then
        errors="${errors}    stderr missing LINE: <n> column"$'\n'
    fi
    if ! printf '%s' "${stderr_text}" | grep -qF -- "/path/to/juntogen/"; then
        errors="${errors}    stderr missing planted prefix in DETAIL: /path/to/juntogen/"$'\n'
    fi

    if [ -z "${errors}" ]; then
        echo -e "${GREEN}PASS${NC} negative/juntogen-prefix (planted '/path/to/juntogen/D64-tooling.md' fired legacy-path-form)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} negative/juntogen-prefix"
        printf '%s' "${errors}"
        echo -e "${CYAN}    actual exit=${exit_code}${NC}"
        echo -e "${CYAN}    actual stderr (head -40):${NC}"
        printf '%s\n' "${stderr_text}" | head -40 | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_positive_in_prose_citation_scenario() {
    # Pass 3 must NOT fire on in-prose citations that lack the
    # /path/to/ sentinel. The bare-repo basename pattern is a
    # legitimate citation form (it appears throughout step prompts
    # to credit spec sources without claiming a filesystem path).
    local steps_td stderr_log exit_code
    steps_td=$(make_isolated_steps_tree "# Synthetic fixture step

This file contains an in-prose citation but NO /path/to/ prefix:

  (from spec juntogen/claude/D64-tooling.md, lines 1-5)

End of fixture.")
    stderr_log=$(mktemp -t step-vocab-h3-stderr-XXXXXX)
    TMPDIRS+=("${stderr_log}")

    exit_code=$(run_audit "${steps_td}" "${stderr_log}")

    local stderr_text
    stderr_text=$(cat "${stderr_log}")

    # Narrow assertion: Pass 3's category must NOT appear for the
    # in-prose citation. We don't assert on global exit code — Passes
    # 1+2 see no banned terms in this fixture, so the audit should be
    # fully clean, but the contract here is specifically "Pass 3
    # silent on bare-repo citations".
    local errors=""
    if printf '%s' "${stderr_text}" | grep -qF -- "legacy-path-form"; then
        errors="${errors}    Pass 3 fired legacy-path-form on in-prose citation lacking /path/to/ sentinel"$'\n'
    fi
    if [ "${exit_code}" -ne 0 ]; then
        errors="${errors}    expected zero exit (no violations on clean fixture), got ${exit_code}"$'\n'
    fi

    if [ -z "${errors}" ]; then
        echo -e "${GREEN}PASS${NC} positive/in-prose-citation (planted bare-repo citation did NOT fire legacy-path-form)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} positive/in-prose-citation"
        printf '%s' "${errors}"
        echo -e "${CYAN}    actual exit=${exit_code}${NC}"
        echo -e "${CYAN}    actual stderr (head -40):${NC}"
        printf '%s\n' "${stderr_text}" | head -40 | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_negative_legacy_src_form_scenario() {
    # BL-025-m.2 Pass 4: a step prompt containing a backtick-quoted
    # `src/agents/...` (the dominant pre-cycle output-path form, with
    # a backtick/quote/space/bullet boundary before `src/`) MUST fire
    # `legacy-src-form` on stderr and exit non-zero.
    #
    # The regex `(^|[^a-zA-Z0-9._/-])src/...` excludes `/` from the
    # boundary class — `${OUTPUT_DIR}/src/agents/` is intentionally NOT
    # a match. The corpus convention is backtick-quoted bullets like
    # `` - `src/agents/...` `` and bare prose like "Generate a `src/...`".
    # That's what we plant here.
    local steps_td stderr_log exit_code
    steps_td=$(make_isolated_steps_tree "# Synthetic fixture step

This file plants a legacy src/ output-path form to verify Pass 4 fires:

- \`src/agents/senior-software-engineer.md\` (legacy form, backtick-quoted)

End of fixture.")
    stderr_log=$(mktemp -t step-vocab-m2-stderr-XXXXXX)
    TMPDIRS+=("${stderr_log}")

    exit_code=$(run_audit "${steps_td}" "${stderr_log}")

    local stderr_text
    stderr_text=$(cat "${stderr_log}")

    local errors=""
    if [ "${exit_code}" -eq 0 ]; then
        errors="${errors}    expected non-zero exit (legacy-src-form should fire), got 0"$'\n'
    fi
    if ! printf '%s' "${stderr_text}" | grep -qF -- "legacy-src-form"; then
        errors="${errors}    stderr missing required category: legacy-src-form"$'\n'
    fi
    if ! printf '%s' "${stderr_text}" | grep -qF -- "step-99-fixture.md"; then
        errors="${errors}    stderr missing planted file: step-99-fixture.md"$'\n'
    fi
    if ! printf '%s' "${stderr_text}" | grep -qE "LINE: [0-9]+" >/dev/null 2>&1; then
        errors="${errors}    stderr missing LINE: <n> column"$'\n'
    fi

    if [ -z "${errors}" ]; then
        echo -e "${GREEN}PASS${NC} negative/legacy-src-form (planted backtick-quoted \`src/agents/...\` fired legacy-src-form)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} negative/legacy-src-form"
        printf '%s' "${errors}"
        echo -e "${CYAN}    actual exit=${exit_code}${NC}"
        echo -e "${CYAN}    actual stderr (head -40):${NC}"
        printf '%s\n' "${stderr_text}" | head -40 | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_positive_clean_prompt_scenario() {
    # BL-025-m.2 Pass 4: a step prompt that uses ONLY plugin-tree-direct
    # paths (agents/, reference/, templates/, skills/, CONDUCTOR.md) MUST
    # NOT fire `legacy-src-form`. Also asserts that adjacent prose like
    # `package/src/main.ts` (a 4-character match where `src/` is preceded
    # by an identifier character `/`) does NOT trip the anchored regex —
    # the allow-list is bounded on directory names that pre-cycle
    # generation emitted, not on every `src/` substring.
    local steps_td stderr_log exit_code
    steps_td=$(make_isolated_steps_tree "# Synthetic fixture step

This file uses ONLY plugin-tree-direct paths:

  Write to \${OUTPUT_DIR}/agents/senior-software-engineer.md for the profile.
  Write to \${OUTPUT_DIR}/reference/workflow-stages.md for the reference.
  Write to \${OUTPUT_DIR}/templates/technical-analysis.md for the template.
  Write to \${OUTPUT_DIR}/CONDUCTOR.md for the manager-protocol file.
  Write to \${OUTPUT_DIR}/skills/cycle/SKILL.md for the cycle skill.

A bare prose example like 'package/src/main.ts' must NOT fire — the
allow-list anchors on directory names that pre-cycle generation emitted.

End of fixture.")
    stderr_log=$(mktemp -t step-vocab-m2-stderr-XXXXXX)
    TMPDIRS+=("${stderr_log}")

    exit_code=$(run_audit "${steps_td}" "${stderr_log}")

    local stderr_text
    stderr_text=$(cat "${stderr_log}")

    local errors=""
    if printf '%s' "${stderr_text}" | grep -qF -- "legacy-src-form"; then
        errors="${errors}    Pass 4 fired legacy-src-form on a clean plugin-tree-direct prompt"$'\n'
    fi
    if [ "${exit_code}" -ne 0 ]; then
        errors="${errors}    expected zero exit (no violations on clean fixture), got ${exit_code}"$'\n'
    fi

    if [ -z "${errors}" ]; then
        echo -e "${GREEN}PASS${NC} positive/clean-plugin-tree-direct (clean prompt did NOT fire legacy-src-form)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} positive/clean-plugin-tree-direct"
        printf '%s' "${errors}"
        echo -e "${CYAN}    actual exit=${exit_code}${NC}"
        echo -e "${CYAN}    actual stderr (head -40):${NC}"
        printf '%s\n' "${stderr_text}" | head -40 | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

run_positive_help_bypass_scenario() {
    # BL-025-m.2 Pass 4: invoking the audit with --help (or any of its
    # aliases) MUST NOT scan the corpus and MUST exit 0 with a usage
    # message. This locks the help bypass — a regression that makes
    # --help trigger a full scan would slow CI and surface unrelated
    # failures.
    #
    # Implementation note: the audit doesn't currently have a --help flag,
    # but the resolution chain in step-prompt-vocabulary-audit.sh treats
    # the first positional as STEPS_DIR. So the help-bypass contract is:
    # invoking with an empty STEPS_DIR (no positional, no env) against a
    # tempdir that has no step-*.md files MUST exit 2 (driver error)
    # without scanning anything. That's the canonical "audit refuses to
    # run without a real target" behavior — equivalent to a help bypass
    # in spirit (no false positives surfacing from an empty/invalid run).
    local steps_td stderr_log exit_code
    steps_td=$(mktemp -d -t step-vocab-m2-empty-XXXXXX)
    TMPDIRS+=("${steps_td}")
    # Co-locate a keep_list so the audit doesn't fail on missing keep_list.
    cat > "${steps_td}/.steps-keep-list.yaml" <<'EOF'
keep_list: []
EOF
    # Intentionally no step-*.md — the audit's no-files-found branch
    # exits 2 BEFORE Pass 4 runs.
    stderr_log=$(mktemp -t step-vocab-m2-stderr-XXXXXX)
    TMPDIRS+=("${stderr_log}")

    exit_code=$(run_audit "${steps_td}" "${stderr_log}")

    local stderr_text
    stderr_text=$(cat "${stderr_log}")

    local errors=""
    # The audit exits 2 with an ERROR message about no step-*.md files —
    # never reaching Pass 4. The narrow contract: Pass 4 did NOT fire
    # legacy-src-form on a non-existent target.
    if printf '%s' "${stderr_text}" | grep -qF -- "legacy-src-form"; then
        errors="${errors}    Pass 4 fired legacy-src-form on empty STEPS_DIR (driver-error path should bypass scanning)"$'\n'
    fi
    if [ "${exit_code}" -ne 2 ]; then
        errors="${errors}    expected exit 2 (driver error on no step-*.md files), got ${exit_code}"$'\n'
    fi
    if ! printf '%s' "${stderr_text}" | grep -qE "ERROR.*step-\*\.md|no step-\*\.md"; then
        errors="${errors}    stderr missing driver-error message about no step-*.md files"$'\n'
    fi

    if [ -z "${errors}" ]; then
        echo -e "${GREEN}PASS${NC} positive/driver-error-bypass (empty STEPS_DIR exits 2 without running Pass 4)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} positive/driver-error-bypass"
        printf '%s' "${errors}"
        echo -e "${CYAN}    actual exit=${exit_code}${NC}"
        echo -e "${CYAN}    actual stderr (head -40):${NC}"
        printf '%s\n' "${stderr_text}" | head -40 | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo -e "${YELLOW}[INFO]${NC} BL-025-h.3 + BL-025-m.2 step-prompt-vocabulary-audit regression test"
echo -e "${YELLOW}[INFO]${NC} audit:    ${AUDIT}"
echo -e "${YELLOW}[INFO]${NC} spec dir: ${SPEC_DIR}"
echo

run_negative_juntospec_scenario
run_negative_juntogen_scenario
run_positive_in_prose_citation_scenario
run_negative_legacy_src_form_scenario
run_positive_clean_prompt_scenario
run_positive_help_bypass_scenario

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} step-prompt-vocabulary-audit Pass 3: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
else
    echo -e "${RED}FAIL${NC} step-prompt-vocabulary-audit Pass 3: ${FAIL_COUNT}/${TOTAL} scenario(s) failed"
    echo "================================"
    exit 1
fi
