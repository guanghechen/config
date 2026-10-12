# Rust Treeview

Status: Design。本文定义模块边界、句柄、原子提交与生命周期；各算法以[专题契约](README.md)为准。
Lua 字段见[类型定义](../../../lua/__types__/ux/treeview.lua)，使用方式见[接入指南](../../treeview.md)。

## 模块边界

- Rust 位于 `rust/yoz/src/ux/treeview/`，binding 位于其 `lua/` 子模块；入口为 `yoz.ux.treeview`。
- Lua surface 位于 `lua/ux/treeview/`，处理输入、glyph/theme、窗口、buffer 和 viewport decorations。
- Rust 持有已发布 source、交互状态、投影与行映射。Lua producer 准备业务 records，接入见 [results.md](results.md)。
- Core 不依赖 Lua、Neovim 或 filepath。Filetree 解释资源与文件 Job，native Explorer 解释浏览和选区用途。

## 身份与数据输入

| 对象        | 职责                                                     |
| ----------- | -------------------------------------------------------- |
| DataHandle  | Source topology 与 provider key/NodeId 映射的唯一 owner  |
| NodeId      | Data 实例内不复用的 opaque `u64`；Lua 使用 opaque string |
| StateHandle | 绑定一份 Data 的交互状态                                 |
| ViewHandle  | 绑定一份 State 的 surface 连接，不保存 Neovim handle     |
| Frame       | 固定 source、状态和投影的不可变读取句柄                  |
| Revision    | 单调 `u64`，Lua 原样回传；溢出前拒绝更新，不回绕         |

Source 是有序 forest；节点只有一个 parent，结构无环。Label、排序和压缩不改变 NodeId。
Provider key、scoped import、完整快照、增量与 FFI 所有权见 [data.md](data.md)。

Children 分别记录已知子项、`unknown / partial / complete` 完整性，以及 `idle / loading / error` 请求状态。
Leaf 无 children 且完整。刷新可保留上次有效子项，只有完整成功的结果能确认缺失项已移除。

## 节点更新批次

Rust 使用 `Batch { base_revision, operations }`，Lua 使用 `data:batch(operations, base_revision?)`。
Operations 按顺序作用于私有候选，每步满足 parent 存在、identity 唯一和无环约束；整批合法才发布。

