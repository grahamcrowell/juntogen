#!/usr/bin/env bash
#
# structural-diff.sh — BL-025-m.1 Deliverable 8 (skeleton).
#
# PURPOSE: 4-layer structural diff between a live plugin tree and the frozen
# snapshot manifest at juntogen/claude/validation/snapshots/plugin-tree.snapshot.yaml.
# This is the SKELETON — full integration into the generate pipeline lands in
# BL-025-m.3. m.1 ships the harness with self-test + negative-control coverage.
#
# LAYERS:
#   1. file-set                — every committed path in oj-claude/ matches
#                                the snapshot's `files:` list. Detects added
#                                or removed files (regen drift).
#   2. manifest-keys           — plugin.json top-level keys match the
#                                snapshot's `plugin_json_keys`. hooks.json
#                                shape (matcher count, handler count,
#                                command paths) matches the snapshot's
#                                `hooks_json_shape`.
#   3. frontmatter-schema      — every skills/*/SKILL.md has the required
#                                frontmatter keys (currently just
#                                `description:` per QE F9).
#   4. referential-integrity   — (new in m.1, SA F1) every hook command
#                                path resolves to an existing executable;
#                                every backtick-delimited path reference in
#                                CONDUCTOR.md — either `@<subdir>/...md` or
#                                `${CLAUDE_PLUGIN_ROOT}/<subdir>/...md` —
#                                resolves to a file under the plugin tree.
#                                SCOPED to path-resolution, NOT identifier
#                                checks (Tier A's job).
#   5. byte-diff-data          — (new in m.3) every DATA-class artifact
#                                listed in byte-diff-baseline.yaml matches
#                                the recorded sha256. Locks the byte-
#                                determinism invariant for output-class
#                                `data` files (plugin.json, hooks.json,
#                                contracts.sh, platform-defaults.yaml). PROSE
#                                files are intentionally NOT byte-diffed
#                                (LLM paraphrase drift is admissible).
#
# OUTPUT FORMAT (BL-025-g/h structured-stderr pattern):
#   FAIL line on stderr:
#     CATEGORY: <kind> | FILE: <path> | LINE: <N> | DETAIL: <text>
#   PASS line on stdout:
#     PASS L<n>: <description>
#
# EXIT CODES:
#   0 - all four layers clean
#   1 - one or more layers detected drift
#   2 - driver error (snapshot missing, plugin tree missing, etc.)
#
# USAGE:
#   ./structural-diff.sh [PLUGIN_ROOT]
#   PLUGIN_ROOT defaults to OJ_OUTPUT_DIR or the canonical hand-cut baseline.
#
# DESIGN NOTES:
#   - Snapshot is YAML; we parse via python3+yaml. If python3+yaml missing,
#     fall back to grep-based extraction with a clearly-worded WARN.
#   - File-set check uses `git ls-files` for the live tree (matches snapshot
#     generation: git ls-files | sort) so transient untracked files don't
#     trip the gate.
#   - Layer 4 is intentionally lightweight: hook-path resolution check
#     plus CONDUCTOR.md path-reference resolution (covering both legacy
#     `@<subdir>/...` and generated `${CLAUDE_PLUGIN_ROOT}/<subdir>/...`
#     shapes). Tier A's §11/§12 already catch identifier-level drift;
#     this is the path-level complement.

set -euo pipefail

# ────────────────────────────────────────────────────────────────────
# Argument parsing + plugin-tree root resolution
# ────────────────────────────────────────────────────────────────────
PLUGIN_ROOT="${1:-${OJ_OUTPUT_DIR:-/Users/brenton/workspace/github.com/openjunto/oj-claude}}"

if [[ ! -d "${PLUGIN_ROOT}" ]]; then
    echo "ERROR: structural-diff: PLUGIN_ROOT not a directory: ${PLUGIN_ROOT}" >&2
    exit 2
fi
PLUGIN_ROOT="$(cd "${PLUGIN_ROOT}" && pwd)"

