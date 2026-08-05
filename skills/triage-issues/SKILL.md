---
name: triage-issues
description: Persist and triage issues, suggestions, or decision points already surfaced in the current context, one at a time. Use only when the user explicitly invokes this skill. Do not invoke implicitly, discover new items, rerun the originating analysis, or implement changes.
---

# 逐项整理问题、建议与决策

保存上下文中已有的条目，再逐项与用户评审。除非用户另行授权，否则只写清单，不实施改动。

## 1. 提取与分类

- 用户要求继续且当前上下文明确关联清单路径时，读取该文件，按第 2 节完成 schema 检查或迁移后进入第 3 节，不重新提取或追加条目。
- 创建清单或明确要求追加时，使用用户指定的列表；否则取会话中最近一个边界清晰的列表。指代有歧义时才询问。
- 保留原意、证据、影响或收益、来源结论和顺序；可各自独立决策的内容分开；当前推荐相同不构成合并理由，只合并明显重复项；不得重跑原分析、丢弃内容或引入来源中不存在的新发现。
- 缺失信息写 `unknown`。补充选项必须标记为 `proposed`；所有持久化和展示内容都应遮盖疑似 secret。
- 没有可用条目时请用户指明来源，不创建空清单。

按核心性质分类，不因条目来自“需要用户决策”的列表就统一标为 `decision`：

- `issue`：存在有证据支持的缺陷、回归或风险；即使要决定修复还是接受风险，仍是 `issue`。
- `suggestion`：没有确认缺陷的可选改进。
- `decision`：核心是从多个合理方案、策略或约束中选择。

## 2. 持久化

- 继续或追加时复用当前上下文明确关联的清单路径；路径不明确时请用户提供，不得靠扫描 `local/` 猜测该路径或另建文件。追加时保留现有内容，按最大 ID 继续编号，并把每个新条目追加到队列末尾；与既有条目明显重复的只补充原条目的证据和日志，不新增 ID；原条目已为终态且用户未明确要求重开时，先确认。
- 未要求继续或追加时，若当前上下文已关联活动清单，先请用户选择新建、继续或追加；否则在 repository 或 workspace 根目录创建 `local/YYYYMMDD/issues-NN.md`。`NN` 取当天最大序号加一，从 `01` 开始；冲突时递增，超过 `99` 后询问用户，绝不覆盖。
- 使用稳定 ID `ITEM-001`、`ITEM-002`……，不得重新编号。

```markdown
# 问题、建议与决策

- Schema version: `2`
- 背景：<任务或会话背景>
- 来源：<adversarial review | 用户请求的分析 | agent decision request | 其他>
- 创建时间：<带时区的 ISO-8601 时间>

## 队列

- ITEM-001 — <标题>

## ITEM-001 — <标题>

- 类型：`issue` | `suggestion` | `decision`
- 来源：<来源>
- 原始结论：<原始 disposition 或 unknown>
- 状态：`pending`
- 简述：<简明描述>
- 触发条件 / 证据：<已知内容或 unknown>
- 影响 / 收益：<已知内容或 unknown>
- 原始建议 / 选项：<原始内容、proposed 或 unknown>
- 决策：`undecided`
- 决策理由：`unknown`
- Effort：`unestimated`
- 日志：<时间> — 从上下文提取。
```

复用清单时，version `2` 按上述模板校验后直接使用；其他已标记 version 保持不变并询问。出现不在下列保留或转换规则中的状态，或校验失败时，保持文件不变并询问。未标记旧版仅在以下转换全部成功后写入 version `2` 和迁移日志：

- 移除队列中的 checkbox 和状态，仅保留 ID、标题及顺序；将 `原始建议` 改为 `原始建议 / 选项`，缺失的 `决策理由` 补为 `unknown`。
- `pending`、`discussing`、`decided`、`deferred`、`dismissed` 保持不变；`validate`、`change-approved`、`accepted`、`resolved` 转为 `decided`，并在原决策为 `undecided` 时分别补为“先验证”“批准改动”“接受现状 / 风险”“旧版已解决”。

## 3. 逐项评审

选择当前条目：用户明确要求重开终态条目时，将原决定记入日志，决策重置为 `undecided`，状态置为 `discussing`，并把其他 `discussing` 项恢复为 `pending`；其他情况，唯一的 `discussing` 优先，多个 `discussing` 时让用户指定并将其余恢复为 `pending`，没有 `discussing` 时取第一个 `pending`；均不存在时输出完成汇总。展示前把选中的 `pending` 写为 `discussing`。条目详情中的状态是唯一事实来源，队列只保存顺序。

