#!/usr/bin/env bash
#
# contract-validate.sh — BL-025-g/h.1 contract↔corpus bijection enforcer.
#
# PURPOSE: Assert that the platform contract (juntospec/platform-contract.yaml)
#          and the spec corpus (juntospec/{D,F,M}*.md, plus juntogen-resident
#          canonical sources flagged via `file_repo: juntogen`) are in
#          bijective agreement on canonical_ids and on layout.spec_files
#          referenced from juntogen step prompts.
#
# Three independent directions (BL-025-g) plus a 4th (BL-025-h.1):
#
#   D1 forward (canonical_ids):
#     contract.canonical_ids[]  → [CANONICAL: id] marker in host file
#   D2 reverse (canonical_ids):
#     [CANONICAL: id] marker in corpus → contract.canonical_ids[] entry
#   D3 spec_files presence (BL-025-h.1):
#     contract.layout.spec_files[] → file actually exists at resolved path
#   D4 spec-file-marker-closure (BL-025-h.1):
#     [FILE: basename] / [CANONICAL: id] markers in juntogen step prompts
#     resolve to declared layout.spec_files[] / canonical_ids[] entries.
#     Scope: juntogen/claude/steps/step-*.md only. Literal path forms
#     (/path/to/juntospec/X) — once the step-prompt conversion lands —
#     are zero, so this check enforces the marker contract going forward.
#
# ORTHOGONALITY (FINDING-7 — verbatim, do not collapse):
#   D1+D2 mirror validate-dry-run.sh Check c (which walks step prompts →
#   asserts ids exist in contract). All three must run; deleting any
#   creates a one-way blind spot.
#   D4 catches step-prompt → contract drift at preflight time, eliminating
#   the silent literal-marker emission failure mode (BL-025-h.1 F-01).
#
# Failure-mode categories:
#   canonical-id-file-missing        contract entry's file path doesn't resolve
#   canonical-id-missing-marker      file resolves but [CANONICAL: id] marker absent
#   canonical-id-orphan-marker       spec file contains [CANONICAL: id] for an
#                                    id NOT declared in the contract
#   spec-file-missing                contract.layout.spec_files[] entry's path
#                                    does not resolve to a real file (D3)
#   spec-file-marker-orphan          [FILE: x] in step prompt with no matching
#                                    layout.spec_files[].file (D4)
#   canonical-id-marker-orphan       [CANONICAL: y] in step prompt with no
#                                    matching contract.canonical_ids[].id (D4)
#   unsupported-file-repo            contract row's `file_repo` is neither
#                                    empty/juntospec nor juntogen — refuses
#                                    to silently fall through (F2 mitigation;
#                                    note: load-contract.py's parse-time enum
#                                    guard fires first and exits 1 — this
#                                    branch only fires in legacy paths)
#   juntogen-root-resolution-failed  autodetect / explicit --juntogen-root does
#                                    not point at a real juntogen tree
#
# The `section:` field is NOT validated — it is a human-readable pointer
# only, per the contract preamble at platform-contract.yaml:19-20 (F3
# mitigation; section text drifts under refactors and is not a parser
# contract).
#
# USAGE:
#   contract-validate.sh \
#       --spec-dir /path/to/juntospec \
#       [--juntogen-root /path/to/juntogen]   # default = realpath ${SCRIPT_DIR}/../../..
#       [--steps-dir /path/to/juntogen/claude/steps]   # default = ${juntogen_root}/claude/steps
#       [--skip-marker-closure]                # opt out of D4 (test fixtures)
#
# Or via env vars (lower precedence than flags):
#   OJ_SPEC_DIR        same as --spec-dir
#   OJ_JUNTOGEN_ROOT   same as --juntogen-root
#   OJ_STEPS_DIR       same as --steps-dir
#
# EXIT CODES:
#   0 — pass (zero violations)
#   1 — at least one bijection violation
#   2 — driver error (missing dependency, bad args, unresolvable paths, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output.
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

SPEC_DIR="${OJ_SPEC_DIR:-}"
JUNTOGEN_ROOT="${OJ_JUNTOGEN_ROOT:-}"
STEPS_DIR="${OJ_STEPS_DIR:-}"
SKIP_MARKER_CLOSURE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --spec-dir)
            [ $# -ge 2 ] || { echo "ERROR: --spec-dir requires a value" >&2; exit 2; }
            SPEC_DIR="$2"; shift 2 ;;
        --juntogen-root)
            [ $# -ge 2 ] || { echo "ERROR: --juntogen-root requires a value" >&2; exit 2; }
            JUNTOGEN_ROOT="$2"; shift 2 ;;
        --steps-dir)
            [ $# -ge 2 ] || { echo "ERROR: --steps-dir requires a value" >&2; exit 2; }
            STEPS_DIR="$2"; shift 2 ;;
        --skip-marker-closure)
            SKIP_MARKER_CLOSURE=1; shift ;;
        --help|-h)
            sed -n '2,80p' "$0"; exit 0 ;;
        *)
            echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
    esac
