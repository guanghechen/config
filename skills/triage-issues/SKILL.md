---
name: triage-issues
description: Persist and triage issues or suggestions already surfaced in the current context, one at a time. Use only when the user explicitly invokes $triage-issues. Do not invoke implicitly, discover new items, rerun the originating analysis, or implement changes.
---

# 逐项整理问题与建议

将上下文中已有的问题或建议保存为清单，再逐项与用户评审。除非用户另行授权，否则只写清单，不执行其他改动。

## 1. 提取条目

- 使用用户明确指向的列表；否则使用会话中最近一个边界清晰的列表。仅在指代存在歧义时询问用户。
- 保留每个条目的原意、证据、影响或收益、来源结论和原始顺序。可以压缩措辞，但不得重跑产生这些条目的 review 或分析。
- 不得补造缺失信息、静默丢弃条目或新增条目。缺失信息标记为 `unknown`；仅合并明显重复项。
- 写入前遮盖疑似 secret。没有可用条目时，请用户指明来源，不创建空清单。

## 2. 持久化清单

在当前 repository 或 workspace 根目录下创建清单：

1. 同一组条目已有活动清单时，继续复用该文件。
2. 否则创建 `local/YYYYMMDD/issues-NN.md`；`NN` 为当天目录内现有 `issues-NN.md` 的两位数最大序号加一，从 `01` 开始。
3. 不得覆盖现有文件。发生冲突时尝试下一个序号；超过 `99` 时停止并请求用户决定。
4. 使用稳定 ID：`ITEM-001`、`ITEM-002`，依此类推；不得重新编号。

使用以下结构：

```markdown
# 问题与建议

- 背景：<任务或会话背景>
- 来源：<adversarial review | 用户请求的分析 | 其他>
- 创建时间：<带时区的 ISO-8601 时间>

## 队列
- [ ] ITEM-001 — <标题> (`pending`)

## ITEM-001 — <标题>
- 类型：`issue` | `suggestion`
- 来源：<adversarial review | 用户请求的分析 | 其他 | unknown>
- 原始结论：<material issue | non-material finding | tradeoff | suggestion | 其他 | unknown>
- 状态：`pending`
- 简述：<简明描述>
- 触发条件 / 证据：<已知触发条件和证据，或 unknown>
- 影响 / 收益：<已知影响或预期收益>
- 原始建议：<如有>
- 决策：`undecided`
- Effort：`unestimated`
- 日志：<时间> — 从上下文提取。
```

## 3. 每次评审一个条目

写入清单后立即从第一个条目开始。展示前，先将该条目及队列中的状态更新为 `discussing` 并写回清单。任何时候只能有一个条目处于 `discussing` 状态。

必要时只读检查与当前条目直接相关的代码、测试、help 或已有 benchmark，以补足准确示例；不得借此重新扫描 repository、扩展问题集合或实施改动。

每次使用以下决策简报，完整重新展示当前条目：

```markdown
### ITEM-001 — <标题>

#### 结论先行

- 类型 / 来源：<issue | suggestion> / <来源及原始 disposition>
- 具体要改什么：<用业务或使用者能理解的语言描述，不只写实现术语>
- 为什么值得做：<当前损失、风险或具体收益>
- 推荐决策：<批准改动 | 先验证 | 接受现状 / 风险 | 延后 | 忽略> — <理由>

#### 直观变化

- 代表场景：<真实或明确标注为 illustrative 的场景>

| 输入 / 前提 | 当前实际结果 | 改后预期结果 | 对用户或系统的影响 |
| --- | --- | --- | --- |
| <具体调用、数据、状态或 workload> | <可观察结果> | <可观察结果> | <为什么这项差异有价值> |

- 明确不变的内容：<至少说明关键 happy path、兼容性或非目标；写出实际结果，不只写“行为不变”>

#### 实现与证据

- 推荐解决思路：<最小有效方案及理由>
- 改动范围：<预计涉及的模块、接口、数据流或文档>
- 证据与可信度：<measured | estimated | illustrative；给出来源和假设>
- 验证方式：<如何证明行为、性能或兼容性符合预期>

#### 决策成本

- Effort：<规模、范围和假设>
- Tradeoff / 风险：<成本、兼容性、不确定性或残余风险>
- 备选方案：<仅列有实质差异的方案；没有则写无>
```

直观变化至少覆盖一个代表性端到端场景。不得只写“更早报错”“行为不变”“结构更清晰”等抽象结论：

- CLI、API 或行为变化：展示具体输入，以及当前和改后的输出、错误类型、状态或发生阶段；若 happy path 不变，也写出其实际结果。
- Performance：说明 workload，给出 latency、throughput、memory、allocation、I/O 或复杂度等最相关指标的 baseline、预期值和差值。
- Architecture 或 refactor：展示改动前后的调用、数据或 ownership 流向，并用一个后续修改任务说明影响，例如涉及模块、重复步骤或测试面如何变化。

所有数字、错误文本和行为必须来自证据；否则标记为 `estimated` 或 `illustrative`，并写明假设。无法给出可信对比时，明确说明缺口、给出验证方案，并推荐“先验证”，不得为满足模板而臆造。Effort 必须包含验证、实现、测试和 review：`XS` ≤30 分钟，`S` 0.5–2 小时，`M` 0.5–1 天，`L` 1–3 天，`XL` >3 天或需要单独设计。

每次只请求一个明确决策；同一轮不得展示下一个条目。

## 4. 记录并推进

- 进入下一项前，先更新清单中的决策、理由、时间、Effort、约束和队列状态。
- 状态仅使用：`pending`、`discussing`、`validate`、`change-approved`、`accepted`、`deferred`、`dismissed`、`blocked`、`resolved`。
- 严格映射用户决策：批准改动 → `change-approved`；先验证 → `validate`；接受现状或风险 → `accepted`；延后 → `deferred`；忽略 → `dismissed`。`blocked` 和 `resolved` 只由 workflow 根据事实设置。
- 本 Skill 不实施改动。将用户另行授权的验证或实现交给相应 workflow，并继续保留清单路径。
- 仅在适用验证通过后标记 `resolved`。没有后续完整 review 时，不得声称 adversarial review 已 `Converged`。
- 讨论中出现新条目时，先告知用户并征得同意，再追加到清单。

队列处理完成后，报告清单路径、各状态数量、已批准工作及 Effort、已接受或延后的风险，以及推荐的下一步。
