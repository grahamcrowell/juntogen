#!/usr/bin/env python3
"""load-contract.py — BL-025-h contract loader.

Reads ${SPEC_DIR}/platform-contract.yaml and emits machine-readable views
of the contract for bash consumption. Sibling to parse-contract.py (which
focuses on the keep_list/banned_terms tables for vocabulary-audit). This
loader focuses on the primitives, canonical_ids, and contract metadata
consumed by the generator pipeline.

Subcommands:

  primitives        one primitive name per line (preserves contract order)
  primitive-roles   one row per primitive (TSV).
                    Columns: name<TAB>role
                    Role text is the frozen `role` one-liner from the
                    contract (any change to a role string requires a
                    coordinated juntospec + juntogen + oj-claude release).
  canonical-ids     one row per canonical_id (TSV).
                    Columns: id<TAB>file<TAB>section<TAB>file_repo
                    File order matches the contract; multi-id source lines
                    each emit one row (already expanded in the contract).
                    file_repo is the optional cross-repo locator (BL-025-g):
                    empty/"juntospec" => resolve under SPEC_DIR; "juntogen"
                    => resolve under the juntogen repo root. Backward-
                    compatible: existing 3-column consumers (e.g.,
                    validate-dry-run.sh:151 which awks $1) are unaffected.
                    Parse-time enum guard (BL-025-h.1 F-05): file_repo not
                    in ("", "juntospec", "juntogen") => die(1) — refuses
                    to silently fall through.
  spec-files        one row per layout.spec_files[] entry (TSV) — BL-025-h.1.
                    Columns: file<TAB>file_repo<TAB>path
                    `file` is the basename used in the [FILE: ...] marker;
                    `path` is the resolved path under the indicated repo
                    (defaults to file when not explicitly set in the
                    contract). file_repo enum guard applies (same as
                    canonical-ids).
  version           the contract `version` field on a single line
  source-fragment   sourceable bash fragment defining:
                      OJ_PRIMITIVE_NAMES        space-joined primitive names
                      OJ_CONTRACT_VERSION       contract version string
                      OJ_PRIMITIVE_VOCAB_REGEX  pipe-joined alternation of
                                                regex-escaped primitive names,
                                                suitable for `grep -E` with
                                                a word-boundary check.
                    The CALLER is responsible for `mktemp`-ing a tempfile
                    and passing its path via env or shell capture; this
                    subcommand emits ONLY the variable definitions, never
                    a tempfile path. (The original brief mentioned an
                    OJ_CANONICAL_IDS_TSV path-passthrough; on review the
                    sourceable-fragment idiom is purer if we just emit the
                    TSV variable inline. We use the `canonical-ids`
                    subcommand for the TSV stream — callers that want a
                    file redirect it themselves with a single `>`.)

Exit codes:
  0 success
  1 file not found / yaml parse failure / malformed contract
  2 usage error (unknown subcommand, wrong arg count)

Idempotency invariant (FINDING-8):
  All output is a deterministic function of the YAML input. The contract
  is read with safe_load (no Python object hooks). Lists preserve order
  (yaml.safe_load on a sequence returns a Python list — order-stable).
  Dict iteration is avoided in favor of explicit field reads. Every shell-
  quoted value uses shlex.quote so the same input produces byte-identical
  fragment output across runs.
"""

from __future__ import annotations

import re
import shlex
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write(
        "ERROR: PyYAML not available; install with `python3 -m pip install pyyaml`\n"
    )
    sys.exit(1)


def die(msg: str, code: int = 1) -> None:
    sys.stderr.write(f"ERROR: {msg}\n")
    sys.exit(code)


def load_contract(path_arg: str) -> dict:
    path = Path(path_arg)
    if not path.is_file():
        die(f"contract file not found: {path}", 1)
    try:
        with path.open() as f:
            doc = yaml.safe_load(f)
    except yaml.YAMLError as exc:
        die(f"YAML parse failed for {path}: {exc}", 1)
    if not isinstance(doc, dict):
        die(f"contract root must be a mapping (got {type(doc).__name__}): {path}", 1)
    return doc