done

# Required input.
[ -d "${SPEC_DIR}" ] || {
    echo -e "${RED}ERROR${NC} SPEC_DIR not a directory: ${SPEC_DIR:-<unset>}" >&2
    echo "       pass --spec-dir /path/to/juntospec or export OJ_SPEC_DIR" >&2
    exit 2
}

command -v python3 >/dev/null 2>&1 || {
    echo -e "${RED}ERROR${NC} python3 not on PATH" >&2; exit 2
}

# Autodetect juntogen-root: SCRIPT_DIR is juntogen/claude/validation/scripts,
# so juntogen root is 3 levels up. cd-then-pwd normalizes any symlinks
# (F9 mitigation). The sentinel check below verifies the path is real.
if [ -z "${JUNTOGEN_ROOT}" ]; then
    JUNTOGEN_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
fi
JUNTOGEN_ROOT="$(cd "${JUNTOGEN_ROOT}" 2>/dev/null && pwd)" || {
    echo -e "${RED}ERROR${NC} juntogen-root path does not exist: ${JUNTOGEN_ROOT}" >&2
    exit 2
}
SPEC_DIR="$(cd "${SPEC_DIR}" && pwd)"

# F1 mitigation: realpath sanity check. If JUNTOGEN_ROOT is bogus the
# cross-repo lookups will silently fail with `canonical-id-file-missing`,
# which masks a configuration bug as a corpus-drift bug. Hard-fail upfront.
SENTINEL="${JUNTOGEN_ROOT}/claude/D64-tooling.md"
if [ ! -f "${SENTINEL}" ]; then
    echo -e "${RED}ERROR${NC} juntogen-root sanity check failed" >&2
    printf 'CATEGORY: %s | FILE: %s | LINE: %s | DETAIL: %s\n' \
        "juntogen-root-resolution-failed" \
        "${JUNTOGEN_ROOT}" \
        "0" \
        "expected sentinel file claude/D64-tooling.md to exist; pass --juntogen-root /path/to/juntogen if autodetect is wrong" >&2
    exit 2
fi

LOAD_PY="${SCRIPT_DIR}/lib/load-contract.py"
[ -f "${LOAD_PY}" ] || {
    echo -e "${RED}ERROR${NC} load-contract.py missing at ${LOAD_PY}" >&2; exit 2
}

CONTRACT="${SPEC_DIR}/platform-contract.yaml"
[ -f "${CONTRACT}" ] || {
    echo -e "${RED}ERROR${NC} platform-contract.yaml not found at ${CONTRACT}" >&2
    exit 2
}

# BL-025-h.1: autodetect STEPS_DIR if not provided. The 4th-direction
# spec-file-marker-closure check scans juntogen/claude/steps/step-*.md.
# If the directory does not exist (e.g., custom test harness), the check
# is silently skipped — the gate fires only on real-corpus drift.
if [ -z "${STEPS_DIR}" ]; then
    STEPS_DIR="${JUNTOGEN_ROOT}/claude/steps"
fi
if [ -d "${STEPS_DIR}" ]; then
    STEPS_DIR="$(cd "${STEPS_DIR}" && pwd)"
fi

echo -e "${YELLOW}[INFO]${NC} contract-validate: spec dir       = ${SPEC_DIR}"
echo -e "${YELLOW}[INFO]${NC} contract-validate: juntogen root  = ${JUNTOGEN_ROOT}"
echo -e "${YELLOW}[INFO]${NC} contract-validate: contract       = ${CONTRACT}"
echo -e "${YELLOW}[INFO]${NC} contract-validate: steps dir      = ${STEPS_DIR} ($([ -d "${STEPS_DIR}" ] && echo present || echo absent))"
echo

# Pull the contract's canonical_ids as 4-column TSV: id<TAB>file<TAB>section<TAB>file_repo
CONTRACT_ROWS=$(python3 "${LOAD_PY}" canonical-ids "${CONTRACT}")
if [ -z "${CONTRACT_ROWS}" ]; then
    echo -e "${RED}ERROR${NC} contract.canonical_ids is empty" >&2
    exit 2
