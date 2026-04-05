---
name: instruments-profile
description: 'Record an Instruments Time Profiler trace with xctrace, export the call stacks, and normalize the result into an LLM-friendly hotspot summary. Use when the user wants Copilot to take the profile directly, analyze a .trace file, massage a huge Instruments call tree, inspect SwiftUI or AppKit hotspots, or profile PerformanceDashboard from the terminal.'
argument-hint: 'attach <process-or-pid> | launch -- <command> | summarize <trace-path>'
---

# Instruments Profile

Capture a Time Profiler trace with the Instruments CLI, then convert the exported call stacks into a short summary that is much easier to analyze than the raw call tree dump.

Use the wrapper script first:

- [./scripts/time_profiler.sh](./scripts/time_profiler.sh)

The wrapper records a trace with `xcrun xctrace`, then runs the normalizer:

- [./scripts/summarize_time_profile.py](./scripts/summarize_time_profile.py)

## When to Use

- The user asks to profile the app from chat instead of opening Instruments manually
- The user shares a `.trace` file or a very large call tree dump
- The user asks for help with `Instruments`, `xctrace`, `Time Profiler`, `call tree`, `hotspots`, or `performance profiling`
- You need a trimmed summary that emphasizes app-owned frames and suppresses framework noise

## Procedure

1. Decide whether to attach to an existing process, launch a command, or summarize an existing `.trace`.
2. Default to `Time Profiler` and a `10s` capture unless the user asks for something else.
3. Prefer `attach` if the app is already running. Prefer `launch` if you need to start it from scratch.
4. Read the generated markdown summary before reading the raw XML or a giant call tree.
5. Use the raw `.trace` only if you need UI drill-down inside Instruments.app.

## Commands

Attach to a running process:

```bash
./.github/skills/instruments-profile/scripts/time_profiler.sh attach PerformanceDashboard --time-limit 15s
```

Launch the app binary and profile it. Always build first, then launch from inside the staging bundle — **never use `swift run`** and **never launch the bare `release/` binary** (see Notes):

```bash
swift build -c release
./.github/skills/instruments-profile/scripts/time_profiler.sh launch --focus-process PerformanceDashboard --time-limit 15s -- .build/staging/PerformanceDashboard.app/Contents/MacOS/PerformanceDashboard
```

Summarize an existing trace without recording a new one:

```bash
./.github/skills/instruments-profile/scripts/time_profiler.sh summarize /path/to/profile.trace
```

## What the Summary Contains

- Trace metadata: template, duration, target process, run number
- Top sampled threads
- Top feature groups attributed to dashboard layout, metric tile text/layout, ring gauges, sparklines, and polling services when those symbols are present
- Top app-owned hotspots by inclusive and self time
- Top overall hotspots when app-owned frames are not enough
- Representative call paths trimmed around the hot frame instead of the full run-loop stack

## Notes

- `xctrace` can exit non-zero even when it successfully writes a trace bundle. If the output `.trace` exists, treat that as success and continue.
- The generated summary is optimized for LLM analysis, not exact parity with the Instruments UI call tree columns.
- Use the summary as the input to code review or optimization work, then open the `.trace` in Instruments only for fine-grained inspection.
- **macOS 26 / Instruments 26 deferred-mode limitation.** Time Profiler uses deferred recording; the `time-profile` export table (symbolicated call tree) is left empty and only populated when the trace is opened in Instruments.app. The raw stackshots are in the `time-sample` schema as unsymbolicated PC addresses. If the summarizer reports "*N raw stackshots found in time-sample schema*", open the `.trace` file in Instruments.app to view the full symbolicated profile.
- **Never pass `swift run -c release` as the launch command.** SPM stages the binary to `.build/staging/PerformanceDashboard.app` and exec's into it; xctrace follows the exec under `ptrace` and leaves the staged app SIGSTOP'd when the trace ends. The result is an orphaned process in state `T` and an empty time-profile table.
- **Never launch the bare `.build/release/PerformanceDashboard` binary.** AppKit detects it is running outside a bundle and re-execs into the co-located `.build/staging` app — producing two processes, only one tracked by xctrace. Always launch from inside the staging bundle: `.build/staging/PerformanceDashboard.app/Contents/MacOS/PerformanceDashboard`. Build first with `swift build -c release` (SPM updates the staging bundle automatically).
- **`launch` mode auto-kills both orphaned processes** after the trace ends: the directly-launched binary tracked by xctrace (via TOC PID), and the re-exec'd staging-bundle copy that macOS/AppKit spawns when it finds the co-located `.build/staging` app bundle (this second process is never tracked by xctrace). If a stopped (`T`) `PerformanceDashboard` process remains, run `kill -CONT <pid> && kill -TERM <pid>` manually.