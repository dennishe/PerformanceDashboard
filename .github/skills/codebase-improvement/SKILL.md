---
name: codebase-improvement
description: Explore a codebase to find opportunities for architectural improvement, focusing on making the codebase more testable by deepening shallow modules. Use when user wants to improve architecture, find refactoring opportunities, consolidate tightly-coupled modules, or make a codebase more AI-navigable.
---

# Improve Codebase Architecture

Explore a codebase like an AI would, surface architectural friction, discover opportunities for improving testability, and produce module-deepening refactor RFCs for this repository.

A **deep module** (John Ousterhout, "A Philosophy of Software Design") has a small interface hiding a large implementation. Deep modules are more testable, more AI-navigable, and let you test at the boundary instead of inside.

## Process

### 1. Explore the codebase

Use the Agent tool with the `Explore` subagent to navigate the codebase naturally. Do NOT follow rigid heuristics - explore organically and note where you experience friction:

- Where does understanding one concept require bouncing between many small files?
- Where are modules so shallow that the interface is nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called?
- Where do tightly-coupled modules create integration risk in the seams between them?
- Which parts of the codebase are untested, or hard to test?

The friction you encounter IS the signal.

### 2. Present candidates

Present a numbered list of deepening opportunities. For each candidate, show:

- **Cluster**: Which modules/concepts are involved
- **Why they're coupled**: Shared types, call patterns, co-ownership of a concept
- **Dependency category**: See [REFERENCE.md](REFERENCE.md) for the four categories
- **Test impact**: What existing tests would be replaced by boundary tests

Do NOT propose interfaces yet. Ask the user: "Which of these would you like to explore?"

### 3. User picks a candidate

### 4. Frame the problem space

Before spawning sub-agents, write a user-facing explanation of the problem space for the chosen candidate:

- The constraints any new interface would need to satisfy
- The dependencies it would need to rely on
- A rough illustrative code sketch to make the constraints concrete — this is not a proposal, just a way to ground the constraints

Show this to the user, then immediately proceed to Step 5. The user reads and thinks about the problem while the sub-agents work in parallel.

### 5. Design multiple interfaces

Spawn 3+ sub-agents in parallel using the Agent tool. Each must produce a **radically different** interface for the deepened module.

Prompt each sub-agent with a separate technical brief (file paths, coupling details, dependency category, what's being hidden). This brief is independent of the user-facing explanation in Step 4. Give each agent a different design constraint:

- Agent 1: "Minimize the interface — aim for 1-3 entry points max"
- Agent 2: "Maximize flexibility — support many use cases and extension"
- Agent 3: "Optimize for the most common caller — make the default case trivial"
- Agent 4 (if applicable): "Design around the ports & adapters pattern for cross-boundary dependencies"

Each sub-agent outputs:

1. Interface signature (types, methods, params)
2. Usage example showing how callers use it
3. What complexity it hides internally
4. Dependency strategy (how deps are handled — see [REFERENCE.md](REFERENCE.md))
5. Trade-offs

Present designs sequentially, then compare them in prose.

After comparing, give your own recommendation: which design you think is strongest and why. If elements from different designs would combine well, propose a hybrid. Be opinionated — the user wants a strong read, not just a menu.

### 6. User picks an interface (or accepts recommendation)

### 7. Create local refactor RFC and execution checklist

Create a local RFC document using the template in [REFERENCE.md](REFERENCE.md):

- Path: `docs/rfcs/YYYY-MM-DD-<short-name>.md`
- Include concrete references to current modules in `Sources/` and tests in `Tests/`
- Add a short migration checklist that names call sites to update

Then create implementation tasks in `docs/todo.md`:

- Add 3-8 actionable checklist items under **Active Backlog**
- Scope tasks to an incremental rollout (interface first, migration, cleanup, tests)
- Include boundary-test work and obsolete-test deletion work

After writing the RFC and TODO items, summarize:

1. What new deep module interface was selected
2. Which existing seams/risk it removes
3. Which tests should be added, deleted, or rewritten
4. The exact files edited

Do not require GitHub CLI, issue creation, or external integrations.

## Project adaptation

When applying this workflow in this repo:

- Prefer refactors that reduce complexity in `Sources/Services/` (system API isolation), `Sources/ViewModels/` (data transformation), and `Sources/Shared/` (protocols and mocks)
- Favor actor-safe boundaries and explicit dependency injection via `MetricMonitorProtocol`
- Keep public surfaces small and Swift-native (value types for snapshot data where possible)
- Update and run tests with Swift Package Manager (`swift test`) after implementation work