fi

# KNOWN_IDS used by reverse scan to detect orphan markers. Sorted unique.
KNOWN_IDS=$(printf '%s\n' "${CONTRACT_ROWS}" | awk -F'\t' '{print $1}' | sort -u)

# Stage violations into a tempfile so we can sort them deterministically
# (FINDING-8) before emitting to stderr at the end.
VIOL_FILE="$(mktemp -t contract-validate-viols-XXXXXX)"
trap 'rm -f "${VIOL_FILE}"' EXIT

# stage_violation: CATEGORY FILE LINE DETAIL — all four fields tab-free.
stage_violation() {
    # Format identical to validate-dry-run.sh:103-107 final output.
    printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >>"${VIOL_FILE}"
}

# ── Forward checks: contract -> corpus ───────────────────────────────────
echo -e "${YELLOW}[INFO]${NC} Forward check: contract -> corpus (every entry's marker present?)"
FORWARD_VIOL_BEFORE=0
[ -s "${VIOL_FILE}" ] && FORWARD_VIOL_BEFORE=$(wc -l <"${VIOL_FILE}" | tr -d '[:space:]')

# Bash IFS read loop on TSV. Trailing _extra absorbs any future column
# growth (parse-contract-schema-test.sh idiom; BL-028 lesson).
while IFS=$'\t' read -r cid cfile csection cfile_repo _extra; do
    [ -z "${cid}" ] && continue

    # Resolve file_repo:
    case "${cfile_repo}" in
        ""|juntospec)
            resolved_path="${SPEC_DIR}/${cfile}"
            ;;
        juntogen)
            resolved_path="${JUNTOGEN_ROOT}/${cfile}"
            ;;
        *)
            stage_violation \
                "unsupported-file-repo" \
                "${cfile}" \
                "0" \
                "id=${cid} declares file_repo=${cfile_repo}; only empty|juntospec|juntogen are supported. Update contract or extend contract-validate.sh resolver."
            continue
            ;;
    esac

    if [ ! -f "${resolved_path}" ]; then
        stage_violation \
            "canonical-id-file-missing" \
            "${cfile}" \
            "0" \
            "id=${cid} contract row points at file that does not exist (resolved=${resolved_path}); fix file: in contract or restore the source file."
        continue
    fi

    # Use grep -nF (literal, with line numbers). On match, we record the
    # first matching line for the FILE/LINE detail; on no match, fire
    # missing-marker. The forward direction does not need to enumerate
    # multiple matches — the reverse direction does that.
    if ! grep -nF -- "[CANONICAL: ${cid}]" "${resolved_path}" >/dev/null 2>&1; then
        stage_violation \
            "canonical-id-missing-marker" \
            "${cfile}" \
            "0" \
            "id=${cid} declared in contract but [CANONICAL: ${cid}] marker is absent from ${resolved_path}; either add the marker at the canonical section or remove the contract entry."
    fi
done <<EOF
${CONTRACT_ROWS}
EOF

# ── Reverse check: corpus -> contract ────────────────────────────────────
echo -e "${YELLOW}[INFO]${NC} Reverse check: corpus -> contract (every marker declared?)"

# Scan list:
#   1. juntospec D/F/M*.md spec corpus
#   2. plus, for every distinct file_repo: juntogen contract row, the
#      resolved file inside juntogen-root.
# This asymmetric scan is principled: spec corpus is the canonical-source
# main territory; juntogen-resident canonical sources are tracked
# exceptions enumerated by the contract's `file_repo` field (TENSION-3).
SCAN_FILES_RAW=""
# nullglob-equivalent: use find so missing prefixes don't break the loop.
for prefix in D F M; do
    while IFS= read -r -d '' f; do
        SCAN_FILES_RAW="${SCAN_FILES_RAW}${f}"$'\n'
    done < <(find "${SPEC_DIR}" -maxdepth 1 -type f -name "${prefix}*.md" -print0 2>/dev/null)
done

# Add juntogen-resident rows.
JUNTOGEN_FILES=$(printf '%s\n' "${CONTRACT_ROWS}" | awk -F'\t' '$4 == "juntogen" {print $2}' | sort -u)
while IFS= read -r jfile; do
    [ -z "${jfile}" ] && continue
    resolved="${JUNTOGEN_ROOT}/${jfile}"
    if [ -f "${resolved}" ]; then
        SCAN_FILES_RAW="${SCAN_FILES_RAW}${resolved}"$'\n'
    fi
    # If absent, the forward check already fired canonical-id-file-missing.
    # We don't re-fire here.
