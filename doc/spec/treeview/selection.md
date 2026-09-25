# Rust Treeview selection

Status: Design。适用于 `yoz.ux.treeview`；文档入口见 [Treeview](README.md)。

本文定义 `rust/yoz/src/ux/treeview/` 已确认的 selection 语义、派生结果与消费边界。

## 状态与派生集合

Selection 使用 [共用版本标记算法](stamps.md)，保存独立的 generation、节点的 `subtree_stamp`、
`self_stamp` 与全局 `clear_stamp`。自身 action 只写 self，递归 action 只写 subtree。
`marked(n) = value(n)` 由节点自己的 self stamp、自己和祖先的 subtree stamp 及全局 clear 按版本决定；
`full(n)` 聚合自身及全部后代是否都选中，包括未加载、折叠和隐藏的后代。

Selection 按选取范围分解成两个集合：

| 集合              | 含义                                           |
| ----------------- | ---------------------------------------------- |
| `subtree_roots`   | 整棵子树全选的最外层根，每项代表自身及全部后代 |
| `self_only_nodes` | 自身选中、但未被上述完整子树覆盖的剩余节点     |

令 `descendants_including_self(r)` 包含根自身，则：

```text
M = { n | marked(n) }
R = subtree_roots = { n | full(n) 且没有 full 的严格祖先 }
C = union(descendants_including_self(r) for r in R)
I = self_only_nodes = M - C
M = C ∪ I
C ∩ I = ∅
```

等式描述完整逻辑选区；查询 pending 时只返回已知部分，不将 known 集合当作完整 M。

- `subtree_roots` 内没有祖先/后代重叠；两组不会重复表示同一个选中节点。
- `self_only_nodes` 可以包含某个 `subtree_roots` 根的祖先，该祖先只代表自身；不能合并两组 ID
  后再按祖先归并为递归操作源。
- 选中的独立文件、空目录同样可以进入 `subtree_roots`；分类依据是选取范围，不是 leaf/container 类型。
- 两组由同一份 stamp 和当前 topology 派生，可按需查询、缓存和枚举；不作为两份独立可写的选区，
  也不要求将完整选中子树的所有后代物化成 set。所有修改仍通过同一 selection 事务提交。
- 集合记录当前覆盖，不记录 action 历史：`select_node(..., { recursive = false })` 选中的已知 leaf/完整空分支也可进入 `subtree_roots`。
  该分类不把 self stamp 改成 subtree stamp；空分支后来新增 child 时，新 child 仍只继承 subtree 标记。

## 标记与交互

公开 selection actions 使用统一的 `xxx_node(..., { recursive: boolean })` 形式。
`recursive` 必填且必须为 boolean，不隐式设默认值，也不按 consumer 类型推断 scope；缺失或类型错误返回 InvalidUpdate。
下面是逻辑签名，Lua 表字段使用 `recursive = false/true`：

| Action          | 目标布尔值          | recursive=false | recursive=true |
| --------------- | ------------------- | --------------- | -------------- |
| `select_node`   | `true`              | SelfOnly        | Subtree        |
| `deselect_node` | `false`             | SelfOnly        | Subtree        |
| `toggle_node`   | 提交前 `!marked(n)` | SelfOnly        | Subtree        |

SelfOnly 使用 `assign_self(n, value, g)`，Subtree 使用 `assign_subtree(n, value, g)`。
下文“自身 action”与“递归 action”分别表示 recursive=false/true 的同一套接口，不提供另一套 `_subtree` 别名。

Mouse、Ctrl+mouse、键盘、分组标题是否触发动作，以及哪些节点接受选择或激活，由上层决定。
Core 不按 class、目录等业务类型选用 scope，也不从输入设备推断范围；选择、展开和激活是独立意图。
同一 state 中可交错使用两类 actions，不切换或重置 selection 模型。

