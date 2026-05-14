#!/usr/bin/env bash
#
# validate-no-claude-home-leak.sh — standalone leak-hygiene validator for
# OpenJunto plugin output trees.
#
# PURPOSE: Assert that no literal `~/.claude/` path references appear in
# the adopter-visible plugin tree. Such references point at the original
# manager-side `~/.claude/` install (where the spec source lives), NOT
# at the plugin-installed tree. The portable form is
# `${CLAUDE_PLUGIN_ROOT}/...` for plugin-internal files and
# `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/dev}/...` for the dev-feedback path.
# A `~/.claude/` literal in adopter-installed output means a plugin user
# would be redirected away from the plugin tree into their own HOME.
#
# SCOPE (positive-glob, fail-closed, NO keep-list):
#   - CONDUCTOR.md                    (manager protocol file)
#   - agents/*.md                     (one level, includes index.md, _preamble.md,
#                                      and all 16 full + 16 compact profiles)
#   - reference/*.md                  (one level)
#   - docs/**/*.md                    (recursive; today only docs/onboarding.md)
#   - skills/*/*.md                   (one skill subdir level; covers SKILL.md
#                                      and any companion files such as
#                                      REFERENCE.md or sub-prompts)
#
# OUT OF SCOPE (excluded by positive-glob construction):
#   - bin/                            (BL-023 intentional documentation comments)
#   - README.md, WHY.md               (adopter-facing migration prose, may
#                                      reference original `~/.claude/` install
#                                      for migration context)
#   - .claude/CLAUDE.md               (project-local, not plugin-internal)
#   - org-scaffold/                   (step-11 educational refs)
#   - tests/, scripts/, hooks/, bin/  (out of adopter prose path)
#
# REGEX: literal `~/\.claude/` (with mandatory trailing slash).
#   - Does NOT extend to `$HOME/.claude/` because that form is legitimate
#     inside the `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/dev}` fallback used
#     by the dev-mode feedback path.
#   - Does NOT extend to bare `~/.claude` (no slash) because none of the
#     current 22 hits use the bare form. Widening is a documented
#     follow-up risk if a future paraphrase uses the bare form.
#
# USAGE:
#   validate-no-claude-home-leak.sh <OUTPUT_DIR>
#
# EXIT CODES:
#   0 — no `~/.claude/` literals found in scoped files (clean)
#   1 — at least one leak found; offending FILE:LINE:TEXT printed to stdout
#   2 — driver error (OUTPUT_DIR missing / not a directory / not supplied)
#
# SOURCING:
#   When sourced as a library, no top-level code runs (guarded by
#   ${BASH_SOURCE[0]} == ${0}). Callers invoke check_no_claude_home_leak
#   directly and read the function's exit code + captured output. Mirrors
#   the validate-no-step-sentinel.sh contract used by Tier A Assertion 18.

set -euo pipefail

