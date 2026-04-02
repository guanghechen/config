---
name: arch-gate
description: Enforce architecture-first workflow for medium/large tasks with Dataflow State Machine, Interaction Lifecycle Model, and Minimal Core plus Plug-in Architecture constraints.
---

# Architecture Governance Skill

## 何时使用

触发策略：

1. 默认触发：新 feature 或 non-trivial refactor，进入实现前默认 follow `arch-gate`。
2. 例外触发：tiny scoped change 可以跳过，但必须先给出明确理由。
3. 显式触发：当用户明确要求使用该 skill 时，立即启用。
4. 不确定触发：当任务边界不清且存在架构风险时，先询问用户是否启用。

高风险信号示例：

1. 跨模块边界变更。
2. 依赖方向变更或潜在循环依赖。
3. plugin lifecycle 或插件装配机制变更。

默认 spec 目录约定：`<REPO_ROOT>/spec/feat/<feature>/`。

目录结构约定：

```text
<REPO_ROOT>/spec/feat/<feature>/
  arch.md    # final design: Interaction + Plugin
  flow.md    # final design: Dataflow State Machine
  draft.md   # 临时草稿，用于收敛问题与方案
  plan.md    # 临时计划，用于分解实现步骤
```

文件角色：

1. `flow.md`、`arch.md` 是 final design 文档。
2. `draft.md`、`plan.md` 是临时桥接文档，用于填平 final design 与 code 之间的 gap。
3. 实现完成后，`draft.md`、`plan.md` 应标记为完成或按项目约定清理。

final design 表达约束：

1. `flow.md`、`arch.md` 中的结论必须清晰、明确、可执行。
2. 禁止在正文中散落 `TBD/TODO/待定`；所有待定项必须统一收敛到专门 section。
3. 待定项 section 需要记录 `topic/options/owner/deadline/blocking/decision_rule`。

## 强制流程

1. 禁止先实现后建模。
2. 先建立 feature spec 目录：`<REPO_ROOT>/spec/feat/<feature>/`，并创建 `draft.md`。
3. 在 `draft.md` 收敛关键分歧、风险与边界，再定稿 `flow.md` 与 `arch.md`。
4. 在 `flow.md` 产出 `Dataflow State Machine`。
5. 在 `arch.md` 产出 `Interaction Lifecycle Model` 与 `Minimal Core + Plugin Contract`。
6. 基于 final design 生成 `plan.md`，拆分实现步骤、验收标准与回滚策略。
7. 通过检查清单后，才允许进入实现阶段。

## 必填输出 0: `draft.md`（临时草稿）

文件路径：`<REPO_ROOT>/spec/feat/<feature>/draft.md`

建议结构：

```md
# <feature> Draft

## 1. Problem Statement

## 2. Context and Constraints

## 3. Open Questions
| Question | Options | Decision | Rationale |
|----------|---------|----------|-----------|

## 4. Risk Notes
| Risk | Trigger | Evidence | Impact | Mitigation |
|------|---------|----------|--------|------------|

## 5. Draft Decisions
```

规则：

1. `draft.md` 只记录收敛过程，不替代 final design。
2. 未收敛问题不得直接进入实现。
3. 关键取舍必须记录 rationale。

## 必填输出 A: `flow.md`（Dataflow State Machine）

文件路径：`<REPO_ROOT>/spec/feat/<feature>/flow.md`

建议结构：

```md
# <feature> Flow Spec

## 1. Scope

## 2. Boundary
- Input Boundary:
- Output Boundary:

## 3. Dataflow State Machine
### States
| State | Owner                | Read Set  | Write Set | Side Effects |
|-------|----------------------|-----------|-----------|--------------|

### Transitions
| From  | To    | Trigger            | Guard          | On Failure               |
|-------|-------|--------------------|----------------|--------------------------|

## 4. Failure Path
- retry:
- rollback:
- degrade:
- abort:

## 5. Invariants

## 6. Test Matrix

## 7. Open Decisions（唯一待定区）
| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
```

规则：

1. 每个 state 必须有唯一 owner。
2. 数据流向必须单向、可追踪，不得出现隐式共享写入。
3. 失败路径必须显式且可测试。
4. 除 `Open Decisions` 外，不得出现 `TBD/TODO/待定`。
5. 一个 `Dataflow State Machine` 仅描述一个主数据实体或一条主数据流，不得混合多个主流程。
6. 仅当发生语义变化（owner 变化、持久化语义变化、失败策略变化）时，才应新增 state；实现细节步骤不应强制建 state。
7. 模块生命周期与调用协议属于 `arch.md` 的 `Interaction Lifecycle Model`，不得混入 `flow.md`。
8. `Open Decisions` 中若存在 `Blocking=true` 且未决项，禁止进入实现阶段。

