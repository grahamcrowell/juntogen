#!/usr/bin/env bash
# contracts.sh — pinned-string CONTRACTS shared between oj-helper and tests.
#
# Each constant below is a CONTRACT: it appears in user-visible output AND is
# pattern-matched by the test harness, the structural validator, and the
# /oj:health-check skill. Edits MUST be coordinated:
#
#   1. Update the constant here.
#   2. Run scripts/validate-plugin.sh (drift canary C4 greps bin/oj-helper
#      for the literal — fails loudly if the helper has not been updated).
#   3. Run scripts/tests/oj-helper-hook-test.sh + plugin-validate-test.sh.
#
# This file is sourced (not executed). It must remain side-effect-free at
# the top level: declare constants only.
#
# Origin: BL-025-k synthesis 2026-05-11 (F5 — centralize pinned-string
# contract; both oj-helper AND tests source this; structural check C4
# greps bin/oj-helper for the literal as a drift canary).

# ────────────────────────────────────────────────────────────────────
# OJ_STDERR_CONDUCTOR_MISSING
# ────────────────────────────────────────────────────────────────────
# Stable stderr advisory emitted by `oj-helper conductor-inject` when
# CONDUCTOR.md is absent or unreadable. Health-check tooling and the
# oj-helper-hook-test harness pattern-match on this literal — DO NOT
# edit casually. The em-dash is intentional (matches the live string).
readonly OJ_STDERR_CONDUCTOR_MISSING="OpenJunto: CONDUCTOR.md missing — manager protocol will not be injected this session"