必要时仅只读检查当前条目直接相关的代码、测试、help 或 benchmark，以补足准确示例；不得扩展问题集合。

本会话首次展示或重开当前条目时完整重述并使用以下简报；用户追问按第 4 节直接回答。`issue` / `suggestion` 只用“当前 vs 改后”表，`decision` 只用“选项对比”表。

```markdown
### ITEM-001 — <标题>

#### 结论先行

- 类型 / 来源：<类型> / <来源及原始 disposition>
- 条目本身：<issue / suggestion：具体触发或现状 → 机制或限制 → 后果、阻塞或收益；decision：选项、关键分歧及阻塞>
- 本项需要决定什么：<具体选择>
- 推荐决策：<选择> — <理由>

#### 具体例子与变化

- 端到端例子：<具体命令、输入或前提 → 关键步骤 → 最终可观察结果；真实或 illustrative>

  | 输入 / 前提 (issue / suggestion only) | 当前结果     | 改后结果     | 影响       |
  | ------------------------------------- | ------------ | ------------ | ---------- |
  | <具体场景>                            | <可观察结果> | <可观察结果> | <具体价值> |

  | 选项 (decision only)   | 选择后的结果 | 收益       | 成本 / 风险 | Effort / 可逆性    |
  | ---------------------- | ------------ | ---------- | ----------- | ------------------ |
  | <原始或 proposed 选项> | <可观察结果> | <具体收益> | <具体代价>  | <总成本与回退难度> |

- 明确不变：<关键 happy path、兼容性或非目标的实际结果>

#### 方案与成本

- 推荐方案 / 范围：<最小有效方案及涉及范围>
- 证据 / 验证：<可信度、来源、假设和验证方式>
- Effort：<规模、范围和假设>
- Tradeoff / 未决信息：<风险、替代方案或 unknown>
```

每个简报先讲清条目本身，再用一个端到端例子说明变化（一个无法覆盖关键差异时最多两个）：行为变化给出具体命令或输入、关键步骤及前后可观察结果，不得用类别名或风险术语代替例子；Performance 给出 workload、baseline、预期值和差值；Architecture 给出前后调用、数据或 ownership 流及后续修改影响；`decision` 逐项给出结果、成本、风险、Effort 和可逆性。

证据等级为 `verified`（代码、测试或 reproduction）、`measured`（benchmark 或观测）、`estimated`（有假设的推算）、`illustrative`（解释示例）。精确数字、错误文本和当前行为只能是 `verified` 或 `measured`；否则当前结果写 `unknown（待验证）`。无法可信对比时说明缺口并推荐“先验证”。

Effort 覆盖适用的验证、实现、测试和 review：`XS` <30 分钟；`S` 30 分钟–2 小时；`M` >2 小时–1 天；`L` >1–3 天；`XL` >3 天或需单独设计。`decision` 比较各选项的后续成本；没有后续工作写 `N/A`。

## 4. 记录与推进

- 状态仅为 `pending`、`discussing`、`decided`、`deferred`、`dismissed`；具体选择写入“决策”。
- 批准、先验证、接受风险或选择选项 → `decided`；延后 → `deferred`；忽略 → `dismissed`。进入下一项前把决定、理由、时间、Effort 和约束写回清单文件。
- 用户追问、质疑、补充约束或未明确选择时，直接回应且不推断决策；除必要的一句持久化提示外，不复述状态机或 Skill 规则。保持 `discussing`；纯澄清本身不写文件。回答一旦转向与当前推荐不一致的方案，或改变结论、推荐、条目范围，就按实质变化处理：先说明原因，写回并追加一条日志，只重述受影响的小节。其他新增事实、证据或约束只写回并追加一条日志；否则不重复。
- 本 Skill 不跟踪后续验证或实施。讨论中出现新条目或发现当前项含可独立决策的内容时，征得同意后以新 ID 追加为 `pending`；拆分时当前项保留原 ID 与 `discussing` 并收窄。
- 仅在当前条目已讲清且没有未答问题时请求明确决策；不同时展开下一项。

完成后报告清单路径、状态数量、批准工作及 Effort、所选决策、接受或延后的风险和推荐下一步。
