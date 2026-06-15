---
name: pr-review
description: Review a pull request or a base-to-worktree diff with emphasis on risk, code polishing, scope control, value, testability, and merge readiness. Use when the user asks to review a specific PR (by id, branch, or the current branch's PR), or to review everything changed since a given base commit/branch up to the current working tree.
argument-hint: "[pr number/branch | base commit/branch]"
---

# PR Review

## 使用边界

本 skill 处理两类审查请求：

1. **PR 审查**：用户给出具体 PR id、指定分支，或当前分支已关联 PR。base 取该 PR 的 merge target，审查范围是 PR 引入的提交（`base...HEAD`）。
2. **base→工作树 审查**：用户给出一个 base（commit hash 或分支），要求审查从该 base 到当前文件状态的所有 diff。范围含已提交、staged、unstaged 改动，以及未跟踪新文件。

不属于这两类的请求（如泛泛「看看这段代码」），先确认它能否归入其一，否则说明本 skill 不适用。

目标不是泛泛表扬或格式检查，而是判断：这些改动是否以足够小、足够清晰、足够可验证的方式解决了真实问题，且没有引入不合理风险。

## 审查原则

1. 风险优先：先找可能导致 bug、行为回归、兼容性问题、性能退化、安全/数据风险、发布风险或隐藏 side effect 的改动。
2. 证据驱动：每个 finding 给出具体代码位置、触发条件、证据、影响和建议。没有最小复现时，说明触发路径、证据和影响范围。
3. 简洁必要：识别无用代码、重复逻辑、过度抽象、绕路实现和臃肿改动；只有能降低真实复杂度的抛光建议才升级为 `Should Fix`。
4. 行为优先于 diff 表面：对关键改动追踪 input、state、output、error path 和 side effect，对比新旧行为，而不是只读 diff 表面。
5. 范围与价值约束：改动必须能映射到 issue/PR 目标或必要验证；无法映射又不够小的改动建议拆 follow-up。价值声明要落到可观察证据，不接受「更优雅」「以后会用到」式空泛声明。

## 工作流

1. 获取审查对象
   - 先判定属于哪一类：
     - **PR 审查**：用户给出 PR id、分支名，或要求审查当前分支的 PR。用 `gh` 取材：`gh pr view <n>`（含描述、关联 issue）、`gh pr diff <n>`（diff）；当前分支的 PR 用 `gh pr view`（不带号，自动解析当前分支）。base = 该 PR 的 merge target（`gh pr view <n> --json baseRefName`），不要臆测。审查范围是 PR 引入的提交，即 `base...HEAD`。
     - **base→工作树 审查**：用户给出 base（commit hash 或分支）。取材覆盖到当前文件状态：
       - 已提交 + 已跟踪的未提交改动：`git diff <base>`（含 staged 与 unstaged）。
       - 未跟踪新文件：`git status --porcelain` 取 `??` 行，逐个 `git diff --no-index /dev/null <path>` 读入（与 git-commit 一致）；忽略被 `.gitignore` 排除项。
   - 若 issue 或目标可见，先提炼 1-3 条成功标准：合入后应解决什么、不能改变什么。
   - secret 处理：diff 或文件内容中出现 secret，mask 具体值并把 secret leak 作为 finding；若 review 范围涉及 secret-looking 路径（如 `.env*`、`.ssh/`、credential/request dump），按全局安全规则停止，不读取其内容。

2. 意图/范围映射
   - 把每类改动映射到 issue、PR 描述或成功标准，按三类归档：
     - In scope：直接服务 issue/目标/必要验证。
     - Supportive：不直接解决问题，但很小、收益明确、风险极低（如同一代码路径上的 typo、补齐缺失 fixture）。
     - Out of scope：无法映射，或扩大行为面/评审面/测试面/发布风险；通常建议拆到后续提交或独立 PR。
   - 对 foundation/refactor 类改动，要求指出后续工作会依赖的具体接口、模块边界或删除的复杂度，而非抽象地「为以后做准备」。

3. 建立改动地图
   - 按功能代码、测试、配置、迁移、文档、生成物分类。
   - 标记高风险区域：公共 API、权限/认证、计费、数据写入、并发、缓存、迁移、构建发布配置、跨模块共享逻辑。

4. 按行为路径审查关键改动
   - 输入：入口、参数、权限、环境变量、配置、用户操作是否变化。
   - 状态：缓存、数据库、内存、并发、UI state 是否有新的读写路径。
   - 输出：返回值、渲染、事件、日志、通知、外部调用是否符合预期。
   - 错误路径：异常、空值、超时、重试、部分失败、回滚是否被处理。
   - Side effect：后台任务、迁移、网络请求、文件写入、跨模块调用是否扩大影响面。

5. 给出合入判断
   - 用 `Blocker`、`Should Fix`、`Nit`、`Question` 标记 findings。
   - 输出 `Merge Verdict`：`Request changes`、`Conditional approve`、`Approve` 或 `Needs redesign`，理由必须对应 findings、测试缺口、范围偏差或价值判断。

## 输出格式

优先输出 findings。除非用户明确要求摘要优先，否则不要把总结放在问题前面。

每个 finding：

```markdown
- [Severity] 文件路径:行号 - 简短标题
  问题：具体说明哪里不对。
  证据：引用 diff、现有行为、issue 要求或触发路径。
  影响：用户、系统、数据、维护或发布层面的后果。
  建议：可执行的修改方向；若需拆分，说明拆到后续提交或独立 PR 的边界。
```

Severity：

- `Blocker`：合入会造成明确错误、严重风险、价值缺失或明显偏离 issue。
- `Should Fix`：建议合入前修复，风险或维护成本真实但不一定阻断所有场景。
- `Nit`：低风险抛光，不能夸大成阻塞。纯风格偏好、等价写法、轻微命名偏好通常只能是 Nit，且不能要求大范围重写。
- `Question`：需作者澄清的设计/范围/行为问题，要有具体依据。

未发现问题时明确写 `未发现阻塞问题。`，然后说明残余的测试缺口、风险或人工验收建议。

最后必须输出：

```markdown
Merge Verdict: Request changes | Conditional approve | Approve | Needs redesign
理由：1-3 条，对应 findings、测试缺口、范围偏差、价值判断或明确的无阻塞结论。
```

- `Request changes`：存在 blocker 或合入前必须修复的真实风险。
- `Conditional approve`：无 blocker，但有明确 follow-up、验证缺口或小范围修改要求。
- `Approve`：未发现阻塞问题，范围、价值、验证都足够清楚。
- `Needs redesign`：问题主要来自方向、价值、范围或架构边界，无法靠局部 patch 修好。

severity → verdict 映射（取最高档）：

- 有 `Blocker`：`Request changes`（若根因是方向/范围/架构而非局部缺陷，则 `Needs redesign`）。
- 无 `Blocker`、有 `Should Fix`：`Conditional approve`，把这些 `Should Fix` 列为合入前的小范围修改要求。
- 仅剩 `Question` 未决：默认 `Conditional approve` 并列出待澄清项；仅当澄清结果可能推翻设计、不澄清就无法判断能否合入时，才用 `Request changes`。
- 只剩 `Nit` 或无 finding：`Approve`。

收敛判断（反复执行时）：当某轮无新增 `Blocker`/`Should Fix`、仅剩 `Nit` 或可选打磨时，显式声明「已达可合入收敛点，剩余为可选项」，不要为了找问题而继续升级 Nit；是否继续打磨交由我决定。

若对当前结论仍不够满意（如证据不足、范围存疑、价值待确认），在末尾补一条简要的下一步建议（需要补的信息、可拆的边界或待验证的点），供我判断后再决定。

## 示例（正反对比）

风险评估
- ✗「这里可能有问题。」
- ✓「API 返回 empty array 时，新逻辑跳过清空状态，页面继续展示上次结果。触发路径是 `loadItems -> setItems` 没在空结果分支执行，用户会看到过期数据。」

代码抛光
- ✗「这里可以优化。」
- ✓「新增 helper 只被调用一次，把 3 行直线逻辑拆到远处，增加跳转成本但无复用收益。建议内联。」

范围约束
- ✗ 默认接受「顺手调整了按钮布局。」
- ✓「issue 只要求修复导出失败，按钮重排属无关 UI 变化，会影响截图测试和用户既有操作习惯，建议拆到单独 PR。」

价值评估
- ✗「实现看起来没问题。」
- ✓「PR 加了缓存层，但慢路径来自数据库排序，缓存没覆盖该查询入口；核心性能问题没解决，合入价值不足。」

行为路径
- ✗「错误处理看起来不完整。」
- ✓「token refresh 超时时直接返回 cached user，但没标记 auth stale。后续写操作仍带旧 token，触发 401 重试循环。建议在 timeout path 清理 session 或进入重新登录。」

## 避免事项

- 不要把个人风格偏好包装成阻塞问题。
- 不要只罗列 diff，要分析行为和维护影响。
- 不要因为改动较大就笼统反对；指出具体可拆边界和风险来源。
- 不要因为测试通过就停止审查；测试只降低风险，不替代范围和价值判断。
- 不要建议无关大重构，除非它是修复当前改动风险的最小必要改动。
