#!/usr/bin/env python3
"""parse-contract.py — Read juntospec/platform-contract.yaml and emit TSV
to stdout for bash consumption.

Two output modes (selected by first arg):

  keep-list   one row per keep_list entry. Columns:
              file<TAB>line<TAB>term<TAB>match_kind<TAB>context_hash<TAB>reason<TAB>signed_off_by

  banned-terms one row per banned_terms entry. Columns:
              term<TAB>kind<TAB>scope<TAB>exempt_regions_csv<TAB>assertion

              The trailing `assertion` column (BL-025-e.1) names the
              tier-a-assertions.sh section that enforces the term
              ("s13"|"s14"|"s15"|"s16"). Empty string when absent so older
              contracts (and fixtures that omit the field) parse cleanly.

Lines are encoded so that no field contains a tab or newline. Term values
that legitimately contain tabs (none today, but future-safe) would be
rejected with a non-zero exit and a clear error.

Invoked from vocabulary-audit.sh and vocabulary-audit-test.sh; not a
public stable interface.

Usage:
  parse-contract.py keep-list <path-to-platform-contract.yaml>
  parse-contract.py banned-terms <path-to-platform-contract.yaml>

Exit codes:
  0 success
  1 file not found / yaml error / field validation error
  2 usage error
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write("ERROR: PyYAML not available; install with `python3 -m pip install pyyaml`\n")
    sys.exit(1)


def reject_unsafe(value: str, field: str) -> str:
    if "\t" in value or "\n" in value:
        sys.stderr.write(
            f"ERROR: field {field!r} contains tab or newline (unsupported by TSV encoding): {value!r}\n"
        )
        sys.exit(1)
    return value


# COLUMN_COUNT: 7  (BL-028 schema-drift guard — bash consumers read 7 vars + _extra)
# Fields: file<TAB>line<TAB>term<TAB>match_kind<TAB>context_hash<TAB>reason<TAB>signed_off_by
def emit_keep_list(doc: dict) -> None:
    entries = doc.get("keep_list", []) or []
    for entry in entries:
        file_v = reject_unsafe(str(entry.get("file", "")), "file")
        line_v = reject_unsafe(str(entry.get("line", "")), "line")
        term_v = reject_unsafe(str(entry.get("term", "")), "term")
        kind_v = reject_unsafe(str(entry.get("match_kind", "literal")), "match_kind")
        hash_v = reject_unsafe(str(entry.get("context_hash", "")), "context_hash")
        reason_v = reject_unsafe(str(entry.get("reason", "")), "reason")
        signer_v = reject_unsafe(str(entry.get("signed_off_by", "")), "signed_off_by")
        # NOTE: any new column added below MUST be paired with _extra-tail
        # updates in vocabulary-audit.sh AND a bump to COLUMN_COUNT and the
        # parse-contract-schema-test.sh expected count. The schema-drift test
        # will fail loudly otherwise (BL-028).
        print(f"{file_v}\t{line_v}\t{term_v}\t{kind_v}\t{hash_v}\t{reason_v}\t{signer_v}")


# COLUMN_COUNT: 5  (BL-028 schema-drift guard — bash consumers read 5 vars + _extra)
# Fields: term<TAB>kind<TAB>scope<TAB>exempt_regions_csv<TAB>assertion
def emit_banned_terms(doc: dict) -> None:
    entries = doc.get("banned_terms", []) or []
    for entry in entries:
        term_v = reject_unsafe(str(entry.get("term", "")), "term")
        kind_v = reject_unsafe(str(entry.get("kind", "literal")), "kind")
        scope_v = reject_unsafe(str(entry.get("scope", "core-spec-corpus")), "scope")
        regions = entry.get("exempt_regions", []) or []
        regions_csv = reject_unsafe(",".join(str(r) for r in regions), "exempt_regions")
        # BL-025-e.1: `assertion` field maps the term to a tier-a-assertions.sh
        # section. Empty string when the field is absent (older contracts /
        # fixtures); tier-a is responsible for deciding whether absence is a
        # hard error in its dispatch.
        assertion_v = reject_unsafe(str(entry.get("assertion", "")), "assertion")
        # NOTE: any new column added below MUST be paired with _extra-tail
        # updates in vocabulary-audit.sh AND a bump to COLUMN_COUNT and the
        # parse-contract-schema-test.sh expected count. The schema-drift test
        # will fail loudly otherwise (BL-028).
        print(f"{term_v}\t{kind_v}\t{scope_v}\t{regions_csv}\t{assertion_v}")


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        sys.stderr.write(__doc__ or "")
        return 2
    mode, path_arg = argv[1], argv[2]
    path = Path(path_arg)
    if not path.is_file():
        sys.stderr.write(f"ERROR: not a file: {path}\n")
        return 1
    try:
        with path.open() as f:
            doc = yaml.safe_load(f) or {}
    except yaml.YAMLError as exc:
        sys.stderr.write(f"ERROR: YAML parse failed for {path}: {exc}\n")
        return 1

    if mode == "keep-list":
        emit_keep_list(doc)
        return 0
    if mode == "banned-terms":
        emit_banned_terms(doc)
        return 0
    sys.stderr.write(f"ERROR: unknown mode {mode!r} (expected keep-list | banned-terms)\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
