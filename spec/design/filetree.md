# Filetree 技术契约

Status: Design。本文确定 Filetree 的 Rust/Lua 边界、资源身份、读取、任务接入及性能验收。
Design 不表示 runtime 已实现或性能已达标。用户已确认的浏览与文件操作行为见
[Filetree 行为说明](../../doc/spec/filetree/module.md)；其中 Explorer 专属 UI 草案不作为 Filetree 的隐式需求。

## 模块与所有权

- 使用现有 `yoz` crate：Rust 位于 `rust/yoz/src/ux/filetree/`，binding 位于其 `lua/` 子模块，
  Lua facade 位于 `lua/ux/filetree/`，入口为 `yoz.ux.filetree` / `require("ux.filetree")`。
- 依赖为 Filetree → Treeview 与现有 Rust fs/git 工具。Treeview 不导入 Filetree、Lua 或 Neovim。
  不新增 crate，不将已实现的 Treeview 移回 `rust/ux`，不为未来 VFS 引入未使用的插件框架。
- 每份 Filetree data 组合一个通用 Treeview DataHandle。它的 owner 持有唯一权威 source topology、
  key/NodeId 映射和不可变节点 payload；Filetree 不保存另一份可独立修改的 parent/children tree。
- Filetree 拥有资源解释、目录观测、路径查找索引、IO 缓存与调度。索引只保存节点身份或不可变数据引用，
  按同一提交版本更新；旧 source/frame 使用旧 payload，不能查最新可变缓存来解释旧节点。
- 原生 worker 将 owned records/delta 交给 owner；Lua 不接收整份 readdir table 再送回 Rust。
  Native 读取与 Lua provider 使用相同的 request epoch、page sequence、取消与完成 reservation。
  同一读取只交给一个 provider driver，不让 Lua 与 native 竞争消费 NeedChildren/CancelChildren。
- Owner 只处理有界提交与派生计算；目录 IO、文件操作、身份查询和格式化放在 Rust worker。
  Worker 不调用 Lua/Neovim；等待 IO 或用户确认时释放 owner 的执行权。
- Treeview state 持有 root、expansion、selection 和逻辑 cursor。Explorer 拥有 mode、任务用途和 UI 确认。
  Filetree 输出操作结果与确认请求，不注册 keymap、不代替 Explorer 决定 mode。

### 句柄与调用边界

| 入口 | 结果与职责 |
| --- | --- |
| `open(path)` | Future 完成为 Filetree data 与初始 display-root NodeId；路径 IO 在 worker 执行 |
| `data:create_state(root?)` | 创建同 data 的独立 Treeview state，省略 root 使用初始入口 |
| `data:source()` | 返回不可变 source，资源查询必须携带这个 source 或相应 frame |
| `data:resolve(path)` | Future 返回资源句柄；只补齐定位所需的祖先，不递归读取整个 workspace |
| `data:refresh(state)` | 按该 state 的 Tree 展开范围或 List 递归范围建立刷新需求，返回请求接受结果 |
| `data:inspect(source, node)` | 按需返回该版本的资源信息；需要新 IO 的详情查询另返回带身份校验的 Future |
| `data:details(resource)` | Worker 校验资源及祖先 identity，返回当前 size、权限、八进制 mode 与 RFC3339 日期 |
| `data:start_operation(plan)` | 接收明确源项、目标及可选的原任务清理资格，返回文件 Job，不自行选择操作源 |
| `data:check_transfer_target(source, target)` | Worker 核对源和已存在目标祖先、拒绝 physical self-descendant，供补父目录前检查 |
| `data:start_create({target, path, directory})` | 在明确目录内新建相对路径，自动补齐父目录，返回同一类文件 Job |
| `job:status()` / `job:results(first, last)` | 读取进度/终态和有界逐项结果，不一次导出全部任务记录 |
| `job:confirm(token, override)` / `job:cancel()` | 提交一次性确认或取消请求，不能被解释为 IO 已结束 |

