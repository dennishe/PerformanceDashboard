---
name: code-coverage-improvement
description: Improve test coverage by running coverage analysis, identifying uncovered files with a sub-agent, then implementing tests with parallel sub-agents. Use when user wants to improve code coverage, add missing tests, find untested files, or raise coverage percentage.
---

# Code Coverage Improvement

Run the coverage report, identify the worst-covered files, and write tests to improve them. Analysis and implementation run in separate sub-agents.

## Process

### 1. Generate the Coverage Report

Use `create_and_run_task` to run coverage as a VS Code task so the output appears in the Task panel:

- **label**: `Generate Coverage Report`
- **type**: `shell`
- **command**: `swift test --enable-code-coverage 2>&1 && xcrun llvm-cov report .build/debug/PerformanceDashboardPackageTests.xctest/Contents/MacOS/PerformanceDashboardPackageTests -instr-profile .build/debug/codecov/default.profdata`

This produces a per-file line coverage table. Pipe the output to a file for easier reading:
```bash
swift test --enable-code-coverage 2>&1
xcrun llvm-cov report .build/debug/PerformanceDashboardPackageTests.xctest/Contents/MacOS/PerformanceDashboardPackageTests \
  -instr-profile .build/debug/codecov/default.profdata > coverage.txt
```

If the user specifies a target threshold (e.g., "get everything above 80%"), record it. Default: focus on files below **80% line coverage**, prioritizing those with **0–60%**.

### 2. Read the Report

Read the coverage output after the command completes. Extract the bottom N files (typically bottom 10–15) to build the candidate list. Focus only on files under `Sources/Services/` and `Sources/ViewModels/` — skip `Sources/Views/` (SwiftUI UI files).

Do NOT proceed if coverage output is missing or empty. Check for build errors first.

### 3. Spawn an Analysis Sub-agent

Delegate analysis to a **read-only Explore sub-agent**. Do NOT read the source files yourself.

Provide the sub-agent with:
- The list of candidate files and their coverage percentages
- The full path to each file
- Links to relevant test files already in `Tests/PerformanceDashboardTests/`

Ask the sub-agent to return, for each candidate file:
1. What the file does (one sentence)
2. Which public types, methods, or code paths are likely uncovered
3. Which test file to add tests to (or whether a new test file is needed)
4. Which test pattern to use (mock service via `MetricMonitorProtocol`, direct service instantiation, `AsyncStream` snapshot injection)
5. An estimated difficulty: `easy` / `medium` / `hard`

Present the analysis to the user as a prioritized table. Ask: "Which files would you like to target? Or should I proceed with all easy and medium ones?"

### 4. Group into Implementation Batches

Group the selected files into **independent batches**. Aim for 2–4 batches.

**Hard rule: each batch must write to a distinct set of test targets.** No two batches may touch the same test file. This keeps diffs clean and eliminates merge conflicts when applying sub-agent results.

- Files that need the same test file must either go in the same batch, or have their additions sequenced (one batch at a time).
- If two files both belong in `CoreTests.swift` and together they exceed a comfortable batch size, split them by keeping them in the same batch rather than splitting across batches.
- Do NOT batch files from different test targets together just because they share a pattern — test target is the primary grouping key.

If it is unclear which test file a source file should map to, use `vscode_askQuestions` to ask the user before proceeding.

After finalising the batches, publish a `manage_todo_list` task list — one item per batch — so the user can see which files are in each batch and track progress as sub-agents complete:

- Mark each batch `not-started` before spawning sub-agents
- Mark a batch `in-progress` immediately when its sub-agent is launched
- Mark a batch `completed` as soon as its edits are applied

### 5. Spawn Implementation Sub-agents in Parallel

Spawn one sub-agent per batch using the `Agent` tool. Each sub-agent must:

1. Read the source file(s) in its batch
2. Read the corresponding existing test file (if any)
3. Write concrete tests using the project's Swift Testing framework (`@Test`, `#expect`)
4. Follow the existing test file style and Swift Testing conventions for this project
5. Return the exact file path edited and a summary of tests added

**Critical constraints for each sub-agent:**
- Use `@Test("descriptive name")` — never XCTest
- Use `#expect(...)` and `Issue.record(...)` — never `XCTAssert`
- For ViewModel tests: inject mock services via `MetricMonitorProtocol` (see `Sources/Shared/Mocks/MockMonitors.swift`)
- Do NOT add `import XCTest` anywhere
- Match the indentation and style of the existing test file

### 6. Apply the Edits

After all sub-agents complete, apply their results. Because each batch targets a distinct test file, no merging should be required. If a collision is detected anyway, do NOT silently merge — use `vscode_askQuestions` to surface the conflict and ask the user how to proceed.

### 7. Validate

Run the tests to confirm nothing is broken. Use `create_and_run_task`:

- **label**: `Run Tests`
- **type**: `shell`
- **command**: `swift test 2>&1 | tail -30`

If tests fail, diagnose before re-running. Do not retry a failing test without understanding the error.

### 8. Re-run Coverage and Report Delta

After tests pass, re-run coverage using `create_and_run_task` again (same label as Step 1 — reuse the existing task if already created).

Compare the new output against the old one. Render a `renderMermaidDiagram` showing the before/after delta for each improved file:

```
xychart-beta
  title "Line Coverage Delta"
  x-axis [file1, file2, ...]
  y-axis "Coverage %" 0 --> 100
  bar [before_pct, ...]
  bar [after_pct, ...]
```

Also summarise in prose:
- Files improved and their new coverage %
- Overall line coverage before → after
- Files that still need attention

Update repository memory under `/memories/repo/` with any new patterns discovered or files brought to high coverage.

## Project-specific notes

- Test files live in `Tests/PerformanceDashboardTests/` and mirror the source tree
- Service tests go in `Tests/PerformanceDashboardTests/Services/`
- ViewModel tests go in `Tests/PerformanceDashboardTests/ViewModels/`
- Shared/protocol tests go in `Tests/PerformanceDashboardTests/Shared/`
- New test files are automatically discovered — no registration needed in `Package.swift`
- `Views/` files (SwiftUI) are excluded from coverage targets — skip them
- Service tests must not call real system APIs; mock or stub all `MetricMonitorProtocol` implementations

## Coverage thresholds guide

| Coverage | Priority |
|----------|----------|
| 0–40%    | Critical — address first |
| 40–70%   | High     |
| 70–85%   | Medium   |
| 85–100%  | Low / polish |
