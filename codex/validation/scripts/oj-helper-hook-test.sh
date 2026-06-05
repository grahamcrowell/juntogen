#!/usr/bin/env bash
#
# oj-helper-hook-test.sh — runtime hook-contract test for the generated oj-codex oj-helper.
# Codex sibling of oj-claude/scripts/tests/oj-helper-hook-test.sh, scoped to the Codex
# subcommands. Exercises the real script with mock Codex hook conditions on a per-scenario
# isolated tempdir (rebinds PLUGIN_ROOT). No codex binary required.
#
# Scenarios:
#   S1 conductor-inject present     -> valid JSON, additionalContext == CONDUCTOR.md, banner on stderr, exit 0
#   S2 conductor-inject missing     -> OJ_STDERR_CONDUCTOR_MISSING + empty additionalContext + exit 0
#   S3 conductor-inject empty file  -> empty additionalContext, NO missing-advisory, exit 0
#   S4 inject-profile no marker     -> graceful degrade (exit 0)
#   S5 subagents-check              -> valid JSON {ok,available,reason}, always exit 0 (Axiom 8)
#
# Usage: oj-helper-hook-test.sh [PLUGIN_DIR]
# Exit:  0 all pass | 1 a scenario failed | 2 driver error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${1:-${OJ_CODEX_DIR:-${SCRIPT_DIR}/../../../../oj-codex}}"
[ -d "${PLUGIN_DIR}" ] || { echo "ERROR: plugin dir not found: ${PLUGIN_DIR}" >&2; exit 2; }
PLUGIN_DIR="$(cd "${PLUGIN_DIR}" && pwd)"
OJ_HELPER="${PLUGIN_DIR}/bin/oj-helper"
CONTRACTS="${PLUGIN_DIR}/bin/lib/contracts.sh"
[ -x "${OJ_HELPER}" ] || { echo "ERROR: oj-helper not executable: ${OJ_HELPER}" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }
# shellcheck source=/dev/null
[ -r "${CONTRACTS}" ] && source "${CONTRACTS}" || { echo "ERROR: contracts.sh missing: ${CONTRACTS}" >&2; exit 2; }

if [ -t 1 ]; then RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'; else RED=''; GREEN=''; CYAN=''; NC=''; fi
PASS=0; FAIL=0
chk(){ if [ "$2" = ok ]; then echo "${GREEN}PASS${NC} $1"; PASS=$((PASS+1)); else echo "${RED}FAIL${NC} $1"; [ -n "${3:-}" ] && echo "${CYAN}      $3${NC}"; FAIL=$((FAIL+1)); fi; }

# run oj-helper with an isolated PLUGIN_ROOT; capture stdout/stderr/exit into T.
run() { # $1=T $2=subcmd ...
  local T="$1"; shift; local sub="$1"; shift; local rc=0
  # Copy the helper into the isolated tree so its script-relative CONDUCTOR fallback
  # ($(dirname $0)/../CONDUCTOR.md) also resolves under $T/plugin — otherwise the real
  # oj-codex/CONDUCTOR.md leaks in and breaks the "missing" scenarios.
  mkdir -p "$T/plugin/bin/lib"
  cp "${OJ_HELPER}" "$T/plugin/bin/oj-helper"; chmod +x "$T/plugin/bin/oj-helper"
  cp "${CONTRACTS}" "$T/plugin/bin/lib/contracts.sh"
  HOME="$T/home" PLUGIN_ROOT="$T/plugin" XDG_CONFIG_HOME="$T/xdg" \
    "$T/plugin/bin/oj-helper" "$sub" "$@" >"$T/out" 2>"$T/err" </dev/null || rc=$?
  echo "$rc" >"$T/rc"
}

