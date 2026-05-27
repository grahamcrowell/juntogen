# Generation Prompt: Step 10 — User Documentation

## Input

Read these specification files before generating:

1. `[FILE: F08-axioms.md]` — Foundational axioms (why OpenJunto exists, what it solves)
2. `[FILE: F16-architecture.md]` — System architecture (installed layout, activation mechanism, data flow)
3. `[FILE: D08-core-protocol.md]` — Triage model, execution tiers, quality gates
4. All other spec files (03-10) for comprehensive understanding

**Also read the actual OpenJunto source files** for reference:
- `/path/to/junto/README.md` — Project overview and quickstart
- `/path/to/junto/WHY.md` — Problem statement, how OpenJunto works, honest tradeoffs

## Task

Generate three user-facing documentation files:

1. **README.md** — Project overview, quickstart, architecture summary
2. **WHY.md** — Problem statement, how OpenJunto works, honest tradeoffs
3. **docs/onboarding.md** — First 10 minutes after installation

**Locations**:
- `/path/to/junto-project/README.md`
- `/path/to/junto-project/WHY.md`
- `/path/to/junto-project/docs/onboarding.md`

## 1. README.md

**Purpose**: First file users read. Quick overview, installation, and usage examples.

### Structure

1. **One-line summary** — "A Claude Code configuration that transforms the AI into a coordinated team of 16 expert sub-agents with structured peer review."

2. **Quickstart** — Installation in 3 commands:
   ```bash
   git clone <repo-url>
   cd junto
   make install
   ```

3. **Usage** — Show how OpenJunto activates automatically:
   - "Review this pull request for security issues."
   - "Fix the flaky test in auth_service_test.go."
   - "Evaluate whether we should migrate from REST to gRPC for internal services."

   Explain that the Manager handles triage, expert selection, peer review, and quality gates transparently.

4. **What's Included** — Brief list of components:
   - 16 expert agents (link to `agents/`)
   - Templates (link to `templates/`)
   - Complexity triage (Simple/Moderate/Complex tiers)
   - Peer review workflow
   - Circuit breakers

5. **How It Works** — Four-step flow:
   1. Triage — Incoming requests scored against 4 criteria
   2. Delegation — Manager spawns domain experts
   3. Review — Peer experts validate work
   4. Synthesis — Manager consolidates findings

6. **Advanced: Backlog Sprint** — Explain `/run-task` command for projects with `.claude/BACKLOG.md`

7. **Directory Structure** — Show the plugin tree (`agents/`, `templates/`, `skills/`, `reference/`, `CONDUCTOR.md` at plugin root) and the `.claude/` per-project layout (`.claude/BACKLOG.md`, `.claude/CLAUDE.md`, `.claude/state/`, `.claude/artifacts/`).

8. **Documentation Links** — Link to WHY.md and onboarding.md

### Key Requirements

- Keep it short (~80 lines max)
- Focus on getting started, not internals
- Examples should be concrete and recognizable
- Link to deeper docs (WHY.md, onboarding.md) for details

## 2. WHY.md

**Purpose**: Explain what problem OpenJunto solves, how it works, and honest tradeoffs. This is for people deciding whether to adopt OpenJunto.

### Structure

1. **The Problem** (from spec F08-axioms.md, Axiom 3):
   - Single-agent blind spots — Claude jumps to implementation without considering security, operational burden, failure modes
   - "Just prompt better" does not scale — Cannot hold 16 expert perspectives in your head
   - Context windows are the hard ceiling — Dilution across all roles

   **Result**: Code that works on happy path, but misses distributed bypass vectors, cache poisoning edge cases, thundering herds.

2. **How OpenJunto Works**:
   - Manager agent triages requests and selects domain experts
   - Domain experts analyze and build
   - Different expert reviews the work adversarially
   - Three tiers (Simple/Moderate/Complex) proportional to risk

   **Key mechanics**:
   - 16 domain experts (list roles)
   - Mandatory stakeholder perspectives (Product + Tech minimum)
   - STRONGEST OBJECTION required in every handback
   - Pre-mortem: "Imagine this shipped and failed. What went wrong?"
   - Circuit breaker: auto-escalates after 3 revision cycles

