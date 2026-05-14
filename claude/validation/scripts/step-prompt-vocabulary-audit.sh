#!/usr/bin/env bash
#
# step-prompt-vocabulary-audit.sh — BL-025-h step-prompt vocabulary audit.
#
# PURPOSE: Fail closed when juntogen/claude/steps/*.md contains banned
#          Claude-platform identifiers in spec-prose context. The audit
#          enforces the same vocabulary as the spec-corpus audit
#          (vocabulary-audit.sh) but on the step-prompt middle layer:
#
#            - vocabulary-audit.sh        scopes juntospec/{D,F,M}*.md +
#                                          README/MANIFEST. Source of truth
#                                          for banned terms is
#                                          juntospec/platform-contract.yaml.
#            - step-prompt-vocabulary-audit.sh (this script) scopes
#                                          juntogen/claude/steps/*.md.
#                                          Source of truth for banned
#                                          terms is the SAME
#                                          platform-contract.yaml; the
#                                          keep_list is separate
#                                          (juntogen/claude/steps/.steps-keep-list.yaml)
#                                          because the legitimate
#                                          [EXTERNAL] occurrences are
#                                          different.
#
# DETECTION: For each banned term in platform-contract.yaml banned_terms[]
#            (kind: literal), scan every step-XX-*.md file. For each hit,
#            consult .steps-keep-list.yaml. Hits not on the keep_list
#            emit a structured `CATEGORY: banned-term-bleed` line on
#            stderr and the script exits non-zero.
#
# EXIT CODES:
#   0 — all checks pass
#   1 — one or more violations
#   2 — driver error (yaml helper missing, contract not found, etc.)
#
# USAGE:
#   step-prompt-vocabulary-audit.sh /path/to/juntogen/claude/steps  # positional (highest precedence)
#   OJ_STEPS_DIR=/path/to/juntogen/claude/steps step-prompt-vocabulary-audit.sh
#   step-prompt-vocabulary-audit.sh                                 # sibling probe (script lives at
#                                                                   # juntogen/claude/validation/scripts/,
#                                                                   # so steps sibling is
#                                                                   # ../../steps from SCRIPT_DIR)
#
# Structured stderr lines mirror vocabulary-audit.sh:
#   CATEGORY: <kind> | FILE: <path> | LINE: <line> | DETAIL: <free-form>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Resolve STEPS_DIR ────────────────────────────────────────────────────
if [ -n "${1:-}" ]; then
    STEPS_DIR="$1"
elif [ -n "${OJ_STEPS_DIR:-}" ]; then
    STEPS_DIR="${OJ_STEPS_DIR}"
elif [ -d "${SCRIPT_DIR}/../../steps" ]; then
    STEPS_DIR="$(cd "${SCRIPT_DIR}/../../steps" && pwd)"
else
    echo "ERROR: cannot locate juntogen/claude/steps. Provide one of:" >&2
    echo "  positional arg          step-prompt-vocabulary-audit.sh /path/to/steps" >&2
    echo "  OJ_STEPS_DIR=DIR (env)  exported environment variable" >&2
    echo "  sibling layout          steps/ is ../../steps relative to this script" >&2
    exit 2
fi

if [ ! -d "${STEPS_DIR}" ]; then
    echo "ERROR: STEPS_DIR is not a directory: ${STEPS_DIR}" >&2
    exit 2
fi

# ── Resolve SPEC_ROOT (for platform-contract.yaml banned_terms[]) ───────
# Same precedence chain as vocabulary-audit.sh; this audit must read
# banned_terms from the same contract to stay aligned.
if [ -n "${OJ_SPEC_DIR:-}" ]; then
    SPEC_ROOT="${OJ_SPEC_DIR}"
elif [ -d "${SCRIPT_DIR}/../../../../juntospec" ]; then
    SPEC_ROOT="$(cd "${SCRIPT_DIR}/../../../../juntospec" && pwd)"
else
    echo "ERROR: cannot locate juntospec corpus root for banned_terms source." >&2
    echo "  OJ_SPEC_DIR=DIR (env)  exported environment variable" >&2
    echo "  sibling layout         juntogen ↔ juntospec under common parent" >&2
    exit 2
fi

