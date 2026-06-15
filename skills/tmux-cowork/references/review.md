# review flow (adversarial code review)

Run one round of **adversarial** structured review between a primary agent and an independent reviewer agent. The value is in countering the two default failure modes of LLM-to-LLM review: the reviewer tends to rubber-stamp, the primary tends to defend. Use structure and guardrails to force evidence-backed findings and an honest wrap-up.

## Relation to the protocol

review is not a separate message format but a body convention for `mode: review`: by default each artifact = one tmux-cowork message, with the outer envelope following SKILL.md "Message format".

- Envelope reuse: write the review goal in `goal`, the review object in `topic`, and the round in `turn` — these are **not repeated in the body**.
- The body (after `--------`) holds only review-specific fields the protocol does not have, using the same lowercase `key: value` plus blank-line separation.
- review = `discuss` flow plus a structured body, with the primary as `original`; for turn / exit / cap see "Multi-round contract", for addressing (to/from swap) see "Receiver flow", and for delivery see "Send and confirm".
- transport: tmux-cowork by default (two agent panes); with no second pane, run inline — the primary produces the Packet for the user to pass to the reviewer, waits for the user to paste back the Findings, and reuses the same structured artifacts. In any form, the primary's self-review must not stand in for an independent reviewer.
- roles: the primary holds the change and starts the review; the reviewer is read-only by default (no file edits / no stage / no commit) unless the user explicitly asks for a patch.

| Artifact         | mode   | turn |
|------------------|--------|------|
| Review Packet    | review | 1    |
| Findings         | review | 1    |
| Resolution Notes | review | 2    |
| re-review        | review | 2    |
| Consensus label  | final  | 2    |

> The table above is the **typical 2-round** path. When the Findings clearly state `no blocking findings`, the primary may wrap up right after turn 1 (`Consensus` or `Consensus with residual risks`), skipping Resolution / re-review; with a Medium+ finding, go through Resolution / re-review, looping unresolved items by turn until `original` judges convergence or `turn` hits the hard cap `10` — wrap up early when you can.

## When to use

- Run it only when there is a concrete review object (diff / patch / changed files / design doc / test artifact).
- For a tiny local change, just self-check; do not wrap it in a review loop.
- Open discussion / brainstorming with no concrete artifact uses `mode: discuss` and is not `review`.

## Full example (turn 1 · Review Packet)

A complete review message looks like this; the body templates below give only the segment after `--------`.

```text
[tmux-cowork] Please handle this message with the tmux-cowork skill, following the mode/expect contract.
to: %5
from: %3
original: %3
mode: review
turn: 1

topic: auth middleware patch
goal: confirm the patch implements session validation correctly with no regression; reach consensus or converge to bounded risk
expect: reply with Findings (mode: review, same format, keep topic / goal / original / turn)

context: rewriting auth middleware; legal requires changing how the session token is stored

--------

scope: correctness / security / regressions
changed files: src/auth/mw.ts (validation rewrite), src/auth/store.ts (token storage)
diff source: git diff main...HEAD
tests run: pnpm test auth — pass; e2e not run (no staging)
known unverified: concurrent token-refresh path untested
behavior changed: session validation failure now returns 401 (was 500)
```

## body templates

A `finding` id (such as `F-001`) stays the same across Findings, Resolution, and re-review.

### Review Packet (turn 1, primary → reviewer)

The primary summary does not replace diff/test evidence; when the diff is large, give an artifact link / file list / minimal snippets, and do not paste noisy scrollback.

```text
scope: <focus among correctness / security / regressions / tests / API contract / maintainability>
changed files: <path + one line on its role>
diff source: <git diff / patch / explicit snippets / artifact path>
tests run: <command + pass/fail; if not run, write not run + reason>
known unverified: <unverified paths / environment limits / missing tests / assumptions>
behavior changed: <user-visible or API-visible change>
```

### Findings (turn 1 reply, reviewer → primary)

Sorted by severity, one block each, blank-line separated; anything without trigger+evidence is downgraded to a residual risk. re-review reuses the `finding` id and adds `status: confirmed-fixed | still-open | withdrawn | escalated`, without renumbering.

```text
finding: F-001
severity: Critical | High | Medium | Low
trigger: <the condition or code path that triggers the problem>
evidence: <file / function / line / diff hunk / command output / observable behavior>
impact: <what breaks, who is affected, why it matters>
fix: <the narrowest fix>
confidence: High | Medium | Low

no blocking findings: <only when there is no Critical/High/Medium>
residual risks: <unverified areas / missing tests / low confidence>
```

### Resolution Notes (turn 2, primary → reviewer)

Respond item by item, once per finding; for needs-discussion raise just one narrow question.

```text
finding: F-001
decision: accept | reject | needs-discussion
reason: <why this decision is right>
action: <patch / test / doc, or none>
verification: <command/test/evidence, or not run + reason>
residual risk: <remaining risk, or none>
```

### Consensus label (wrap-up · mode: final)

Sent by the primary (= `original`) after receiving the re-review: the primary decides exit (exit criteria in "Multi-round contract"), **mechanically maps** the label from the finding severity and status the reviewer gave, with no discretion, and organizes it for the user; the reviewer does not switch to `final`.

- `Consensus`: all blocking findings are `confirmed-fixed` / `withdrawn`, verification has run or there is sufficient alternative evidence, and there is no residual risk.
- `Consensus with residual risks`: all blocking findings cleared, but there remain unrun tests / low-confidence areas / environment limits / an unfixed Low finding.
- `No consensus / user decision needed`: a blocking (Medium+) finding is still `still-open` / `escalated`, or there is a material risk that cannot be converged with evidence within the hard cap `10`.

## Guardrails

- The reviewer must not rubber-stamp, must not raise an abstract concern without trigger+evidence, and must not bypass the `finding` id to edit code directly.
- The primary must not hide unrun tests / known failures; with an unresolved blocking (Medium+) finding it must not claim `Consensus`, and with an unverified risk it may only use `Consensus with residual risks`.
- If any stage is missing a mandatory artifact: ask for it or downgrade the final state; do not treat the primary summary as complete evidence.
