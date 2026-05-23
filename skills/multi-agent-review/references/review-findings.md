# Review Findings Template

Reviewer output 必须 evidence-backed。不要在 findings 前写大段泛泛 commentary。

每个 finding 必须使用稳定 `Finding ID`，并在后续 Resolution Notes 和 ReReview 中保持不变。ID 推荐格式：`F-001`、`F-002`。

```text
Review Findings

Finding ID: F-001
Status: open
Severity: <Critical|High|Medium|Low>
Trigger: <触发问题的具体 condition 或 code path。>
Evidence: <file、function、line、diff hunk、command output 或 observable behavior。>
Impact: <什么会坏、影响谁、为什么重要。>
Suggested fix: <最窄、最实际的修复建议。>
Confidence: <High|Medium|Low>

Finding ID: F-002
Status: open
Severity: <Critical|High|Medium|Low>
Trigger: <触发问题的具体 condition 或 code path。>
Evidence: <file、function、line、diff hunk、command output 或 observable behavior。>
Impact: <什么会坏、影响谁、为什么重要。>
Suggested fix: <最窄、最实际的修复建议。>
Confidence: <High|Medium|Low>

No blocking findings:
<只有在没有 Critical/High/Medium findings 时使用本节。>

Residual risks or test gaps:
<未验证区域、missing tests、assumptions 或 low-confidence concerns。>
```

如果一个 finding 无法提供 trigger 和 evidence，不要把它当作 finding。只有在仍值得跟踪时，才降级成 residual risk。

Re-review 时只引用原始 `Finding ID`，并把 `Status` 更新为：`confirmed-fixed`、`still-open`、`withdrawn` 或 `escalated`。除非发现新的 material risk，否则不要重新编号或重新开始 full review。
