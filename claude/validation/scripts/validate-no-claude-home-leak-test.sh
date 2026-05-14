#!/usr/bin/env bash
#
# validate-no-claude-home-leak-test.sh — CI gate for the standalone
# `~/.claude/` leak-hygiene validator (validate-no-claude-home-leak.sh).
#
# PURPOSE: Lock in the contract of validate-no-claude-home-leak.sh across
# eight canonical inputs covering the positive-glob scope AND, critically,
# the exemption-control (N5) that proves the validator does NOT over-trigger
# on out-of-scope files (bin/, README.md, .claude/CLAUDE.md). The
# adjudicated scope is fail-closed with NO keep-list, so the test must
# confirm that out-of-scope paths are not scanned even when they contain
# `~/.claude/` literals.
#
# SCENARIOS:
#   P1 — empty OUTPUT_DIR (exists, no files at all).
#        Expected: exit 0 (no scoped files = vacuously clean).
#   P2 — partial tree (no CONDUCTOR.md, scoped subdirs exist but contain
#        no leak — mirrors a fresh `--spike NN` output stopping before
#        plugin-tree finalization).
#        Expected: exit 0.
#   P3 — the live oj-claude/ baseline tree, POST-SCRUB.
#        Expected: exit 0 (regression sentinel for the m.6 item 2 scrub).
#   N1 — plant `~/.claude/agents/X.md` literal in CONDUCTOR.md.
#        Expected: exit 1, FILE:LINE:TEXT surfaced.
#   N2 — plant in agents/index.md (the m.6 m.3-Iter-3b reproducer).
#        Expected: exit 1, FILE:LINE:TEXT surfaced.
#   N3 — plant in senior-software-engineer-compact.md (the 16x compact-
#        profile Full-profile-line class — most common leak shape).
#        Expected: exit 1, FILE:LINE:TEXT surfaced.
#   N4 — plant in skills/cycle/SKILL.md (one-level skill subdir scope).
#        Expected: exit 1, FILE:LINE:TEXT surfaced.
#   N5 — CRITICAL EXEMPTION CONTROL: plant simultaneously in
#        bin/oj-helper (BL-023 intentional doc comments), README.md
#        (adopter-facing migration prose), .claude/CLAUDE.md
#        (project-local). Expected: exit 0. This proves the positive-glob
#        scope does NOT over-trigger on out-of-scope paths.
#   N6 — companion skill file: plant `~/.claude/...` literal in a
#        hypothetical `skills/health-check/REFERENCE.md` (an ancillary
#        non-SKILL.md skill file). Regression guard for the m.6 8a
#        widening from skills/*/SKILL.md → skills/*/*.md.
#        Expected: exit 1, FILE:LINE:TEXT surfaced.
#
# OUTPUT FORMAT (mirrors validate-no-step-sentinel-test.sh):
#   PASS <scenario name>
#   FAIL <scenario name> (with diagnostic)
#   Summary: ${PASS_COUNT}/${TOTAL}
#
# EXIT CODES:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error (script missing, baseline tree missing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="${SCRIPT_DIR}/validate-no-claude-home-leak.sh"
LIVE_BASELINE="${OJ_LIVE_BASELINE:-/Users/brenton/workspace/github.com/openjunto/oj-claude}"

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[ -f "${VALIDATOR}" ] || { echo -e "${RED}ERROR${NC} validator not found: ${VALIDATOR}" >&2; exit 2; }
[ -x "${VALIDATOR}" ] || { echo -e "${RED}ERROR${NC} validator not executable: ${VALIDATOR}" >&2; exit 2; }
[ -d "${LIVE_BASELINE}" ] || { echo -e "${RED}ERROR${NC} live baseline not found: ${LIVE_BASELINE}" >&2; exit 2; }

PASS_COUNT=0
FAIL_COUNT=0

TMPDIRS=()
cleanup() {
    local td
    for td in "${TMPDIRS[@]:-}"; do
        if [ -n "${td}" ] && [ -d "${td}" ]; then
            rm -rf "${td}"
        fi
    done
}
trap cleanup EXIT

# Run the validator and capture exit code + combined output.
# Args: <output_dir>
# Sets globals: RUN_RC, RUN_OUT
run_validator() {
    local out_dir="$1"
    set +e
    RUN_OUT=$(bash "${VALIDATOR}" "${out_dir}" 2>&1)
    RUN_RC=$?
    set -e
}

