# Rust Treeview display roots

Status: Design。适用于 `yoz.ux.treeview`；文档入口见 [Treeview](README.md)。

本文定义 Treeview 的显式展示范围，以及 topology 更新后的顶层入口归并。

## 显式范围与派生入口

- `ChildrenOf(root)` 从当前 root 的直接 children 开始展示，root 自身隐藏；不保存一份独立的 children 名单。
- `Forest(ids)` 保存调用方显式指定的有序 NodeId 列表。它表示持续浏览这些节点及其子树的意图，
  不要求它们一直位于 data forest 的最顶层。
- State 只保存一份权威范围。实际用于遍历的 `display_roots` 根据该范围与当前 topology 派生，
  可以缓存，不能独立设置；它与 selection 的 `subtree_roots` 分属不同语义。
- 创建 state 或显式 `SetRoot` 时，校验 ID 的实例与存活性；`Forest` 输入有重复项时返回 `InvalidUpdate`。
  显式入口允许祖先重叠，统一通过下述规则归并。无祖先重叠是派生 display roots 的约束，
  当前保存的合法范围可以直接用于创建另一份 state，不因既有祖先覆盖关系而被拒绝。

对 `Forest(ids)`，在当前 topology 上计算：

```text
live_ids = [n for n in ids if alive(n)]
display_roots = [
    n for n in live_ids
    if no other m in live_ids is a strict ancestor of n
]
```

- 保留未被覆盖入口在 `ids` 中的相对顺序。被覆盖的入口不占额外行，它作为实际后代使用 source
  的 children 顺序、展开/折叠及过滤规则展示。
- 归并先于折叠、过滤与压缩；祖先被折叠或过滤，不会使后代重新成为独立顶层入口。
- 只从显式入口中取最外层节点，不补入它们的共同祖先或其他未指定资源。
- 当前被另一入口覆盖的存活 ID 仍保留在 `ids` 中。其祖先关系解除后，自动按原入口顺序恢复。

## 节点更新与发布

1. Data owner 按既定顺序在私有候选 topology 上解释整批 operations，并准备各份 state 的标记补丁。
2. 在整批更新的最终 topology 上，清理已被 `Remove` 的显式入口，再派生各份 state 的 `display_roots`。
   中途出现的祖先重叠不会删除显式入口，也不会让合法的 reparent 返回 `InvalidUpdate`。
3. 将 data、显式范围清理及派生状态与其他 state 补丁同批发布；失败时全部丢弃，不发布中间布局。

共享 data 的独立 states 分别使用自己的显式范围归并；共享完整 state 的 views 共用同一结果。
State 的范围及派生状态变更遵循现有 revision 协议，布局 revision 同时考虑行映射、导航和 source
祖先索引。Snapshot 保留对应提交的显式范围及派生顶层结构，Lua 不用最新 topology 修补旧 frame。

Reparent 对 selection 的影响仍由 [selection 契约](selection.md) 定义；展示归并本身不生成
选择事务，也不将展示入口当作业务源项。普通光标按 NodeId 可见性恢复；Visual 中的 view 按
[圈选契约](visual.md) 延后展示布局变化，后台 data/state 正常提交。

## 入口生命周期

- 显式 `SetRoot` 替换保存的范围；之前未出现在新范围中的入口不保留为隐藏历史。
- 真正 `Remove` 的 NodeId 从 `Forest(ids)` 剔除，并通过既有节点失效与视图变化通知报告。
  同名新建节点具有新 ID，不自动继承原入口位置。
- 暂时未加载、loading/error、折叠或过滤都不使入口失效。显式 roots（包括被其他入口覆盖的项）
  及其必要祖先属于结构引用，不能因 render/metadata cache 淘汰而丢失 identity 或 parent 链。
- `Forest` 的入口全部失效后成为 `Forest([])`，展示为空；不自动选取新的资源范围。
- `ChildrenOf(root)` 的 root 被移除时展示为空并发出 `RootUnavailable`，由上层显式选择新 root。
  Root 仅发生 reparent 时仍按同一 NodeId 浏览其当前 children。

## 例子

用户显式设置 `Forest([A, B])`，A、B 初始互不包含；移动始终保留 NodeId：

| 更新       | 保存的显式入口 | 派生的 display roots | 展示                                  |
| ---------- | -------------- | -------------------- | ------------------------------------- |
| 初始       | `[A, B]`       | `[A, B]`             | A、B 分别作为顶层入口                 |
| B 移入 A   | `[A, B]`       | `[A]`                | B 只在 A 的子树中出现，服从折叠与过滤 |
| B 再移出 A | `[A, B]`       | `[A, B]`             | B 恢复原顶层入口位置                  |
| Remove B   | `[A]`          | `[A]`                | B 的入口失效                          |

若显式顺序是 `[B, C, A]`，B 移入 A 后得到 `[C, A]`，不把 A 提到 B 原来的位置；B 移出后恢复
`[B, C, A]`。若 A、B 一起移到未指定的 Q 下，仍从 A、B 开始展示，不把 Q 加入范围。

同一批次先把 B 移入 A、再移出 A，最终仍保存并展示 `[A, B]`。若要删除 A 并保留 B，须按节点
更新契约先将 B 移出，再 Remove A；最终显式范围保留 B。

## 验证要求

- 归并后的入口无重复、无祖先重叠；完整展开时，每个覆盖节点恰好遍历一次，范围等于显式子树的并集。
- 覆盖存活入口不修改 `ids`；反复移入/移出、多个入口形成祖先链后再拆开，均恢复原成员与顺序。
- 验证被覆盖入口的 Remove、移出后删除旧祖先、同名新 ID、全部入口失效及显式 SetRoot 替换。
- 验证同批临时重叠、批次失败、共享 data 下不同范围，以及折叠/过滤/压缩不改变祖先归并规则。
- 归并后的 cursor、Visual 延后发布与 selection 提交继续满足各自契约。
