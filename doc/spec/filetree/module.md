# Filetree redesign

Status: Draft。本文直接列出 Filetree 的范围、资源数据契约，以及它对树选取、投影和生命周期的支持。
本文保留业务行为及 Explorer 组合说明；Filetree 的定稿技术契约、预算与验收见
[Filetree 技术契约](../../../spec/design/filetree.md)。Explorer 专属 UI 待定项不作为 Filetree 的隐式实现前提。

## 已确认的范围

- Filetree 使用现有 `yoz` crate，位于 `rust/yoz/src/ux/filetree/`，binding 位于其 `lua/` 子模块。
- Filetree 依赖 Treeview 与既有 fs/git 工具；Treeview 不反向依赖 Filetree，不为三层分别创建 crate。
- 新 Filetree 首期仅供新 Explorer 使用；后续再推广到其他与文件相关的 treeview。
- 当前只考虑 Neovim。适度保留组合与模块边界，不为其他宿主增加适配层。
- 数据、状态和重逻辑由 Rust 持有并执行；Lua 负责 UI 交互与 Neovim 对接。
- 首期只实现真实 filesystem provider。未来 VFS 通过 Rust provider 接入；provider 负责资源访问、
  文件操作、能力声明和变更通知；首期不为未接入的 VFS 实现预留插件框架。
- 虚拟文件的 buffer 编辑、保存及 LSP/Git 集成另行设计，不纳入首期。
- 未来加密 DB provider 不意味着资源必须能转换为本地 filepath。

## 职责方向（草案）

### Filetree

Filetree 是文件资源领域的 owner，组合通用 Treeview data owner 供 Explorer 使用：

- 决定节点资源身份和结构事实；通用 data owner 持有唯一权威 parent/children topology 与 NodeId 索引。
- 已加载的目录数据、metadata、加载与刷新状态。
- 资源类型、名称比较、隐藏项判断、路径展示以及 Git/diagnostic 聚合等文件领域计算。
- 向 Treeview 提供完整 topology 和确定顺序的结构输入，支持选取、可见投影和导航计算。

资源 metadata 随 source 不可变发布；Filetree 持有派生资源索引、目录 IO 缓存和读取来源版本，
不再持有另一份可修改 topology、selection、展开状态或可见行索引。Filetree 不自行注册 Neovim keymap。

### Treeview

Treeview 持有与文件无关的交互状态：display root、展开状态、显示过滤、逻辑光标、selection 和选区锁。
它负责子树选择覆盖、子树反选、可见投影、压缩及 row/node 导航，不解释 copy/cut、不执行文件 IO。

Filetree 适配 Treeview 的结构契约，Treeview 不导入 Filetree 实现。需要未加载子项时由 Rust
composition 请求 Filetree 加载，结果通过 revision 校验后提交；Lua 不参与树结构推导。
Filetree 决定 provider key，通用 owner 分配 opaque NodeId，不各自维护一棵可修改的 topology。
Treeview 不要求节点关联 filepath；资源 identity、路径变化和新旧节点匹配由 Filetree/provider 判断。

Rename/move 通过上层提供的业务 callback 执行。完成后 Filetree 提交实际的节点数据更新、insert、
remove 或 reparent，Treeview 只根据这些结构事实更新交互状态与布局。外部 filesystem 变化同样先由
资源层识别并转换为节点更新，Treeview 不读取 watcher 事件来猜测资源发生了什么。
上层提交 reparent 时，先让 Treeview 按旧祖先链将继承值记到节点自身，再提交新 parent。
不生成新选择版本，也不做移动后选区修补；后续状态按新祖先链自然计算，业务成功项清理由上层另行提交。

### Explorer

Explorer 组合 Filetree data、Treeview state 与文件任务，拥有 workspace、上一个 display root、
select/copy/cut mode 和操作结果处理。Filetree 需要支持以下消费方式：

