#!/usr/bin/env bash
#
# validate-dry-run.sh — BL-025-h dry-run formal post-condition.
#
# PURPOSE: Assert dry-run-time invariants over the resolved step-prompt
#          corpus. Generate's --dry-run path skips LLM calls but still
#          builds the substituted prompts; this script makes the dry-run
#          MEANINGFUL by validating those prompts before they would be
#          handed to Claude.
#
# INVARIANTS (per BL-025-h step 5):
#   a. exit-status check (implicit — script reaches here only if invoked
#      after the dry-run main loop succeeded; the caller exits non-zero
#      before chaining if any step build failed).
#   b. ZERO unresolved placeholders in any built prompt:
#        {OJ_SOURCE}                  (graceful-degrade exception when
#                                      --oj-source absent — pass via
#                                      OJ_SOURCE_PROVIDED=0)
#        /path/to/juntospec/
#        /path/to/juntogen/
#        /path/to/junto-project/
#        /path/to/oj-project/
#        /path/to/openjunto/
#   c. Every [CANONICAL: id] reference in the step-prompt corpus must
#      resolve to a contract.canonical_ids[] entry.
#   d. step-prompt-vocabulary-audit.sh passes (chained).
#   e. vocabulary-audit.sh passes against ${SPEC_DIR} (chained, even in
#      dry-run mode — F4 mitigation).
#
# USAGE:
#   validate-dry-run.sh \
#       --prompt-dir /tmp/junto-build/prompts-built \
#       --spec-dir /path/to/juntospec \
#       --steps-dir /path/to/juntogen/claude/steps \
#       [--oj-source-provided 1|0]
#
# Or via env vars (lower precedence than flags):
#   OJ_DRY_RUN_PROMPT_DIR  same as --prompt-dir
#   OJ_SPEC_DIR            same as --spec-dir
#   OJ_STEPS_DIR           same as --steps-dir
#   OJ_SOURCE_PROVIDED     same as --oj-source-provided
#
# EXIT CODES:
#   0 — all post-conditions pass
#   1 — at least one post-condition failed
#   2 — driver error (missing dependency, bad args, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output.
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

PROMPT_DIR="${OJ_DRY_RUN_PROMPT_DIR:-}"
SPEC_DIR="${OJ_SPEC_DIR:-}"
STEPS_DIR="${OJ_STEPS_DIR:-}"
OJ_SOURCE_PROVIDED="${OJ_SOURCE_PROVIDED:-1}"

while [ $# -gt 0 ]; do
    case "$1" in
        --prompt-dir)
            [ $# -ge 2 ] || { echo "ERROR: --prompt-dir requires a value" >&2; exit 2; }
            PROMPT_DIR="$2"; shift 2 ;;
        --spec-dir)
            [ $# -ge 2 ] || { echo "ERROR: --spec-dir requires a value" >&2; exit 2; }
            SPEC_DIR="$2"; shift 2 ;;
        --steps-dir)
            [ $# -ge 2 ] || { echo "ERROR: --steps-dir requires a value" >&2; exit 2; }
            STEPS_DIR="$2"; shift 2 ;;
        --oj-source-provided)
            [ $# -ge 2 ] || { echo "ERROR: --oj-source-provided requires 0|1" >&2; exit 2; }
            OJ_SOURCE_PROVIDED="$2"; shift 2 ;;
        --help|-h)
            sed -n '2,40p' "$0"; exit 0 ;;
        *)
            echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
    esac
done

# Required inputs.
[ -d "${PROMPT_DIR}" ]  || { echo -e "${RED}ERROR${NC} PROMPT_DIR not a directory: ${PROMPT_DIR}" >&2; exit 2; }
[ -d "${SPEC_DIR}" ]    || { echo -e "${RED}ERROR${NC} SPEC_DIR not a directory: ${SPEC_DIR}" >&2; exit 2; }
[ -d "${STEPS_DIR}" ]   || { echo -e "${RED}ERROR${NC} STEPS_DIR not a directory: ${STEPS_DIR}" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}ERROR${NC} python3 not on PATH" >&2; exit 2; }

LOAD_PY="${SCRIPT_DIR}/lib/load-contract.py"
VOCAB_AUDIT="${SCRIPT_DIR}/vocabulary-audit.sh"
STEPS_AUDIT="${SCRIPT_DIR}/step-prompt-vocabulary-audit.sh"
[ -f "${LOAD_PY}" ]      || { echo -e "${RED}ERROR${NC} load-contract.py missing at ${LOAD_PY}" >&2; exit 2; }
[ -x "${VOCAB_AUDIT}" ]  || { echo -e "${RED}ERROR${NC} vocabulary-audit.sh missing/not executable: ${VOCAB_AUDIT}" >&2; exit 2; }
[ -x "${STEPS_AUDIT}" ]  || { echo -e "${RED}ERROR${NC} step-prompt-vocabulary-audit.sh missing/not executable: ${STEPS_AUDIT}" >&2; exit 2; }

