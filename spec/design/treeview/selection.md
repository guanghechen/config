# Treeview selection

Status: Design。本文定义 selection 的状态、交互、聚合结果解释、判空与 Lua API；文档入口见 [Treeview](README.md)。
标记算法见 [stamps.md](stamps.md)，任务锁、源项准备与清理见 [tasks.md](tasks.md)；实现位于 `state.rs` 与 `stamps.rs`。
按键、用途与源项选择等业务规则由 consumer 定义，例如 [Explorer 标记与用途](../feat/explorer.md#标记与用途)
与[多选 List](results.md#多选-list)。

## 状态与派生集合

Selection 使用[共用版本标记算法](stamps.md)：自身 action 只写 `self_stamp`，递归 action 只写 `subtree_stamp`，
ClearSelection 写全局 `clear_stamp`。`marked(n)` 由节点的 self stamp、自身与祖先的 subtree stamp 及全局 clear 按版本决定；
`full(n)` 表示自身及全部后代均选中，包括未加载、折叠和隐藏的后代。

Selection 按覆盖范围分解为两个集合：

| 集合              | 含义                                           |
| ----------------- | ---------------------------------------------- |
| `subtree_roots`   | 整棵子树全选的最外层根，每项代表自身及全部后代 |
| `self_only_nodes` | 自身选中、但未被上述完整子树覆盖的节点         |

```text
M = { n | marked(n) }
R = subtree_roots = { n | full(n) 且没有 full 的严格祖先 }
C = union(descendants_including_self(r) for r in R)
I = self_only_nodes = M - C
M = C ∪ I,  C ∩ I = ∅
```

等式描述完整逻辑选区；pending 时只返回已知部分，不把已知集合当作完整的 M。

- `subtree_roots` 之间没有祖先/后代重叠，两组不会重复表示同一节点。
- `self_only_nodes` 可以包含某个 `subtree_roots` 根的祖先，该祖先只代表自身；不能合并两组后按祖先归并为递归操作源。
- 分类依据覆盖范围而非节点类型：选中的独立 leaf 或已知空分支也进入 `subtree_roots`，即使由自身 action 选中。
  分类不把 self stamp 改写为 subtree stamp，空分支以后新增的 child 仍只继承 subtree 标记。
- 两组由同一份 stamp 与当前 topology 按需派生，不是两份可独立写入的选区，也不要求物化完整子树的全部后代。

### 用途

`selection_purpose` 是 consumer 解释的不透明字符串，由 native consumer 在 owner 提交中设置并与 selection 原子发布；
Lua 没有写入入口。纯用途切换只推进 state revision，不写 stamp，也不推进 selection revision。
ClearSelection 清除用途；投影或查询确认选区精确为空（两类数量为 0 且无 pending）且未持锁时也清除。
`state:status()` 与 Frame header 返回已提交的用途；旧 Frame 继续描述自身画面，任务使用锁定期间已提交的用途。

## 标记与交互

公开 action 为 `select_node`、`deselect_node` 与 `toggle_node`。`recursive` 的类型约束见[命令](module.md#命令)；
scope 由调用方显式给出，不按 consumer、节点类型或输入设备推断。

| Action          | 目标布尔值          | `recursive=false`       | `recursive=true`          |
| --------------- | ------------------- | ----------------------- | ------------------------- |
| `select_node`   | `true`              | SelfOnly：`assign_self` | Subtree：`assign_subtree` |
| `deselect_node` | `false`             | SelfOnly：`assign_self` | Subtree：`assign_subtree` |
| `toggle_node`   | 提交前 `!marked(n)` | SelfOnly：`assign_self` | Subtree：`assign_subtree` |

- 输入为显式 NodeIds 或实际 Frame 的行范围。自身 action 只去重，不丢弃同时输入的父/子节点；递归 action 按 source
  关系归并为最外层根。Scope 在入队时固定；同次 action 的目标值都从提交前状态读取，共用一个 generation。
- `toggle_node` 必须携带捕获的 Frame；提交时各目标的 `marked` 与该 Frame 不一致则返回 `Stale`。
  行范围的身份与归并校验见 [Visual 提交](visual.md#提交圈选)。
- 同值赋值同样写入新 stamp 并返回 `Applied`，只有无适用目标时返回 `NoChange`，见[共用命令规则](stamps.md#同值赋值与-nochange)。
- 持锁期间的拒绝规则见[锁](tasks.md#锁)；任务成功项只经[任务清理](tasks.md#成功项清理)取消。
- 哪些输入触发选择、哪些节点接受选择由 consumer 决定；同一 State 可交错使用两种 scope，不切换或重置 selection 模型。

写入语义：

- 自身 action 不修改后代已有选择，也不为未来后代提供继承值；它不表示“只留下自身”。
- 递归 action 覆盖未加载和以后新增的后代；较新的 subtree 标记覆盖旧的 self 例外，较新的 self 例外只覆盖自身。
- 祖先与旁支的权威标记保持原值，祖先的 `full`、计数和缓存按后代新状态重新派生；children 全选不会补写祖先。
- 两种 toggle 都按 `marked(n)` 而非 `full(n)` 决定目标值：`self_only_nodes` 中的节点在 `recursive=false` 时取消自身，
  `recursive=true` 时取消整棵子树。
- 取消某个子树后，原已选祖先变为 `marked=true, full=false`，退出 `subtree_roots` 并由 `self_only_nodes` 表示。
- Reparent 保存旧链继承值，不分配 generation、不补写祖先，见 [stamps.md](stamps.md#reparent)。
- 导航、display root、排序、过滤、折叠、压缩和 Tree/List 切换不改变选择标记。

Surface 分别表达自身是否选中与子树是否完整：`marked && !full` 显示为“仅自身选中”，只有后代选中的连接祖先不显示为已选。

### Selected-only 与 hidden

Selected-only 开启时采用 `selected > hidden`：hidden 过滤不参与投影，保留自身或后代有选择（含 pending）的节点及连接祖先。
显式 filter 下的 List 不额外加入连接祖先，成员规则见 [Tree/List 投影](projection.md#tree-与-list)。

- 祖先只作为连接路径时不因此显示为已选；完整选中目录内的隐藏后代继承选择，被反选的项仍按实际 selection 过滤。
- 仍遵守 display roots 与 Tree 折叠状态，不为展示已选项自动展开目录；pending 范围保留但不显示为已选。
- Selected-only 不改写 `show_hidden`；关闭后当前 hidden 设置重新参与投影。上层不能先按 hidden 裁剪 source。

## 覆盖、判空与计数

子树 summary 为 `{ full, known_roots, known_self_only, pending }`：

- `known_roots`：当前已知结果中可证明完整覆盖的最外层子树数量。
- `known_self_only`：未被这些完整子树覆盖的已选自身数量；pending 时后续补载可能改变分组。
- `pending`：完整枚举或计数仍需要 children；已有可证明的非空结果继续有效。

聚合使用包含 self stamp 的 `max_stamp`。令祖先传入值为 `p`，`s = max(p, subtree_stamp(n))`、`e = max(s, self_stamp(n))`：

1. `s >= max_stamp(n)` 时整棵子树统一：奇数返回 `{true, 1, 0, false}`，偶数返回 `{false, 0, 0, false}`。
2. 否则按 `e` 的奇偶确定自身 `marked`，向已知 children 传入 `s`（不能传 `e`）并合并其 summary。
3. 未物化 children 的 stamp 为 0，直接继承 `s`，不为证明覆盖而加载。
4. 自身 marked、全部已知 children full，且 children 已 complete 或 `s` 为奇数时，返回 `{true, 1, 0, false}`。
5. 否则合并已知 children 的数量，自身 marked 时再计一个 self-only。Children 不完整时，`s` 为奇数，或 `s` 为偶数而自身
   marked 且已知 children 全部 full，置 pending 并把该节点列入 `needed_children`；其他偶数继承的未知旁支不贡献选取。

`full` 只在可证明完整覆盖时为 true。例如 `select_node({P}, false)` 而 P 的 children 未知：自身已选可立即判非空，
但 P 是否为空分支未知，精确分组仍 pending；确认有未选 child 则 P 为 self-only，确认为空分支则 P 归入 `subtree_roots`，
两种结果都不改写原 self stamp。自身标记写入不等待 children。

令 `known_count = known_roots + known_self_only`：

- `known_count > 0`：selection 确定非空；pending 时总数仍待定。
- `known_count == 0 && !pending`：selection 确定为空（Lua summary 的 `is_empty`）。
- `known_count == 0 && pending`：尚不能判空。

数量是紧凑表示的条目数，不是递归节点数或可见行数；不能把 `known_roots == 0` 当作没有选择。

## 消费边界

- 递归操作只使用 `subtree_roots`；`self_only_nodes` 中的 container 只代表自身，其业务含义由 consumer 按动作定义。
- Pending 结果只含已知部分与 `needed_children`，不能作为完整操作输入；完整源项须经[任务准备](tasks.md#源项准备)。
- 源项不足或为空不清空 selection，也不清除用途；是否执行、是否回退到其他目标由 consumer 决定。
- 任务只取消成功项，之后按两组实际结果判空。例如 P 自身选中、子项 A 全选，清理成功的 A 后 `self_only_nodes={P}`，
  selection 仍非空。只有显式 ClearSelection 或使两组确定为空的写入才清空。
- 只读消费已物化结果可直接读取 Frame，不取得任务锁，见[多选 List](results.md#多选-list)。

## Lua API

| 方法                                                                            | 语义                                                                                                           |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `state:select_node(nodes, recursive)` / `state:deselect_node(nodes, recursive)` | 对 NodeIds 写入，dispatch kind 同名                                                                            |
| `state:toggle_node(nodes, recursive, frame)`                                    | 按捕获 Frame 的 `marked` 切换                                                                                  |
| `state:dispatch({ kind, range = { frame, first, last }, recursive })`           | 行范围输入，1-based 闭区间                                                                                     |
| `view:select(action, recursive)`                                                | 对当前显示 Frame 的光标行或 Visual 范围提交                                                                    |
| `state:clear_selection()`                                                       | ClearSelection                                                                                                 |
| `state:inspect_selection()`                                                     | `Inspected`：revisions、summary、两组源项、`needed_children` 与不可变 source                                   |
| `state:status()`                                                                | 已提交的 `selection_purpose`、`locked` 与 revisions                                                            |
| `frame:header()`                                                                | 该 Frame 的 `summary`、`selection_purpose` 与 `selection_revision`                                             |
| `frame:flags(node)` / `frame:rows(first, last)`                                 | 单节点的 `marked` 与 `expanded`（含被折叠或过滤的节点，缺失返回 nil）；行批次的 `marked`、`full`、`pending` 列 |
| `frame:marked_nodes(visible_only)`                                              | 该 Frame 的已选 NodeIds；true 按可见行序，false 包括被折叠与过滤的节点                                         |
| `frame:all_marked(nodes)`                                                       | 显式节点是否全部选中，读取该 Frame 的状态，不受折叠或过滤影响                                                  |

`frame:all_marked(nodes)` 的空输入返回 true，重复 ID 不改变结果；所有 ID 都须存在于该 Frame 的 Source，
即使已遇到未选节点，后续缺失 ID 仍报 `MissingNode`。输入上限见[默认容量](action.md#默认容量)；批量查询共享祖先的继承值，
工作量限于输入节点及其所需祖先，不扫描范围外的行或选中项。

`state:lock_selection` 与 `task:*` 见 [tasks.md](tasks.md#生命周期)。

## 例子

### 自身与递归交错

P 有 leaf 子项 A、B，起初均未选中，children 完整：

```text
select_node({P}, false)    -> P 已选，A/B 未选
select_node({P}, true)     -> P/A/B 全选
deselect_node({P}, false)  -> P 未选，A/B 仍选；后来新增 C 也继承子树选中
select_node({P}, false)    -> P 恢复已选，后代状态不变
deselect_node({P}, true)   -> P 及全部后代未选
```

`select_node({P, A}, false)` 分别写 P 与 A 的 self stamp，不因 P 是祖先而丢弃 A；`recursive=true` 时归并为 P。

以下例子使用 `recursive=true`；表中的 stamp 指 subtree stamp，self stamp 均为 0。

### 取消子项与恢复覆盖

P 有两个 leaf 子项 A、B，children 完整，初始均未选中：

| 操作               | P stamp | A stamp | B stamp | `subtree_roots` | `self_only_nodes` |
| ------------------ | ------- | ------- | ------- | --------------- | ----------------- |
| g1：选中 P         | 3       | 0       | 0       | `{P}`           | `{}`              |
| g2：取消 A         | 3       | 4       | 0       | `{B}`           | `{P}`             |
| g3：重新选中 A     | 3       | 7       | 0       | `{P}`           | `{}`              |
| g4：再次取消 A     | 3       | 8       | 0       | `{B}`           | `{P}`             |
| g5：取消 B         | 3       | 8       | 10      | `{}`            | `{P}`             |
| g6：在 P 上 Toggle | 12      | 8       | 10      | `{}`            | `{}`              |

取消 A 不写 P；P 自身仍选中，只是 full 变为 false。重新选中 A 后 P 自然恢复 full，stamp 仍为 3。
A、B 都取消后 selection 仍包含 P 自身；随后 Toggle P 才使两组都为空。

### 同值选择与 Reparent

文件 A 与空目录 Q 起初平级，初始均未选中，移动保留 A 的 NodeId：

| 操作              | A stamp | Q stamp | A 是否选中   |
| ----------------- | ------- | ------- | ------------ |
| g1：同时选中 A、Q | 3       | 3       | 是           |
| g2：取消 Q        | 3       | 4       | 是           |
| g3：再次选中 A    | 7       | 4       | 是           |
| A reparent 到 Q   | 7       | 4       | 是，7 覆盖 4 |

再次选中 A 即使没有改变当前选区，也写入 `7` 并返回 Applied；Reparent 不生成新版本，A 的 `7` 胜过新祖先 Q 的 `4`。
若第三步只是切换 `selection_purpose`，A 保留原 stamp `3`，移动后为 false。

### Reparent 与 Toggle

空目录 P 与文件 X 起初平级，children 完整，移动保留 X 的 NodeId：

| 操作                         | P stamp | X stamp | `subtree_roots` | `self_only_nodes` |
| ---------------------------- | ------- | ------- | --------------- | ----------------- |
| 同时选中 P、X                | 3       | 3       | `{P, X}`        | `{}`              |
| 取消 X                       | 3       | 4       | `{P}`           | `{}`              |
| X reparent 到 P              | 3       | 4       | `{}`            | `{P}`             |
| 在 P 上 Toggle，取消 P 子树  | 6       | 4       | `{}`            | `{}`              |
| 再次在 P 上 Toggle，选中子树 | 9       | 4       | `{P}`           | `{}`              |

Reparent 后 P 自身仍选中而 X 未选中，P 的 summary 为 `{false, 0, 1, false}`，显示为仅自身选中。
若 P 还有已选子项 Y，则得到 `subtree_roots={Y}` 与 `self_only_nodes={P}`，递归操作只以 Y 为源项。

## 成本

单点标记查询为 `O(H)`；聚合与源项枚举最坏 `O(N)` 时间、`O(H)` 遍历栈；递归 action 的范围归并为 `O(K * H)`
（`H` 为树高，`N` 为访问的已知节点数，`K` 为输入节点数）。写入、存储与 generation 上限见
[共用成本与容量](stamps.md#成本与容量)；selection 与 expansion 分别计费，IO、排序与 UI 发布另计。
