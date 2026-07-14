#!/usr/bin/env bash
#
# tier-a-assertions.sh - Tier A structural assertions for the plugin-tree-direct
#                       OpenJunto installation (BL-025-m.1 retarget).
#
# PURPOSE: Validate structural properties of the generated OpenJunto plugin
#          tree using section-bounded awk extraction (prevents cross-section
#          bleed) for the manager-protocol-file assertions, plus per-surface
#          iteration for the hygiene assertions.
#
# SCOPE (BL-025-m.1):
#   - Manager-protocol-file assertions target ${OUTPUT_DIR}/CONDUCTOR.md
#     (pre-cycle: src/CLAUDE.md).
#   - Hygiene assertions iterate the whole plugin tree at ${OUTPUT_DIR}
#     (pre-cycle: src/{commands,agents,reference,templates}).
#   - Core spec-corpus assertions (§13–§16) are unchanged — they target the
#     juntospec spec corpus regardless of plugin-tree shape.
#   - Assertion 0 (loader smoke per DE F7) is new in m.1 — runs
#     ${OUTPUT_DIR}/scripts/validate-plugin.sh as the gate to coverage drop.
#
# USAGE: ./tier-a-assertions.sh [OUTPUT_DIR]
#        OUTPUT_DIR defaults to the sibling oj-claude checkout (<parent>/oj-claude,
#                            resolved from this script's location) when invoked
#        without an argument and OJ_OUTPUT_DIR is unset.
#
# EXIT CODES:
#   0 - All assertions passed
#   1 - One or more assertions failed
#   2 - Target tree not found / loader smoke failed (Assertion 0)

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo -e "${GREEN}PASS${NC} $*"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}FAIL${NC} $*"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
}

# BL-025-m.1: target the plugin-tree root, not a single manager-protocol file.
# Resolution order:
#   1. positional argument $1 (explicit OUTPUT_DIR)
#   2. ${OJ_OUTPUT_DIR} env var
#   3. canonical hand-cut baseline (oj-claude under the openjunto workspace)
# Default to the sibling oj-claude checkout resolved from this script's location
# (<parent>/oj-claude, sibling to juntogen/); override via $1 or OJ_OUTPUT_DIR.
_JG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUTPUT_DIR="${1:-${OJ_OUTPUT_DIR:-$(dirname "${_JG_ROOT}")/oj-claude}}"

if [[ ! -d "${OUTPUT_DIR}" ]]; then
    echo -e "${RED}ERROR${NC} OUTPUT_DIR is not a directory: ${OUTPUT_DIR}"
    echo "Usage: $0 [OUTPUT_DIR]"
    echo "Resolution: \$1 > \$OJ_OUTPUT_DIR > default (oj-claude hand-cut baseline)"
    exit 2
fi

# Resolve to absolute path
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

# CONDUCTOR.md is the manager-protocol file post-BL-025-i.2; src/CLAUDE.md is retired.
TARGET_FILE="${OUTPUT_DIR}/CONDUCTOR.md"
# v0.1.0 CONDUCTOR slim: the execution mechanics (quality-gate tier checklists
# and handback formats) moved out of the always-injected CONDUCTOR core into the
# on-demand reference/execution-protocol.md. Assertions 1 and 6 target this file;
# the delegation Self-Check and Circuit Breaker stayed in CONDUCTOR.md.
EXEC_PROTO_FILE="${OUTPUT_DIR}/reference/execution-protocol.md"

if [[ ! -f "${TARGET_FILE}" ]]; then
    echo -e "${RED}ERROR${NC} CONDUCTOR.md not found at ${TARGET_FILE}"
    echo "  (was the plugin-tree-direct generation completed?)"
    exit 2
fi

info "Running Tier A structural assertions against plugin tree: ${OUTPUT_DIR}"
info "Manager protocol target: ${TARGET_FILE}"
echo ""

# ---------------------------------------------------------------------------
# ASSERTION 0 (BL-025-m.1 / DE F7): loader smoke — independent oracle.
# Runs ${OUTPUT_DIR}/scripts/validate-plugin.sh. If the plugin tree fails
# the BL-025-k structural validator, no downstream Tier A check is
# meaningful; abort hard so the operator fixes the loader-level breakage
# first.
#
# Rationale: the frozen-manifest snapshot encodes today's tree shape but
# cannot prove loader-correctness on its own (DE STRONGEST OBJECTION).
# Running validate-plugin.sh up front guarantees the tree is loadable by
# the Claude plugin host BEFORE we start asserting structural invariants
# on its contents.
# ---------------------------------------------------------------------------
info "Assertion 0 (BL-025-m.1): loader smoke — validate-plugin.sh"

VALIDATE_PLUGIN="${OUTPUT_DIR}/scripts/validate-plugin.sh"
if [[ ! -x "${VALIDATE_PLUGIN}" ]]; then
    fail "Assertion 0: validate-plugin.sh missing or not executable at ${VALIDATE_PLUGIN}"
    echo "  (BL-025-k harness expected at <OUTPUT_DIR>/scripts/validate-plugin.sh)"
else
    # Run with --no-claude in non-CI contexts (CI re-runs without the flag).
    # Either way we treat non-zero as a hard abort: tier-a downstream checks
    # are not meaningful against a tree that can't load.
    if bash "${VALIDATE_PLUGIN}" --no-claude >/tmp/tier-a-validate-plugin.$$ 2>&1; then
        pass "Assertion 0: validate-plugin.sh exits 0 (plugin tree is loadable)"
    else
        fail "Assertion 0: validate-plugin.sh exited non-zero — plugin tree is not loadable"
        echo "  (last 20 lines of validate-plugin output:)"
        tail -20 /tmp/tier-a-validate-plugin.$$ | sed 's/^/    /'
        rm -f /tmp/tier-a-validate-plugin.$$
        # Hard abort: downstream Tier A assertions are not meaningful.
        echo ""
        echo -e "${RED}ERROR${NC} Tier A aborted: loader smoke failed (Assertion 0). Fix loader issues first."
        exit 2
    fi
    rm -f /tmp/tier-a-validate-plugin.$$
fi

echo ""

# ---------------------------------------------------------------------------
# BL-025-e.1: Load banned_terms from platform-contract.yaml once and dispatch
# per `assertion:` field. Replaces the hard-coded regex literals previously
# inlined in §13/§14/§15/§16. Single source of truth: contributors extend
# tier-a hygiene by adding a banned_terms entry with the appropriate
# `assertion:` value rather than editing this script.
#
# BL-025-f: validation/ moved into juntogen. SPEC_ROOT now resolves via:
#   1. ${OJ_SPEC_DIR}      environment variable
#   2. sibling probe       juntogen ↔ juntospec under common parent
#                          (script lives at juntogen/claude/validation/scripts/,
#                          so juntospec sibling is 4 levels up)
#   3. hard-fail           actionable message naming both surfaces
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -n "${OJ_SPEC_DIR:-}" ]; then
    SPEC_ROOT="${OJ_SPEC_DIR}"
elif [ -d "${SCRIPT_DIR}/../../../../juntospec" ]; then
    SPEC_ROOT="$(cd "${SCRIPT_DIR}/../../../../juntospec" && pwd)"
else
    echo -e "${RED}ERROR${NC} cannot locate juntospec corpus root. Provide one of:"
    echo "  OJ_SPEC_DIR=DIR (env)    exported environment variable"
    echo "  sibling layout           juntogen/ and juntospec/ as siblings under"
    echo "                           a common parent (recommended; e.g."
    echo "                           /path/to/openjunto/{juntogen,juntospec})."
    echo "Searched: \$OJ_SPEC_DIR (unset), sibling probe at"
    echo "${SCRIPT_DIR}/../../../../juntospec (not a directory)."
    exit 2
