---
name: dry-report
description: 'Navigate a codebase with multiple parallel agents to find DRY violations, repeated patterns, copy-paste code, clunky solutions, and inelegant code. Produces an RFC report documenting all issues. Use when: code quality audit, finding duplication, repeated logic, ugly code, refactoring candidates, DRY audit, elegance review, codebase cleanup, copy-paste code, verbose patterns.'
argument-hint: 'Optional: scope or focus area (e.g. "Sources/Services" or "ViewModels")'
---

# DRY Report

A codebase quality audit that hunts for DRY violations, repeated patterns, inelegant solutions, and clunky code — then writes an RFC report ranking every issue by severity. The report is not a refactoring plan; it is a structured inventory that lets you decide what to fix and in what order.

## When to Use

- Code has grown organically and you suspect hidden duplication
- You want a structured list of refactoring candidates before a cleanup sprint
- You want to produce an RFC for team review or self-directed cleanup
- Someone says: "find repeated patterns", "find ugly code", "DRY audit", "code quality report"

## Output

An RFC saved to `docs/rfcs/YYYY-MM-DD-dry-report.md`. If the folder does not exist, print the report in chat instead. After saving, display:
1. An executive summary (total issues per severity)
2. The 3 most impactful issues
3. A question: "Want to start fixing any of these now?"

---

## Procedure

### Step 1 — Orient

Before dispatching agents, read:

- `Package.swift` — understand modules and targets
- Top-level `Sources/` directory listing — note module names and sizes
- Any architecture docs in `.github/` (e.g. `copilot-architecture.md`, `copilot-conventions.md`)

If an argument was provided (e.g. `"Sources/Services"`), scope all agents to that path. Otherwise, scope to all `Sources/` and `Tests/` directories.

---

### Step 2 — Parallel Agent Dispatch

Launch **5 agents in parallel** using the `Explore` subagent. Give each agent a distinct smell category and the scope constraint. Ask each for **file paths, line ranges, and a brief description** for every finding. Thoroughness: **thorough**.

#### Agent A — Structural Duplication

Hunt for:
- `struct` or `class` definitions sharing 3+ identical stored properties
- Parallel enum types with the same associated value shapes (e.g. two enums both wrapping a `nodeId` + `value`)
- Near-identical `Codable` `encode`/`decode` or `init(from:)` implementations
- Protocol conformances copy-pasted across types that could be default implementations on the protocol

#### Agent B — Logic Duplication

Hunt for:
- The same `switch` over the same enum appearing in 2+ different files
- Copy-paste `if-else` chains that differ only in constants or type names
- Helper functions with identical or near-identical bodies defined independently in more than one file
- Repeated guard/validation blocks (e.g. "check node is awake", "check security class") that could be extracted

#### Agent C — Constant & Literal Duplication

Hunt for:
- Magic numeric values (percentages, byte counts, durations) hard-coded in 3+ places
- Repeated string literals (error messages, log tags, accessibility labels) that should be constants
- Duplicated threshold values (`0.8`, `0.9`, etc.) scattered as literals instead of using the `Threshold` enum
- Repeated polling interval or timeout values scattered as literals instead of using `Constants.swift`
- Duplicated `ByteCountFormatter` or `NumberFormatter` setup across multiple files

#### Agent D — Verbose & Inelegant Code

Hunt for:
- Functions longer than ~60 lines that do two or more conceptually distinct things
- `if let x = x { return x } else { return nil }` style patterns instead of `map` / `??`
- Manual `for` loops where `map`, `filter`, `compactMap`, or `flatMap` would be clearer
- Parameter lists of 5+ items that should be grouped into a value type
- `Bool` parameters that gate two distinct code paths (should be an enum)
- Force-unwraps (`!`) where a safe pattern is obvious and the crash risk is real
- Nested closures deeper than 3 levels where async/await or decomposition would help

#### Agent E — Abstraction Smells

Hunt for:
- Protocols with exactly one conformer (over-abstraction with no payoff)
- Delegate patterns that could be a single closure or `async`/`await`
- Base classes used only for code sharing (composition would be cleaner)
- Thin wrapper types that add ceremony without hiding any complexity
- Error types with a single case (just use a concrete type or `Error`)
- Repeated ad-hoc state machines (e.g. manual `isConnecting`/`isConnected`/`isFailed` Bool triplets) that should be a typed enum

---

### Step 3 — Collate & Deduplicate

After all 5 agents return:

1. Merge findings. If two agents flagged the same file and line range, keep one entry and note both smell categories.
2. Assign severity:

| Severity | Criteria |
|----------|----------|
| **Critical** | Verbatim or near-verbatim code block duplicated in 3+ places; any change must be made N times |
| **High** | Logic or structure repeated in 2+ places with a clear extraction target |
| **Medium** | Verbose or inelegant; extractable but lower urgency |
| **Low** | Minor style inconsistency; optional cleanup |

3. Count totals per severity level for the executive summary.

---

### Step 4 — Write the RFC

Save to `docs/rfcs/YYYY-MM-DD-dry-report.md`. Use today's date.

```markdown
# RFC: DRY & Elegance Audit — YYYY-MM-DD

## Status
Draft

## Summary

<Scope audited. Total issues: N critical, N high, N medium, N low. Top themes in 1–3 sentences.>

---

## Issues

### Critical

#### [C1] <Short descriptive title>
- **Smell**: Structural Duplication / Logic Duplication / ...
- **Files**:
  - `Sources/Foo/Bar.swift` lines 12–45
  - `Sources/Baz/Qux.swift` lines 78–111
- **Problem**: <1–2 sentences. Include a short inline code excerpt if it makes the issue clearer.>
- **Suggestion**: <Extract into / Replace with / Move to — high-level only, no implementation.>

#### [C2] ...

---

### High

#### [H1] ...

---

### Medium

#### [M1] ...

---

### Low

#### [L1] ...

---

## Recommended Action Order

1. [C1] — <reason it should go first>
2. [C2] — ...
3. [H1] — ...
...

## Out of Scope

<List any modules, directories, or smell categories not examined, and why.>
```

---

### Step 5 — Report Back

After saving the RFC:

1. Print the executive summary table to chat (severity → count)
2. Call out the 3 most impactful issues with a one-liner each
3. Ask: "Want to start fixing any of these now, or run a deeper audit on a specific area?"