Operation plan 包含操作种类、原 source/资源身份、源项句柄，以及适用的目标目录、名称和 Treeview 任务资格。
直接单项动作和已有 selection 的批量动作均使用明确源项；是否在无选区时使用光标项由 Explorer 决定。
Job 保留源引用、结果及 cleanup 状态，terminal 只发布一次；取消、重复确认与迟到消息不能重新执行已完成 IO。
`results` 使用 1-based inclusive 范围，每次最多 512 条。目录内部结果先保留于 Job，完整成功时归并为目录根；
一个外层源项结束后才将该组结果加入可查询前缀，取消/终止时发布尚未归并的明细，已经公开的索引不移动。
等待目录收尾时通过 `bytes` 与当前确认请求读取进度。
IO error 保留操作、对应资源、平台错误类别与原始 error code；普通业务失败为完成值，不抛成丢失上下文的 Lua error。

Move 成功记录可附带 `source_physical` / `target_physical`，在确认后、执行槽内、最终身份验证后捕获。
只解析父目录，不跟随末尾 symlink，供编辑器同步已经 canonicalize 的 buffer 名称。
结果与确认始终提供可显示的 `source_label` / `target_label`；Windows 无法无损表示的 filepath 返回 nil，
不因一个路径转换失败而丢失整个 Job 的进度、确认或结果。

文件任务可以使用现有的 Treeview task/Ready 句柄，source roots 通过原生 NodeIds 传递；
不得先将全部 NodeIds/metadata 展开成 Lua tables 再交回 Rust。Lua facade 复用 `stl.c.Future` 与 Treeview surface。

## 资源记录与路径

每个逻辑目录项包含独立的 occurrence key、原始名称、资源类型及可观察的 filesystem identity。
目录项是 symlink 时另外保存链接文本与按需取得的目标信息，不能把目标身份当成链接自身身份。

- 原始名称/路径由 Rust `OsString` / `PathBuf` 表达。子项保存原始 basename，路径由 source 的 parent 链组成；
  仅资源入口需要保存完整基路径。Rename/move 不逐个重写所有后代的完整 filepath。
  路径中的 `..` 按 filesystem 解析，末尾 symlink 保留自己的 occurrence；大小写不敏感的平台按实际 basename 对齐。
- 核心 metadata 包括类型、file identity、长度、时间和权限等原始数值。原生发布使用紧凑、不可变 payload，
  可以放入既有 `Value::Bytes`；编码属于 Filetree 私有实现，Lua 不解析该 blob。
  每份 allocation 只计费一次，旧 frame 的最后一个引用释放后才回收。
- uid/gid 名称、日期、大小、人类可读权限只在详情或实际展示需要时格式化；不在每次 readdir 中逐项查询用户数据库。
  现有 `fs.readdir` 的完整展示记录不是高频扫描协议。
- 路径查询使用 `(parent occurrence, raw basename) → NodeId` 索引，比较原始名字；完整路径定位按 components 查询。
  不以字符串前缀判断祖先，不为每个后代存多份绝对路径或 canonical path。
- 打开 workspace 时只建立 filesystem/volume 入口到初始目录的已知祖先链，未枚举的 children 保持 partial/unknown。
  Workspace 不是 source 的人工 filesystem 边界；向上切换 display root 可复用这些祖先，必要时按需定位。
- Lua 通过资源句柄请求路径或发起操作。Unix 可按需返回原始 path bytes；不能无损转换成 Neovim filepath 的路径
  返回明确的不可用结果，Rust 文件操作仍使用原始资源句柄。显示字符串不能作为文件操作输入反解。
- `details` 读取 symlink 自身的 size/permissions，不把 referent 当作链接。捕获的链接目标、叶项或任一
  已知祖先被替换时返回 Stale；同一 identity 的内容、mtime 或权限更新可以返回最新 metadata。
  不可用的 accessed/created 日期返回 nil，不伪造平台不提供的时间。

### 显示与排序

- 原始名称与 display label 分离。Label 保留正常 UTF-8；换行、回车、tab、其他控制字符和非法 UTF-8 bytes
  使用可区分的转义，反斜杠本身也转义。Unix 非 UTF-8 名称和 Windows 非 Unicode 名称仍保留原生单位。
