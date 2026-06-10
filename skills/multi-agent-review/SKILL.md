---
name: multi-agent-review
description: 用于在 tmux panes、TUI sessions 或 inline handoffs 中协调 primary agent 和 reviewer agent 进行结构化 code review、讨论 review comments、处理 findings，并达成 consensus。Use when the user asks one agent to ask another agent to review work, resolve findings, or reach consensus between agents. For lightweight agent messaging without the review-loop structure, use tmux-pane-collab.
---

# Multi-Agent Review

## 适用范围

使用这个 skill 来运行 primary coding agent 与 independent reviewer agent 之间的结构化 review loop。

这个 skill 负责：
- 从代码变更、测试结果和已知风险中整理简洁的 Review Packet
- 通过 tmux panes、TUI sessions 或 inline handoff 发送 review request
- 要求 reviewer 输出 evidence-backed Findings
- 驱动 primary agent 按稳定 Finding ID 逐条处理每个 finding
- 运行有边界的 re-review loop，直到 fixed final status 或明确的 residual risk

这个 skill 不负责：
- 没有具体 work product 的泛泛 multi-agent brainstorming
- 缺少 evidence、impact 和 decision point 的开放式争论
- 没有 diff、artifact、design doc 或其他具体 review object 的 review loop
- 在用户没有明确要求 subagents 或 delegated agent work 时自行 spawn subagents
- 在用户没有明确要求时执行 destructive git operations

把 tmux 当作 transport 和 observation layer。真正的 source of truth 是结构化 handoff：Review Packet、Findings、Resolution Notes 和最终 consensus。

Reviewer 默认 read-only。除非用户明确要求 reviewer patch，否则 reviewer 只读 diff、文件、测试输出和 artifacts，不修改 workspace、不 stage、不 commit。

## Architecture Gate

Minimal core：workflow 可以只靠 plain text handoffs 运行，不依赖 tmux、scripts 或特定 agent TUI。

Optional transport adapters：
- tmux pane handoff
- inline copy/paste handoff
- external agent session handoff

Dataflow State Machine：

| State        | Owner    | Reads                              | Writes                                  | Failure path                  |
|--------------|----------|------------------------------------|-----------------------------------------|-------------------------------|
| ScopeGate    | primary  | user goal, artifact availability   | review mode decision                    | abort missing artifact        |
| ReviewPacket | primary  | diff, files, tests, user scope     | mandatory artifacts, optional context   | request missing evidence      |
| Findings     | reviewer | review request, direct evidence    | ID-based severity-ranked findings       | request corrected findings    |
| Resolutions  | primary  | findings, code, tests              | ID-based decision/status records        | escalate unsupported reject   |
| ReReview     | reviewer | resolutions, changed evidence      | confirmed/disputed/withdrawn statuses   | stop after two rounds         |
| FinalStatus  | primary  | confirmed resolutions, risks       | fixed final status label and summary    | list residual risks           |

Interaction Lifecycle：
- init：识别 primary、reviewer、transport、pane refs（如果有）和 review scope。
- start：创建并发送 Review Packet。
- stop：当所有 findings 都被 accepted、带 evidence rejected，或作为 residual risk escalated 时停止。
- dispose：留下简洁 final record；不要为这个 workflow 保留后台 agent sessions。

Interface contract：
- Input：changed work product、user goal、review scope、mandatory artifacts、可选 tmux pane refs。
- Output：`Consensus`、`Consensus with residual risks` 或 `No consensus / user decision needed`，以及简洁 review record。
- Errors：missing pane、missing artifact、missing diff、unclear scope、reviewer output without Finding ID or evidence。
- Timeout：如果 reviewer 不响应，或 discussion 超过两轮，报告当前状态并请用户决定。

## Workflow

1. Identify roles and transport。
- Primary 负责 implementation 和最终 resolution。
- Reviewer 独立检查 correctness、security、regressions、tests 和 maintainability risks。
- 如果用户提供了 tmux pane refs，用 `tmux-pane-collab` skill 的 tmux transport conventions 发送 handoff，并遵守 `references/tmux-handoff.md` 的 review-specific notes。
- 如果没有 pane refs，进入 inline handoff：生成 Review Packet 给用户转交 reviewer，并等待用户贴回 reviewer Findings；不要把 primary 自己的 self-review 当作 independent reviewer output。

2. Run scope gate。
- 只有存在具体 review object 时才进入 review loop：diff、patch、changed files、design doc、test artifact 或其他 bounded work product。
- 如果用户只是要 brainstorming、方向讨论或没有 artifact 的开放式判断，不要启动 full review loop；先生成更窄的 handoff 或请用户确认 review object。
- 对 tiny local changes，可以说明 review loop 成本高于收益，并直接给 normal self-check。