| 更新            | 语义                                                                             |
| --------------- | -------------------------------------------------------------------------------- |
| Insert          | 分配 NodeId，声明 parent、sibling 位置与初始数据                                 |
| Update          | 修改同一 ID 的数据，不隐式改变 parent 或选择                                     |
| Reparent        | 保存各 State 的旧链继承值后改 parent，标记规则见 [stamps.md](stamps.md#reparent) |
| Reorder         | 修改 sibling 顺序，不改 identity 或标记                                          |
| Remove          | 移除节点及其子树，失效相关状态和请求；不等同于缓存淘汰                           |
| Children result | 按 request token 合并子项，完整终态才能确认缺项移除                              |

需要保留的 child 先 reparent，再 remove 原 parent。显式 operations 不隐式改排；完整 import 的对齐由 owner 生成合法操作顺序。

提交过程：

1. 校验 base revision、写入范围及实际来源 context；Query 在此处重验 generation。
2. 在候选 topology 上准备数据和各 State 的标记、root、请求及任务资格补丁。
3. 校验全部更新与容量，不调用外部 callback，不发布中间状态。
4. 同次发布 Data/State 补丁、推进 revision，再释放借用并通知消费者。

候选使用受影响节点的 overlay/journal，失败全部丢弃。树状态的原子性不回滚已经发生的业务 IO。

### 新增、补载与移除

新 ID 的标记从 0 继承；补载已有 ID 保留标记，真正 Remove 才清理身份与状态。
资源暂不可访问可以表达为 error，普通刷新失败保留有效数据。

可淘汰派生 metadata/render cache。标记、展开、显式 root 或任务引用的节点及必要祖先保留结构 skeleton；
被其他入口覆盖的显式 root 也属于引用。不得为腾出缓存空间丢失已知 children、完整性或例外标记。

## State、View 与共享

State 持有 display root、display options、逻辑 cursor、selection、expansion 和任务锁。
选择与展开使用独立标记和 generation；具体语义分别见 [selection](selection.md)、[expansion](expansion.md)。
显式入口及 topology 归并见 [roots.md](roots.md)。

`selection_purpose` 是业务方解释的不透明字符串，随 selection 原子发布；精确空选区且未持锁时清除。
纯用途切换不刷新 selection stamp。`state:status()` 返回已提交的用途、锁与 revisions；
`state:display()` 返回同次 publication 的选项与 state revision，修改时不能拼接不同版本的两次读取。
任务使用已提交用途解释 Ready 源项，surface 的旧 Frame 继续描述自身画面。

支持共享 Data 各自 State、共享完整 State，以及全部独立；不提供任意字段的局部共享或跨重启恢复。
共享 State 同步逻辑状态，各 View 独立持有窗口、viewport、Visual 端点与已发布 Frame。

- `treeview.attach(state, options?)` 创建专用正文 buffer；`bufname` 只设置一次，默认使用 `treeview://` 身份。
- `options.bufnr` 仅接受空、未修改的 scratch buffer，转交所有权并保留 filetype；detach 释放它。
- `on_attach(view)` 在内部注册完成、首次 Frame 请求之前执行；失败则 detach 并传播错误。Filetree 先安装自身装饰。
- Native View 的 `poll_frame(previous?)` 同次读取 Frame 与 projection error；未变 Frame 返回 nil，当前错误仍交付。
- Detach 只解除该 View。State/Data 的其他持有者和已接受命令继续存活，关闭 pane 不清 selection 或结束 Job。
- 最后持有者释放后清理句柄、订阅与派生数据；无法继续的工作返回 Disposed，迟到 callback 不写失效 surface。
- Suspend/resume、Visual 持帧与重绑定遵循 [view 生命周期](visual.md#退出失败与生命周期)。

## Commands 与 callback

Lua `data:create_state(root, display?)` 创建独立 State；`state:dispatch(command, context?)` 返回 Future。
修改成功使用 Applied/NoChange，失败使用 `Rejected {error}`。Applied 只表示提交完成，不表示 IO 或 UI 已完成。
完整完成值与一次完成规则见 [action.md](action.md#dispatch-与-future)。

| 命令                                      | 职责                                                           |
| ----------------------------------------- | -------------------------------------------------------------- |
| SetRoot / SetDisplay                      | 设置展示范围或选项，不替换 selection                           |
| SetExpanded / ToggleExpanded              | 按 SelfOnly/Subtree scope 修改展开                             |
| SetCursor / Navigate                      | 设置逻辑 cursor 或执行结构导航，无目标时 NoChange              |
| select_node / deselect_node / toggle_node | 对 NodeIds 或 Frame 行范围选择；`recursive` 必须显式传 boolean |
| ClearSelection                            | 清空全部标记；持锁时拒绝                                       |
| InspectSelection / PrepareSources         | 查询或准备源项，后者要求任务锁                                 |
| Unselect                                  | 仅凭原任务资格清理成功项                                       |

同值赋值、NoChange 与 scope 规则见 [stamps.md](stamps.md#同值赋值与-nochange)。
Effects 包括读取/取消、Query/取消、ViewChanged、RootUnavailable、NodeInvalidated、SelectionPending 与 TaskFailed。
上层接入实际 IO 和业务 UI，不能通过 callback 直接修改 owner 内部状态。

回调在提交并释放可变借用后执行；异步结果作为新事件入队，不携带旧交互快照覆盖当前状态。
Rust worker 不调用 Lua/Neovim。

## Revision 与过期输入

- `data_revision`：节点数据、结构或加载状态提交。
- `selection_revision`：标记或会改变选择解释的结构/完整性变化，与标记 generation 分开。
- `state_revision`：交互状态提交，包含同值写入及用途变化。
- `layout_revision`：行映射、导航、压缩链或输入归并所需的 source 关系变化；纯 metadata 不推进。
- `frame_id`：固定上述输入及展示内容的一份不可变 Frame。

NodeId 输入验证实例、存活性和实际命令前提，不因无关 revision 推进而统一拒绝。
SetRoot/SetDisplay 验证 expected state revision；Frame/range/toggle 校验其捕获的 scope、目标和相对操作判据，
完整规则见 [Visual 输入](visual.md#提交圈选)。Lua 不用新行号解释旧 Frame，失效输入不重绑定同名节点。

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

普通输入错误使用结构化结果，不 panic。Lua provider 的非结构化错误归 ProviderError；
非法分页返回或 error payload 归 InvalidUpdate。上层展示错误，保留原状态或已明确提交的事实。

## Children 请求

读取由 `(DataHandle, NodeId, request_epoch)` 标识，分页附带 sequence。有效槽位的多个需求共用读取。
重试、替换请求、外部 children 结构变化及 Remove 使旧 epoch 失效；同一请求自己的分页不推进 epoch，乱序或重复页返回 Stale。
无关节点或 selection 更新不作废读取，owner 按 token 在当前 Data 上提交有效结果。

请求只更新数据与真实完整性，不恢复旧 root、展开或 cursor。普通读取没有 core 隐含超时，
provider 的 deadline 以失败结果结束；error 等待显式重试。需求与取消见 [读取调度](action.md#children-读取调度)，
完整/部分结果合并见 [data.md](data.md#完整快照增量与分页)。这些规则不允许旧 Query generation 提交结果。

## Selection 聚合与任务锁

`inspect_selection()` 返回 Inspected 及同版 summary、Source 和两组源项；`summary.pending` 表示数据未完整。
PrepareSources 的 Pending 也表示本次 Future 已完成，补载后须提交新查询，不能消费部分操作输入。

`state:lock_selection(deadline_ms?, selection_revision?)` 的 Future 返回 Task 或 Rejected；Task 通过 `prepare_sources()` 取得 Ready，
通过 `unselect(ready.cleanup, successful_ids)` 清理结果，并最终 `unlock()`。
锁、两类选取、补载失败与清理资格统一见 [selection.md](selection.md)。
只读的已物化结果选择使用 Frame 查询，consumer 接入见 [results.md](results.md#多选-list)。

## Layout 与 surface

Frame 提供头部 revisions/root/cursor/summary、逻辑行数，以及按需读取的行身份、结构、标记和展示数据。
Lua 行输入为 1-based，byte column 为 0-based；行批次的缺失位置用 0，单项查询用 nil。
Root、Tree/List、filter/sort 与文本定义见 [projection](projection.md)，结构导航与压缩见 [indentline](indentline.md)。

每个 View 从实际已显示的 Frame 生成 RenderPlan，在有界 staging 中准备，再一次性发布正文、Frame 与装饰。
纯装饰变化不写正文；部分写入失败先隔离输入，再完整 resync。交换、sentinel、预算与恢复统一见 [render.md](render.md)。

`view:range_action(submit)` 向 callback 交付捕获的 Frame、first/last 和 visual 标志，并消费返回的 Future。
第二参数为 false 时由调用方报告错误；surface 仍完成相同生命周期。`on_frame(frame)` 只在完整发布后通知上层。
Visual 的冻结、端点恢复与提交遵循 [visual.md](visual.md)，不另建 Lua 选择模型。

首次非空视图定位首个节点。更新后原 NodeId 可见则保留，否则回退到最近可见祖先、附近行；
原节点再次可见不自动跳回。空视图无逻辑 cursor，不触发隐式打开。

## 缓存与调度

权威 source、标记与必要结构不作为可丢弃缓存。派生缓存依据其完整输入身份复用，见 [projection](projection.md#输入与缓存有效性)。
Owner 的串行提交、projection 合并、native 通知、背压与容量恢复由 [action.md](action.md) 定义。
各 View 的准备与发布独立，持帧不会阻塞其他 View，也不积压中间帧的 Lua 行数组。

## 实现验收

Rust specs 位于 `rust/yoz/src/ux/treeview/`，Lua/UI specs 位于 `__test__/specs/ux/treeview/`，
真实 consumer 的 specs 位于对应 `era` 目录。各专题维护自身的行为与失败场景，不在此重复测试清单。
成本边界和端到端目标见 [performance.md](performance.md)，运行方式与测量记录见[测试指南](../../../__test__/README.md)。