CONTRACT="${SPEC_ROOT}/platform-contract.yaml"
KEEP_YAML="${STEPS_DIR}/.steps-keep-list.yaml"
PARSE_PY="${SCRIPT_DIR}/lib/parse-contract.py"

# Color output (only when stdout is a TTY; quiet for CI logs).
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi

VIOLATIONS=0

emit_violation() {
    # $1=category $2=file $3=line $4=detail
    printf 'CATEGORY: %s | FILE: %s | LINE: %s | DETAIL: %s\n' "$1" "$2" "$3" "$4" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
}

# ── Sanity ────────────────────────────────────────────────────────────────
[ -f "${CONTRACT}" ]   || { echo -e "${RED}ERROR${NC} platform-contract.yaml not found at ${CONTRACT}" >&2; exit 2; }
[ -f "${KEEP_YAML}" ]  || { echo -e "${RED}ERROR${NC} step-prompt keep_list not found at ${KEEP_YAML}" >&2; exit 2; }
[ -f "${PARSE_PY}" ]   || { echo -e "${RED}ERROR${NC} parse-contract.py missing at ${PARSE_PY}" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}ERROR${NC} python3 not on PATH" >&2; exit 2; }

# ── Load banned terms (literal kind only) ────────────────────────────────
BANNED_TSV=$(python3 "${PARSE_PY}" banned-terms "${CONTRACT}")
BANNED_COUNT=$(printf '%s\n' "${BANNED_TSV}" | grep -c . || true)

# ── Load step-prompt keep_list ───────────────────────────────────────────
# Inline python: emit one TSV row per keep_list entry.
# Columns: file<TAB>line<TAB>term<TAB>match_kind
KEEP_TSV=$(python3 - "${KEEP_YAML}" <<'PY'
import sys, yaml
path = sys.argv[1]
with open(path) as f:
    doc = yaml.safe_load(f) or {}
entries = doc.get("keep_list", []) or []
for entry in entries:
    file_v = str(entry.get("file", ""))
    line_v = str(entry.get("line", ""))
    term_v = str(entry.get("term", ""))
    kind_v = str(entry.get("match_kind", "literal"))
    for fname, val in (("file", file_v), ("line", line_v), ("term", term_v), ("kind", kind_v)):
        if "\t" in val or "\n" in val:
            sys.stderr.write(f"ERROR: keep_list field {fname!r} contains tab/newline: {val!r}\n")
            sys.exit(1)
    print(f"{file_v}\t{line_v}\t{term_v}\t{kind_v}")
PY
)
KEEP_COUNT=$(printf '%s\n' "${KEEP_TSV}" | grep -c . || true)

echo -e "${YELLOW}[INFO]${NC} step-prompt-vocabulary-audit: ${BANNED_COUNT} banned terms, ${KEEP_COUNT} keep_list entries"
echo -e "${YELLOW}[INFO]${NC} steps dir: ${STEPS_DIR}"
echo -e "${YELLOW}[INFO]${NC} contract:  ${CONTRACT}"
echo

# ── Pass 1: keep_list integrity (term presence) ──────────────────────────
echo -e "${YELLOW}[INFO]${NC} Pass 1: keep_list term presence at file:line"
while IFS=$'\t' read -r kfile kline kterm kkind; do
    [ -z "${kfile}" ] && continue
    abs="${STEPS_DIR}/${kfile}"
    if [ ! -f "${abs}" ]; then
        emit_violation "term-mismatch" "${kfile}" "${kline}" "keep_list file does not exist under steps dir"
        continue
    fi
    line_for_check="${kline}"
    case "${kline}" in
        *-*) line_for_check="${kline%%-*}" ;;
    esac
    if [ "${kkind}" = "literal" ]; then
        actual_line=$(awk -v n="${line_for_check}" 'NR==n' "${abs}")
        case "${actual_line}" in
            *"${kterm}"*) ;;
            *)
                emit_violation "term-mismatch" "${kfile}" "${kline}" "keep_list term '${kterm}' not present at ${kfile}:${kline}"
                ;;
        esac
    else
        emit_violation "term-mismatch" "${kfile}" "${kline}" "keep_list match_kind '${kkind}' is not literal (regex unsupported in step-prompt audit)"
    fi