# ---------------------------------------------------------------------------
# Library function — sourced by tier-a-assertions.sh.
#
# check_no_claude_home_leak <output_dir>
#
# Returns:
#   0 — clean (no leaks)
#   1 — leaks found (FILE:LINE:TEXT printed to stdout, one per line)
#   2 — output_dir missing / not a directory (message to stderr)
#
# Stdout contract on FAIL (exit 1):
#   Each offending line printed as `FILE:LINE:TEXT` (grep -n style with
#   relative path from output_dir). The caller is responsible for
#   formatting (e.g. Tier A adds "  " indent).
# ---------------------------------------------------------------------------
check_no_claude_home_leak() {
    local output_dir="${1:-}"

    if [[ -z "${output_dir}" ]]; then
        echo "ERROR: check_no_claude_home_leak requires <output_dir> argument" >&2
        return 2
    fi

    if [[ ! -d "${output_dir}" ]]; then
        echo "ERROR: OUTPUT_DIR is not a directory: ${output_dir}" >&2
        return 2
    fi

    # Collect scoped files into an array. We list each glob separately
    # and silently skip missing paths so a partial tree (e.g. --spike NN
    # output before CONDUCTOR.md is emitted) doesn't trigger a driver
    # error. Use bash globbing with nullglob so unmatched globs expand
    # to empty rather than the literal pattern.
    local files=()
    local f
    local prev_nullglob
    prev_nullglob=$(shopt -p nullglob || true)
    shopt -s nullglob
    # 1. CONDUCTOR.md at root
    if [[ -f "${output_dir}/CONDUCTOR.md" ]]; then
        files+=("${output_dir}/CONDUCTOR.md")
    fi
    # 2. agents/*.md (one level)
    for f in "${output_dir}"/agents/*.md; do
        [[ -f "${f}" ]] && files+=("${f}")
    done
    # 3. reference/*.md (one level)
    for f in "${output_dir}"/reference/*.md; do
        [[ -f "${f}" ]] && files+=("${f}")
    done
    # 4. docs/**/*.md (recursive)
    if [[ -d "${output_dir}/docs" ]]; then
        # Use find for recursive walk; -print0 + read is overkill since
        # markdown paths don't contain newlines in this project.
        while IFS= read -r f; do
            [[ -f "${f}" ]] && files+=("${f}")
        done < <(find "${output_dir}/docs" -type f -name '*.md' 2>/dev/null | LC_ALL=C sort)
    fi
    # 5. skills/*/*.md (one skill subdir level)
    #    Widened from skills/*/SKILL.md (BL-025-m.6 carry-forward 8a) to
    #    cover future companion files (REFERENCE.md, sub-prompts, etc.).
    #    Live tree today has zero such companion files — defense-in-depth.
    #    The N6 fixture in validate-no-claude-home-leak-test.sh pins the
    #    regression guard.
    for f in "${output_dir}"/skills/*/*.md; do
        [[ -f "${f}" ]] && files+=("${f}")
    done
    # Restore prior nullglob state.
    eval "${prev_nullglob}"

    if [[ "${#files[@]}" -eq 0 ]]; then
        # No scoped files exist (e.g. empty OUTPUT_DIR). Vacuously clean.
        return 0
    fi

    # Run grep -nF for fixed-string `~/.claude/` per-file. -H always
    # prints the filename. -n prints the line number. -F treats the
    # pattern as a literal string (no regex escape headaches across
    # GNU/BSD grep). 2>/dev/null suppresses "no such file" if a glob
    # raced. Capture all hits; sort for stable output.
    #
    # grep returns 0 on match, 1 on no-match, 2 on error. We treat
    # 0+1 as expected and only surface a >1 as a driver error.
    local hits
    set +e
    hits=$(grep -nHF '~/.claude/' "${files[@]}" 2>/dev/null)
    local grep_rc=$?
    set -e

    if [[ "${grep_rc}" -gt 1 ]]; then
        echo "ERROR: grep failed with exit ${grep_rc} while scanning scoped files" >&2
        return 2
    fi

    if [[ -z "${hits}" ]]; then
        return 0
    fi

    # Normalize paths relative to OUTPUT_DIR for readability. grep -H
    # prints absolute paths because we passed absolute paths. Strip the
    # output_dir prefix + trailing slash for compact FILE:LINE:TEXT.
    local prefix="${output_dir}/"
    echo "${hits}" | LC_ALL=C sort | sed "s|^${prefix}||"
    return 1
}

# ---------------------------------------------------------------------------
# Standalone CLI entry-point. Skipped when sourced.
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "ERROR: OUTPUT_DIR is required" >&2
        echo "Usage: $0 <OUTPUT_DIR>" >&2
        exit 2
    fi

    OUTPUT_DIR="$1"

    if [[ ! -d "${OUTPUT_DIR}" ]]; then
        echo "ERROR: OUTPUT_DIR is not a directory: ${OUTPUT_DIR}" >&2
        echo "Usage: $0 <OUTPUT_DIR>" >&2
        exit 2
    fi

    # Normalize rc=2 for unreadable OUTPUT_DIR (BL-025-m.6 carry-forward 8b).
    # Without this precheck, an unreadable dir would yield rc=1 from the
    # downstream grep (empty file list → no hits → "clean"), or surface as
    # a confusing partial result. CI consumers using rc-only parsing would
    # misinterpret that as "no leaks". Mirror the missing-dir branch above.
    if [[ ! -r "${OUTPUT_DIR}" ]]; then
        echo "ERROR: OUTPUT_DIR not readable: ${OUTPUT_DIR}" >&2
        echo "Usage: $0 <OUTPUT_DIR>" >&2
        exit 2
    fi

    # Resolve to absolute path for clearer diagnostics.
    OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

    set +e
    HITS=$(check_no_claude_home_leak "${OUTPUT_DIR}")
    rc=$?
    set -e

    case "${rc}" in
        0)
            echo "PASS: 0 ~/.claude/ literals found in scoped plugin tree under ${OUTPUT_DIR}"
            exit 0
            ;;
        1)
            COUNT=$(echo "${HITS}" | wc -l | tr -d ' ')
            echo "FAIL: ${COUNT} ~/.claude/ leak(s) found in scoped plugin tree under ${OUTPUT_DIR}:"
            echo "${HITS}" | sed 's/^/  /'
            exit 1
            ;;
        *)
            # Driver error already printed to stderr by check_no_claude_home_leak.
            exit 2
            ;;
    esac
fi