- Sibling 排序键为可浏览目录优先、原始名称的 ASCII case-fold 顺序，再以原始名称作稳定 tie-break。
  可浏览的目录 symlink 参与目录组，悬空或不可展开链接不因名称猜测目标类型。
  排序使用未转义的名称，不因显示 escape、locale 或用户名格式化改变顺序。
- 文件领域排序写入 source sibling order；Filetree 的 Tree/List 均使用 Treeview 的 source order，
  List 因此按各层目录优先的 DFS 展开，不对全部目录和文件重新做一次全局 branches-first 排序。
- 常见名称每次观测只生成一次排序/显示数据；metadata 不变时复用已有 allocation。

## Identity 对齐

Provider key 是本 data 内分配的 occurrence identity，不直接使用 filepath、inode 或它们的 hash 充当 NodeId。
Treeview owner 分配 NodeId。一个物理资源经 hardlink/symlink 出现在多个位置时，保持多个 occurrence。

- Unix 采用 device/inode；Windows 采用 volume/file ID。
  身份读取不跟随最终 symlink。平台无法提供可用身份时报告读取能力错误，不伪造稳定 file ID。
- Birth/creation time 属于可变 metadata，不参与稳定 identity 的相等或 hash 比较。
  macOS 调整 mtime 时可能同时调整 birth time，这不能单独作为目录项被替换的证据。
- 同一目录中的原始名称与资源 identity 均连续时保留 key。原地写入、mtime/size/权限变化不单独更换 key。
- 已观察到原目录项被替换、类型改变或真正删除时结束旧 identity；同名新项分配新 key/NodeId。
  新节点自然继承祖先标记，不推断外部编辑器的“保存意图”，也不转移旧节点自身的标记。
- 本任务确认成功的 rename/move 明确携带源 occurrence 的映射，保留 key；跨 filesystem move 也按已确认业务映射
  更新物理 identity。文件操作与 NodeId 业务映射按实际完成结果发布；后代浏览缓存允许在后续常规或显式刷新时收敛，
  不要求 Job 返回前全部已加载 alias 的 target/cycle 即时一致，也不为此扩展全量同步事务。
  整体目录 rename 后，worker 只沿已加载子树重新观测链接目标与循环边界，不枚举未知 children。
  对已经执行的后代观测，owner 校验对应 subtree/node 版本并在同一次发布中应用调整；相关数据已变时报告同步 Stale。
  移动执行单元内暂缓相关 native 读取与观测，保留读取 lease；发布或失败后恢复，避免本次 rename 的监听事件提前删除源 occurrence。
  跨 filesystem move 的每个 copy/remove 子项及末尾目录删除也保持协调直到 owner 发布；递归枚举在这些执行单元之间进行。
- 外部 rename 只在同一批可靠观测中存在无歧义的一对旧/新目录项，且资源 identity 对应时保持 key。
  无法确认、存在 hardlink/alias 歧义或旧节点已经 Remove 时按删除/新增处理，不事后复活旧 ID。
  粗粒度 watcher 不提供可靠跨目录关联时，不强行推断跨目录 rename。
- 目录枚举与 metadata 不是 filesystem 快照。不能保证识别两次观测之间发生、又完全消失的变化，
  也不声称仅靠 inode 可以排除所有复用；契约基于实际取得的身份信息和已确认的操作结果。
- 入口被删除时发布 RootUnavailable；同路径新建入口不自动绑定旧任务、旧 NodeId 或旧 view 的 root。

## 目录读取、刷新与监听

### 有界扫描

- 首次 Tree 展开只读直接 children；List 和递归展开的后续需求由 Treeview 提供。
  共享 views/任务对同一目录同一 epoch 合并读取，不为每个 view 发起一份 readdir。
- 同一轮刷新同时覆盖祖先与后代时，先对齐祖先，再按当前路径重读后代；初次 List 加载仍可并发读取已发现的目录。
- 每次扫描固定目录 occurrence、资源 identity、request epoch 和来源。Worker 使用显式遍历栈，
  一个目录取得基路径后复用于其直接 children，不为每条目重走整条祖先链。
