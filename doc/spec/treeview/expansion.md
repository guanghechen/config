# Rust Treeview expansion

Status: Design。适用于 `yoz.ux.treeview`；文档入口见 [Treeview](README.md)。

本文定义展开/折叠的独立状态、普通与递归操作，以及异步加载和布局的消费方式。
状态查询与 selection 复用 [版本标记算法](stamps.md)，两者使用独立标记和 generation。

## 自身状态与可见性

Expansion 使用共用算法的 `subtree_stamp`、可写 true/false 的 `self_stamp` 及 `clear_stamp`：

```text
expanded(n) = can_expand(n) && expansion.value(n)
```

- `expanded(n)` 只表示该节点自身是否展开，不表示全部后代都展开，也不表示 children 已加载完成。
  判断已知节点自身状态只需要 source parent 链与标记，不为这个判断加载后代。
- 对通过节点/context 校验的不可展开 leaf，展开/折叠输入返回 NoChange，不写 stamp、不分配 generation、
  不请求 children。可展开的空目录是适用目标，普通和递归赋值均记录意图，后续新增 children 按当前标记展示。
- 节点可见性由 display roots、过滤及展示路径决定。A 折叠时，其后代 B 可以仍保存 `expanded=true`，
  只是暂时不可见；重新展开 A 后使用 B 当前保存的展开状态，不还原折叠时的旧快照。
- `ChildrenOf(A)` 隐藏 A，并直接从其 children 开始投影；A 自身的折叠不隐藏这批顶层行。
  `Forest` 从 [归并后的 display roots](roots.md) 开始，入口行不受范围外祖先折叠的门控。
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
- 同次多目标操作先校验全部 ID 与 context，再筛除不可展开 leaf；递归操作归并最外层适用目标，
  按提交前状态确定各目标值，共用一个新 generation 原子写入，已满足目标值的项也参与写入。
  普通 SelfOnly 操作只去重 ID，不删除同时输入的父/子目标，因为它们分别修改自身。
