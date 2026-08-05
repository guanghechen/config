---
name: triage-issues
description: Persist and triage issues, suggestions, or decision points already surfaced in the current context, one at a time. Use only when the user explicitly invokes this skill. Do not invoke implicitly, discover new items, rerun the originating analysis, or implement changes without explicit item-scoped authorization.
disable-model-invocation: true
---

# 逐项整理问题、建议与决策

保存上下文中已有的条目，再逐项与用户评审。用户明确选择“试做当前项”时只实施该项；否则除另行授权外只写清单，不实施改动。

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

选择当前条目：显式重开终态项时记录原决定、重置为 `undecided`，并将其设为唯一的 `discussing`；否则续接唯一的 `discussing`，多个时让用户指定并将其余设为 `pending`，没有时取首个 `pending`，均无则汇总。展示前把选中的 `pending` 改为 `discussing`。详情状态是唯一事实来源，队列只定顺序。

必要时仅只读检查当前条目直接相关的代码、测试、help 或 benchmark，以补足准确示例；不得扩展问题集合。

本会话首次展示或重开当前条目时完整重述并使用以下简报；用户追问按第 4 节直接回答。`issue` / `suggestion` 只用“当前 vs 改后”表，`decision` 只用“选项对比”表。

```markdown
### ITEM-001 - <简短标题>

#### Descriptions

<详细描述：issue / suggestion 说明具体触发或现状 → 机制或限制 → 后果、阻塞或收益；decision 说明背景、选项、关键分歧及阻塞；必要时注明来源和原始 disposition>

#### Examples

<一个端到端例子：具体命令、输入或前提 → 关键步骤 → 最终可观察结果；真实或标明 illustrative>

#### Proposal

<推荐方案或选项、理由、最小有效范围和验证方式；首次处理提供“Accept 后续统一处理 / Reject / 先验证 / 延后”，可安全实施时再提供“试做当前项”；decision 有后续工作时再选处理时机；补充选项标为 proposed>

---

| 对比项 (issue / suggestion only) | 解决前       | 解决后       | 变化 / 影响 |
| -------------------------------- | ------------ | ------------ | ----------- |
| <行为、性能或 architecture 维度> | <可观察结果> | <可观察结果> | <具体差异>  |

| 选项 (decision only)   | 选择后的结果 | 收益       | 成本 / 风险 | Effort / 可逆性    |
| ---------------------- | ------------ | ---------- | ----------- | ------------------ |
| <原始或 proposed 选项> | <可观察结果> | <具体收益> | <具体代价>  | <总成本与回退难度> |

<明确不变：关键 happy path、兼容性或非目标的实际结果>

---

- 收益：<解决问题或选择方案后的具体价值>
- 代价 / 风险：<实施成本、副作用和 tradeoff>
- Effort / 可逆性：<总成本、范围、假设和回退难度>
- 证据 / 未决信息：<可信度、来源、验证缺口或 unknown>
```

`Descriptions` 应能独立说明条目。示例默认一个，无法覆盖关键差异时最多两个，不得用抽象类别或风险术语代替可观察结果。对比区只留适用的一张表：Performance 写 workload、baseline、预期值和差值；Architecture 写前后 flow、ownership 及修改影响；`decision` 写结果、成本、风险、Effort 和可逆性。最后分析推荐方案的收益、代价与不确定性。

证据等级为 `verified`（代码、测试或 reproduction）、`measured`（benchmark 或观测）、`estimated`（有假设的推算）、`illustrative`（解释示例）。精确数字、错误文本和当前行为只能是 `verified` 或 `measured`；否则当前结果写 `unknown（待验证）`。无法可信对比时说明缺口并推荐“先验证”。

Effort 覆盖适用的验证、实现、测试和 review：`XS` <30 分钟；`S` 30 分钟–2 小时；`M` >2 小时–1 天；`L` >1–3 天；`XL` >3 天或需单独设计。`decision` 比较各选项的后续成本；没有后续工作写 `N/A`。

## 4. 记录与推进

- 处理结果：试做 → `discussing`；接受试做结果、Accept 后续统一处理或其他明确接受决定 → `decided`；Reject / 忽略 → `dismissed`；延后 → `deferred`。`decision` 需确定方案；有后续工作时还需处理时机。进入下一项前记录决定、理由、时间、Effort 和约束；有试做改动时，只在接受结果或安全回退后写入终态。
- 试做只授权实施并验证当前项：先在日志记录所选方案 / 选项、受影响路径及 worktree baseline，不 stage、commit 或 push，保持 `undecided`；完成后展示实际行为、diff、验证和未决风险。若不接受，明确确认后只回退本次试做改动；无法隔离时保持 `discussing` 并询问。
- 追问、质疑、补充约束或未明确选择时直接回应，不推断决策，并保持 `discussing`。纯澄清不写文件；新增事实只写回并记一条日志；结论、推荐或范围变化时先说明原因，再只重述受影响的小节；否则不重复。
- 除当前项的显式试做外，本 Skill 不跟踪后续验证或实施。讨论中出现新条目或发现当前项含可独立决策的内容时，征得同意后以新 ID 追加为 `pending`；拆分时当前项保留原 ID 与 `discussing` 并收窄。
- 仅在当前条目已讲清且没有未答问题时请求明确决策；不同时展开下一项。

完成后报告清单路径、状态数量、已接受的试做、Accept 后续统一处理的工作及 Effort、Reject 或延后、所选决策和推荐下一步。
