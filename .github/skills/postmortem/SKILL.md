---
name: postmortem
description: Run a post-fix postmortem that determines whether a bug was enabled by an architectural issue, then turn the findings into concrete prevention work for this repository.
---

# Postmortem

Use this skill after a bug has been fixed. The goal is not just to explain the defect, but to determine whether the bug was enabled by a structural weakness in the codebase and define the smallest concrete changes that reduce recurrence risk.

## Project adaptation

This repository has several risk-heavy boundaries:

- service-layer system API calls in `Sources/Services/` (IOKit, Mach kernel, `getifaddrs`)
- actor isolation and `@MainActor` / `MonitorActor` boundaries in ViewModels and services
- `MetricMonitorProtocol` conformance and mock substitution in `Sources/Shared/`
- regression coverage and boundary seams in `Tests/PerformanceDashboardTests/`

The postmortem must be specific to those boundaries. Avoid generic incident language when the source evidence is in code, tests, actor isolation, dependency shape, system API access, or entitlement semantics.

## Operating mode

1. Start from the fix, not from speculation. Identify the changed code, affected tests, and the observed failure mode.
2. Reconstruct the failure path from evidence in source, tests, logs, RFCs, or repository memory.
3. Decide whether the bug was:
   - a local implementation mistake, or
   - enabled by a structural issue that made the mistake likely, hard to notice, or hard to test
4. If structural factors exist, classify them and explain why the current design allowed the bug through.
5. Convert findings into concrete prevention work: tests, boundary changes, deeper modules, ownership cleanup, diagnostics, or RFC/todo follow-up.
6. End with a concise written postmortem and explicit next actions.

## Structural issue tests

Treat the bug as structurally enabled when one or more of these are true:

1. Understanding the broken behavior requires jumping across too many files or layers.
2. A concept has split ownership across modules, actors, adapters, or command handlers.
3. The public interface exposes coordination details instead of hiding them.
4. The fix depends on restoring an invariant that was never encoded in one clear place.
5. The failure crossed concurrency, persistence, or environment boundaries with weak guarantees.
6. Existing tests only covered helpers or fragments, not the real behavioral boundary.
7. A caller had too much freedom to assemble an invalid state or sequence.

If none of those hold, classify the issue as a local defect and avoid inventing architecture work.

## Structural categories

When a structural contributor exists, classify it using the closest category:

1. Responsibility boundary failure: one concept has multiple owners.
2. Shallow module: interface and implementation complexity are nearly the same.
3. Missing invariant owner: no single type/module enforces the rules.
4. Concurrency boundary weakness: actor isolation, ordering, cancellation, or reentrancy was unclear.
5. Persistence or I/O boundary weakness: storage, file updates, or serialization semantics were unsafe or ambiguous.
6. System API boundary weakness: IOKit, Mach, or network interface APIs used without proper error handling or entitlement gating.
7. Test seam mismatch: tests validate pieces, but not the boundary where the defect actually happened.
8. Observability gap: logs, diagnostics, or assertions were too weak to localize the issue quickly.

## Workflow

### 1. Gather evidence

Read the fix and supporting context first. Prefer these sources:

- edited files in `Sources/` and `Tests/`
- relevant failing or newly added tests
- `docs/rfcs/` records related to the area
- repository memory files under `/memories/repo/` when they match the subsystem

Capture:

- the user-visible symptom
- the exact code path that produced it
- what changed to fix it
- what test or validation now proves the fix

### 2. Reconstruct the failure path

Write a short causal chain in code terms, not vague prose:

1. trigger
2. state or input assumption
3. boundary crossing
4. incorrect behavior
5. why the system failed to prevent or detect it earlier

If the code path is uncertain, inspect more source before concluding.

### 3. Classify local vs structural

Ask: if a competent engineer made a small mistake here, did the architecture make that mistake unusually easy to introduce or miss?

- If no: classify as `local defect`.
- If yes: classify as `structurally enabled defect` and name the category.

### 4. Identify the prevention layer

Pick the smallest prevention change that addresses recurrence risk at the right layer:

- add or strengthen a regression test at the real boundary
- move invariant enforcement into one owning type or module
- reduce protocol/environment surface area
- consolidate orchestration hidden behind a deeper module
- add assertions, diagnostics, or logging at the boundary
- create follow-up refactor work when the fix exposed a broader design flaw

Do not default to broad rewrites. Favor narrow, defensible prevention work.

### 5. Decide required follow-up artifacts

Use this branching logic:

- Always create a postmortem note at `docs/postmortems/YYYY-MM-DD-<short-name>.md`.
- If the issue is local and fully contained: keep the postmortem narrow and add the minimum regression test or assertion follow-up if still missing.
- If the issue reveals a subsystem design weakness but not a large redesign: add a small actionable follow-up to `docs/todo.md` and identify the exact files likely to change.
- If the issue exposes a meaningful architectural weakness: create a local RFC in `docs/rfcs/YYYY-MM-DD-<short-name>.md` and add actionable checklist items to `docs/todo.md`.

### 6. Validate completeness

Before finishing, verify that the postmortem answers all of these:

1. What failed?
2. Why did it fail in code terms?
3. Why was it not prevented earlier?
4. Was the cause local or structural?
5. What concrete change best reduces recurrence risk?
6. What test or validation proves the system is now safer?

## Output format

Produce the postmortem in this order:

1. `Issue`: one-sentence statement of the bug and affected behavior.
2. `Evidence`: relevant files, tests, and observed behavior.
3. `Failure path`: concise causal chain.
4. `Classification`: `local defect` or `structurally enabled defect` plus category.
5. `Structural assessment`: what in the design contributed, or a brief statement that no structural contributor was found.
6. `Prevention`: the minimum high-leverage follow-up.
7. `Validation`: tests run or evidence that should be collected.
8. `Artifacts created`: postmortem document path, plus RFC/todo updates when warranted.
9. `Next actions`: concrete file-level follow-ups.

## Codebase-first behavior

When running this skill:

- inspect code before asking the user for facts that are already in the repo
- prefer repository memory when prior analysis already exists for the subsystem
- cite exact workspace files and lines when presenting conclusions
- avoid generic retrospectives detached from code structure

## Quality bar

The skill is complete only when:

1. the root cause is explained in source-level terms
2. the structural classification is explicitly justified
3. the prevention work is proportional to the evidence
4. tests or validation are named clearly
5. a postmortem note is written to the repository
6. any architectural follow-up is translated into a concrete RFC and/or todo work item when needed