# Assert exit code matches expected and (when checking for FAIL) all
# expected substrings appear in output.
# Args: <scenario name> <expected_rc> [<expected_substring> ...]
assert_outcome() {
    local name="$1" expected_rc="$2"
    shift 2

    if [ "${RUN_RC}" -ne "${expected_rc}" ]; then
        echo -e "${RED}FAIL${NC} ${name}"
        echo -e "${CYAN}    expected exit ${expected_rc}, got ${RUN_RC}${NC}"
        echo -e "${CYAN}    output:${NC}"
        echo "${RUN_OUT}" | sed 's/^/      /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    local sub
    for sub in "$@"; do
        if ! echo "${RUN_OUT}" | grep -qF -- "${sub}"; then
            echo -e "${RED}FAIL${NC} ${name}"
            echo -e "${CYAN}    expected substring not found: ${sub}${NC}"
            echo -e "${CYAN}    output:${NC}"
            echo "${RUN_OUT}" | sed 's/^/      /'
            FAIL_COUNT=$((FAIL_COUNT + 1))
            return
        fi
    done

    echo -e "${GREEN}PASS${NC} ${name} (exit ${RUN_RC})"
    PASS_COUNT=$((PASS_COUNT + 1))
}

echo -e "${YELLOW}[INFO]${NC} validate-no-claude-home-leak test suite"
echo -e "${YELLOW}[INFO]${NC} validator:     ${VALIDATOR}"
echo -e "${YELLOW}[INFO]${NC} live baseline: ${LIVE_BASELINE}"
echo

# ---------------------------------------------------------------------------
# P1: empty OUTPUT_DIR (no scoped files exist, vacuously clean)
# ---------------------------------------------------------------------------
TD_P1=$(mktemp -d -t leakcheck-p1-XXXXXX)
TMPDIRS+=("${TD_P1}")
run_validator "${TD_P1}"
assert_outcome "P1: empty OUTPUT_DIR -> exit 0" 0 "PASS"

# ---------------------------------------------------------------------------
# P2: partial tree (scoped subdirs exist, no leaks, no CONDUCTOR.md)
# ---------------------------------------------------------------------------
TD_P2=$(mktemp -d -t leakcheck-p2-XXXXXX)
TMPDIRS+=("${TD_P2}")
mkdir -p "${TD_P2}/agents" "${TD_P2}/reference" "${TD_P2}/skills/consult"
# Non-leaking content so the scan has something to scan.
echo "# Index" > "${TD_P2}/agents/index.md"
echo "# Stakeholders" > "${TD_P2}/reference/stakeholder-guide.md"
echo "# Consult skill" > "${TD_P2}/skills/consult/SKILL.md"
run_validator "${TD_P2}"
assert_outcome "P2: partial tree (no CONDUCTOR.md, no leaks) -> exit 0" 0 "PASS"

# ---------------------------------------------------------------------------
# P3: live oj-claude/ baseline tree, POST-SCRUB
# ---------------------------------------------------------------------------
run_validator "${LIVE_BASELINE}"
assert_outcome "P3: live oj-claude baseline (post-scrub) -> exit 0" 0 "PASS"

# ---------------------------------------------------------------------------
# N1: leak planted in CONDUCTOR.md at root
# ---------------------------------------------------------------------------
TD_N1=$(mktemp -d -t leakcheck-n1-XXXXXX)
TMPDIRS+=("${TD_N1}")
cat > "${TD_N1}/CONDUCTOR.md" <<'EOF'
# OpenJunto: Agent Coordination System
See `~/.claude/agents/index.md` for the roster.
EOF
run_validator "${TD_N1}"
assert_outcome "N1: leak in CONDUCTOR.md -> exit 1, FILE:LINE:TEXT surfaced" 1 \
    "FAIL" \
    "CONDUCTOR.md:2:" \
    '~/.claude/agents/index.md'

# ---------------------------------------------------------------------------
# N2: leak planted in agents/index.md (m.3 Iter 3b reproducer)
# ---------------------------------------------------------------------------
TD_N2=$(mktemp -d -t leakcheck-n2-XXXXXX)
TMPDIRS+=("${TD_N2}")
mkdir -p "${TD_N2}/agents"
cat > "${TD_N2}/agents/index.md" <<'EOF'
# Agent Index
See `~/.claude/reference/stakeholder-guide.md` for stakeholder mapping.
EOF
run_validator "${TD_N2}"
assert_outcome "N2: leak in agents/index.md -> exit 1, FILE:LINE:TEXT surfaced" 1 \
    "FAIL" \
    "agents/index.md:2:" \
    '~/.claude/reference/stakeholder-guide.md'