fi

if [[ ! -d "${SPEC_ROOT}" ]]; then
    echo -e "${RED}ERROR${NC} SPEC_ROOT is not a directory: ${SPEC_ROOT}"
    exit 2
fi

PARSE_PY="${SCRIPT_DIR}/lib/parse-contract.py"
CONTRACT_YAML="${SPEC_ROOT}/platform-contract.yaml"

if [[ ! -f "${PARSE_PY}" ]]; then
    echo -e "${RED}ERROR${NC} parse-contract.py missing at ${PARSE_PY}"
    exit 2
fi
if [[ ! -f "${CONTRACT_YAML}" ]]; then
    echo -e "${RED}ERROR${NC} platform-contract.yaml missing at ${CONTRACT_YAML}"
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}ERROR${NC} python3 not on PATH (required by parse-contract.py)"
    exit 2
fi

# Escape awk-regex metacharacters in a literal string. Covers the metachars
# that appear or could appear in literal banned_terms entries: `\`, `.`,
# `/`, `[`, `]`, `(`, `)`, `|`, `+`, `*`, `?`, `^`, `$`. Curly braces are
# intentionally omitted — BSD awk does not consistently support `{m,n}`
# quantifiers as ERE, and no current literal banned_term contains `{`/`}`.
# Uses sed (single-pass, no parameter-expansion bracketing pitfalls) for
# portability — the bash `${var//pattern/replacement}` form mis-parses
# replacement strings ending in `}`.
escape_awk_regex() {
    # Backslash first so subsequent escapes don't double-escape.
    printf '%s' "$1" | sed -e 's:\\:\\\\:g' \
                           -e 's:\.:\\.:g' \
                           -e 's:/:\\/:g' \
                           -e 's:\[:\\[:g' \
                           -e 's:\]:\\]:g' \
                           -e 's:(:\\(:g' \
                           -e 's:):\\):g' \
                           -e 's:|:\\|:g' \
                           -e 's:+:\\+:g' \
                           -e 's:\*:\\*:g' \
                           -e 's:?:\\?:g' \
                           -e 's:\^:\\^:g' \
                           -e 's:\$:\\$:g'
}

# Per-assertion regex variables, built from banned_terms by `assertion:` field.
A13_LITERALS=()   # tracks the literal terms picked up for §13 (alternation)
A14_LITERAL=""    # single literal for §14
A15_LITERAL=""    # single literal for §15
A16_REGEX=""      # verbatim regex pulled from banned_terms

while IFS=$'\t' read -r bt_term bt_kind bt_scope bt_regions bt_assertion; do
    [[ -z "${bt_term}" ]] && continue
    case "${bt_assertion}" in
        s13)
            # §13 expects literal platform-tool names assembled into an
            # awk-regex alternation. Each term is escaped so that any future
            # entry containing regex metacharacters still matches as a literal.
            A13_LITERALS+=("$(escape_awk_regex "${bt_term}")")
            ;;
        s14)
            A14_LITERAL="$(escape_awk_regex "${bt_term}")"
            ;;
        s15)
            A15_LITERAL="$(escape_awk_regex "${bt_term}")"
            ;;
        s16)
            # §16 is a regex-kind term — used verbatim, not escaped.
            A16_REGEX="${bt_term}"
            ;;
        "")
            # Entry without `assertion:` — vocabulary-audit still consumes it
            # (kind+term suffice for the audit), but tier-a has no section to
            # dispatch it to. Skip silently rather than fail; tier-a only
            # asserts the subset of banned_terms with explicit assertion tags.
            :
            ;;
        *)
            echo -e "${RED}ERROR${NC} unknown assertion '${bt_assertion}' in banned_terms entry term='${bt_term}' (expected one of: s13, s14, s15, s16)"
            exit 2
            ;;
    esac
done < <(python3 "${PARSE_PY}" banned-terms "${CONTRACT_YAML}")