done <<< "${KEEP_TSV}"

# ── Pass 2: banned-term-bleed sweep ──────────────────────────────────────
echo -e "${YELLOW}[INFO]${NC} Pass 2: banned-term-bleed sweep (${BANNED_COUNT} terms × steps corpus)"

# Build keep_list lookup: file<TAB>line<TAB>term
KEEP_LOOKUP=$(printf '%s\n' "${KEEP_TSV}" | awk -F'\t' '{print $1"\t"$2"\t"$3}')

in_keep_list() {
    local file="$1" line="$2" term="$3"
    echo "${KEEP_LOOKUP}" | awk -F'\t' -v f="${file}" -v ln="${line}" -v t="${term}" '
        $1 != f { next }
        index($3, t) == 0 { next }
        {
            split($2, parts, "-")
            if (length(parts[2]) == 0) {
                if (parts[1]+0 == ln+0) { found=1; exit }
            } else {
                if (ln+0 >= parts[1]+0 && ln+0 <= parts[2]+0) { found=1; exit }
            }
        }
        END { exit (found ? 0 : 1) }
    '
}

# Scope: step-XX-*.md under STEPS_DIR.
SCOPE_FILES=$(ls "${STEPS_DIR}"/step-*.md 2>/dev/null || true)
if [ -z "${SCOPE_FILES}" ]; then
    echo "ERROR: no step-*.md files found under ${STEPS_DIR}" >&2
    exit 2
fi

while IFS=$'\t' read -r bterm bkind bscope bregions bassertion _extra; do
    if [ -n "${_extra}" ]; then
        echo "ERROR: parse-contract.py emitted >5 columns for banned-terms; consumer must be updated (BL-028 schema-drift guard)" >&2
        exit 2
    fi
    [ -z "${bterm}" ] && continue
    # The step-prompt audit only enforces the literal kind. Regex-kind
    # banned terms (the model-id sweep) are not relevant in step-prompt
    # context where api_id strings are legitimate platform facts.
    [ "${bkind}" != "literal" ] && continue
    # Skip filesystem/manager-protocol bridges — those are platform facts
    # in step-prompt context (e.g., step-09 references CLAUDE.md as the
    # manager-protocol filename binding). The narrowly-scoped banned set
    # for step prompts is the BL-025-c sweep (Task tool / TeamCreate /
    # TeamDelete / SendMessage / SubagentStart). The BL-025-d sweep
    # (~/.claude/, CLAUDE.md) is out of scope for step prompts because
    # those identifiers are deliberate platform-binding references.
    case "${bterm}" in
        "Task tool"|"TeamCreate"|"TeamDelete"|"SendMessage"|"SubagentStart") ;;
        *) continue ;;
    esac

    for spec_file in ${SCOPE_FILES}; do
        rel_path=$(basename "${spec_file}")
        # Iterate over every line, flag literal substring hits.
        while IFS=$'\t' read -r hline hcontent; do
            [ -z "${hline}" ] && continue
            if in_keep_list "${rel_path}" "${hline}" "${bterm}"; then
                continue
            fi
            emit_violation "banned-term-bleed" "${rel_path}" "${hline}" "banned term '${bterm}' (kind=${bkind}) outside keep_list"
        done < <(awk -v t="${bterm}" '{ if (index($0, t) > 0) printf "%d\t%s\n", NR, $0 }' "${spec_file}")
    done
done <<< "${BANNED_TSV}"

