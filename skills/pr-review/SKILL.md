---
name: pr-review
description: "Review a pull request or a base-to-worktree diff for merge readiness — read-only. Acquire the changeset and its goal, delegate the core four-dimension code review to the adversarial-review skill, then add PR-specific judgment: value, testability, and ship readiness. Report findings in the core's material / non-material / tradeoff vocabulary and end with a Merge Verdict. Never edit files. Use when the user asks to review a specific PR (by id, branch, or the current branch's PR), or everything changed since a given base up to the working tree."
argument-hint: "[pr number/branch | base commit/branch]"
---

# PR Review

## 使用边界

本 skill 处理两类审查请求，只审查、不修改文件：

1. **PR 审查**：用户给出 PR id、指定分支，或当前分支已关联 PR。范围由该 PR 的 base / head OID 界定；除非已核验本地 `HEAD` 等于 PR head，否则不得用本地 `HEAD` 代替。
2. **base→工作树 审查**：用户给出一个 base（commit 或分支），审查从该 base 到当前文件状态的全部 diff，含已提交、staged、unstaged 与未跟踪新文件。

不属于这两类的请求（如泛泛「看看这段代码」），先确认能否归入其一；否则说明本 skill 不适用——无取材边界的纯代码审查直接用 `adversarial-review` skill。

## 定位

pr-review 是**纯审查器**：判断这些改动是否以足够小、足够清晰、足够可验证的方式解决了真实问题，且没有引入不合理风险与合入障碍。

四维度代码审查（鲁棒性、克制、风格、简洁）、material 判定与 finding 契约整块**委派**给 `adversarial-review` skill，本 skill 不复述其判据。pr-review 只负责核心不覆盖的部分：取材、目标与价值判断、合入就绪、Merge Verdict，并沿用核心的 `material / non-material / tradeoff` 词表，不引入平行 severity。

## Workflow

### 1. 取材

- **先筛路径，再读内容**：先用不返回 patch / content 的 rename-aware metadata 取得完整 old / new path 清单，排除全局 Security 红线禁止读取的 secret 路径（非 template `.env*`、`.ssh/`、`.git-credentials` 等），再加载允许路径的 diff。禁止路径删除若无法与 rename 可靠配对，同时存在任意未配对 addition / untracked path，则不读取新增内容：base→工作树模式要求 staged rename 或 sanitized changeset，PR 模式要求 sanitized changeset。不得先运行 bulk diff 再过滤；装入内容中意外出现的疑似 secret 立即 mask。
- **Git 输入安全**：在进程内将用户给出的 base 与 `^{commit}` 拼成一个 revision，作为单一 argv 传给 `git rev-parse --verify --end-of-options`，解析为 immutable `baseOID`；失败即停止。后续每个 revision、OID 与 path 都作为独立 argv 传递，绝不拼接进 shell command；路径经 NUL-safe loop 处理，并用 `git --literal-pathspecs` 与 `--no-ext-diff --no-textconv` 禁止 pathspec magic、external diff 和 textconv。
- **PR 模式**：从同一 PR snapshot 取得描述、关联 issue、base / head OID，以及分页的 `path` / change type metadata；分页期间 OID 变化则丢弃并重取，metadata 数量必须等于 provider 报告的 changed-file 总数。diff 必须固定到这组 OID，不得再次按可变 PR ref 取材，也不得用其他 checkout 的本地 `HEAD` 代替；逐路径记录完整 diff 或明确的 binary 状态，任何遗漏、截断或 provider limit 都视为取材失败。若 metadata 不能安全给出 rename 的 old / new path、含禁止路径，或远端取材不完整，则仅在 base / head object 本地可用时，以 `baseOID...headOID` 的 rename-aware metadata 按允许路径读取；否则停止并要求 sanitized changeset。
- **base→工作树 模式**：用 `git --literal-pathspecs diff --no-ext-diff --no-textconv --name-status -z --find-renames <baseOID>` 与 `git --no-optional-locks status --porcelain=v1 -z --untracked-files=all` 取得完整的 NUL-delimited old / new path metadata，再逐个读取允许路径：已跟踪文件用 `git --literal-pathspecs diff --no-ext-diff --no-textconv <baseOID> -- <path...>`，未跟踪新文件用 `git --literal-pathspecs diff --no-index --no-ext-diff --no-textconv -- /dev/null <path>`（exit code `1` 表示存在 diff，不是执行失败）；忽略 `.gitignore` 排除项。若 rename 任一端是禁止路径，则不读取该文件内容。
- **worktree 一致性**：读取前后分别计算 path / status、old / new path 与允许文件 content identity 的 fingerprint；不一致说明取材期间发生 drift，丢弃本轮结果并从路径筛查重新开始。