自身 action 不修改后代已有选择，也不为未来后代提供新的继承值；它并不表示“只留下自身、取消其余节点”。
递归 action 覆盖未加载和以后新增的后代，较新的 subtree 标记覆盖旧 self 例外；较新的 self 例外只覆盖自身。
祖先与旁支的权威标记保持原值；祖先的 `full`、两类计数和缓存按后代的新状态重新派生。
`marked` 的查询不读取后代，命令也不因取消后代而额外改写祖先自身。

每个 action 可接受显式 NodeIds 或实际 frame 的行范围，单点是单元素输入。自身 action 只去重 ID，
不丢弃同时指定的父/子节点；递归 action 按 source 关系归并最外层根。捕获 scope 后不能在提交时改用另一种解释。
同次 action 的目标布尔值都从提交前状态读取，共用一个 generation；不同 scope 使用独立 actions 按 queue 顺序执行。
ClearSelection 使用本 selection 状态的 `clear_all(g)`，覆盖全部 self/subtree 标记。

本文 Explorer 场景中的 Add/Toggle 是 `select_node` / `toggle_node` 配合 `recursive=true` 的语义简称，
不是带隐含默认 scope 的公共 action。
现有受任务 token 保护的 Unselect 仍按 Explorer 的子树成功项清理协议执行；公开 deselect actions 不能绕过选区锁。

