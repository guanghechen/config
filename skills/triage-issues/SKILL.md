---
name: triage-issues
description: Persist and triage issues, suggestions, questions, or decision points already surfaced in the current context, one at a time. Use only when the user explicitly invokes this skill. Do not invoke implicitly, discover new items, rerun the originating analysis, or implement changes without explicit item-scoped authorization.
disable-model-invocation: true
---

# 逐项整理问题、建议、疑问与决策

保存当前上下文中已提出的条目，再逐项与用户评审。只有用户明确授权“试做当前项”时才实施该项；其他情况只维护清单，除非用户对当前项另有明确授权。

## 1. 提取与分类

- 用户要求继续且当前上下文明确关联清单路径时，读取该文件，按第 2 节完成 schema 检查后进入第 3 节，不重新提取或追加条目。
- 创建清单或明确要求追加时，使用用户指定的列表；否则取会话中最近一个边界清晰的列表。指代有歧义时才询问。
- 保留原意、证据、影响或收益、来源结论和顺序。分开可独立处理的内容；只合并明显重复项，当前推荐相同不构成合并理由。
- 不得重跑原分析、丢弃内容或引入来源中不存在的新发现。每个条目的来源边界仅为来源列表中该条目自身，不包含周边讨论。
- 缺失信息写 `unknown`；补充选项标记为 `proposed`。
- 持久化或展示前，将疑似 secret 替换为可见遮盖标记。
- 没有可用条目时请用户指明来源，不创建空清单。

按核心性质分类，不因条目来自“需要用户决策”的列表就统一标为 `decision`：

- `issue`：存在有证据支持的缺陷、回归或风险；即使要决定修复还是接受风险，仍是 `issue`。
- `suggestion`：没有确认缺陷的可选改进，不论是否已有具体方案。
- `question`：核心是澄清未知的事实、意图、约束或假设，而非选择方案。
- `decision`：核心是从多个合理方案、策略或约束中选择。

以事实性答案为终点时为 `question`；即使事实明确仍需权衡选择时为 `decision`。证据不完整本身不决定类型：“X 是否发生”是 `question`；“已有证据表明 X 在 Y 下发生”是 `issue`。

## 2. 持久化

### 路径与新增条目

- 继续或追加时，复用当前上下文明确关联的清单路径。路径不明确时请用户提供；不得扫描 `local/` 猜测路径或另建文件。
- 追加时保留现有内容，按最大 ID 继续编号，并将新条目追加到队列末尾。若新条目与既有条目明显重复，按第 4 节将新事实追加到原条目，必要时重建 projection，不新增 ID。原条目已为终态且用户未明确要求重开时，先确认。
- 未要求继续或追加时，若当前上下文已关联活动清单，先请用户选择新建、继续或追加；否则在 repository 或 workspace 根目录创建 `local/YYYYMMDD/issues-NN.md`。`NN` 取当天最大序号加一，从 `01` 开始；冲突时递增，超过 `99` 后询问用户，绝不覆盖。
- 使用稳定 ID `ITEM-001`、`ITEM-002`……，不得重新编号。
- 创建或追加时先完成分类，只读取本批实际出现类型的 reference，再按其 `Item format` 生成 payload；不读取未出现类型的 reference。同时将来源条目在遮盖 secret 后的全文逐字写入 `来源原文`；确无来源文本时写 `unknown`，不伪造原文。仅当本批所有公共 envelope 和 payload 都通过校验时写入，否则保持文件不变并询问。
- `来源原文` 超过 2000 字符时，写入前按批列出超限条目并询问一次，推荐仍完整内嵌。持久化永不自动截断，不使用 sidecar；频繁超限时重新检查来源边界。

### 清单格式

`````markdown
# 问题、建议、疑问与决策

- Schema version: `4`
- 背景：<任务或会话背景>
- 来源：<adversarial review | 用户请求的分析 | agent decision request | 其他>
- 创建时间：<带时区的 ISO-8601 时间>

## 队列

- ITEM-001 — <标题>

## ITEM-001 — <标题>

- 类型：`issue` | `suggestion` | `question` | `decision`
- 来源：<来源>
- 原始结论：<来源中的原始结论或 unknown>
- 状态：`pending`
- 简述：<简明描述>
<按类型 reference 的 Item format 插入 payload fields，不保留本占位行>
- 结论 / 决策：`undecided`
- 结论 / 决策理由：`unknown`
- Effort：`unestimated`
- 来源原文：

  ````text
  <遮盖 secret 后的来源条目全文或 unknown>
  ````
<有新增事实时才按下文格式插入 `补充事实`；不保留本占位行>
- 日志：<时间> — 从上下文提取。
`````