### 2. 确认目标与价值锚点

- 从 issue / PR 描述提炼要解决的问题与 1-3 条成功标准：合入后应解决什么、不能改变什么。
- 该目标一物两用：既作第 3 步核心「确认目标」的传入值，又作第 4 步价值判断的基准。
- 目标不可见或存在会显著影响判断的歧义时，先向用户确认。

### 3. 委派四维度审查

- 以第 2 步成功标准为「确认目标」，invoke the `adversarial-review` skill 审查本次 changeset，收集其 findings（`material / non-material / tradeoff`）与终态信号（`Adversarial Review: Clean` / `Adversarial Review: User decision required`）。
- 对某一 changeset 状态**只 invoke 一次并报告**；本 skill 不修复、不「修完再 invoke」（那等于改文件）。作者推新 commit 后由用户重跑，即新的一遍，非内部修复环。

### 4. PR 专属判断

- **价值 / efficacy**：整套改动是否真正解决目标问题、有可观察价值——落到证据，不接受「更优雅」「以后会用到」。与核心克制区分：克制查「改动该不该在」，价值查「整体是否达成目标」；代码正确且在范围内，仍可能因未覆盖真正瓶颈而价值不足。
- **合入闸门**：测试可测性与 ship 就绪（feature flag、迁移顺序、灰度兼容）是否足以合入；不足则列为合入前要求或 follow-up。
- **范围处置**：核心判为 `Out of scope` 的改动应从当前 changeset 移除；若仍有独立价值，再放入 follow-up commit / PR。
- **foundation / refactor 改动**：要求点名后续会依赖的具体接口、模块边界或删除的复杂度，而非抽象地「为以后做准备」。

### 5. Merge Verdict

由两条正交轴共同决定，取更严一侧：

- **代码质量轴**（读核心终态，不重判 blocking-ness）：未 `Clean` 且有必须修复的 material issue ／ `User decision required`（待决 tradeoff，并保留核心的处理建议）／ `Clean`（无必须修复项，可含已接受 tradeoff 与 non-material）。
- **价值 / 合入轴**（pr-review 独有）：是否解决真问题、测试与 ship 是否足以合入。

映射：

- 有必须修复的 material issue、合入前必须补齐的测试 / ship 缺口，或核心对待决 tradeoff 建议 `Reject and revise` → 根因是局部缺陷 `Request changes`；根因是方向、架构或价值不足 `Needs redesign`。
- 无必须修复项，但有待用户明确接受的 tradeoff（核心建议 `Accept tradeoff`）或其他 merge prerequisite → `Conditional approve`，列出决策项与前置条件。
- `Clean` 且价值已确认，仅剩 optional non-material follow-up 或无 → `Approve`。

`Clean` 是 `Approve` 的必要非充分条件——它只清洁代码质量轴，价值/测试闸门可独立否决。`User decision required` 折叠为 verdict 的决策项，沿用核心「推荐 `Accept tradeoff` | `Reject and revise`」，不替用户拍板。

## 输出格式

findings 优先，除非用户要求摘要优先。每个 finding 按 `adversarial-review` 的 finding 要求给出（位置或受影响范围、触发条件、证据、影响、建议），并标注 `material / non-material / tradeoff`；本 skill 只额外呈现 Merge Verdict，不重定义 finding 字段。

未发现问题时写 `未发现阻塞问题。`，再说明残余的合入风险（人工验收、rollout、待补信息）。

最后必须输出：

```markdown
Merge Verdict: Request changes | Conditional approve | Approve | Needs redesign
理由：1-3 条，对应代码质量轴信号、价值判断、测试/范围缺口或明确的无阻塞结论。
```

## 示例（正反对比）

价值评估
- ✗「实现看起来没问题。」
- ✓「PR 加了缓存层，但慢路径来自数据库排序，缓存没覆盖该查询入口；核心性能问题没解决——即便核心审查判 `Clean`，合入价值仍不足，判 `Needs redesign`。」

范围约束
- ✗ 默认接受「顺手调整了按钮布局。」
- ✓「issue 只要求修复导出失败，按钮重排属无关 UI 变化，会影响截图测试与用户既有操作习惯；核心已判其 `Out of scope`，建议拆到单独 PR 而非并入本次。」

## 避免事项

- 不因改动较大就笼统反对；指出具体可拆边界与风险来源。
- 不因测试通过就停止审查；测试只降低风险，不替代范围与价值判断。
- 不把四维度判据、finding 字段或 severity 阶梯搬回本 skill——那是 `adversarial-review` 的职责。
