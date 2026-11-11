# Filetree 文件 Job

Status: Design。本文定义 Filetree 文件 Job 的生命周期、进度与结果、私有遍历、冲突、执行器、staging 与成功子项清理；
资源、identity、目录读取、watch 与容量见 [Filetree](README.md)，任务锁与 cleanup context 见 [Treeview 任务](../treeview/tasks.md)。

## Job 生命周期

Operation plan 包含操作种类、原 source/资源身份、源项句柄，以及适用的目标目录、名称和 Treeview 任务资格。
直接单项动作和已有 selection 的批量动作均使用明确源项；是否在无选区时使用光标项由 Explorer 决定。
Job 保留源引用、结果及 cleanup 状态，terminal 只发布一次；取消、重复确认与迟到消息不能重新执行已完成 IO。
运行中的 worker 和调用方持有 Job；终态后调用方仍可读取结果，最后一个强引用释放时回收其源引用与结果。
Job 的确认、已发布结果、取消状态和终态在提交状态、释放锁后，通过所属 data 的合并通知唤醒 Lua；
这些变化不要求 source/frame 更新。字节与处理项进度通知共用 40 ms 限频；两者各自的首次非零变化、
阶段转换与终态不等待下一次进度周期。阶段通知不消耗字节/处理项进度的限频窗口。
通知仅弱引用 native data，不保活 Lua facade；Lua 按通知读取最新状态，Filetree 统一观察并向调用方交付。
运行中的 Job 保留通知连接，不因等待 IO 持续启动快速轮询；通知失败时沿用轮询回退。订阅初次读取也观察已完成的 Job。

## Job 进度与结果

`job:status(previous_revision?)` 返回观察 revision；与上次通知 revision 相同则返回 nil，不重复导出状态。
不传 revision 时始终读取当前状态。Revision 描述已通知的变化，字节与处理项进度可以在下一次限频通知前继续增长。

`results` 使用 1-based inclusive 范围，每次最多 512 条。目录内部结果先保留于 Job，完整成功时归并为目录根；
一个外层源项结束后才将该组结果加入可查询前缀，取消/终止时发布尚未归并的明细，已经公开的索引不移动。

`processed` 单调累计已形成处理结果的文件、链接和目录，包含 failed/skipped；create 仅计新建 components。
它不随子树归并、staging 发布失败或取消而回退，也不代表 success 或可查询结果数量。
整体 rename/trash 等未枚举后代的操作计为一个条目，不为百分比预扫描。
`bytes` 是已传输字节；空文件依靠 `processed` 提供进度。

`phase` 为 preparing、reading、working、publishing、cleanup 或 complete：reading 覆盖目录枚举等待，
working 包含逐项 IO/模型同步，publishing 标识私有目录的整棵发布，cleanup 覆盖任务选择清理与解锁。
终态总为 complete，成功、失败和取消由其余终态字段区分；确认与 cancelling 独立于阶段。

每个操作条目有 Job 内唯一且不复用的 ItemId，与 inode 和浏览 NodeId 分离。
确认与结果的 Lua 字段为不透明的 `item`；`node` 为 optional，只表示执行时已捕获或准入的浏览 occurrence。
私有后代无需 NodeId 即可执行 copy、确认冲突与保留结果，cleanup 后的准入不回填历史 `node`。

普通成功项以 ItemId、optional NodeId、原始 basename 和共享的源/目标父路径保留；每页引用已有不可变结果，
Lua 逐项序列化时才临时组成完整路径，不在 native Job 中保存一整页展开副本。
共享路径固定为执行时捕获的值，不从最新 Source 重建，后续 rename/delete 不改变历史结果。
失败、跳过、同步错误、不同目标名称及 physical paths 保留完整记录；成功子树归并不能吞掉同步错误。
任务内存预留随记录和共享路径的所有权释放，取消与部分归并也使用相同计费；向量保留容量仍计入预留。
合法范围的结果读取不要求再取得 native retained 预算，避免 IO 终态后因内存压力中断结果交付。
调用方持有的结果继续共享原有计费；结果自身不持有 Source，最后一个引用释放时回收记录与共享路径。