- 枚举和基本 metadata 读取按有界块进行；每页最多 512 项且 owned payload 不超过 1 MiB。
  页被 owner 消费后才推进下一页，沿用 Treeview publication 背压，不能把完整目录先导出 Lua。
- 完整刷新需要记录本轮 seen 成员，只有成功终态才能删除旧集合中未出现的成员。
  Seen 集合与在途结果计入预算；无需为未变化成员复制新的 NodeData 或重新发布 metadata。
- 初次加载可逐页插入，source 顺序通过 sibling 索引维护。刷新中的新数据可以发布，旧数据保留到完整终态。
  枚举失败、取消或硬预算失败不得把 partial 集合当成完整集合。
- 条目 metadata 失败不能当作该条目不存在。保留已知有效记录并标记本轮不完整；首次未知条目报告读取错误。
  无法确认缺失的其他旧项也不能在该轮被清除。权限失败可显式重试。
  同一路径、同一 symlink occurrence 的 target 暂时不可确认时，保留最后确认的 target 和 children，
  标记读取错误/不完整；恢复后确认 target 未变时保留 children 的 NodeId 与 selection。
  Move 到新路径不继承旧路径的 target 判断；确定的 target 替换、缺失或非目录仍结束旧 children。
- 目录 IO 返回时无关数据 revision 已推进，可在 owner 内按当前 source 重做该槽位对齐；
  目录 epoch、身份或本轮读取资格已失效时拒绝。不能简单以全局 revision 不同丢掉全部有效读取。
  同一 occurrence 的内部读取重启保留活跃 lease 的身份与需求；换 epoch 不等于调用方释放读取。

### 增量更新

- Watcher 给出的确定路径仅用于缩小 dirty 范围；粗粒度事件使目录失效，不直接解释成权威 Insert/Remove。
- 同一目录重复事件合并为一个 dirty 标记及递增 epoch。扫描中再次失效最多保留一份后续需求，
  不为每个事件排一份扫描，不让过期扫描覆盖新事实。
- 已知单项变化只更新该项、相关 sibling 排序位置和祖先聚合。只有完整目录观测时，允许扫描 W 个直接 children
  做对齐；不能将这个成本描述成 O(1)，也不能顺便扫描整个 workspace。
- 不对每个小批次重新排序全部 W 个 children。持有稳定排序索引，单项修改更新相应路径，批量刷新可合并排序工作。
- 任务、刷新和 watcher 结果都进入同一个 data owner。其提交顺序可以影响结果；保证的是每次提交有效且原子，
  不要求与内部操作顺序无关。

### Watch 与生命周期

- Rust platform backend 使用原生目录通知；首期用现有依赖或平台 API，不额外引入 watcher package。
  注册失败报告错误并保留手动刷新，不静默切换为全树周期扫描。
  Windows 使用 `ReadDirectoryChangesW` 的 overlapped 读取，每个 watch 的 16 KiB buffer 计入预算；
  注册时核对打开目录的 identity，取消后等 pending IO 完成再释放 event、buffer 与 handle。
- Tree 的 watch 需求来自可见 views 的展开目录及其入口；List 也受同一预算约束。
  同一资源可共享 OS watch，逻辑 occurrence 的刷新结果仍分别对齐。
  每个目录链接入口分别请求其自身父目录与 link text 对应目标父目录的监听，后者由 watch 线程解析；
  共享 referent 不省略其他入口的父目录需求，目标父目录监听也计入同一 watch 预算。
- 每份 data 最多 50 个目录 watch，事件合并窗口为 150 ms。优先入口和当前可见展开目录，
  其余按最近需求顺序分配；超出预算的目录标记为需要手动/后续重读，不能声称保持实时完整。
- 无 view 且无任务的目录释放 watch/读取需求，保留的 source 标记需要重读；再次使用时刷新。
  任务不依赖 pane 存活，最后一个 data/state/task/frame 引用消失后回收对应资源。
- Symlink 浏览按每条逻辑祖先链的目标目录 identity 检测循环，允许非祖先方向的别名访问。
  遇到循环保留链接项并报告循环原因，停止该分支递归；不全局去重物理目录从而吞掉其他合法 alias。

