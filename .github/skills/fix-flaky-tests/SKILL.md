---
name: fix-flaky-tests
description: 'Identify, diagnose, and fix flaky Swift tests. Use when a test passes sometimes and fails others, a test was disabled due to timing, CI fails but locals pass, you want to eliminate Task.sleep timing dependencies, fix shared state races, or repair test isolation in this Swift Testing codebase.'
argument-hint: 'Optional: test name or file path to focus on'
---

# Fix Flaky Tests

## When to Use
- A test fails intermittently (flaky)
- You want to find which tests are likely flaky
- A test is marked `.disabled` due to timing or environment issues
- CI fails on a test that passes locally (or vice versa)

---

## Workflow

### Phase 1 — Detection

**Skip this phase if a specific test is already identified.**

Run the full suite five times and collect failures:

```bash
for i in $(seq 1 5); do
  echo "--- Run $i ---"
  swift test 2>&1 | grep -E "FAILED|error:|✗"
done
```

Note tests that fail on some runs but not others. Those are your candidates.

---

### Phase 2 — Diagnose

Read the failing test file. Match signals against the [root-cause patterns](./references/patterns.md):

| # | Category | Key Signal |
|---|---|---|
| A | Sleep-then-assert | `Task.sleep` / `Thread.sleep` directly before `#expect` |
| B | Shared mutable state | A `var` shared across `@Test` functions without `.serialized` |
| C | Leaked external state | Temp files, global registries not cleaned up between runs |
| D | Detached teardown race | `defer { Task { await x.stop() } }` — teardown races with next test |
| E | NSLock/NSCondition timeout | `.wait(until:)` with a tight deadline (< 100ms) |
| F | Nanosecond serial timing | `Task.sleep(nanoseconds:)` to sequence serial ACK/callback pairs |

For each candidate test, state the category and the specific line(s) causing the problem before proceeding to Phase 3.

---

### Phase 3 — Fix

Apply the fix recipe from [patterns.md](./references/patterns.md) for the diagnosed category.

**Rules:**
- Never remove a test to fix flakiness — fix the root cause
- Never increase `Task.sleep` duration as a fix — replace with event-driven waits
- Preserve existing mock actor interfaces; add capabilities rather than replacing them
- `.serialized` is acceptable when external state (file system, IOKit) is unavoidable, but prefer per-test isolation for pure Swift state

---

### Phase 4 — Verify

1. Run the fixed test five times to confirm stability:
   ```bash
   for i in $(seq 1 5); do
     swift test --filter "<TestName>" 2>&1 | grep -E "PASSED|FAILED|✗|✔"
   done
   ```
2. Run the full suite once: `swift test`
3. Confirm no regressions.
