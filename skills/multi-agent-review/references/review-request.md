# Review Request Template

当需要请 reviewer agent 检查一个具体 code change 时，使用这个模板。

Review Packet 必须区分 mandatory review artifacts 和 optional context。Primary 的总结只能帮助 reviewer 定位风险，不能替代 diff、文件或测试证据。

```text
Review Request

Goal:
<这次变更要解决什么问题，或应该实现什么行为。>

Review scope:
<重点检查 correctness / security / regressions / tests / API contract / maintainability 等。>

Review mode:
<full-diff review | focused-diff review | design-doc review | artifact-only review。>

Mandatory review artifacts:
- Changed files: <列出文件路径，并用一句话说明每个文件的作用。>
- Diff source: <git diff / patch file / explicit changed snippets / design artifact path。>
- Tests and checks run: <commands 和 pass/fail results；没跑就写 "not run" 并说明原因。>
- Known unverified areas: <未验证路径、环境限制、missing tests 或 assumptions。>

Optional context:
- Primary summary: <实现思路摘要；不能替代 mandatory artifacts。>
- Suspected risk areas: <primary agent 希望 reviewer 重点看的路径。>
- Relevant logs or artifacts: <只放最小相关日志，不放 noisy scrollback。>

Behavior changed:
<说明 user-visible 或 API-visible behavior changes。>

Reviewer output contract:
Inspect the mandatory artifacts directly when available. Return findings only,
sorted by severity. For each finding include Finding ID, Status, severity,
trigger, evidence, impact, suggested fix, and confidence. If there are no
blocking findings, say that and list residual risks or test gaps.
```

Review Packet 应该短到 reviewer 能快速聚焦。diff 很大时，优先给 artifact link、changed file list 和最小必要 snippets，不要粘贴整段 noisy scrollback。

如果 mandatory artifacts 缺失，先要求补齐或把最终状态降级为 `Consensus with residual risks` / `No consensus / user decision needed`，不要把 primary summary 当作完整 review evidence。
