# Rust Treeview

Status: Design。本文定义 `yoz.ux.treeview` 的核心运行契约；专题与新旧 API 关系见 [文档入口](README.md)。

## 模块边界

- `rust/ux` 使用 `yoz-ux` crate，treeview、filetree、explorer 共用该 crate。
- 依赖方向为 `rust/yoz -> rust/ux`；Lua binding 放在 `rust/yoz/src/ux/`，入口为 `yoz.ux.treeview`。
- Treeview core 不依赖 Lua、Neovim 或 filepath；Filetree 提供资源数据，Explorer 提供业务 callback。
- Rust 持有数据、状态、计算和文件操作；Lua 处理输入、glyph/theme、窗口和 buffer。
- Rename/move、资源 identity 和 filesystem 事件由上层解释；Treeview 只接收节点更新。

本文定义 Rust 交互树的数据、更新和运行协议；现有 `stl.view.treeview.layout` 的纯计算接口遵循
[Lua layout 契约](lua-layout.md)，其 feature-owned 状态规则不约束这里的 Rust Treeview state。
Explorer 的接入说明见 [multi-select.md](multi-select.md)，缩进与导航见 [indentline.md](indentline.md)。
版本标记、继承查询与 reparent 以 [共用标记算法](stamps.md) 为准。
已确认的 selection 语义以 [Rust Treeview selection](selection.md) 为准。
普通与递归展开/折叠以 [expansion 契约](expansion.md) 为准。
Visual 的稳定布局、提交与重绘以 [Visual 圈选契约](visual.md) 为准。
显式展示范围与动态顶层归并以 [display roots 契约](roots.md) 为准。
命令与异步结果的串行提交、Future 返回协议及 children 读取调度以 [action queue 契约](action.md) 为准。
Provider key、完整快照/增量输入及 Rust/Lua 所有权以 [data 接入契约](data.md) 为准。
Tree/List 的 filter、sort 与派生缓存有效性以 [projection 契约](projection.md) 为准。
Provider 连续查询的 generation、取消及结果替换以 [query 契约](query.md) 为准。
增量投影、正文差量、可见区域装饰及失败恢复以 [render 契约](render.md) 为准，成本与验收目标见 [performance](performance.md)。

## 身份与数据输入

| 对象        | 契约                                                                    |
| ----------- | ----------------------------------------------------------------------- |
| DataHandle  | Rust data owner 的句柄；所有节点 ID 均属于这一 data 实例                |
| NodeId      | Owner 分配的 opaque `u64`，实例生命周期内不复用；Lua 使用 opaque string |
| StateHandle | 一份交互状态，绑定一个 DataHandle                                       |
| ViewHandle  | 一次 surface 连接；绑定一个 StateHandle，不保存 Neovim handle           |
| Revision    | 单调 `u64`，Lua 使用 opaque token 原样回传；溢出前报错，不回绕          |

Provider 接入以 key 标识节点，由通用 Rust data owner 对齐并分配 NodeId；完整快照、增量与写入范围遵循 [data.md](data.md)。
Owner 发布的 readonly source 包含 `id`、`parent`、有序 children、是否可展开，以及上层提供的展示数据。
NodeId 不随 label、排序或压缩改变；每个节点只有一个 parent，结构无环，顶层节点组成有序 forest。
创建 state 或显式 SetRoot 时校验 ID 的实例与存活性，重复入口返回 InvalidUpdate；显式入口允许祖先重叠。
Forest 保存显式 NodeIds，实际 display roots 按当前 topology 派生；合法 reparent 造成的入口重叠只在展示时归并，
不删除被覆盖的存活入口，也不据此拒绝数据更新。

Children 分开保存：

- 已知子项：有序 NodeId 集合，包括仍被选择或展开状态引用的已物化节点。
- 完整性：`unknown / partial / complete`；leaf 固定为 complete 且无 children。
- 请求状态：`idle / loading / error`，包含当前 request token 与可展示错误。
- 刷新可在 loading/error 时保留上次有效 children；只有完整成功的空结果表示空分支。

Data owner 是 topology 的唯一 writer。Treeview 通过 Rust readonly source 接口读取事实，保存派生索引，
不维护第二棵权威树，不回调 Lua 逐节点取 children。业务 payload 不进入 selection 或 navigation key。

## 节点更新批次

