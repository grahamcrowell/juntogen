#!/usr/bin/env bash
#
# vocabulary-audit.sh — BL-025-e core spec corpus vocabulary audit.
#
# PURPOSE: Fail closed when the juntospec core spec corpus contains banned
#          Claude-platform identifiers outside an exempted region or an
#          explicit keep_list entry. Mirrors and extends the BL-026/BL-025-d
#          intent enforced inline by tier-a-assertions.sh §13/§14/§15/§16
#          (which run only after generation produces oj-claude/src/CLAUDE.md
#          and so cannot guard regen prerequisites).
#
# SCOPE:   juntospec/{D,F,M}*.md, README.md, MANIFEST.md (the core spec
#          corpus). The juntogen/claude/* generator tree is a separate repo
#          and is OUT of scope by design.
#
# DETECTION CATEGORIES (per stderr `CATEGORY:` field):
#   banned-term-bleed   — banned term outside keep_list AND outside exempt regions
#   hash-drift          — keep_list context_hash != recomputed shasum (covers stale-hash)
#   term-mismatch       — keep_list term not literally present at file:line
#   invalid-reason      — keep_list reason not in permitted enum
#   pending-signoff     — keep_list signed_off_by == "pending-tech-writer-review"
#
# EXIT CODES:
#   0 — all checks pass
#   1 — one or more violations
#   2 — driver error (yaml helper missing, contract not found, etc.)
#
# Permitted reason enum (line up with platform-contract.yaml comment):
#   historical-anchor, platform-binding-surface, snapshot-doc,
#   filesystem-bridge, manager-protocol-bridge, external-url,
#   non-mechanical-1
#
# USAGE:
#   vocabulary-audit.sh /path/to/juntospec  # positional arg (highest precedence)
#   OJ_SPEC_DIR=/path/to/juntospec vocabulary-audit.sh   # env var
#   vocabulary-audit.sh                     # sibling probe (juntogen ↔ juntospec)
#
# Structured stderr lines:
#   CATEGORY: <kind> | FILE: <path> | LINE: <line> | DETAIL: <free-form>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# BL-025-f: validation/ now lives in juntogen, not juntospec. SPEC_ROOT is
# resolved via the same precedence chain as the generate script:
#   1. positional arg ($1)        caller passes spec corpus path explicitly
#   2. ${OJ_SPEC_DIR}              environment variable
#   3. sibling probe               juntogen ↔ juntospec under common parent
#                                  (script lives at juntogen/claude/validation/
#                                  scripts/, so juntospec sibling is 4 levels up)
#   4. hard-fail                   actionable message naming all 3 surfaces
if [ -n "${1:-}" ]; then
    SPEC_ROOT="$1"
elif [ -n "${OJ_SPEC_DIR:-}" ]; then
    SPEC_ROOT="${OJ_SPEC_DIR}"
elif [ -d "${SCRIPT_DIR}/../../../../juntospec" ]; then
    SPEC_ROOT="$(cd "${SCRIPT_DIR}/../../../../juntospec" && pwd)"
else
    echo "ERROR: cannot locate juntospec corpus root. Provide one of:" >&2
    echo "  positional arg           vocabulary-audit.sh /path/to/juntospec" >&2
    echo "  OJ_SPEC_DIR=DIR (env)    exported environment variable" >&2
    echo "  sibling layout           juntogen/ and juntospec/ as siblings under" >&2
    echo "                           a common parent (recommended; e.g." >&2
    echo "                           /path/to/openjunto/{juntogen,juntospec})." >&2
    echo "Searched: positional arg (unset), \$OJ_SPEC_DIR (unset), sibling probe at" >&2
    echo "${SCRIPT_DIR}/../../../../juntospec (not a directory)." >&2
    exit 2
fi

if [ ! -d "${SPEC_ROOT}" ]; then
    echo "ERROR: SPEC_ROOT is not a directory: ${SPEC_ROOT}" >&2
    exit 2
fi

CONTRACT="${SPEC_ROOT}/platform-contract.yaml"
EXEMPT_AWK="${SCRIPT_DIR}/lib/exempt-regions.awk"
PARSE_PY="${SCRIPT_DIR}/lib/parse-contract.py"

