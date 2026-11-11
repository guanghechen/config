# Treeview expansion

状态查询与 selection 复用 [版本标记算法](stamps.md)，两者使用独立标记和 generation。

## 自身状态与可见性

Expansion 使用共用算法的 `subtree_stamp`、可写 true/false 的 `self_stamp` 及 `clear_stamp`：

```text
expanded(n) = can_expand(n) && expansion.value(n)
```

- `expanded(n)` 只表示该节点自身是否展开，不表示全部后代都展开，也不表示 children 已加载完成。
  判断已知节点自身状态只需要 source parent 链与标记，不为这个判断加载后代。
- 不可展开 leaf 不是展开/折叠的适用目标，输入返回 NoChange 且不请求 children；可展开的空目录是适用目标，
  后续新增 children 按当前标记展示。适用目标与 NoChange 见[共用命令规则](stamps.md#同值赋值与-nochange)。
- 节点可见性由 display roots、过滤及展示路径决定。A 折叠时，其后代 B 可以仍保存 `expanded=true`，
  只是暂时不可见；重新展开 A 后使用 B 当前保存的展开状态，不还原折叠时的旧快照。
- `ChildrenOf(A)` 隐藏 A，并直接从其 children 开始投影；A 自身的折叠不隐藏这批顶层行。
  `Forest` 从 [归并后的 display roots](projection.md#display-roots) 开始，入口行不受范围外祖先折叠的门控。
  标记的继承查询仍使用完整 source parent 链，展示边界不截断版本继承。

## 普通与递归操作

`SetExpanded` 接收 NodeId、目标布尔值与 `SelfOnly / Subtree` scope：

| 操作            | 标记写入                             | 后代语义                                 |
| --------------- | ------------------------------------ | ---------------------------------------- |
| 普通展开 / 折叠 | `assign_self(n, true / false, g)`    | 保留各后代原有状态                       |
| 递归展开 / 折叠 | `assign_subtree(n, true / false, g)` | 覆盖整棵子树，包括未加载及以后新增的后代 |

- 普通 Toggle 按提交前的 `expanded(n)` 设置相反的 SelfOnly 值；递归 Toggle 使用同一个判据，
  但将相反值写入 Subtree。自身展开而后代部分折叠时，递归 Toggle 先折叠整棵子树。
- 递归赋值覆盖旧后代例外。递归展开之后单独折叠 B 会留下较新的自身 false；再次显式递归展开
  其祖先会用新版本覆盖这个例外。仅普通展开祖先则保留该例外。
- 折叠 B 不会把 A 一起折叠；expansion 与 selection 的目标操作都不额外改写严格祖先。
  Selection 通过 recursive 选项指定自身/递归 scope，按各自 scope 写 self/subtree；两种状态的 generation 仍相互独立。
- 同次多目标操作先校验全部 ID 与 context，再筛除不可展开 leaf；去重、归并、同值写入与 NoChange
  遵循[共用命令规则](stamps.md#同值赋值与-nochange)。
- 来自实际 Frame 的 Toggle 捕获 NodeId、scope 和当时的 expanded 判据，提交时校验对应前提；
  不按另一个展开状态重放旧 Toggle。绝对赋值遵循既有 expected state context，metadata 更新本身不使输入过期。

## Consumer 动作

Core View 的 `<CR>` 见[默认键位](view.md#默认键位)。其他展开键位由 consumer 定义，通过同一 owner 提交 SetExpanded 或
ToggleExpanded，不由 core 按节点类型推断；Explorer 的键位见 [Explorer 默认键位](../../feat/explorer/README.md#默认键位)。
Normal 相对动作使用 owner 执行时的状态与按键时目标；Visual 继续验证捕获 Frame 的范围和标记。

- 折叠当前展示范围：对 `ChildrenOf(R)` 的 R 写 false Subtree stamp；R 自身隐藏，当前直接 children 仍作为顶层行。
  该动作不使用覆盖整个 DataHandle 的全局 clear，也不处理展示范围之外的其他子树。
- Reveal：上层确定展示范围与目标后，只对使目标可见所需的祖先执行普通展开；不递归展开旁支。
- List 的递归展示独立于 Tree 展开状态，Tree 专用展开/折叠动作在 List 不执行；切回 Tree 使用当前保存的标记。

## 未加载后代与请求生命周期

递归展开的标记立即覆盖逻辑子树，实际数据由上层有界并发加载并分批提交。设置 stamp 本身不预先
扫描或物化后代；随着目录出现，其默认 0 stamp 自然继承展开意图，当前投影继续请求所需 children。

- Tree 只为当前展示范围中按展开、过滤等条件仍需浏览的分支产生 children 需求。隐藏分支保留标记，
  后续变为可见时再根据当时状态请求；完整展开意图不等于已经扫描全部 filesystem。
- Loading/error 属于数据请求状态；`expanded=true` 可以与 loading/error 并存，UI 分开显示。
  按 [预算与恢复规则](action.md#预算背压与恢复)，临时背压等待容量后继续；硬容量不足或读取失败
  保留已提交的展开意图及有效数据，明确报告未完成/错误，不能伪装成完整空目录。
- 用户普通折叠 A 后，解除本消费者对 A 后代的 Tree 展开需求，停止继续调度该隐藏范围的新读取；
  不清除后代展开标记。若其他 View/state、List、selection 准备或任务仍需要数据，保留其共享读取。
- 递归折叠还覆盖子树原有展开意图；之后没有新的后代改写时，普通展开 A 只打开 A 自身，后代保持折叠。
- 晚到结果按 request token 校验后只提交有效数据。结果不能写回旧展开标记，也不能在 A 已折叠时
  重新展开 A、恢复旧 root 或拉回 cursor；后续需求依据最新 state 重新计算。
- 显式重新展开恢复当前可见展开路径的加载需求。错误槽位通过显式重试/刷新恢复，不因每次投影
  都发现 expanded 而无限重试；重新展开不把 error 当作成功。
- 离开展示范围、切到 List 或关闭最后一个相关 View 时，解除对应 Tree 展开需求；展开标记随 state
  保留。重连 state 或切回 Tree 后，按最新范围及标记重新建立需求，不恢复旧请求队列。
- 标记布尔值是同步确定的，递归加载是否完整另行报告。Loader 使用既有 children token、共享订阅、
  deadline、资源预算及循环处理规则；不为展开状态另建一套读取协议。

## Topology、共享与发布

- 新增、补载与 Remove 的标记规则见[新增、补载与移除](module.md#新增补载与移除)。普通展开 A 只写 self，
  不为后代增加展开意图；没有其他递归展开继承时，新子目录默认折叠。递归展开 A 写 subtree，新子目录会继承展开，
  除非当前链上有更新的递归折叠。
- 带非零 expansion 标记的隐藏后代及必要结构 skeleton 保留，不能因它们暂不可见而丢失折叠记忆。
- Reparent 使用[共用算法](stamps.md#reparent)。普通折叠使用 self_stamp，所以 reparent 不能把节点的 effective false
  当作整个子树的继承值。例如 B 的 inherited 为 `3`、自身折叠为 `4`，移动时保存 `3`；B 自身仍受 `4` 影响，
  后代不继承这个自身折叠。
- Expansion 与 selection 分别计算标记补丁，与同一份候选 topology 原子发布。展开操作推进相应
  state revision，实际布局变化推进 layout revision；selection 标记与 generation 不因展开操作改变。
- 共享完整 state 的 View 同步展开状态；共享 data 的独立 states 各自保存展开意图。
  Selection 业务锁不锁展开，文件任务期间仍可浏览与折叠。
- Visual 持帧见 [Visual 圈选](view.md#visual-圈选)；后台展开状态、请求和其他 View 正常更新，
  冻结的旧 Frame 不作为恢复旧展开意图或继续过时读取的依据。
- 压缩链的非末端节点必须已展开，末端可以折叠（见 [indentline](indentline.md#压缩链)）；
  输入仍映射回 source NodeId，压缩本身不写展开标记。

## 例子

已知目录链为 `A -> B -> C`，初始均折叠；只列 B 的标记，C 没有自身例外：

| 操作                          | B subtree stamp | B self stamp | B 是否展开 | C 是否展开        |
| ----------------------------- | --------------- | ------------ | ---------- | ----------------- |
| g1：递归展开 A，A subtree = 3 | 0               | 0            | 是，继承 3 | 是，继承 3        |
| g2：普通折叠 B                | 0               | 4            | 否         | 是，暂被 B 隐藏   |
| g3：普通展开 B                | 0               | 7            | 是         | 是，恢复可见      |
| g4：递归折叠 B                | 8               | 7            | 否         | 否                |
| g5：普通展开 B                | 8               | 11           | 是         | 否，仅 B 自身打开 |
| g6：递归展开 B                | 13              | 11           | 是         | 是，旧例外被覆盖  |

此后加载发现 B 下的新目录 D，D 的两个 stamp 为 0，自然继承 `13` 并展开。若用户随后普通折叠 B，
D 保留自己的展开状态但暂时不可见，晚到的 children 结果不会重新打开 B。
