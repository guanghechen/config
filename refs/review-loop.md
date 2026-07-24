# Review Loop (caller-side)

## Purpose and ownership

本流程在 significant change 完成 implementation 和 ordinary verification 后、交付前执行。caller 负责取材、维护 loop history 与 retry state、启动 reviewer、处置 review 结果并驱动循环。只读的 `adversarial-review` core 负责审查判据、验证边界、disposition 与终态。

## Workflow

### Step 1 — Acquire current input

- 明确目标、成功标准、关键 non-goals 与适用约束。
- 每轮重新采集当前任务的完整累积 changeset（含前几轮 fix）作为 primary scope；进入多轮循环后，同时采集 latest delta 作为 secondary scope，且仅用于定位新风险。不得沿用旧快照，也不得只提供最新 patch。
- 收集 raw verification commands 与 results，作为待 reviewer 独立复核的证据。
- 输入齐备且足以约束 review → 进入 Step 2；存在没有 safe default 的 material ambiguity，或补齐输入需要新授权 → 停止，并向用户提供证据、影响、具体选项与推荐。

### Step 2 — Start the reviewer

- 使用真正隔离的 clean-context reviewer，不得继承 implementation conversation、reasoning history 或 implementer 结论。只传 Step 1 的输入，并要求其调用只读的 `adversarial-review` skill。
- reviewer 成功启动 → 进入 Step 3。
- clean-context capability 不可用 → 在 retry budget 内等待并回到 Step 2；budget 耗尽后仍不可用 → 按「Degraded mode」披露，改用 distinct same-context pass，然后进入 Step 3。

### Step 3 — Run the review

- reviewer 以完整 changeset 为主、latest delta（如有）为辅执行 `adversarial-review`，独立复核 raw evidence，并返回 core 规定的 findings、dispositions 与适用时的终态。
- reviewer 按 core 契约完成整个 primary scope → caller 记录 `coverage: complete`；reviewer 按 core 要求返回 `User decision required` 并提前终止 → caller 记录 `coverage: stopped`。context 或 resource exhaustion 等非预期中断属于 reviewer failure，不得记为 `stopped`。
- outcome 必须自洽：只有 caller 记录 `coverage: complete`，且 result 不包含未解决的 material finding 或尚未完成的 blocking verification 时，才能标记为 `Converged`；`User decision required` 必须对应 `coverage: stopped`。冲突的 outcome 不得 dispatch。
- 结果足以按 Step 4 的优先级确定下一步 → 交回 caller 并进入 Step 4；reviewer 不编辑被审查文件。
- reviewer timeout、执行失败或结果不足以 dispatch → 不改写 loop history，也不新增 fix attempt；在 retry budget 内回到 Step 2，budget 耗尽后仍失败则停止，并向用户提供证据、影响、已试方案、具体选项与推荐。

### Step 4 — Dispatch the result

- caller 先按「Loop history」将本轮 findings 和 coverage 与既有状态对照，更新 loop history，再按以下顺序 dispatch；命中一项即执行，不再进入本轮后续分支。
- outcome 为 `User decision required`，或命中「Escalation criteria」→ 停止，向用户提供证据、影响、已试方案、具体选项与推荐。
- outcome 为 `Converged`，且更新后的 loop history 中没有 `active` material finding → 交付并结束；若仍有 `active` material finding，则结果不足以 dispatch，按 Step 3 的 reviewer failure 分支处理。
- reviewer 提出但无法安全执行的 writeful 验证 → caller 在现有授权内独立确认影响范围与副作用后执行，然后回到 Step 1。
- 存在已确认、由 core 建议修复、in-scope 且在现有授权下可安全局部解决的 finding → 进入 Step 5。

### Step 5 — Fix and re-verify

- 产生 concrete fix → caller 按「Loop history」为每个实际处理的 finding 记录一次 fix attempt，并运行 risk-proportionate verification；无论 verification 是否通过，都回到 Step 1，重新取材并 review 完整 changeset。
- 未产生 concrete fix，或结果为 no-op → 不计 attempt，也不 re-review 未变化的 changeset；在 retry budget 内回到 Step 5，budget 耗尽后仍无法应用 concrete fix 则停止，并向用户提供证据、影响、已试方案、具体选项与推荐。

## Loop history

- caller 按 finding 的触发路径、受影响行为与实际影响识别其 semantic identity，不依赖 reviewer 的措辞或临时 id。
- 当前 review 报告已确认、由 core 建议修复的 material finding 时，caller 按 semantic identity 更新已有记录；若无匹配记录，则新建记录。对应记录标记为 `active`。已接受的 tradeoff、可忽略的 non-material finding 与需要用户决策的事项不进入 active fix history。
- 仅在 concrete fix 已应用，且后续 `coverage: complete` 的 review 未再报告具有相同 semantic identity 的 finding 时，才可标记为 `resolved`：
  - 若存在独立验证通道，还须由 risk-proportionate verification 或直接证据确认原 trigger path 已消除。
  - 若不存在独立验证通道，只能依赖 read-only review，则 post-fix 的 `coverage: complete` review 未再报告该 finding 即可作为充分证据。
  - 若不满足上述前提，单纯未报告不足以判定 resolved；`coverage: stopped` 或 reviewer failure 亦同。
- 已 `resolved` 的 finding 后续再次被报告时，仅在证据表明后续 delta 恢复了同一 trigger path 时，才标记为 `reintroduced`；否则恢复为 `active`，并保留既有 fix-attempt count。
- fix attempt 仅在 caller 为该 finding 应用 concrete fix 时增加一次；verification-only、no-op 或 reviewer failure 不计数。
- 一个 fix 同时处理多个 findings 时，为每个实际处理的 finding 各增加一次 attempt；未被该 fix 处理的 finding 不计数。

## Guardrails

- 完整累积 changeset 始终是 primary scope；latest delta 不得替代它。
- 不向 reviewer 传递 implementer 的结论、风险判断或推荐；passing tests 也不能替代对未覆盖高风险路径与 material uncertainty 的独立判断。
- loop history 与 retry state 仅由 caller 持有并用于跨轮次控制，不传给 reviewer。
- failure episode 从对应操作首次失败开始，并跨后续 retry 跳转持续。caller 为其维护独立、有限的 retry budget；仅当该操作成功或流程退出相应 failure path 时，才重置 budget。
- `adversarial-review` core 始终只读并独占审查判据与验证边界；caller 独占写入与循环控制。
- caller 不得将 core 判为可接受的 tradeoff 或可忽略的 non-material finding 擅自改判为待修复 finding。

## Escalation criteria

- `stalled-progress`：对同一 `active` material finding 连续执行 2 次已计数的 fix attempt 后，`coverage: complete` 的 review 仍报告该 finding。
- `oscillation / reintroduction`：fixes 在多个 findings 之间反复，或有证据确认后续 delta 重新引入已解决的 finding；命中即升级，无需累计次数。
- `decision boundary`：下一步需要产品或架构判断、新授权或 material scope；命中即升级，无需累计次数。
- 单次 concrete fix 后 finding 仍在，或一次未能应用 concrete fix，不构成 stalled-progress。

## Degraded mode

- 不得因便利、token 成本或短暂容量不足启用 degraded mode。
- 仅当 clean-context capability 持续不可用时，才可使用 distinct same-context pass；必须明确披露 anti-anchoring 降级，且不得将其称为 isolated review。
