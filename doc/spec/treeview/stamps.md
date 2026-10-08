# Rust Treeview versioned tree state

Status: Design。适用于 Rust Treeview 的独立标记状态；文档入口见 [Treeview](README.md)。

本文定义 selection 与 expansion 共用的版本标记算法：子树继承、自身覆盖、单点查询及 topology 更新。
各状态的命令决定写入哪些节点与哪些 scope；算法只解释这些写入，不自动执行祖先修补或业务动作。
具体写入策略分别见 [selection](selection.md) 与 [expansion](expansion.md)。

## 独立状态与版本

Selection 与 expansion 各有独立的 generation、全局 `clear_stamp` 和节点标记。两种状态绑定同一份
Treeview state/topology，但不比较彼此的版本；共享完整 state 时分别共享这两份状态。

每次提交新的标记意图时，在该状态中分配一个单调递增的 generation `g`；同次批量操作共用它：

```text
stamp(g, value) = 2 * g + int(value)
```

偶数表示 false，奇数表示 true，较大值优先。新 generation 大于本状态所有已提交 generation；
清空不将它归零。共用算法使用两个默认值为 0 的节点标记输入，各状态只保存其实际写入的字段：

| 标记            | 作用域                                         |
| --------------- | ---------------------------------------------- |
| `subtree_stamp` | 节点自身与全部后代，沿 source parent 链继承    |
| `self_stamp`    | 仅节点自身，不传给后代；可以表示 true 或 false |

State 另存默认值为 0 的全局 `clear_stamp`，只写偶数。Selection 与 expansion 均保存 subtree/self 两个字段；
Selection 的 `recursive=false` 写 self，`recursive=true` 写 subtree，分别对应 SelfOnly/Subtree scope；
expansion 继续按其明确的 scope 写入。
“自身是否为 true”与“整棵子树是否为 true”是不同查询。

## 查询与基础写入

以下变量均来自同一种状态，例如全部来自 selection 或全部来自 expansion：

```text
inherited(n) = max(clear_stamp, subtree_stamp(a) for a in ancestors_including_self(n))
effective(n) = max(inherited(n), self_stamp(n))
value(n)     = (effective(n) & 1) == 1

assign_self(n, value, g):
    n.self_stamp = stamp(g, value)

assign_subtree(n, value, g):
    n.subtree_stamp = stamp(g, value)

clear_all(g):
    clear_stamp = stamp(g, false)
```

- 查询使用完整 source parent 链，不在 display root、折叠或过滤处截断。`self_stamp` 不进入传给
  children 的继承值；节点自身的选择、取消、展开或折叠只改变这个覆盖值。
- 两个写入 scope 各自只写目标节点的一个字段，不向严格祖先写入标记。Selection 与 expansion
  都按 action 的明确 scope 使用 `assign_self` 或 `assign_subtree`。祖先 full 的变化属于派生聚合。
- 同一 range 事务先确定 scope、去重及各目标的提交前状态，再写标记。共享 generation 的写入
  必须具有明确的组合结果，不用同版本的奇偶大小替代对相互冲突命令的解释。
- Owner 校验目标、版本和命令前提后，原子发布标记及关联状态；失败不发布部分写入，不调用借用内 callback。

## 同值赋值与 NoChange

显式赋值记录本次操作意图。`select_node`、`deselect_node` 与 `SetExpanded` 通过校验且存在适用目标时，必须向目标 scope
写入新 stamp；当前自身布尔值相同、目标子树已 full，或完整范围已满足目标值，都不能跳过写入。
新版本参与后续 reparent 的继承竞争；Subtree 写入还决定未加载及以后新增后代的继承。

- 同次批量操作完成目标校验、scope 筛选、去重与归并后，共用一个新 generation 写入全部适用目标，
  包括已满足目标值的项；不按当前布尔值筛掉同值目标。
- SelfOnly 只刷新目标的 self stamp，Subtree 只刷新目标根的 subtree stamp。无需为判定是否写入
  而加载后代；两种 scope 均按各自语义记录 true 或 false。
- 写入后返回 `Applied`，推进对应标记状态的 revision。Selection 写入推进 selection/state revision，
  expansion 写入推进 state revision；布尔值和两组集合未变也按实际写入发布。
- Layout revision、重绘与 children 请求按实际布局、展示和数据需求决定；stamp 更新本身不要求重绘
  或重新加载。新的 revision 仍须让依赖该状态的查询与缓存观察到。
- 这些标记命令的 `NoChange` 仅用于没有适用目标，例如空目标集合、对不可展开 leaf 的展开/折叠。
  它不写 stamp、不分配 generation，也不推进标记状态 revision。可展开的空目录属于适用目标。
- 节点失效、context 过期、锁冲突或容量不足按对应错误拒绝，不能当成 NoChange，也不能静默移除无效
  ID 后提交其余目标。整批校验和容量检查在任何写入前完成。
- 查询、聚合、重绘、children 结果接收和纯 mode 切换不生成新的标记意图。它们各自需要的数据、派生
  或 feature revision 按原契约发布，不为刷新 stamp 合成赋值命令。

## Reparent

在更换 parent 之前，对每份关联 Treeview state 的每一种标记状态分别计算：

