#!/usr/bin/env bash
#
# validate-no-step-sentinel.sh — standalone sentinel-hygiene validator for
# OpenJunto plugin output trees.
#
# PURPOSE: Assert that no run-tracking sentinel files (`.step-NN.done`,
# matched by glob `.step-*.done`) appear anywhere under OUTPUT_DIR. These
# sentinels are part of the per-run pipeline cache (default
# ~/.cache/juntogen/run-<UTC>/) and MUST NEVER leak into the
# adopter-visible plugin tree — a leak means the regen pipeline pollutes
# the installed plugin with internal pipeline metadata.
#
# SCOPE: This is the single source of truth for the sentinel-leak check.
# Tier A `tier-a-assertions.sh` sources this helper and wraps
# `check_no_step_sentinel` with its own pass/fail counters so the
# 18/0 baseline stays stable. The standalone entry-point below allows the
# check to run on partial generation outputs (e.g. `--spike NN` runs that
# stop before CONDUCTOR.md is emitted) where Tier A's CONDUCTOR.md
# pre-flight would otherwise short-circuit.
#
# DEPTH: unbounded (BL-025-m.2 reviewer P4 H1 — a -maxdepth 2 cap silently
# passed leaks at depth ≥ 3, e.g. skills/consult/foo/.step-04.done). The
# plugin tree is small (sub-second walk) so a full scan is cheap and the
# contract is sharper: sentinels never legitimately appear anywhere under
# OUTPUT_DIR.
#
# USAGE:
#   validate-no-step-sentinel.sh <OUTPUT_DIR>
#
# EXIT CODES:
#   0 — no `.step-*.done` files found under OUTPUT_DIR (clean)
#   1 — at least one sentinel found; offending paths printed to stdout
#   2 — driver error (OUTPUT_DIR missing / not a directory / not supplied)
#
# SOURCING:
#   When sourced as a library, no top-level code runs (guarded by
#   ${BASH_SOURCE[0]} == ${0}). Callers invoke check_no_step_sentinel
#   directly and read the function's exit code + captured output.

set -euo pipefail

# ---------------------------------------------------------------------------
# Library function — sourced by tier-a-assertions.sh.
#
# check_no_step_sentinel <output_dir>
#
# Returns:
#   0 — clean (no sentinels)
#   1 — sentinels found (paths printed to stdout, one per line)
#   2 — output_dir missing / not a directory (message to stderr)
#
# Stdout contract on FAIL (exit 1):
#   Each offending sentinel path printed on its own line, no prefix.
#   The caller is responsible for formatting (e.g. Tier A adds "  " indent).
# ---------------------------------------------------------------------------
check_no_step_sentinel() {
    local output_dir="${1:-}"

    if [[ -z "${output_dir}" ]]; then
        echo "ERROR: check_no_step_sentinel requires <output_dir> argument" >&2
        return 2
    fi

    if [[ ! -d "${output_dir}" ]]; then
        echo "ERROR: OUTPUT_DIR is not a directory: ${output_dir}" >&2
        return 2
    fi

    # Full-tree walk (unbounded depth). The plugin tree is small;
    # sub-second walk. find prints nothing when no matches exist.
    local hits
    hits=$(find "${output_dir}" -name '.step-*.done' 2>/dev/null || true)

    if [[ -z "${hits}" ]]; then
        return 0
    fi

    # Print each path on its own line, sorted for stable output.
    echo "${hits}" | LC_ALL=C sort
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

    # Resolve to absolute path for clearer diagnostics.
    OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"

    set +e
    HITS=$(check_no_step_sentinel "${OUTPUT_DIR}")
    rc=$?
    set -e

    case "${rc}" in
        0)
            echo "PASS: 0 .step-*.done sentinels found under ${OUTPUT_DIR}"
            exit 0
            ;;
        1)
            COUNT=$(echo "${HITS}" | wc -l | tr -d ' ')
            echo "FAIL: ${COUNT} .step-*.done sentinel(s) found under ${OUTPUT_DIR}:"
            echo "${HITS}" | sed 's/^/  /'
            exit 1
            ;;
        *)
            # Driver error already printed to stderr by check_no_step_sentinel.
            exit 2
            ;;
    esac
fi
