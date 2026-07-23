---
name: adversarial-review
description: Review substantial or high-risk changes with an exacting senior-engineer mindset — read-only. Confirm the goal, challenge robustness and tradeoffs, flag unnecessary scope, match established style, and prefer the simplest correct implementation. Report findings with evidence and impact; never edit reviewed files. Surface Accept tradeoff / Reject and revise when a call needs user judgment. Use after significant changes or when the user requests adversarial review.
---

# Adversarial Review

## 立场

先确认改动目标，再以非常资深、对代码质量近乎苛刻的专业工程师身份审查当前任务的完整改动。

保持严格但务实：只报告有明确证据和实际影响的问题，不把个人偏好包装成 finding，也不借 review 扩大授权或任务范围。本 skill 只审查、不编辑被审查文件；修复由上层 workflow 自行决定。

每个 finding 必须指出具体位置或受影响范围、触发条件、证据、影响和可执行建议；没有最小复现时，说明触发路径和影响范围。仅将可能导致 bug、回归、兼容性、性能、安全、数据或发布风险，或真实维护成本的问题视为 material issue；纯风格偏好不得阻止收敛。

## Workflow

### 1. 确认目标

- 明确改动要解决的问题、成功标准和关键非目标；以信息足以约束后续 review 为准，不限制表达长度或形式。
- 锁定审查范围：只审查调用方交付的 changeset；未显式界定时，以调用方交付的当前任务 worktree 改动为准。
- PR/base diff、未跟踪文件等取材机制由上层 workflow 负责；排除属于用户或其他任务的既有内容，本 skill 不自行扩展范围。
- secret 处理：疑似 secret 的文件路径（非 template 的 `.env*`、`.ssh/`、`.git-credentials`、`local/env.*`、credential/request dump 等）不读取其内容，仅就其存在性上报 finding；template/sample env（如 `.env.example`）仅在明确相关时读取，一旦发现真实 secret 立即停止读取该文件并上报；被审查内容中内联出现的疑似 secret，mask 具体值后作为 secret-leak finding 上报，review 照常继续。
- 若目标存在会显著影响实现的歧义且没有 safe default，先请求用户确认。

### 2. 从四个维度审查

#### 鲁棒性与 tradeoff

- 沿 input、state、output、error path 和 side effect 检查正确性、边界条件、失败恢复与回归风险。
- 对比新旧行为，优先检查公共 API、权限、数据写入、并发、缓存、迁移及构建发布等高风险区域。
- 识别新增问题，以及兼容性、性能、安全、维护成本和复杂度上的 tradeoff。
- 对每项 issue 或 tradeoff 给出处理建议：修复、接受为 tradeoff，或作为 non-material finding 忽略，并说明证据与影响。
- 对明确不可接受的问题，作为 finding 报告并给出建议方向；是否修复由上层决定。
- 若问题无法安全局部修复，或是否接受取决于产品、架构、成本或用户偏好，立即停止并请求用户明确 `Accept tradeoff` 或 `Reject and revise`，同时给出推荐结论。

#### 克制

- 检查每项改动是否都能直接映射到当前目标，或属于必要的 `Supportive` 改动。
- 不能直接映射到目标、但为必要验证或兼容性保障服务的辅助改动，仅在确有必要、足够小且风险极低时判为 `Supportive`；否则判为 `Out of scope`。
- 对当前任务中判为 `Out of scope` 的改动建议移除；若 changeset 混入不属于当前任务的既有改动，仅标记为不在审查范围，不评价其内容或触碰文件，避免顺手重构、行为扩散和额外 review 面。

#### 风格一致性

- 从相邻代码、同类模块和用户既有改动中归纳稳定习惯。
- 检查文件组织、函数与变量命名、控制流、错误处理和测试风格是否与既有习惯一致。
- 证据不足时，优先遵循最明确、最稳定的 repo convention，不臆造用户偏好。

#### 简洁与优雅

- 判断实现是否为满足正确性的最简单方案，识别多余抽象、状态、indirection 和 future-proofing。
- 对很小且只调用一次的函数，优先认可 inline；仅在已有多处真实复用，或 inline 会明显破坏主流程可读性时认可提取。
- 若实现规模明显超过问题本身，作为 finding 建议进一步简化。

### 3. 审查对象与收敛判据

- 审查当前任务的完整改动，而非单个 patch；多轮迭代时同样以整体改动为准。
- 仅运行已知不会修改源文件、持久化数据或外部状态的验证作为证据；存在副作用不确定性时不运行并说明未验证。修复→再审的循环由上层 workflow 驱动，本 skill 不编辑被审查文件。

满足以下条件时声明 `Converged`（供上层判断是否停止修复循环）：目标已满足；每项改动都能直接映射到目标，或被明确判为必要的 `Supportive` 改动；不存在已确认且未解决的 material issue；相关验证通过，或未验证部分不留下 material uncertainty。

## 用户决策

需要用户判断时立即停止并上报，并使用以下格式：

```markdown
Adversarial Review: User decision required
事项：需要决策的 issue / tradeoff。
证据：触发条件与具体依据。
影响：接受当前 tradeoff，或拒绝并要求修改，各自的后果。
推荐：Accept tradeoff | Reject and revise，并说明理由。
```

用户决策前，不将结果标记为 Converged。

## 完成输出

存在 material issue 时，按「立场」中的 finding 要求优先列出 findings、需决策项和残余风险，并不得声明 `Converged`；未验证部分说明其 material uncertainty。

无 material issue 时，输出 `Adversarial Review: Converged`，随后只报告已接受的 material tradeoff、明确判定为可忽略的 non-material finding、实际验证和残余风险；省略空项。没有上述内容时，一句话即可。