3. Build the Review Packet。
- 包含 goal、review scope、review mode、behavior changed、mandatory artifacts 和 optional context。
- Mandatory artifacts 至少包括 changed files、diff source 或 explicit snippets、tests/checks run、known unverified areas。
- Optional context 可以包括 primary summary、suspected risk areas 和最小相关 logs。
- Primary summary 不能替代 mandatory artifacts。
- 如果 reviewer 能访问同一 workspace，要求 reviewer 直接 inspect changed files/diff，而不是只接受 primary explanation。
- 不要把 noisy terminal scrollback 当作主要 review artifact 发送。
- 需要模板时使用 `references/review-request.md`。

4. Ask for Findings, not commentary。
- 要求 findings 按 severity 排序。
- 每个 finding 必须包含 stable `Finding ID`、status、severity、trigger、evidence、impact、suggested fix 和 confidence。
- `Finding ID` 在 Resolution Notes 和 ReReview 中必须保持不变。
- 要求 reviewer 在没有 blocking findings 时明确说明，并列出 residual risks 或 test gaps。
- 精确 output contract 见 `references/review-findings.md`。

5. Resolve each finding。
- Primary 必须按 `Finding ID` 对每个 finding 标记一个 decision：`accept`、`reject` 或 `needs-discussion`。
- `accept` 需要 action 和 verification。
- `reject` 需要 code evidence、test evidence 或明确 invariant。
- `needs-discussion` 需要提出最小的 unresolved technical question。
- 如果 verification 没有运行，必须说明原因，并把相关风险带入 final status。
- 精确 output contract 见 `references/resolution-notes.md`。

6. Re-review only changed or disputed items。
- 除非 patch 发生 substantial change，否则不要重新开始 full review。
- ReReview 必须引用原始 `Finding ID`，并只更新 accepted fixes 和 disputed findings。
- 默认最多进行两轮 review-resolution。
- 如果某个点仍未收敛，总结双方 position、evidence 和 residual risk，交给用户决策。

7. Finalize。
- 必须使用一个 final status label：`Consensus`、`Consensus with residual risks` 或 `No consensus / user decision needed`。
- `Consensus`：所有 blocking findings 都已关闭，且验证已运行或有充分替代 evidence。
- `Consensus with residual risks`：没有 blocking finding，但存在未跑测试、低信心区域、环境限制或明确 residual risk。
- `No consensus / user decision needed`：material risk 无法在两轮内用 evidence 收敛。
- 报告 accepted fixes、带 evidence 的 rejected findings、tests run 和 residual risks。
- 如果 verification 没有运行，必须明确说明。
- final answer 保持简洁，并以 review record 为依据。

## Reviewer Rules

Reviewer should：
- 独立 review mandatory artifacts；如果能访问同一 workspace，直接 inspect diff/files，而不是只接受 primary agent 的解释。
- 默认只读 workspace；除非用户明确要求 reviewer patch，否则不要修改文件、stage、commit 或运行 destructive commands。
- 优先关注 behavioral bugs、security issues、data loss、races、missing tests 和 broken contracts。
- 避免 style-only comments，除非它们影响 maintainability 或 correctness。
- 每个 issue 都给出 stable Finding ID、concrete trigger、evidence 和 impact。

Reviewer should not：
- Rubber-stamp primary agent 的解释。
- 直接修代码并绕过 Finding ID / Resolution Notes 流程。
- 在没有 trigger、evidence 和 impact 的情况下提出抽象 design concerns。
- 在缺少 mandatory artifacts 时假装完成 full review；应请求 evidence 或标记 residual risk。
- 在 narrow fix 足以处理风险时要求 broad rewrites。

## Primary Rules

Primary should：
- 把 reviewer comments 当作需要 resolution 的 findings，而不是需要赢下的 debate。
- 在请求 re-review 前修复 accepted findings。
- 只有在有 evidence 时才 reject。
- 保持 Finding ID 稳定，并在 re-review 中只发送 changed/disputed items。
- 对 unresolved decisions 进行 escalate，而不是无限 loop。

Primary should not：
- 隐藏 known failures 或 unrun tests。
- 在可以提供 structured packet 时，让 reviewer 去读 raw terminal noise。
- 在任何 high-severity finding 未解决时声称 consensus。
- 在存在相关未验证风险时使用 `Consensus`；应使用 `Consensus with residual risks`。

## Reference Files

- `references/review-request.md`：primary 发给 reviewer 的 Review Packet 模板。
- `references/review-findings.md`：reviewer 必须遵守的 Findings 格式。
- `references/resolution-notes.md`：primary 逐条回应 findings 的 Resolution Notes 格式。
- `references/tmux-handoff.md`：review-specific tmux notes；通用 tmux transport conventions 复用 `tmux-pane-collab` skill。
