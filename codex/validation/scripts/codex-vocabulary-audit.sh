#!/usr/bin/env bash
#
# codex-vocabulary-audit.sh — fail if Claude-platform vocabulary bleeds into the
# generated oj-codex plugin tree.
#
# The first full generation left Claude residue (haiku/sonnet/opus, "Task tool",
# "TeamCreate", "SendMessage", "CLAUDE.md") in CONDUCTOR.md and two skills because the
# delta-style step prompts point at the Claude generator's prompts/specs. This audit is the
# regression gate for that defect class.
#
# KEEP (valid on Codex, NOT flagged): "SessionStart" / "SubagentStart" hook names; the
# abstract primitives Consult/Convene/Inform/Onboard; deliberate "Claude Code" comparative
# prose (the per-expert-effort capability-gain note).
#
# Usage: codex-vocabulary-audit.sh [PLUGIN_DIR]
# Exit:  0 clean | 1 bleed found | 2 usage/plugin-dir error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${1:-${OJ_CODEX_DIR:-${SCRIPT_DIR}/../../../../oj-codex}}"
[ -d "${PLUGIN_DIR}" ] || { echo "ERROR: plugin dir not found: ${PLUGIN_DIR}" >&2; exit 2; }
PLUGIN_DIR="$(cd "${PLUGIN_DIR}" && pwd)"

if [ -t 1 ]; then RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; NC=$'\033[0m'; else RED=''; GREEN=''; NC=''; fi

# Banned terms (ERE). Word-boundaried where a substring would over-match.
BANNED=(
  '\$\{CLAUDE_PLUGIN_ROOT\}'
  '\$\{CODEX_PLUGIN_ROOT\}'
  '~/\.claude/'
  '\b(haiku|sonnet|opus)\b'
  '\bTask tool\b'
  '\bTeamCreate\b'
  '\bSendMessage\b'
  '\bCLAUDE\.md\b'
  '\bclaude plugin\b'
)

# Paths excluded from the scan: VCS + generation scaffolding (logs narrate banned terms).
PRUNE=( -path '*/.git' -o -path '*/.oj-codex-sentinels' -o -path '*/prompts-built' )

fail=0
echo "vocabulary audit: ${PLUGIN_DIR}"
for term in "${BANNED[@]}"; do
  # Collect matching files (content), excluding pruned dirs.
  hits=$(find "${PLUGIN_DIR}" \( "${PRUNE[@]}" \) -prune -o -type f \
           \( -name '*.md' -o -name '*.toml' -o -name '*.json' -o -name 'oj-helper' \) -print 2>/dev/null \
         | xargs grep -lE "${term}" 2>/dev/null || true)
  if [ -n "${hits}" ]; then
    echo "${RED}FAIL${NC} banned term /${term}/ in:"
    echo "${hits}" | sed "s#${PLUGIN_DIR}/#  - #"
    fail=1
  else
    echo "${GREEN}ok${NC}   /${term}/ absent"
  fi
done

echo ""
if [ "${fail}" -eq 0 ]; then
  echo "${GREEN}PASS${NC} codex-vocabulary-audit: no Claude-platform bleed"
  exit 0
fi
echo "${RED}FAIL${NC} codex-vocabulary-audit: Claude-platform vocabulary present (fix step prompts + regenerate)"
exit 1
