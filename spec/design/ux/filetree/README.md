# Filetree 技术契约

Status: Design。本文定义 Filetree 的模块边界、资源、identity、读取、watch 与容量契约；文件 Job 见 [Filetree 文件 Job](jobs.md)。
Explorer 的输入与 UI 见 [Explorer Design](../../feat/explorer/README.md)，通用交互状态见 [Treeview](../treeview/README.md)。
性能目标见 [Treeview 性能契约](../treeview/performance.md)。

## 模块与所有权

- 当前只支持真实 filesystem 与最新 Neovim；不为其他宿主或未接入的 VFS 预留适配层。
  Explorer 与 Find Explorer 使用本模块；文件 Picker 的真实 IO 与 Diffview 的 untracked discard 也使用 native Jobs。
  Picker、Searcher、Diffview 的逻辑结果通过 [通用 Treeview records](../../feat/results.md) 表达。
- 使用现有 `yoz` crate：Rust 位于 `rust/yoz/src/ux/filetree/`，binding 位于其 `lua/` 子模块，
  Lua facade 位于 `lua/ux/filetree/`，入口为 `yoz.ux.filetree` / `require("ux.filetree")`。
- 依赖为 Filetree → Treeview 与现有 Rust fs/git 工具。Treeview 不导入 Filetree、Lua 或 Neovim。
  VFS 扩展保留在 [Draft](../../../draft/ux.md#vfs)，不属于当前 filesystem 契约。
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

| 入口                                                | 结果与职责                                                                                                                                                                       |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `open(path, options?)`                              | Future 返回 Filetree Data 或 Rejected；`data.root` 为初始入口 NodeId，路径 IO 在 worker 执行                                                                                     |
| `data:create_state(root?, display?)`                | 创建同 data 的独立 Treeview State，省略 root 使用初始入口                                                                                                                        |
| `data:source()`                                     | 返回不可变 source，资源查询必须携带这个 source 或相应 frame                                                                                                                      |
| `data:resolve(path)`                                | Future 返回资源句柄；只补齐定位所需的祖先，不递归读取整个 workspace                                                                                                              |
| `data:refresh(state)`                               | 按该 state 的 Tree 展开范围或 List 递归范围建立刷新需求，返回请求接受结果                                                                                                        |
| native `data:is_settled()`                          | 在请求接受后观察 owner 队列及执行中的整轮工作、active reads/query、待调度扫描/探测与 dirty demand 是否已收尾；不表示 IO 成功或 UI 已发布                                         |
| `data:inspect(source, node)`                        | 按需返回该版本的资源信息；需要新 IO 的详情查询另返回带身份校验的 Future                                                                                                          |
| `data:details(resource)`                            | Worker 校验资源及祖先 identity，返回当前 size、权限、八进制 mode 与 RFC3339 日期                                                                                                 |
| `data:listing(frame, first, last, parent_context?)` | Worker 格式化最多 512 行的已捕获 metadata；权限、size、日期、owner/group 不重新 stat 或扫描目录。`parent_context=true` 时上下文行使用该 Frame 中的父目录 metadata，保留行 NodeId |
| `data:subscribe({on_effect?, on_source_changed?})`  | 观察 effects 与 source revision；返回可幂等取消的订阅                                                                                                                            |
| `data:start_operation(plan)`                        | 接收明确源项、目标及可选的原任务清理资格，返回文件 Job，不自行选择操作源                                                                                                         |
| `data:check_transfer_target(source, target)`        | Worker 核对源和已存在目标祖先、拒绝 physical self-descendant，供补父目录前检查                                                                                                   |
| `data:start_create({target, path, directory})`      | 在明确目录内新建相对路径，自动补齐父目录，返回同一类文件 Job                                                                                                                     |
| `job:status()` / `job:results(first, last)`         | 读取进度/终态和有界逐项结果，不一次导出全部任务记录                                                                                                                              |
| `job:confirm(token, accept)` / `job:cancel()`       | 提交一次性确认或取消请求，不能被解释为 IO 已结束                                                                                                                                 |

具体字段见 [Lua 类型](../../../../lua/__types__/ux/filetree.lua)，入口适配见 [Lua facade](../../../../lua/ux/filetree/init.lua)。

### Data 请求的完成边界

`is_busy()` 供 Lua 调度观察已发布的 active work；完整目录刷新观察使用 `is_settled()`，
避免尚未取得 read slot 的 dirty demand 被判为空闲，也覆盖已接受的展开或 display 变更
在 owner 内派生 projection、read scheduling 和 Reader publication 的执行窗口。这个只读观察不增加 Lua 定时轮询；
请求接受、扫描结束、适用 frame 的 preparation/publication 和匹配 redraw 是不同边界。
`is_settled()` 只描述当前已接受的工作，失败的扫描也会收尾；调用方仍须检查对应 Source/slot 的错误。
取消 token 的确认不等于 IO worker 已退场：Reader 保留 queued/running worker 所属 slot，
同目录的页工作串行交接，取消后的 Scan 缓存释放后才允许替代扫描开始。Worker 退出时唤醒 owner 完成回收，
不增加 Lua 定时轮询。
独立文件 Job 和尚未由 watch 合并投递的通知（包括新订阅的 reconciliation）不属于这个完成条件，
不据此承诺后续不会出现新工作。

### 错误

IO error 保留操作、对应资源、平台错误类别与原始 error code；普通业务失败为完成值，不抛成丢失上下文的 Lua error。
`std::io::ErrorKind::NotFound` 对应结构化 `error.code = "NotFound"`；其他 IO 失败为 `ProviderError`。
调用方只根据 code 决定是否补建缺失父目录，不解析 message 中的诊断文字；`NotADirectory` 与权限失败不等价于缺失。

## 资源记录与路径

每个逻辑目录项包含独立的 occurrence key、原始名称、资源类型及可观察的 filesystem identity。
目录项是 symlink 时另外保存链接文本与按需取得的目标信息，不能把目标身份当成链接自身身份。

- **路径契约：除底层 filesystem / OS 操作边界外，路径字符串一律使用 `/` 分隔目录。**
  Filetree/Explorer 的 Lua 输入输出、root/reveal、Resource.path、link、Job 确认与结果（包括 physical paths）、
  annotations、导航、操作准备与持久化偏好均遵循此契约；`physical` 表示解析后的资源位置，不表示使用系统分隔符。
  Lua 使用 `ux.filetree.path` 处理这些路径；不得送入同时把 `/` 和 `\` 当分隔符的通用字符串函数。
  Windows 输入在 OS 边界把 `\` 转为 `/`，调用系统 API 时才反向转换；drive、UNC 和 verbatim 前缀保持身份，
  分别可表示为 `C:/`、`//server/share/`、`//?/C:/`、`//?/UNC/server/share/`。
  Unix 中只有 `/` 是目录分隔符，名称里的字面量 `\` 和非 UTF-8 bytes 必须原样保留。
  转换不折叠 `..`、改写大小写或跟随 symlink；例如 `link/../file` 由实际 filesystem 解析。
  Neovim buffer 名称、系统 cwd 与路径补全结果在进入此协议时转换；显示缩写、控制字符转义不回流到 IO。
- 原始名称/路径由 Rust `OsString` / `PathBuf` 表达。子项保存原始 basename，路径由 source 的 parent 链组成；
  这些原生值封闭在底层 filesystem provider 内，用于资源定位、identity、watch 与 IO；不直接泄漏到 Lua 路径协议。
  仅资源入口需要保存完整基路径。Rename/move 不逐个重写所有后代的完整 filepath，不额外缓存完整逻辑路径副本。
  路径中的 `..` 按 filesystem 解析，末尾 symlink 保留自己的 occurrence；大小写不敏感的平台按实际 basename 对齐。
- 核心 metadata 包括类型、file identity、长度、时间和权限等原始数值。原生发布使用紧凑、不可变 payload，
  由 Treeview `NodeData.payload` 直接持有；结构化 `fields` 不承载资源 blob，也不为每个条目建立单项字段 map。
  编码属于 Filetree 私有实现，Lua 通过 Resource API 读取，不接收或解析该 blob。
  预算估算直接计算同一 native 编码的长度，不为计费生成临时 payload；实际发布时才编码。
  每份 allocation 只计费一次，旧 frame 的最后一个引用释放后才回收。
- uid/gid 名称、日期、大小、人类可读权限只在详情或实际展示需要时格式化；不在每次 readdir 中逐项查询用户数据库。
  现有 `fs.readdir` 的完整展示记录不是高频扫描协议。
- 路径查询使用 `(parent occurrence, raw basename) → NodeId` 索引，比较原始名字；完整路径定位按 components 查询。
  不以字符串前缀判断祖先，不为每个后代存多份绝对路径或 canonical path。
- 打开 workspace 时只建立 filesystem/volume 入口到初始目录的已知祖先链，未枚举的 children 保持 partial/unknown。
  Workspace 不是 source 的人工 filesystem 边界；向上切换 display root 可复用这些祖先，必要时按需定位。
- Lua 通过资源句柄请求 `/` 路径或发起操作。Unix 按需保留原始 path bytes；不能无损转换成 Neovim filepath 的路径
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
  移动执行单元内暂缓相关 native 读取与观测，保留显式请求和当前浏览需求；发布或失败后恢复，避免本次 rename 的监听事件提前删除源 occurrence。
  跨 filesystem move 的每个 copy/remove 子项及末尾目录删除也保持协调直到 owner 发布；递归枚举在这些执行单元之间进行。
- 外部 rename 只在同一批可靠观测中存在无歧义的一对旧/新目录项，且资源 identity 对应时保持 key。
  无法确认、存在 hardlink/alias 歧义或旧节点已经 Remove 时按删除/新增处理，不事后复活旧 ID。
  粗粒度 watcher 不提供可靠跨目录关联时，不强行推断跨目录 rename。
- 目录枚举与 metadata 不是 filesystem 快照。不能保证识别两次观测之间发生、又完全消失的变化，
  也不声称仅靠 inode 可以排除所有复用；契约基于实际取得的身份信息和已确认的操作结果。
- 入口被删除时发布 RootUnavailable；同路径新建入口不自动绑定旧任务、旧 NodeId 或旧 view 的 root。
- 捕获资源在 owner 中重验时，校验同一 data、节点及全部祖先的 NodeId parent 链、原始名称、anchor 和资源 signature。
  Ancestor symlink 固定 referent；对末尾链接自身的操作固定链接 occurrence，写入链接目录时另固定其 referent。
  普通 metadata 或 children 完整性更新不改变该判据；filesystem IO 仍执行自身的 identity 校验。

## 目录读取、刷新与监听

### 有界扫描

- 首次 Tree 展开只读直接 children；List 和递归展开的后续需求由 Treeview 提供。
  共享 views/源项准备对同一目录同一 epoch 合并读取，不为每个 view 发起一份 readdir。
  已启动文件 Job 使用[私有遍历](jobs.md#job-私有遍历)，不为遍历申请浏览 read lease。
- 同一轮刷新同时覆盖祖先与后代时，先对齐祖先，再按当前路径重读后代；初次 List 加载仍可并发读取已发现的目录。
- 每次扫描固定目录 occurrence、资源 identity、request epoch 和来源。Worker 使用显式遍历栈，
  一个目录取得基路径后复用于其直接 children，不为每条目重走整条祖先链。
- 枚举和基本 metadata 读取按有界块进行；首个 page 较小、后续 page 较大（上限见[容量](#容量与成本边界)），
  以保留首批显示速度并减少宽目录反复插入、索引修复与 publication 的成本。
  Scan staging 或 data retained 余量不足时继续使用首个 page 的小批次，不提高既有硬预算。
  初始化已知成员索引时逐项检查取消，分页枚举也持续检查；取消后释放已取得的暂存和目录句柄。
  页被 owner 消费后才推进下一页，沿用 Treeview publication 背压，不能把完整目录先导出 Lua。
  Surface 仅等待 source 合并 deadline 时允许确认已消费的 source revision，继续分页；实际 frame 准备仍保持背压。
  显示等待不要求中间每一页都发布为 Lua 正文，既有读取、暂存和 latest target 的容量边界保持不变。
- 完整刷新需要记录本轮 seen 成员，只有成功终态才能删除旧集合中未出现的成员。
- Browse Scan 固定一份不可变 Source；已知直接 children 使用 NodeId/identity ordinal 索引与访问、消费和有效排序标记。
  稳定成员不保留名称、payload 的额外副本，也不重建完整排序树；排序位置由原有 sibling 顺序与本轮新增/改序的有界 delta 合并。
  同名观察去重、hardlink 歧义和 rename 对齐仍基于该次捕获与完整观测，不能混入新的 live Source 或可变路径索引。
  Deferred/carry 只持有已计费的观察，进入 page 时再准入输出空间；预算随观察、分页结果和扫描索引各自的 ownership 释放。
  Deferred 容器按 capacity 增长准入，底层存储持续由 Scan 计费，不能因元素移入 page 而提前释放仍保留的槽位费用。
  每个 Reader 的共享 scan staging 受[容量](#容量与成本边界)上限约束；扩大后续 page 不改变该上限与全局 data 预算。
  Seen 集合与在途结果计入预算；无需为未变化成员复制新的 NodeData 或重新发布 metadata。
- 初次加载可逐页插入，source 顺序通过 sibling 索引维护。刷新中的新数据可以发布，旧数据保留到完整终态。
  枚举失败、取消或硬预算失败不得把 partial 集合当成完整集合。
- macOS 在未以 nosuid 挂载的 APFS 卷上批量同时读取名称与 metadata，结果与逐项 `lstat` 一致，
  批次缓冲计入扫描预留；symlink、firmlink、挂载点、单项错误与属性不全的条目仍按路径逐项读取。一个批次是一次观测：
  批次读取之后才删除或 rename 的条目留在本轮结果中，由之后的监听重读收敛。其他卷只列名称、逐项读取：
  FAT 与 exFAT 每次列目录都给空文件新的 file ID，nosuid 挂载丢弃 setuid 与 setgid 位。
- 逐项读取时，`read_dir` 已缓存的条目在 metadata 读取前被删除或 rename，明确的 NotFound 可跳过；
  只有扫描成功终态才按本轮成员集合删除对应旧项，目录本身的 identity 与读取错误仍须检查。
  其他条目 metadata 失败不能当作该条目不存在。保留已知有效记录并标记本轮不完整；首次未知条目报告读取错误。
  无法确认缺失的其他旧项也不能在该轮被清除。权限失败可显式重试。
  同一路径、同一 symlink occurrence 的 target 暂时不可确认时，保留最后确认的 target 和 children，
  标记读取错误/不完整；恢复后确认 target 未变时保留 children 的 NodeId 与 selection。
  Move 到新路径不继承旧路径的 target 判断；确定的 target 替换、缺失或非目录仍结束旧 children。
- 目录 IO 返回时无关数据 revision 已推进，可在 owner 内按当前 source 重做该槽位对齐；
  目录 epoch、身份或本轮读取资格已失效时拒绝。不能简单以全局 revision 不同丢掉全部有效读取。
  同一 occurrence 的内部读取重启保留显式请求和仍适用的浏览需求；换 epoch 不等于调用方撤销请求。

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

- Rust platform backend 使用现有依赖与平台原生目录通知。
  注册失败报告错误并保留手动刷新，不静默切换为全树周期扫描。
  Linux 监听绑定已验证目录的 inode，注册后不持有目录 fd，因此不延迟空根目录的删除通知。
  Linux 的 display root 同时监听父目录中的入口名称，处理 cwd/外部句柄仍持有根目录而推迟 self-delete 通知的情况；
  该辅助监听只匹配根名称与父目录自身事件，其他 sibling 活动不刷新根目录，占用同一份 OS 监听根预算。
  Windows 每个 watch 的读取 buffer 计入预算；注册时核对打开目录的 identity，取消后等 pending IO 完成再释放平台资源。
- Tree 的刷新兴趣来自可见 views 的展开目录及其入口；List 请求当前浏览范围内的目录。
  同一资源共享内部兴趣，逻辑 occurrence 的刷新结果仍分别对齐。
  每个目录链接入口分别请求其自身父目录与 link text 对应目标父目录的监听，后者由 watch 线程解析；
  共享 referent 不省略其他入口的父目录需求。
- macOS 将递归监听根与目录刷新兴趣分开。浏览初始 workspace 内的子目录时，保留 workspace 根订阅；
  仅用于订阅的根不要求重读自身 children。按 canonical path 的组件 Trie 合并祖先/后代监听根，
  一个 workspace 内展开超过 50 个目录仍只持有一个 OS root 和目录句柄；外部 symlink 可能需要独立根。
  每份 data 的实际监听根数受[容量](#容量与成本边界)上限约束，内部目录兴趣受 source 容量和 retained 总预算约束；
  Linux/Windows 的非递归 backend 每个目录 watch 占一个根。
  超限时优先入口和当前可见展开目录，其余按最近需求顺序分配；未覆盖目录需要手动/后续重读。
- FSEvents 普通文件事件只匹配 Trie 中的精确目录及其父目录，不能以 workspace 祖先命中来刷新所有后代。
  目录 create/remove/rename 和 `MustScanSubDirs` 使对应子树内的兴趣失效；历史丢失、根移动或卷变化使已覆盖兴趣全部失效。
  变化在事件静默后交付，自首个事件起最多等待合并上限（静默、上限与单批 dirty NodeId 数见[容量](#容量与成本边界)）。
  距上次合并重读不足合并上限就开始的变化视为持续活动，合并满上限；注册与重试引起的重读不算活动。
  孤立变化因此尽快显示，持续变化每个上限周期至多重读一批。目录读取沿用现有并发与排队预算。
- `watch_status().roots` 表示实际 OS 监听根数，`directories` 表示已覆盖的物理目录兴趣数，
  `covered` 是这些兴趣关联的逻辑 occurrence NodeId 集合。仅用于订阅的根不计入 `directories`。
  Linux 仅匹配入口名称的父目录辅助监听也不计入 `directories`，仍计入实际 `roots`。
  macOS 的 `limited` 反映实际根预算，不因普通展开目录超过 50 而置位。
- `watch_activity()` 计数携带 filesystem 事件的 dirty 交付批次；目录读取、注册与重试引起的重读，
  以及 macOS 新覆盖目录的补读都不推进它。事件标记与对应 id 在同一临界区取出，交付间隙到达的事件计入下一批。
  消费者据此区分磁盘变化与浏览读取引起的 source 变化。
- 目录收起或失去 view 需求时撤销刷新兴趣；再次加入兴趣时强制重读，关闭读取与注册监听之间的竞态窗口。
  无剩余兴趣时释放 OS 订阅，保留的 source 不能被视为持续更新的缓存。
  任务不依赖 pane 存活，最后一个 data/state/task/frame 引用消失后回收对应资源。
- Lua facade 通过 Treeview 的[合并通知与 `after_poll`](../treeview/action.md#native-notifications) 接入自己的收尾，
  不改写底层私有方法；无 view、Job、读取、query 或未准备 task deadline 需求时释放通知连接。
  Watch status 的独立变化也通知 Lua，不要求另一次 source publication；Filetree 按 revision 读取一次，
  通过 `data:subscribe` 与创建时的 `on_effect` 交付 `WatchStatus`，共享 data 的 Explorer sessions 消费同一发布。
  最后一个 view 关闭后保留通知连接，收到实际 watch roots 归零后再释放，不为此维持周期轮询。
  未提供自定义 handler 时，可见 view 的监听错误与覆盖不足使用默认告警。
- 观察者按注册顺序同步接收通知，先于创建时的 `on_effect`；一个观察者出错不阻止后续观察者或默认 handler。
  Source 回调从注册时的 revision 开始，只交付之后观察到的变化；selection/annotations 不伪装成 source 变化。
  `unsubscribe()` 立即撤销尚未开始的交付；交付中新增观察者不接收当前事件。最后 Session 释放自己的订阅，
  不通过恢复下层回调链完成清理。观察者注册本身不创建 filesystem 兴趣，也不阻止无需求 data 休眠。
  回调重入 Neovim 事件循环并观察到更新版本时，旧 source/watch 发布停止后续交付，不能倒退其他观察者的状态；
  普通任务 effects 保留各自交付，不按 source/watch 的最新版本策略丢弃。
- Linux 与 macOS 的 watch controller 由平台事件和订阅变更、关闭及停止请求唤醒，事件在进入等待前发生也不会丢失；
  仅在合并 deadline 或待完成工作需要检查时定时等待，没有事件时休眠。Windows backend 以有界轮询读取平台事件。
  任务仍可在没有 view 时发布结果；同一 source revision 不重复发送 publication acknowledgement。
- Symlink 浏览按每条逻辑祖先链的目标目录 identity 检测循环，允许非祖先方向的别名访问。
  遇到循环保留链接项并报告循环原因，停止该分支递归；不全局去重物理目录从而吞掉其他合法 alias。

## 多 state 的 List 文本

Filetree 使用 [Treeview List 正文](../treeview/projection.md#list-正文)，不把 filesystem 路径解析交给 Treeview。

- 无深度限制的 State 使用 `list_text="ancestry"`；Tree 显示 basename。
- 指定 `list_depth` 时保留调用方的 `list_text`。
- 不同 roots 的 State 可共享 Data，各自从 Frame 的 source labels 派生正文，不在 Lua 拼接整份路径表。
- Root 边界、匹配 spans、共享文本、rename/reparent 失效与字节预算统一遵循上述 Treeview 契约。

## Git 与 diagnostics

- Git 原生结果与 Lua 提交的 diagnostics 是独立的、带来源 revision 的输入；过期批次不覆盖新状态。
  Diagnostics 按 namespace/buffer 替换对应集合，关闭或清空时撤销原贡献，不重复累加计数。
- 未加载文件的状态保留在有界的稀疏路径索引中，不为显示 Git/diagnostic 聚合而递归扫描目录、
  创建全部 filesystem 节点或打开 buffers。目录聚合按受影响的逻辑祖先链增量更新。
- 每个逻辑 occurrence 可展示同一资源的状态；聚合按该逻辑树的后代 occurrence 计数。
  输入事件本身去重，不为跨 alias 的展示去重建立全树资源集合。
- 单个诊断或 Git 状态变化不重建所有行。保持 basename allocation，使用 viewport decoration 查询。
  导航只查当前 frame 的可见结果，类型筛选和循环规则见下方 `data:next_annotation`。

输入接口由调用方连接已有 Git/diagnostic 数据源，Filetree 不另建一套 Git 轮询或订阅系统：

- `data:set_git(root, revision, snapshot?, ignored?)` 接收 `yoz.git.StatusSnapshot` 与可选的 `yoz.git.IgnoreCache` 当前快照，
  直接保留原生不可变结果，不经 Lua 导出全部路径；同一 root 的较旧或重复 revision 拒绝，两个输入都省略表示撤销。
- `data:set_diagnostics(namespace, bufnr, revision, path?, counts)` 替换该 namespace/buffer 的贡献。
  `counts` 依次为 error/warning/info/hint；全零撤销旧贡献，仍保留最后 revision 防止迟到结果复活。
  Lua facade 提供 `sync_diagnostics(namespace, bufnr)`，通过 `vim.diagnostic.count` 读取计数并补齐四种 severity；
  不复制完整 diagnostic records。事件订阅由调用方持有，namespace ledger 保留 reset/reconnect 的撤销资格；
  `DiagnosticChanged` 的事件 payload 不能代替 buffer 的全部 namespace 状态。
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
  准备期间目标或 viewport 改变时重查，Busy 延后重试；独立 annotation 输入的 native 通知和 viewport 变化触发后续更新。
  普通查询完成时须仍拥有当前 request key 和 viewport；迟到的旧范围结果不能覆盖新 publication 的缓存或清除其 key。
- `data:next_annotation(frame, row, kind, forward)` 仅在给定 frame 的可见行循环查找；row=0 表示从头/尾开始，
  返回 1-based 行号或 0。kind 为 git/diagnostic/error/warning；diagnostic 类只命中文件，git 可命中目录，ignored 本身不算 changed。
- 装饰输入只改变独立索引和装饰 revision，不推进 source topology、selection 或正文版本；Filetree attach 负责当前 viewport 的显示。

## 容量与成本边界

每份 data 的 retained 总预算、Source 节点数与 payload 沿用 [Treeview 默认容量](../treeview/action.md#默认容量)，
包含 Filetree payload/索引、旧版本与在途数据。下表列出 Filetree 覆盖或新增的默认上限，各项与 data 总预算同时生效；
性能测试规模不代表硬容量。

| 项目                                              | 默认上界                                                           |
| ------------------------------------------------- | ------------------------------------------------------------------ |
| 全进程并发目录读取                                | 4，单 data 最多 4（覆盖 Treeview `concurrent_reads`）              |
| 单 data 排队的目录读取                            | 256（覆盖 `queued_reads`）；其余需求保留在有界 dirty/interest 集合 |
| 首个扫描页                                        | 512 项 / 1 MiB，先到者为准                                         |
| 后续扫描页                                        | 最多 2,048 项 / 4 MiB；预算不足时使用首批大小                      |
| 单 data 扫描与结果暂存                            | 32 MiB，计入 retained 总预算                                       |
| 单任务遍历、结果、身份、journal 与 admission 暂存 | 共享 32 MiB，计入所属 data 总预算                                  |
| 全进程文件任务数                                  | 16，包括排队与等待确认任务                                         |
| 文件 copy 流式 buffer                             | 每个 Job 最多 1 MiB，按需分配并复用                                |
| 单 data OS 监听根数                               | 50；macOS 根递归覆盖，Linux/Windows 每目录一个                     |
| Watch 合并静默 / 上限 / 单批 dirty NodeId         | 30 ms / 150 ms / 512                                               |

- Dirty/interest 集合按 source NodeId 去重，受 source 容量约束，不无限保留已删除路径。
  错误信息与任务结果包含 bytes 上限，超限报告 ResourceLimit；不以无限字符串或日志旁路预算。
- 不把各子系统的独立上界简单相加当成可同时使用的容量，统一总预算也必须满足。
- 局部 identity/metadata 更新包含该条目的 IO、排序索引与受影响祖先；没有 O(1) 的整目录 freshness 保证。
- W 个直接 children 的完整枚举/对齐至少 O(W)；首次排序允许 O(W log W)。已知 D 项 delta 使用局部索引更新。
- 目录 rename 的原生路径定位不重写所有后代路径，但实际改变的 List 正文字节和已加载 metadata 更新仍按量计费。
- 旧 frames、持锁任务与尚未完成的请求按引用保留数据；释放后可回收。Source 节点不淘汰，只因 Remove 减少，
  见 [Treeview 新增、补载与移除](../treeview/module.md#新增补载与移除)。
- 完整 cold copy 可以只保留浏览根；100k 的零散 partial frontier、已加载目标或跨卷 move 仍可能需要
  O(N) 个 Source 节点。预算不承诺任意文件名、目录形状、独立错误数均可完成 100k。

### 性能目标

通用延迟口径、2 ms 工作片与已加载数据局部交互 p95 ≤16 ms 见 [Treeview 性能契约](../treeview/performance.md)。
Filetree 另以 release Rust、附着 Neovim UI 衡量以下目标；压力档不冒充基线：

- 本地 SSD、缓存预热、50k entries 的宽目录：首批 512 项 flush p95 ≤100 ms，完整首轮 p95 ≤2 s；
  同时报告枚举/stat、对齐、projection、staging 和 UI flush。慢 filesystem 的 IO 单独报告，不删掉完整延迟。
- 真实 watch 单项变化分别记录 OS 通知、合并等待、IO、owner 和 UI；已有 dirty 数据就绪后
  局部发布 p95 ≤16 ms。不能将刻意的合并等待从“文件变化到显示”总延迟中隐藏。
- 大文件取消测量取消请求到停止发起新 IO、当前 syscall 返回和最终终态的时间，不给阻塞 IO 虚假的统一截止。
- 深度 10k 的结构/文本片段用合成 source 验证，真实 filesystem 测到平台路径限制；
  分开报告结构深度安全和实际输出字节，不能要求 OS 接受超过路径限制的目录树。
- 连续扫描/刷新/取消、反复开关 view、重复 query/目录替换后，队列与 retained memory 稳定且引用最终释放。
