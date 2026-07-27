---
name: review-loop
description: Gate delivery of significant or explicitly reviewed changes after implementation and ordinary verification. Use for cross-module, stateful, public-interface, shared-configuration, security-sensitive, broad-refactor, or high-regression-risk changes. Orchestrate fresh read-only $adversarial-review passes, safe fixes, and bounded re-verification until Converged, clearly blocked, or user input is required.
---

# Review Loop

Run this as a distinct final pass. The caller is the single writer for loop state, fixes, verification, and transitions; `$adversarial-review` remains read-only and owns review judgment.

## Limits

- A round spans evidence acquisition through result dispatch; any fix or new writeful verification starts a new round.
- Allow at most 7 rounds, 2 fresh reviewer attempts per round, and 2 fixes for the same finding, identified by trigger, affected behavior, and impact.
- Reviewer deadlines are absolute: 180 seconds unless a longer bound is chosen before launch. Polling does not extend them. On timeout, close or terminate the reviewer before replacement; if shutdown is uncertain, stop as blocked.
- Give caller-run verification a bounded deadline chosen before launch. On timeout, stop waiting, preserve raw evidence, and cancel or terminate it when safe. If termination or side-effect state is uncertain, stop as blocked; do not retry under unchanged preconditions.

### 1. Acquire Evidence

- State the goal, success criteria, non-goals, and constraints.
- Capture the complete changeset: staged, unstaged, task-relevant untracked, and applicable base-to-worktree content. For non-Git work, capture complete changed artifacts or equivalent before/after evidence. Use a post-fix delta only as secondary evidence.
- Collect raw verification commands and results, including failures and timeouts. Exclude unrelated user changes explicitly.
- Stop when material ambiguity requires user input or new authority.

### 2. Review

- Start a new reviewer with no parent history (`fork_context=false` or `fork_turns=none` when exposed), require `$adversarial-review`, and keep it read-only. Never reuse the implementer thread, a prior reviewer, or a full-history fork while a clean-context reviewer is available.
- Pass only the goal, criteria, non-goals, constraints, complete changeset, optional latest delta, raw verification, and deadline. Do not pass implementer conclusions, suspected findings, recommended fixes, history, or budgets.
- A valid `Adversarial Review: User decision required` may stop with partial coverage. Otherwise treat timeout, execution failure, contradictory outcome, incomplete scope, or no unique next step as invalid; retry within the limits.
- `Unavailable` means no fresh reviewer can be started or reached. Only after both clean-context attempts are unavailable may the caller perform one disclosed same-context core review as the sole exception to the no-implementer rule; never call it isolated.

### 3. Dispatch

- `Adversarial Review: Converged` and no active material finding or blocking verification: deliver.
- `Adversarial Review: User decision required`: stop and present the decision, evidence, impact, and recommendation.
- Material finding with a safe local in-scope fix: mark active and continue to Fix.
- Material finding without such a fix: stop as blocked; report evidence, impact, and recommended direction without broadening scope.
- Requested verification that is safe and not equivalent to existing evidence: run it, record raw results, and start a new round.
- Preserve reviewer dispositions for tradeoffs and non-material findings; do not put them in the fix loop.

### 4. Fix

- Apply only confirmed, recommended, authorized, in-scope fixes.
- Run bounded risk-proportionate verification, preserve failed or inconclusive evidence, then start a new round from the complete changeset.
- Resolve a finding only when a complete later review no longer reports it and applicable independent verification confirms its trigger is gone.

## Stop

- Stop on user decision, new authority, unsafe verification, exhausted limits, repeated failure, oscillation, reintroduction, or invalid review.
- Report evidence, impact, attempted actions, and the recommended next step.
- Never turn incomplete review, passing tests, low time, or exhausted budget into `Converged`; never override reviewer disposition or unsupported blocking verification.
