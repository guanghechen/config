# Resolution Notes Template

Primary output 必须对每个 reviewer finding 逐条回应，且每个 finding 只回应一次。

Resolution Notes 必须保留 reviewer 的 `Finding ID`。如果 finding 被拆分、合并或发现新问题，先在 notes 中说明关系，再请求 reviewer re-review。

```text
Resolution Notes

Finding ID: F-001
Decision: <accept|reject|needs-discussion>
Status: <fixed|rejected-with-evidence|disputed|escalated>
Reason: <为什么这个 decision 是正确的。>
Action taken: <patch、test、doc change，或 "none"。>
Verification: <command/test/evidence，或 "not run" 并说明原因。>
Residual risk: <剩余风险，或 "none"。>

Finding ID: F-002
Decision: <accept|reject|needs-discussion>
Status: <fixed|rejected-with-evidence|disputed|escalated>
Reason: <为什么这个 decision 是正确的。>
Action taken: <patch、test、doc change，或 "none"。>
Verification: <command/test/evidence，或 "not run" 并说明原因。>
Residual risk: <剩余风险，或 "none"。>

Items for re-review:
<只列 accepted fixes 和 disputed findings，按 Finding ID 引用。>
```

Rules：
- `accept` 需要 action 和 verification plan。
- `reject` 需要 code evidence、test evidence 或明确 invariant。
- `needs-discussion` 只能提出一个 narrow question，不要展开成 broad debate。
- 如果 verification 没有运行，必须说明原因，并把相关风险带入 final status。