```text
n.subtree_stamp = inherited(n)  # 使用本次操作前的 source parent 链
```

完成各状态的旧链继承值保存后，再在候选 topology 中更换 parent。

- 保存的是可向后代传递的 `inherited`，不是包含自身覆盖的 `effective`；`self_stamp` 原样保留。
- 不生成新 generation，不根据移动后的聚合结果补写祖先。移动后继续按新 parent 链查询，旧链继承值
  与新链的标记按版本竞争；并不保证节点的布尔值永远保持为移动前的值。
- 例如节点保存旧链的 `4` 后移入继承值为 `7` 的分支，结果为 true；若保存的是 `8`，则仍为 false。
- 同批多次 reparent 按 operations 顺序分别保存各自操作前的继承值，不用整批开始时的旧快照替代。
- 标记准备、topology 更新、失效清理与其他 state 补丁在同一批次发布；失败全部丢弃。

## 新增、补载与移除

- 新 NodeId 在各状态实际保存的 stamp 都从 0 开始，沿当前祖先链继承；新建与加载发现使用同一规则，不产生 generation。
- 补载已有 NodeId 保留标记。异步数据结果只提交数据事实，不重放请求开始时的标记或交互状态。
- Remove 才清理对应 NodeId 及被删除子树的标记；同名新节点没有旧 ID 的自身例外。
- 各状态中带非零标记的节点及必要结构 skeleton 必须保留。未知 children 不得藏有因缓存淘汰而丢失的
  非零例外；metadata/render cache 的释放不等于 Remove。

## 聚合与缓存基础

单点判断可沿完整 parent 链查询；遍历时只需向 child 传递当前 `inherited`，不重复走祖先链。
按一种状态缓存已知子树的：

```text
max_stamp(n) = max(
    subtree_stamp(n),
    self_stamp(n),
    max_stamp(c) for c in known_children(n)
)
s = max(parent_inherited, subtree_stamp(n))
```

若 `s >= max_stamp(n)`，该子树所有节点的原始布尔标记都等于 `s` 的奇偶值，包括尚未物化且默认
stamp 为 0 的后代。这能直接证明统一覆盖，无须为证明覆盖而加载它们。
否则需要考虑自身覆盖与已知后代例外；`self_stamp(n)` 不可作为传给后代的 `s`。

具体聚合输出由用途定义：selection 需要完整子树根、自身选取与 pending 计数；expansion 的布局
主要查询节点自身是否展开，并结合可展开属性和当前可见路径判断是否继续遍历。布尔覆盖可证明，
不代表 children 已加载或所需行已经全部生成。

- 缓存按标记状态分别保存；键包括结构/children revision、本状态的标记 revision 和传入 stamp。
  Global clear 通过新传入值失效缓存；generation 与表示解释变化的 revision 分开。
- 标记写入使相关节点与祖先缓存失效；reparent 使旧/新祖先路径失效。失效与重算只改变派生信息。
- 使用迭代 DFS/postorder，每层保留 child cursor；同次遍历不重复计算相同输入，不保存完整祖先前缀数组。

## 成本与容量

`H` 为树高，`N` 为本次访问的已知节点数：

| 操作                                     | 标记核心成本               |
| ---------------------------------------- | -------------------------- |
| 自身赋值、子树赋值、全局清空             | `O(1)` 写入                |
| 单点完整链查询、每种状态的 reparent 保存 | `O(H)`                     |
| 携带继承值的已知结构遍历                 | `O(N)` 时间、`O(H)` 遍历栈 |

祖先路径上的缓存失效、具体命令的额外写入、结构索引、IO、文本生成和 UI 发布分别计费。
例如 selection 的子树取消只需一次 stamp 写入，但仍需沿祖先链失效相关聚合缓存；这些失效不改写祖先标记。

Selection 与 expansion 的每个有标记节点各保存两个 `u32`（8 bytes），
不含索引和缓存。两种状态都需要记录时分别计费。31 位 generation 上限为 `2^31 - 1`；递增与编码使用 checked 运算，
溢出在任何写入前失败并保留原状态，禁止回绕。

## 验证要求

- 惰性查询与逐节点参考状态在自身赋值、子树赋值、全局清空及交错操作后等价。
- 同值 true/false 赋值写入新 stamp；验证后续 reparent 的版本竞争及新节点的 scope 继承。
- 验证同值与变值目标混合的批量写入、单一 generation、NoChange 的无写入，以及拒绝/溢出前的整批校验。
- 标记 revision 随同值写入推进；展示未变化不强制重绘，查询、重绘与纯 mode 切换不刷新标记。
- Selection 的自身 action 只修改 self，递归 action 只修改 subtree；两者都不改变严格祖先的权威标记。
- 祖先的自身覆盖不传给后代；较新子树赋值覆盖较旧的自身例外，较新的自身例外覆盖旧继承值。
- Reparent 只保存 inherited：包含较新自身 true/false 的节点移动后，不把该自身值传播给后代。
- 验证新增、补载、移入/移出、同批多次移动、Remove、独立状态及失败/溢出的原子性。
- 验证统一覆盖快捷判断、混合版本遍历、未知 children 的默认继承，以及深树的迭代遍历。