- 对可展开目标，SetExpanded 总是按 scope 写入新 stamp，即使自身或整棵子树已满足目标 true/false。
  同值赋值返回 Applied 并推进 state revision；完整规则见 [共用命令规则](stamps.md#同值赋值与-nochange)。
  无适用目标时才返回 NoChange；children 加载单独报告进度，重绘依据实际展示变化决定。
- 来自实际 frame 的 Toggle 捕获 NodeId、scope 和当时的 expanded 判据，提交时校验对应前提；
  不按另一个展开状态重放旧 Toggle。绝对赋值遵循既有 expected state context，metadata 更新本身不使输入过期。

## Explorer 动作映射

- `l`、`<CR>`、双击：可展开节点执行普通 Toggle；leaf 仍调用上层打开动作。
- `h`：当前节点已展开则普通折叠自身，否则定位并普通折叠 source parent；在 display root 边界停止。
- `z`：对当前分支执行递归 Toggle，作用范围包括未加载后代，不取决于之前缓存了多少内容。
- `W`：递归折叠当前展示子树，保留顶层行。`ChildrenOf(R)` 对 R 写 false subtree stamp，
  R 自身隐藏，当前直接 children 仍作为顶层行；`Forest` 对归并后的各入口写 false subtree stamp。
  该动作不使用覆盖整个 DataHandle 的全局 clear，也不处理展示范围之外的其他子树。
- Reveal：上层确定展示范围与目标后，只对使目标可见所需的祖先执行普通展开；不递归展开旁支。
- List 的递归展示独立于 Tree 展开状态，Tree 专用展开/折叠键在 List 不执行；切回 Tree 使用当前保存的标记。

## 未加载后代与请求生命周期

递归展开的标记立即覆盖逻辑子树，实际数据由上层有界并发加载并分批提交。设置 stamp 本身不预先
扫描或物化后代；随着目录出现，其默认 0 stamp 自然继承展开意图，当前投影继续请求所需 children。

- Tree 只为当前展示范围中按展开、过滤等条件仍需浏览的分支产生 children 需求。隐藏分支保留标记，
  后续变为可见时再根据当时状态请求；完整展开意图不等于已经扫描全部 filesystem。
- Loading/error 属于数据请求状态；`expanded=true` 可以与 loading/error 并存，UI 分开显示。
  按 [预算与恢复规则](action.md#预算背压与恢复)，临时背压等待容量后继续；硬容量不足或读取失败
  保留已提交的展开意图及有效数据，明确报告未完成/错误，不能伪装成完整空目录。
- 用户普通折叠 A 后，解除本消费者对 A 后代的 Tree 展开需求，停止继续调度该隐藏范围的新读取；
  不清除后代展开标记。若其他 view/state、List、selection 准备或任务仍需要数据，保留其共享读取。
- 递归折叠还覆盖子树原有展开意图；之后没有新的后代改写时，普通展开 A 只打开 A 自身，后代保持折叠。
- 晚到结果按 request token 校验后只提交有效数据。结果不能写回旧展开标记，也不能在 A 已折叠时
  重新展开 A、恢复旧 root 或拉回 cursor；后续需求依据最新 state 重新计算。
- 显式重新展开恢复当前可见展开路径的加载需求。错误槽位通过显式重试/刷新恢复，不因每次投影
  都发现 expanded 而无限重试；重新展开不把 error 当作成功。
- 离开展示范围、切到 List 或关闭最后一个相关 view 时，解除对应 Tree 展开需求；展开标记随 state
  保留。重连 state 或切回 Tree 后，按最新范围及标记重新建立需求，不恢复旧请求队列。
- 标记布尔值是同步确定的，递归加载是否完整另行报告。Loader 使用既有 children token、共享订阅、
  deadline、资源预算及循环处理规则；不为展开状态另建一套读取协议。

## Topology、共享与发布

- 新 NodeId 从 0 stamp 继承。普通展开 A 只写 self，不为后代增加展开意图；没有其他递归展开继承时，
  新子目录默认折叠。递归展开 A 写 subtree，新子目录会继承展开，除非当前链上有更新的递归折叠。
- 补载已有 ID 保留自身例外；Remove 才清理标记。带非零 expansion 标记的隐藏后代及必要结构
  skeleton 同样保留，不能因它们暂不可见而丢失折叠记忆。
- Reparent 使用共用算法：移动前保存 expansion 的旧 inherited，保留 self_stamp，再改 parent。
  新链的较新 subtree 意图仍可覆盖移动节点及后代；不额外生成版本或修补祖先。
- 普通折叠使用 self_stamp，所以 reparent 不能把节点的 effective false 当作整个子树的继承值。
  例如 B 的 inherited 为 `3`、自身折叠为 `4`，移动时保存 `3`；B 自身仍受 `4` 影响，后代不继承这个自身折叠。
- Expansion 与 selection 分别计算标记补丁，与同一份候选 topology 原子发布。展开操作推进相应
  state revision，实际布局变化推进 layout revision；selection 标记与 generation 不因展开操作改变。
- 共享完整 state 的 views 同步展开状态；共享 data 的独立 states 各自保存展开意图。
  Selection 业务锁不锁展开，文件任务期间仍可浏览与折叠。
- Visual 中的 view 遵循 [圈选契约](visual.md) 保持当前行映射；后台展开状态、请求和其他
  views 正常更新。冻结的旧 frame 不作为恢复旧展开意图或继续过时读取的依据。
- 压缩链从当前可见展开路径派生，输入仍映射回 source NodeId；压缩本身不写展开标记。

## 例子

### 普通与递归操作

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

### 已展开空目录的递归赋值

A 起初是折叠的空目录，可展开且 children 完整：

| 操作           | A subtree stamp | A self stamp | 新子目录 B   |
| -------------- | --------------- | ------------ | ------------ |
| g1：普通展开 A | 0               | 3            | 尚不存在     |
| g2：递归展开 A | 5               | 3            | 尚不存在     |
| A 下新增 B     | 5               | 3            | 继承 5，展开 |

第二步当前布尔值未变，仍须写入 subtree stamp `5` 并返回 Applied；已知空目录不因此重新请求 children。
后来 B 以默认 0 stamp 加入时，自然继承递归展开意图。普通展开只写 self，不能替代这次 Subtree 写入。

## 验证要求

- 普通折叠/展开保留后代记忆；折叠 child 不影响 parent 或旁支，递归操作覆盖旧例外。
- 递归展开覆盖未加载和新增后代；普通展开不新增后代展开意图，结果不依赖 cache 暖热程度。
- 已展开空目录再次递归展开仍写 subtree stamp，新子目录继承展开；同值递归折叠同样覆盖未来后代。
- SelfOnly/Subtree 的同值 true/false 均写新版本，验证其在 reparent 后与新祖先的竞争及 scope 边界。
- 验证混合 leaf/可展开目标、空目标、失效 ID 与过期 context；NoChange 和整批拒绝均不写标记。
- 验证自身 expanded 与可见性、可展开空目录与 leaf，以及 ChildrenOf/Forest 的展示边界。
- Reparent 保存 inherited 而非 effective；分别验证较新自身展开、较新自身折叠及新祖先版本竞争。
- 验证展开后立刻折叠、晚到结果、分页、失败重试、预算、共享请求、关闭/重连及切换 Tree/List。
- 验证递归 Toggle 的自身判据、普通多目标 scope、当前范围全部折叠、Reveal 与 selection 锁独立。
- 模型验证标记语义；实现时另验有界异步调度、UI 输入与 Visual frame 发布时序。
