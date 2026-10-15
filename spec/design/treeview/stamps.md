# Treeview 版本标记

Status: Design。本文定义 selection 与 expansion 共用的版本标记算法：子树继承、自身覆盖、单点查询与 topology 更新；
文档入口见 [Treeview](README.md)，实现位于 `stamps.rs`。
各状态的命令决定写入哪些节点与 scope，算法只解释这些写入，不自动修补祖先或执行业务动作；
写入策略分别见 [selection](selection.md) 与 [expansion](expansion.md)。

## 独立状态与版本

Selection 与 expansion 各有独立的 generation、全局 clear 和节点标记。两种状态绑定同一份 State/topology，
但不比较彼此的版本；共享完整 State 时分别共享这两份状态。

每次提交新的标记意图时，在该状态中分配一个单调递增的 generation `g`，同次批量操作共用它：

```text
stamp(g, value) = 2 * g + int(value)
```

偶数表示 false，奇数表示 true，较大值优先。新 generation 大于本状态所有已提交 generation；清空不将它归零。

| 标记            | 作用域                                         | 代码              |
| --------------- | ---------------------------------------------- | ----------------- |
| `subtree_stamp` | 节点自身与全部后代，沿 source parent 链继承    | `Marks.subtree`   |
| `self_stamp`    | 仅节点自身，不传给后代；可以表示 true 或 false | `Marks.own`       |
| `clear_stamp`   | 整个状态，只写偶数                             | `Stamps.clear`    |
| `max_stamp(n)`  | 自身两个标记与已知后代的最大值，供聚合使用     | `Stamps::maximum` |

节点标记默认为 0，只保存实际写入的节点。`recursive=false` 写 self，`recursive=true` 写 subtree，
分别对应 SelfOnly/Subtree scope。“自身是否为 true”与“整棵子树是否为 true”是不同查询。

## 查询与基础写入

以下变量均来自同一种状态：

```text
inherited(n) = max(clear_stamp, subtree_stamp(a) for a in ancestors_including_self(n))
effective(n) = max(inherited(n), self_stamp(n))
value(n)     = (effective(n) & 1) == 1

assign_self(n, value, g):    n.self_stamp = stamp(g, value)
assign_subtree(n, value, g): n.subtree_stamp = stamp(g, value)
clear_all(g):                clear_stamp = stamp(g, false)
```

- 查询使用完整 source parent 链，不在 display root、折叠或过滤处截断。`self_stamp` 不进入传给 children 的继承值。
- 两个写入 scope 各自只写目标节点的一个字段，不向严格祖先写入标记；祖先 full 的变化属于派生聚合。
- 同一事务先确定 scope、去重及各目标的提交前状态，再写标记；共享 generation 的写入必须有明确的组合结果。
- Owner 校验目标、版本和命令前提后，原子发布标记及关联状态；失败不发布部分写入。

## 同值赋值与 NoChange

显式赋值记录本次操作意图。`select_node`、`deselect_node` 与 `set_expanded` 通过校验且存在适用目标时，
必须向目标 scope 写入新 stamp；当前布尔值相同、子树已 full 或范围已满足目标值，都不能跳过写入。
新版本参与后续 reparent 的继承竞争；Subtree 写入还决定未加载及以后新增后代的继承。

- 同次操作完成目标校验、scope 筛选、去重与归并后，共用一个新 generation 写入全部适用目标，包括已满足目标值的项。
- SelfOnly 只刷新目标的 self stamp，Subtree 只刷新目标根的 subtree stamp，不为判定是否写入而加载后代。
- 写入后返回 `Applied`：selection 写入推进 selection 与 state revision，expansion 写入推进 state revision；
  布尔值未变也按实际写入发布。Layout revision、重绘与 children 请求按实际布局和需求决定。
- `NoChange` 仅用于没有适用目标，例如空目标集合、对不可展开 leaf 的展开/折叠；它不写 stamp、不分配 generation，
  也不推进 revision。可展开的空目录属于适用目标。
- 节点失效、context 过期、锁冲突或容量不足按对应错误拒绝，不当成 `NoChange`，也不静默移除无效 ID 后提交其余目标。
- 查询、聚合、重绘、children 结果接收和纯用途切换不生成新的标记意图。

## Reparent

在更换 parent 之前，对每份 State 的每种标记状态分别计算：

```text
n.subtree_stamp = inherited(n)  # 使用本次操作前的 source parent 链
```

完成各状态的旧链继承值保存后，再在候选 topology 中更换 parent。

- 保存的是可向后代传递的 `inherited`，不是包含自身覆盖的 `effective`；`self_stamp` 原样保留。
- 不生成新 generation，不根据移动后的聚合结果补写祖先。移动后旧链继承值与新链标记按版本竞争，
  例如保存 `4` 后移入继承值为 `7` 的分支，结果为 true；若保存的是 `8`，仍为 false。
- 同批多次 reparent 按 operations 顺序分别保存各自操作前的继承值，不用整批开始时的快照替代。
- 标记准备、topology 更新、失效清理与其他 State 补丁在同一批次发布，失败全部丢弃。

## 新增、补载与移除

- 新 NodeId 的 stamp 从 0 开始，沿当前祖先链继承；新建与加载发现使用同一规则，不产生 generation。
- 补载已有 NodeId 保留标记；异步数据结果只提交数据事实，不重放请求开始时的标记或交互状态。
- Remove 才清理对应 NodeId 及被删除子树的标记；同 key 的新节点没有旧 ID 的自身例外。
- 当前不淘汰 source 节点（未实现）；若引入淘汰，带非零标记的节点及其祖先结构不得被淘汰，
  约束见 [新增、补载与移除](module.md#新增补载与移除)。

## 聚合

单点判断沿完整 parent 链查询；遍历时向 child 传递当前 `inherited`，不重复走祖先链。

```text
max_stamp(n) = max(subtree_stamp(n), self_stamp(n), max_stamp(c) for c in known_children(n))
s = max(parent_inherited, subtree_stamp(n))
```

若 `s >= max_stamp(n)`，该子树所有节点的标记都等于 `s` 的奇偶值，包括尚未物化、默认 stamp 为 0 的后代，
无须为证明覆盖而加载它们。否则需要考虑自身覆盖与已知后代例外；`self_stamp(n)` 不可作为传给后代的 `s`。

`max_stamp` 随标记写入、reparent 与 Remove 沿祖先链增量维护。聚合结果可以缓存，但必须与逐节点查询等价；
缓存与失效只改变派生信息，不改写任何标记。具体聚合输出由用途定义：selection 的 summary 见
[selection](selection.md#覆盖判空与计数)，expansion 主要查询节点自身是否展开。布尔覆盖可证明，不代表 children 已加载。

## 成本与容量

`H` 为树高，`N` 为本次访问的已知节点数：

| 操作                                     | 标记核心成本                         |
| ---------------------------------------- | ------------------------------------ |
| 自身赋值、子树赋值                       | `O(1)` 写入，`max_stamp` 维护 `O(H)` |
| 全局清空                                 | `O(1)`                               |
| 单点完整链查询、每种状态的 reparent 保存 | `O(H)`                               |
| 携带继承值的已知结构遍历                 | `O(N)` 时间、`O(H)` 遍历栈           |

结构索引、IO、文本生成和 UI 发布分别计费。每个有标记节点每种状态保存两个 `u32`（8 bytes），不含索引；
两种状态都需要记录时分别计费。Generation 上限见[默认容量](action.md#默认容量)，递增与编码使用 checked 运算，溢出在任何写入前失败并保留原状态。
