# Generation Prompt: Step 09 — Settings (RETIRED in plugin form)

## Status

**This step is RETIRED for the plugin-tree-direct shape.** The plugin host configures settings at install time from the static `${OUTPUT_DIR}/.claude-plugin/plugin.json` and `${OUTPUT_DIR}/hooks/hooks.json` manifests; the plugin tree does NOT ship a `settings.json` file (that file is user-configured under `~/.claude/settings.json` and is outside the plugin distribution).

> **Historical context** — the pre-retirement tooling spec for this step lived at `[FILE: D64-tooling.md]` (juntogen-rooted; cross-repo marker preserved so the build-prompt substitution test continues to exercise the file_repo=juntogen path). The current binding is in `lib/emit-static-plugin-manifest.sh`; D64 documents the broader tooling contract this step formerly contributed to.

The numeric step gap is preserved so older sentinel/log archives remain comparable across pipeline versions. The generator dispatches verify_step_09 to a trivial `return 0` stub; this prompt is preserved as documentation rather than as an active generation task.

## Task

**No artifacts are generated.** The pre-cycle behavior (writing a legacy `settings.json` file under the retired `src/` wrapper, populated with environment variables, permissions, hook matchers, and model selection) was superseded by:

1. **Static manifests** — `.claude-plugin/plugin.json` (metadata) and `hooks/hooks.json` (SessionStart + the hook matcher contracts) are emitted by `lib/emit-static-plugin-manifest.sh` during step-07 dispatch. The matcher entry and the inject-profile hook command live there now.
2. **Plugin-host install flow** — environment variables, permissions, and model selection are handled by the plugin host at install time, not by a generator-emitted settings.json.

## Verification

verify_step_09 returns 0 unconditionally; there are no files to check. The step exists only to keep the sentinel-history gap from re-renumbering downstream prompts and validators.

## Dependencies

None. This step depends on nothing and produces nothing. Steps 10 and 11 do not depend on step-09 output.

## Retirement notes

- The pre-cycle prompt instructed Claude to write a legacy `settings.json` file (under the retired src-rooted output wrapper) with platform-fact bindings resolved from `platform-snapshot.yaml`. Those bindings have been relocated:
  - The hook matcher resolved from `hooks[point="*the platform hook contract*"].matchers[0]` is now consumed by step-07 (inject-profile agent-type filter) and emitted as a hooks.json literal by the static-emit helper.
  - The reasoning-tier model `api_id` is consumed by step-01 (CONDUCTOR.md model selection table) and is not pinned in the plugin tree.
- The Makefile-installer deep-merge protocol (content-hash gating, backup-on-merge) was retired with the Makefile itself (BL-025-m.1); the plugin host handles install semantics.
- If a future step needs to re-introduce settings.json emission, the numeric reuse target is step-09 (not a new step number).