def _primitives(doc: dict) -> list[tuple[str, str]]:
    """Return (name, role) tuples in contract order. Does NOT filter on
    anchor_status (per BL-025-h TENSION-3 mitigation: contract loader
    reads all primitives unconditionally; pending->active flip is
    BL-025-c.1's responsibility, not the loader's)."""
    primitives = doc.get("primitives") or []
    if not isinstance(primitives, list):
        die("contract.primitives must be a list", 1)
    rows: list[tuple[str, str]] = []
    for entry in primitives:
        if not isinstance(entry, dict):
            die(f"contract.primitives[] entry must be a mapping: {entry!r}", 1)
        name = entry.get("name")
        if not isinstance(name, str) or not name:
            die(f"contract.primitives[] entry missing name: {entry!r}", 1)
        if "\t" in name or "\n" in name:
            die(f"primitive name contains tab/newline: {name!r}", 1)
        role = entry.get("role")
        if not isinstance(role, str) or not role:
            die(f"contract.primitives[{name!r}] missing role", 1)
        if "\t" in role or "\n" in role:
            die(f"primitive role for {name!r} contains tab/newline: {role!r}", 1)
        rows.append((name, role))
    if not rows:
        die("contract has no primitives", 1)
    return rows


def _primitive_names(doc: dict) -> list[str]:
    return [name for name, _role in _primitives(doc)]


_VALID_FILE_REPOS = ("", "juntospec", "juntogen")


def _check_file_repo(value: str, where: str) -> None:
    """Enum guard for file_repo (BL-025-h.1 F-05). Refuses to silently
    fall through on unknown values. Applies to BOTH canonical_ids and
    spec_files."""
    if value not in _VALID_FILE_REPOS:
        die(
            f"{where}: file_repo={value!r} not in {_VALID_FILE_REPOS}; "
            "extend allow-list or fix contract row",
            1,
        )


def _canonical_id_rows(doc: dict) -> list[tuple[str, str, str, str]]:
    rows: list[tuple[str, str, str, str]] = []
    entries = doc.get("canonical_ids") or []
    if not isinstance(entries, list):
        die("contract.canonical_ids must be a list", 1)
    for entry in entries:
        if not isinstance(entry, dict):
            die(f"contract.canonical_ids[] entry must be a mapping: {entry!r}", 1)
        cid = str(entry.get("id", ""))
        cfile = str(entry.get("file", ""))
        csection = str(entry.get("section", ""))
        # BL-025-g: optional cross-repo locator. Empty string is the
        # implicit "juntospec / spec corpus" default — preserves backward
        # compat for the 42 of 43 entries that omit the field.
        file_repo_raw = entry.get("file_repo")
        cfile_repo = "" if file_repo_raw is None else str(file_repo_raw)
        # BL-025-h.1 F-05: parse-time enum guard.
        _check_file_repo(cfile_repo, f"contract.canonical_ids[id={cid!r}]")
        for field, value in (
            ("id", cid),
            ("file", cfile),
            ("section", csection),
            ("file_repo", cfile_repo),
        ):
            if "\t" in value or "\n" in value:
                die(f"canonical_id field {field!r} contains tab/newline: {value!r}", 1)
        rows.append((cid, cfile, csection, cfile_repo))
    return rows


def _spec_file_rows(doc: dict) -> list[tuple[str, str, str]]:
    """BL-025-h.1: layout.spec_files[] reader.

    Returns (file, file_repo, path) tuples in contract order.
      file       = basename used in [FILE: ...] markers (must be unique)
      file_repo  = "" | "juntospec" | "juntogen" (enum-guarded)
      path       = optional override for path resolution; defaults to file
    """
    rows: list[tuple[str, str, str]] = []
    layout = doc.get("layout") or {}
    if not isinstance(layout, dict):
        die("contract.layout must be a mapping", 1)
    entries = layout.get("spec_files") or []
    if not isinstance(entries, list):
        die("contract.layout.spec_files must be a list", 1)
    seen_files: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            die(f"contract.layout.spec_files[] entry must be a mapping: {entry!r}", 1)
        sfile = str(entry.get("file", ""))
        if not sfile:
            die(f"contract.layout.spec_files[] entry missing file: {entry!r}", 1)
        if sfile in seen_files:
            die(
                f"contract.layout.spec_files[]: duplicate file basename "
                f"{sfile!r} — basenames must be unique for [FILE: ...] resolution",
                1,
            )
        seen_files.add(sfile)
        file_repo_raw = entry.get("file_repo")
        sfile_repo = "" if file_repo_raw is None else str(file_repo_raw)
        _check_file_repo(sfile_repo, f"contract.layout.spec_files[file={sfile!r}]")
        path_raw = entry.get("path")
        spath = sfile if path_raw is None or str(path_raw) == "" else str(path_raw)
        for field, value in (
            ("file", sfile),
            ("file_repo", sfile_repo),
            ("path", spath),
        ):
            if "\t" in value or "\n" in value:
                die(
                    f"spec_files field {field!r} contains tab/newline: {value!r}",
                    1,
                )
        rows.append((sfile, sfile_repo, spath))
    return rows