上层提交 `TreeChangeBatch { base_data_revision, operations }`。Operations 按顺序作用于私有候选状态，
全部合法才一次发布；每个步骤均须满足 parent 存在、唯一 ID 和无环约束。

| 更新            | 做法                                                                                 |
| --------------- | ------------------------------------------------------------------------------------ |
| Insert          | 分配新 NodeId，提供 parent、相对 sibling 的插入位置及初始数据                        |
| Update          | 修改同一 ID 的展示数据或属性，不隐式改变 parent 或选择                               |
| Reparent        | 分别保存 selection/expansion 的旧链 inherited，再改 parent；不生成标记版本或修补祖先 |
| Reorder         | 更新同组有序 children；只影响投影、导航和输出顺序                                    |
| Remove          | 移除当前候选状态中该节点及其子树，失效对应状态与请求；不是卸载缓存                   |
| Children result | 按 request token 合并已知子项；完整结果才能确认缺失节点的移除                        |

需要保留的 child 必须先 reparent，再 remove 原 parent。相同 ID 多次更新遵守批次顺序；
不将整批操作隐式改排，也不由 Treeview 猜测两个不同 ID 是同一资源。

Provider 查询产生的批次还须携带 [查询归属](query.md#提交时校验)，在实际提交处验证会话、generation 与结果范围。
新一轮结果替换和本轮分页追加必须明确区分；查询版本校验不替代本节的原子性、base revision 与节点生命周期校验。

提交过程：

1. 校验 `base_data_revision`，在 owner 的候选 topology 上解释 operations。
2. 对连接该 data 的每份独立 state，按各自标记准备 reparent 写回和被移除 ID 的清理；在整批最终 topology 上
   清理失效显式入口、派生无祖先重叠的 display roots，保留被覆盖的存活入口及原顺序。
3. 验证全部更新、请求 token、任务 cleanup context 的失效或预期推进及状态补丁；期间不调用外部 callback，不发布中间 UI。
4. Owner 在同一提交阶段发布 data 和 state 补丁，递增 revision，随后通知 views。

候选状态使用受影响节点的 overlay/journal，不复制整棵树。失败丢弃候选结果，原 data/state 不变。
这只保证树状态的原子性，不回滚上层已经发生的业务 IO；上层须重新读取事实后提交更新。

### 新增、补载与移除

- 新 NodeId 的 selection/expansion subtree/self stamp 均为 0，分别沿当前祖先链自然继承，不生成 generation。
- 补载已存在 NodeId 只补充数据，保留标记、展开及 identity；不得当作新节点重置。
- Remove 清理被移除 ID 的标记、展开、缓存和请求；存活祖先的选择标记不因删除而被补写。
- 资源暂不可访问可以由上层表达为节点 error；只有明确 Remove 才失效 NodeId。
- 普通刷新失败保留有效数据；部分 children 结果不能把尚未返回的项当作已删除。

可淘汰不影响事实的 metadata/render cache；带标记、展开、显式 root 或任务引用的节点及其祖先保留结构 skeleton。
被其他入口覆盖的显式 root 同样保留结构引用。
Selection 存在时不因折叠或缓存预算丢失已知 children、子项完整性或例外标记。

## State、View 与共享

State 持有 display root、展开状态、filter/sort 输入、展示开关、逻辑 cursor、selection、选区锁及派生缓存。
Forest 的显式入口是权威范围，实际顶层入口为派生结果；移入另一入口时去重展示，移出后恢复原入口顺序。
Selection 的 `subtree_roots` 与 `self_only_nodes` 从同一份权威 stamp 派生，使用统一的 selection revision。
Selection 保存 subtree/self stamp；自身 action 只改自身，递归 action 覆盖目标子树，祖先自身不被额外改写。
Full 与两类集合从当前覆盖派生，具体输入映射由上层选择明确的 action，不由 core 设置 consumer 默认 scope。
Expansion 使用独立的 subtree/self stamp 和 generation；自身展开/折叠与递归操作分别写 SelfOnly/Subtree scope，
展开节点集合与可见行均为派生结果。递归展开覆盖未加载后代，随当前投影的有界异步请求继续加载。
上层 feature state 持有 copy/cut 等用途；composition 用同一 commit revision 发布 core 与 feature 的结果。

提供三种组合：共享 data 各自 state；共享 data 和完整 state；data/state 全部独立。
暂不提供任意字段的局部共享。共享 state 同步 root、展开、cursor、selection 和锁；各 view 的 window、
viewport、Visual marks、焦点与已绘制 frame 属于 Lua surface。
Visual 期间本 view 保持圈选布局和两个端点；后台 state 及其他 views 照常更新，本 view 结束圈选后再显示布局变化。
每个独立 view 的 Lua surface 使用专用正文 buffer，可以共用 Rust snapshot，不能相互改写已显示的正文。

- `attach` 创建 ViewHandle，立即取得当前 snapshot；`detach` 只解除该 view 的连接。
- 上层、view 或业务任务持有 state 时继续存活；关闭 pane 不清空 selection 或结束任务。
- 最后 owner 释放 state 后清理订阅和派生缓存，晚到结果返回 `Disposed`。
- 同一 DataHandle 的读取可由多个 state/view 共用，由上层 data owner 管理需求与取消。
- Task 保留必要句柄直至终止；节点被 Remove 时向上层报告失效 ID，不按同名资源替换任务源项。
- 本契约不定义跨重启持久化和任务恢复。

## Commands 与 callback

State/view binding 暴露 `create_state / attach / detach / dispatch / snapshot`；DataHandle 由上层 Rust data owner 创建，
原生 provider 与 Lua adapter 的数据提交路径遵循 [data 接入契约](data.md)。
`create_state(data, root, display_options)` 创建独立 state，`attach(state)` 返回 view；共享通过传入同一句柄表达。
`dispatch` 接收 StateHandle、命令及其 context token，统一返回 Future，不在借用可变状态时执行 Lua。
Future 完成值为该命令的成功 payload 或 `Rejected {error}`：修改状态使用 Applied/NoChange，
InspectSelection 使用带版本的 summary 与 needed children，PrepareSources 使用 Ready/Pending。
入队失败返回已完成的错误 Future；Pending 只表示源项数据不完整，不表示队列项尚未处理。
完整返回形状与一次完成规则遵循 [Dispatch 与 Future](action.md#dispatch-与-future)。下表描述完成值的语义。

| 命令                                      | 输入与结果                                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------------------------------ |
| SetRoot                                   | ChildrenOf(NodeId) 隐藏 root；Forest(NodeIds) 保存显式入口、派生有序顶层；不替换 selection |
| SetExpanded                               | NodeId、目标布尔值、SelfOnly/Subtree scope；递归覆盖未加载后代，返回必要的 children 请求   |
| SetDisplay                                | Tree/List、filter/sort 输入和展示开关；不改标记                                            |
| SetCursor / Navigate                      | NodeId 或结构方向；无目标时 NoChange，List 结构跳转同样不执行                              |
| select_node / deselect_node / toggle_node | 显式 NodeIds 或 frame 行范围及必填 recursive；false 只去重，true 归并最外层根              |
| ClearSelection                            | 清空标记语义，返回准确空选区；持锁时拒绝                                                   |
| Unselect                                  | 成功项 NodeIds、lock token 与 cleanup context；全部校验后原子清理，仅允许任务 owner        |
| InspectSelection                          | 返回覆盖、两类选取计数及 selection 非空状态；信息不足时返回所需 children                   |
| PrepareSources                            | 上层持锁后查询两组选取，每次返回 Ready 或 Pending；业务按动作契约消费，不执行部分源项      |

Selection 的完整 action 名称与 scope 见 [selection](selection.md#标记与交互)，所有 action 仍经 dispatch 返回 Future。
Explorer 文档中的 Add/Toggle 指其既有 subtree 交互；受任务 token 保护的 Unselect 继续执行子树成功项清理。

标记命令遵循 [同值赋值与 NoChange](stamps.md#同值赋值与-nochange)：select/deselect 与 SetExpanded 有适用目标时
即使当前值相同也写入新 stamp，返回 Applied 并发布对应 revision。NoChange 仅用于没有适用目标，
不能替代节点/context 校验；generation 更新本身不要求推进 layout revision、重绘或重新加载。

Treeview 只返回通用 effects：`NeedChildren`、`SelectionPending`、`ViewChanged`、`RootUnavailable`、
`NodeInvalidated`。上层接入实际加载、业务 action 和确认 UI；文件动作名称不是 Treeview enum。

调用 callback 前完成内部提交并释放借用；callback 可同步返回或异步完成。完成结果作为新的节点/状态
命令进入 owner，不能直接写内部字段，也不能把旧 cursor、root 或 selection 快照一起恢复。

## Revision 与过期输入

- `data_revision`：每次发布节点数据、结构或加载状态变化递增。
- `selection_revision`：标记变化或可能改变选择解释的结构/children 完整性变化递增，包含同值 Add 的 stamp 更新；它与标记 generation 分开。
- `state_revision`：Treeview 交互状态提交递增，包含同值标记写入；上层 mode 使用自己的 feature revision，并与 selection 原子发布。
- `layout_revision`：圈选布局、行映射、导航或 source 祖先归并信息改变时递增；不影响这些结果的 metadata 更新不递增。
- `frame_id`：一次不可变布局及展示快照，包含上述 revision 和自身行映射。

普通 NodeId 输入验证实例、存活性和命令前提；不因无关 metadata 更新而一律拒绝。
Range/toggle 校验捕获 frame 对应的 action scope、目标身份与 marked 等实际前提；递归 action 另校验祖先归并关系。
自身 action 只去重 ID，不因目标成为另一目标的后代而删除它或单凭该关系变化拒绝输入；
仅全局 revision 推进不直接返回 Stale，不按另一个标记状态重放 toggle。业务源项准备继续验证 selection context。
SetRoot/展示设置等绝对意图验证 expected state revision，避免覆盖另一个共享 view 的较新设置。

Lua 从实际显示的 frame 捕获行范围；Rust 使用该 frame 映射 NodeId，不用最新行号重新解释旧输入。
Visual 从进入时开始保留布局，提交时使用该布局上的实际 frame。纯插入、排序或 metadata 变化，
在目标及动作前提仍有效时不会使圈选提交失效；具体校验遵循 Visual 契约。
过期 frame 已被释放、节点失效或 context 不符时返回 `Stale / MissingNode`，刷新后由用户重新触发。
只读查询可重试；有副作用的 action、toggle 和已确认的用户输入不自动重放。
依赖 copy/cut 等用途的 action 由上层额外校验 feature revision，Treeview 不解释业务 mode。

错误统一为 `InvalidUpdate / MissingNode / Stale / Busy / Disposed / ResourceLimit`；普通输入错误返回
结构化结果，不 panic。上层负责消息展示，Treeview 保持原状态或已明确提交的事实。

## Children 请求

每个 children 槽位使用 `(DataHandle, NodeId, request_epoch)` 标识读取，分页再携带递增 sequence。
相同有效槽位的多个需求共用请求；去重、出队校验及需求变化遵循
[children 读取调度](action.md#children-读取调度)。折叠或关闭 view 不取消已发出的读取，后续读取按当前需求决定。

- 重试、替换请求或外部 children 结构更新使旧 epoch 失效；旧结果不能覆盖新数据。
  同一请求提交自己的后续 page 不推进 epoch，只校验 sequence；重复或乱序 page 返回 Stale。
- 无关节点更新或 selection 改变不使读取本身失效；owner 校验目标 epoch 后，在当前 data revision 上提交。
- 初次分页结果标为 partial；刷新先保留旧集合，缺失项只在完整结果提交时移除。
- Loading 不锁选区，允许浏览、折叠和改选；返回结果按最新状态投影，不重新展开或拉回 cursor。
- Tree 递归展开的标记立即生效，所需 children 有界异步读取；折叠解除本消费者对隐藏范围的展开需求，
  共享读取按剩余需求继续。结果只提交数据，不写展开标记；展开意图与加载是否完整分别报告。
- 加载失败附着于对应节点并允许重试；刷新失败保留仍有效的数据，首次失败不报告为空。
  Error 槽位等待显式重试/刷新，不因重复 NeedChildren 在每次重绘中无限重试。
- 切 root、退出 List 或关闭 view 不恢复旧视图；仍有效的共享数据结果可以由 owner 接收。
- 普通读取没有 Treeview 隐含超时；上层 callback 声明 deadline，并以 error 结果结束。失效结果不得复活节点。

上述允许在途 children 读取完成的规则不适用于过期 provider 查询；查询结果遵循 [query.md](query.md)。

## Selection 聚合与任务锁

查询返回 `{full, known_roots, known_self_only, pending}`，使用已确认的两类选取聚合与判空契约。
`known_roots + known_self_only > 0` 可证明 selection 非空；两类均为 0 且无 pending 才是空选区。
完整子树计作一个 root，其余自身 marked 的节点计入 self-only；递归业务源项单独按 roots 判断。
Unknown 计数显示待定状态，按需补载直接子项，不为已完整选中的子树递归扫描。
Empty/Nonempty 通知只描述查询结果，不生成选择版本或自动补写标记；用途变化由上层完成。

标记提交后同步更新可确定的聚合；判空 pending 时保留 mode，继续读取所需 children。
用户可继续改选；读取完成只重新计算当前 selection，不用旧判空结果清空新选区。ClearSelection 始终能直接判空。

业务任务单独持有 lock token：源项准备、执行、确认和取消中禁止改选及重复提交，浏览仍可继续。
普通加载不取得或解除该锁；只有持锁 owner 可提交任务结果并释放锁。
上层 Rust 使用配对的 `lock_selection(context)` / `unlock_selection(token)`；结果清理携带相同 token。
用户 dispatch 不具备绕过锁的身份；成功项已由 Remove 清理时，上层不再对失效 ID 重放 Unselect。
Unselect 校验通过后，只向成功根写取消 subtree stamp，与交互反选使用相同写入范围；不取消严格祖先自身。
锁住 selection 不冻结数据事实；上层仍可提交节点变化，任务通过 context/失效通知决定后续处理。
Ready 源项绑定 data/selection revision；上层在该数据版本中解析业务对象并固定输入，不在等待确认后
用更新后的对象隐式替换原目标。源项准备失败时不启动任何部分业务操作。
Ready 同时返回 `subtree_roots` 和 `self_only_nodes`；递归 copy/move/delete 只消费前者。
仅有自身选择时，递归动作不执行 IO，也不清空 selection/mode 或回退到光标项。
PrepareSources 单次查询的 Future 可完成为 Pending；上层持锁补载，允许所需 children 推进 revision，
再于新版本提交新的查询，直至 Ready 或准备失败。旧 Future 不随补载再次完成，单次查询完成不释放任务锁。
Ready 同时固定 `cleanup_context`；准备阶段的外部结构变化使原动作前提失效时返回 Stale，
由上层终止或重新准备。已经发生 IO 后不通过重新准备重放 action。

必要补载失败或 deadline 到期时，按 [准备失败与重试](selection.md#准备失败与重试) 终止任务并释放
本任务锁；selection 查询仍可为 pending/error，失败本身不清选区或切 mode。晚到读取不能恢复旧任务，
用户显式重试创建新任务并重新验证当前输入。

### 业务结果清理

结果清理遵循 [已确认的清理协议](selection.md#业务结果清理)：

- `cleanup_context` 绑定原任务、源项和相关 topology 前提；owner 根据已提交变更的旧/新关系维护有效性。
  无关 metadata、纯重排、浏览状态及不影响源项关系的范围外更新不会使其失效，不能只比较全局 data revision。
- 相关外部结构变化使 context 失效；本任务节点更新只有在 context 仍有效且归属、身份和预期范围
  都经 owner 验证时才能推进 context。晚到任务结果不能覆盖已有失效，来源不明时保守返回 Stale。
- IO 结束或确认取消停止后，将全部待清理成功项的校验和 selection 补丁放在同一串行提交中。
  Context 无效则整个清理返回 `Rejected {error=Stale}`，不执行部分 Unselect，也不递增标记 generation。
- Stale 只拒绝选区清理，不回滚节点事实或 IO 结果。Explorer 单独保存 cleanup 状态，提示重新选择；
  任务发布终止结果后仍释放自己的锁，旧 token 和重复 callback 不得影响后续任务。

## Layout 与 surface

- Forest 先按最终 topology 归并 display roots，再应用折叠、过滤和压缩；这些展示条件不恢复被祖先覆盖的顶层入口。
- Rust 对 Tree 投影生成有序 DFS 行、NodeId 映射、depth、可见 parent、首尾 child、最后 descendant、
  sibling、最后顶层项、完整 folded chain，以及独立的 connector 末项信息。
- Tree 使用展开状态；List 从递归候选范围按 filter/sort 生成平铺行及 NodeId 映射，无视觉缩进或压缩。
  List 是 source tree 的派生缓存，允许跨父节点排序，不固定为 DFS；有效性与上下文遵循 [projection](projection.md)。
- 排序、过滤及 can-fold 使用 Rust 上层提供的属性/谓词，不逐节点跨 FFI 调用 Lua。单子链满足上层条件且
  不隐藏选择边界时才能压缩；完整 source chain 和最深代表 ID 均保留。
- 上层文本必须能组成单行；名称中的换行等由上层转义。图标、字节范围和主题均不参与 identity 判断。
- 缓存命中时复用计算结果；需要更新时增量维护共享行块与索引，返回逻辑完整的不可变 Snapshot。
  一般 diff 与 Reset 按成本和预算选择，不为每次局部变化重建全部 layout；buffer 保存真实行，不使用虚拟空白行。
- Snapshot 头部包含 frame/data/state/selection/layout revision、root、cursor anchor、row_count、选择 summary 和加载/错误状态。
  按需 Row 批次包含代表 NodeId、folded IDs、结构索引、connector 信息、selection kind 和上层单行展示数据；
  内部使用稳定定位与顺序统计，输出时按该 frame 换算所需行号，不因局部插入重写所有后缀的绝对索引。
  Selection kind 区分自身未选、仅自身选中和子树全选；后代聚合独立表达，roots 为 0 不抹去自身选择。
  Lua 正文行为 1-based，byte column 为 0-based；批量索引用 0 表示无目标，单项查询返回 nil。
- RenderPlan 基于每个 view 实际显示的 frame，分段准备必要正文到有界 Lua staging；在不 yield 的短提交中
  应用反向 splice 或 Reset，并交换完整 frame/envelope。纯装饰变化不写正文，按当前 viewport 发布 ephemeral marks。
  发布 guard 隔离中间回调，API 部分失败后先标记失步再完整 resync；正文、映射、空 buffer sentinel 与恢复遵循 [render](render.md)。
- 上层以同一 commit revision 组装 core snapshot 与 feature snapshot，Lua 只发布这份完整 envelope；
  Treeview snapshot 不存 copy/cut enum，业务展示数据由上层附带。
- 普通行动作触发时捕获实际 frame 并持有至命令完成；Visual 进入时便保留圈选布局，其命令在 mode
  切换或交换待显示 frame 前捕获范围，持有对应 frame 至事务处理结束。旧 frame 无持有者后释放。
- Visual 期间，改变 layout revision 的 snapshot 只作为本 view 最新待显示项；相同布局的完整 envelope
  可以发布，但必须原子保存/恢复 Visual mode 和两个端点，并屏蔽程序重绘造成的退出/导航事件。
- Frame 在 Rust 中保留范围归并所需的只读 source 祖先索引。Visual 结构导航只查询实际 frame，
  先移动 surface 端点，再按现有前提同步有效逻辑 cursor；其他 view 的 cursor 更新不能拉动这两个端点。
- 提交或正常退出 Visual 后展示最新可用 snapshot。标记提交后，owner 先确认 snapshot 覆盖该提交，
  避免把提交之前的待显示帧发布回去；尚未就绪时暂留当前画面。

初次非空视图默认定位第一可见节点；空视图无逻辑 cursor。更新后同 ID 可见则保留，否则依次定位
最近可见祖先、附近可见行；原节点重新可见不自动跳回。上层可提交显式定位目标，不触发隐式打开。
压缩行保留 cursor 的 NodeId 关联；行输入默认使用最深代表节点，展开压缩后按保留的关联恢复。
ChildrenOf 的 root 被移除时输出空视图和 `RootUnavailable`，由上层选择新 root；Forest 仅从显式入口中剔除已失效 ID 并通知上层。
祖先重叠只影响派生 display roots；入口全部失效则为 Forest([])，被覆盖后再移出的存活入口恢复原位置。
Treeview 不推断 filepath，也不因 root 失效隐式选择另一个资源范围。

Tree 的 Normal/Visual 支持 `[i`、`]i`，List 均不执行；Visual 只改变范围，显式 `<Tab>`、`c`、`x` 才改 selection。
不引入 Insert 编辑模式，不新增或覆盖 `<Esc>`；所有窗口焦点及 buffer 打开由 Lua 上层管理。

## 缓存与调度

- 缓存包括结构索引、子树最大 stamp、选择 summary 和展示数据；权威标记不属于可随意淘汰的缓存。
  Summary 以子树结构 revision、子树标记 revision 和传入 stamp 为键，加载完整性变化也使其失效。
- Tree/List 派生缓存绑定 source、filter、sort 及实际使用的展示上下文；输入变化使旧结果失效，
  发布时校验完整输入身份。缓存复用与暂留旧 frame 的区别遵循 [projection](projection.md#输入与缓存有效性)。
- 变更仅使相关节点与祖先的派生缓存失效；reparent 失效旧/新祖先路径，不额外写选择标记。
- 批量更新合并受影响祖先集合，每个提交只失效一次；不对每个新增节点重复扫描已覆盖的整条祖先链。
- Owner 按 [action queue](action.md) 串行提交命令与异步结果，不等待 IO；耗时计算可使用
  不可变输入在 worker 执行，发布时校验 revision，worker 不调用 Lua/Neovim。
- 每个 state 最多有一个运行中的投影和一个最新待处理需求；共享 state 的 views 复用结构 snapshot。
  连续刷新合并，旧投影结果不覆盖新 frame；各 view 最多一个准备中的 RenderPlan 和一个最新 target 引用，
  分别完成 Lua 展示和 frame 交换，不积压中间帧的行数组。
- 进行 Visual 圈选的 view 只持有当前 frame 和最新待显示 snapshot 引用；不阻塞其他 views，不积压逐帧重绘。
- 大批次保留私有候选状态，期间可继续展示旧 frame；命令使用 expected context 校验，不发布半份布局。
- 预算与恢复遵循 [action queue 契约](action.md#预算背压与恢复)：IO/读取队列暂满时背压等待，
  新用户命令无法入队或数据达到硬容量时返回 ResourceLimit；已接受工作的完成通知保留处理容量。
  硬容量失败保留最近有效 frame，不把截断的递归结果标为完整，不因普通重绘自动重试。

## 实现验收

- Rust tests 位于 `rust/ux` 对应模块内，验证更新原子性、identity 失效、动态选择聚合和过期结果处理。
- 全已加载的 50,000 节点结构布局以单次 `< 8 ms` 为目标；深度 10,000 无递归栈溢出。
  局部发布、连续输入、压力档与合计内存遵循 [性能契约](performance.md)，不能以结构布局代替端到端指标。
- 性能分别记录核心索引、聚合、文本字节数、FFI 和 provider IO；不把完整渲染成本写成严格 `O(N)`。
- 普通导航使用已生成索引；大片子树选择不逐节点写标记，reparent 只做一次旧链标记准备。
- 核对共享/独立 state、关闭最后 view、请求重试、部分加载、Visual 旧 frame 和 source 准备失败。
- 核对 [data 验收](data.md#consumer-接入与验收)：四类 provider、key 对齐、scoped snapshot、增量、所有权与按需读取。
- 核对 [projection 验收](projection.md#例子与验收)：跨目录 List 排名、tree/filter/sort 失效、上下文依赖与过期计算。
- 核对 [query 验收](query.md#例子与验收)：连续查询替换、提交时归属校验、分页/空结果/失败与旧工作清理。
- 核对 reparent 产生 self-only、两组判空与计数、selected-only 展示，以及仅有自身选择时的业务源项为空。
- 核对 recursive=false/true 交错、父子多目标、self 例外不传给后代、未知 children 下的 full/pending 及旧 frame scope。
- 核对 Forest 入口移入/移出、链式覆盖、原顺序恢复、真正 Remove、同批临时重叠和独立 states 的各自归并。
- 核对 expansion 的 SelfOnly/Subtree scope、普通折叠保留后代记忆、未加载节点继承、reparent 及晚到加载结果。
- 核对 Visual 期间稳定行映射、metadata 重绘的两个端点恢复、共享 view 的 cursor/root 更新、
  正常退出与提交后刷新、真正失效的输入，以及 ModeChanged/旧 gesture callback 的时序。
- 核对 [局部发布验收](render.md#验收)：多区间结构修改、可见装饰、实际 base、跳帧、viewport、空 buffer 与部分写入恢复。

上述性能是实现目标，需在实现阶段实测；本设计不包含跨重启持久化及任意字段共享。