# ---------------------------------------------------------------------------
# N3: leak planted in senior-software-engineer-compact.md
# (the 16x compact-profile Full-profile-line class)
# ---------------------------------------------------------------------------
TD_N3=$(mktemp -d -t leakcheck-n3-XXXXXX)
TMPDIRS+=("${TD_N3}")
mkdir -p "${TD_N3}/agents"
cat > "${TD_N3}/agents/senior-software-engineer-compact.md" <<'EOF'
# Senior Software Engineer (compact)
Full profile: `~/.claude/agents/senior-software-engineer.md`
EOF
run_validator "${TD_N3}"
assert_outcome "N3: leak in senior-software-engineer-compact.md -> exit 1, FILE:LINE:TEXT surfaced" 1 \
    "FAIL" \
    "agents/senior-software-engineer-compact.md:2:" \
    '~/.claude/agents/senior-software-engineer.md'

# ---------------------------------------------------------------------------
# N4: leak planted in skills/cycle/SKILL.md (one-level skill subdir scope)
# ---------------------------------------------------------------------------
TD_N4=$(mktemp -d -t leakcheck-n4-XXXXXX)
TMPDIRS+=("${TD_N4}")
mkdir -p "${TD_N4}/skills/cycle"
cat > "${TD_N4}/skills/cycle/SKILL.md" <<'EOF'
# /cycle Skill
Reads agent profiles from `~/.claude/agents/`.
EOF
run_validator "${TD_N4}"
assert_outcome "N4: leak in skills/cycle/SKILL.md -> exit 1, FILE:LINE:TEXT surfaced" 1 \
    "FAIL" \
    "skills/cycle/SKILL.md:2:" \
    '~/.claude/agents/'

# ---------------------------------------------------------------------------
# N5: CRITICAL EXEMPTION CONTROL — plants in OUT-OF-SCOPE files
# bin/oj-helper (BL-023 intentional doc comments),
# README.md (adopter-facing migration prose),
# .claude/CLAUDE.md (project-local).
# Expected: exit 0. The positive-glob scope must NOT scan these.
# ---------------------------------------------------------------------------
TD_N5=$(mktemp -d -t leakcheck-n5-XXXXXX)
TMPDIRS+=("${TD_N5}")
mkdir -p "${TD_N5}/bin" "${TD_N5}/.claude"
cat > "${TD_N5}/bin/oj-helper" <<'EOF'
#!/usr/bin/env bash
# oj-helper — references ~/.claude/agents/ for migration context.
exit 0
EOF
chmod +x "${TD_N5}/bin/oj-helper"
cat > "${TD_N5}/README.md" <<'EOF'
# OpenJunto Plugin
Migrating from the prior `~/.claude/` install? See docs/onboarding.md.
EOF
cat > "${TD_N5}/.claude/CLAUDE.md" <<'EOF'
# Project-local CLAUDE.md
Points at user's `~/.claude/CLAUDE.md` for global instructions.
EOF
# Also include a clean scoped file so the scan has scoped input.
mkdir -p "${TD_N5}/agents"
echo "# Index (clean)" > "${TD_N5}/agents/index.md"
run_validator "${TD_N5}"
assert_outcome "N5: out-of-scope leaks in bin/+README.md+.claude/CLAUDE.md -> exit 0 (no over-trigger)" 0 "PASS"

# ---------------------------------------------------------------------------
# N6: leak planted in a companion skill file (skills/health-check/REFERENCE.md)
# Regression guard for m.6 8a glob widening: skills/*/*.md must catch
# non-SKILL.md skill files.
# ---------------------------------------------------------------------------
TD_N6=$(mktemp -d -t leakcheck-n6-XXXXXX)
TMPDIRS+=("${TD_N6}")
mkdir -p "${TD_N6}/skills/health-check"
# Clean SKILL.md so the skill subdir is realistic.
cat > "${TD_N6}/skills/health-check/SKILL.md" <<'EOF'
---
description: Health check skill
---
# Health check
EOF
cat > "${TD_N6}/skills/health-check/REFERENCE.md" <<'EOF'
# Health-check Reference
See `~/.claude/reference/health-check-runbook.md` for full context.
EOF
run_validator "${TD_N6}"
assert_outcome "N6: leak in skills/health-check/REFERENCE.md (companion file) -> exit 1, FILE:LINE:TEXT surfaced" 1 \
    "FAIL" \
    "skills/health-check/REFERENCE.md:2:" \
    '~/.claude/reference/health-check-runbook.md'

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} validate-no-claude-home-leak-test: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
else
    echo -e "${RED}FAIL${NC} validate-no-claude-home-leak-test: ${FAIL_COUNT}/${TOTAL} scenario(s) failed"
    echo "================================"
    exit 1
fi