# ────────────────────────────────────────────────────────────────────
# Snapshot file resolution
# ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAPSHOT_FILE="${OJ_SNAPSHOT_FILE:-${SCRIPT_DIR}/../snapshots/plugin-tree.snapshot.yaml}"

if [[ ! -f "${SNAPSHOT_FILE}" ]]; then
    echo "ERROR: structural-diff: snapshot not found: ${SNAPSHOT_FILE}" >&2
    exit 2
fi

# ────────────────────────────────────────────────────────────────────
# Color setup
# ────────────────────────────────────────────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
    # $1 = layer id (e.g., "L1"), $2 = description
    echo "${GREEN}PASS${NC} $1: $2"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    # $1 = CATEGORY, $2 = FILE, $3 = LINE (0 if N/A), $4 = DETAIL
    echo "${RED}FAIL${NC} CATEGORY: $1 | FILE: $2 | LINE: $3 | DETAIL: $4" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
    echo "${YELLOW}WARN${NC} $1: $2"
    WARN_COUNT=$((WARN_COUNT + 1))
}

# ────────────────────────────────────────────────────────────────────
# Snapshot loader — yaml -> bash arrays
# ────────────────────────────────────────────────────────────────────
HAVE_PY_YAML=0
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
    HAVE_PY_YAML=1
fi

# Load a list-valued top-level key from the snapshot into a temp file
# (one entry per line). Returns the tempfile path on stdout.
snapshot_list() {
    local key="$1"
    local out
    out=$(mktemp -t snapshot-list-XXXXXX)
    if [[ "${HAVE_PY_YAML}" -eq 1 ]]; then
        python3 - "${SNAPSHOT_FILE}" "${key}" <<'PYEOF' > "${out}"
import sys, yaml
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = yaml.safe_load(f)
key = sys.argv[2]
val = data.get(key, [])
if isinstance(val, list):
    for v in val:
        print(v)
PYEOF
    else
        # Fallback: grep-based extraction. Format-fragile but unblocks the
        # skeleton when python3+yaml are unavailable in a hostile environment.
        awk -v key="${key}:" '
            $0 == key { in_block=1; next }
            in_block && /^[a-z_]+:/ { in_block=0 }
            in_block && /^  - / { sub(/^  - /, ""); gsub(/^"|"$/, ""); print }
        ' "${SNAPSHOT_FILE}" > "${out}"
        warn "fallback-loader" "python3+yaml unavailable; using awk fallback for ${key} (format-fragile)"
    fi
    echo "${out}"
}