CONTRACT="${SPEC_DIR}/platform-contract.yaml"
[ -f "${CONTRACT}" ] || { echo -e "${RED}ERROR${NC} platform-contract.yaml not found at ${CONTRACT}" >&2; exit 2; }

VIOLATIONS=0

emit_violation() {
    # $1=category $2=file $3=line $4=detail
    printf 'CATEGORY: %s | FILE: %s | LINE: %s | DETAIL: %s\n' "$1" "$2" "$3" "$4" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
}

echo -e "${YELLOW}[INFO]${NC} validate-dry-run: prompt dir = ${PROMPT_DIR}"
echo -e "${YELLOW}[INFO]${NC} validate-dry-run: spec dir   = ${SPEC_DIR}"
echo -e "${YELLOW}[INFO]${NC} validate-dry-run: steps dir  = ${STEPS_DIR}"
echo -e "${YELLOW}[INFO]${NC} validate-dry-run: --oj-source provided = ${OJ_SOURCE_PROVIDED}"
echo

# ── Check b: Unresolved placeholders in built prompts ─────────────────────
echo -e "${YELLOW}[INFO]${NC} Check b: unresolved placeholders in built prompts"
PLACEHOLDERS_BASE=(
    "/path/to/juntospec/"
    "/path/to/juntogen/"
    "/path/to/junto-project/"
    "/path/to/oj-project/"
    "/path/to/openjunto/"
)
PROMPT_FILES=$(find "${PROMPT_DIR}" -maxdepth 1 -type f \( -name 'step-*.prompt' -o -name 'step-*.txt' -o -name 'step-*.md' \) 2>/dev/null | sort)
if [ -z "${PROMPT_FILES}" ]; then
    emit_violation "missing-built-prompts" "${PROMPT_DIR}" "0" "no step-*.prompt|.txt|.md files found in PROMPT_DIR"
fi
for pf in ${PROMPT_FILES}; do
    rel=$(basename "${pf}")
    for ph in "${PLACEHOLDERS_BASE[@]}"; do
        # Use grep -F (literal) to avoid regex surprises with /.
        if grep -nF -- "${ph}" "${pf}" >/dev/null 2>&1; then
            while IFS=':' read -r ln rest; do
                emit_violation "unresolved-placeholder" "${rel}" "${ln}" "placeholder '${ph}' present"
            done < <(grep -nF -- "${ph}" "${pf}")
        fi
    done
    # {OJ_SOURCE} is graceful-degrade exempt when --oj-source not provided.
    if [ "${OJ_SOURCE_PROVIDED}" = "1" ]; then
        if grep -nF -- "{OJ_SOURCE}" "${pf}" >/dev/null 2>&1; then
            while IFS=':' read -r ln rest; do
                emit_violation "unresolved-placeholder" "${rel}" "${ln}" "placeholder '{OJ_SOURCE}' present (--oj-source was provided)"
            done < <(grep -nF -- "{OJ_SOURCE}" "${pf}")
        fi
    fi
    # BL-025-h.1 F-01: residual [CANONICAL: ...] / [FILE: ...] markers in
    # a BUILT prompt indicate that build_prompt's substitution silently
    # fell through (e.g., the awk pass was skipped or the marker form
    # didn't match the regex). build_prompt should have hard-failed at
    # generation time; this is the post-condition belt-and-braces. The
    # meta-id literal `[CANONICAL: id]` is the documentation form
    # (precedent: validate-dry-run.sh:179) and is exempt.
    if grep -nE '\[CANONICAL:[[:space:]]*[A-Za-z0-9_-]+\]' "${pf}" >/dev/null 2>&1; then
        while IFS=':' read -r ln rest; do
            # Skip the meta-id documentation form.
            if printf '%s' "${rest}" | grep -qE '\[CANONICAL:[[:space:]]*id\]'; then
                # Line carries `[CANONICAL: id]` literal; check whether
                # there are any OTHER non-meta canonical markers on the
                # same line. If yes, fail; if no, skip.
                non_meta=$(printf '%s' "${rest}" | grep -oE '\[CANONICAL:[[:space:]]*[A-Za-z0-9_-]+\]' \
                    | grep -vE '^\[CANONICAL:[[:space:]]*id\]$' || true)
                if [ -z "${non_meta}" ]; then
                    continue
                fi
            fi
            emit_violation "unresolved-marker" "${rel}" "${ln}" "[CANONICAL: ...] marker present in built prompt (build_prompt substitution failed silently)"
        done < <(grep -nE '\[CANONICAL:[[:space:]]*[A-Za-z0-9_-]+\]' "${pf}")
    fi
    if grep -nE '\[FILE:[[:space:]]*[A-Za-z0-9._-]+\]' "${pf}" >/dev/null 2>&1; then
        while IFS=':' read -r ln rest; do
            emit_violation "unresolved-marker" "${rel}" "${ln}" "[FILE: ...] marker present in built prompt (build_prompt substitution failed silently)"
        done < <(grep -nE '\[FILE:[[:space:]]*[A-Za-z0-9._-]+\]' "${pf}")
    fi