# ── Pass 3: legacy /path/to/<repo>/ literal-path-form ban (BL-025-h.3) ───
# Future regressions that re-introduce literal repo-path forms in step
# prompts would silently bypass contract D4 closure (build_prompt's
# /path/to/{juntospec,juntogen}/ prefix-sed substitutions resolve them
# before they reach the LLM). This pass makes that invisible-regression
# class a loud test failure.
#
# Banned: substring match anywhere in any line (no anchor). The two
# prefixes are absolutely banned in step prompts — no keep_list
# consultation; there is no legitimate use case in step-prompt context
# (spec-file refs must derive from contract layout.spec_files[] via the
# [FILE: <basename>] marker).
#
# In-prose citations like "(from spec juntogen/claude/D64-tooling.md)"
# lack the `/path/to/` prefix and are NOT matched.
echo -e "${YELLOW}[INFO]${NC} Pass 3: legacy-path-form ban (BL-025-h.3)"
LEGACY_PREFIXES=(
    "/path/to/juntospec/"
    "/path/to/juntogen/"
)
for spec_file in ${SCOPE_FILES}; do
    rel_path=$(basename "${spec_file}")
    for prefix in "${LEGACY_PREFIXES[@]}"; do
        while IFS=$'\t' read -r hline hcontent; do
            [ -z "${hline}" ] && continue
            emit_violation "legacy-path-form" "${rel_path}" "${hline}" \
                "legacy literal-path form '${prefix}' present; convert to [FILE: <basename>] (BL-025-h.3 ban; spec-file refs must derive from contract layout.spec_files[])"
        done < <(awk -v p="${prefix}" '{ if (index($0, p) > 0) printf "%d\t%s\n", NR, $0 }' "${spec_file}")
    done
done

# ── Pass 4: legacy src/ output-path form ban (BL-025-m.2) ────────────────
# Pre-cycle, generation prompts targeted a `src/` tree (e.g.
# `src/agents/`, `src/CLAUDE.md`, `src/commands/`). The m.1 retarget
# moved every output path to the plugin-tree-direct shape — `agents/`,
# `CONDUCTOR.md`, `skills/`. The step prompts still reference the old
# layout. This pass makes the legacy form a loud audit failure so
# m.2's prompt rewrites can be verified mechanically: the audit fires
# on every unconverted occurrence at sweep time and exits clean once
# every prompt has been converted.
#
# Detection: match `src/X` where X is in the hard-coded suffix
# allow-list — the directories/files that pre-cycle prompts emitted
# under src/. Anchored on a non-identifier prefix (line start or any
# character that is not alphanumeric / `.` / `_` / `/` / `-`) so that
# `~/.claude/src/` style bridge prose remains visible (the trailing
# `/src/` is part of an installed-system path, not an output-path
# binding) and `package/src/file.ts` style prose in step-10
# examples does NOT fire — only `src/<dir-from-allowlist>`.
#
# Hard-coded suffix allow-list (the pre-cycle output surfaces):
#   src/agents          (full + compact profiles)
#   src/reference       (reference files)
#   src/templates       (deliverable templates)
#   src/commands        (slash-command files; commands→skills in m.2)
#   src/org-scaffold    (org-coordination scaffold)
#   src/settings.json   (legacy settings file; plugin doesn't ship it)
#   src/CLAUDE.md       (legacy manager-protocol filename → CONDUCTOR.md)
#
# No keep_list per BL-025-m.2 scope — converging the prompts to the
# plugin tree is the entire point; there is no legitimate residual
# occurrence in a step prompt body.
echo -e "${YELLOW}[INFO]${NC} Pass 4: legacy-src-form ban (BL-025-m.2)"
LEGACY_SRC_REGEX='(^|[^a-zA-Z0-9._/-])src/(agents|reference|templates|commands|org-scaffold|settings\.json|CLAUDE\.md)'
for spec_file in ${SCOPE_FILES}; do
    rel_path=$(basename "${spec_file}")
    while IFS=$'\t' read -r hline hcontent; do
        [ -z "${hline}" ] && continue
        emit_violation "legacy-src-form" "${rel_path}" "${hline}" \
            "legacy 'src/<dir>' output-path form present; convert to plugin-tree-direct shape (BL-025-m.2 ban; src/agents→agents/, src/reference→reference/, src/templates→templates/, src/commands→skills/, src/CLAUDE.md→CONDUCTOR.md, src/settings.json removed)"
    done < <(awk -v re="${LEGACY_SRC_REGEX}" 'match($0, re) { printf "%d\t%s\n", NR, $0 }' "${spec_file}")
done

echo

# ── Summary ───────────────────────────────────────────────────────────────
echo "================================"
if [ "${VIOLATIONS}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} step-prompt-vocabulary-audit: 0 violations"
    echo "================================"
    exit 0
else
    echo -e "${RED}FAIL${NC} step-prompt-vocabulary-audit: ${VIOLATIONS} violation(s) — see structured stderr above"
    echo "================================"
    exit 1
fi
