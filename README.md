# juntogen

Generator for OpenJunto platform artifacts.

`juntogen` consumes the specification corpus in [`juntospec`](https://github.com/openjunto/juntospec) and emits installable artifacts into the `oj-{platform}` repos (initially `oj-claude`). It is the compiler in the juntospec-juntogen-ojclaude toolchain:

- **juntospec** — the genome (specs, contracts, canonical IDs).
- **juntogen** — the derivation engine (this repo; consumes the spec + `platform-contract.yaml`, produces platform-specific profiles and plugin artifacts).
- **oj-{platform}** — the installable plugin (e.g., `oj-claude` for Claude Code).

## Status

Pre-v0.0.1. The Claude platform generator has landed at `claude/` (BL-025-f).
The `claude/generate` pipeline orchestrates 12 generation steps that consume
`juntospec/` and emit installable artifacts into `oj-claude/`. SPEC_DIR
resolves via `--spec-dir` flag, `OJ_SPEC_DIR` env var, or the sibling probe
when `juntogen/` and `juntospec/` are co-located under a common parent.

```
{parent}/
  juntospec/    # spec corpus (the genome)
  juntogen/     # generators (this repo)
    claude/
      generate                # 12-step orchestrator
      D64-tooling.md          # Claude-platform-binding spec
      platform-defaults.yaml  # Layer 0 capability fallback
      steps/                  # generation prompts (step-NN-name.md)
      validation/             # vocabulary audit, tier-a assertions, fixtures
  oj-claude/    # installable plugin output
```