# Permitted reason enum.
readonly REASON_ENUM="historical-anchor platform-binding-surface snapshot-doc filesystem-bridge manager-protocol-bridge external-url non-mechanical-1"

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
[ -f "${EXEMPT_AWK}" ] || { echo -e "${RED}ERROR${NC} exempt-regions.awk missing at ${EXEMPT_AWK}" >&2; exit 2; }
[ -f "${PARSE_PY}" ]   || { echo -e "${RED}ERROR${NC} parse-contract.py missing at ${PARSE_PY}" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}ERROR${NC} python3 not on PATH" >&2; exit 2; }

# ── Pull tables ───────────────────────────────────────────────────────────
KEEP_TSV=$(python3 "${PARSE_PY}" keep-list "${CONTRACT}")
BANNED_TSV=$(python3 "${PARSE_PY}" banned-terms "${CONTRACT}")

KEEP_COUNT=$(printf '%s\n' "${KEEP_TSV}" | grep -c . || true)
BANNED_COUNT=$(printf '%s\n' "${BANNED_TSV}" | grep -c . || true)

echo -e "${YELLOW}[INFO]${NC} vocabulary-audit: ${BANNED_COUNT} banned terms, ${KEEP_COUNT} keep_list entries"
echo -e "${YELLOW}[INFO]${NC} spec root: ${SPEC_ROOT}"
echo

# ── Pass 1: keep_list integrity ───────────────────────────────────────────
# Validate every keep_list entry: pending-signoff, invalid-reason, term-mismatch, hash-drift.
echo -e "${YELLOW}[INFO]${NC} Pass 1: keep_list integrity (term/hash/reason/signoff)"