3. **What This Actually Looks Like** — Concrete example: adding rate limiting to an API

   **Without OpenJunto**: Working implementation, but misses:
   - Distributed bypass (attackers rotating IPs)
   - Cache poisoning (manipulating rate limit counters)
   - Thundering herd (simultaneous retries on window reset)
   - Storage cost at scale (per-user counter overhead)
   - Degradation behavior (rate limiter's backing store goes down)
   - Observability (no metrics on limit hit rates)

   **With OpenJunto**: Manager triages as Moderate, selects Security + DevOps + Software Engineer stakeholders. Each analyzes from their perspective, implementation incorporates findings, Distinguished Engineer conducts adversarial review.

4. **Honest Tradeoffs** — Table format (from junto/WHY.md):

   | Tradeoff | Reality |
   |----------|---------|
   | Token cost | 2-5x more tokens than baseline Claude |
   | Wall-clock time | Moderate tasks take minutes, not seconds |
   | Learning curve | ~1 week to internalize triage model |
   | Process discipline | Must respond to triage questions, approve stakeholder selections |
   | Over-processing risk | Simple tasks can get over-triaged if you don't push back |
   | Verbosity | Expert handbacks are structured and explicit (more text to read) |

   **When OpenJunto is NOT worth it**:
   - Quick one-off questions
   - Trivial fixes (typos, import ordering)
   - Rapid prototyping
   - Tasks where you know exactly what you want

   **When OpenJunto IS worth it**:
   - Security reviews
   - Architectural decisions
   - Cross-system changes
   - Compliance-sensitive work
   - Anything where "looks good to me" is not good enough

5. **Try It** — Installation command + first task to try:
   - "Review this pull request for security issues and operational readiness."
   - Point it at a real design problem and compare to single-agent Claude

### Key Requirements

- Be honest about costs (token overhead, wall-clock time, learning curve)
- Use concrete examples (rate limiting scenario)
- Do not oversell — "slower but catches the thing that would have cost you a week of incident response"
- Table format for tradeoffs (clear, scannable)

## 3. docs/onboarding.md

**Purpose**: Guide for new users in their first 10 minutes after installation.

### Structure

1. **Confirm Installation** — Check version banner:
   ```bash
   claude
   # Should print on stderr: OpenJunto v{version} active — OpenJunto coordination system
   ```
   The banner is emitted by the `SessionStart` hook. It appears on **session start** (startup, resume, `/clear`, compaction) — NOT on `/reload-plugins` or `/plugin reload` (plugin reload refreshes skills/agents/hooks in-process but does not re-fire `SessionStart`). After installing or reloading the plugin, start a new session (or `/clear`) to see the banner. `{version}` is read from the plugin package's `VERSION` file.

2. **Your First Task** — Start with something where multi-perspective review adds obvious value:
   - "Review this file for security issues: src/auth/token_validator.go"
   - Observe: Manager triages, spawns Security Engineer and Distinguished Engineer, synthesizes findings

3. **Understanding Triage** — The system scores requests against 4 criteria:
   1. Spans multiple technical domains?
   2. Regulatory or compliance implications?
   3. Could impact production stability?
   4. Significant cost or resource commitment?

   **Scoring**: 0-1 = Simple, 2-3 = Moderate, 4 = Complex

   **You can override triage** — If Manager over-triages a simple task, push back: "This is a typo fix, just do it."

4. **Stakeholder Selection** — Every task gets Product + Tech minimum. Domain signals add more:
   - Security/compliance → Security Engineer
   - Data modeling → Data Architect
   - Infrastructure/CI/CD → DevOps Engineer
   - ML systems → ML Engineer

5. **Reading Expert Handbacks** — Structure:
   - **STATUS**: Complete / Needs Iteration / Blocked / Escalate
   - **CONFIDENCE**: High / Medium / Low
   - **STRONGEST OBJECTION**: Best argument against the recommendation
   - **FALSIFIER**: Empirical condition that breaks it in production

   Low confidence is valuable signal, not failure.

6. **Common Mistakes**:
   - Over-accepting triage — Don't let Manager over-process simple tasks
   - Ignoring STRONGEST OBJECTION — It's not boilerplate, it's the best counterargument
   - Expecting instant results — Moderate tasks take minutes; process overhead is real

7. **Advanced: Backlog Sprint** — If your project has `.claude/BACKLOG.md`:
   ```bash
   claude '/run-task'
   ```
   Manager picks next item, delegates to experts, enforces peer review, marks done.

8. **Next Steps**:
   - Read WHY.md for tradeoffs
   - Read CONDUCTOR.md for full manager protocol
   - Try `/run-task` on a project with backlog
   - Check `agents/index.md` for expert roster

### Key Requirements

- Walk through first 10 minutes chronologically
- Show expected output at each step
- Include "Common Mistakes" section (prevents early frustration)
- Link to deeper docs (WHY.md, CLAUDE.md) for next level

## Verification

After generating all three files, verify:

1. **README.md**:
   - Installation is plugin-host-mediated (no `make install` — plugin host handles install at user opt-in)
   - Usage examples are concrete (not abstract)
   - Directory structure shows the plugin tree (`agents/`, `templates/`, `skills/`, `reference/`, `CONDUCTOR.md` at plugin root) and the `.claude/` per-project layout
   - Links to WHY.md and onboarding.md

2. **WHY.md**:
   - Problem statement references single-agent blind spots (Axiom 3 from F08-axioms.md)
   - Concrete example (rate limiting scenario) shows what's missed without OpenJunto
   - Tradeoffs table is honest (token cost 2-5x, wall-clock time overhead)
   - "When OpenJunto is NOT worth it" section exists

3. **docs/onboarding.md**:
   - Confirms installation with version banner check
   - First task is concrete and shows triage in action
   - Triage model explained (4 criteria, 0-1/2-3/4 scoring)
   - Common mistakes section exists
   - Links to next steps (WHY.md, CLAUDE.md, agents/index.md)

## Dependencies

This step requires:
- **Prior steps**: 00-06 complete (all spec files exist for reference)
- **External tools**: None

**Next step**: None (documentation is the final step)
