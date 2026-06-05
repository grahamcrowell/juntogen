#!/usr/bin/env bash
#
# validate-plugin.sh — structural validation of the generated oj-codex plugin tree.
# Codex sibling of oj-claude/scripts/validate-plugin.sh.
#
# Usage: validate-plugin.sh [PLUGIN_DIR]
# Exit:  0 all checks pass | 1 one or more fail | 2 plugin-dir error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${1:-${OJ_CODEX_DIR:-${SCRIPT_DIR}/../../../../oj-codex}}"
[ -d "${PLUGIN_DIR}" ] || { echo "ERROR: plugin dir not found: ${PLUGIN_DIR}" >&2; exit 2; }
PLUGIN_DIR="$(cd "${PLUGIN_DIR}" && pwd)"
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }

if [ -t 1 ]; then RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; NC=$'\033[0m'; else RED=''; GREEN=''; NC=''; fi
PASS=0; FAIL=0
ok(){ echo "${GREEN}PASS${NC} $1"; PASS=$((PASS+1)); }
no(){ echo "${RED}FAIL${NC} $1"; [ -n "${2:-}" ] && echo "      $2"; FAIL=$((FAIL+1)); }
have(){ [ -f "${PLUGIN_DIR}/$1" ]; }

# C1 — plugin.json
if have .codex-plugin/plugin.json && jq -e '.name and .version and .description' "${PLUGIN_DIR}/.codex-plugin/plugin.json" >/dev/null 2>&1; then
  ok "C1 .codex-plugin/plugin.json valid + name/version/description"
else no "C1 .codex-plugin/plugin.json valid + required fields"; fi

# C2 — marketplace.json
if have .codex-plugin/marketplace.json && jq -e '.name and .plugins' "${PLUGIN_DIR}/.codex-plugin/marketplace.json" >/dev/null 2>&1; then
  ok "C2 .codex-plugin/marketplace.json valid"
else no "C2 .codex-plugin/marketplace.json valid"; fi

# C3 — hooks.json: valid + SessionStart/SubagentStart + PLUGIN_ROOT oj-helper commands
if have hooks/hooks.json && jq -e '.hooks.SessionStart and .hooks.SubagentStart' "${PLUGIN_DIR}/hooks/hooks.json" >/dev/null 2>&1; then
  cmds=$(jq -r '[.hooks[][]?.hooks[]?.command] | join(" ")' "${PLUGIN_DIR}/hooks/hooks.json")
  if echo "${cmds}" | grep -q '\${PLUGIN_ROOT}/bin/oj-helper conductor-inject' \
     && echo "${cmds}" | grep -q '\${PLUGIN_ROOT}/bin/oj-helper inject-profile'; then
    ok "C3 hooks.json wires conductor-inject (SessionStart) + inject-profile (SubagentStart) via \${PLUGIN_ROOT}"
  else no "C3 hooks.json hook commands" "cmds=${cmds}"; fi
else no "C3 hooks.json valid + SessionStart/SubagentStart"; fi

# C4 — oj-helper executable + bash -n + sources contracts.sh
if have bin/oj-helper && [ -x "${PLUGIN_DIR}/bin/oj-helper" ] && bash -n "${PLUGIN_DIR}/bin/oj-helper" 2>/dev/null; then
  if grep -q 'lib/contracts.sh' "${PLUGIN_DIR}/bin/oj-helper"; then
    ok "C4 bin/oj-helper executable + bash -n clean + sources contracts.sh"
  else no "C4 bin/oj-helper sources contracts.sh"; fi
else no "C4 bin/oj-helper executable + bash -n"; fi