# Compose §13 alternation regex: (a|b|c|d). Empty alternation would degenerate
# to `()` which matches every line — guard with a non-matching sentinel that
# never appears in markdown so an empty mapping fails closed (zero hits)
# rather than open (every line a hit).
if [[ ${#A13_LITERALS[@]} -gt 0 ]]; then
    A13_BANNED_REGEX="($(IFS='|'; printf '%s' "${A13_LITERALS[*]}"))"
else
    A13_BANNED_REGEX='__no_s13_terms_in_contract__'
fi

# §14/§15 use a single literal each. Empty mapping → sentinel (non-matching).
A14_BANNED_REGEX="${A14_LITERAL:-__no_s14_term_in_contract__}"
A15_BANNED_REGEX="${A15_LITERAL:-__no_s15_term_in_contract__}"
# §16: verbatim regex from contract; empty mapping → sentinel.
A16_BANNED_REGEX="${A16_REGEX:-__no_s16_term_in_contract__}"

# ---------------------------------------------------------------------------
# ASSERTION 1: Quality gate item counts
# Expected: Simple tier = 2 items, Moderate tier = 6 items, Complex tier = 9 items
# ---------------------------------------------------------------------------
info "Assertion 1: Quality gate item counts"

# Simple Tier — section-bounded extraction stops at next ###, ##, or ---
SIMPLE_HEADER_FOUND=$(awk '/^### Simple Tier \(2 items\)/{print 1; exit}' "${EXEC_PROTO_FILE}")
if [[ -z "${SIMPLE_HEADER_FOUND}" ]]; then
    fail "Section header not found: '### Simple Tier (2 items)'"
else
    SIMPLE_GATES=$(awk '/^### Simple Tier \(2 items\)/{found=1; next} found && /^(###|##|---)/{exit} found && /^- \[ \]/{count++} END{print count+0}' "${EXEC_PROTO_FILE}")
    if [[ "${SIMPLE_GATES}" -eq 2 ]]; then
        pass "Simple tier quality gates: ${SIMPLE_GATES} items (expected 2)"
    else
        fail "Simple tier quality gates: ${SIMPLE_GATES} items (expected 2)"
    fi
fi

# Moderate Tier
MODERATE_HEADER_FOUND=$(awk '/^### Moderate Tier \(6 items\)/{print 1; exit}' "${EXEC_PROTO_FILE}")
if [[ -z "${MODERATE_HEADER_FOUND}" ]]; then
    fail "Section header not found: '### Moderate Tier (6 items)'"
else
    MODERATE_GATES=$(awk '/^### Moderate Tier \(6 items\)/{found=1; next} found && /^(###|##|---)/{exit} found && /^- \[ \]/{count++} END{print count+0}' "${EXEC_PROTO_FILE}")
    if [[ "${MODERATE_GATES}" -eq 6 ]]; then
        pass "Moderate tier quality gates: ${MODERATE_GATES} items (expected 6)"
    else
        fail "Moderate tier quality gates: ${MODERATE_GATES} items (expected 6)"
    fi
fi

# Complex Tier
COMPLEX_HEADER_FOUND=$(awk '/^### Complex Tier \(9 items\)/{print 1; exit}' "${EXEC_PROTO_FILE}")
if [[ -z "${COMPLEX_HEADER_FOUND}" ]]; then
    fail "Section header not found: '### Complex Tier (9 items)'"
else
    COMPLEX_GATES=$(awk '/^### Complex Tier \(9 items\)/{found=1; next} found && /^(###|##|---)/{exit} found && /^- \[ \]/{count++} END{print count+0}' "${EXEC_PROTO_FILE}")
    if [[ "${COMPLEX_GATES}" -eq 9 ]]; then
        pass "Complex tier quality gates: ${COMPLEX_GATES} items (expected 9)"
    else
        fail "Complex tier quality gates: ${COMPLEX_GATES} items (expected 9)"
    fi
fi

echo ""

# ---------------------------------------------------------------------------
# ASSERTION 2: Triage criteria count
# Expected: Exactly 4 criteria in the Execution Model section only
# ---------------------------------------------------------------------------
info "Assertion 2: Triage criteria count"

EXEC_HEADER_FOUND=$(awk '/^### A\. Execution Model/{print 1; exit}' "${TARGET_FILE}")
if [[ -z "${EXEC_HEADER_FOUND}" ]]; then
    fail "Section header not found: '### A. Execution Model'"
else
    TRIAGE_CRITERIA=$(awk '/^### A\. Execution Model/{found=1; next} found && /^###/{exit} found && /^\| [0-9] \|/{count++} END{print count+0}' "${TARGET_FILE}")
    if [[ "${TRIAGE_CRITERIA}" -eq 4 ]]; then
        pass "Triage criteria: ${TRIAGE_CRITERIA} (expected 4)"
    else
        fail "Triage criteria: ${TRIAGE_CRITERIA} (expected 4)"
    fi
fi

echo ""

# ---------------------------------------------------------------------------
# ASSERTION 3: PERSPECTIVE block format
# Expected: 4-line format (PERSPECTIVE/LENS/ASSESSMENT/CONCERN) all present
# ---------------------------------------------------------------------------
info "Assertion 3: PERSPECTIVE block format"

HAS_PERSPECTIVE=$(awk '/^PERSPECTIVE:/{count++} END{print count+0}' "${TARGET_FILE}")
HAS_LENS=$(awk '/^LENS:/{count++} END{print count+0}' "${TARGET_FILE}")
HAS_ASSESSMENT=$(awk '/^ASSESSMENT:/{count++} END{print count+0}' "${TARGET_FILE}")
HAS_CONCERN=$(awk '/^CONCERN:/{count++} END{print count+0}' "${TARGET_FILE}")

if [[ "${HAS_PERSPECTIVE}" -ge 1 ]] && [[ "${HAS_LENS}" -ge 1 ]] && \
   [[ "${HAS_ASSESSMENT}" -ge 1 ]] && [[ "${HAS_CONCERN}" -ge 1 ]]; then
    pass "PERSPECTIVE block format: all 4 fields present (PERSPECTIVE/LENS/ASSESSMENT/CONCERN)"
else
    fail "PERSPECTIVE block format: missing fields (found P:${HAS_PERSPECTIVE} L:${HAS_LENS} A:${HAS_ASSESSMENT} C:${HAS_CONCERN})"
fi

echo ""

# ---------------------------------------------------------------------------
# ASSERTION 4: Delegation self-check questions
# Expected: 4 numbered questions (v0.1.0 added item 0 — the orchestration-scope
# carve-out gating the delegation boundary — ahead of the original 3).
# ---------------------------------------------------------------------------
info "Assertion 4: Delegation self-check questions"

SELFCHECK_HEADER_FOUND=$(awk '/\*\*Self-Check\*\*/{print 1; exit}' "${TARGET_FILE}")
if [[ -z "${SELFCHECK_HEADER_FOUND}" ]]; then
    fail "Section header not found: '**Self-Check**'"
else
    SELF_CHECK_QUESTIONS=$(awk '/\*\*Self-Check\*\*/{found=1; next} found && /^(###|##|---)/{exit} found && /^[0-9]\. /{count++} END{print count+0}' "${TARGET_FILE}")
    if [[ "${SELF_CHECK_QUESTIONS}" -eq 4 ]]; then
        pass "Delegation self-check: ${SELF_CHECK_QUESTIONS} questions (expected 4)"
    else
        fail "Delegation self-check: ${SELF_CHECK_QUESTIONS} questions (expected 4)"
    fi
fi

echo ""

# ---------------------------------------------------------------------------
# ASSERTION 5: Circuit breaker conditions
# Expected: Exactly 4 bullet conditions in circuit breaker section
# ---------------------------------------------------------------------------
info "Assertion 5: Circuit breaker conditions"

CIRCUIT_HEADER_FOUND=$(awk '/^### Circuit Breaker/{print 1; exit}' "${TARGET_FILE}")
if [[ -z "${CIRCUIT_HEADER_FOUND}" ]]; then
    fail "Section header not found: '### Circuit Breaker'"
else
    CIRCUIT_CONDITIONS=$(awk '/^### Circuit Breaker/{found=1; next} found && /^(###|##|---)/{exit} found && /^- /{count++} END{print count+0}' "${TARGET_FILE}")
    if [[ "${CIRCUIT_CONDITIONS}" -eq 4 ]]; then
        pass "Circuit breaker conditions: ${CIRCUIT_CONDITIONS} (expected 4)"
    else
        fail "Circuit breaker conditions: ${CIRCUIT_CONDITIONS} (expected 4)"
    fi
fi

echo ""

# ---------------------------------------------------------------------------
# ASSERTION 6: Handback field counts
# Expected: Simple = 5 fields, Moderate/Complex >= 9 fields
# Uses fenced code block extraction scoped to the relevant anchor line.
#
# TODO(BL-015 root-cause): pin [EXACT] anchors in step-01 prompt — deferred
# per 2026-04-17 cycle (Theme A — spec-test coupling). Symptom fix applied
# here: anchor regex is case-insensitive (tolower() — portable across BSD/GNU
# awk), and we require the counted fenced block to contain HANDBACK: on its
# first non-empty line as a belt-and-braces guard against unrelated code
# blocks sitting between the anchor and the handback example.
# ---------------------------------------------------------------------------
info "Assertion 6: Handback field counts"

# Simple handback: extract first fenced code block after "compressed format" anchor.
# Case-insensitive match via tolower() to tolerate Title-Case generator output
# ("Compressed format (~5 lines):"). Secondary HANDBACK: guard ensures we only
# count the handback example block, not an unrelated code fence.
SIMPLE_HANDBACK_FIELDS=$(awk '
    tolower($0) ~ /compressed format/ { found=1; next }
    found && /^```/ {
        if (inblock) { exit }
        inblock=1; first=1; next
    }
    found && inblock && NF {
        if (first) {
            first=0
            if ($0 !~ /HANDBACK:/) { inblock=0; next }
        }
        count++
    }
    END { print count+0 }
' "${EXEC_PROTO_FILE}")

if [[ "${SIMPLE_HANDBACK_FIELDS}" -ge 5 ]]; then
    pass "Simple handback format: ${SIMPLE_HANDBACK_FIELDS} fields (expected >=5)"
else
    fail "Simple handback format: ${SIMPLE_HANDBACK_FIELDS} fields (expected >=5)"
fi

# Moderate/Complex handback: extract first fenced code block after "full format" anchor.
# Same case-insensitive + HANDBACK: guard treatment as Simple above.
COMPLEX_HANDBACK_FIELDS=$(awk '
    tolower($0) ~ /full format/ { found=1; next }
    found && /^```/ {
        if (inblock) { exit }
        inblock=1; first=1; next
    }
    found && inblock && NF {
        if (first) {
            first=0
            if ($0 !~ /HANDBACK:/) { inblock=0; next }
        }
        count++
    }
    END { print count+0 }
' "${EXEC_PROTO_FILE}")

if [[ "${COMPLEX_HANDBACK_FIELDS}" -ge 9 ]]; then
    pass "Moderate/Complex handback format: ${COMPLEX_HANDBACK_FIELDS} fields (expected >=9)"
else
    fail "Moderate/Complex handback format: ${COMPLEX_HANDBACK_FIELDS} fields (expected >=9)"
fi

echo ""

# ---------------------------------------------------------------------------
# ASSERTION 7: Org-content hygiene — no bare issue tracker-style ticket IDs in prose
# issue tracker IDs (pattern: [A-Z]{2,10}-[0-9]+) are allowed only inside:
#   - fenced code blocks (``` ... ```)
#   - backtick-quoted inline code spans (`...`)
# ---------------------------------------------------------------------------
info "Assertion 7: Org-content hygiene (no bare issue tracker-style IDs in prose)"

ORG_VIOLATIONS=$(awk '
    /^```/ { in_block = !in_block; next }
    in_block { next }
    {
        line = $0
        # Strip backtick inline code spans
        gsub(/`[^`]*`/, "", line)
        # Strip known-safe technical standard patterns (e.g. SHA-256, ISO-8601, HTTP-2).
        # Note: \b word boundaries are omitted — not portable in BSD awk (macOS);
        # the prefix lists are specific enough to avoid false negatives without them.
        gsub(/(SHA|ISO|UTF|HTTP|HTTPS|TLS|SSL|TCP|UDP|XML|HTML|CSS|SQL)-[0-9]+[a-zA-Z0-9]*/, "", line)
        # Strip spec-internal measurement/test IDs (MR-NNN, DEL-NNN, QG-NNN, TIER-NNN,
        # CB-NNN, SE-NNN, SH-NNN, BL-NNN, M-XX-NN, H-NNN).
        gsub(/(MR|DEL|QG|TIER|CB|SE|SH|BL)-[0-9]+/, "", line)
        gsub(/M-[A-Z]+-[0-9]+/, "", line)
        gsub(/H-[0-9]+/, "", line)
        # Check for remaining issue tracker-style IDs
        if (line ~ /[A-Z][A-Z][A-Z]*-[0-9][0-9]*/) {
            print NR": "line
        }
    }
' "${TARGET_FILE}")

if [[ -z "${ORG_VIOLATIONS}" ]]; then
    pass "Org-content hygiene: no bare issue tracker-style IDs found in prose"
else
    fail "Org-content hygiene: bare issue tracker-style IDs found in prose (allowed only in code blocks/spans):"
    echo "${ORG_VIOLATIONS}" | while IFS= read -r line; do
        echo "  ${line}"
    done
fi

echo ""

# ---------------------------------------------------------------------------
# ASSERTION 11 (BL-025-m.1 retarget): Legacy helper/marker hygiene —
# no toe-helper or toe-expert anywhere in the adopter-visible plugin tree.
# Rationale: Prior to BL-025-i.2, a stale `toe-helper feedback-path`
# invocation in an installed command silently broke dev-mode Phase 5 for
# every adopter. This assertion fails generation loudly if legacy helper/marker
# tokens leak into any adopter-visible generated file. Scans agents/, reference/,
# templates/, skills/, CONDUCTOR.md (the surfaces a Claude plugin host loads).
# bin/oj-helper is intentionally out of scope — it legitimately accepts
# legacy invocation forms for one-release backward compatibility.
# ---------------------------------------------------------------------------
info "Assertion 11 (BL-025-m.1): No legacy toe-helper/toe-expert tokens in adopter-visible plugin tree"

# BL-025-m.1: scan the plugin tree directly. Use OUTPUT_DIR (resolved above).
PLUGIN_ROOT="${OUTPUT_DIR}"

LEGACY_HITS=""
# Adopter-visible surfaces: agents/, reference/, templates/, skills/.
# (commands/ removed — flat plugin layout uses skills/<name>/SKILL.md.)
for subdir in agents reference templates skills; do
    scan_dir="${PLUGIN_ROOT}/${subdir}"
    if [[ -d "${scan_dir}" ]]; then
        # grep -R matches markdown and any other text; -E for alternation.
        # Guard with `|| true` so a clean directory (no matches, exit 1) does not trip set -e.
        hits=$(grep -RnE 'toe-helper|toe-expert' "${scan_dir}" 2>/dev/null || true)
        if [[ -n "${hits}" ]]; then
            LEGACY_HITS="${LEGACY_HITS}${hits}"$'\n'
        fi
    fi
done

# Also scan CONDUCTOR.md at the plugin root (the new manager-protocol file).
for rootfile in "${PLUGIN_ROOT}/CONDUCTOR.md"; do
    if [[ -f "${rootfile}" ]]; then
        hits=$(grep -nE 'toe-helper|toe-expert' "${rootfile}" 2>/dev/null \
               | sed "s|^|${rootfile}:|" \
               || true)
        if [[ -n "${hits}" ]]; then
            LEGACY_HITS="${LEGACY_HITS}${hits}"$'\n'
        fi
    fi
done

if [[ -z "${LEGACY_HITS}" ]]; then
    pass "Legacy hygiene: no toe-helper/toe-expert tokens in adopter-visible plugin tree (agents/, reference/, templates/, skills/, CONDUCTOR.md)"
else
    fail "Legacy hygiene: toe-helper/toe-expert tokens found in adopter-visible plugin tree:"
    echo "${LEGACY_HITS}" | while IFS= read -r line; do
        [[ -n "${line}" ]] && echo "  ${line}"
    done
fi

echo ""

# ---------------------------------------------------------------------------
# ASSERTION 12: junto-* rename hygiene — no legacy junto-helper, junto-expert,
# JUNTO_* env var references, or .junto-{version,settings-hash,workspace}
# dotfile references in the adopter-visible generated surface. These must
# rename to oj-helper, oj-expert, OJ_*, and .oj-* respectively.
# Rationale: BL-013 Tier 2 enforces the junto → oj rename across identifiers
# while keeping brand prose as OpenJunto. The oj-helper binary itself and
# the Makefile migrate-dotfiles + settings merge targets intentionally
# reference the legacy tokens for one-release backward compatibility —
# those locations are out of scope here (Makefile is checked by assert-hooks,
# not tier-a). This assertion scans the same adopter-visible surface as
# Assertion 11 PLUS src/CLAUDE.md and src/settings.json.
# ---------------------------------------------------------------------------
info "Assertion 12: No legacy junto-* identifier tokens in adopter-visible src/"

# Transition-note exemption (ANCHORED — hardened after Phase 3 reviewer P0):
#
# Earlier version used an UNANCHORED `grep -Ev 'legacy|fallback|backward.compat|one.release'`
# which was exploitable — any line containing one of those words (even in an
# unrelated clause) bypassed the hygiene gate. A malicious or careless line like
#   This is live code: junto-helper --foo <!-- legacy docs below -->
# would have silently slipped through.
#
# The exemption now requires BOTH conditions on the same line:
#   (1) EVERY occurrence of the forbidden junto-* token is inside a backtick
#       inline code span (i.e., after stripping `...` runs the token disappears), AND
#   (2) the line contains at least one transition keyword (legacy | fallback |
#       backward.compat | one.release) OUTSIDE a backtick span (so the
#       transition intent is visible in prose, not smuggled inside code).
#
# Lines that fail either condition remain hits. Implementation uses awk for
# proper per-line parsing — regex alone cannot reliably enforce "token is
# inside backticks" because it is a balanced-delimiter property.
#
# Verification (manual smoke test after changes to this block):
#   (a) `This is live code: junto-helper --foo <!-- legacy docs below -->`
#       MUST fail Assertion 12 (live token outside backticks).
#   (b) `<!-- legacy: accepts \`junto-helper\` for one release -->`
#       MUST pass Assertion 12 (token inside backticks, transition keyword in prose).

filter_junto_hits() {
    awk '
    {
        raw = $0
        stripped = raw
        # Strip all backtick-delimited inline code spans. Non-greedy via char class.
        gsub(/`[^`]*`/, "", stripped)
        # (1) Token outside backticks? If the stripped line still contains a
        #     forbidden junto-* token, the line is NOT eligible for exemption.
        token_outside = (stripped ~ /junto-helper|junto-expert|JUNTO_[A-Z]|\.junto-(version|settings-hash|workspace)/)
        # (2) Transition keyword in prose (outside backticks)?
        kw_in_prose = (stripped ~ /(legacy|fallback|backward[-. ]compat|one[-. ]release)/)
        if (!token_outside && kw_in_prose) {
            # Exempted transition note — skip.
            next
        }
        print raw
    }'
}

JUNTO_HITS=""
# BL-025-m.1: scan adopter-visible surfaces in the plugin tree.
# (commands/ removed — flat plugin layout uses skills/<name>/SKILL.md.)
for subdir in agents reference templates skills; do
    scan_dir="${PLUGIN_ROOT}/${subdir}"
    if [[ -d "${scan_dir}" ]]; then
        # Rename-forbidden patterns:
        #   junto-helper   — installed binary name
        #   junto-expert   — HTML spawn marker
        #   JUNTO_[A-Z]    — env var family (JUNTO_DEVMODE, JUNTO_HOOK_DEBUG, JUNTO_SOURCE)
        #   \.junto-(version|settings-hash|workspace) — installed dotfile markers
        hits=$(grep -RnE 'junto-helper|junto-expert|JUNTO_[A-Z]|\.junto-(version|settings-hash|workspace)' "${scan_dir}" 2>/dev/null \
               | filter_junto_hits \
               || true)
        if [[ -n "${hits}" ]]; then
            JUNTO_HITS="${JUNTO_HITS}${hits}"$'\n'
        fi
    fi
done

# BL-025-m.1: scan CONDUCTOR.md at the plugin root (new manager-protocol file).
# settings.json is NOT shipped by the plugin (user-configured), so it drops
# out of scope. README.md / WHY.md at the root carry user-facing transition-
# note prose with legitimate `junto-helper` references inside fenced code
# blocks and inline `code` spans (one-release backward-compat upgrade
# instructions); they're out of scope here. The original pre-cycle scan
# covered src/CLAUDE.md + src/settings.json — CONDUCTOR.md is the
# post-cycle equivalent of CLAUDE.md, and settings.json no longer ships,
# so this loop intentionally has a single entry.
for rootfile in "${PLUGIN_ROOT}/CONDUCTOR.md"; do
    if [[ -f "${rootfile}" ]]; then
        hits=$(grep -nE 'junto-helper|junto-expert|JUNTO_[A-Z]|\.junto-(version|settings-hash|workspace)' "${rootfile}" 2>/dev/null \
               | filter_junto_hits \
               | sed "s|^|${rootfile}:|" \
               || true)
        if [[ -n "${hits}" ]]; then
            JUNTO_HITS="${JUNTO_HITS}${hits}"$'\n'
        fi
    fi
done

if [[ -z "${JUNTO_HITS}" ]]; then
    pass "junto-* rename hygiene: no legacy junto-helper/junto-expert/JUNTO_*/.junto-* tokens in adopter-visible plugin tree"
else
    fail "junto-* rename hygiene: legacy identifier tokens found in adopter-visible plugin tree (must rename to oj-*):"
    echo "${JUNTO_HITS}" | while IFS= read -r line; do
        [[ -n "${line}" ]] && echo "  ${line}"
    done
fi

# ---------------------------------------------------------------------------
# ASSERTION 13: BL-026 platform-binding hygiene — no Claude-platform-name
# leakage in core spec corpus prose.
#
# Scope: juntospec/{D,F,M}*.md core spec layer (NOT platforms/, NOT validation/).
# Banned terms (case-sensitive, word-bounded): "Task tool", "TeamCreate",
# "SendMessage", "SubagentStart". These are Claude Code platform-name literals;
# the core spec corpus must use the abstract primitive vocabulary
# (Consult/Convene/Inform/Onboard) and delegate platform-name binding to
# M16 §3 [platform-capabilities] and platform-contract.yaml.
#
# Exempted region: M16-derivation-architecture.md §3 (the canonical Layer 0
# platform-capability-ingestion anchor where binding parentheticals live).
# §3 is bounded by `## 3. Platform Capability Ingestion (Layer 0)` and the
# next `## ` heading.
#
# This assertion is REPOSITORY-SCOPE (independent of ${TARGET_FILE}). It
# resolves the juntospec spec root via the chain documented at the top of
# this script (env var > sibling probe > hard-fail). After BL-025-f the
# script lives at juntogen/claude/validation/scripts/.
# ---------------------------------------------------------------------------
info "Assertion 13: BL-026 platform-binding hygiene (core spec corpus)"

# SPEC_ROOT was resolved at script start (banned_terms loader). Re-check here
# in case the directory disappeared between then and now (defensive).
if [[ ! -d "${SPEC_ROOT}" ]]; then
    fail "Spec root not resolvable from script location: ${SPEC_ROOT}"
else
    # Note: \b word boundaries are omitted — not portable in BSD awk (macOS).
    # The terms are specific enough to avoid false positives:
    #   - "Task tool" requires a space (lowercase t in tool); no compound words.
    #   - TeamCreate/SendMessage/SubagentStart are CamelCase platform identifiers
    #     with no neighboring alphabetic-character contexts in the spec corpus.
    # BL-025-e.1: regex assembled from `banned_terms[assertion=s13]` entries;
    # see escape_awk_regex / A13_BANNED_REGEX construction at script top.
    BANNED_REGEX="${A13_BANNED_REGEX}"
    BL026_HITS=""
    SPEC_FILE_COUNT=0

    # Scan only D*.md, F*.md, M*.md at the juntospec root (NOT platforms/, NOT validation/).
    for spec_file in "${SPEC_ROOT}"/D[0-9]*.md "${SPEC_ROOT}"/F[0-9]*.md "${SPEC_ROOT}"/M[0-9]*.md; do
        [[ -f "${spec_file}" ]] || continue
        SPEC_FILE_COUNT=$((SPEC_FILE_COUNT + 1))
        rel_name=$(basename "${spec_file}")

        if [[ "${rel_name}" == "M16-derivation-architecture.md" ]]; then
            # Exclude §3 region: from `## 3. Platform Capability Ingestion` (inclusive)
            # through the line just before the next `## ` heading.
            scoped_hits=$(awk -v re="${BANNED_REGEX}" '
                /^## 3\. Platform Capability Ingestion/ { in_s3 = 1; next }
                in_s3 && /^## / { in_s3 = 0 }
                !in_s3 && match($0, re) { printf "%s:%d:%s\n", FILENAME, NR, $0 }
            ' "${spec_file}" 2>/dev/null || true)
        else
            # All other core spec files: full-file scan (no exemption region).
            scoped_hits=$(awk -v re="${BANNED_REGEX}" '
                match($0, re) { printf "%s:%d:%s\n", FILENAME, NR, $0 }
            ' "${spec_file}" 2>/dev/null || true)
        fi

        if [[ -n "${scoped_hits}" ]]; then
            BL026_HITS="${BL026_HITS}${scoped_hits}"$'\n'
        fi
    done

    # F11 fix: a silent zero-iteration loop would PASS this assertion against
    # the wrong SPEC_ROOT. Fail loudly if no D/F/M specs were found.
    if [[ "${SPEC_FILE_COUNT}" -eq 0 ]]; then
        fail "BL-026 platform-binding hygiene: no D/F/M*.md specs found at SPEC_ROOT=${SPEC_ROOT} — assertion cannot run"
    elif [[ -z "${BL026_HITS}" ]]; then
        pass "BL-026 platform-binding hygiene: no Claude-platform-name leakage in core spec corpus (D/F/M*.md, M16 §3 exempted; ${SPEC_FILE_COUNT} files scanned)"
    else
        fail "BL-026 platform-binding hygiene: Claude-platform-name leakage in core spec corpus (use abstract primitive vocabulary; M16 §3 is the only exempted region):"
        echo "${BL026_HITS}" | while IFS= read -r line; do
            [[ -n "${line}" ]] && echo "  ${line}"
        done
    fi
fi

# ---------------------------------------------------------------------------
# ASSERTION 14: BL-025-d Claude-filesystem-path leakage in core spec corpus
# Detects `~/.claude` literals in core spec corpus (D/F/M*.md at juntospec
# root). Core specs MUST use the abstract `{install-root}` primitive instead.
# Bridge prose in F16's installed-layout section is permitted via keep_list
# exemption (the canonical anchor where the primitive resolves to its
# Claude-Code rendering). README.md and MANIFEST.md may contain dual-render
# bridge prose — also permitted via keep_list. The historical-keep-list
# documentation block in README.md is exempted by content (Junto-origin
# references that name files containing the historical anchor).
#
# This assertion is REPOSITORY-SCOPE (independent of ${TARGET_FILE}).
# ---------------------------------------------------------------------------
info "Assertion 14: BL-025-d Claude-filesystem-path hygiene (core spec corpus)"

if [[ ! -d "${SPEC_ROOT}" ]]; then
    fail "Spec root not resolvable from script location: ${SPEC_ROOT}"
else
    A14_HITS=""
    A14_FILE_COUNT=0
    # Scan D/F/M*.md plus README.md and MANIFEST.md at juntospec root.
    # T8 verbatim-block exemption applies to D08 (reproduces literal CLAUDE.md
    # text inside fenced `(verbatim):` blocks; M08 string-match contracts
    # require these strings literally — they cannot be abstracted).
    for spec_file in "${SPEC_ROOT}"/D[0-9]*.md "${SPEC_ROOT}"/F[0-9]*.md "${SPEC_ROOT}"/M[0-9]*.md "${SPEC_ROOT}"/README.md "${SPEC_ROOT}"/MANIFEST.md; do
        [[ -f "${spec_file}" ]] || continue
        A14_FILE_COUNT=$((A14_FILE_COUNT + 1))
        rel_name=$(basename "${spec_file}")

        # BL-025-e.1: §14 banned regex sourced from
        # banned_terms[assertion=s14] (literal `~/.claude/`, escaped to
        # awk regex form). Passed to awk via -v re=… for both branches.
        if [[ "${rel_name}" == "D08-core-protocol.md" ]]; then
            scoped_hits=$(awk -v re="${A14_BANNED_REGEX}" '
                BEGIN { in_verb = 0; verb_lines = 0; pending_verb = 0; open_fence = "" }
                /\(verbatim\):[[:space:]]*$/ { pending_verb = 1; next }
                # Capture the opening fence string to require exact-match close
                pending_verb && /^`{3,}/ {
                    in_verb = 1; verb_lines = 0; pending_verb = 0
                    match($0, /^`+/); open_fence = substr($0, RSTART, RLENGTH)
                    next
                }
                pending_verb && !/^`{3,}/ { pending_verb = 0 }
                # Exit only on a fence that matches the opening exactly (length-equal)
                in_verb && /^`{3,}/ {
                    match($0, /^`+/); close_fence = substr($0, RSTART, RLENGTH)
                    if (close_fence == open_fence) { in_verb = 0; verb_lines = 0; open_fence = ""; next }
                }
                in_verb { verb_lines++; if (verb_lines > 30) { in_verb = 0; verb_lines = 0; open_fence = "" }; next }
                !in_verb && match($0, re) { printf "%s:%d:%s\n", FILENAME, NR, $0 }
            ' "${spec_file}" 2>/dev/null || true)
        else
            scoped_hits=$(awk -v re="${A14_BANNED_REGEX}" '
                match($0, re) { printf "%s:%d:%s\n", FILENAME, NR, $0 }
            ' "${spec_file}" 2>/dev/null || true)
        fi

        if [[ -n "${scoped_hits}" ]]; then
            A14_HITS="${A14_HITS}${scoped_hits}"$'\n'
        fi
    done

    if [[ "${A14_FILE_COUNT}" -eq 0 ]]; then
        fail "BL-025-d filesystem-path hygiene: no D/F/M*.md/README.md/MANIFEST.md found at SPEC_ROOT=${SPEC_ROOT} — assertion cannot run"
    elif [[ -z "${A14_HITS}" ]]; then
        pass "BL-025-d filesystem-path hygiene: no \`~/.claude\` leakage in core spec corpus (${A14_FILE_COUNT} files scanned)"
    else
        # Filter out keep_list exemptions. Each exempt entry is matched by
        # exact (file, line, term) — embedded as inline list below since
        # keep_list YAML parsing requires shell-only tooling.
        # Format: "<basename>:<line>"
        A14_KEEP="\
F16-architecture.md:20
F16-architecture.md:63
README.md:20
README.md:90
README.md:107
MANIFEST.md:68
"
        A14_LEAKS=""
        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            rel=$(echo "${line}" | awk -F: -v root="${SPEC_ROOT}/" '{ sub(root, "", $1); print $1":"$2 }')
            if ! echo "${A14_KEEP}" | grep -qFx "${rel}"; then
                A14_LEAKS="${A14_LEAKS}${line}"$'\n'
            fi
        done <<< "${A14_HITS}"

        if [[ -z "${A14_LEAKS}" ]]; then
            pass "BL-025-d filesystem-path hygiene: only keep_list-exempt \`~/.claude\` occurrences in core spec corpus"
        else
            fail "BL-025-d filesystem-path hygiene: \`~/.claude\` leakage in core spec corpus (use \`{install-root}\` primitive; bridge prose requires keep_list entry):"
            echo "${A14_LEAKS}" | while IFS= read -r ln; do
                [[ -n "${ln}" ]] && echo "  ${ln}"
            done
        fi
    fi
fi

# ---------------------------------------------------------------------------
# ASSERTION 15: BL-025-d CLAUDE.md leakage in core spec corpus
# Detects `CLAUDE.md` literals in core spec corpus. Core specs MUST use the
# abstract "manager protocol file" / `CONDUCTOR.md` vocabulary.
#
# T8 mitigation — verbatim-block exemption: D08 reproduces the generated
# manager protocol file's `[EXACT]` text inside fenced code blocks marked
# `(verbatim):`. These blocks reproduce literal CLAUDE.md content that the
# M08 string-match contracts require to be preserved exactly. The awk
# state machine enters "verbatim mode" when a line ending in `(verbatim):`
# is followed by an opening fence ` ``` `, and exits at the closing fence
# OR after a TIMEOUT of 30 lines (defensive cap — no D08 verbatim block
# exceeds 25 lines today; cap prevents runaway exemption from a missing
# close fence).
#
# Exempt regions:
#   1. M16-derivation-architecture.md §3 (platform-capabilities anchor)
#   2. D08 fenced verbatim blocks (preceding line ends in `(verbatim):`)
#   3. keep_list entries (line-precise)
# ---------------------------------------------------------------------------
info "Assertion 15: BL-025-d CLAUDE.md hygiene (core spec corpus)"

if [[ ! -d "${SPEC_ROOT}" ]]; then
    fail "Spec root not resolvable from script location: ${SPEC_ROOT}"
else
    A15_HITS=""
    A15_FILE_COUNT=0
    for spec_file in "${SPEC_ROOT}"/D[0-9]*.md "${SPEC_ROOT}"/F[0-9]*.md "${SPEC_ROOT}"/M[0-9]*.md "${SPEC_ROOT}"/README.md "${SPEC_ROOT}"/MANIFEST.md; do
        [[ -f "${spec_file}" ]] || continue
        A15_FILE_COUNT=$((A15_FILE_COUNT + 1))
        rel_name=$(basename "${spec_file}")

        # BL-025-e.1: §15 banned regex sourced from
        # banned_terms[assertion=s15] (literal `CLAUDE.md`, escaped).
        if [[ "${rel_name}" == "M16-derivation-architecture.md" ]]; then
            scoped_hits=$(awk -v re="${A15_BANNED_REGEX}" '
                /^## 3\. Platform Capability Ingestion/ { in_s3 = 1; next }
                in_s3 && /^## / { in_s3 = 0 }
                !in_s3 && match($0, re) { printf "%s:%d:%s\n", FILENAME, NR, $0 }
            ' "${spec_file}" 2>/dev/null || true)
        elif [[ "${rel_name}" == "D08-core-protocol.md" ]]; then
            # T8 verbatim-block state machine with fence-length matching
            # and 30-line timeout. Outer 4-backtick fences may contain inner
            # 3-backtick fences (D08 fallback section). Exit only on a
            # fence whose length equals the opening fence's length.
            scoped_hits=$(awk -v re="${A15_BANNED_REGEX}" '
                BEGIN { in_verb = 0; verb_lines = 0; pending_verb = 0; open_fence = "" }
                /\(verbatim\):[[:space:]]*$/ { pending_verb = 1; next }
                pending_verb && /^`{3,}/ {
                    in_verb = 1; verb_lines = 0; pending_verb = 0
                    match($0, /^`+/); open_fence = substr($0, RSTART, RLENGTH)
                    next
                }
                pending_verb && !/^`{3,}/ { pending_verb = 0 }
                in_verb && /^`{3,}/ {
                    match($0, /^`+/); close_fence = substr($0, RSTART, RLENGTH)
                    if (close_fence == open_fence) { in_verb = 0; verb_lines = 0; open_fence = ""; next }
                }
                in_verb { verb_lines++; if (verb_lines > 30) { in_verb = 0; verb_lines = 0; open_fence = "" }; next }
                !in_verb && match($0, re) { printf "%s:%d:%s\n", FILENAME, NR, $0 }
            ' "${spec_file}" 2>/dev/null || true)
        else
            scoped_hits=$(awk -v re="${A15_BANNED_REGEX}" '
                match($0, re) { printf "%s:%d:%s\n", FILENAME, NR, $0 }
            ' "${spec_file}" 2>/dev/null || true)
        fi

        if [[ -n "${scoped_hits}" ]]; then
            A15_HITS="${A15_HITS}${scoped_hits}"$'\n'
        fi
    done

    if [[ "${A15_FILE_COUNT}" -eq 0 ]]; then
        fail "BL-025-d CLAUDE.md hygiene: no D/F/M*.md/README.md/MANIFEST.md found at SPEC_ROOT=${SPEC_ROOT} — assertion cannot run"
    elif [[ -z "${A15_HITS}" ]]; then
        pass "BL-025-d CLAUDE.md hygiene: no \`CLAUDE.md\` leakage in core spec corpus (M16 §3 exempted; D08 verbatim blocks exempted with 30-line timeout; ${A15_FILE_COUNT} files scanned)"
    else
        # keep_list exemptions for non-D08, non-M16-§3 occurrences
        A15_KEEP="\
README.md:20
README.md:107
MANIFEST.md:68
"
        A15_LEAKS=""
        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            rel=$(echo "${line}" | awk -F: -v root="${SPEC_ROOT}/" '{ sub(root, "", $1); print $1":"$2 }')
            if ! echo "${A15_KEEP}" | grep -qFx "${rel}"; then
                A15_LEAKS="${A15_LEAKS}${line}"$'\n'
            fi
        done <<< "${A15_HITS}"

        if [[ -z "${A15_LEAKS}" ]]; then
            pass "BL-025-d CLAUDE.md hygiene: only keep_list-exempt \`CLAUDE.md\` occurrences in core spec corpus"
        else
            fail "BL-025-d CLAUDE.md hygiene: \`CLAUDE.md\` leakage in core spec corpus (use \"manager protocol file\" / \`CONDUCTOR.md\`; bridge prose requires keep_list entry; D08 verbatim blocks must be in fenced \`(verbatim):\`-marked code blocks):"
            echo "${A15_LEAKS}" | while IFS= read -r ln; do
                [[ -n "${ln}" ]] && echo "  ${ln}"
            done
        fi
    fi
fi

# ---------------------------------------------------------------------------
# ASSERTION 16: BL-025-d concrete model-id leakage in core spec corpus
# Detects standalone `haiku`, `sonnet`, or `opus` tokens in core spec corpus.
# Core specs MUST use abstract `{tier-routine}`/`{tier-implementation}`/
# `{tier-reasoning}` vocabulary. Concrete model IDs belong only in the
# Layer 0 platform-capabilities snapshot (M16 §3) where they bind primitives
# to platform facts.
#
# T9 mitigation — exit anchor for §3 region: M16 §3 is bounded by
# `## 3. Platform Capability Ingestion (Layer 0)` (inclusive) and the
# next `## ` heading (exclusive). Mirrors assertion 13 pattern.
#
# Token definition: BSD awk lacks `\b`. Use space/punctuation neighbors —
# the regex matches `[^a-zA-Z0-9_-](haiku|sonnet|opus)[^a-zA-Z0-9_-]` OR
# the token at line start/end. To handle BSD awk constraints we anchor by
# enumerating context characters in two passes (start/end and middle).
# ---------------------------------------------------------------------------
info "Assertion 16: BL-025-d concrete model-id hygiene (core spec corpus)"

if [[ ! -d "${SPEC_ROOT}" ]]; then
    fail "Spec root not resolvable from script location: ${SPEC_ROOT}"
else
    A16_HITS=""
    A16_FILE_COUNT=0
    # Word-boundary regex compatible with BSD awk:
    # match (start | non-word-char) (token) (end | non-word-char)
    # BL-025-e.1: pulled byte-identically from
    # banned_terms[assertion=s16] (kind: regex). Single source of truth.
    A16_REGEX="${A16_BANNED_REGEX}"

    for spec_file in "${SPEC_ROOT}"/D[0-9]*.md "${SPEC_ROOT}"/F[0-9]*.md "${SPEC_ROOT}"/M[0-9]*.md "${SPEC_ROOT}"/README.md "${SPEC_ROOT}"/MANIFEST.md; do
        [[ -f "${spec_file}" ]] || continue
        A16_FILE_COUNT=$((A16_FILE_COUNT + 1))
        rel_name=$(basename "${spec_file}")

        if [[ "${rel_name}" == "M16-derivation-architecture.md" ]]; then
            scoped_hits=$(awk -v re="${A16_REGEX}" '
                /^## 3\. Platform Capability Ingestion/ { in_s3 = 1; next }
                in_s3 && /^## / { in_s3 = 0 }
                !in_s3 && match($0, re) { printf "%s:%d:%s\n", FILENAME, NR, $0 }
            ' "${spec_file}" 2>/dev/null || true)
        else
            scoped_hits=$(awk -v re="${A16_REGEX}" '
                match($0, re) { printf "%s:%d:%s\n", FILENAME, NR, $0 }
            ' "${spec_file}" 2>/dev/null || true)
        fi

        if [[ -n "${scoped_hits}" ]]; then
            A16_HITS="${A16_HITS}${scoped_hits}"$'\n'
        fi
    done

    if [[ "${A16_FILE_COUNT}" -eq 0 ]]; then
        fail "BL-025-d concrete model-id hygiene: no D/F/M*.md/README.md/MANIFEST.md found at SPEC_ROOT=${SPEC_ROOT} — assertion cannot run"
    elif [[ -z "${A16_HITS}" ]]; then
        pass "BL-025-d concrete model-id hygiene: no \`haiku\`/\`sonnet\`/\`opus\` leakage in core spec corpus (M16 §3 exempted; ${A16_FILE_COUNT} files scanned)"
    else
        fail "BL-025-d concrete model-id hygiene: concrete model-id leakage in core spec corpus (use \`{tier-routine}\`/\`{tier-implementation}\`/\`{tier-reasoning}\` vocabulary; M16 §3 is the only exempted region):"
        echo "${A16_HITS}" | while IFS= read -r ln; do
            [[ -n "${ln}" ]] && echo "  ${ln}"
        done
    fi
fi

# ---------------------------------------------------------------------------
# ASSERTION 18 (BL-025-m.2): no_step_sentinel_in_plugin_tree.
#
# Sentinel files (`.step-NN.done`) belong under SENTINEL_DIR (per-run
# cache, default ~/.cache/juntogen/run-<UTC>/) — NOT in the OUTPUT_DIR
# plugin tree. A leak would mean the regen pipeline pollutes the
# adopter-visible plugin install with run-tracking metadata. This
# assertion finds any `.step-*.done` file anywhere under OUTPUT_DIR
# and fails loudly.
#
# Depth: unbounded (was -maxdepth 2; reviewer P4 H1 — a -maxdepth 2 cap
# silently passed leaks at depth ≥ 3, e.g. skills/consult/foo/.step-04.done).
# The plugin tree is small (sub-second walk), so a full scan is cheap and
# the contract is sharper: sentinels never legitimately appear anywhere
# under OUTPUT_DIR.
#
# BL-025-m.4: the find-command logic is now the single source of truth in
# validate-no-step-sentinel.sh (callable as a standalone validator on
# partial trees that lack CONDUCTOR.md, e.g. `--spike NN` outputs).
# Tier A sources that helper and wraps `check_no_step_sentinel` with its
# own pass/fail counter increments so the stdout/stderr format remains
# byte-identical to the prior inline implementation.
# ---------------------------------------------------------------------------
info "Assertion 18 (BL-025-m.2): no_step_sentinel_in_plugin_tree"

# Source the standalone helper. Resolve relative to this script so the
# call works regardless of caller cwd.
TIER_A_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
A18_HELPER="${TIER_A_SCRIPT_DIR}/validate-no-step-sentinel.sh"
if [[ ! -f "${A18_HELPER}" ]]; then
    fail "Assertion 18: helper script missing at ${A18_HELPER}"
else
    # shellcheck source=/dev/null
    . "${A18_HELPER}"
    set +e
    A18_HITS=$(check_no_step_sentinel "${OUTPUT_DIR}")
    A18_RC=$?
    set -e
    if [[ "${A18_RC}" -eq 0 ]]; then
        pass "Assertion 18: 0 .step-*.done sentinels found in plugin tree (full OUTPUT_DIR walk)"
    else
        A18_COUNT=$(echo "${A18_HITS}" | wc -l | tr -d ' ')
        fail "Assertion 18: ${A18_COUNT} .step-*.done sentinel(s) found in plugin tree:"
        echo "${A18_HITS}" | sed 's/^/  /'
    fi
fi

# ---------------------------------------------------------------------------
# Assertion 19 (BL-025-m.6 item 2): no_claude_home_leak_in_plugin_tree
#
# Empirically motivated by BL-025-m.3 Iter 3b: 22 `~/.claude/` literals
# survived the cycle in the live oj-claude plugin tree (16 compact-profile
# "Full profile:" lines, agents/index.md cross-reference, 4 lines in
# reference/dev-mode.md, 1 line in reference/workflow-stages.md). The
# literal `~/.claude/` form points at the manager-side install where the
# specs are authored, not at the plugin-installed tree — adopters reaching
# these references would be silently redirected away from the plugin tree.
#
# The standalone helper enforces a positive-glob fail-closed scope with
# NO keep-list: CONDUCTOR.md, agents/*.md, reference/*.md, docs/**/*.md,
# skills/*/SKILL.md. Out-of-scope paths (bin/, README.md, .claude/CLAUDE.md,
# org-scaffold/) carry intentional migration prose and are excluded by
# construction (verified by the N5 exemption-control test in the helper's
# CI gate).
# ---------------------------------------------------------------------------
info "Assertion 19 (BL-025-m.6 item 2): no_claude_home_leak_in_plugin_tree"

A19_HELPER="${TIER_A_SCRIPT_DIR}/validate-no-claude-home-leak.sh"
if [[ ! -f "${A19_HELPER}" ]]; then
    fail "Assertion 19: helper script missing at ${A19_HELPER}"
else
    # shellcheck source=/dev/null
    . "${A19_HELPER}"
    set +e
    A19_HITS=$(check_no_claude_home_leak "${OUTPUT_DIR}")
    A19_RC=$?
    set -e
    if [[ "${A19_RC}" -eq 0 ]]; then
        pass "Assertion 19: 0 ~/.claude/ literals found in scoped plugin tree (CONDUCTOR.md, agents/*.md, reference/*.md, docs/**/*.md, skills/*/*.md)"
    else
        A19_COUNT=$(echo "${A19_HITS}" | wc -l | tr -d ' ')
        fail "Assertion 19: ${A19_COUNT} ~/.claude/ leak(s) found in scoped plugin tree:"
        echo "${A19_HITS}" | sed 's/^/  /'
    fi
fi

echo ""
echo "================================"
echo -e "${GREEN}PASSED${NC}: ${PASS_COUNT}"
echo -e "${RED}FAILED${NC}: ${FAIL_COUNT}"
# BL-025-m.1: baseline + post-cycle count printed for downstream reviewers
# to confirm coverage did NOT silently shrink during the retarget. Pre-cycle
# baseline (TARGET_FILE=src/CLAUDE.md) was 16/0 PASS. Post-cycle adds
# Assertion 0 (loader smoke per DE F7), bringing the floor to 17.
# BL-025-m.2: adds Assertion 18 (no_step_sentinel_in_plugin_tree),
# bringing the floor to 18. A drop below 18 means coverage silently
# shrank — that's a regression even if all green.
# BL-025-m.6 item 2: adds Assertion 19 (no_claude_home_leak_in_plugin_tree),
# bringing the floor to 19. Empirically motivated by m.3 Iter 3b: 22
# `~/.claude/` literals survived the cycle. A drop below 19 means coverage
# silently shrank.
echo -e "BASELINE: 16 (pre-cycle src/CLAUDE.md target)"
echo -e "POST-CYCLE FLOOR: 19 (adds Assertion 0 loader smoke + Assertion 18 sentinel hygiene + Assertion 19 claude-home leak)"
echo "================================"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    exit 1
else
    exit 0
fi
