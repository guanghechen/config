# Treeview action queue

Status: Design。本文定义串行提交、Future 与 Pending 语义、读取队列、预算与全部默认容量；文档入口见 [Treeview](README.md)。
命令、revision 与 effect 交付见 [核心契约](module.md)，任务语义见 [tasks.md](tasks.md)。

## 串行提交

同一 DataHandle 及其 States 的全部写入——用户命令、节点更新、children/Query 结果、任务操作与 native consumer action——
都进入 owner 的 action queue，按顺序在 owner 线程短处理并原子提交。耗时 IO 在外部执行，结果作为新 action 入队。

1. 入队时固定命令输入、scope 与 context；行输入持有实际显示的 Frame，直到该项处理结束。
2. 处理时按当前状态校验节点、context 与锁，再原子提交；过期或不合法的输入返回既有错误。
3. 提交后释放内部借用，再完成 Future、交付 effects；需要 IO 的 effect 由上层执行，队列继续处理下一项。
4. IO 结果重新入队，经 request token 或相应 context 校验后提交；不自动重放原用户命令。

例如依次收到“展开 A、折叠 A”，而 children 读取较慢：

```text
set_expanded(A, true)  -> Applied { ViewChanged }；随后的投影使读取调度产生 NeedChildren(A)
set_expanded(A, false) -> Applied { ViewChanged }
children_page(A)       -> 校验 token 后只提交数据，A 保持折叠
```