- Select/deselect 总是向对应 scope 写新 stamp；subtree 赋值覆盖较旧后代例外，node 赋值不修改它们。
  同值赋值、Applied 与空目标 NoChange 遵循 [共用命令规则](stamps.md#同值赋值与-nochange)。
- 纯 mode 切换由上层提交 feature 变化，不调用 Add，不刷新 selection stamp、generation 或 selection revision；
  两组派生集合不能分别写入。
- 两种 toggle 都按 `marked(n)` 决定目标布尔值，再写入 action 指定的 scope，不按 full 判断。
  `self_only_nodes` 中的节点自身已选中，recursive=false 时取消自身，recursive=true 时取消该子树；
  Explorer Normal `c`/`x` 的已选判断使用相同口径。
- 取消目标子树时，祖先自身与旁支保留原选择。原已选祖先变为 `marked=true, full=false` 时，
  退出 `subtree_roots`，自身由 `self_only_nodes` 表示；不能继续用它执行递归业务操作。
- Reparent 保存旧链继承 stamp，不分配新 generation、不补写祖先标记；新的两组结果通过正常聚合取得。
- UI 分别表达自身是否选中和子树是否完整覆盖：`marked && !full` 展示为“仅自身选中”，
  并可同时显示已选后代；只有后代选中的连接祖先不能显示为自身已选。
- Selected-only 保留两组代表的选中节点、必要的连接祖先和 pending 范围；压缩不能隐藏
  “自身未选”“仅自身选中”“整棵子树全选”之间的选择边界。
- Visual 的 frame 保留、范围捕获及动作校验遵循 [Visual 圈选契约](visual.md)；
  后台布局变化不改变正在圈选的行输入，也不直接修改 selection。
- 导航、display root、排序、过滤、折叠、压缩和 Tree/List 切换不改变选择标记；selected-only
  补足连接祖先，不因展示而修改其标记。

### Selected-only 与 hidden

Selected-only 开启时采用 `selected > hidden`：hidden 过滤不参与本次投影，保留选中节点、必要的
连接祖先及 pending 范围。Hidden 的判定由上层提供，Treeview 不根据文件名或 filepath 推断。

- 已选隐藏项与到达它所需的隐藏祖先可以显示；祖先只作为连接路径时不因此变为 marked。
  完整选中目录内的隐藏后代同样继承选择，被反选的项仍按实际 selection 过滤。
- 仍遵守 display roots 和 Tree 折叠状态，不跨展示范围汇总选区，也不为展示已选项自动展开目录。
  Pending 范围按已有规则保留，不显示为已选；List 继续按既有规则递归。
- Selected-only 不改写保存的隐藏项开关；关闭 selected-only 后，当前隐藏项设置重新参与投影。
  上层不能先按 hidden 裁剪真实 source，导致 selected-only 无法取得选中节点或连接祖先。

例如 `.gitignore` 已选中且是当前展示范围的顶层项：关闭“显示隐藏项”时，普通浏览隐藏它；开启
selected-only 后显示它；关闭 selected-only 后再次隐藏它。三个步骤都不改变其选择标记。

## 覆盖、判空与计数

子树 summary 为 `{ full, known_roots, known_self_only, pending }`：

- `known_roots`：当前已知结果中可证明完整覆盖的最外层子树数量。
- `known_self_only`：当前未被这些已证明完整子树覆盖的已选自身数量；pending 时后续补载可能改变分组。
- `pending`：完整枚举或计数仍需要 children；已有可证明的非空结果继续有效。

Full 子树返回 `{true, 1, 0, false}`，跳过后代。非 full 子树合并直接 children 的两类数量，
自身 `marked` 时再给 `known_self_only` 加 1，并合并未知旁支的 pending。
完整子树的覆盖判断继续使用继承 stamp、后代例外及 children 完整性；自身 marked 不能替代 full。
子项后来重新覆盖时自然重算 full，不补写祖先。祖先自身原已选时可以重新成为 full；自身原未选时，
即使 children 全选也不自动选中它。不按“已加载孩子全选”单独写回父标记，也不为派生集合归并
额外生成选择操作；尚未确定的后代范围不显示为已选，已确定的自身 marked 仍正常显示。

具体聚合使用包含 self stamp 的 `max_stamp` 缓存。令祖先传入值为 `p`，
`s = max(p, subtree_stamp(n))`、`e = max(s, self_stamp(n))`：

1. `s >= max_stamp(n)` 时，统一奇数返回 `{true, 1, 0, false}`，统一偶数返回 `{false, 0, 0, false}`。
2. 否则按 `e` 的奇偶计算自身 `marked`，向已知 children 传入 `s` 并取得 summary，不能传 `e`。
3. 未物化 children 的 stamp 为 0，直接继承 `s`，不为证明覆盖而递归加载。
4. 自身 marked、全部已知 children full，且 children 已 complete 或 `s` 为奇数时，返回 `{true, 1, 0, false}`。
   未知 children 的状态按 `s` 判断，不能用节点自身的 true 覆盖来证明整棵子树已选。
5. 否则合并已知 children 的两类数量，自身 marked 再增加一个 self-only，并合并 child pending。
   Children 不完整时，`s` 为奇数表示未知旁支可能贡献额外选取，需置 pending；`s` 为偶数、自身 marked
   且全部已知 children full 时，也需置 pending，因为尚不能确定它应归为完整子树还是自身选取。
   其他偶数继承的未知旁支不贡献额外选取，不因自身 action 无条件递归加载后代。

`full` 只在可证明完整覆盖时为 true；pending 时两组为当前可证明覆盖下的已知结果，补载可能改变分组。
例如 select_node(P, { recursive = false })、P 的 children 为 unknown：自身已选可立即判非空，但 P 是否为空分支尚未知，
精确分组仍 pending。后来确认有未选 child 则 P 为 self-only，确认空分支则 P 可归入 subtree_roots；
两种结果都不改变原 self stamp。查询与渲染所需的补载由既有需求协议决定，自身标记写入不等待 children。

令 `known_count = known_roots + known_self_only`：

- `known_count > 0`：selection 确定非空；pending 时总数仍待定。
- `known_count == 0 && !pending`：selection 确定为空。
- `known_count == 0 && pending`：尚不能判空。

Selection 数量是上述紧凑表示的条目数，不是全部递归节点数或可见行数。UI 同时保留两类数量，
不能把 `known_roots == 0` 显示为“没有选择”。递归业务源项的数量和判空单独依据 `subtree_roots`
及其完整性；源项不足或为空不清空 selection，也不自动解除 mode。

## 消费边界

- 完整查询保留两组结果及 revision；信息不足时保留已知结果和 needed children，不把部分枚举
  当成完整业务输入。
- 递归 copy/move/delete 使用 `subtree_roots`。`self_only_nodes` 中的 container 只表示自身，
  不能被当作整目录操作源；其业务用途由 Explorer 按动作定义，Treeview 保留这一状态。
- 递归源项确定为空但 selection 非空时，该动作不执行 IO，保留选区和 mode，不回退到光标项。
- 任务终止后根据结果清理后的两组实际状态重新判空，只有 selection 确定为空才退出 multiselection；
  不能仅因递归源项全部成功就执行全局 ClearSelection。显式 ClearSelection 清空全部标记语义。
- 取消最后一个已选子项或清理全部递归源项后，祖先自身可能仍在 `self_only_nodes` 中，此时保留 mode。
  已清理源项之外的自身选择不会被额外取消。

## 源项准备

按 data owner 的完整 forest/children 顺序枚举，范围不受 display root、折叠或显示过滤限制：

- Full 节点输出到 `subtree_roots`，跳过后代；非 full 节点自身 marked 时输出到 `self_only_nodes`，继续查询 children。
  只有两类数量均为 0 且无 pending 时才跳过该分支；不能把 self-only 节点的已选后代一起跳过。
- Pending 分支请求必要的完整直接 children；已 full 的目录不为枚举其自身而加载后代。
- 通过 dispatch 查询时，Future 完成值为 `Ready {revision, cleanup_context, subtree_roots, self_only_nodes}` 或
  `Pending {revision, known_subtree_roots, known_self_only_nodes, needed_children}`；两者都记录本次查询的
  data/selection revision，部分集合不能当作完整操作输入。
  上层按动作契约消费两组结果，递归 copy/move/delete 只使用 `subtree_roots`。
- Pending 表示源项信息尚未完整，但本次查询的 Future 已完成；上层补载后提交新的查询，不把旧
  Future 更新为 Ready。查询完成不结束业务任务或释放其锁；返回协议遵循 [Dispatch 与 Future](action.md#dispatch-与-future)。
- 信息不足时由上层 callback 补载，失败保留 selection 查询的 pending 与节点 error；业务准备任务
  按下述失败终止规则处理。重试仍校验节点和 request token。
- 业务准备持有选区锁；自己的 children 补载可推进 revision 并继续查询，Ready 时固定最终 context。
- 外部变更使动作前提失效时，在业务副作用开始前重新准备或明确失败；执行后的结果清理单独校验
  原 cleanup context，失效时保留结果并返回 Stale，不重放已经执行的业务 action。
- 普通判空/计数查询不锁选区，补载完成只更新当前 selection 的 summary，不能应用旧判空结论。

### 准备失败与重试

Selection 查询的信息完整性与业务任务终态分别表达：查询仍可为 pending/error，但本次业务准备
已经失败，不因此继续持锁等待重试。本节适用于源项尚未准备完成、文件修改 IO 尚未开始的阶段。

- 完成准备所必需的 children 读取失败、deadline 到期，或遇到尚未显式重试的 error 槽位时，
  终止本次业务任务，记录准备失败及对应节点、原因；已知的部分源项也不能先执行业务操作。
- 必要补载因 [硬容量不足](action.md#硬容量不足) 被拒绝时，同样终止准备并解锁；单纯等待 IO
  或读取队列容量不构成失败。失败任务不因容量释放而恢复，显式重试仍创建新任务。
- 持锁 owner 在同一提交阶段发布终止结果并释放本任务的选区锁，再通知 views；不等待用户重试。
  解除本任务的读取需求，共享读取继续按剩余需求处理，任务解锁不等待这些读取结束。
- 准备失败不执行 Unselect/ClearSelection、不生成选择标记，也不因失败切换 mode。保留当前选区、
  节点 error 和已接收的数据事实，不恢复准备开始时的旧快照；节点事实使选区确定为空时仍按正常判空规则退出 mode。
- 任务终止后，晚到读取按现有 request token 协议接收有效数据，只更新当前状态；不能恢复旧任务、
  自动启动文件操作、清理选区或释放后续任务的锁。重复失败 callback 同样不能再次终止或解锁。
- 用户显式重试业务动作时创建新任务，重新取得选区锁，验证当前 selection、mode、目标及数据前提，
  再准备完整源项。显式重试可按 children 协议重试当前所需的 error 槽位；不复用失败任务的 lock token
  或旧源项。单独刷新数据或读取恢复成功不会自动重试业务动作。
- Lua `task:prepare_sources(true)` 在 native owner 内重试当前选区所需、已有 error 的普通 children 槽位，
  返回 Pending 后继续用默认查询等待。重试沿用本任务的读取需求，取消锁后无其他需求的读取可停止；
  full 目录、无关 error 和已准备好的 Ready snapshot 不受影响。Query-owned 槽位仍通过其 query session 重试。
  此选项只用于显式新尝试，不能在每次轮询时反复设置；新读取失败仍终止当前任务。

例如 P 已选中、已知子项 A 被排除、B 仍选中，但 P 的 children 不完整。复制准备补载 P 失败时，
不先复制 B；任务失败并解锁，保留选择及读取错误。用户随后可以排除不可访问范围或显式重试，
即使旧读取后来返回，也只能提交有效数据，不能继续原复制任务。

## 业务结果清理

采用保守的结果清理策略：正常情况下移除成功源项；相关 topology 已变化时，保留 IO 结果，
选区清理返回 `Stale`，提示用户重新整理选择。成功项此时可以暂留选区，不能误清失败项或重放已完成的 IO。

### Cleanup context

在源项准备达到 Ready 时固定 `cleanup_context`，绑定 DataHandle、StateHandle、任务 lock token、
本次源项身份及清理涉及的 topology 前提。它由 Rust owner 持有，不能用最新 revision 重新生成后
代替原 context；全局 data/state revision 和 frame_id 不能单独决定其是否有效。

相关范围包含任务源项的子树与祖先继承链，以及清理可能影响的其他任务源项关系：

- 源项或祖先的 reparent/Remove、节点跨源项边界移入或移出、源项子树内的 insert/Remove，
  以及影响范围判断的 children 完整性变化，使 context 失效。
- 纯重排、名称和图标、Git/diagnostic metadata、loading/error 状态，以及 root/cursor/viewport
  等浏览变化不使 context 失效；范围之外且不改变上述关系的 topology 更新也不使其失效。
- Owner 按每次已提交更新的旧/新关系判断影响，将 context 失效与 data/state 一起发布。
  外部相关变化即使随后移回原位置，已失效的 context 也不恢复。
- 本任务已确认的 move/delete 等会产生预期节点更新。仅在 context 仍有效、owner 已验证任务归属、
  源项身份和预期影响范围，且未破坏其他源项的清理前提时，才允许该更新推进 context。
  来源不明或仅携带相同 task token 的 watcher/callback 不能取得这一例外；无法证明时按 `Stale` 处理。
- 已观察到的外部失效不能被后续本任务结果覆盖。上述检查基于 owner 的节点更新与派生索引，
  不为清理复制整棵树，也不递归加载完整选中目录来冻结 filesystem。

### Native 任务的 slot 更新

Native provider 的一次性更新资格可同时携带 `Slot { node, can_expand, completeness }`，
用于已授权移动导致资源展开能力改变的情况。Owner 校验所属 prepared subtree 与实际最终值，
并按提交顺序消费资格；旧 children 的删除仍需要各自的 Remove 资格，不能借 slot 更新插入新成员。
普通 Lua 任务入口仍只接受既有的 remove/reparent 更新声明。
同一 prepared subtree 内已准入的子项可随它整体移动或归回该 subtree，不能合并不同 prepared roots。


### 原子提交

1. Explorer 记录真实的逐项 IO 结果，Filetree 提交已确认的节点事实；IO 结果与 selection 清理结果
   分开记录，清理失败不会把已成功的 IO 改报为失败。
2. 批次的 IO 已结束或确认取消停止后，owner 在同一串行提交中校验 lock token、原 cleanup context
   与全部待清理成功项，并准备私有 selection 补丁；校验和标记写入之间不 yield 或调用外部 callback。
   待清理 ID 必须是原任务完整源项或其已准入的成功子项，且有对应 success 结果；
   不能替换为当前同名节点或最新选区。原 source 中存在的子项按原祖先关系校验所属 prepared root，
   任务中发现的新节点另须通过 owner 的任务读取/准入协议，不因当前位于该子树就自动获准。
3. 已由本任务确认的 Remove 清理掉的源项不再提交 Unselect，不复活失效 NodeId。其余成功项
   只有在整个 context 有效时才统一清理：按当前 source 去掉仍被成功祖先覆盖的重复目标，
   共用一个 generation，对每个成功根执行
   `assign_subtree(root, false, g)`，不写其严格祖先或旁支。不能清掉一部分后再对剩余项返回 `Stale`。
   已由本任务移出成功祖先的成功子项仍单独清理；部分成功不要求保留整个原目录的选择。
4. 正常分支发布 selection 补丁及结果。Stale 分支不发布清理补丁，不递增标记 generation，
   保留提交时的当前选区；两者都保存逐项结果与独立的 cleanup 状态，再按当前两组结果计算 mode。
5. 任务终止并发布上述结果后，释放该任务自己的锁，通知 views。清理 Stale 不维持执行中/取消中的锁；
   旧 token、重复结果或晚到 callback 不得再次清理选区，也不能释放后续任务的锁。

“保留当前选区”指不额外执行成功项 Unselect 或 ClearSelection。已发布的 reparent、Remove 等数据
事实仍然有效，后续事实也继续接收；不恢复任务开始时的旧 selection，不复活被移除的节点。
当前存活选区非空时保留原 mode；若节点事实已使两组确定为空，则按正常判空规则退出 mode。

### Stale 反馈与后续动作

- Explorer 展示真实 success/failed/skipped 结果，并单独提示“目录结构已变化，选区未自动清理，请重新选择”。
  没有可见 view 时保留结果与清理状态，重连同一 state 后仍可读取。
- 不自动换用当前 topology 重试 Unselect，不重新 PrepareSources 后重放原 IO，也不推断移动后的新源项。
  用户整理选择并显式触发的动作是新任务。
- 该策略允许成功项在冲突后暂留选区。它只约束结果清理，不保证外部 filesystem 快照，也不回滚已发生的 IO。

例如 A、B 起初平级且都选中，本次复制 A 成功、B 失败。结果回写前 B 被外部移入 A：

```text
A/       # 本次复制成功
└─ B     # 本次复制失败
```

该 reparent 使原 cleanup context 失效。整批成功项清理返回 `Stale`，不执行 Unselect(A)，
所以不会由此次清理取消 B；A 的 success 与 B 的 failed 均保留，任务释放锁并提示重新选择。

## 已确认的例子

### 自身与递归交错

P 有 leaf 子项 A、B，起初均未选中，children 完整：

```text
select_node(P, { recursive = false })    -> P 已选，A/B 未选
select_node(P, { recursive = true })     -> P/A/B 全选
deselect_node(P, { recursive = false })  -> P 未选，A/B 仍选；后来新增 C 也继承子树选中
select_node(P, { recursive = false })    -> P 恢复已选，后代状态不变
deselect_node(P, { recursive = true })   -> P 及全部后代未选
```

同一批 select_node([P, A], { recursive = false }) 必须分别写 P/A 的 self stamp，不能因 P 是祖先而丢弃 A。
recursive=true 则归并为 P；这一区别不由当前 Tree/List 模式或鼠标修饰键决定。
Reparent 只保存 subtree 的 inherited 并保留 self；节点自身 true/false 不会因移动被扩散给后代。

下列既有 Explorer 例子继续使用 递归 actions，表中的 stamp 指 subtree stamp，self stamp 均为 0。

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

取消 A 不写 P；P 自身仍选中，只是 full 变为 false。重新选中 A 后，P 自然恢复 full，P 的 stamp
仍为 3。A、B 都被取消后 selection 仍包含 P 自身；随后 Toggle P 才使两组都为空并退出 mode。

### 成功项清理

P 自身选中，子项 A 全选、X 未选中；当前为 `subtree_roots={A}`、`self_only_nodes={P}`。
复制只消费 A。Context 有效且复制成功时，清理只写 A 的取消 stamp，结果为
`subtree_roots={}`、`self_only_nodes={P}`，mode 保留。若 A、B 同时为源项而仅 A 成功，
则保留 B 的子树选择与 P 自身；若成功删除 A 已通过 Remove 发布，P 自身同样保留。

### 同值 Add 与 Reparent

文件 A 与空目录 Q 起初平级，初始均未选中，移动保留 A 的 NodeId：

| 操作              | A stamp | Q stamp | A 是否选中   |
| ----------------- | ------- | ------- | ------------ |
| g1：同时选中 A、Q | 3       | 3       | 是           |
| g2：取消 Q        | 3       | 4       | 是           |
| g3：再次 Add(A)   | 7       | 4       | 是           |
| A reparent 到 Q   | 7       | 4       | 是，7 覆盖 4 |

再次 Add(A) 即使没有改变当前选区，也写入 `7` 并返回 Applied；这次显式选中晚于取消 Q。
Reparent 不生成新版本，A 的 `7` 胜过新祖先 Q 的 `4`。若第三步只是切换 copy/cut mode，
则不构成 Add，A 仍保存原 stamp，并按该版本参与之后的继承竞争。

### Reparent 与 Toggle

假设空目录 P 与文件 X 起初平级，children 完整，移动保留 X 的 NodeId。两者在同一次事务中
选中，随后取消 X，再将 X 移入 P：

| 操作                         | P stamp | X stamp | `subtree_roots` | `self_only_nodes` |
| ---------------------------- | ------- | ------- | --------------- | ----------------- |
| 同时选中 P、X                | 3       | 3       | `{P, X}`        | `{}`              |
| 取消 X                       | 3       | 4       | `{P}`           | `{}`              |
| X reparent 到 P              | 3       | 4       | `{}`            | `{P}`             |
| 在 P 上 Toggle，取消 P 子树  | 6       | 4       | `{}`            | `{}`              |
| 再次在 P 上 Toggle，选中子树 | 9       | 4       | `{P}`           | `{}`              |

Reparent 后 P 自身仍选中，但 X 未选中，所以 P 的 summary 为 `{false, 0, 1, false}`。
此时 selection 非空，UI 展示 P 为仅自身选中；第一次 Toggle 正常取消这一选择，随后才退出 mode。

若 P 还有已选子项 Y，则可同时得到 `subtree_roots={Y}` 与 `self_only_nodes={P}`。
递归操作只以 Y 为源项，P 的自身选择不能作为递归操作根。

## 成本与存储

`H` 为树高，`N` 为本次访问的已知节点数，`K` 为原始范围节点数：

| 操作                        | 标记核心成本                    |
| --------------------------- | ------------------------------- |
| 已知节点自身/子树赋值、清空 | `O(1)` 写入                     |
| 单点标记查询                | `O(H)`                          |
| 聚合、操作源枚举            | 最坏 `O(N)` 时间、`O(H)` 遍历栈 |
| 基础 parent-chain 范围归并  | `O(K * H)`                      |

单点标记写入不包含派生缓存失效；失效沿祖先链处理。每种聚合的单次遍历读取每个已知节点至多一次，IO、排序和 UI 发布另计。
Reparent、标记存储及 generation 上限以 [共用成本与容量](stamps.md#成本与容量)
为准；selection 与 expansion 各自计费，结构索引修改、缓存失效与后续聚合分别计费。

## 验证要求

- 两组表示的选中节点与逐节点 `marked` 查询一致，且覆盖无重复、无遗漏。
- 验证 select/deselect/toggle 的 recursive=false/true、同一 state 交错与同值写入，缺失或非 boolean 选项拒绝且不改标记。
- 验证 recursive=false 的范围只去重、recursive=true 的范围归并；同时输入父子节点、旧 frame reparent 与 scope 固定不被重解释。
- 验证 node 自身取消保留后代及后续 child 的原继承，新的 subtree 赋值覆盖较旧 self 例外。
- 验证 self stamp 参与 marked/max_stamp 但不传给 child；未知 children 下自身已选与 full/pending 的区别。
- 验证 select_node(..., { recursive = false }) 的空分支暂归 subtree_roots、新增 child 后重算，以及 reparent 不把自身覆盖传播到后代。
- 已 full 的单点或 range Add 仍刷新 stamp；验证同值 Add 后的 reparent，以及混合目标共用一个新 generation。
- Visual c/x 对归并目标执行显式 Add；Normal 已选项的纯 mode 切换不刷新标记或 selection revision。
- 取消子项只改变目标子树的选择，祖先与旁支的权威 stamp 和自身 marked 保持原值；祖先 full 可变化。
- 子项重新选中后，原已选祖先自然恢复 full；原未选祖先不会因 children 全选而自动选中。
- 取消最后一个子项、成功清理全部递归源项后仍有祖先自身选择时，保留 mode；显式清空或 Toggle 自身才按实际结果判空。
- 验证空目录、独立 leaf、仅自身选中的祖先与完整子树后代并存，以及上述 reparent/Toggle 序列。
- 未知 children 保留 pending；已有 self-only 节点可证明 selection 非空，但不能据此声称递归源项完整。
- 验证 Ready/Pending 均带本次查询版本；Pending 完成当前 Future，补载后重新查询，单次完成不提前解锁。
- 准备所需读取失败、deadline 到期及已有 error 槽位使任务终止并解锁；已知部分源项不启动文件操作，
  失败不改写 selection/mode，节点事实造成的正常判空仍生效。
- 必要补载因硬容量不足被拒绝时终止并解锁；临时背压只等待，释放容量不恢复已经失败的任务。
- 验证失败后立即改选、共享读取继续、旧读取晚到与重复失败 callback；旧任务不能恢复执行或释放新任务锁。
- 显式重试创建新任务并校验当前 selection/mode/目标；单独刷新成功不自动重试业务动作。
- Selected-only 和压缩保留自身选择边界；业务源项确定为空时不清选区，任务清理后的判空仍考虑两组。
- 验证 selected-only 下 `selected > hidden`：已选隐藏项及连接祖先显示、反选项被过滤，hidden
  设置保持独立；关闭 selected-only 后隐藏过滤重新生效，全过程不改选择标记。
- 验证隐藏的完整选中子树、self-only、pending 范围，以及 display roots、Tree 折叠与 List 的既有边界。
- 结果清理验证正常成功/失败、外部移入/移出、移走再移回、无关 metadata/重排与范围外更新。
- 验证本任务预期 move/Remove、无法确认来源的更新、外部失效后晚到本任务结果，以及整批拒绝时不写任何清理标记。
- 清理 Stale 保留逐项 IO 结果并释放本任务锁；旧 token、重复 callback 不能影响新任务。