## 多 state 的 List 文本

采用 Treeview 的通用“祖先 label 组成正文”能力，不让 Treeview 解析 filesystem 路径：

- Filetree 在 List 中使用 `list_text = "ancestry"`，具体默认值、root 边界、分隔符与匹配 spans 遵循
  [Treeview List 正文](../../doc/spec/treeview/projection.md#list-正文)。Tree 仍显示 basename，压缩链沿用既定规则。
- Text 的 source、root、格式和依赖全部固定在 frame 中。两个 state 共享 data、root 不同时可产生不同正文，
  不改写 source label，不在 Lua 拼路径，也不复制整份 source。
- Rust 使用共享的祖先文本片段及长度索引；相同前缀只保留一份，旧 frame 与新 frame 复用未变片段。
  不为每个节点缓存一份完整路径字符串，避免深树 O(N × depth) 的驻留字符量。
- 字节预算查询利用片段累计长度；实际导出在限定行/字节范围内展开文本，成本包含真实输出字节。
  片段构建、读取和最后引用释放均使用深度安全的迭代流程。
- 叶子 rename 只影响本行及真实排序依赖；目录 rename/reparent 影响其在本 state root 内的后代路径正文。
  改变被排除的 root label 不应使全部后代正文失效。完整改变 root 则允许处理整个受影响展示范围。
- Path 文本依赖变化推进 text revision；正文未变的 metadata/selection 更新保留正文。
  RenderPlan、viewport spans、文本预算和 staging 复用都使用同一份派生文本，不能只修改显示出口。
- 名称过滤仍按 Treeview 已定义的 source label 执行；本能力只改变 List 正文。
  Filetree 不因此新增实时路径过滤产品功能。

## Git 与 diagnostics

- Git 原生结果与 Lua 提交的 diagnostics 是独立的、带来源 revision 的输入；过期批次不覆盖新状态。
  Diagnostics 按 namespace/buffer 替换对应集合，关闭或清空时撤销原贡献，不重复累加计数。
- 未加载文件的状态保留在有界的稀疏路径索引中，不为显示 Git/diagnostic 聚合而递归扫描目录、
  创建全部 filesystem 节点或打开 buffers。目录聚合按受影响的逻辑祖先链增量更新。
- 每个逻辑 occurrence 可展示同一资源的状态；聚合按该逻辑树的后代 occurrence 计数。
  输入事件本身去重，不为跨 alias 的展示去重建立全树资源集合。
- 单个诊断或 Git 状态变化不重建所有行。保持 basename allocation，使用 viewport decoration 查询。
  导航只查当前 frame 的可见结果，沿用 Explorer 已确认的类型筛选和循环规则。

输入接口由调用方连接已有 Git/diagnostic 数据源，Filetree 不再建立一套 Git 轮询或订阅系统：

- `data:set_git(root, revision, snapshot?, ignored?)` 接收 `yoz.git.StatusSnapshot` 与可选的 `yoz.git.IgnoreCache` 当前快照，
  直接保留原生不可变结果，不经 Lua 导出全部路径；同一 root 的较旧或重复 revision 拒绝，两个输入都省略表示撤销。
- `data:set_diagnostics(namespace, bufnr, revision, path?, counts)` 替换该 namespace/buffer 的贡献。
  `counts` 依次为 error/warning/info/hint；全零撤销旧贡献，仍保留最后 revision 防止迟到结果复活。
  Lua facade 提供 `sync_diagnostics(namespace, bufnr)` 从 Neovim 提取当前 buffer 的计数；事件订阅由调用方持有。
- `data:annotations(frame, first, last)` 异步查询 1-based inclusive viewport，最多 512 行；返回独立装饰 revision。
  symlink 路径解析在 worker 中按查询共享前缀，目录聚合不递归枚举未知 filesystem 节点。
  查询按 frame 捕获的 occurrence、链接文本与 target identity 复核 filesystem；链接或已确认目标改变返回 Stale。
  原来没有确认 target 的悬空、循环或不可读链接仍可查询，不使无关行装饰一起失效。
  Lua 遇 Stale 清除旧装饰，等新的 source/layout/input revision 再查询；Busy 保留重试资格。
- 同一 view 的 annotation 缓存依赖 source data revision、layout revision、viewport 范围与 annotation revision，
  不因单纯 cursor/selection publication 重查。source 与 layout 未变时，在新 frame 首次 redraw 前重绑定已有装饰，
  避免 filename highlight 与状态文字先消失再恢复。后台刷新仅改变加载状态时，通过 Source 的内容比较确认
  节点身份、parent 和资源 payload 未变，在新查询完成前继续使用原装饰；只比较行布局不足以判断缓存有效性。
  实际资源内容、布局或 annotation 输入变化仍触发重新查询；路径/identity 改变和 Stale 不复用旧装饰。
  缓存失效、正文变空或 view detach 时释放旧 Source 引用；后台 tab 也在 frame publication 时完成清理。
- Fold/expand 等布局切换在 Surface 准备阶段查询目标 viewport 的 annotations；查询期间继续显示旧 frame，
  就绪后同时发布正文、行映射和装饰，避免整屏先退回默认色。cursor/loading-only 更新可复用仍有效的完整 viewport。
  准备期间目标或 viewport 改变时重查，Busy 延后重试；独立 annotation 输入与已发布 frame 的滚动仍由轮询更新。
  普通查询完成时须仍拥有当前 request key 和 viewport；迟到的旧范围结果不能覆盖新 publication 的缓存或清除其 key。
- `data:next_annotation(frame, row, kind, forward)` 仅在给定 frame 的可见行循环查找；row=0 表示从头/尾开始，
  返回 1-based 行号或 0。kind 为 git/diagnostic/error/warning；diagnostic 类只命中文件，git 可命中目录，ignored 本身不算 changed。
- 装饰输入只改变独立索引和装饰 revision，不推进 source topology、selection 或正文版本；Filetree attach 负责当前 viewport 的显示。

## 文件任务与成功子项

### 执行器

- 首期全进程使用一个文件修改执行器，多个独立 data/state 也共享执行槽；读取使用独立的有界 worker pool。
  这保证本进程不并发修改同一资源，避免把选区锁当成 filesystem 锁。
- 每个文件/整体 rename 是一个执行单元。目录遍历在项之间让出执行槽；等待用户确认的任务挂起，
  其他任务可以继续。恢复时重新校验源、目标和必要父目录的身份，沿用已确认的覆盖规则。
- 任务持有自己的状态与 source references，关闭 pane 不结束任务；确认/进度通过可轮询的不可变结果提供给 Lua。
  Job 接管已准备的任务后，准备阶段的 deadline 不再解锁选区；执行完成或取消确认后才释放本任务锁。
  接管失败也释放精确凭据对应、尚未被其他 Job 接管的锁；检查与释放在 owner 内原子执行。
  任务最多有一个待确认项，确认 token 一次消费。旧确认不能用于后来换入的资源。
- 源目录不能复制/移动进它自身或其后代，检查考虑实际解析的目录 identity 与 symlink 别名。
  源和目标为同一目录项时不执行破坏性覆盖，报告对应项未执行。
- Copy 文件使用目标目录中的私有临时文件，完成并校验后发布；失败时清理本任务临时输出。
  Unix 临时输出通过目标目录 fd 创建、发布及清理，目标目录改名不导致临时文件遗留。
  新建目录先以私有权限填充，收尾时采用源目录权限；合并已有目录保持目标目录权限。
  目录合并没有全目录事务，已发布的成功项不回滚。跨 filesystem move 完成复制后才移除对应源项，
  只有复制和源项移除均成功才将该移动项报告为 success；不能把半个 move 清理为成功。
- Cancellation 在项边界及大文件块间检查；停止发起新 IO，处理自身临时输出后报告终态。
  不能把发出取消请求当作已经停止，也不承诺立即中断所有平台的阻塞 syscall。

### 新建、回收站与移动准备

- 新建只接受非空相对路径，不能以 `.` / `..` 作为 component；最多 256 components、32 KiB 路径。
  已存在的中间目录可复用，最终目标禁止覆盖。Unix 新文件以 `0666`、新目录以 `0755` 创建，均受 umask
  约束；copy/move 自动补齐的父目录沿用此规则，transfer staging 仍使用私有权限。
  临时输出返回已知 FileIdentity，发布/resolve 后再次核对
  identity/kind；父目录被替换时停止，不能继续写入替代目录。
  新建后的 resolve 若因并发发布返回 Stale，最多重新观察并提交两次；每次重试前复核原父目录身份，
  接受结果仍须匹配已创建项的 identity/kind。只重试资源观察，不重复创建 IO，也不重试任务选区清理。
- 新建与 copy/move/delete 共用全进程执行槽、16 Job 准入和单 Job 32 MiB 结果预算。
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

### 受任务校验的子项清理

成功部分取消、失败或跳过部分保留，遵循
[已确认行为](../../doc/spec/filetree/module.md#已确认目录内部结果与选择清理)。
为实现该行为，Treeview 的任务准入增加“已准备源项下的子项”支持：

- Ready 仍固定最外层源项，不提前递归枚举完整选中目录。任务记录 root 集合及原 source，
  已加载的成功子项以原 NodeId 和所属 prepared root 验证；不接受 self-only root 作为递归授权。
- Filetree 在实际目录 IO 中发现未加载子项时，以该任务持有的读取资格登记观测；包含父 occurrence、
  epoch、page sequence、资源身份和原任务 root。通用 owner 校验结构归属后分配 NodeId，登记任务准入。
  不把“相同 task token”本身视为任意 Insert/Reparent 的授权。
- 只填充原 unknown/partial 槽位的可信发现可推进该任务 context。已知项被替换/移除、跨范围移动等外部事实
  仍使 context Stale；其他任务也按自己的相关范围判断失效。晚到观测不恢复已失效 context。
- Filetree 持有资源结果与准入身份的对应关系。成功子项可来自 prepared source 或已登记的发现，
  不能靠最新同名路径替代；元数据补载和结果登记不自动改变 selection。
- 对子项的预期 move/delete，owner 先校验其任务归属与影响范围，再签发一次性更新资格。
  跨 filesystem 目录 move 可将已完成子项移到目标临时 occurrence，整个目录成功后原目录 NodeId 接管目标及这些子项；
  已准入子项可以随原 prepared subtree 整体移动，不能并入另一个 prepared root。
  目录链接移动前解析新位置的目标，预先授权必要的旧 children Remove 与精确的 slot 状态；执行后不匹配即同步 Stale。
  允许更新已准入的子项，不局限于最外层 prepared root；不得破坏其他成功/失败项的清理前提。
- Cleanup 先按原 source/登记关系校验整批成功子项，再按提交时的 source 去掉仍被成功祖先覆盖的重复子项，
  共用一个 generation 清理；已由本任务移出成功祖先的子项仍需单独清理。
  外部相关变化仍使整批清理 Stale，不能先清一部分再失败；本任务已 Remove 的节点直接略过。
- Root 资格使用集合与共享祖先校验，不为 K 个成功子项各扫描全部 S 个 prepared roots。
  任务失效检测也按变更节点的祖先/受保护祖先索引查询，避免每个 metadata/无关节点变化扫描全部任务源项。
- 结果按成功的完整子树归并；失败路径和其必要成功兄弟保留明细。登记、结果和待发布子项均计入任务预算，
  在无法保留必要身份/结果前停止后续 IO 并报告容量失败，不能丢弃失败记录后声称整个目录成功。
- Native 任务观测/结果准入属于 owner 的受控协议。普通 Lua `deselect` 不能绕过任务锁；
  原先按 prepared roots 清理的调用方继续适用，不被解释为允许任意新节点。

## 容量与成本边界

以下为首期默认预算。实现可按测量修正内部块大小，但不能悄悄扩大公开容量或省略计费。

| 项目 | 默认上界 |
| --- | ---: |
| 每份 data 的 Rust retained 总预算 | 512 MiB，包含 Treeview、Filetree payload/索引、旧版本与在途数据 |
| Source 节点数 | 沿用 Treeview 容量，基线 50k；200k 使用显式压力预算 |
| 全进程并发目录读取 | 4，单 data 最多 4 |
| 单 data 排队的目录读取 | 256；其余需求保留在有界 dirty/interest 集合 |
| 单页 records | 512 项 / 1 MiB，先到者为准 |
| 单 data 扫描与结果暂存 | 32 MiB，计入 retained 总预算 |
| 单任务结果与身份暂存 | 32 MiB，计入所属 data 总预算 |
| 全进程文件任务数 | 16，包括排队与等待确认任务 |
| 文件 copy 流式 buffer | 每个在执行文件最多 1 MiB |
| 单 data watch 数 / 合并窗口 | 50 / 150 ms |

- Dirty/interest 集合按 source NodeId 去重，受 source 容量约束，不无限保留已删除路径。
  错误信息与任务结果包含 bytes 上限，超限报告 ResourceLimit；不以无限字符串或日志旁路预算。
- 不把各子系统的独立上界简单相加当成可同时使用的容量，统一总预算也必须满足。
- 局部 identity/metadata 更新包含该条目的 IO、排序索引与受影响祖先；没有 O(1) 的整目录 freshness 保证。
- W 个直接 children 的完整枚举/对齐至少 O(W)；首次排序允许 O(W log W)。已知 D 项 delta 使用局部索引更新。
- 目录 rename 的原生路径定位不重写所有后代路径，但实际改变的 List 正文字节和已加载 metadata 更新仍按量计费。
- 旧 frames、持锁任务与尚未完成的请求按引用保留数据；释放后可回收。缓存淘汰不能伪装成 Remove 或丢失选择 skeleton。

## 验收

使用当前基线机器、release Rust 和附着 Neovim UI，记录硬件/OS/Neovim、数据形状、样本数及自然 GC。
下面是目标，不是当前实测结果；压力档不冒充基线。

- 已加载数据的局部交互和数据就绪到适用 frame flush，沿用 Treeview 的 p95 ≤16 ms 目标；
  可让出的 Lua 主线程准备每片以 2 ms 为预算，目录 metadata 不进入主线程。
- 本地 SSD、缓存预热、50k entries 的宽目录：首批 512 项 flush p95 ≤100 ms，完整首轮 p95 ≤2 s；
  同时报告枚举/stat、对齐、projection、staging 和 UI flush。慢 filesystem 的 IO 单独报告，不删掉完整延迟。
- 真实 watch 单项变化分别记录 OS 通知、150 ms 合并等待、IO、owner 和 UI；已有 dirty 数据就绪后
  局部发布 p95 ≤16 ms。不能将刻意的合并等待从“文件变化到显示”总延迟中隐藏。
- 50k / 200k source、单目录 50k entries、至少三个不同 roots/modes 的 states、旧 frame 保留，
  验证 basename rename、目录 rename/reparent、局部插删与 metadata 更新。
- 深度 10k 的结构/文本片段用合成 source 验证，真实 filesystem 测到平台路径限制；
  分开报告结构深度安全和实际输出字节，不能要求 OS 接受超过路径限制的目录树。
- 连续扫描/刷新/取消、100 次开关 view、重复 query/目录替换后，队列与 retained memory 稳定且引用最终释放。
  内存分别报告 Rust requested/retained、Lua heap、Neovim buffers 与进程 RSS，不重复相加。
- Copy/move/delete 在临时目录内覆盖目录合并、拒绝覆盖后继续、类型冲突、symlink、部分失败、取消、
  跨 filesystem 回退和源/目标被替换。校验真实磁盘结果、NodeId、选择与独立 cleanup 状态。
- 大文件取消测量取消请求到停止发起新 IO、当前 syscall 返回和最终终态的时间，不给阻塞 IO 虚假的统一截止。
- 成功子项清理覆盖已加载与任务中发现的后代、失败兄弟、完整成功子树、同名重建、其他任务变化及重复回调。
  对大量 prepared roots 的无关更新和批量结果增加复杂度测试，不能只用少量 roots 的延迟推断可扩展性。
- Source order / ancestry text / task 准入扩展分别与 Treeview 原有行为做回归测试；原 consumer 默认行为保持原契约。
