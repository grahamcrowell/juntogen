# Validation Suite

Checks that the generated OpenJunto system conforms to spec at both the structural and behavioral layers.

## Layout

- `checklist.md` -- Structural verification: file counts, format strings, section headers, threshold values. Manual or scripted.
- `smoke-tests.md` -- Functional tests for critical paths (triage, delegation, quality gates).
- `anti-patterns.md` -- Common generation mistakes to check for.
- `problems/` -- Synthetic test fixtures grouped by behavioral dimension:
  - `delegation-boundary/` -- Manager delegates vs. implements.
  - `stakeholder-identification/` -- Correct stakeholder selection for a task.
  - `tier-classification/` -- Simple/Moderate/Complex triage accuracy.
- `scripts/` -- Automated validation scripts:
  - `tier-a-assertions.sh` -- Structural assertions against generated output.
  - `validate-platform-snapshot.sh` -- Schema check for `platform-snapshot.yaml`.
  - `validate-primitive.sh` -- Validates the `claude --append-system-prompt` primitive.

## Tiers

Validation is organized into tiers per spec `M08-validation-evolution.md`:

- **Tier A** -- Structural (fast, mechanical). Checks file presence, format strings, canonical identifiers.
- **Tier B** -- Behavioral (LLM-driven). Feeds synthetic problems through the generated system and scores the traces.
- **Tier C** -- Outcome measurement (longitudinal). Tracks calibration over time.

See `M08-validation-evolution.md` for the full methodology.