### Evidence stream 与字段职责

`来源原文` 是必填、非空的 fenced block，逐字保存来源条目在遮盖 secret 后的全文；确无来源文本时写 `unknown`。使用比内容中最长同类 fence 更长的分隔符；结构性缩进不属于 block body。

`补充事实` 是可选 fenced block，仅在有内容时按以下结构放在 `来源原文` 与 `日志` 之间。每条以空行分隔，首行只允许以下三种形式：

`````markdown
- 补充事实：

  ````text
  补充：<新事实>

  更正：<被更正的原断言的逐字引用> → <替代内容>

  撤回：<被撤回的原断言的逐字引用> — <理由>
  ````
`````

字段职责如下：

- `来源原文` 与 `补充事实` 组成 evidence stream。
- `简述`、`原始结论` 和 payload 是可重建的 typed projection，`类型` 选择 projection schema。
- `状态`、`结论 / 决策`、`结论 / 决策理由` 和 `Effort` 是 workflow state。
- `日志` 只记操作。

`来源原文` 只在创建或拆分新项时初次写入；`补充事实` 只由第 4 节追加；projection 只在创建、转类、拆分或证据变化时重建。每次写回清单前，以读入文件为 baseline 检查所有已存在条目，必须保证：

- `来源原文` 的 block body 与读入时逐字节相同。唯一例外是事后发现 secret：只得将 secret 替换为可见遮盖标记，不得删除周边内容，并记一条日志。
- `补充事实` 只能在 block body 末尾追加；旧 block body 必须是新 block body 的逐字节前缀。更正或撤回可指向 `来源原文` 或先前的 `补充事实`，引用必须是目标文本的完整逐字子串，不得用省略号缩写；引用在当时的 evidence stream 中不唯一时，增加上下文直到唯一。
- 重开、转类、拆分、状态变化和 projection 重建均不得修改上述已存在的 evidence stream；拆分出的新条目复制拆分时原条目的完整 evidence stream，之后独立追加。
- 任一不变性、必填性、append-only 或引用校验失败时，保持整个文件不变并询问。

### 校验

只复用标记为 version `4` 的清单；未标记或其他 version 保持文件不变并询问。先校验清单头、队列和所有条目的公共 envelope；payload 在条目首次展示、重开或继续时按对应 reference 校验。合法状态为 `pending`、`discussing`、`decided`、`answered`、`deferred`、`dismissed`，其中 `answered` 仅用于 `question`。出现未定义的类型或状态，或校验失败时，保持文件不变并询问。

## 3. 逐项评审

### 选择当前条目

`decided`、`answered`、`deferred`、`dismissed` 为终态。按以下顺序选择当前条目：

1. 用户显式重开终态项时，选中该项。
2. 否则续接唯一的 `discussing`；若有多个，请用户指定。
3. 没有 `discussing` 时，选择首个 `pending`。
4. 没有 `pending` 时，直接汇总。

选中条目后，先按下文读取 reference 并校验 payload。校验通过后：

- 重开项先在日志记录原结论或决定及其理由，再将 `结论 / 决策` 和 `结论 / 决策理由` 分别重置为 `undecided` 和 `unknown`。
- 将选中项设为唯一的 `discussing`，并将其余 `discussing` 改为 `pending`。

校验失败时保持文件不变并询问。详情中的状态是唯一事实来源，队列只定义顺序。

### Reference 与展示

首次展示、重开或继续当前条目前，根据其类型只读取对应 reference：

- `issue`：[references/issue.md](references/issue.md)
- `suggestion`：[references/suggestion.md](references/suggestion.md)
- `question`：[references/question.md](references/question.md)
- `decision`：[references/decision.md](references/decision.md)

不得为展示当前条目读取其他类型的 reference。转类后停止使用原 reference，读取新类型的 reference，在保留 evidence stream 的前提下重写 payload，并在日志记录原类型 → 新类型；无法归属或缺失的内容写 `unknown`。

职责边界如下：

- `SKILL.md` 是清单头、队列、公共 envelope、公共展示标题和状态流转的唯一事实来源。
- 当前类型 reference 的 `Item format` 是 payload 字段名、顺序和语义的唯一事实来源，并另行规定展示正文与可选操作。

两者不得重复定义或改写对方负责的字段。

