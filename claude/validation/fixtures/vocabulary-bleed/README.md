# vocabulary-bleed fixtures

Negative + positive test fixtures for `vocabulary-audit.sh` (BL-025-e).

## Fixture contract

Each fixture directory contains exactly three files:

- `spec.md` — a synthetic spec file (named matching the core-spec scope pattern;
  the harness renames it on copy to control which scope file the audit sees,
  e.g. `D24-fixture.md` or `M16-derivation-architecture.md`). The first line
  of `spec.md` declares the target name via `<!-- target: NAME.md -->`.
- `contract.yaml` — a minimal `platform-contract.yaml`-shaped document containing
  only `banned_terms:` and (optionally) `keep_list:`. The harness writes this
  directly as `platform-contract.yaml` in the synthetic spec root.
- `expected.yaml` — assertions:
  ```yaml
  exit_code: 1                            # required, expected audit exit code
  must_contain_stderr:                    # optional, list of substrings ALL of
    - "banned-term-bleed"                 #   which must appear in stderr
    - "FILE: D24-fixture.md"
  must_not_contain_stderr:                # optional, list of substrings NONE
    - "M16-derivation-architecture.md"    #   of which may appear in stderr
  ```

## Axes covered (per BL-025-e negative-fixture matrix)

- **A** banned-term-per-type: one fixture per banned term
  (Task tool, TeamCreate, SendMessage, SubagentStart, ~/.claude/, CLAUDE.md, model-tier).
- **B** detection-class:
  - (i) raw bare occurrence MUST flag
  - (ii) inside D08 `(verbatim):` block MUST NOT flag
  - (iii) inside M16 §3 region MUST NOT flag
  - (iv) inside the juntogen generator tree MUST NOT flag (out-of-scope path; post-BL-025-f the generator lives in a separate repo)
  - (v) one line after `## 4.` heading following §3 MUST flag (region-exit anchor)
- **C** keep_list semantics:
  - valid `match_kind: literal` entry — must pass
  - valid `match_kind: regex` entry — must pass
  - invalid `reason:` value — must flag
- **D** hash-drift:
  - wrong `context_hash` — must flag
  - correct hash but 1-byte edit to protected line — must flag
- **E** signoff state:
  - `pending-tech-writer-review` — must flag (BL-025-e block-ship policy)

## Migrated positives

The `positive/migrated-bl-025-c-*/` fixtures derive from the BL-025-c Stage B
human-readable artifacts at `.claude/artifacts/bl-025-c-stageb-fixtures/`,
re-encoded into the harness-consumable contract above. They demonstrate
post-rewrite spec content that MUST audit clean.