done

# ── Check c: [CANONICAL: id] reference closure ───────────────────────────
echo -e "${YELLOW}[INFO]${NC} Check c: [CANONICAL: id] reference closure"
# Pull the set of valid ids from the contract.
KNOWN_IDS=$(python3 "${LOAD_PY}" canonical-ids "${CONTRACT}" | awk -F'\t' '{print $1}' | sort -u)
if [ -z "${KNOWN_IDS}" ]; then
    emit_violation "contract-empty" "${CONTRACT}" "0" "contract.canonical_ids is empty"
fi
# Scan the step-prompt corpus (NOT the built prompts — built prompts
# inherit from steps; checking either is equivalent because the
# placeholder resolution doesn't touch [CANONICAL: ...] markers).
#
# META-ID FILTER: the literal id-name `id` is the meta-syntactic
# placeholder used in documentation (e.g., step-01:58 explains "[CANONICAL: id]
# markers in the source files identify the authoritative definitions").
# Real canonical_ids in the contract are kebab-case multi-word strings
# (e.g., circuit-breaker, delegation-boundary-invariant). Skip the
# meta-id by exact match so the closure check focuses on real refs.
for sf in "${STEPS_DIR}"/step-*.md; do
    [ -f "${sf}" ] || continue
    rel=$(basename "${sf}")
    # Extract every [CANONICAL: id] occurrence with line number.
    while IFS= read -r match; do
        [ -z "${match}" ] && continue
        ln=$(printf '%s' "${match}" | awk -F':' '{print $1}')
        rest=$(printf '%s' "${match}" | cut -d: -f2-)
        # Pull the id from the [CANONICAL: id] form.
        cid=$(printf '%s' "${rest}" | sed -nE 's/.*\[CANONICAL:[[:space:]]*([a-zA-Z0-9_-]+)\].*/\1/p' | head -1)
        if [ -z "${cid}" ]; then
            continue
        fi
        # Meta-id placeholder; documentation reference, not a real ref.
        if [ "${cid}" = "id" ]; then
            continue
        fi
        if ! printf '%s\n' "${KNOWN_IDS}" | grep -qx "${cid}"; then
            emit_violation "canonical-id-orphan" "${rel}" "${ln}" "[CANONICAL: ${cid}] not present in contract.canonical_ids"
        fi
    done < <(grep -nE '\[CANONICAL:[[:space:]]*[a-zA-Z0-9_-]+\]' "${sf}" 2>/dev/null || true)
done

# ── Check d: chain step-prompt vocabulary audit ──────────────────────────
echo -e "${YELLOW}[INFO]${NC} Check d: step-prompt-vocabulary-audit (chained)"
if ! OJ_SPEC_DIR="${SPEC_DIR}" "${STEPS_AUDIT}" "${STEPS_DIR}" >/dev/null; then
    emit_violation "step-prompt-vocab-failed" "${STEPS_DIR}" "0" "step-prompt-vocabulary-audit.sh exited non-zero"
fi

# ── Check e: chain spec-corpus vocabulary audit ──────────────────────────
echo -e "${YELLOW}[INFO]${NC} Check e: vocabulary-audit (spec corpus, chained — F4 mitigation)"
if ! "${VOCAB_AUDIT}" "${SPEC_DIR}" >/dev/null; then
    emit_violation "spec-corpus-vocab-failed" "${SPEC_DIR}" "0" "vocabulary-audit.sh exited non-zero"
fi

echo

# ── Summary ───────────────────────────────────────────────────────────────
echo "================================"
if [ "${VIOLATIONS}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} validate-dry-run: 0 post-condition violations"
    echo "================================"
    exit 0
else
    echo -e "${RED}FAIL${NC} validate-dry-run: ${VIOLATIONS} violation(s) — see structured stderr above"
    echo "================================"
    exit 1
fi