折叠不等待读取结束。任务等待 IO 时不占住队列，允许的浏览命令继续处理；被选区锁禁止的命令按规则拒绝，
不留到解锁后自动执行。用户命令按接收顺序解释，标记意图不因最终布尔值相同而合并，不同 scope 的 actions 各自提交，
同值规则见 [stamps](stamps.md#同值赋值与-nochange)。Neovim 滚动与 Visual 端点移动由 Lua surface 即时处理，
需要同步逻辑 cursor 时再提交命令；Query 输入的替换遵循 [query.md](query.md)。

## 导航意图

Lua `state:navigation_sequence()` 记录同一 State wrapper 上显式提交的导航意图，多个 view 共用。
`set_cursor`、`navigate`、`set_root`、`set_display`、`set_expanded` 与 `toggle_expanded` 在 dispatch 时推进它，
包括同值请求和之后被拒绝的请求。Native 自动 cursor 回退、frame 发布、selection 查询与任务清理不推进它。
绕过 Lua dispatch 的 native 输入可先调用 `state:note_navigation()` 记录意图。

该序列只供上层撤销迟到的 UI 跟随，不是 native revision，也不证明提交成功，不取消已排队的命令。
Consumer 的记录时机见 [Explorer 导航与输入时序](../feat/explorer.md#导航与输入时序)。

## Dispatch 与 Future

Lua `state:dispatch(command, context?)` 把 native Ticket 适配为 `stl.c.Future`，Future 只表达本次 action 是否处理完成：

- 排队或处理中时未完成；校验与提交结束后完成一次。不以入队成功代替 `Applied`，也不发布 Queued/Pending 中间值。
- 输入解析失败或无法取得入队容量时，立即返回已完成的 Future，值为 `Rejected`（如 `InvalidUpdate`、`ResourceLimit`）。
- 排队后校验失败以 `Rejected` 完成；owner 释放时以 `Rejected { error = Disposed }` 完成，不留下永远等待的 Future。
- `Applied` 只表示状态已提交，children IO、投影或 surface 重绘可能仍未完成；后续读取失败只更新节点 error。
- View 关闭不取消已接受的 action，观察者释放 Future 也不撤销命令；回调仍须校验 surface 生命周期。
- Future 在提交并释放内部借用后完成；Lua 通过回调或协程让出等待，不阻塞 Neovim。

| 命令                            | 成功完成值                                                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------- |
| 修改状态的命令                  | `Applied { revisions, effects }` 或 `NoChange`                                              |
| `inspect_selection`             | `Inspected { revisions, summary, subtree_roots, self_only_nodes, needed_children, source }` |
| `prepare_sources`               | `Ready` 或 `Pending`，见 [源项准备](tasks.md#源项准备)                                      |
| `lock_selection`（非 dispatch） | `Locked { revisions, token }`，Lua 包装为 Task                                              |

所有命令都可用 `Rejected { error }` 表示失败，错误分类见[核心契约](module.md#revision-与过期输入)。
Inspected 的 summary、两组源项与 `needed_children` 来自同一次查询，并附带解析这些 NodeId 的不可变 Source；
后续 publication 不改变它，调用方不能改用新的 live Source 拼接旧结果。查询不生成标记 generation。

`Pending` 与 summary 的 `pending` 只表示数据尚不完整：返回时本次 Future 已完成，上层补载后发起新查询，
旧 Future 不会再完成为 Ready。Snapshot 读取取得当前可用的不可变快照，不等待排队命令或 IO；
等待到 `Applied` 也不代表新 Frame 已显示。

## 投影与发布

Owner 线程按批处理队列：每个 action 执行后、完成其 Ticket 前，先发布 Source 与 State status，并把该 action 的 effects
放入事件队列；因此 Future 完成时 `state:status()` 已是新值，Frame 仍可能是旧的。每批最多 32 个 action 或 2 ms，
随后对有待处理变化的 State 同步执行投影，再依次处理任务 deadline、Query 调度与 children 读取调度，发布 Frame 并唤醒 Lua。
调度再次使 Frame 失效时立即进入下一轮。

- 同一批内的连续更新合并为一次投影，不逐个生成过时的中间 Frame；投影不在后台并行运行。
- 投影失败保留上一 Frame，错误经 `state:status().projection_error` 与 `view:poll_frame()` 交付，下次成功投影清除。
- 共享 State 的 views 读取同一 Frame；各 view 的 RenderPlan、发布与 pacing 遵循 [render.md](render.md)，
  缓存复用遵循 [projection](projection.md)。Visual 持帧期间不用新行号解释旧输入，见 [visual.md](visual.md)。

## Native notifications

Native 在发布 Frame、effects、Ticket 完成或 deadline 结果后发送可合并的唤醒信号。Lua 先确认信号再读取最新状态，
期间的新发布会再次唤醒；空闲 owner 不持续轮询，ModeChanged 和 viewport 变化显式安排检查。

- Native `data:subscribe(write_fd)` 复制调用方的 pipe write descriptor 并返回 notification lease，调用方可立即关闭原 descriptor。
  每份 data 的 lease 数受 `views` 限制；每个 lease 最多保留一个未确认字节，读取后调用 `acknowledge()`。
  `close()` 幂等，先停止 writer 再关闭 read endpoint；descriptor 不继承给子进程。Lease 与 read callback 不保活 Lua owner，
  native owner 终止时关闭所有 writer。通知通道失败时报告错误，并以轮询继续处理已接受的工作。
- 组合层通过 `new_data` / `from_native` 的 options 提供 `after_poll(preparing)`。它在 effects、views 与读取启动之后执行：
  返回 `true` 请求下一次快速检查，`false` 等待原生通知，`nil` 释放通知连接并挂起该 owner。
  挂起的 owner 在任何新的 native 请求或 Ticket 完成时恢复，attach view 也会恢复；未提供时保持默认调度。
- 挂起只断开该 owner 的通知连接，不取消 native action，也不改变任务、读取或 Frame 的所有权。
  本轮 `_poll` 回调中发起的新请求或显式 watch 保留到下一轮观察，不能被本轮的 `nil` 结果撤销；显式 `unwatch` 直接移除订阅。
- `data:events()` 在同一把锁下返回 effects 与“仍有未准备任务的 deadline”标志；到期失败的 effect 先入队，
  之后才撤销观察需求，Lua 不会先看到无任务需求再错过 `TaskFailed`。
- Native owner 在没有排队 action、待投影 State、需要轮询的 provider 工作或任务 deadline 时休眠，不周期性重建 publication。
  Action 入队、publication 确认与 native reader 显式唤醒 owner；通知状态与等待队列共用同步谓词，避免丢失唤醒。
  尚无完成通知的 provider 工作要求有界轮询，任务 deadline 独立于 Lua 活动触发。

## Children 读取调度

Owner 按 NodeId 去重读取需求，使用读取队列与有界并发：

- 需求来源为显式 `data:request_children()`、有 view 的 State 当前 Frame 所需的 children、仍可观察的刷新请求，
  以及有效任务的 `needed_children`。重复需求复用已排队或在途的读取，多个 views/tasks 不重复发起。
- 读取在出队时检查节点存活、仍可展开、仍有需求且尚未满足；Error 槽位只在显式重试后再次读取，重复投影不自动重试。
  Query 拥有的槽位不进入普通读取，见 [query.md](query.md)。
- 祖先有显式刷新请求时，后代读取等待祖先对齐后再占用读取名额。
- 分页是拉取式的：每页提交后，只有该槽位仍有需求时才请求下一页；否则读取结束，槽位保持 Partial。
  Lua provider 的后续页在本 data 有 view 正在准备发布时延后启动，首页不受影响。
- 折叠、切 root 或 detach 不使当前 epoch 失效；已发出的读取允许完成并提交有效数据。显式重试、外部结构更新及
  节点失效按 [Children 请求](module.md#children-请求) 校验，旧结果不能覆盖新事实。
- 读取成功或失败按协议结束 loading，保留已接受数据及真实完整性；任务所需读取失败的处理见
  [准备失败与重试](tasks.md#准备失败与重试)。

需求判断由 owner 依据当前消费者状态完成，不提供独立的订阅 API。

## 预算、背压与恢复

预算由 data owner 管理，分别约束在途 IO、排队工作、批次与保留数据，数值见[默认容量](#默认容量)。
各项同时约束一次工作，不保证达到节点上限前不会触及字节预算。50k/200k 是性能测试规模，与硬容量分开。

### 临时拥塞

- 并发名额已满时读取排队；读取队列已满时新需求暂不入队，容量恢复后按当前需求重新调度，不另建无界待执行集合。
  这是正常背压，不报告加载失败。
- 恢复调度时重新检查当前需求、节点与 request token；等待期间失效或不再需要的工作不再发起。
- 新命令无法入队时立即返回 `Rejected { error = ResourceLimit }`：不分配 generation、不改变状态、不持有其 Frame，
  容量恢复后也不自动执行。

### 硬容量不足

- 读取准入在 data 预算内建立候选 Source、token 与任务读取资格，检查通过才提交并发出 `NeedChildren`。
  准入失败不保留新的读取、资格或半个 epoch，对应槽位进入 `ResourceLimit` error，显式重试可恢复；
  此前已产生的 `CancelChildren` 仍交付。
- 节点、payload 或内存预算不足时，整批拒绝超限的数据批次，当前读取以 `ResourceLimit` 结束。保留此前提交的数据、
  完整性、selection、expansion 和最近有效 Frame；不能把截断的批次标为 complete，也不能把失败报告为空目录。
- 错误按节点 error 展示，不因重绘或需求重复而自动重试；单独释放容量不恢复已经失败的读取或任务。
- 必要补载因硬容量失败时任务的处理见 [准备失败与重试](tasks.md#准备失败与重试)；单纯等待并发或队列容量不构成准备失败。
- 缩小 display root 能减少后续工作，但不释放 selection、展开或任务所需的已有节点，不能为腾空间隐式 Remove 或清空选区；
  Source 节点淘汰当前未实现，约束见 [新增、补载与移除](module.md#新增补载与移除)。

### 已接受工作的收尾

- 每项在途 read/query work 发布时登记完成资格。其页、失败与取消通知不占普通入队额度，不因普通队列已满而被丢弃；
  同一 work 同时至多一个待提交通知，没有完成资格的通知以 `Stale` 拒绝。
- 每页的节点数与字节数受批次上限约束，并随消费进度施加背压：上一页提交后才请求下一页，worker 不无限积压后续结果。
- 结果因硬容量被拒绝时，仍提交对应的错误终态、结束 loading，并按任务规则失败解锁。
- 晚到结果对应的请求已失效或目标已移除时，只结束旧工作并释放其资格，不恢复旧任务或节点；
  拒绝重复或乱序的页不释放仍有效请求的资格，也不影响替代请求。

例如 List 已接收若干页，剩余节点预算为 100 而下一页需要新增 200 个节点：该页整批不提交，读取以 `ResourceLimit` 结束，
已有列表保留并报告未完成。若只是并发名额已满，则等待空位后继续，不进入错误状态。

## 默认容量

`new_data({ limits = ... })` 可覆盖 `Limits` 字段；Filetree 的覆盖值与自有限额见 [Filetree 容量](../filetree.md#容量与成本边界)。

| 项目                                            | 默认值                                      | 说明                                                                      | 代码位置                                   |
| ----------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------ |
| `memory_bytes`                                  | 512 MiB                                     | 每份 data 的 retained 总预算，含旧版本与在途候选                          | `model.rs`、`memory.rs`                    |
| `nodes` / `payload_bytes`                       | 1,000,000 / 256 MiB                         | Source 节点数与节点数据字节                                               | `model.rs`、`data.rs`                      |
| `states`                                        | 16                                          | State 数；provider 数同受此限                                             | `engine.rs`、`provider.rs`                 |
| `views`                                         | 64                                          | View 数与通知 lease 数                                                    | `runtime.rs`                               |
| `queued_actions`                                | 256                                         | 排队的普通 action 数                                                      | `runtime.rs`                               |
| 单个 action / 队列总字节                        | `batch_bytes` / 2 × `batch_bytes`           | 普通 action 的估算字节                                                    | `runtime.rs`                               |
| `concurrent_reads`                              | 8                                           | 在途 children 读取与 Query 工作共用                                       | `reads.rs`、`query.rs`                     |
| `queued_reads`                                  | 128                                         | 读取队列长度；显式请求与可观察刷新的未完成总数同受此限                    | `reads.rs`                                 |
| `batch_nodes` / `batch_bytes`                   | 200,000 / 64 MiB                            | 单个 Batch、import 或页；Query 输入 pattern 不超过 `batch_bytes`          | `provider.rs`、`query.rs`                  |
| 每轮处理                                        | 32 个 action 或 2 ms                        | 之后统一投影与调度                                                        | `runtime.rs`                               |
| 私有分块导入                                    | 每份 data 2 个                              | 暂存合计不超过 2 × `batch_bytes`                                          | `runtime.rs`                               |
| `upload:append()`                               | 512 条 / 1 MiB                              | 每个 chunk 的记录数与 Lua 输入计量；整份导入仍受批次上限                  | `lua/upload.rs`                            |
| Lua 单次输入                                    | 64 MiB / 1,000,000 项                       | 解码字节与字段项；嵌套不超过 32 层                                        | `lua/input.rs`                             |
| Lua 数组输入                                    | 200,000 项                                  | NodeId 数组、`task:authorize_update()` 的变化数等                         | `lua/input.rs`、`lua/mod.rs`               |
| 标记 generation                                 | 2^31 − 1                                    | 超出前拒绝写入                                                            | `stamps.rs`                                |
| `frame:rows()`                                  | 512 行 / 1 MiB / 8192 matches / 8192 guides | 单次 viewport 读取                                                        | `projection.rs`、`lua/output.rs`           |
| `frame:guide_path()`                            | 512 行                                      | 单次 guide 读取                                                           | `projection.rs`                            |
| `plan:lines()`                                  | 512 行 / 1 MiB                              | Lua surface 按 512 行、64 KiB 分块准备；单个 RenderPlan 文本不超过 64 MiB | `render.rs`、`lua/ux/treeview/surface.lua` |
| `children` / `slice` / `row_keys` / `node_keys` | 1024 项 / 1 MiB keys                        | 单次出站读取                                                              | `lua/mod.rs`、`lua/output.rs`              |
| `source:key()`                                  | 单个 key 1 MiB                              | 单项出站读取                                                              | `lua/mod.rs`                               |

缩进加正文超过 64 KiB 的单行使本次发布以 `ResourceLimit` 失败，该 target 不自动重试。
经 owner 提交的 action 超限时返回 `ResourceLimit`；同步出站读取（`frame:*`、`source:*`、`plan:lines()`）超限时直接抛 Lua error。
两者都不截断 source，也不篡改已有 Frame。Filter pattern、`context_label` 与 `branch_suffix` 的长度上限
属于 DisplayOptions 校验，见 [Display 选项](projection.md#display-选项)。
