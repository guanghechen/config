# Treeview 展示范围、filter、sort 与派生缓存

## Ground truth 与所有权

DataHandle 对应的 source tree 是节点数据、identity 和父子关系的唯一 ground truth。
这里的 tree 指 provider 提供的有序 forest，不限定为 filesystem tree，也不等同于 Tree 展示模式。
Selection、expansion 等交互状态仍由 StateHandle 持有。

List 是 source tree 经 filter 与 sort 计算出的派生缓存：

```text
list = project(tree, display; display_context)
```

- List 保存 NodeId 顺序、匹配位置和必要索引，引用对应版本的 source 数据；不复制一套权威业务数据。
- Filter 或 sort 改变不通过 Remove、Reparent 或 Reorder 修改 source，也不分配新 NodeId。
  Source 的真实变化仍由 data owner 提交节点更新批次。
- Tree 展示同样由 source 与当前展示条件派生。两种模式不需要互相同步另一份节点集合或 parent 关系。
- Rust 负责投影内部的匹配、排序、缓存和行映射。Consumer 可以在 Lua 准备路径分组、frecency 排名或 matcher 结果，
  通过 records、source 顺序和有序 `filter` 交接；不逐节点提供跨 FFI 谓词或比较函数，也不在 Lua 计算最终可见行。

## Display 选项

`DisplayOptions` 由 `create_state(root, display?)` 和 SetDisplay 整体提交；SetDisplay 替换全部字段，省略的字段取默认值。
Lua 类型见 `ux.treeview.IDisplay`。

| 字段              | 默认     | 取值与约束                                                             | 影响                                    |
| ----------------- | -------- | ---------------------------------------------------------------------- | --------------------------------------- |
| `mode`            | `tree`   | `tree` / `list`                                                        | 布局                                    |
| `pattern`         | `""`     | 最多 4096 bytes；空串不按文本过滤                                      | 成员、匹配 spans                        |
| `case_sensitive`  | `false`  | boolean                                                                | 同 `pattern`                            |
| `fuzzy`           | `false`  | boolean                                                                | 同 `pattern`                            |
| `regex`           | `false`  | boolean，优先于 `fuzzy`；非法表达式使投影失败                          | 同 `pattern`                            |
| `filter`          | nil      | 有序 NodeId 数组（200,000 项上限）或 native NodeIds 句柄（不受该上限） | 成员；List 且 `sort=source` 时决定顺序  |
| `sort`            | `source` | `source` / `name` / `score`                                            | 兄弟或 List 顺序                        |
| `branches_first`  | `false`  | boolean                                                                | 同 `sort`                               |
| `show_hidden`     | `true`   | boolean；为 false 时排除 `hidden` 节点，selected-only 下不生效         | 成员                                    |
| `selected_only`   | `false`  | boolean                                                                | 成员；布局依赖 selection                |
| `compress`        | `false`  | boolean；仅 Tree 生效                                                  | 压缩链；布局依赖 expansion 与 selection |
| `list_text`       | `label`  | `label` / `ancestry`；仅 List 与分组平铺范围生效                       | 正文                                    |
| `list_depth`      | nil      | 非负整数；仅 List 生效                                                 | 候选范围                                |
| `list_from_depth` | nil      | 非负整数；要求 `mode=tree`、`compress=false`，不能与 `list_depth` 同用 | 布局（分组平铺）                        |
| `context_label`   | nil      | 要求 ChildrenOf、List、`list_text=label`；最多 4096 bytes，无控制字符  | 入口上下文行                            |
| `branch_suffix`   | `""`     | 要求 List、`list_text=label`；最多 32 bytes，无控制字符                | 正文与匹配文本                          |

失败时机：

- 类型、枚举、数组形状与数组上限在输入解析时失败，Future 以 `Rejected` 完成，命令不入队。
- `create_state` 在创建时完整构建首个 Frame，上述全部约束（含 pattern 长度、字段组合与 regex）不满足时以 `Rejected` 完成。
- SetDisplay 提交时只检查 pattern 长度，其余组合在投影时校验。投影失败不发布新 Frame：State 保留旧 Frame，
  `state:status().projection_error` 报告错误，View 经 `on_error` 或默认 reporter 报告且同一错误不重复；
  后续合法的 SetDisplay 或显式 `view:refresh()` 重新投影。

