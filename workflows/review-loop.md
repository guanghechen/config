# Review Loop (caller-side)

## Purpose and ownership

本流程在 significant change 完成 implementation 和 ordinary verification 后、交付前执行。caller 是 budgets、attempt state、histories、所有写操作与 loop 终态 `Converged` 的 single writer；只读的 `adversarial-review` core 独占审查判据、验证边界、disposition 与 review-local outcome（`Clean` / `User decision required`）。下文的“停止”均指结束当前流程，并向用户报告证据、影响、已试方案、具体选项与推荐。

## Bounds and failure policy

- 一个 review round 从 Step 1 取材开始，到 Step 3 dispatch 结束；替换 reviewer 不开启新 round，fix 或 writeful verification 后回到 Step 1 则开启新 round。整个 final pass 默认最多 4 个 rounds。
- reviewer attempt 与 caller-run verification 均使用固定 deadline，默认 180 秒。已知规模或验证时长需要更多时间时，可在启动前设置更长但仍有限的 deadline 并记录依据；启动后不得延长。
- caller-run verification 到达 deadline 后，caller 停止等待并尝试 cancel 或 terminate，同时记录 timeout raw evidence；无法确认操作已终止，或 writeful side-effect 状态不确定时，停止且不得在相同前提下重试。
- 每个 round 最多执行 2 个 clean-context attempts。无法启动 reviewer 记为 `unavailable`；到达 deadline、执行失败或结果无法 dispatch 记为 `invalid`。poll 或状态消息不重置 deadline，也不增加 attempt。
- attempt 失败且仍有 clean-context attempt 时替换 reviewer。attempt 耗尽后，仅当两次均为 `unavailable` 时，才允许 1 次 distinct same-context pass；caller 必须披露 anti-anchoring 降级，且不得称其为 isolated review。其他组合或该 pass 失败时停止。

## Workflow

### Step 1 — Acquire current input

- round budget 耗尽则停止；否则消费 1 个 round。
- 明确目标、成功标准、关键 non-goals 与适用约束。
- 重新采集完整累积 changeset 作为 primary scope；有前序 fix 时，同时采集 latest delta 作为仅用于定位新风险的 secondary scope。不得沿用旧快照或只提供最新 patch。
- active finding 需要独立验证时，仅在尚无对应记录或前提实质变化时，按 caller-run verification policy 执行并记录；无法在现有授权内安全执行或 policy 要求停止时，停止。未通过、timeout 或无法判断的结果作为 raw evidence 保留，finding 维持 `active`。
- 收集所有相关 raw verification commands 与 results，包括已执行的 writeful verification。输入不足、存在没有 safe default 的 material ambiguity，或补齐输入需要新授权时停止；否则进入 Step 2。

### Step 2 — Run the reviewer

- 启动真正隔离的 clean-context reviewer，只传 Step 1 的输入与 attempt deadline，并要求其调用只读的 `adversarial-review` skill；无法启动时记为 `unavailable`，按 failure policy retry、degrade 或停止。
- reviewer 以完整 changeset 为主、latest delta（如有）为辅，独立复核 raw evidence，并返回 core 规定的 findings、dispositions 与适用时的 review-local outcome。
- reviewer 完成 primary scope → `coverage: complete`；按 core 要求提前返回 `User decision required` → `coverage: stopped`；其他非预期中断均为 `invalid`。
- `Clean` 仅适用于 `coverage: complete` 且无未解决 material finding 或 blocking verification；`User decision required` 必须对应 `coverage: stopped`。
- valid result 进入 Step 3；deadline、执行失败、outcome 矛盾或没有唯一下一步时记为 `invalid`，按 failure policy retry 或停止。

### Step 3 — Dispatch the result

- caller 先按「Loop history」更新 findings 与 coverage，再按以下顺序 dispatch；命中一项即执行。
- `User decision required` 或命中「Escalation criteria」→ 停止。
- `Clean` 且没有 `active` material finding 或 blocking verification → caller 写入 `Converged` 并交付；仍有任一项 → 停止并报告 caller state 与 core outcome 的冲突。
- reviewer 请求 caller 执行 writeful verification：
  - verification history 已包含相同 semantic identity 与实质相同的前提 → 停止并报告 evidence conflict；caller 不重复副作用，也不替 core 判定验证已满足。
  - 尚无对应记录或前提已实质变化 → caller 在现有授权内确认影响与副作用；无法安全执行则停止，否则按 caller-run verification policy 执行并记录。policy 要求停止时停止，否则回到 Step 1。
- core 报告已确认、建议修复、in-scope 且可安全局部解决的 material finding → 进入 Step 4。
- 仍有 `active` material finding 或 blocking verification，且以上分支均不适用 → 命中 `decision boundary` 并停止；不得写入 `Converged` 或改判为 reviewer failure。

### Step 4 — Fix and re-verify

- 产生 concrete fix → caller 为每个实际处理的 finding 记录 1 次 fix attempt，并按 caller-run verification policy 运行 risk-proportionate verification。policy 要求停止时停止，否则回到 Step 1；未通过、timeout 或无法判断的结果作为 raw evidence 保留，不得提前标记 finding 为 `resolved`。
- 无法产生可安全执行的 concrete fix，或结果为 no-op → 停止；输入未变化时不得重试。

## Loop history

- caller 按 finding 的 trigger path、受影响行为与实际影响识别 semantic identity，不依赖措辞或临时 id。
- core 报告已确认、建议修复的 material finding 时，对应记录标记为 `active`；tradeoff、non-material finding 与需用户决策的事项不进入 active fix history。
- concrete fix 应用后，只有 `coverage: complete` 的 review 未再报告相同 finding，且适用的独立验证确认原 trigger path 已消除，才标记为 `resolved`；不存在独立验证通道时，完整 post-fix review 未再报告即可。
- 已 `resolved` 的 finding 再次出现时，仅在后续 delta 恢复同一 trigger path 时标记为 `reintroduced`；否则恢复为 `active`。两者都保留既有 fix-attempt count。

## Guardrails

- 完整累积 changeset 始终是 primary scope；latest delta 不得替代它。
- 不向 reviewer 传递 implementer 的结论、风险判断、推荐、loop history 或 budgets；raw verification evidence 必须传递。
- caller 独占 histories、budgets、写操作、workflow transition 与 loop 终态；core 独占审查判据、验证边界、disposition 与 review-local outcome。caller 不得改判 core 的 tradeoff、non-material finding 或 blocking verification。

## Escalation criteria

- `stalled-progress`：同一 `active` material finding 已执行 2 次 concrete fix，完整 review 仍报告该 finding；单次 fix 后仍在不构成 stalled。
- `oscillation / reintroduction`：fixes 在多个 findings 之间反复，或后续 delta 重新引入已解决的 finding。
- `decision boundary / round-budget exhausted`：下一步需要产品或架构判断、新授权、material scope，或新的 round 已无预算。