while IFS=$'\t' read -r kfile kline kterm kkind khash kreason ksigner _extra; do
    # BL-028 schema-drift guard: parse-contract.py keep-list emits 7 columns
    # (COLUMN_COUNT: 7). If a future change grows the schema, _extra catches
    # the overflow before the loop body uses any field. Fail loudly here
    # rather than silently polluting ksigner with an embedded tab.
    if [ -n "${_extra}" ]; then
        echo "ERROR: parse-contract.py emitted >7 columns for keep-list; consumer must be updated (BL-028 schema-drift guard)" >&2
        exit 2
    fi
    [ -z "${kfile}" ] && continue

    abs="${SPEC_ROOT}/${kfile}"
    if [ ! -f "${abs}" ]; then
        emit_violation "term-mismatch" "${kfile}" "${kline}" "keep_list file does not exist"
        continue
    fi

    # pending-signoff (block-ship policy per BL-025-e T3)
    if [ "${ksigner}" = "pending-tech-writer-review" ]; then
        emit_violation "pending-signoff" "${kfile}" "${kline}" "keep_list entry has pending-tech-writer-review signer (term=${kterm})"
    fi

    # multi-cover-keep-list: a keep_list entry's `term` MUST NOT be a superstring
    # of two or more banned terms. The substring-cover rule in in_keep_list()
    # would otherwise let a single signoff silently exempt multiple bleeds
    # (the canonical example: a keep_list entry with term "~/.claude/CLAUDE.md"
    # would cover BOTH banned `~/.claude/` AND banned `CLAUDE.md` under one
    # signoff). The invariant: one keep_list entry covers exactly one banned
    # term. Lines that legitimately need to exempt N banned terms must use N
    # separate keep_list entries (the M16:116 / :148 / :173 multi-row pattern).
    # Regex-kind banned terms are skipped here (they describe patterns, not
    # literal substrings — substring containment would be a category error).
    multi_covered=""
    multi_count=0
    while IFS=$'\t' read -r mb_term mb_kind mb_scope mb_regions mb_assertion _extra; do
        # BL-028 schema-drift guard: banned-terms emits 5 columns (COLUMN_COUNT: 5).
        # _extra catches future schema growth before mb_assertion gets polluted.
        if [ -n "${_extra}" ]; then
            echo "ERROR: parse-contract.py emitted >5 columns for banned-terms; consumer must be updated (BL-028 schema-drift guard)" >&2
            exit 2
        fi
        [ -z "${mb_term}" ] && continue
        [ "${mb_kind}" != "literal" ] && continue
        case "${kterm}" in
            *"${mb_term}"*)
                multi_count=$((multi_count + 1))
                if [ -z "${multi_covered}" ]; then
                    multi_covered="${mb_term}"
                else
                    multi_covered="${multi_covered}, ${mb_term}"
                fi
                ;;
        esac
    done <<< "${BANNED_TSV}"
    if [ "${multi_count}" -ge 2 ]; then
        emit_violation "multi-cover-keep-list" "${kfile}" "${kline}" "keep_list term '${kterm}' covers banned terms [${multi_covered}] under a single signoff (reason='${kreason}'); split into per-banned-term entries with distinct reasons."
    fi

    # invalid-reason
    if ! echo " ${REASON_ENUM} " | grep -q " ${kreason} "; then
        emit_violation "invalid-reason" "${kfile}" "${kline}" "keep_list reason '${kreason}' not in permitted enum (term=${kterm})"
    fi

    # Range form (e.g., "42-47") — pick first line in range for term/hash check.
    line_for_check="${kline}"
    case "${kline}" in
        *-*) line_for_check="${kline%%-*}" ;;
    esac

    # term-mismatch: literal substring search at exact line. Regex-kind keep_list
    # entries (none today) would need different logic; emit a clear error.
    if [ "${kkind}" = "literal" ]; then
        actual_line=$(awk -v n="${line_for_check}" 'NR==n' "${abs}")
        case "${actual_line}" in
            *"${kterm}"*) ;;  # match
            *)
                emit_violation "term-mismatch" "${kfile}" "${kline}" "keep_list term '${kterm}' not present at ${kfile}:${kline}"
                ;;
        esac
    elif [ "${kkind}" = "regex" ]; then
        actual_line=$(awk -v n="${line_for_check}" 'NR==n' "${abs}")
        if ! echo "${actual_line}" | grep -qE "${kterm}"; then
            emit_violation "term-mismatch" "${kfile}" "${kline}" "keep_list regex '${kterm}' does not match at ${kfile}:${kline}"
        fi
    else
        emit_violation "term-mismatch" "${kfile}" "${kline}" "keep_list match_kind '${kkind}' is not literal|regex"
    fi

    # hash-drift: recomputed sha256[0:8] of the line content vs stored.
    # Empty stored hash skips the check (legacy entries; flagged separately as drift if needed).
    if [ -n "${khash}" ]; then
        recomp=$(awk -v n="${line_for_check}" 'NR==n' "${abs}" | shasum -a 256 | cut -c1-8)
        if [ "${recomp}" != "${khash}" ]; then
            emit_violation "hash-drift" "${kfile}" "${kline}" "context_hash drift (stored=${khash}, recomputed=${recomp}, term=${kterm})"
        fi
    fi
done <<< "${KEEP_TSV}"

# ── Pass 2: banned-term-bleed sweep ───────────────────────────────────────
echo -e "${YELLOW}[INFO]${NC} Pass 2: banned-term-bleed sweep (${BANNED_COUNT} terms × core spec corpus)"

# Build a temp keep_list lookup: file<TAB>line<TAB>term
KEEP_LOOKUP=$(printf '%s\n' "${KEEP_TSV}" | awk -F'\t' '{print $1"\t"$2"\t"$3}')

# In-keep helper — checks (file, line, term) against the lookup.
# Match semantics:
#   - file must equal the keep_list entry's file.
#   - line must equal entry's line OR fall inside its range form ("42-47").
#   - term match: the keep_list entry's term must CONTAIN the banned term
#     as a substring. This handles legitimate overlap cases where a longer
#     keep_list term (e.g. "~/.claude/.oj-version", "openjunto/.claude/CLAUDE.md",
#     ".claude/CLAUDE.md") signs off the broader line context that ALSO
#     contains a shorter banned term ("~/.claude/", "CLAUDE.md").
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

