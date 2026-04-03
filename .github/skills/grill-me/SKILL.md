---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview the user relentlessly about every aspect of their plan until you reach shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

If a question can be answered by exploring the codebase, explore the codebase instead.

## Project context

This project is a macOS performance dashboard in Swift/SwiftUI, using MVVM + a service layer. Services read system APIs (IOKit, Mach kernel, `getifaddrs`, etc.) on a background `MonitorActor` and deliver values via `AsyncStream` to `@Observable` ViewModels on `@MainActor`. The most useful grilling is not generic: it must stress-test actor boundaries, `MetricMonitorProtocol` surface design, service isolation, concurrency safety, and test strategy.

## Operating mode

1. Start by restating the plan in one sentence and naming the top 3 unknowns.
2. Ask one high-leverage question at a time using the VS Code Ask Questions UI (`vscode_askQuestions`).
3. After each answer, either:
	- Ask the next dependency question, or
	- Explore the codebase when the answer should be derivable from source.
4. Continue until each branch is resolved or explicitly parked as a risk.
5. End with a concise decision record: decisions made, risks accepted, and next implementation step.

## Ask Questions UI requirements

- Use `vscode_askQuestions` for user prompts instead of plain chat questions.
- Prefer one-question prompts for dependency-critical decisions.
- Use multi-question batches (2-3 max) only when questions are independent.
- Use `options` for constrained architectural choices when possible.
- Enable `allowFreeformInput` when nuance is likely required.
- After each response, summarize the resolved decision in chat and identify the next branch.

## Branches you must cover

For architecture/refactor plans in this repo, always walk these branches:

1. Responsibility boundary: what single concept is owned by the proposed module/service/actor?
2. Interface depth: can the public surface be reduced while hiding more internal coordination?
3. Concurrency model: actor isolation, `@MainActor` vs `MonitorActor`, async call graph, cancellation, and reentrancy risks.
4. Dependency strategy: injected `MetricMonitorProtocol` vs direct concrete coupling.
5. System API boundary: which system API (IOKit, Mach, `getifaddrs`, etc.) is called and where — is it properly isolated behind the service layer?
6. Mock strategy: can the service be replaced with a `Mock*Monitor` for tests and previews without changing callers?
7. Failure semantics: how errors and degraded values propagate (e.g. unavailable IOKit service, missing entitlement).
8. Test migration: which boundary tests are added and which shallow tests should be removed.
9. Rollout plan: incremental migration steps and fallback behavior.

## Codebase-first behavior

When uncertain, inspect code before asking. Prioritize reading:

- `Sources/Services/` for system API access and service isolation boundaries
- `Sources/ViewModels/` for data transformation and `@Observable` state
- `Sources/Shared/Protocols/` for `MetricMonitorProtocol` and related contracts
- `Sources/Shared/Mocks/` for mock implementations used in tests and previews
- `Tests/PerformanceDashboardTests/` for current testing seams and likely rewrite targets

When you discover evidence, cite exact files and lines in the response and convert assumptions into facts.

## Question quality bar

Questions should be:

- Binary or tightly scoped when possible
- Ordered by dependency (do not ask downstream questions early)
- Explicit about trade-offs being decided
- Grounded in current code, not hypothetical architecture trends

Avoid broad prompts like "any concerns?" or "what do you prefer?" without constraints.

## Output format while grilling

For each turn, provide:

1. Current branch being resolved
2. One question (or one fact found from code exploration)
3. Why this branch blocks downstream decisions

When complete, provide:

1. Final design decisions
2. Open risks and mitigations
3. Concrete implementation order
4. Test updates required (`swift test` validation path)