Filter 是成员约束：nil 不限制成员，空数组表示无结果，不存在或已删除的 ID 不产生行；Tree 与 List 的成员规则见
[Tree 与 List](#tree-与-list)。过滤不改写 source topology。
排队和保留 filter 的内存计入 data owner 预算。

`regex=true` 优先于 `fuzzy`，按正则匹配并标出全部匹配，`case_sensitive=false` 时不区分大小写。其余 pattern 采用
[Yoz Fuzzy](../../yoz/fuzzy.md) 的 fzf 语法与 `path` scheme：`fuzzy=false` 时普通词为精确子串，`case_sensitive=false`
为 smart-case，每个 label 只标出一个最佳对齐。
匹配对象是节点 label，List 中可展开节点追加 `branch_suffix`；viewport spans 使用原始 UTF-8 byte offsets。
Matcher 在 worker 构造，pattern 与三个匹配开关不变时复用。

排序输入只有 `sort`、`branches_first`、`filter` 排名以及节点的 label/score，不接受上层比较规则：

- `branches_first` 先排可展开节点，再按 `sort` 比较。
- `source` 保持 source 顺序；List 有 `filter` 时按 filter 排名，未排名项在后，同排名保持 source DFS 顺序。
- `name` 按 label 的 ASCII 小写比较，`score` 按 score 降序；两者同值时按 NodeId 排序。
- Tree 对每组兄弟排序；List 对全部候选整体排序。同一份完整输入重复计算得到同一结果。

## Display roots

### 显式范围与派生入口

- `ChildrenOf(root)` 从当前 root 的直接 children 开始展示，root 自身隐藏；不保存一份独立的 children 名单。
  List 可用 `context_label` 显示该入口的上下文行，见 [List 正文](#list-正文)；它仍引用原 NodeId。
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
  的 children 顺序、展开/折叠及过滤规则展示；完整展开时每个节点恰好出现一次，范围等于各显式子树的并集。
- 归并先于折叠、过滤与压缩；祖先被折叠或过滤，不会使后代重新成为独立顶层入口。
- 只从显式入口中取最外层节点，不补入它们的共同祖先或其他未指定资源。
- 当前被另一入口覆盖的存活 ID 仍保留在 `ids` 中。其祖先关系解除后，自动按原入口顺序恢复。

### 节点更新与发布

1. Data owner 按既定顺序在私有候选 topology 上解释整批 operations，并准备各份 state 的标记补丁。
2. 在整批更新的最终 topology 上，清理已被 `Remove` 的显式入口，再派生各份 state 的 `display_roots`。
   中途出现的祖先重叠不会删除显式入口，也不会让合法的 reparent 返回 `InvalidUpdate`。
3. 将 data、显式范围清理及派生状态与其他 state 补丁同批发布；失败时全部丢弃，不发布中间布局。

共享 data 的独立 states 分别使用自己的显式范围归并；共享完整 state 的 View 共用同一结果。
Snapshot 保留对应提交的显式范围及派生顶层结构，Lua 不用最新 topology 修补旧 Frame。
展示归并本身不生成选择事务，也不将展示入口当作业务源项。

### 入口生命周期

- 显式 `SetRoot` 替换保存的范围；之前未出现在新范围中的入口不保留为隐藏历史。
- 真正 `Remove` 的 NodeId 从 `Forest(ids)` 剔除，并通过既有节点失效与视图变化通知报告。
  同名新建节点具有新 ID，不自动继承原入口位置。
- 暂时未加载、loading/error、折叠或过滤都不使入口失效。显式 roots（包括被其他入口覆盖的项）
  及其必要祖先属于结构引用，不能因 render/metadata cache 淘汰而丢失 identity 或 parent 链。
- `Forest` 的入口全部失效后成为 `Forest([])`，展示为空；不自动选取新的资源范围。
- `ChildrenOf(root)` 的 root 被移除时展示为空并发出 `RootUnavailable`，由上层显式选择新 root。
  Root 仅发生 reparent 时仍按同一 NodeId 浏览其当前 children。

### 归并例子

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

## 输入与缓存有效性

每份缓存及计算产物关联完整的输入身份：DataHandle 与 data revision、完整 display 选项，以及实际使用的 display context。
版本属于内部有效性契约，不要求 Lua 每帧接收完整输入或索引。

- Tree 数据或 display 任一变化，旧缓存即不再是当前输入的有效结果；输入相同且缓存仍在时复用。
  完全回退到旧条件也必须核对全部输入，不能仅因 pattern 相同就复用其他 data revision 的结果。
- 节点 label、score、`hidden` 与 `foldable` 属于 data 输入。它们在当前 display 下参与过滤、排序或压缩时，
  更新使对应结果失效（依赖范围见 [render](render.md#依赖失效与重算范围)）；不比较谓词对象地址判断有效性。
- Display context 包含当前展示范围与模式，以及参与计算的状态。Selected-only 与 `compress` 依赖当前 selection；
  Tree 可见行还依赖 expansion。Root、相关选择或展开状态改变后不能继续使用旧可见行。
  普通 cursor 移动不参与筛选或排序，不使结果顺序缓存失效。
- 缓存失效要求重新计算当前结果，不要求丢弃全部可复用的内部索引。实现可以复用经验证仍适用的
  子计算，但不能把旧产物直接标记为新输入的结果。
- 输入变化不必推进 layout revision。重算后只有行映射、导航、source 祖先归并等布局信息
  实际变化才推进该 revision；正文变化另推进 text revision。

## Tree 与 List

Tree 保留 source 层级，在 display roots 内应用 filter、兄弟排序、展开与压缩，再生成 DFS 可见行。
匹配到后代时保留展示路径所需的连接祖先；连接祖先不因此变成直接匹配项。匹配本身不写展开标记，
不越过 display roots 或自动展开已折叠的分支。Hidden 与 selected-only 的优先级遵循
[selection 契约](selection.md#selected-only-与-hidden)，连接线与压缩遵循 [indentline](indentline.md)。

List 的候选范围默认递归覆盖 display roots，不受 Tree 折叠影响；filter 决定结果成员，sort 决定平铺顺序。
递归候选范围不要求输出按 DFS 排列。普通文本匹配不强制加入只用于连接的祖先行；selected-only
在没有显式 `filter` 时保留必要祖先与 pending 范围。有显式 `filter` 的 List 只保留直接命中成员。

- 行序不反写 source 的 sibling 顺序；切回 Tree 使用保存的展开状态。
- List 无视觉缩进、连接线或压缩，不支持 Tree 专用结构导航与折叠动作。
- 未加载范围仍报告真实的 partial/loading/error，按现有 children 调度补载。不能仅因当前缓存已算完，
  就把尚未加载的候选范围声明为完整；有效补载提交更新 tree 后使缓存失效。

`list_depth` 限制 List 候选范围：display roots 深度为 0，`ChildrenOf(root)` 配合 0 只列直接 children。
超出边界的已加载后代不参与匹配；边界节点不产生 children 读取或 watch 需求。ChildrenOf 入口自身仍需加载直接 children。
有界 List 的结构更新只重算这段范围，再复用未变行块。

`list_from_depth` 为 Tree 提供分组平铺：display roots 深度为 0，指定深度以上保留 Tree 行与展开状态，
每个到达该深度的子范围独立应用 List 成员筛选和排序。范围内不受其目录折叠影响，行的视觉 parent 指向所属
Tree 分组；source parent、NodeId、selection 与 expansion 均不变。分组折叠隐藏其整个平铺范围，分组层级不参与路径压缩。
`list_text=ancestry` 在每个平铺范围内组合 labels，不包含分组 header；范围以外的 Tree 行继续显示自身 label。
Source、root 和 display 不变时，展开／折叠只重新投影受影响的 Tree 分组并修复祖先边界，复用其他分组的行块；
平铺范围内部的目录展开标记不改变布局。Source、成员筛选或展示范围改变时重算当前展示范围。

Filter、sort 和模式切换不改变 selection 标记。递归 action 的输入祖先归并仍使用 source 关系，
不会因平铺、排序或隐藏了部分后代而缩小为屏幕上的几行。

## List 正文

`list_text = "label" | "ancestry"` 只影响 List 正文。`label` 使用节点自身 label；`ancestry` 将 display root
范围内的祖先 labels 用 `/` 连接。ChildrenOf 的入口自身不进入正文，Forest 从实际派生的显式入口起包含入口 label；
被祖先覆盖的入口不另起路径。这是 source labels 的组合，不解析 filepath、不正规化名称，也不改写 source label。

正文依赖的 source、root 和模式随 Frame 固定，多个不同 root 的 states 可以共享同一 data。
成员筛选仍按 source label，匹配 spans 移到该 label 在实际正文中的 byte offset，不把祖先文本当成新增的匹配条件。
Tree 正文与压缩链见 [indentline](indentline.md#压缩链)。正文变化推进 text revision，不能仅凭行映射一致复用旧 staging。

祖先文本使用共享片段与累计长度，实际导出才展开完整字符串；构建、读取和最后引用释放必须深度安全。
叶子 rename 只处理本行；目录 rename/reparent 处理实际依赖它的后代正文，排除在 display root 外的祖先变化不改正文。
RenderPlan、viewport spans 与字节预算使用同一文本来源，计入真实输出字节，不为每节点缓存完整路径字符串。

`context_label` 为 ChildrenOf List 提供一个位于首行的入口上下文行。它保留入口 NodeId，以给定 label 参与普通
pattern/filter，不改写 source label，不建立虚拟资源。该行独立于 children 的排序与 selected-only 成员，用途及动作由
consumer 决定，Find Explorer 的用法见 [Find Explorer](../../feat/explorer/find.md#入口与状态)。标签变化推进 text revision 并按正文更新发布。

`branch_suffix` 为可展开节点的 List label 追加展示标记；它同时参与匹配与正文，不修改 source label。
上下文行使用自己的完整标签。
派生 label 的共享存储计入 Rust 预算；标签或 suffix 变化按正文更新发布。

## 异步计算与显示

- 每个 state 的计算与合并遵循 [action 调度](action.md#投影与发布)：owner 线程按批同步投影，
  同批的连续更新合并为一次投影，不在后台并行运行。
- 过期结果不能成为当前有效缓存或发布为当前结果；输入变化只合并派生计算，不丢弃已接受的标记命令。
- 失效不等于立刻清空 buffer。新结果尚未准备好时可以显示旧 Frame，但必须保留它原来的输入身份、
  数据版本与行映射，不能将它伪装成新 filter/sort 的结果。
- 输入始终捕获实际显示的 Frame，由该 Frame 映射 NodeId，再校验当前节点与动作前提；
  缓存失效本身不意味着用户针对旧 Frame 的所有输入都失效。发布与持帧分别见 [render](render.md) 与 [view](view.md#visual-圈选)。
  派生缓存可以淘汰，但不得破坏仍被 View、命令或任务持有的不可变数据。

Finder 过滤与新查询的边界见 [query](query.md#与其他协议的边界)，数据接入遵循 [data 契约](data.md)。
查询结果的归属与当前目标查询也是发布时需要核对的输入，不与派生缓存有效性混为一套生命周期。

本契约决定派生结果是否仍有效；失效后的局部依赖重算、共享行序列、差量及 Neovim 发布方式遵循
[render 契约](render.md)。一个完整目标 snapshot 不要求整表复制或全量发布。

## 例子

Source 中 `src` 的 children 为 `[a.lua, b.lua]`，之后的 `test` 下有 `c.lua`。
Finder 仅保留文件，按排名 `b > c > a` 提交 `filter = [b, c, a]`、`sort = "source"`、`list_text = "ancestry"` 时，List 为：

```text
src/b.lua
test/c.lua
src/a.lua
```

切回 Tree 仍是 `src -> [a.lua, b.lua]`、`test -> [c.lua]` 的 source 关系；兄弟顺序按 Tree 的 sort 计算，
不因此前平铺时两个 src 文件被分开而产生 Reparent。
