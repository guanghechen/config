# Treeview 任务

Status: Design。本文定义 selection 任务的锁、源项准备、cleanup context、授权更新与 native Job discovery；
文档入口见 [Treeview](README.md)。选择状态、聚合与判空见 [selection.md](selection.md)，revision 与错误分类见
[module.md](module.md#revision-与过期输入)。任务资格由 `tasks.rs` 管理，锁、准备与清理命令位于 `engine.rs`。
业务用途、结果展示与 filesystem 校验分别属于 [Explorer](../feat/explorer.md#任务进度与结果) 与
[Filetree](../filetree.md#受任务校验的子项清理)。

## 生命周期

每个 State 同时至多一个任务。下列步骤各是一次独立的 owner 提交：

| 步骤     | Lua                                                                                             | Rust                                                      |
| -------- | ----------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| 锁定     | `state:lock_selection(deadline_ms?, selection_revision?)`，`Locked` 包装为 Task                 | `Action::Lock` / `Action::LockCurrent` → `lock_selection` |
| 准备     | `task:prepare_sources(retry?)` → `Ready` / `Pending`                                            | `Command::PrepareSources`                                 |
| 授权更新 | `task:authorize_update(cleanup, changes)` → `data:task_batch(authorization, operations, base?)` | `authorize_task_update` → `apply_task_batch`              |
| 清理     | `task:unselect(cleanup, successful)`                                                            | `Command::Unselect`                                       |
| 解锁     | `task:unlock()`                                                                                 | `Action::Unlock` → `unlock_selection`                     |

清理与解锁分开提交。Unselect 只写清理标记并把任务记为已清理，此后该任务的准备、授权、discovery 与再次清理均返回
`Stale`；锁仍由任务持有，直到 owner 提交 `unlock_selection`（Lua `task:unlock()`，native Job 经 `ReleaseTask`）。清理返回 `Stale` 时同样不解锁，owner 记录清理失败后照常解锁。
只有[准备失败](#准备失败与重试)由 Treeview 在同一提交中自动解锁。

## 锁

- 持锁期间 select/deselect/toggle 与 ClearSelection 返回 `Busy`；root、display、展开、cursor、导航与 InspectSelection 不受影响。
  锁不冻结 source，数据变化对任务的影响只由 [cleanup context](#cleanup-context) 判定。
- 传入 `selection_revision` 时，owner 在取得锁的提交中校验它等于当前值，否则返回 `Stale`；省略时在该 action 的队列位置
  读取并锁定当前选区，此前排队的改选先生效，之后的改选被拒绝。需要固定先前查询结果的调用方必须显式传入其 revision，
  过期时不退回当前版本。结构性数据提交也推进 selection revision，因此捕获后的补载同样使其过期。
- 已持锁时再次锁定返回 `Busy`。解锁只接受当前 token，旧 token 返回 `Stale`，不能释放后续任务的锁。
- 锁定与解锁推进 state revision，不推进 selection revision；锁定后的补载不影响任务资格。

## 源项准备

PrepareSources 按 [selection 聚合](selection.md#覆盖判空与计数)枚举完整 forest，不受 display root、折叠或显示过滤限制：

- Full 节点输出到 `subtree_roots` 并跳过后代；非 full 但自身 marked 的节点输出到 `self_only_nodes` 并继续向下；
  两类数量均为 0 且无 pending 的分支跳过。
- 仍需 children 才能确定分组的节点进入 `needed_children`，任务的读取需求按[读取调度](action.md#children-读取调度)补载；
  已 full 的目录不为枚举自身而加载后代。
- `Pending` 只给出已知部分，不能作为操作输入；本次 Future 已完成，补载后再次调用 `prepare_sources()`。
- `Ready` 携带 `revisions`、`summary`、两组源项、不可变 `source` 与 `cleanup` token，并固定 cleanup context；
  同一任务再次准备返回同一份 Ready。

Ready 之前，本任务所需 children 的读取结果不使任务失效；其他相关变化按 cleanup context 规则使任务失效，
此后 `prepare_sources()` 返回 `Stale`，锁仍由 owner 释放。

### 准备失败与重试

以下情况在 Ready 之前终止任务：owner 在同一提交中发布 `TaskFailed { lock, error }` 并解锁，effect 经
`data:events()` 交付。

- 任务所需的普通 children 读取失败，或读取准入因硬容量以 `ResourceLimit` 失败。
- 任务所需的 Query 结果范围失败。
- PrepareSources 遇到所需槽位已有 error（含 Query 错误）；本次 Future 以该错误 `Rejected` 完成。
- `deadline_ms` 到期：以 `Stale "source preparation deadline expired"` 失败。Deadline 只约束 Ready 之前的准备，
  Ready 后 Treeview 不再因 deadline 解锁；native Job 接管时的处理见 [Filetree 执行器](../filetree.md#串行执行)。

失败不写 selection 标记、不改用途，保留节点 error 与已接收的数据事实。单纯等待读取并发或队列容量不构成失败。
任务终止后迟到的读取只按 request token 提交有效数据，不能恢复旧任务；重复失败不会再次解锁。

`task:prepare_sources(true)` 是一次显式新尝试：当前选区所需、已有 error 且不属于 Query 的 children 槽位以新 epoch
重试并计入本任务的读取需求，返回 `Pending`；后续轮询使用默认参数。Query 拥有的槽位通过其会话重试。
重试仍失败时终止当前任务；业务层的再次尝试创建新任务并重新取得锁。

## Cleanup context

Ready 时固定 cleanup context，绑定 DataHandle、State、lock token、两组源项与准备所需节点（下称引用节点）及其祖先链。
Context 由 owner 持有；全局 revision、`frame_id` 或最新 source 不能替代它。

使 context 失效的变化：

- 引用节点自身或其后代在旧/新 topology 中的 Insert、Remove、Reparent 与 children 完整性变化，
  包括浏览读取向引用子树插入新 children、节点跨引用子树边界移入或移出。
- 引用节点祖先的 Reparent 或 Remove。
- Provider 声明引用子树内未物化的成员发生变化。

不使 context 失效的变化：metadata Update、加载状态、sibling 重排（含同 parent 内移动）、仅为祖先的节点的 Insert
或完整性变化、引用范围之外的变化，以及 root、cursor、display、展开等浏览状态。本任务的[授权更新](#授权更新)与
[读取资格](#读取资格)按各自规则处理。Context 一旦失效不再恢复，即使节点随后移回原位置。

### 成功项清理

`task:unselect(cleanup, successful)` 在同一提交中校验并写入：

1. lock 与 cleanup token 必须属于当前任务，context 有效且尚未清理，否则返回 `Stale`。
2. 每个 ID 必须属于某个 prepared `subtree_roots` 根：按 Ready 时 source 的祖先关系，或经读取资格、discovery 准入的成员；
   self-only 节点不是递归根，重复 ID 同样返回 `Stale`。不按当前同名节点或最新选区重新解释。
3. 已由本任务授权 Remove 的 ID 跳过，不复活；其余不存在的 ID 返回 `MissingNode`。
4. 按当前 source 去掉被同批成功祖先覆盖的目标，共用一个 generation 对每个目标执行 `assign_subtree(target, false, g)`，
   不写严格祖先或旁支；已由本任务移出成功祖先的子项不再被覆盖，单独清理。整批成功或整批拒绝，
   不能清理一部分后返回 `Stale`。

成功时推进 selection 与 state revision；没有剩余目标时返回 `NoChange`，任务同样记为已清理。
`Stale` 时不写标记、不分配 generation，保留当前选区；已发布的 Reparent、Remove 等数据事实仍然有效，不恢复任务开始时的选区。

例如 A、B 起初平级且都选中，复制 A 成功、B 失败；清理前 B 被外部移入 A。该 Reparent 使 context 失效，
清理返回 `Stale`，不执行 Unselect(A)，因此不会顺带取消 B；owner 保留两项的 IO 结果并解锁。

成功项的根资格按 prepared 根集合与已解析成员的共享祖先缓存判定，不为每个成功项扫描全部 prepared 根；
context 失效检测按变更节点的祖先链与受保护祖先计数判定，不为每次 metadata 或无关变化扫描全部任务源项。

## 授权更新

本任务确认的 move/delete 会产生预期的节点更新。它们必须先取得一次性授权，否则按外部变化使 context 失效：

- `task:authorize_update(cleanup, changes)` 要求任务已 Ready、context 有效且未清理，`changes` 非空。
  每项的节点必须属于 prepared 子树（含已准入成员）、仍然存活且互不重复；Reparent 的新 parent（省略表示 forest 顶层）
  必须有效且不是节点自身，也不能位于其他引用节点的子树内，同一 prepared 根内除外。
  因此已准入的子项可随所属 prepared 子树整体移动或移回，但不能并入另一个 prepared 根。
- Lua `changes` 只接受 `{ kind = "remove", node }` 与 `{ kind = "reparent", node, parent? }`。
  Rust `ExpectedChange::Slot { node, can_expand, completeness }` 仅供 native provider 声明已授权移动导致的
  展开能力或完整性的最终值。
- 返回 `TaskUpdateToken`（Lua 为 opaque string）；任务同时只保留一份待消费授权，新授权替换旧授权。
- `data:task_batch(authorization, operations, base_revision?)` 中每个结构变化（Reorder 除外）必须按顺序与授权逐项一致：
  Reparent 对应 `reparent`，Remove 对应 `remove`，完整性或 `can_expand` 变化对应 `Slot` 的实际最终值。
  出现未授权的结构变化（包括 Insert）或遗漏授权项时返回 `Stale`，整批不发布；metadata Update 与 Reorder 不需要授权。
  旧 children 的删除需要各自的 Remove 授权，不能借 `Slot` 插入新成员。
- 授权在成功提交后消费。它只豁免本任务：已 Remove 的节点记入任务，供清理时跳过；其他任务仍按自身 context 判断。
  来源不明或仅携带相同 task token 的 watcher/callback 更新不能取得这一例外。

## Job discovery

Native provider 可以自行遍历资源，不要求先把整棵操作子树装入 Source。Discovery 只对 native Job 开放，
普通 Lua 任务没有对应入口；[读取资格](#读取资格)对所有 Ready 任务生效，Job 接管前只覆盖不可再发现的槽位；资源签名与 filesystem 路径仍由 provider 校验，Filetree 的私有遍历见
[文件任务](../filetree.md#文件任务与成功子项)。

### 独立准入

一次 discovery 绑定 state、已接管任务的 native Job、lock、cleanup、直接父节点与 prepared 根，只能包含该父节点下的 Insert。
Owner 校验：

- 任务 token 与 context 有效，任务由该 native Job 接管；父节点属于该 prepared 根（原 source 或已准入成员）。
- 父节点当前不是 Complete；它在 Ready 时的 source 中也不是 Complete，且尚未[关闭](#读取资格)。
- 该父节点没有从 Complete 起始、仍有效的读取。

准入的节点与 Source 插入、provider 自身索引在同一提交中发布，成为该 prepared 根的成员，可作为清理目标。
其他任务按自身 context 判断，不因父节点相同而获得资格；错误或预算不足时不发布半份成员关系。

Discovery 是普通的 children 结构变化：父节点的 request epoch 推进，在途旧读取的页随之失效，只有仍有需求时才重新读取。

### 读取资格

Ready 任务为 prepared 子树内槽位的真实读取（ReadToken）绑定资格；资格不产生读取需求，失效任务也不阻止浏览数据发布。

- Native Job 接管前，只有不可再发现的槽位（Ready 时已 Complete 或已关闭）获得资格，且只允许该读取的分页完整性变化，
  不准入新成员。原本 Unknown/Partial 的槽位不因此获得发现资格。
- 接管时为当前有效读取绑定资格，之后的新读取在首页提交前绑定。从可发现槽位开始的读取可把插入的 children 准入为成员；
  从 Complete 开始的读取即使分页期间 Source 显示 Partial，也不准入新成员。
- 已绑定资格的读取若从 Complete 开始，或在任务期间完成，对应槽位关闭到任务结束；关闭状态不因完成、取消或重试而放宽。
  重试保持或收紧原资格，旧 epoch 的完成或取消不能移除新 epoch 的资格。
- 替换、Remove、跨范围移动等外部事实仍使 context 失效。
- Native provider 在同一次 publication 中读取 Source 与任务状态（有效性、已关闭槽位），不混用不同版本。
  任务成员、读取资格与关闭集合计入 data retained 预算。

### 成功 frontier 清理

Provider 可以分批准入已确认的成功 frontier（成功文件、完整成功子树的根及必要祖先），但只有全部批次准入成功、
原 context 仍有效时，才提交一次[成功项清理](#成功项清理)。任一批失败时不提交清理标记，此前发布的资源事实继续有效，
记录独立的清理错误后精确解锁，不重放 IO。

- 完整成功的子树用其根清理；部分成功只清理成功文件或完整成功子树，保留失败项、未遍历的旁支与严格祖先自身的选择。
- 本任务已 Remove 的节点不复活；迟到的 callback 不能清理或解锁新任务。
- 批次大小、遍历顺序、IO 原子性与容量由 provider 定义，见 [Filetree](../filetree.md#受任务校验的子项清理)。