# S1 — conductor-inject present
s1(){ local T; T=$(mktemp -d); mkdir -p "$T/home" "$T/plugin" "$T/xdg"
  printf '# Conductor\n\nbody here\n' >"$T/plugin/CONDUCTOR.md"; printf '9.9.9\n' >"$T/plugin/VERSION"
  run "$T" conductor-inject
  [ "$(cat "$T/rc")" = 0 ] && chk "S1 conductor-inject present: exit 0" ok || chk "S1 exit 0" fail "rc=$(cat "$T/rc") err=$(cat "$T/err")"
  jq -e '.hookSpecificOutput.hookEventName=="SessionStart"' "$T/out" >/dev/null 2>&1 && chk "S1 hookEventName==SessionStart" ok || chk "S1 hookEventName" fail "out=$(cat "$T/out")"
  [ "$(jq -r '.hookSpecificOutput.additionalContext' "$T/out")" = "$(cat "$T/plugin/CONDUCTOR.md")" ] && chk "S1 additionalContext byte-identical to CONDUCTOR.md" ok || chk "S1 additionalContext" fail
  grep -qF 'active — OpenJunto coordination system' "$T/err" && chk "S1 version banner on stderr" ok || chk "S1 banner" fail "err=$(cat "$T/err")"
  rm -rf "$T"; }

# S2 — conductor-inject missing
s2(){ local T; T=$(mktemp -d); mkdir -p "$T/home" "$T/plugin" "$T/xdg"
  run "$T" conductor-inject
  [ "$(cat "$T/rc")" = 0 ] && chk "S2 missing: exit 0 (graceful)" ok || chk "S2 exit 0" fail "rc=$(cat "$T/rc")"
  grep -qF "${OJ_STDERR_CONDUCTOR_MISSING}" "$T/err" && chk "S2 missing: OJ_STDERR_CONDUCTOR_MISSING on stderr" ok || chk "S2 advisory" fail "err=$(cat "$T/err")"
  jq -e '.hookSpecificOutput.additionalContext==""' "$T/out" >/dev/null 2>&1 && chk "S2 missing: empty additionalContext" ok || chk "S2 empty body" fail "out=$(cat "$T/out")"
  rm -rf "$T"; }

# S3 — conductor-inject empty file (legit disabled state: no missing-advisory)
s3(){ local T; T=$(mktemp -d); mkdir -p "$T/home" "$T/plugin" "$T/xdg"; : >"$T/plugin/CONDUCTOR.md"
  run "$T" conductor-inject
  [ "$(cat "$T/rc")" = 0 ] && chk "S3 empty: exit 0" ok || chk "S3 exit 0" fail
  jq -e '.hookSpecificOutput.additionalContext==""' "$T/out" >/dev/null 2>&1 && chk "S3 empty: additionalContext==\"\"" ok || chk "S3 empty body" fail "out=$(cat "$T/out")"
  ! grep -qF "${OJ_STDERR_CONDUCTOR_MISSING}" "$T/err" && chk "S3 empty: no missing-advisory (disabled state stays silent)" ok || chk "S3 silent" fail "err=$(cat "$T/err")"
  rm -rf "$T"; }

# S4 — inject-profile with no expert marker -> graceful
s4(){ local T; T=$(mktemp -d); mkdir -p "$T/home" "$T/plugin" "$T/xdg"
  run "$T" inject-profile
  [ "$(cat "$T/rc")" = 0 ] && chk "S4 inject-profile no-marker: exit 0 (graceful)" ok || chk "S4 exit 0" fail "rc=$(cat "$T/rc") err=$(cat "$T/err")"
  rm -rf "$T"; }

# S5 — subagents-check: valid JSON, always exit 0
s5(){ local T; T=$(mktemp -d); mkdir -p "$T/home" "$T/plugin" "$T/xdg"
  run "$T" subagents-check
  [ "$(cat "$T/rc")" = 0 ] && chk "S5 subagents-check: exit 0 (Axiom 8 probe never blocks)" ok || chk "S5 exit 0" fail "rc=$(cat "$T/rc")"
  jq -e 'has("ok") and has("available") and has("reason")' "$T/out" >/dev/null 2>&1 && chk "S5 subagents-check: JSON {ok,available,reason}" ok || chk "S5 JSON shape" fail "out=$(cat "$T/out")"
  rm -rf "$T"; }

echo "oj-helper-hook-test → ${OJ_HELPER}"; echo
s1; s2; s3; s4; s5
echo; echo "================================"
TOTAL=$((PASS+FAIL))
[ "${FAIL}" -eq 0 ] && { echo "${GREEN}PASS${NC} oj-helper-hook-test: ${PASS}/${TOTAL}"; exit 0; }
echo "${RED}FAIL${NC} oj-helper-hook-test: ${FAIL}/${TOTAL} failed"; exit 1
