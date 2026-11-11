# Treeview 核心契约

Lua 字段见[类型定义](../../../../lua/__types__/ux/treeview.lua)，使用方式见[接入指南](integration.md)。

## 模块边界

- Rust 位于 `rust/yoz/src/ux/treeview/`，binding 位于其 `lua/` 子模块；入口为 `yoz.ux.treeview`。
- Lua surface 位于 `lua/ux/treeview/`，处理输入、glyph/theme、窗口、buffer 和 viewport decorations。
- Rust 持有已发布 source、交互状态、投影与行映射。Lua producer 准备业务 records，接入见 [results.md](../../feat/results.md)。
- Core 不依赖 Lua、Neovim 或 filepath。Filetree 解释资源与文件 Job，native Explorer 解释浏览和选区用途。
- 权威 source、标记与必要结构不作为可丢弃缓存；派生缓存依据完整输入身份复用，见 [projection](projection.md)。

## 句柄

| 对象        | 职责                                                                                                                 | Lua                                |
| ----------- | -------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| DataHandle  | Source topology、key/NodeId 映射与串行提交的唯一 owner                                                               | `ux.treeview.Data`                 |
| Source      | 某个 data revision 的不可变 topology 与节点数据；旧 Source 可被 Frame 或任务继续持有。文中 snapshot 只泛指不可变版本 | `data:source()`、`frame:source()`  |
| StateHandle | 绑定一份 Data 的交互状态                                                                                             | `ux.treeview.State`                |
| Frame       | 固定 Source、State 与投影的不可变行映射，Lua 行输入以它为准                                                          | `state:snapshot()`、`view:frame()` |
| ViewHandle  | 绑定一份 State 的 surface 连接，不保存 Neovim handle；surface 指 Lua 侧的 buffer、窗口与装饰发布                     | `ux.treeview.View`                 |
| Task        | 持有 selection 锁的任务，见 [tasks.md](tasks.md)                                                                     | `ux.treeview.Task`                 |
| Provider    | 独占写入范围，见 [data.md](data.md#写入范围)                                                                         | `ux.treeview.Provider`             |
| Query       | Provider 的查询会话，见 [query.md](query.md)                                                                         | `ux.treeview.Query`                |
| NodeId      | Data 实例内不复用的 opaque `u64`                                                                                     | opaque string                      |
| Revision    | 单调 `u64`；溢出前拒绝更新，不回绕，见 [Revision](#revision-与过期输入)                                              | opaque string，原样回传            |

Lock、cleanup、update authorization、read 与 query token 同样是 opaque 值，只能原样传回。

Source 是有序 forest；节点只有一个 parent，结构无环。Label、排序和压缩不改变 NodeId。
Children 分别记录已知子项、`unknown / partial / complete` 完整性，以及 `idle / loading / error` 请求状态。
Leaf 无 children 且完整。刷新可保留上次有效子项，只有完整成功的结果能确认缺失项已移除。
Provider key、写入范围、完整快照、增量与 FFI 所有权见 [data.md](data.md)。

### 术语

| 术语                                | 含义                                                                                                                                          |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Data / owner                        | 一个 DataHandle 及其串行提交线程，唯一持有 Source 与全部 State                                                                                |
| Feature commit                      | Consumer `prepare_frame` 返回的提交回调，与 Frame 一起发布该 viewport 的业务装饰                                                              |
| Display root                        | State 的展示入口：`ChildrenOf(node)` 展示某节点的直接 children，`Forest(nodes)` 展示一组节点，见 [Display roots](projection.md#display-roots) |
| `subtree_roots` / `self_only_nodes` | Selection 的两组派生集合，见 [selection.md](selection.md#状态与派生集合)                                                                      |
| `selection_purpose`                 | Consumer 解释的不透明用途字符串，见[用途](selection.md#用途)                                                                                  |

## 节点更新批次

Rust 使用 `Batch { base_revision, operations }`，Lua 使用 `data:batch(operations, base_revision?)`。
`base_revision` 必须等于当前 data revision，否则返回 `Stale`。Operations 按顺序作用于私有候选，
每步满足 parent 存在、identity 唯一和无环约束；整批合法才发布。

| Operation | 语义                                                                                 |
| --------- | ------------------------------------------------------------------------------------ |
| Insert    | 分配 NodeId，声明 parent、sibling 位置、初始数据与完整性                             |
| Update    | 修改同一 ID 的数据，不隐式改变 parent 或选择；改变完整性或 `can_expand` 属于结构变化 |
| Reparent  | 保存各 State 的旧链继承值后改 parent，标记规则见 [stamps.md](stamps.md#reparent)     |
| Reorder   | 修改 sibling 顺序，不改 identity 或标记                                              |
| Remove    | 移除节点及其子树，失效相关状态和请求                                                 |

需要保留的 child 先 Reparent，再 Remove 原 parent。显式 operations 不隐式改排；完整 import 的对齐由 owner 生成合法操作顺序。
Children 读取结果不是 Operation，而是按 request token 提交的独立页（`ChildrenPage`），见 [Children 请求](#children-请求)。

提交过程：

1. 校验 base revision、写入范围及实际来源 context；Query 结果在此处重验 generation。
2. 在候选 topology 上准备数据和各 State 的标记、root、请求及任务资格补丁。
3. 校验全部更新与容量，不调用外部 callback，不发布中间状态。
4. 同次发布 Data/State 补丁、推进 revision，再释放借用并交付 effects。

失败的候选整体丢弃，已发布的 Source、State 与 Frame 不受影响。树状态的原子性不回滚已经发生的业务 IO。

### 新增、补载与移除

- 新 NodeId 的标记从 0 开始沿祖先链继承，新建与加载发现都不产生 generation；补载已有 ID 保留标记；
  只有 Remove 清理身份与状态，同 key 再出现取得新 NodeId。
- 资源暂不可访问可以表达为 children error，普通刷新失败保留有效数据。
- Source 不淘汰节点，节点只因 Remove 减少。

## State、View 与共享

State 持有 display root、display options、逻辑 cursor、selection、expansion、`selection_purpose` 和任务锁。
选择与展开使用独立标记和 generation，语义分别见 [selection](selection.md)、[expansion](expansion.md)；
显式入口及 topology 归并见 [Display roots](projection.md#display-roots)。

- `state:status()` 同次返回已提交的 revisions、`locked`、`selection_purpose` 与 `projection_error`；
  `state:display()` 返回同次 publication 的 display 与 state revision，修改时不能拼接不同版本的两次读取。
- 支持共享 Data 各自 State、共享完整 State，以及全部独立；不提供任意字段的局部共享或跨重启恢复。
  共享 State 同步逻辑状态，各 View 独立持有窗口、viewport、Visual 端点与已发布 Frame。
- View 的创建、buffer 所有权、suspend/resume 与 detach 见 [View 生命周期](view.md#生命周期)。
- 最后持有者释放后清理句柄、订阅与派生数据；无法继续的工作返回 `Disposed`，迟到 callback 不写失效 surface。

## 命令

`data:create_state(root, display?)` 创建独立 State；`state:dispatch(command, context?)` 返回 Future，
完成值与一次完成规则见 [Dispatch 与 Future](action.md#dispatch-与-future)。`context` 为 `{ expected_state?, frame? }`。

| `kind`                                          | 语义                                                | 必需输入                                                   |
| ----------------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------- |
| `set_root`                                      | 设置展示范围，不替换 selection                      | `root`；context `expected_state`                           |
| `set_display`                                   | 替换 [DisplayOptions](projection.md#display-选项)   | `display`；context `expected_state`                        |
| `set_expanded`                                  | 按 scope 赋值展开，见 [expansion](expansion.md)     | `nodes` 或 `range`、`value`、boolean `recursive`           |
| `toggle_expanded`                               | 按捕获 Frame 的 expanded 判据切换                   | `node`、boolean `recursive`；context `frame`               |
| `set_cursor`                                    | 设置逻辑 cursor；节点不在当前 Frame 时 `NoChange`   | `node?`                                                    |
| `navigate`                                      | 按捕获 Frame 结构导航，无目标时 `NoChange`          | `frame`、`row`、`direction`                                |
| `select_node` / `deselect_node` / `toggle_node` | 见 [selection](selection.md#标记与交互)             | `nodes` 或 `range`、boolean `recursive`；toggle 需 `frame` |
| `clear_selection`                               | 清空全部标记与用途；持锁规则见 [tasks](tasks.md#锁) | —                                                          |
| `inspect_selection`                             | 查询两组源项，不取锁                                | —                                                          |
| `prepare_sources` / `unselect`                  | 见 [tasks.md](tasks.md)                             | `lock` 等任务 token                                        |

- 缺少 `expected_state` 的 `set_root` / `set_display` 返回 `InvalidUpdate`；Lua `state:set_root()` / `state:set_display()`
  从 `state:status()` 读取并填入当前 state revision。
- `set_expanded`、`toggle_expanded` 与 selection 命令的 `recursive` 必须是 boolean，缺失或其他类型返回 `InvalidUpdate`。
- 同值赋值、`NoChange` 与 scope 规则见 [stamps.md](stamps.md#同值赋值与-nochange)。
- 上层接入实际 IO 和业务 UI，不能通过 callback 直接修改 owner 内部状态。

## Effects 与交付

| Effect                            | 产生                                  | 交付通道                                  |
| --------------------------------- | ------------------------------------- | ----------------------------------------- |
| `NeedChildren` / `CancelChildren` | 读取调度、显式请求与取消              | `data:events()`；native reader 可先行消费 |
| `Query` / `CancelQuery`           | Query 调度、新查询与取消              | `data:events()`                           |
| `TaskFailed`                      | 任务准备失败，见 [tasks.md](tasks.md) | `data:events()`                           |
| `RootUnavailable`                 | `ChildrenOf` 入口被 Remove            | `data:events()`                           |
| `ViewChanged`                     | State 或 Data 提交                    | 仅 `Applied.effects`                      |
| `NodeInvalidated`                 | Remove 使节点失效                     | 仅 `Applied.effects`                      |

- `data:events()` 只收集上表前四行的 effect，按 work、lock 或 state 合并，同键只保留最新一项。
  这些 effect 也可能出现在触发它的提交的 `Applied.effects` 中，consumer 以 `data:events()` 为准。
- Lua Data 在轮询中消费读取与 Query effect，调用 `read_children` 或 query handler；其余 effect 交给 `on_effect`。
  Children 与 Query 页提交回复中的 `NodeInvalidated` 也转交 `on_effect`。
- Effects 在提交并释放可变借用后交付；异步结果作为新 action 入队，不携带旧交互快照覆盖当前状态。
  Rust worker 不调用 Lua/Neovim。

## Revision 与过期输入

| Revision          | 推进时机                                                                                                          |
| ----------------- | ----------------------------------------------------------------------------------------------------------------- |
| `commit`          | Owner 级计数；每次改变 Source、State（含锁与用途）或 Query 状态的提交都推进，Frame 记录生成时的 `commit_revision` |
| `data`            | Source 的任何提交，包括节点数据、结构、完整性与加载状态                                                           |
| `state`           | 该 State 的交互状态提交（含同值写入、锁与用途变化），以及任何结构性数据提交                                       |
| `selection`       | Selection 标记写入、ClearSelection、成功的任务清理，以及任何结构性数据提交                                        |
| `layout_revision` | Frame 布局相对上一 Frame 改变；纯展示数据变化不推进                                                               |
| text revision     | Frame 正文相对上一 Frame 可能改变；装饰变化不推进                                                                 |

布局指 display root、Tree/List 模式、有序行与代表 NodeId、folded chain、导航索引和范围归并所需的 source 祖先关系。
正文变化包括布局变化，以及行 label、List 祖先文本、`context_label` 或 `branch_suffix` 的改变；text revision 只在 native
内部用于 RenderPlan retarget 与 staging 复用，不导出 Lua。
结构性数据提交指 Insert、Remove、Reparent、Reorder，以及完整性或 `can_expand` 变化，包括 children 页与 Query 结果的提交；
这类提交同时推进所有 State 的 `state` 与 `selection` revision。纯 metadata Update 与加载状态变化不推进二者。
`frame_id` 标识一份固定上述输入及展示内容的不可变 Frame；两个 Frame 可以有相同 layout revision 和不同 metadata。

Native 方法 `state._native:applicable(frame, minimum?)` 判断 Frame 是否仍是该 State 当前发布的 Frame：
state/data revision 与 Query 状态未变，且 `commit_revision >= minimum`。View 在 range action 得到 `Applied` 后记录其 `revisions.commit` 作为最低要求，
不发布早于自身已提交动作的 Frame。

NodeId 输入验证实例、存活性和实际命令前提，不因无关 revision 推进而统一拒绝。
`set_root` / `set_display` 验证 `expected_state`；Frame、range 与 toggle 输入校验其捕获的目标和相对操作判据，
完整规则见 [Visual 输入](view.md#提交圈选)。Lua 不用新行号解释旧 Frame，失效输入不重绑定同名节点。
只读观察可重试，已确认的副作用与 toggle 不自动重放。业务用途和资源身份由上层在执行边界继续校验。

| 错误                   | 含义                                    |
| ---------------------- | --------------------------------------- |
| InvalidUpdate          | 输入、结构、范围或协议不合法            |
| MissingNode / NotFound | NodeId 已失效 / provider 确认资源不存在 |
| Stale                  | 捕获的身份或动作前提已改变              |
| Busy                   | 当前锁或执行条件不允许该操作            |
| Disposed               | 所属 owner 或句柄已释放                 |
| ResourceLimit          | 容量不足                                |
| ProviderError          | IO、能力或 provider 执行失败            |

普通输入错误使用结构化结果，不 panic。Lua provider 的非结构化错误归 `ProviderError`；
非法分页返回或 error payload 归 `InvalidUpdate`。上层展示错误，保留原状态或已明确提交的事实。

## Children 请求

读取由 `(DataHandle, NodeId, request_epoch)` 标识，分页附带 sequence。有效槽位的多个需求共用读取。
重试、外部 children 结构变化及 Remove 使旧 epoch 失效；同一请求自己的分页不推进 epoch，乱序或重复页返回 `Stale`。
无关节点或 selection 更新不作废读取，owner 按 token 在当前 Data 上提交有效结果。

请求只更新数据与真实完整性，不恢复旧 root、展开或 cursor。普通读取没有 core 隐含超时，
provider 的 deadline 以失败结果结束；error 等待显式重试。调度、分页与取消见 [读取调度](action.md#children-读取调度)，
完整/部分结果合并见 [data.md](data.md#完整快照增量与分页)。这些规则不允许旧 Query generation 提交结果。

## Layout 与 surface

Frame 提供头部 revisions/root/cursor/summary、逻辑行数，以及按需读取的行身份、结构、标记和展示数据。
Lua 行输入为 1-based、范围为闭区间，byte column 为 0-based；行批次的缺失位置用 0，单项查询用 nil。
Root、Tree/List、filter/sort 与文本定义见 [projection](projection.md)，结构导航与压缩见 [indentline](indentline.md#结构导航)。

每个 View 从实际已显示的 Frame 生成 RenderPlan，在有界 staging 中准备，再一次性发布正文、Frame 与装饰，
见 [render.md](render.md)。`view:range_action(submit, notify?)` 向 callback 交付捕获的 Frame、first/last 和 visual 标志，
并消费返回的 Future；`submit` 只通过返回的 Future 交付失败，不能同步抛错。Future 失败或以 `Rejected` 完成时默认由 View 报告，
`notify = false` 时由调用方报告，surface 生命周期不受影响；Visual 的冻结、端点恢复与提交遵循 [Visual 圈选](view.md#visual-圈选)，不另建 Lua 选择模型。
`on_frame(frame)` 只在完整发布后通知上层；cursor 回退见 [render.md](render.md#cursor-回退)。

## API 索引

Lua 包装方法如下；native 方法签名见 [yoz/ux.lua](../../../../lua/__types__/yoz/ux.lua)。

### Data 与 Source

| Lua                                                                        | 语义                                        |
| -------------------------------------------------------------------------- | ------------------------------------------- |
| `treeview.new_data(options?)` / `treeview.from_native(native, options?)`   | [action.md](action.md#native-notifications) |
| `data:batch(operations, base?)`                                            | [节点更新批次](#节点更新批次)               |
| `data:import(records, scope?, base?)` / `data:begin_import(scope?, base?)` | [data.md](data.md#完整快照增量与分页)       |
| `data:task_batch(authorization, operations, base?)`                        | [授权更新](tasks.md#授权更新)               |
| `data:create_state(root, display?)`                                        | [State](#stateview-与共享)                  |
| `data:create_provider(scope)`                                              | [写入范围](data.md#写入范围)                |
| `data:request_children(nodes, retry?)`                                     | [读取调度](action.md#children-读取调度)     |
| `data:source()`、`source:*`                                                | [出站读取](data.md#snapshot-与出站读取)     |
| `source:query_result(scope)`                                               | [query.md](query.md#结果替换与分页)         |

### State、Task 与 Query

| Lua                                                                                             | 语义                                                                                   |
| ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `state:dispatch(command, context?)`                                                             | [命令](#命令)                                                                          |
| `state:set_root(root)` / `state:set_display(display)`                                           | [Display roots](projection.md#display-roots)、[projection](projection.md#display-选项) |
| `state:set_expanded(nodes, value, recursive)`                                                   | [expansion](expansion.md)                                                              |
| `state:select_node` / `deselect_node` / `toggle_node` / `clear_selection` / `inspect_selection` | [selection](selection.md#标记与交互)                                                   |
| `state:lock_selection(deadline_ms?, selection_revision?)`                                       | [tasks](tasks.md#锁)                                                                   |
| `task:prepare_sources(retry?)` / `task:unselect(cleanup, successful)`                           | [准备](tasks.md#源项准备)、[清理](tasks.md#成功项清理)                                 |
| `task:authorize_update(cleanup, changes)` / `task:unlock()`                                     | [授权](tasks.md#授权更新)、[解锁](tasks.md#生命周期)                                   |
| `state:status()` / `state:display()` / `state:snapshot()`                                       | [State](#stateview-与共享)                                                             |
| `state:navigation_sequence()` / `state:note_navigation()`                                       | [导航意图](action.md#导航意图)                                                         |
| `state._native:applicable(frame, minimum?)`                                                     | [Revision](#revision-与过期输入)                                                       |
| `provider:import` / `batch` / `begin_import` / `create_query(handler)`                          | [data](data.md#写入范围)、[query](query.md)                                            |
| `query:start(input)` / `query:cancel()` / `query:info()`                                        | [query.md](query.md)                                                                   |

### Frame 与 View

| Lua                                                                                         | 语义                                                                     |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `frame:header()`、`frame:id()`、`frame:source()`                                            | [Revision](#revision-与过期输入)、[query.md](query.md#结果替换与分页)    |
| `frame:rows(first, last)`、`frame:guide_path(row, first, last)`                             | [viewport 装饰](indentline.md#viewport-装饰)                             |
| `frame:node_at`、`position`、`node`、`node_keys`、`row_keys`、`subtree_end`、`same_rows`    | [出站读取](data.md#snapshot-与出站读取)、[render](render.md)             |
| `frame:navigate(row, direction)`、`frame:adjacent_leaf(row, forward)`                       | [结构导航](indentline.md#结构导航)                                       |
| `frame:flags(node)`、`frame:marked_nodes(visible_only)`、`frame:all_marked(nodes)`          | [selection](selection.md)                                                |
| `treeview.attach(state, options?)`、`view:detach()`、`view:suspend()`、`view:resume(winnr)` | [View 生命周期](view.md#生命周期)                                        |
| `view:frame()`、`view:status()`、`view:refresh()`、`view:refresh_decorations()`             | [render.md](render.md)                                                   |
| `view:set_cursor(row)`、`view:navigate(direction)`、`view:activate()`                       | [结构导航](indentline.md#结构导航)、[默认键位](view.md#默认键位)         |
| `view:select(action, recursive)`、`view:range_action(submit, notify?)`                      | [selection](selection.md#标记与交互)、[Visual 圈选](view.md#visual-圈选) |