- 同一批节点可生成不同的显示投影，而不复制整份资源数据。
- UI 的展开、排序、过滤或光标变化不会修改文件操作的源项。
- 文件操作取得当前最外层的已选源项，以及明确的目标目录。
- 文件任务保存成功、失败、跳过和取消结果；cleanup context 有效时移除成功项，失效时保留当前选区并提示重新选择。
- Lua 获得绘制所需的数据和状态；结构查询、选择推导、排序、聚合与跳转计算在 Rust 完成。

### Filesystem provider

目录访问及 copy、move、delete 等文件操作在 Rust 侧执行。Lua 转发用户意图、确认结果，
并展示进度和错误。

首期以真实 filesystem 的行为验证 provider 边界。未来 VFS 不要求实现当前阶段未使用的
能力；具体 capability、资源标识和异步接口仍需单独确定。

## 必须支持的浏览能力

以下是新 Explorer 延续当前浏览能力时，对 Filetree 的直接要求，不通过引用其他实现补足。

### 节点、路径与目录加载

- 查询节点、父节点、直接子项、祖先链及后代关系。
- 节点保留原始名称、类型、资源定位信息和 provider 可提供的 metadata。
- 本地目录与文件可以有相同显示前缀，但身份与 parent 关系必须明确，不能只依赖字符串前缀判断祖先。
- Tree 展开时读取直接子项，未展开的更深层目录可保持未加载；List 主动递归读取 display root 下的资源。
- Tree 递归展开使用 [expansion 契约](../treeview/expansion.md)：未加载后代继承展开意图，
  Filetree 按当前有效需求有界读取，折叠解除对应订阅，结果不写展开标记。