def _contract_version(doc: dict) -> str:
    version = doc.get("version")
    if version is None:
        die("contract.version is missing", 1)
    sv = str(version)
    if "\t" in sv or "\n" in sv:
        die(f"contract.version contains tab/newline: {sv!r}", 1)
    return sv


def cmd_primitives(doc: dict) -> int:
    for name in _primitive_names(doc):
        print(name)
    return 0


def cmd_primitive_roles(doc: dict) -> int:
    for name, role in _primitives(doc):
        print(f"{name}\t{role}")
    return 0


def cmd_canonical_ids(doc: dict) -> int:
    for cid, cfile, csection, cfile_repo in _canonical_id_rows(doc):
        print(f"{cid}\t{cfile}\t{csection}\t{cfile_repo}")
    return 0


def cmd_spec_files(doc: dict) -> int:
    # BL-025-h.1: TSV columns: file<TAB>file_repo<TAB>path
    for sfile, sfile_repo, spath in _spec_file_rows(doc):
        print(f"{sfile}\t{sfile_repo}\t{spath}")
    return 0


def cmd_version(doc: dict) -> int:
    print(_contract_version(doc))
    return 0


# Word-boundary-friendly regex alternation. We re.escape() each primitive
# name to defang shell metacharacters (".", "{", "}", etc.) and join with
# the standard alternation operator. The CALLER chooses how to enforce
# word boundaries (BSD-grep on macOS does not support \b in -E by
# default; the consumer pattern is `grep -E "(^|[^a-zA-Z0-9_-])(${REGEX})([^a-zA-Z0-9_-]|$)"`,
# matching the s16 model-id idiom in tier-a-assertions.sh).
def _vocab_regex(names: list[str]) -> str:
    return "|".join(re.escape(n) for n in names)


def cmd_source_fragment(doc: dict) -> int:
    names = _primitive_names(doc)
    version = _contract_version(doc)
    vocab_regex = _vocab_regex(names)

    # Single space join is intentional — primitive names contain no spaces
    # (validated above). shlex.quote produces single-quoted POSIX-safe
    # values that bash sources verbatim.
    names_joined = " ".join(names)

    print("# load-contract.py source-fragment — BL-025-h")
    print("# Generated from platform-contract.yaml. Do not edit by hand.")
    print(f"OJ_PRIMITIVE_NAMES={shlex.quote(names_joined)}")
    print(f"OJ_CONTRACT_VERSION={shlex.quote(version)}")
    print(f"OJ_PRIMITIVE_VOCAB_REGEX={shlex.quote(vocab_regex)}")
    print("export OJ_PRIMITIVE_NAMES OJ_CONTRACT_VERSION OJ_PRIMITIVE_VOCAB_REGEX")
    return 0


_DISPATCH = {
    "primitives": cmd_primitives,
    "primitive-roles": cmd_primitive_roles,
    "canonical-ids": cmd_canonical_ids,
    "spec-files": cmd_spec_files,
    "version": cmd_version,
    "source-fragment": cmd_source_fragment,
}


def main(argv: list[str]) -> int:
    if len(argv) < 2 or len(argv) > 3:
        sys.stderr.write(__doc__ or "")
        return 2
    subcmd = argv[1]
    if subcmd not in _DISPATCH:
        sys.stderr.write(
            f"ERROR: unknown subcommand {subcmd!r} (expected one of: "
            f"{', '.join(sorted(_DISPATCH))})\n"
        )
        return 2

    # Resolve contract path: explicit positional (argv[2]) takes precedence;
    # otherwise fall back to ${OJ_CONTRACT_PATH} (caller may export this);
    # otherwise hard-fail with a clear message.
    if len(argv) == 3:
        contract_path = argv[2]
    else:
        import os
        contract_path = os.environ.get("OJ_CONTRACT_PATH", "")
        if not contract_path:
            sys.stderr.write(
                "ERROR: contract path required. Pass as second argument "
                "or export OJ_CONTRACT_PATH=...\n"
            )
            return 2

    doc = load_contract(contract_path)
    return _DISPATCH[subcmd](doc)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
