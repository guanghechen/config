# Treeview action queue

Status: Design。本文定义 Treeview 命令、异步结果与 children 读取的调度方式。
状态、请求 token 与发布契约以 [核心契约](module.md) 及各专题为准；文档入口见 [Treeview](README.md)。

## 目标与归属

进入 Treeview state 的用户命令统一 push 到 action queue，按顺序处理。每个队列项完成一次短处理，
状态修改原子提交；耗时 IO 在后台运行，完成结果作为新事件入队。队列持续处理可执行项，不人为延迟输入。

- 串行提交入口由 Rust data owner 持有，覆盖同一 DataHandle 及关联 states，保持数据与状态补丁的原子性。
- 用户命令、节点更新及异步完成事件通过该入口提交；Treeview 返回通用 effects，由上层接入实际 IO。
- Neovim 滚动和 Visual 端点移动仍由 Lua surface 即时处理；需要同步逻辑 cursor 时再提交对应命令。
- Explorer 的文件任务及其选区锁继续遵循业务契约，Treeview queue 不定义 copy/move/delete 的执行策略。
- Provider 查询输入的替换与结果提交遵循 [query 契约](query.md)；查询工作可合并，用户标记命令仍按序提交。

## 单个队列项

1. 入队时固定命令输入、action scope 与 context；行输入持有实际显示的 frame，直到命令处理结束。
2. 处理时按当前状态校验节点、context 与任务锁，再原子提交；过期或不合法的输入返回既有错误。
3. 提交后释放内部借用，再发布 effects。需要 IO 的 effect 交给上层后台执行，队列继续处理下一项。
4. IO 完成结果重新入队，经 request token 或相应 context 校验后提交；不自动重放原用户命令。

例如按顺序收到“展开 A、折叠 A”，而 children 读取较慢：

```text
Expand(A) -> commit expanded=true, start read
Collapse(A) -> commit expanded=false
ChildrenResult(A) -> validate token, commit data
```

折叠不等待 children 读取结束；结果有效时只更新 data，A 继续保持折叠。文件任务等待 IO 时也不
占住提交队列，允许的浏览命令继续处理；被选区锁禁止的命令按既有规则拒绝，不留到解锁后自动执行。