done <<EOF
${JUNTOGEN_FILES}
EOF

# Deduplicate and sort scan list.
SCAN_FILES=$(printf '%s' "${SCAN_FILES_RAW}" | awk 'NF' | sort -u)

# For each file, find every line containing one or more [CANONICAL: id]
# markers. For each match line, extract every id on that line via grep -oE
# (FINDING-4 / F5: multi-id lines like D24:20 must surface all 4 ids; do
# NOT replicate validate-dry-run.sh:174's `head -1` bug).
while IFS= read -r sf; do
    [ -z "${sf}" ] && continue
    [ -f "${sf}" ] || continue
    # Display path: spec-corpus rows show basename; juntogen-rooted rows
    # show the relative path from juntogen-root for clarity.
    case "${sf}" in
        "${SPEC_DIR}"/*) display="$(basename "${sf}")" ;;
        "${JUNTOGEN_ROOT}"/*) display="${sf#${JUNTOGEN_ROOT}/}" ;;
        *) display="${sf}" ;;
    esac

    # First pass: capture line numbers of any line carrying a marker.
    while IFS=':' read -r lineno rest; do
        [ -z "${lineno}" ] && continue
        # Extract every id on this line.
        while IFS= read -r marker; do
            [ -z "${marker}" ] && continue
            # marker is literally `[CANONICAL: foo]` — strip the brackets/prefix.
            cid=$(printf '%s' "${marker}" \
                | sed -nE 's/^\[CANONICAL:[[:space:]]*([a-zA-Z0-9_-]+)\]$/\1/p')
            [ -z "${cid}" ] && continue
            # Meta-id placeholder; documentation reference, not a real ref
            # (validate-dry-run.sh:179 precedent).
            if [ "${cid}" = "id" ]; then
                continue
            fi
            if ! printf '%s\n' "${KNOWN_IDS}" | grep -qx -- "${cid}"; then
                stage_violation \
                    "canonical-id-orphan-marker" \
                    "${display}" \
                    "${lineno}" \
                    "[CANONICAL: ${cid}] present in corpus but not declared in contract.canonical_ids; either add a contract entry or remove the marker."
            fi
        done < <(printf '%s' "${rest}" | grep -oE '\[CANONICAL:[[:space:]]*[a-zA-Z0-9_-]+\]' || true)
    done < <(grep -nE '\[CANONICAL:[[:space:]]*[a-zA-Z0-9_-]+\]' "${sf}" 2>/dev/null || true)
done <<EOF
${SCAN_FILES}
EOF

# ── D3: spec_files presence (BL-025-h.1) ─────────────────────────────────
echo -e "${YELLOW}[INFO]${NC} D3: spec_files presence (every layout.spec_files[] entry resolves to a file)"
SPEC_FILES_TSV=$(python3 "${LOAD_PY}" spec-files "${CONTRACT}")
# KNOWN_SPEC_FILES used by D4 to validate [FILE: basename] markers.
KNOWN_SPEC_FILES=$(printf '%s\n' "${SPEC_FILES_TSV}" | awk -F'\t' 'NF>0 {print $1}' | sort -u)

while IFS=$'\t' read -r sfile sfile_repo spath _extra; do
    [ -z "${sfile}" ] && continue
    case "${sfile_repo}" in
        ""|juntospec)
            resolved_sf="${SPEC_DIR}/${spath}"
            ;;
        juntogen)
            resolved_sf="${JUNTOGEN_ROOT}/${spath}"
            ;;
        *)
            stage_violation \
                "unsupported-file-repo" \
                "${spath}" \
                "0" \
                "spec_files entry file=${sfile} declares file_repo=${sfile_repo}; only empty|juntospec|juntogen are supported."
            continue
            ;;
    esac
    if [ ! -f "${resolved_sf}" ]; then
        stage_violation \
            "spec-file-missing" \
            "${spath}" \
            "0" \
            "layout.spec_files[file=${sfile}] resolves to ${resolved_sf} which does not exist; remove the entry or restore the file."
    fi
done <<EOF
${SPEC_FILES_TSV}
EOF

# ── D4: spec-file-marker-closure (BL-025-h.1) ────────────────────────────
# Scope: juntogen/claude/steps/step-*.md. Every [FILE: basename] must
# resolve to a layout.spec_files[].file entry; every [CANONICAL: id]
# must resolve to a contract.canonical_ids[].id entry. The 4th direction
# closes the loop on step-prompt → contract drift before the LLM ever
# sees the substituted output (BL-025-h.1 F-01 mitigation).
if [ "${SKIP_MARKER_CLOSURE}" -eq 1 ]; then
    echo -e "${YELLOW}[INFO]${NC} D4: skipped via --skip-marker-closure"
elif [ ! -d "${STEPS_DIR}" ]; then
    echo -e "${YELLOW}[INFO]${NC} D4: skipped (steps dir absent: ${STEPS_DIR})"
else
    echo -e "${YELLOW}[INFO]${NC} D4: spec-file-marker-closure (juntogen step prompts)"
    STEP_FILES=$(find "${STEPS_DIR}" -maxdepth 1 -type f -name 'step-*.md' 2>/dev/null | sort)
    while IFS= read -r stepf; do
        [ -z "${stepf}" ] && continue
        rel_step=$(basename "${stepf}")
        # Find every [FILE: basename] occurrence with line number.
        while IFS=':' read -r lineno rest; do
            [ -z "${lineno}" ] && continue
            while IFS= read -r marker; do
                [ -z "${marker}" ] && continue
                bn=$(printf '%s' "${marker}" \
                    | sed -nE 's/^\[FILE:[[:space:]]*([A-Za-z0-9._-]+)\]$/\1/p')
                [ -z "${bn}" ] && continue
                if ! printf '%s\n' "${KNOWN_SPEC_FILES}" | grep -qx -- "${bn}"; then
                    stage_violation \
                        "spec-file-marker-orphan" \
                        "${rel_step}" \
                        "${lineno}" \
                        "[FILE: ${bn}] used in step prompt but no matching layout.spec_files[].file in contract; add a contract entry or fix the marker."
                fi
            done < <(printf '%s' "${rest}" | grep -oE '\[FILE:[[:space:]]*[A-Za-z0-9._-]+\]' || true)
        done < <(grep -nE '\[FILE:[[:space:]]*[A-Za-z0-9._-]+\]' "${stepf}" 2>/dev/null || true)
        # Find every [CANONICAL: id] occurrence with line number.
        while IFS=':' read -r lineno rest; do
            [ -z "${lineno}" ] && continue
            while IFS= read -r marker; do
                [ -z "${marker}" ] && continue
                cid=$(printf '%s' "${marker}" \
                    | sed -nE 's/^\[CANONICAL:[[:space:]]*([a-zA-Z0-9_-]+)\]$/\1/p')
                [ -z "${cid}" ] && continue
                # Meta-id placeholder; documentation reference, not a real ref.
                if [ "${cid}" = "id" ]; then
                    continue
                fi
                if ! printf '%s\n' "${KNOWN_IDS}" | grep -qx -- "${cid}"; then
                    stage_violation \
                        "canonical-id-marker-orphan" \
                        "${rel_step}" \
                        "${lineno}" \
                        "[CANONICAL: ${cid}] used in step prompt but not declared in contract.canonical_ids; add a contract entry or fix the marker."
                fi
            done < <(printf '%s' "${rest}" | grep -oE '\[CANONICAL:[[:space:]]*[a-zA-Z0-9_-]+\]' || true)
        done < <(grep -nE '\[CANONICAL:[[:space:]]*[a-zA-Z0-9_-]+\]' "${stepf}" 2>/dev/null || true)
    done <<EOF
${STEP_FILES}
EOF
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo
VIOL_COUNT=0
if [ -s "${VIOL_FILE}" ]; then
    VIOL_COUNT=$(wc -l <"${VIOL_FILE}" | tr -d '[:space:]')
fi

echo "================================"
if [ "${VIOL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} contract-validate: 0 bijection violations"
    echo "================================"
    exit 0
fi

# Sort lexicographically by (category, file, line, detail) — FINDING-8.
# `sort` over the TSV with -k1,1 -k2,2 -k3,3n -k4,4 keeps the sort stable
# AND deterministic across BSD/GNU because we use POSIX field selectors.
sort -t $'\t' -k1,1 -k2,2 -k3,3n -k4,4 "${VIOL_FILE}" \
    | while IFS=$'\t' read -r cat fl ln dt; do
        printf 'CATEGORY: %s | FILE: %s | LINE: %s | DETAIL: %s\n' \
            "${cat}" "${fl}" "${ln}" "${dt}" >&2
    done

echo -e "${RED}FAIL${NC} contract-validate: ${VIOL_COUNT} violation(s) — see structured stderr above"
echo "================================"
exit 1