# C5 — 16 native agent defs with required keys + valid enums
MODELS_RE='^(gpt-5\.4-mini|gpt-5\.3-codex|gpt-5\.5)$'
EFFORT_RE='^(minimal|low|medium|high|xhigh)$'
defs=$(find "${PLUGIN_DIR}/.codex/agents" -maxdepth 1 -name '*.toml' -type f 2>/dev/null | sort)
ndef=$(echo "${defs}" | grep -c . || true)
bad=0
while IFS= read -r t; do [ -z "$t" ] && continue
  m=$(sed -n 's/^model *= *"\(.*\)"/\1/p' "$t" | head -1)
  e=$(sed -n 's/^model_reasoning_effort *= *"\(.*\)"/\1/p' "$t" | head -1)
  grep -q '^name = ' "$t" && grep -q '^description = ' "$t" && grep -q '^developer_instructions = ' "$t" || { no "C5 ${t##*/} missing required key"; bad=1; continue; }
  echo "$m" | grep -qE "${MODELS_RE}" || { no "C5 ${t##*/} bad model: ${m}"; bad=1; }
  echo "$e" | grep -qE "${EFFORT_RE}" || { no "C5 ${t##*/} bad effort: ${e}"; bad=1; }
done <<< "${defs}"
if [ "${ndef}" -ge 16 ] && [ "${bad}" -eq 0 ]; then ok "C5 ${ndef} native agent defs: required keys + valid model/effort enums"; else [ "${ndef}" -ge 16 ] || no "C5 expected >=16 agent defs, found ${ndef}"; fi

# C6 — skills frontmatter name+description
sok=1; sn=0
while IFS= read -r s; do [ -z "$s" ] && continue; sn=$((sn+1))
  head -n1 "$s" | grep -q '^---' && grep -q '^name:' "$s" && grep -q '^description:' "$s" || { no "C6 ${s#${PLUGIN_DIR}/} frontmatter (need ---/name/description)"; sok=0; }
done < <(find "${PLUGIN_DIR}/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' 2>/dev/null | sort)
{ [ "${sn}" -gt 0 ] && [ "${sok}" -eq 1 ]; } && ok "C6 ${sn} skills have name+description frontmatter" || { [ "${sn}" -gt 0 ] || no "C6 no skills found"; }

# C7 — 16 full + 16 compact profiles
full=$(find "${PLUGIN_DIR}/agents" -maxdepth 1 -name '*.md' ! -name '_preamble.md' ! -name 'index.md' ! -name '*-compact.md' -type f 2>/dev/null | wc -l | tr -d ' ')
comp=$(find "${PLUGIN_DIR}/agents" -maxdepth 1 -name '*-compact.md' -type f 2>/dev/null | wc -l | tr -d ' ')
{ [ "${full}" -ge 16 ] && [ "${comp}" -ge 16 ]; } && ok "C7 ${full} full + ${comp} compact profiles" || no "C7 profiles (full=${full} compact=${comp}, need >=16 each)"

# C8 — CONDUCTOR.md handback anchors + quality gate counts
C="${PLUGIN_DIR}/CONDUCTOR.md"
if have CONDUCTOR.md \
   && grep -qF 'Compressed format (~5 lines):' "$C" && grep -qF 'Full format (9 fields):' "$C" \
   && grep -qF 'Simple Tier (2 items)' "$C" && grep -qF 'Moderate Tier (6 items)' "$C" && grep -qF 'Complex Tier (9 items)' "$C"; then
  ok "C8 CONDUCTOR.md handback anchors + 2/6/9 quality-gate counts present"
else no "C8 CONDUCTOR.md handback anchors / gate counts"; fi

# C9 — vocabulary audit (no Claude bleed)
if "${SCRIPT_DIR}/codex-vocabulary-audit.sh" "${PLUGIN_DIR}" >/dev/null 2>&1; then
  ok "C9 codex-vocabulary-audit (no Claude-platform bleed)"
else no "C9 codex-vocabulary-audit found bleed — run scripts/codex-vocabulary-audit.sh for detail"; fi

echo ""; echo "================================"
TOTAL=$((PASS+FAIL))
if [ "${FAIL}" -eq 0 ]; then echo "${GREEN}PASS${NC} validate-plugin: ${PASS}/${TOTAL}"; exit 0; fi
echo "${RED}FAIL${NC} validate-plugin: ${FAIL}/${TOTAL} check(s) failed"; exit 1