用户命令按接收顺序解释。Add、Toggle、SetExpanded 等标记意图不能因最终布尔值相同而合并，
其 generation 与同值赋值规则遵循 [stamps](stamps.md#同值赋值与-nochange)。

## Action 的 recursive 选项

Selection 提供 `select_node`、`deselect_node`、`toggle_node`，均显式传入必填的 `{ recursive: boolean }`；
false 对应 SelfOnly，true 对应 Subtree，具体写入与范围归并见 [selection](selection.md#标记与交互)。
Action 入队时固定该值，不接受缺失选项、Lua truthy 值或提交时临时推断的默认范围。
上层决定 mouse、Ctrl+mouse、键盘或标题行如何映射；core 不按 consumer 或节点业务类型替上层选择。

自身 action 批量输入只去重 ID，递归 action 才归并最外层根。不同 scope 的 actions 按先后顺序独立提交，
不能为了合并重绘改变 recursive。两种 scope 都遵循同一选区锁、错误和 Future 完成规则，
公开 deselect 不具备任务 owner 的 Unselect 清理身份。

## Dispatch 与 Future

`dispatch(state, command, context)` 统一返回 Future。Future 表达本次 action 是否处理完成，
完成值为该命令的成功 payload 或 `Rejected {error}`；普通输入错误使用结构化完成值，不另建异常通道。

- 排队或处理中，Future 尚未完成；校验与状态提交结束后完成一次。不能仅因入队成功就返回 Applied，
  不额外发布 Queued/Pending 来表示 Future 的等待状态。
- 无法取得入队容量时，立即返回已完成的 Future，其值为 `Rejected {error=ResourceLimit}`；其他
  普通输入错误同样使用已完成或处理后完成的 Future，调用方使用统一的结果处理路径。
- Applied 表示状态已经提交，可以仍有 children IO、投影或 surface 重绘尚未完成。后续读取失败
  更新节点 error，不修改已完成的 action 结果；读取完成作为独立事件入队。
- Future 只完成一次；排队后校验失败以 Rejected 完成，owner 销毁而无法继续处理时以
  `Rejected {error=Disposed}` 完成，不能留下永远等待的 Future。View 关闭不取消仍有效的 action，观察者释放 Future
  也不撤销已经接受的命令；回调仍须校验 surface 生命周期。
- 内部提交并释放可变借用后才完成 Future、调用结果回调；worker 不调用 Lua/Neovim。
  Lua 通过异步回调或协程让出等待，不阻塞 Neovim；具体 Future 适配沿用仓库的异步工具，Rust core
  不依赖 Lua 的 Future 实现。

成功 payload 按命令固定：

| 命令             | Future 的成功完成值                                                        |
| ---------------- | -------------------------------------------------------------------------- |
| 修改状态         | `Applied {revisions, effects}` 或 `NoChange`                              |
| InspectSelection | `{revisions, summary, needed_children}`；summary 包含两类计数及 pending  |
| PrepareSources   | `Ready` 或 `Pending`，包含查询版本及对应源项 payload                     |

所有命令均可用 `Rejected {error}` 表示本次处理失败；错误分类沿用 [核心契约](module.md#revision-与过期输入)。
查询结果的 revisions/revision 记录本次读取的数据与选择版本，summary 与 needed children 必须来自
同一次查询。两组源项与 cleanup context 的内容仍由 [selection](selection.md#源项准备) 定义。

InspectSelection 与每次 PrepareSources 查询同样经过 action queue，按处理时的状态返回一次结果；
查询本身不生成标记 generation，也不为返回结果推进交互状态 revision。`Pending` 和 summary 的
`pending` 仅表示数据尚不完整：返回它们时本次 Future 已完成，上层补载后发起新的查询，不能让旧
Future 再完成为 Ready。PrepareSources 所属业务任务继续持锁，失败与解锁遵循
[准备失败与重试](selection.md#准备失败与重试)；InspectSelection 不取得任务锁。

例如 SetExpanded(A, true) 的 Future 在展开标记提交后完成为 Applied，并带 NeedChildren(A) effect；
读取此时可以仍在运行。PrepareSources 的 Future 可以随后完成为 Pending，上层补载再查询，取得
另一个完成为 Ready 的 Future，才具备完整源项；任一步查询完成均不代表文件任务已经执行完毕。

本节的 Future 协议适用于 dispatch。Snapshot 读取仍取得当前可用的不可变快照，不隐式等待排队
命令或后续 IO；等待 Applied 也不代表新 frame 已显示，surface 仍遵循既有 revision 与发布约束。

## Children 读取调度

上层 data owner 使用按 `(DataHandle, NodeId)` 去重的读取队列与有界并发执行：

- 普通需求重复到达时，复用已排队或当前有效的在途读取；多个 views/tasks 不重复发起相同读取。
  任务加入既有请求后，该请求同样是其准备所需的补载，最初由谁发起不改变这一点。
- 出队前检查节点存活、当前 children 是否仍需补载，以及当前 views/tasks/查询是否仍需要它；
  无需求或数据已满足要求时跳过。Error 槽位仍须显式重试，重复投影不触发自动重试。
- 折叠、切 root 或关闭 view 后，已发出的读取允许自然完成。有效结果可以进入 data，是否继续
  发起下一页或后代读取由当前需求决定；其他 view/task 仍需要时继续调度。
- 折叠、切 root 或 detach 本身不使当前读取 epoch 失效。显式重试、替换读取、外部结构更新及节点失效仍按
  [children 请求](module.md#children-请求) 校验，旧结果不能覆盖新事实。
- 读取成功或失败按现有协议结束 loading，保留已接受数据及真实完整性；关闭或失效的任务不能
  因读取结果恢复执行。必要读取失败时，遵循 [准备失败与重试](selection.md#准备失败与重试)。

需求判断由 data owner 使用当前消费者状态完成，不增加独立的订阅 API。Provider 的资源
预算约束实际在途 IO；action queue 不等待 IO，并不意味着可以无限发起读取。
普通 children 的在途完成策略不适用于已被新 generation 替换的搜索查询。

## 预算、背压与恢复

预算由 data owner 管理，分别约束在途 IO、排队工作、结果批次及保留的数据。以下行为固定，具体
并发数、队列长度、批次大小与节点/内存阈值在实现阶段通过规模测试确定。

### 临时拥塞

- IO 并发已满时，读取排队；读取队列也满时，暂停产生后续分页或递归工作，有空位后继续。
  这是正常 backpressure，不报告加载失败，不为等待容量创建另一份无界待执行集合。
- 恢复调度时重新检查当前需求、节点与 request token；等待期间失效或已不需要的工作不再发起。
- 新用户命令无法取得入队容量时，立即返回已完成的 Future，其值为 `Rejected {error=ResourceLimit}`；
  不分配标记 generation、不改变状态、不继续持有该命令的 frame，容量恢复后也不自动执行这个被拒绝的输入。

### 硬容量不足

- 节点或内存预算不足时，拒绝超限数据批次的全部候选更新，当前读取以 ResourceLimit 错误结束。
  保留此前已提交的数据及其对应完整性、selection、expansion 和最近有效 frame；未完成的扫描
  仍报告未完成，不能把超限批次截断后标为 complete，也不能把失败报告为空目录。
- 错误按既有节点 error 展示，不因每次重绘或普通需求重复到达而自动重试。资源条件改善后由用户
  显式重试，重新校验节点、当前需求与 request token；单独释放容量不恢复已经失败的读取或业务任务。
- 硬容量不足阻断必要源项准备时，按 [准备失败与重试](selection.md#准备失败与重试) 终止任务并解锁。
  单纯等待 IO 或读取队列容量不构成准备失败；实际读取失败或 deadline 到期仍按既有协议处理。
- 可释放不影响事实的 metadata/render cache；权威标记和必须保留的结构继续遵循
  [节点保留规则](module.md#新增补载与移除)。缩小 display root 能减少后续工作，但不保证释放
  selection、展开或任务等引用所需的已有节点，不能为腾空间隐式 Remove 或清空选区。

### 已接受工作的收尾

- 启动异步工作前预留完成通知容量；尚不能取得预留容量时不启动。完成/失败通知使用这份预留，
  不与新用户命令争抢普通入队额度，不因普通队列已满而被丢弃。
- 返回数据按节点数及 payload 字节数限制批次，并随消费进度施加背压；不能先构造无限大的结果
  再只限制通知条目数。分批结果复用该工作的通知预留，上一批处理后才交付下一批；分页仍按既有
  epoch/sequence 提交，不在 worker 中无限积压后续结果。
- 结果数据因硬容量不足被拒绝时，仍须处理对应错误终态，结束 loading，并由任务 owner 完成必要的
  失败处理和解锁。晚到结果对应的请求已失效或目标已移除时，结束该旧工作并释放自身的预留，
  不恢复旧任务或节点；拒绝重复/乱序 page 不释放仍有效请求的预留，也不影响替代请求。
- 非终态批次处理完毕只释放该批传输暂存，通知预留继续保留；该工作的成功/失败或失效终态处理
  完毕后才释放预留。共享数据与任务生命周期仍按各自契约处理。

例如 List 已接收若干页，剩余节点预算为 100，而下一页需要新增 200 个节点：该页整批不提交，
读取以 ResourceLimit 结束，已有列表保留并报告未完成。若只是并发名额已满，则等待空位后继续，
不进入错误状态。此处数量仅用于说明两种边界，不规定实际阈值。

## 投影与发布

状态提交之后的投影继续使用 [既有调度规则](module.md#缓存与调度)：每个 state 最多一个运行中的
投影及一个最新待处理需求。连续更新合并待投影状态，不逐个重绘已经过时的中间状态。
缓存复用与发布校验遵循 [projection 契约](projection.md#异步计算与显示)，核对 source、filter/sort 与展示上下文的输入身份。
各 view 的 RenderPlan 基于自己的已显示 frame；有界准备、短发布、ephemeral 装饰与失步恢复遵循 [render 契约](render.md)。
工作片与端到端延迟按 [performance](performance.md) 验收，不能在 live buffer 边分批写入边让出而保留旧映射。
旧输入的身份校验与 [Visual frame 生命周期](visual.md) 保持不变；排队不允许用新行号解释旧输入。

## 验证要求

- 验证快速展开/折叠/再展开只复用一次有效读取，折叠和导航不等待 IO，完成后不恢复旧展开状态。
- 验证多个 views 与任务共享读取、出队前需求消失、最后 view 关闭后任务仍需读取，以及不再调度无需求的后代。
- 验证旧 epoch、节点 Remove、准备失败及晚到结果；旧任务不能执行文件操作或释放后续任务的锁。
- 验证排队命令保留原 frame/context，标记意图不合并；投影合并不会丢失已提交的 selection/mode。
- 验证 recursive 在入队至提交期间不变，自身多目标不归并父子，公开动作不能绕过选区锁。
- 验证 dispatch 始终返回 Future，队列拒绝使用已完成的错误值；排队后拒绝与 Disposed 同样完成一次。
- 验证 Applied 先于后续 children 完成，晚到成功/失败不改写旧 Future，回调发生在释放内部借用之后。
- 验证 InspectSelection 的 summary、版本与 needed children 一致；PrepareSources 返回 Pending 即完成
  本次 Future，补载后新查询可返回 Ready，Future 完成不提前解锁或启动部分文件操作。
- 验证 view 关闭及观察者释放 Future 不取消已接受 action，结果回调不写入失效 surface。
- 验证 IO 并发满、读取队列满及释放容量后的自动调度；等待期间需求失效时不再发起读取。
- 验证新用户命令入队被拒绝时无状态/标记变更、frame 引用释放，容量恢复后不重放被拒绝的输入。
- 验证硬容量不足时整批拒绝、已提交数据保留、扫描不伪报 complete，以及显式重试与普通重绘的区别。
- 验证普通队列已满时已接受读取仍能报告成功/失败，数据批次超限仍结束 loading，必要准备失败仍解锁。
- 验证结果批次的节点数与字节数边界、过期/失效结果释放自身预留、重复/乱序 page 不误释放，
  以及缩小 root 不淘汰必须保留的结构。
- 验证 [provider 查询](query.md#例子与验收)在结果实际提交时重验归属，旧终态完成自身清理，不改新查询状态。