# Load a scalar-valued nested key. Pass dotted path (e.g., hooks_json_shape.session_start_handler_count).
snapshot_scalar() {
    local key_path="$1"
    if [[ "${HAVE_PY_YAML}" -eq 1 ]]; then
        python3 - "${SNAPSHOT_FILE}" "${key_path}" <<'PYEOF'
import sys, yaml
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = yaml.safe_load(f)
keys = sys.argv[2].split(".")
val = data
for k in keys:
    if val is None: break
    if isinstance(val, dict):
        val = val.get(k)
    else:
        val = None
        break
if val is None:
    print("")
else:
    print(val)
PYEOF
    else
        # Fallback: best-effort grep, single-level only.
        # This is intentionally minimal — caller WARNs.
        local leaf
        leaf="${key_path##*.}"
        awk -v key="  ${leaf}:" '
            $0 ~ "^"key { sub(/^  [a-z_]+:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit }
        ' "${SNAPSHOT_FILE}"
    fi
}

echo "${YELLOW}INFO${NC} structural-diff: plugin tree = ${PLUGIN_ROOT}"
echo "${YELLOW}INFO${NC} structural-diff: snapshot    = ${SNAPSHOT_FILE}"
echo ""

# ────────────────────────────────────────────────────────────────────
# Layer 1 — file-set
# ────────────────────────────────────────────────────────────────────
check_layer_1_file_set() {
    local expected
    expected=$(snapshot_list "files")

    # Live tree must (a) contain every snapshot path as an actual file on
    # disk, and (b) not introduce any new tracked paths. We use git ls-files
    # for the "set of tracked paths" view; a separate on-disk check catches
    # files that are tracked but missing from the working tree.
    local live_tracked
    live_tracked=$(mktemp -t snapshot-live-tracked-XXXXXX)
    (cd "${PLUGIN_ROOT}" && git ls-files | sort) > "${live_tracked}"

    local rc=0

    # (1) Every snapshot path MUST exist on disk in the live tree.
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if [[ ! -e "${PLUGIN_ROOT}/${f}" ]]; then
            fail "structural-drift-missing-file" "${f}" 0 "file in snapshot but missing from live tree (on disk)"
            rc=1
        fi
    done < "${expected}"

    # (2) No new tracked paths beyond the snapshot set.
    local added
    added=$(comm -23 "${live_tracked}" "${expected}" 2>/dev/null || true)
    if [[ -n "${added}" ]]; then
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            fail "structural-drift-added-file" "${f}" 0 "tracked path present in live tree but not in snapshot"
            rc=1
        done <<< "${added}"
    fi

    # (3) No tracked snapshot paths missing from the tracked set (catches
    # a `git rm` against a snapshotted file).
    local removed
    removed=$(comm -13 "${live_tracked}" "${expected}" 2>/dev/null || true)
    if [[ -n "${removed}" ]]; then
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            fail "structural-drift-untracked-file" "${f}" 0 "snapshot path no longer tracked by git in live tree"
            rc=1
        done <<< "${removed}"
    fi

    rm -f "${expected}" "${live_tracked}"
    if [[ "${rc}" -eq 0 ]]; then
        local file_count
        file_count=$(git -C "${PLUGIN_ROOT}" ls-files | wc -l | tr -d ' ')
        pass "L1" "file-set matches snapshot (${file_count} tracked paths, all present on disk)"
    fi
    return "${rc}"
}

# ────────────────────────────────────────────────────────────────────
# Layer 2 — manifest-keys
# ────────────────────────────────────────────────────────────────────
check_layer_2_manifest_keys() {
    local rc=0

    # plugin.json: top-level keys must match.
    local plugin_json="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
    if [[ ! -r "${plugin_json}" ]]; then
        fail "manifest-keys-plugin-json-missing" ".claude-plugin/plugin.json" 0 "file missing or unreadable"
        rc=1
    else
        local expected_keys live_keys
        expected_keys=$(snapshot_list "plugin_json_keys")
        live_keys=$(mktemp -t plugin-live-keys-XXXXXX)
        jq -r 'keys[]' "${plugin_json}" | sort > "${live_keys}"
        if ! diff -q "${expected_keys}" "${live_keys}" >/dev/null 2>&1; then
            fail "manifest-keys-plugin-json-drift" ".claude-plugin/plugin.json" 0 \
                "plugin.json keys differ from snapshot (diff: $(diff "${expected_keys}" "${live_keys}" 2>/dev/null | head -5 | tr '\n' ' '))"
            rc=1
        fi
        rm -f "${expected_keys}" "${live_keys}"
    fi

    # hooks.json: matcher count + handler count + SubagentStart matcher + command paths.
    local hooks_json="${PLUGIN_ROOT}/hooks/hooks.json"
    if [[ ! -r "${hooks_json}" ]]; then
        fail "manifest-keys-hooks-json-missing" "hooks/hooks.json" 0 "file missing or unreadable"
        rc=1
    else
        local expected_ss_matchers expected_handlers
        expected_ss_matchers=$(snapshot_scalar "hooks_json_shape.session_start_matchers")
        expected_handlers=$(snapshot_scalar "hooks_json_shape.session_start_handler_count")
        local live_ss_matchers live_handlers
        live_ss_matchers=$(jq '[.hooks.SessionStart[].matcher] | length' "${hooks_json}")
        live_handlers=$(jq '[.hooks.SessionStart[].hooks[]] | length' "${hooks_json}")
        if [[ "${expected_ss_matchers}" != "${live_ss_matchers}" ]]; then
            fail "manifest-keys-hooks-json-drift" "hooks/hooks.json" 0 \
                "SessionStart matcher count drift: expected=${expected_ss_matchers}, live=${live_ss_matchers}"
            rc=1
        fi
        if [[ "${expected_handlers}" != "${live_handlers}" ]]; then
            fail "manifest-keys-hooks-json-drift" "hooks/hooks.json" 0 \
                "SessionStart handler count drift: expected=${expected_handlers}, live=${live_handlers}"
            rc=1
        fi
    fi

    if [[ "${rc}" -eq 0 ]]; then
        pass "L2" "manifest-keys: plugin.json keys + hooks.json shape match snapshot"
    fi
    return "${rc}"
}

# ────────────────────────────────────────────────────────────────────
# Layer 3 — frontmatter-schema
# ────────────────────────────────────────────────────────────────────
check_layer_3_frontmatter_schema() {
    local skills_dir="${PLUGIN_ROOT}/skills"
    if [[ ! -d "${skills_dir}" ]]; then
        # Plugin without skills is legal — no skills, nothing to validate.
        pass "L3" "no skills/ directory (skipping frontmatter check)"
        return 0
    fi

    local required_keys
    required_keys=$(snapshot_list "skill_frontmatter_required")

    local rc=0 found=0
    for skill_md in "${skills_dir}"/*/SKILL.md; do
        [[ -r "${skill_md}" ]] || continue
        found=$((found + 1))
        if [[ "${HAVE_PY_YAML}" -eq 1 ]]; then
            local parse_out
            parse_out=$(python3 - "${skill_md}" "${required_keys}" <<'PYEOF'
import sys, yaml
p, rk_file = sys.argv[1], sys.argv[2]
with open(p, "r", encoding="utf-8") as f:
    text = f.read()
if not text.startswith("---"):
    print("no leading --- delimiter")
    sys.exit(1)
parts = text.split("---", 2)
if len(parts) < 3:
    print("missing closing --- delimiter")
    sys.exit(1)
try:
    data = yaml.safe_load(parts[1])
except yaml.YAMLError as e:
    print(f"yaml parse error: {e}")
    sys.exit(1)
if not isinstance(data, dict):
    print("frontmatter is not a YAML mapping")
    sys.exit(1)
required = [line.strip() for line in open(rk_file).read().splitlines() if line.strip()]
missing = [k for k in required if k not in data]
if missing:
    print(f"missing required keys: {','.join(missing)}")
    sys.exit(1)
PYEOF
) || {
                local skill_rel="${skill_md#${PLUGIN_ROOT}/}"
                fail "frontmatter-schema-drift" "${skill_rel}" 0 "${parse_out}"
                rc=1
                continue
            }
        else
            # Fallback: header match only.
            if ! head -1 "${skill_md}" | grep -qE '^---[[:space:]]*$'; then
                local skill_rel="${skill_md#${PLUGIN_ROOT}/}"
                warn "L3" "${skill_rel}: no leading --- delimiter (python3+yaml unavailable, skipped key check)"
            fi
        fi
    done

    rm -f "${required_keys}"
    if [[ "${rc}" -eq 0 && "${found}" -gt 0 ]]; then
        pass "L3" "frontmatter-schema: ${found} SKILL.md files have required keys"
    elif [[ "${found}" -eq 0 ]]; then
        pass "L3" "skills/ present but contains no SKILL.md files"
    fi
    return "${rc}"
}

# ────────────────────────────────────────────────────────────────────
# Layer 4 — referential-integrity (new in m.1, SA F1)
# ────────────────────────────────────────────────────────────────────
check_layer_4_referential_integrity() {
    local rc=0
    local hooks_json="${PLUGIN_ROOT}/hooks/hooks.json"

    if [[ ! -r "${hooks_json}" ]]; then
        fail "referential-integrity-hooks-json-missing" "hooks/hooks.json" 0 "file missing or unreadable"
        return 1
    fi

    # Every hook command path resolves to an existing executable under bin/.
    local cmd binary_path binary_rel
    while IFS= read -r cmd; do
        [[ -z "${cmd}" ]] && continue
        local expanded="${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/${PLUGIN_ROOT}}"
        binary_path="${expanded%% *}"
        if [[ ! -e "${binary_path}" ]]; then
            binary_rel="${binary_path#${PLUGIN_ROOT}/}"
            fail "referential-integrity-hook-path-unresolved" "hooks/hooks.json" 0 \
                "hook command path does not resolve: ${binary_rel} (full: ${cmd})"
            rc=1
        elif [[ ! -x "${binary_path}" ]]; then
            binary_rel="${binary_path#${PLUGIN_ROOT}/}"
            fail "referential-integrity-hook-path-not-executable" "${binary_rel}" 0 \
                "hook command target exists but is not executable: ${cmd}"
            rc=1
        fi
    done < <(jq -r '
        [.hooks // {} | to_entries[] | .value[]?.hooks[]?.command // empty] | .[]
    ' "${hooks_json}")

    # CONDUCTOR.md path references: lightweight check. Greps for two reference
    # shapes inside backtick code-spans and verifies each resolves to a file
    # under the plugin tree:
    #   1. `@<subdir>/foo.md`                    — legacy/installed shape
    #   2. `${CLAUDE_PLUGIN_ROOT}/<subdir>/foo.md` — generated/plugin shape
    # (Tier A handles deeper content-vs-identifier consistency; this layer is
    # path-level only.)
    # Backtick anchoring prevents prose-mention false-positives.
    # Documentation-form skips (NOT literal paths to resolve):
    #   - Glob patterns (containing `*`)               e.g. `*-compact.md`
    #   - Meta-placeholders (containing `[`)           e.g. `[profile-filename]`
    #   - Lines describing conditional/optional refs   e.g. `If <path> exists …`
    local conductor="${PLUGIN_ROOT}/CONDUCTOR.md"
    if [[ -r "${conductor}" ]]; then
        local ref ref_path line_no line_text
        # Extract backtick-delimited path tokens of either shape. Awk emits
        # `<line_no>\t<line_text>\t<ref>` per match so we can both surface
        # line numbers in FAILs and inspect surrounding prose for conditional
        # qualifiers. Tab-delimited so paths containing `:` survive intact.
        while IFS=$'\t' read -r line_no line_text ref; do
            [[ -z "${ref}" ]] && continue
            # Skip glob patterns (documentation, not literal path).
            [[ "${ref}" == *'*'* ]] && continue
            # Skip meta-placeholders like `[profile-filename]`.
            [[ "${ref}" == *'['* ]] && continue
            # Skip refs flagged as conditional by prose convention. Matches
            # the documented "If `<path>` exists …" pattern (enterprise-overlay
            # opt-in content).
            if [[ "${line_text}" =~ ^[[:space:]]*If[[:space:]]+\`.*\`[[:space:]]+exists ]]; then
                continue
            fi
            # Resolve to a filesystem path under PLUGIN_ROOT.
            if [[ "${ref}" == '@'* ]]; then
                ref_path="${PLUGIN_ROOT}/${ref#@}"
            elif [[ "${ref}" == '${CLAUDE_PLUGIN_ROOT}/'* ]]; then
                ref_path="${PLUGIN_ROOT}/${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}"
            else
                # Defensive: pattern shouldn't admit other shapes.
                continue
            fi
            if [[ ! -f "${ref_path}" ]]; then
                fail "referential-integrity-conductor-ref-unresolved" "CONDUCTOR.md" "${line_no}" \
                    "${ref}"
                rc=1
            fi
        done < <(awk '
            {
                line = $0
                full = $0
                while (match(line, /`(@|\$\{CLAUDE_PLUGIN_ROOT\}\/)(agents|reference|skills|templates|hooks|bin|docs)\/[A-Za-z0-9._\/\*\[\]-]+\.md`/)) {
                    tok = substr(line, RSTART + 1, RLENGTH - 2)
                    print NR "\t" full "\t" tok
                    line = substr(line, RSTART + RLENGTH)
                }
            }
        ' "${conductor}")
    fi

    if [[ "${rc}" -eq 0 ]]; then
        pass "L4" "referential-integrity: hook paths + CONDUCTOR.md @-refs all resolve"
    fi
    return "${rc}"
}

# ────────────────────────────────────────────────────────────────────
# Layer 5 — byte-diff-data (new in m.3)
# ────────────────────────────────────────────────────────────────────
# Reads byte-diff-baseline.yaml (entries[].path + entries[].sha256 +
# entries[].provenance) and asserts that every recorded path in the
# plugin tree hashes to the recorded sha256. Surfaces a structured-stderr
# FAIL line with category `byte-diff-data-drift` on mismatch.
#
# Scope: DATA-class only. PROSE files (*.md, bin/oj-helper) are NEVER
# enumerated in the baseline — temperature drift makes byte-equality
# wrong for them. The baseline file is the single source of truth for
# what IS byte-diffed.
#
# Failure modes covered:
#   - sha256 mismatch (mutation, edit, helper regression)
#   - missing file (data file absent from the regen tree)
BYTE_DIFF_BASELINE="${OJ_BYTE_DIFF_BASELINE:-${SCRIPT_DIR}/../snapshots/byte-diff-baseline.yaml}"

check_layer_5_byte_diff_data() {
    local rc=0

    if [[ ! -f "${BYTE_DIFF_BASELINE}" ]]; then
        fail "byte-diff-baseline-missing" "${BYTE_DIFF_BASELINE}" 0 \
            "byte-diff baseline yaml not found; L5 cannot run"
        return 1
    fi

    if [[ "${HAVE_PY_YAML}" -ne 1 ]]; then
        warn "L5" "python3+yaml unavailable; skipping byte-diff-data check (fallback parser would misread the baseline)"
        return 0
    fi

    # Read entries as path|sha256|provenance lines via python3.
    local entries_tsv
    entries_tsv=$(mktemp -t baseline-entries-XXXXXX)
    python3 - "${BYTE_DIFF_BASELINE}" <<'PYEOF' > "${entries_tsv}"
import sys, yaml
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = yaml.safe_load(f)
entries = (data or {}).get("entries") or []
for e in entries:
    p = e.get("path", "")
    s = e.get("sha256", "")
    pv = e.get("provenance", "")
    if not p or not s:
        continue
    print(f"{p}\t{s}\t{pv}")
PYEOF

    local path expected provenance actual full_path
    while IFS=$'\t' read -r path expected provenance; do
        [[ -z "${path}" ]] && continue
        full_path="${PLUGIN_ROOT}/${path}"
        if [[ ! -f "${full_path}" ]]; then
            fail "byte-diff-data-drift" "${path}" 0 \
                "DATA-class file missing from plugin tree (provenance=${provenance})"
            rc=1
            continue
        fi
        actual=$(shasum -a 256 "${full_path}" | awk '{print $1}')
        if [[ "${actual}" != "${expected}" ]]; then
            fail "byte-diff-data-drift" "${path}" 0 \
                "sha256 mismatch (expected=${expected}, actual=${actual}, provenance=${provenance})"
            rc=1
        fi
    done < "${entries_tsv}"

    rm -f "${entries_tsv}"

    if [[ "${rc}" -eq 0 ]]; then
        local count
        count=$(python3 -c '
import sys, yaml
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = yaml.safe_load(f)
print(len((data or {}).get("entries") or []))
' "${BYTE_DIFF_BASELINE}")
        pass "L5" "byte-diff-data: ${count} DATA-class artifact(s) match baseline sha256"
    fi
    return "${rc}"
}

# ────────────────────────────────────────────────────────────────────
# Orchestrate
# ────────────────────────────────────────────────────────────────────
check_layer_1_file_set              || true
check_layer_2_manifest_keys         || true
check_layer_3_frontmatter_schema    || true
check_layer_4_referential_integrity || true
check_layer_5_byte_diff_data        || true

echo
echo "================================"
if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo "${GREEN}PASS${NC} structural-diff: ${PASS_COUNT} layer(s) passed, ${WARN_COUNT} warning(s)"
    echo "================================"
    exit 0
fi
echo "${RED}FAIL${NC} structural-diff: ${FAIL_COUNT} layer(s) failed (${PASS_COUNT} passed, ${WARN_COUNT} warning(s))"
echo "================================"
exit 1