# Discover scope files. Core spec corpus = {D,F,M}*.md plus README/MANIFEST at root.
SCOPE_FILES=$(
    for pat in "D[0-9]*.md" "F[0-9]*.md" "M[0-9]*.md"; do
        # shellcheck disable=SC2086
        ls "${SPEC_ROOT}"/${pat} 2>/dev/null || true
    done
    if [ -f "${SPEC_ROOT}/README.md" ];   then echo "${SPEC_ROOT}/README.md";   fi
    if [ -f "${SPEC_ROOT}/MANIFEST.md" ]; then echo "${SPEC_ROOT}/MANIFEST.md"; fi
)

while IFS=$'\t' read -r bterm bkind bscope bregions bassertion _extra; do
    # BL-028 schema-drift guard: banned-terms emits 5 columns (COLUMN_COUNT: 5).
    # This is the loop where the original silent-pollution bug surfaced — the
    # assertion column was absorbed into bregions and only unmasked when a
    # downstream cleanup stripped a coincidental 3-region exempt list.
    if [ -n "${_extra}" ]; then
        echo "ERROR: parse-contract.py emitted >5 columns for banned-terms; consumer must be updated (BL-028 schema-drift guard)" >&2
        exit 2
    fi
    [ -z "${bterm}" ] && continue

    # Translate exempt-region csv into a quick-membership awk regex.
    # Region matching is exact-name; convert "a,b,c" → "(^|,)a(,|$)" style is
    # overkill — we just check substring containment against ',a,'.
    regions_padded=",${bregions},"

    for spec_file in ${SCOPE_FILES}; do
        rel_name=$(basename "${spec_file}")
        rel_path="${spec_file#${SPEC_ROOT}/}"

        # Run exempt-regions.awk to label every line. Then for each line,
        # decide whether the banned term appears AND whether the line is in
        # an exempt region for this banned term.
        labeled=$(awk -f "${EXEMPT_AWK}" "${spec_file}")

        # Per-line scan in awk. We pass the term/regions via -v and let awk
        # emit the candidate hit lines; bash then checks keep_list.
        if [ "${bkind}" = "literal" ]; then
            # Literal substring; build a regex-safe form by escaping awk
            # regex metachars. Simpler: use index() rather than match().
            hits=$(printf '%s\n' "${labeled}" | awk -F'\t' -v t="${bterm}" -v rp="${regions_padded}" '
                {
                    if (index($3, t) == 0) next
                    # Check whether any of THIS line'\''s regions are in rp.
                    n = split($1, lr, ",")
                    exempt = 0
                    for (i = 1; i <= n; i++) {
                        if (lr[i] != "" && index(rp, "," lr[i] ",") > 0) { exempt = 1; break }
                    }
                    if (exempt) next
                    printf "%d\t%s\n", $2, $3
                }
            ')
        else
            # Regex kind; pass to awk as a pattern.
            hits=$(printf '%s\n' "${labeled}" | awk -F'\t' -v re="${bterm}" -v rp="${regions_padded}" '
                {
                    if ($3 !~ re) next
                    n = split($1, lr, ",")
                    exempt = 0
                    for (i = 1; i <= n; i++) {
                        if (lr[i] != "" && index(rp, "," lr[i] ",") > 0) { exempt = 1; break }
                    }
                    if (exempt) next
                    printf "%d\t%s\n", $2, $3
                }
            ')
        fi

        [ -z "${hits}" ] && continue

        # For each hit, check keep_list. If listed, accept silently. Else flag.
        while IFS=$'\t' read -r hline hcontent; do
            [ -z "${hline}" ] && continue
            if in_keep_list "${rel_path}" "${hline}" "${bterm}"; then
                continue
            fi
            emit_violation "banned-term-bleed" "${rel_path}" "${hline}" "banned term '${bterm}' (kind=${bkind}) outside keep_list and exempt regions"
        done <<< "${hits}"
    done
done <<< "${BANNED_TSV}"

echo

# ── Summary ───────────────────────────────────────────────────────────────
echo "================================"
if [ "${VIOLATIONS}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} vocabulary-audit: 0 violations"
    echo "================================"
    exit 0
else
    echo -e "${RED}FAIL${NC} vocabulary-audit: ${VIOLATIONS} violation(s) — see structured stderr above"
    echo "================================"
    exit 1
fi