## 错误与编辑器交接

IO error 与 `NotFound` 的结构见 [Filetree 错误](README.md#错误)。
目录成员读不出元数据（如目录缺少搜索权限）时只记该成员失败，同目录的其他成员与批次中的其他源照常处理；
该目录因此无法完成，delete 不删除它，copy/move 的目录结果为 failed。目录本身或已加载 occurrence 的变化仍按 Stale 中止。

Move 成功记录可附带 `source_physical` / `target_physical`，在确认后、执行槽内、最终身份验证后捕获。
只解析父目录，不跟随末尾 symlink，供编辑器同步已经 canonicalize 的 buffer 名称。
结果与确认始终提供可显示的 `source_label` / `target_label`；Windows 无法无损表示的 filepath 返回 nil，
不因一个路径转换失败而丢失整个 Job 的进度、确认或结果。

文件任务可以使用现有的 Treeview task/Ready 句柄，source roots 通过原生 NodeIds 传递；
不得先将全部 NodeIds/metadata 展开成 Lua tables 再交回 Rust。Lua facade 复用 `stl.c.Future` 与 Treeview surface。

## Job 私有遍历

- 选中根仍由原 task/Source 固定。Job 以自己的有界 Cursor 枚举 filesystem，按发现顺序执行 DFS，
  不等待根或后代在浏览 Source 中达到 Complete，也不以浏览排序决定目录内部的确认顺序。
  同次发现顺序和已公开结果索引固定；不承诺不同执行之间的枚举顺序相同。
- Item 固定 prepared root、执行时路径、Entry/Signature 与必要父链，可带已捕获的 Resource。
  Cursor 每层持有一个 ReadDir、最多四个预读条目和已加载成员的 bitset；预算失败保留原观测，
  不执行未成功准入的目录项，也不能跳过该项后继续。
  已加载成员必须保持原名称、身份和 occurrence；Complete 目录出现新成员、已知成员消失或重复、
  目录身份变化等使任务 Stale。Symlink 仍操作链接本身，不作为递归源跟随。
- staging、已有目录合并、递归 delete 和跨 filesystem move 共用该 Cursor。
  整体 rename/trash 仍按一项执行，不为进度、结果或 cleanup 预扫描所有后代。
  Destructive IO 的未知条目在执行前最小准入，随后与已知条目一样经过 Authorize、Moving 与 Publish。
- Copy 的私有源后代仅在 partial cleanup 需要时准入成功 frontier 及必要祖先。
  完整成功目录按根清理；不能只为生成结果物化后代。已加载目标按实际 delta 同步，
  未加载目标仅同步必要根、目录锚点及已有 occurrence，其余由实际浏览需求加载。
  未物化的成员变化仍使其他相关任务 context 失效，不能因 Source 未新增节点而漏掉冲突。
- Native 准入使用 [Treeview Job discovery](../treeview/tasks.md#job-discovery)。
  Filetree worker 在每次 admission 边界复验捕获的 filesystem 父链，包括已经绑定 NodeId 的祖先；
  bindings 仅缓存 Source 准入，不证明路径仍指向原 inode。Owner 继续校验精确 task/context、
  prepared root、原始名称与资源 signature，并与 Filetree index 一起发布候选事务。
- 私有枚举与实际 IO 前都读取同版 Source/task 资格；预读条目、确认等待和执行槽等待不能免除复验。
  原本没有 NodeId 的父链从 prepared root 逐层对齐当前 Source；closed 祖先下缺失的下一层成员即为 Stale，
  不能跳过尚未物化的中间目录。匹配节点可用于校验，但不回填 Item/result 的历史 NodeId。
  Lookup 使用该 Source 内的有序 children，不与另一次读取的 live Filetree index 混用。
  明确的源目录 identity/type 变化、目录消失和已捕获成员缺失使 task Stale；权限等普通 IO failure
  继续保留 partial 成功语义。资格 snapshot 仅在检查期间持有，不进入历史结果。

## Copy 的目录合并与冲突

- Copy 遇到同名的普通目录时递归合并，保留目标目录中源端没有的文件；目录合并本身不询问覆盖。
- 同名普通文件发生冲突时，逐项展示源路径和目标路径，询问是否覆盖；确认后才覆盖当前文件。
- 拒绝时只跳过当前冲突项的 copy，记录 skipped，继续处理同一目录和批次内的其他文件。
  拒绝单项不取消整个目录或整个任务。
- 没有冲突的文件正常复制；目录内部结果与选区清理遵循[成功子项规则](#受任务校验的子项清理)。

## Move 的目录冲突

- Move 以源目录整体为操作对象；同一 filesystem 内可直接通过 rename 完成，不逐项合并目录内容。
- Move 的实际目标路径已存在同名普通目录，且目标目录非空时，不合并目录；当前源项报告失败，
  保留源目录和目标目录，继续处理批次中的其他源项。
- 同名普通目标目录为空时，按既有覆盖规则逐项询问；确认后以源目录替换该空目录，完成整体移动。
  拒绝时仅跳过当前源项，继续其他源项；不提供另一种逐文件移入空目录的操作模式。

## 文件与目录的类型冲突

- Copy/move 的实际目标路径发生普通文件与普通目录的类型冲突时，当前冲突项报告失败，
  保留源项和目标项，继续处理其他项；两个方向采用相同规则。
- 不提供跨类型覆盖，该冲突不进入覆盖确认流程。涉及 symlink 时按下节规则处理。

## Symlink 操作与覆盖

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

## 覆盖确认的适用范围

- 覆盖确认针对向用户展示的当前源项与目标项，不因路径相同而自动适用于后来换入的资源。
- 执行前重新校验可观察的源项、目标项身份与类型；Move 覆盖空目录时还要检查目标仍为空。
  检测到相关前提改变时，本项报告冲突失败，继续其他项，不沿用旧确认或自动重试该次覆盖。
- 拒绝单项为 skipped，发生冲突或 IO 错误为 failed；不因此取消整个批次。
  目录内部结果与选择清理遵循[成功子项规则](#受任务校验的子项清理)。
- 上述校验不构成跨外部进程的 filesystem 事务；具体 IO 的原子边界由平台操作决定。
  Provider 不得因目标发生竞态变化而退回沿最终 symlink 写入的语义。

## 执行器

### 串行执行

- 全进程使用一个文件修改执行槽，多个独立 data/state 共用；读取使用独立的有界 worker pool。
  这保证本进程不并发修改同一资源，避免把选区锁当成 filesystem 锁。
- 每个文件/整体 rename 是一个执行单元。目录遍历在项之间让出执行槽；等待用户确认的任务挂起，
  其他任务可以继续。恢复时重新校验源、目标和必要父目录的身份，沿用已确认的覆盖规则。
- 任务持有自己的状态与 source references，关闭 pane 不结束任务；确认/进度通过可轮询的不可变结果提供给 Lua。
  Job 接管已准备的任务时，deadline 已到期则以 Stale 拒绝接管；接管后清除 deadline，执行完成或取消确认后
  先提交选区清理、再释放本任务锁，两者是独立的 owner 提交。接管失败也释放精确凭据对应、尚未被其他 Job 接管的锁；
  检查与释放在 owner 内原子执行。
  任务最多有一个待确认项，确认 token 一次消费。旧确认不能用于后来换入的资源。
- 源目录不能复制/移动进它自身或其后代，检查考虑实际解析的目录 identity 与 symlink 别名。
  源和目标为同一目录项时不执行破坏性覆盖，报告对应项未执行。

### 单项发布与目录合并

- 单文件 copy 与已有目标目录内的逐项 copy 使用私有临时文件，完成并校验后发布；失败时清理本任务临时输出。
  Unix 临时输出通过目标目录 fd 创建、发布及清理，目标目录改名不导致临时文件遗留。
  源文件只在 Job 的串行执行槽内按需打开，只持有正在复制的源/目标 fd，退出该项时释放。
  每项固定原路径与 Signature，打开前校验路径，打开后校验 fd 的类型与身份；复制完成再次复验路径。
  Job 复用的 copy buffer 与目标父目录缓存不能免除这些复验，也不能借缓存重绑已替换的目录。
  必需的 fd 或预算不足时报告本次失败，不重放已完成的创建、复制、发布、trash 或 progress。
  macOS 普通文件 copy 完成后通过输出 fd 读取 metadata 与实际名称，再验证目标 pathname 仍指向该 identity；
  读取失败按已完成 IO 的同步错误报告，不把文件复制成功改写为 IO 失败。Symlink 保持目录项观测。
- 同一目标目录内、无覆盖的小文件可合并 source publication，暂存沿用既有 Job 与 data 预算。
  每项仍独立复验和原子发布；一项 Stale 不阻止其他成功项，发布失败记入该项 `sync_error`，
  已完成的 IO 仍报告 success。目录、链接、大文件、覆盖确认、目标目录切换、顶层结果通知、
  目录收尾和终态 cleanup 前均提交已完成项；取消或异常退出也先发布成功前缀，再清理选择与解锁。
- 新建目录先以私有权限填充，收尾时采用源目录权限；合并已有目录保持目标目录权限。
  目录合并没有全目录事务，已发布的成功项不回滚。跨 filesystem move 完成复制后才移除对应源项，
  只有复制和源项移除均成功才将该移动项报告为 success；不能把半个 move 清理为成功。

### 目录 staging

- macOS/Linux 上，普通目录 copy 的最终目标尚不存在时，先在目标父目录创建私有 staging root，
  后代直接写入其中，不为每个文件另建临时名或执行 rename。已有目录合并逐项执行；
  合并期间遇到全新子目录时，该子树同样使用 staging。其他平台使用逐项发布。
  私有目录以私有权限填充，并登记本任务创建项的 identity；
  完成、取消或部分失败后统一复验所有已登记项的身份、目录成员、源根与必要父目录，
  再应用目录权限并通过一次 no-replace rename 发布完整文件前缀。失败或取消的目录可包含已完成子项，
  不完整文件不发布；已完成文件与完整成功子树在发布后才成为可交付 success。
  目标竞争、源根或父目录失效等使 rename 前提不再成立时，本次 staging 整体失败：
  丢弃未发布的临时成功结果，仅按已知 identity 清理自身输出，保留原选区。
  外部替换项与未知成员不删除；清理失败报告 staging 路径，并使残留目录重新可见。
  rename 后的资源观察或模型更新失败仍报告真实 IO 结果及 `sync_error`，不回滚已发布目录。
  这不是跨进程内容快照，也不扩展目录合并或整个 Job 的原子边界。
- staging 的登记、目录遍历和临时结果计入单任务暂存上限（见[容量](README.md#容量与成本边界)）及 data retained 总预算，
  在下一项 IO 前准入，容量不足以 `ResourceLimit` 停止新项；已完成前缀仍尝试按上述规则发布。
  目标侧发布目录根，后代保持 Unknown，
  由实际展开、List、reveal 或共享 view 的浏览需求加载，不因 copy 自动构造整棵目标 Source。
  资源发现、refresh、watch 引发的扫描与路径 resolve 均屏蔽本进程仍持有的私有 staging 目录，
  不能经 symlink alias 进入其子树；屏蔽按 identity 判定，不屏蔽用户创建的同类名称。

### 取消与停止

- Cancellation 在项边界及大文件块间检查；停止发起新项，处理自身临时输出后报告终态。
  不能把发出取消请求当作已经停止，也不承诺立即中断所有平台的阻塞 syscall。
  Unix 普通源文件使用 nonblocking、nofollow open 并核对打开后的类型与 identity；
  源被替换成 FIFO 时不能在 open 等待 writer。macOS 名称探测同样采用 nonblocking open。

## 新建、回收站与移动准备

- 新建只接受非空相对路径，不能以 `.` / `..` 作为 component；最多 256 components、32 KiB 路径。
  已存在的中间目录可复用，最终目标禁止覆盖。Unix 新文件以 `0666`、新目录以 `0755` 创建，均受 umask
  约束；copy/move 自动补齐的父目录沿用此规则，transfer staging 仍使用私有权限。
  临时输出返回已知 FileIdentity，发布/resolve 后再次核对
  identity/kind；父目录被替换时停止，不能继续写入替代目录。
  新建后的 resolve 若因并发发布返回 Stale，最多重新观察并提交两次；每次重试前复核原父目录身份，
  接受结果仍须匹配已创建项的 identity/kind。只重试资源观察，不重复创建 IO，也不重试任务选区清理。
- 新建与 copy/move/delete 共用全进程执行槽、Job 准入和单 Job 结果预算（见[容量](README.md#容量与成本边界)）。
  每次 IO 前预留结果空间；取消或后续失败保留已创建结果，不承诺整个路径事务回滚。
- `kind = "trash"` 使用平台已有的 trash 工具，作为整项任务执行：macOS `trash`、Linux `gio trash`、
  Windows/WSL 的回收站 API（通过 PowerShell 调用，WSL 先使用 `wslpath`）。不额外安装工具，缺失或失败
  报告该项失败，不降级永久删除。Symlink 按链接项处理；成功移出后发布 Remove 并按原 context 清理选区。
  Worker 保留执行槽直到工具退出；取消停止后续项，等待已经启动的工具结束，不将强杀外部工具当作安全停止。
- Move 的 `prepare_move` 由编辑器集成显式启用。每个最外层源项先完成覆盖确认，再发出
  `confirmation.kind = "prepare_move"`，其中路径为不跟随末尾 symlink 的 physical path。
  Lua 完成 `willRenameFiles` 等准备后用同一 token 确认继续；等待期间不占修改执行槽。
  恢复后重验源、目标、父目录和准备时的 physical path；变化时拒绝 IO。跨卷目录的内部子项不重复发起顶层准备。
  普通冲突使用 `kind = "overwrite"`；两种确认 token 均一次消费，取消和迟到回复不能重启已结束任务。

## 受任务校验的子项清理

Treeview 的 cleanup context、成功项清理、授权更新与 Job discovery 见 [Treeview 任务](../treeview/tasks.md)，
选择的清理范围见[成功 frontier 清理](../treeview/tasks.md#成功-frontier-清理)；本节只定义 Filetree 如何产生成功项与资源事实。

- Provider 保留目录内部的逐项 success/failed/skipped 结果及原因；目录汇总结果不能抹掉已经成功的子项。
  单个文件只写入了一部分不算成功，不据此清理该文件的选择。
- 结果按成功的完整子树归并；失败路径和其必要成功兄弟保留明细。登记、结果和待发布子项均计入任务预算，
  在无法保留必要身份/结果前停止后续 IO 并报告容量失败，不能丢弃失败记录后声称整个目录成功。

成功子项回传必须保持原任务内的资源/节点身份，不按当前同名路径重新绑定，也不通过解锁后调用普通 deselect 绕过：

- Filetree 持有资源结果与准入身份的对应关系。成功子项可来自 prepared source 或已登记的发现，
  不能靠最新同名路径替代；元数据补载和结果登记不自动改变 selection。
- 预期 move/delete 使用 [授权更新](../treeview/tasks.md#授权更新)。
  跨 filesystem 目录 move 可将已完成子项移到目标临时 occurrence，整个目录成功后原目录 NodeId 接管目标及这些子项。
  目录链接移动前解析新位置的目标，预先授权必要的旧 children Remove 与精确的 `Slot` 状态；执行后不匹配即同步 Stale。
- 私有成功 frontier 分批准入 Source facts：每批最多 128 项、64 KiB task scratch，先按捕获的路径/签名尺寸预留，
  再读取或复制 Entry，计费持续到 owner 消费完成。批次失败时的处理见 [成功 frontier 清理](../treeview/tasks.md#成功-frontier-清理)。