## 必填输出 B: `arch.md`（Interaction + Plugin）

文件路径：`<REPO_ROOT>/spec/feat/<feature>/arch.md`

建议结构：

```md
# <feature> Architecture Spec

## 1. Module Boundary (SRP)
| Module | Responsibility        | Public Ports      | Private Runtime         |
|--------|-----------------------|-------------------|-------------------------|

## 2. Dependency Graph
- one-way dependencies:
- forbidden reverse dependencies:

## 3. Interaction Lifecycle Model
### Lifecycle
- init:
- start:
- stop:
- dispose:

### Interaction Transitions
| From  | To    | Event              | Guard          | Timeout        | Error Handling             |
|-------|-------|--------------------|----------------|----------------|----------------------------|

## 4. Interface Contracts
| Port          | Input               | Output              | Idempotency | Timeout        | Error Contract        |
|---------------|---------------------|---------------------|-------------|----------------|-----------------------|

## 5. Minimal Core + Plugin Contract
### Minimal Core
- baseline capabilities:
- works without optional plugins: true

### Plugin Contract
- manifest fields: name/version/capabilities/compatibility
- lifecycle hooks: onLoad/onStart/onStop/onUnload
- failure isolation: timeout_guard/circuit_breaker/safe_fallback

## 6. Observability and Degrade Strategy

## 7. Open Decisions（唯一待定区）
| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
```

规则：

1. 依赖方向必须单向。
2. feature 集成必须 interface-only。
3. 模块内部运行必须自治。
4. core 必须可独立运行。
5. plugin 必须支持 load/unload，且故障不得导致 core 崩溃。
6. 除 `Open Decisions` 外，不得出现 `TBD/TODO/待定`。
7. `Open Decisions` 中若存在 `Blocking=true` 且未决项，禁止进入实现阶段。

## 必填输出 C: `plan.md`（临时实现计划）

文件路径：`<REPO_ROOT>/spec/feat/<feature>/plan.md`

建议结构：

```md
# <feature> Implementation Plan

## 1. Scope Mapping
| Design Ref      | Design Source | Code Target      | Test Target      |
|-----------------|---------------|------------------|------------------|

## 2. Work Breakdown
| Step | Design Ref      | Change Area | Inputs | Outputs | Verification | Code Target      |
|------|-----------------|-------------|--------|---------|--------------|------------------|

## 3. Acceptance Criteria

## 4. Rollback Plan

## 5. Progress
| Step | Status | Notes |
|------|--------|-------|
```

规则：

1. `plan.md` 必须从 `flow.md` 与 `arch.md` 映射而来，不得脱离 design。
2. 每个 step 必须包含 `design_ref` 与 `code_target`。
3. 每个 step 必须可验证。
4. 必须有 rollback plan。

## 可选附录：Machine-readable Block

如果需要做自动化校验或生成测试，可在 `flow.md` / `arch.md` 末尾附加 `YAML` block。默认以 Markdown spec 为主，`YAML` 仅作补充。

## Go/No-Go 检查清单

仅当以下问题全部为 yes 时，才可进入实现：

1. state machine 中的数据 owner 是否全程清晰且无歧义。
2. 是否存在跨模块直接访问内部状态。
3. 依赖方向是否单向且无环。
4. 无可选 plugin 时 core 是否可独立运行。
5. plugin 故障是否可隔离并 graceful degradation。
6. public port 是否定义 timeout 与 error contract。
7. 是否已在 `spec/feat/<feature>/flow.md` 与 `spec/feat/<feature>/arch.md` 完成落档。
8. 是否已在 `draft.md` 收敛关键分歧，并在 `plan.md` 建立实现映射。
9. final design 是否清晰明确，且所有待定项仅存在于 `Open Decisions` section。
10. `Open Decisions` 是否不存在 `Blocking=true` 的未决项。

## 默认决策原则

1. 优先稳定边界，而非短期便利。
2. 优先 interface 兼容，而非内部优化。
3. 优先故障隔离与可恢复，而非功能覆盖最大化。