逐项展示时，在 reference 正文前生成公共标题 ``## <当前位置>/<队列总数> — `<类型>` — <简短标题>``，例如 ``## 01/20 — `issue` — `--dry-run` 仍修改目标文件``。类型使用该条目持久化的 `类型` 值。位置和总数均按包含终态项的完整队列计算；两个数字使用相同宽度 `max(2, digits(队列总数))`，不足补零，例如 `001/125`。新增或拆分后重新计算；重开时使用原队列位置。这两个数字只由队列派生，不持久化、不改动稳定 ID；逐项展示不显示 `ITEM-001` 等稳定 ID。

展示前按当前 reference 的 `Item format` 检查 payload 内容归属与顺序，不改变原意；来源缺失的信息仍写 `unknown`。默认不展开 `来源原文` 和 `补充事实`，用户要求或识别出具体矛盾时展示相关片段。

不比较 typed projection 与 evidence stream 的语义等价性：创建时的压缩表达、已记日志的转类或拆分，以及根据新证据重建 projection，均是正常 divergence。仅当用户或 agent 识别出 projection 的具体断言与 evidence stream 矛盾时，才检查该逐字断言是否已被 `更正` / `撤回` 引用，或差异是否来自已记日志的转类 / 拆分；可解释时按追加顺序采用最新未撤回证据重建 projection，否则保持 `discussing`、文件不变并询问。本 Skill 保证 recoverability，不声称 typed projection 的 semantic fidelity 可机械证明。

展示前必要时仅只读检查当前条目直接相关的代码、测试、help 或 benchmark，以补足准确示例；不得扩展问题集合。首次展示或重开时按 reference 完整重述；用户追问按第 4 节直接回答。

标题下的首段应能独立说明条目。不得用抽象类别或风险术语代替可观察结果。按当前类型的 reference 直接写清触发或适用场景、当前结果和实际影响；不同类型不必使用相同字段。最后分析推荐方案或回答路径的收益、代价与不确定性。

精确数字、错误文本和当前行为必须有代码、测试、reproduction、benchmark 或实际观测支持。尚未验证的内容直接说明待验证的断言和缺少的依据，不输出固定等级标签，不把推测写成当前事实。无法形成可信对比或回答时，说明缺口并推荐“先验证”。

Effort 覆盖适用的验证、实现、测试和 review：`XS` <30 分钟；`S` 30 分钟–2 小时；`M` >2 小时–1 天；`L` >1–3 天；`XL` >3 天或需单独设计。`decision` 比较各选项的后续成本；没有后续工作写 `N/A`。

## 4. 记录与推进

- 只使用当前 reference 提供的操作。试做 → `discussing`；明确接受处理结论或选定方案 → `decided`；明确确认 `question` 的答案 → `answered`；Reject / 忽略 → `dismissed`；延后 → `deferred`。
- 进入下一项前记录结论或决定、理由、时间、Effort 和约束；有试做改动时，只在接受结果或安全回退后写入终态。
- “先验证”只授权验证当前条目，默认仅做只读检查。若验证除本 Skill 按既定流程写回清单文件外还会修改 worktree、外部状态或产生其他副作用，保持 `discussing` 并先请求当前条目范围内的明确授权；不得借此实施产品改动。
- 当前 reference 提供“试做当前项”时，该操作只授权实施并验证当前项：先在日志记录所选方案 / 选项、受影响路径及 worktree baseline，不 stage、commit 或 push，保持 `undecided`；完成后展示实际行为、diff、验证和未决风险。若不接受，明确确认后只回退本次试做改动；无法隔离时保持 `discussing` 并询问。
- 追问、质疑、补充约束或未明确选择时直接回应，不推断决策，并保持 `discussing`。纯澄清不写文件；新增事实只追加到 `补充事实`，必要时重建 projection，并记一条日志；结论、推荐或范围变化时先说明原因，再只重述受影响的小节；否则不重复。
- 除当前项的显式试做外，本 Skill 不跟踪后续验证或实施。讨论中出现新条目或发现当前项含可独立决策的内容时，征得同意后以新 ID 追加为 `pending`；拆分时当前项保留原 ID 与 `discussing`、收窄 projection，并在当前项及新项的日志中记录各自范围变化。
- 仅在当前条目已讲清且没有未答问题时请求明确结论或决策；不同时展开下一项。

完成全部评审后，报告清单路径、各状态数量、已回答的疑问、已接受的试做、Accept 后续统一处理的工作及 Effort、Reject 或延后项、所选决策和推荐下一步。