- 分别表达有效子项数据与当前请求状态，允许刷新中/刷新失败时保留上次有效数据；失败不是空目录。
- 对 Treeview 提供完整直接子项的加载结果；若 provider 分页，未读完的页不能当作完整子项集合。
- 隐藏或过滤是投影条件，不能让 data 或 selection 丢失真实子项。
- 本地目录 symlink 可用于浏览；资源同时保留链接自身与可用的目标信息，文件变更仍作用于所选资源。
- 刷新及节点移除、插入、rename/move 要更新索引，并使相关投影失效。
- NodeId 不因排序、过滤、压缩或换行而改变；资源身份与展示节点身份分别定义，row number 不是身份。
- 结构更新携带 revision 与已确认的身份变化；不能因暂未加载便把节点报告成已删除，也不能把
  删除后同名新建的资源静默当作原节点继承选择。身份对齐遵循
  [Identity 契约](../../../spec/design/filetree.md#identity-对齐)。

Children 加载不锁定 Treeview 选区，用户可继续折叠、导航和改选。Filetree 返回有效数据及加载状态，
Treeview 按最新交互状态重投影，不恢复请求时的 root、展开状态或光标。
数据与投影继续更新；处于 Visual 的 view 按 [圈选契约](../treeview/visual.md)
暂缓会改变行映射的 frame 交换，不阻止 Filetree 加载或其他 views 发布最新状态。
加载失败须提供节点错误和重试能力；刷新失败保留上次有效数据，首次失败保持未知，不能伪造空目录。
上层管理共享读取的需求与取消；一个 view 切换 root 不自动中断其他 view 所需读取。
请求结果须通过 revision 校验，旧结果不得覆盖新的数据或已确认的节点移除。

### 排序和显示过滤

- 目录排在文件前；同类名称按忽略 ASCII 大小写的字节序升序比较。
- 显示隐藏项默认开启；隐藏项为名称以 `.` 开头的 item。
- 仅显示选中项默认关闭；开启时保留选中项及连接它们所需的祖先路径。
- 隐藏项与 selected-only 的组合遵循 [selected > hidden](../treeview/selection.md#selected-only-与-hidden)；
  Filetree 提供完整 source 与隐藏项信息，不先删除被隐藏过滤的真实节点。
- Git ignored 与隐藏项不是同一过滤条件；ignored 默认以装饰显示，不据此自动删除节点。
- 过滤不会清除 selected items，也不会改变 copy/cut mode。
- 首期没有独立的自然排序、按大小/日期排序或实时文本过滤契约。

### 布局与导航查询

以下计算由 Treeview 持有，Filetree 提供资源结构和展示数据，不重复实现 layout：

- Tree 从 display root 的直接子项开始，以当前展开状态决定可见后代。
- 提供稳定的可见节点序列，以及 node → row、row → node 的双向定位。
- 提供行深度、可见父行、首尾子项、最后后代和下一兄弟项等导航信息。
- Tree 的 `[i` 使用可见父行，`]i` 优先最后直接 child，再取最后 sibling；List 不支持这两个键。
  Filetree 提供结构，不用 filepath 推算这些行。
- 绘制 connector 的兄弟信息与可见导航索引分开；Explorer selected-only 保留过滤前 source sibling 的连接线。
- 节点数或深度增大时使用显式 traversal stack，避免递归调用栈溢出。
- 相同 data/state 输入必须产生相同投影；Lua 不通过重新遍历树来推导上述索引。
- 数据刷新后按上层提供的 NodeId 恢复光标：仍可见时保留该节点，不把旧行号上的新节点当作原节点。
- 原节点不可见时定位最近的可见祖先，否则定位附近可见行；空视图无光标节点。原节点重新出现时
  不自动跳回；这些定位不改变选区，也不触发上层打开 callback。

### 单子目录链压缩

- 默认启用；已展开目录的唯一可展示子项也是目录时，可将这段路径压缩为一行。
- 按当前 Explorer 能力，parent 在 selected-only 过滤前的 source children 也须只有一项。
- 文件保留独立行；需要独立展示选择边界的目录不得被合并隐藏。
- 压缩行保留完整 source node chain，以最深层目录为默认代表；链上各 ID 都能定位到该行。
- 压缩 chain 只增加一层显示深度；可见父行位于 chain 外，source parent 仍保留用于折叠等结构动作。
- 压缩不修改真实 parent/child 关系、资源定位信息或选择语义。

### 已确认：递归 List

现有 UI 有 Tree/List 开关，但现有 renderer 未实现 List 分支。新实现明确采用递归 List：

- 总是递归 display root 下的资源，以相对 display root 的路径逐行平铺，经过显示过滤后展示。
- 不受 Tree 展开状态限制，也不局限于已加载内容；目录和文件均有独立行，不压缩目录链。
- 切回 Tree 时恢复原展开状态；selection 与 mode 不变，List 读取可扩充共享 data。
- Treeview 负责平铺结构；Filetree 提供显示名称，按 frame 固定的 root 派生相对路径文本，
  共享 data 不改写 source label。具体接入见 [List 文本契约](../../../spec/design/filetree.md#多-state-的-list-文本)。

加载协议：Rust 有界并发读取，分批更新列表并展示 loading/error；失败分支不得被当作空目录。
Symlink 浏览仍保留逻辑路径，但递归不能在祖先链上反复进入同一目标；遇到循环保留该项并报告原因。
切换 root 或离开 List 解除对应 view 的递归请求，使用 generation 丢弃旧结果，不影响共享读取与文件任务。
排序按各层目录优先、名称升序进行 DFS；递归扫描不意味着为所有目录分配 watcher。

### 状态装饰与跳转

- Rust 接收本地资源的 Git 状态、ignored 状态和 Neovim diagnostics 数据，维护目录聚合。
- 目录是否选中与目录是否包含已选后代是不同状态；后者只用于聚合展示。
- 支持在当前可见序列中查找前/后一个 diagnostic、error、warning 文件和 Git changed item。
- Git changed item 包括含变更后代的目录；diagnostic 导航只定位文件；搜索到边界后循环。
- 图标、具体 glyph、主题颜色和 Neovim highlight/extmark 由 Lua 对接，不成为资源身份或排序条件。
- 虚拟资源缺少 Git/LSP 能力时保持基础树功能，不为装饰而生成本地临时文件。

### 刷新与监听

- 手动刷新在 Tree 重读展开范围，在 List 重新递归校验 display root；自动变化通知使 data 和投影失效。
- Tree 监听按当前展开目录集合增减；List 的监听同样受预算约束，不为全量递归结果无限创建 watcher。
  现有默认预算为 50 个目录，事件合并间隔为 150 ms。
- 监听失败或到达预算时向 UI 提供诊断；手动刷新仍可使用。
- 无可见 view 时可暂停视图专用监听，但要标记数据需要重读；文件任务继续。
- 监听事件过滤不等于隐藏文件过滤，不可据此改变 selected items 或文件操作范围。
- 具体 watcher 实现和批次更新协议在 Rust 设计中确定；实现必须防止失效的异步结果覆盖新状态。

## Treeview 选取对 Filetree 的要求

Selection 的唯一 owner 是 Treeview，select/copy/cut mode 由 Explorer 持有。
`subtree_roots` 与 `self_only_nodes` 的定义和判空遵循
[Rust Treeview selection](../treeview/selection.md)，两组从同一份标记派生。
本节完整列出资源层必须支持的行为，Filetree 不维护第二份 selected flag：

- 一个选区只有一种用途：普通 select、copy 或 cut；copy/cut 均隐含选择能力。
- 选中目录的动作覆盖整棵子树，包括未展开、未加载或隐藏的后代；后续区分自身 marked 与子树 full。
- 状态不必向整棵子树逐节点写入，但必须与逐节点选择的逻辑语义等价。
- 选中祖先目录后可用该目录表示整棵已选子树，文件操作不重复提交其后代。
- Visual 范围先保留其中最外层节点；范围含父节点时，其后代不再单独 add/toggle，父节点代表整棵子树。
- 反选被祖先覆盖的后代时，只取消目标子树；祖先自身与旁支保留原选择，祖先 full 重新派生，mode 不变。
- 标记写入只处理目标根，祖先路径只失效派生缓存；真正枚举源项时再读取必要的直接子项。
- 需要枚举的直接子项必须包含隐藏或过滤的节点；display projection 不能作为完整源项的结构输入。
- 原已选祖先不再 full 时，自身进入 `self_only_nodes`；递归文件操作只消费 `subtree_roots`。
- Container 仅自身选中时保留在 `self_only_nodes`，由 Explorer 决定其业务用途，不能隐式递归操作它。
- 两组均确定为空才退出 multiselection；递归源项为空不等于 selection 为空。
  取消最后一个子项后仍有祖先自身选择时保留 mode；操作执行、等待确认和正在取消时禁止修改选区。

例如，`src/` 有 `main.lua`、`lib/keep.lua`、`lib/skip.lua` 和 `assets/`。选中 `src/` 后反选
`lib/skip.lua`，操作源变为 `main.lua`、`lib/keep.lua`、`assets/`；`src/` 与 `lib/` 自身仍选中，
进入 `self_only_nodes`，不作为递归操作源。重新选中 `skip.lua` 后，`src/` 自然恢复 full，源项归并为 `src/`。
无需遍历 `assets/` 的后代就能保留其整棵子树的选择。

选取采用 [Treeview 的 subtree/self 版本标记](../treeview/selection.md#标记与交互)；本文 Explorer 交互显式传
recursive=true，反选只写目标根，不额外取消祖先自身或旁支。Full 另按后代状态聚合，
最外层源项是按有效状态枚举的结果，不要求即时物化。

单点反选的核心 stamp 写入为 `O(1)`；沿祖先链的缓存失效另计，携带继承版本的遍历为 `O(N)`，
不包含目录 IO、精确聚合与 UI 发布。源项准备需要尚未知子项时，由 Filetree 加载并校验 revision；
失败不提交错误源项或半份选区。新 NodeId 的 selection subtree/self stamp 从 0 开始自然继承，
expansion 的 subtree/self stamp 同样从 0 开始；既有 NodeId 补载保留标记，Remove 才清理状态。
Treeview 使用子树最大 stamp 和 `{full, known_roots, known_self_only, pending}` summary；
selection 判空与计数考虑两组，递归源项单独按 roots 判断。Full 子树直接作为一个源项，
非 full 节点仍可保留自身选择；pending 分支通过 Filetree 补充必要的完整直接 children。
Reparent 后不能仅凭父节点的旧奇数标记跳过带有较新取消标记的子项；这一判断属于正常查询/聚合。

Filetree 提交带 base revision 的有序节点批次，私有候选状态验证成功后与所有关联 Treeview state 一起发布。
Children 请求使用节点 request epoch 和 page sequence；无关更新不丢弃有效读取，旧 epoch 不覆盖新事实。
部分结果保留已知节点，完整结果才能确认缺失项的移除；带状态节点的结构 skeleton 不能因缓存淘汰丢失。

提交时同步维护相关任务的 cleanup context：影响源项范围或祖先关系的外部更新使其失效，
metadata/纯重排与无关范围更新不失效。本任务的预期节点更新需由 owner 校验归属、身份和影响范围后
才能推进仍有效的 context；来源不明时保守处理，晚到结果不能覆盖已发生的外部失效。
这一规则只约束选区清理，不阻止真实节点事实发布；详见
[业务结果清理](../treeview/selection.md#业务结果清理)。

## 组合与共享

多个 Explorer 可以连接同一份 Rust data/state，也可以各自拥有独立实例，由调用方组合决定。
共享 Filetree data 不自动意味着共享 Treeview selection；共享 selection 时必须连同 Explorer mode 和
任务锁一起共享，避免同一选区在不同 pane 被解释为不同操作。

设计必须明确各状态的 owner，并保证共享实例只有一份权威状态。Lua 不维护第二份可独立修改的
树、选区或操作状态。Neovim window、buffer 等实际对象由 Lua 对接。

首期支持共享 data 各自 state、共享 data 和完整交互 state、data/state 全部独立三种组合。
不提供任意字段的共享配置。实际 Neovim window、viewport 和 Visual marks
归各自 Lua surface；Rust 逻辑 cursor 的共享不代表同时聚焦多个窗口。
Visual 两个端点与保留 frame 属于该 view，其他共享 view 的 cursor/root 更新不会打断正在进行的圈选。
独立 views 使用独立的正文 buffers，Rust data/state 与 snapshot 的共享不影响各自的帧交换时机。

文件任务由 Explorer 持有，生命周期独立于 pane；Filetree/provider 负责资源操作与变更结果，
Treeview 接收选择更新和锁定状态。完整约束如下：

- 关闭视图不会结束任务；任务及其状态由 Rust 持有，新 view 连接同一 state 后可读取进度。
- 开始执行时固定源项和目标；等待用户决定是否覆盖时，任务保持待确认状态，选区保持锁定。
- 用户拒绝覆盖时本项 skipped，继续处理后续项；context 有效时成功项从选区移除，failed/skipped 保留。
- 业务清理通过任务身份、成功源项及 context 校验后，与交互反选一样只取消目标子树；祖先自身与旁支保留原选择。
- 相关 topology 冲突时，终止任务记录 cleanup Stale，保留逐项 IO 结果，不额外改选；发布结果后释放本任务锁，
  提示重新整理选择，不自动重试清理或已完成的 IO。已发布的 Remove/reparent 不回滚。
- 批量打开不消费选区，成功、部分失败及取消 window picker 均保留 selection 和 mode。
- 清空选取与取消任务通过两个独立 action menu 入口提供，暂不设默认键；执行中不能清空选取。
- 取消请求在当前项结束或可中止点生效；Rust 确认停止前维持“正在取消”和选区锁定。
- 已完成部分不回滚；取消后未完成项保留原 mode。
  任务终止后按清理后的两组重新判空，只有 selection 确定为空才退出 multiselection。
- 退出 Neovim 时如有未完成任务，提供等待/退出确认，默认等待。
- 等待会取消本次退出请求，任务继续，完成后不自动退出；选择退出则取消未完成任务，等待
  Rust 确认安全停止后继续正常退出。停止超时和强制退出仍需设计。
- Rust 不保存可在 worker 中调用的 Neovim window/buffer 对象；UI 确认与显示通过 Lua 适配。

## 已确认：目录内部结果与选择清理

- 成功的部分取消选择，失败、跳过或取消时尚未完成的部分保留选择；目录内部采用同一规则。
  不因一个目录内有失败项而保留其中已经成功部分的选择。
- 整个目录操作成功时可以用该目录作为成功根清理；目录部分成功时，只清理成功的文件或完整成功的子树。
  不取消它们的严格祖先自身或旁支，也不额外修补父目录的选择标记。
- Provider 保留目录内部的逐项 success/failed/skipped 结果及原因；目录汇总结果不能抹掉已经成功的子项。
  单个文件只写入了一部分不算成功，不据此清理该文件的选择。
- 清理继续遵守原任务身份、选区锁及 cleanup context 校验：context 有效时统一清理成功部分；
  Stale 时保留当前存活选区和真实 IO 结果，不自动重试 IO 或清理。已 Remove 的节点不复活。

例如整棵 `src/` 被选中，copy `src/a.txt` 成功、`src/b.txt` 失败或被用户跳过；
正常清理后 `a.txt` 取消选择，`b.txt` 保留选择，`src/` 自身仍按 Treeview 既有规则保留选择。

成功子项回传必须保持原任务内的资源/节点身份，不能按当前同名路径重新绑定。
原任务根及子项准入遵循 [任务接入契约](../../../spec/design/filetree.md#受任务校验的子项清理)，
不通过解锁后调用普通 deselect 绕过该校验。

## 已确认：Copy 的目录合并与冲突

- Copy 遇到同名的普通目录时递归合并，保留目标目录中源端没有的文件；目录合并本身不询问覆盖。
- 同名普通文件发生冲突时，逐项展示源路径和目标路径，询问是否覆盖；确认后才覆盖当前文件。
- 拒绝时只跳过当前冲突项的 copy，记录 skipped，继续处理同一目录和批次内的其他文件。
  拒绝单项不取消整个目录或整个任务。
- 没有冲突的文件正常复制；目录内部结果与选区清理遵循上节规则。

## 已确认：Move 的目录冲突

- Move 以源目录整体为操作对象；同一 filesystem 内可直接通过 rename 完成，不逐项合并目录内容。
- Move 的实际目标路径已存在同名普通目录，且目标目录非空时，不合并目录；当前源项报告失败，
  保留源目录和目标目录，继续处理批次中的其他源项。
- 同名普通目标目录为空时，按既有覆盖规则逐项询问；确认后以源目录替换该空目录，完成整体移动。
  拒绝时仅跳过当前源项，继续其他源项；不提供另一种逐文件移入空目录的操作模式。

## 已确认：文件与目录的类型冲突

- Copy/move 的实际目标路径发生普通文件与普通目录的类型冲突时，当前冲突项报告失败，
  保留源项和目标项，继续处理其他项；两个方向采用相同规则。
- 不提供跨类型覆盖，该冲突不进入覆盖确认流程。涉及 symlink 时按下节规则处理。

## 已确认：Symlink 操作与覆盖

- 最终目录项的类型按不跟随 symlink 的 metadata 判定；链接与普通文件、普通目录分别识别。
- Copy 的源项为 symlink 时复制链接本身，包括递归复制目录时遇到的链接；保留原链接文本，
  相对路径不自动改写，因此改变位置后可能解析到不同资源或成为悬空链接。
  Move/delete 也操作链接本身，链接指向的资源不随之移动或删除。
- 普通文件 copy/move 的最终目标项为 symlink 时，逐项询问是否覆盖；确认后替换链接本身，
  使该目标项成为源普通文件的复制或移动结果，链接原先指向的资源保持不变。
- 源项为 symlink、目标项为普通文件或另一个 symlink 时，逐项确认后用源链接替换目标项。
  目标项为 symlink 时，其指向的资源保持不变；拒绝覆盖只跳过当前冲突项，继续其他项。
- 普通目录与 symlink 之间的冲突在两个方向均报告类型冲突，保留两边并继续其他项；
  即使链接指向目录，也不作为普通目录参与合并或空目录覆盖。
- 上述规则针对被操作的源项和最终目标项。用户可以浏览目录 symlink 并将它选作目标文件夹；
  此时在该文件夹中定位实际目标项，不把目标文件夹本身当作待覆盖的链接。

源链接的 copy 采用 GNU `cp -P` 一类保留链接的语义；覆盖目标链接采用替换链接本身的语义，
类似 `cp --remove-destination` 对目标链接的处理。这不等同于 GNU `cp` 默认沿目标链接写入已有普通文件。
这些是 provider 的行为契约，不要求通过 shell 命令实现，也不引入可切换的 symlink 操作模式。

## 已确认：覆盖确认的适用范围

- 覆盖确认针对向用户展示的当前源项与目标项，不因路径相同而自动适用于后来换入的资源。
- 执行前重新校验可观察的源项、目标项身份与类型；Move 覆盖空目录时还要检查目标仍为空。
  检测到相关前提改变时，本项报告冲突失败，继续其他项，不沿用旧确认或自动重试该次覆盖。
- 拒绝单项为 skipped，发生冲突或 IO 错误为 failed；不因此取消整个批次。
  目录内部结果与选择清理遵循本文件已确认的对应规则。
- 上述校验不构成跨外部进程的 filesystem 事务；具体 IO 的原子边界由平台操作决定。
  Provider 不得因目标发生竞态变化而退回沿最终 symlink 写入的语义。

## 技术契约入口

[Filetree 技术契约](../../../spec/design/filetree.md) 统一定义模块与句柄、identity、原始路径与显示、
目录读取/watch、共享 List 文本、Git/diagnostics、文件执行器与子项清理准入，以及容量、成本与性能验收。
Runtime 是否实现以及实测是否达标，必须通过对应验证判断，不从 Design 状态推断。

## 验证方向

- Rust unit tests 位于对应 crate 内；Filetree 覆盖资源结构、加载/刷新与 provider 的实际文件操作，
  Treeview 覆盖通用状态转换、选区与布局，Explorer 覆盖 mode 和任务结果协调。
- Lua 测试覆盖窗口选择、buffer 定位/加载、按键分派、确认 UI 和状态展示。
- 树布局验证深树、宽目录、folded chain 身份、row/node 映射与过滤后的导航边界。
- 选择验证惰性继承与逐节点语义等价、子树反选保留祖先自身、隐藏/未加载旁支，以及两组选取的枚举。
- 验证子项重选后 full 自然恢复、self-only 仍使 selection 非空，以及成功项清理与交互反选的相同子树范围。
- 验证目录内部部分成功时只取消成功部分，失败/skipped 与祖先自身保留选择；context Stale 时不执行部分清理。
- 多视图验证共享 state 一致性、独立 state 隔离、关闭 view 后任务存活和取消确认。
- 验证源 symlink 的直接/递归复制、相对链接文本保留、最终目标链接替换、目录与链接冲突，
  以及通过目录 symlink 选定目标文件夹；链接资源操作不得误改其指向的资源。
- 验证等待覆盖确认时源/目标被替换、目标类型改变或空目录变为非空的已观测变化：旧确认不能继续使用。
- 首期不迁移 Picker、Searcher、Diffview 等 consumer；后续迁移另行确定各自的业务契约。
