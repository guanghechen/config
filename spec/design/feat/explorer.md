# Explorer 设计

Status: Design。本文记录默认入口的技术契约与当前默认行为。
本文是 Explorer 交互的单一契约；文件操作规则由 [Filetree Design](../filetree.md) 定义。

## 所有权与模块边界

- 默认入口保持 `era.widget.explorer`，通过 `era.m.explorer.Widget` 组合
  [Filetree](../filetree.md) 与 [Treeview](../../../doc/spec/treeview/README.md)。
- Rust `ux/explorer` 组织 workspace、上一个 display root、文件 Job 和浏览动作。
  Filetree 持有 filesystem 事实，Treeview 持有唯一的 topology、root、展开、cursor、selection 和锁。
  Explorer 通过同一个 owner 提交 selection 与用途，不再维护 Lua tree 或独立 pending sources。
- Lua `session.lua` 管理 native handles 与导航 generation；`widget.lua` 管理 pane、标题和持久化偏好；
  `action.lua` / `keymaps.lua` 解释输入；`jobs.lua` 管理准备、确认、进度与取消；`buffers.lua` 接入 LSP/buffer；
  `subscriptions.lua` 接入 Git/diagnostics；`view.lua` 装饰 viewport；`exit.lua` 管理退出协议。
- 实例可传 `data` 共用资源并创建独立 state，也可传 `session` 共享完整浏览/选区/任务状态。
  每个 view 使用专用 buffer。显示开关以 native state 为准，标题直接读取它；Widget observables 只保存偏好和外部输入，
  native 变化不回写成新输入。单个开关提交带同版 revision 的 partial intent，共享 session 与 reveal 的变化同步到各标题。
- 关闭 pane 释放 view、保留 session，不清空选区、不取消 Job。最后 Widget dispose 后撤销输入订阅并取消准备；
  已执行 Job 由 registry 保留至终态且结果交付完毕，再释放 handles。Native Explorer 仅弱引用最近 Job 作为并发启动 guard，
  不额外保留终态 Job 的 Source/结果；外部 Job handle 仍可在终态后读取结果。
  同一 data 共用一个订阅 controller，来源 ledger 与 revision 随 data 存活。
  Controller 使用 Filetree 的可取消订阅接收 source/effect，不改写 Treeview/Filetree 的私有 poll 或 effect 函数。

## 浏览与输入

- 默认 Tree、显示隐藏项、压缩单子目录链，selected-only 关闭，pane 宽 30 列；可恢复显示偏好与宽度。
  正文从 display root 的直接 children 开始，root 放在 tabline；无 tabline 时使用 winbar。
  两种栏共用路径展示：workspace 名、workspace-relative 子目录、home 缩写，以及离开 cwd 的颜色和标记保持一致。
  Pane 创建前完成 Explorer scratch buffer 配置；native view 就绪后接管同一 buffer，不经过普通空 buffer 或二次换入正文。
  隐藏后重开恢复进程内 state；跨重启仅恢复显示偏好与宽度，不恢复选区或未完成任务。
  首次打开失败保留可关闭的错误 pane，`R` 重试。每次 opening attempt 由 Widget 的 `_begin` 统一报告一次，
  多个 pane、显示偏好与 reveal 等 ready 消费者不重复报告同一次失败。用户提示保留错误原因与重试方法，
  不附 Lua traceback；原始 Future 保留完整错误。Dispose 或新 opening attempt 取代旧 ready 后忽略迟到失败；
  ready 成功后的独立 attach/refresh 错误仍正常报告。
- Display root 的目录扫描失败不清空已发布 children。标题从当前 root 的 Source error 显示
  `read failed` 与重试键 `R`，仍有 children 时标明 `cached`；空目录的读取失败不能伪装成成功的空结果。
  扫描错误优先占用 tabline/winbar 的可见宽度，路径与 flags 让位；极窄 pane 使用 `error · R` 或 `! R`。
  Session 只对适用 frame 中的 root/error 转换报告一次，共享视图不重复报告；成功重试或切换 root 后清除提示。
  Job 进度仍优先显示，具体扫描错误由报告保留；这个观察复用 frame publication，不增加轮询。
- Tree/List 均使用 Filetree 的目录优先 sibling source order。List 始终递归，正文使用相对 display root 的 ancestry text；
  Tree 的展开、折叠和结构导航在 List 中不执行。
- Root/reveal 的异步 resolve 使用 generation，迟到结果不覆盖新导航。Reveal 优先保持逻辑路径；目标位于外部时
  尝试 display root 本身及其直接 symlink children，多个 alias 取物理目标最具体者，无法映射才切到目标父目录。
  路径 resolve 因并发发布返回 Stale 时，只读导航最多重新观察两次；每次观察前后检查 generation 与 session 存活。
  其他错误直接报告，过期导航停止重试。文件修改操作继续使用固定 Resource，不采用该路径重试。
  Reveal 将展开的祖先记录到 Treeview expansion invalidation；与 loading/selection 更新合并发布时仍须投影目标行，
  不能因沿用折叠布局而把刚设置的 cursor 回退到父目录。
- Workspace 保存 occurrence 与路径 fallback。Root 删除后明确提示，可返回父目录；workspace 同名重建后可重新定位，
  新资源不继承旧 occurrence。
- 打开、复制路径等动作在输入时捕获 Resource/frame，后来的光标移动不改变本次目标。Visual 通过 Treeview
  `range_action` 保持布局与端点，不在 Lua 重建范围算法。Explorer 的双 Esc 先退出 Visual；copy/cut 用途中
  只取消 pending transfer、保留选区并恢复 select，普通 select 时清空选区。判断与提交由 native owner 原子执行，
  不依赖上一次展示的 frame；取消用途不刷新 selection stamp。持有任务锁时拒绝该动作，已启动的 Job 使用
  Space 菜单取消。其他 Treeview 沿用 [双 Esc 清空选择](../../../doc/spec/treeview/visual.md#移动与共享-state)。
  `i` / `I` 不进入正文编辑。
- `explorer` / `treeview` buffer 不参与 Lua scroll dressing 的插值动画；cursor 与 viewport 由 renderer 发布，
  动画中间位置不能反向成为新的导航输入。窗口从普通 buffer 切入时释放已有动画及其临时 window options。

## Selection 与文件操作

- Lua 操作入口接收一个 `IJobRequest`，由 `kind` 唯一确定 create、rename、paste、delete、普通 copy/move，
  或 copy/move to path/directory；路径请求省略 `path` 时才打开输入框。参数记录分别声明所需字段，
  不再组合 `rename`、`to_path`、`to_directory` 布尔开关；准备状态使用独立的 `IPreparation` record。
  例如 `session:operate(view, {kind="rename", name="next.lua"})` 与
  `session:operate(view, {kind="copy_to_path", path="relative/next.lua"})`。
- 所有路径遵循 [Filetree 路径契约](../filetree.md#资源记录与路径)：Explorer 内统一 `/`，
  原始 OS 输入在边界转换，只有底层 filesystem / OS API 使用系统路径。默认复制名、relative/dirname/basename、
  导航和 Copy Path 共用该语义；Unix 文件名里的 `\` 不得变成目录层级，`..` 保留给 filesystem 解析。
- Selection 判空同时考虑 `subtree_roots`、`self_only_nodes` 和 pending；递归文件动作只消费完整的 `subtree_roots`。
  只有 self-only 选择时保持用途，不执行递归 IO，也不回退到光标项。确定为空时退出用途；
  后续结构更新自然产生选择时进入 select，不恢复先前的 copy/cut。任务期间保留已固定的用途。
- Normal `<Tab>` 与 `ms` 使用 select 用途；`mc`（别名 `y`）/ `mx` 显式使用 copy/cut 用途。未选项加入当前选区并切换用途；
  已选项上切换用途保留选择及 selection stamp，再次请求同一用途才取消该项。select 用途清除 copy/cut。
- Normal `c` / `x` 有逻辑选区时标记 copy/cut，无选区时询问光标项的复制/移动目标路径；复制默认使用 `-copy` 名称。
  Cursor 路径操作携带输入 frame 和原 Resource；native owner 在同一次准备中校验空选区意图、资源及祖先身份并锁定。
  用户改选后再清空仍拒绝，节点替换、路径或祖先关系变化也拒绝；无关目录补载、metadata 更新不因全局 revision 变化误拒绝。
  操作始终绑定原 Resource，不重新捕获当前光标或自动重放；Filetree 在 IO 边界继续校验 filesystem identity。
  Visual `<Tab>` 切换范围选择并保留用途；Visual `c`（别名 `y`）/ `x` 将范围并入已有选区并刷新 stamp。
- `p` 只对 copy/cut 生效；取得 selection lock 后从已提交状态固定用途，与 Ready 源项配对。Treeview 的 subtree roots、
  self-only 和任务清理遵循其契约，不能按可见行猜测完整目录范围。
- 消费逻辑选区的只读动作要求源项完整；native `prepare_selection` 在一次 owner action 中检查选区：完整时返回
  `Inspected` 及对应不可变 Source，不取得任务锁；pending 时直接返回 `Locked`，自动补载必要的 children，Ready 后继续原动作。
  选区以该 owner action 的处理顺序为准，此前排队的改选先生效，之后的改选不能越过已取得的锁。
  读取源项只使用回复携带的 Source，不与新的 `data:source()` 拼接。已有 Job 期间仍允许完整只读 inspection，pending 则返回 Busy。
  标题显示 loading selection，Space menu 可取消；等待期间允许浏览，取消、读取失败或关闭原 pane 后不消费部分集合，
  保留选区与用途。Lua 在提交 acquisition 前登记准备 owner；取消或 dispose 后仍接收晚到的 Locked 回复并释放精确 token，
  在清理完成前不释放 session 或接受下一次准备。已 full 的目录直接作为完整源项，
  不为导出目录路径补载后代；失败后用户重新执行动作创建新的准备任务。每个新准备任务首次查询显式重试
  选区所需的失败 children，后续轮询不重复重试；读取再次失败时终止本次动作，等待用户下一次尝试。
- 当前目录行是 paste/new 的目标，文件行用父目录，空树用 display root。`a` 接受相对路径，末尾 `/` 表示目录；
  `A` 明确新建目录。自动补父目录，禁止覆盖最终目标；新文件成功后 reveal 并打开，新目录只 reveal。
  交互输入使用 `Create file` / `Create directory`，预填相对 display root 的目标目录前缀；保持前缀时仍绑定
  捕获的目标目录 identity，修改前缀时按捕获的 display root 解释路径。只提交目录前缀不创建文件。
  前缀含换行而无法放入单行输入时，预填留空、标题显示目录 label，输入继续相对捕获的目标目录解释。
  创建完成使用 Job 已发布的 NodeId 定位，保留创建时的逻辑 occurrence，不按同一路径重新绑定资源。
- `r` 接受一个源项及单一 basename，保持父目录；无选区时用光标项。Space menu 的 Copy/Move to path 只接受一个源项，
  输入为完整目标路径，相对输入以 cwd 解析，允许补父目录；多项使用 Copy/Move to directory，逐项映射为原 basename。
  Rename 默认值按平台从 native raw path 提取，Unix 文件名中的反斜杠和原始 bytes 不被重解释为分隔符或 display label。
- Normal `d` 使用选区，无选区时用光标项，先确认。`dot.context.explorer.trash=true` 时明确送回收站，否则明确永久删除；
  确认显示固定源项的总数与前五个名称，目录以 `/` 标识，超出部分显示剩余数量，默认 Cancel。
  使用 `vim.ui.input` 的 confirmation 模式，在当前光标附近按 `y` 确认，`n` / `<Esc>` / 空 `<CR>` 取消。
  单项短名称使用一行输入；多项或长名称在同一浮窗中显示可换行的说明，按内容确定高度，最多八行。
  默认确认不使用 picker、搜索框或匹配开关。
  回收站工具不可用或失败不降级永久删除。
- Visual `d` / `oa` 直接消费输入时捕获的临时范围；范围内父节点覆盖后代，按最外层子树去重。
  Rust 只读范围查询复用 Treeview 的 identity / ancestry 校验，不改写逻辑选区；回复保留输入 frame 的 Source，
  外层 revisions 记录 owner 校验时的状态。删除确认和 Job 使用固定的源项，
  不随光标移动或同名资源替换重定向；取消不删除文件，原有无关标记及 copy/cut 用途保留。
- 目录合并、逐项冲突、type/symlink 校验、跨卷 move 和部分成功遵循 Filetree 契约。覆盖提示同时显示源和目标，默认 Skip。
  覆盖与退出时取消未完成操作也使用相同的轻量 confirmation 输入；空输入按否处理。
  成功项清理，失败/跳过保留；context Stale 单独报告，不能重绑同名新项。
- 修改操作准备、执行、确认和取消期间锁定选区与新修改操作，允许浏览。取消准备会结束等待中的输入 Future，等原 token 解锁再恢复；
  迟到 callback 没有执行资格。Job 取消要等 native 终态；标题显示进度，Space menu 提供取消和最近结果。
  Filetree 通过 native 通知统一读取 Job 状态并交付终态、新确认和可读取结果；Explorer 不再单独轮询 Job。
  字节与已处理项进度共用 40 ms 限频，两者首次非零变化、阶段、确认、取消和终态及时唤醒；
  运行和等待确认都不维持周期性的 Job 检查。标题使用独立 `processed`，不把归并后的结果条数当作进度；
  字节量按 B/KiB/MiB/GiB 自适应。处理数包含失败和跳过，不表示成功数，也不显示未经预扫描的总量或百分比。
  运行/准备/确认状态优先占用标题宽度，路径与 flags 让位；读取、私有目录发布和清理阶段保留对应提示。
  结果积压按有界批次调度处理，全部交付后才完成 session；补建目标父目录同样通过终态通知继续准备。
  Filetree 使用目录 staging 时，新目标目录在发布后出现；期间继续通过标题提供进度与取消。
  发布后按实际浏览需求加载目标后代，不能以复制中尚无目标行判断 Job 没有响应。
  成功结果与选区清理由[Filetree 发布契约](../filetree.md#执行器)约束。
  无可见 pane 时 Job 继续使用全局 UI 确认，不强制重开 Explorer。
- 目录内部按 filesystem 发现顺序执行，确认次序不跟随当前浏览排序。
  确认和结果使用 Job 内的 ItemId；结果可以没有浏览 NodeId，历史路径及身份不随后续 cleanup 准入改写。
  完整复制折叠目录不自动加载源或目标后代；partial 成功项清理和预算边界遵循 Filetree 契约。
- 最近结果保留最后 128 项；failed、skipped 与含同步错误的结果独立保留，后续成功不会淘汰它们。
  独立明细最多 512 项、1 MiB 字段与记录预算，先到者为准；超出部分记录数量并在 Last results 中明确显示。
  汇总计数仍覆盖完整 Job，下一次 Job 启动时重置最近结果与明细，不延长终态 native Job 或 Source 的生命周期。
  IO 成功后的 editor 同步失败使用 Explorer 自己的 `editor_error {message, failures}`，与 native `status`、`sync_error`
  分开记录；不将已完成的 IO 改报失败。每个结果只保留首条 editor 诊断及已报告失败次数；诊断最多 4 KiB，超出用 `...`
  标示且不截断 UTF-8 字符，避免最近结果尾部保留任意大小的 plugin error。目录移动不保留无界 buffer 失败列表。
  含 editor_error 的结果同样进入上述 issue history，字节预算包含诊断文本；后续 129 个成功结果
  不能淘汰它，超出既有上限时计入 omitted。完成摘要与 Last results 单列 editor 同步未完成的 item 数，计数覆盖被省略的明细。

## 文件窗口与 LSP

从旧 Explorer 迁移时，以下行为需要调整使用习惯：

- Normal `y` 现在是 `mc` 的别名：同一已标记项再次使用相同 copy 用途会取消该项，不再是幂等 staging。
  例如无选区时在同一文件连续按两次 `y`，第二次取消标记；Visual `y` 仍将范围加入 copy 选区。
- 清理动作改用 `<Esc><Esc>`：copy/cut 时先取消用途并保留选区，普通 select 时清空选区。
  单次 `<Esc>` 可退出 Visual，不承担清空整个逻辑选区的动作。
- 原 `om` 的路径移动入口使用 Space menu；需要区分单项 Move to path 与多项 Move to directory。
- 批量打开保留 selection/mode；普通 `l` / `<CR>` 使用光标项，显式 `o<CR>`、split/tab 策略优先使用逻辑选区。
  `J` / `L` 先通过 window picker 选窗再 split 的能力继续保留。
- List 现在递归展示后代；目录选择表示逻辑子树，并可排除子项，不应再按当前可见行数推断操作源项。

- 打开复用 `dot.win.pick_sourcefile`，排除 Explorer、浮窗、固定 buffer 和其他非 sourcefile pane；单候选直接使用，
  多候选选择，无候选可新建垂直窗口。放弃选择保留原焦点。
  默认打开优先使用当前 tab 记住的源码窗口，`w` 明确通过 window picker 选窗；先替换目标 buffer，成功后再切换焦点，
  避免激活即将被替换的旧 buffer。加载失败保留原焦点及目标 buffer。
- Normal `l` / `<CR>` / 双击只打开捕获的光标文件，保留已有逻辑选区；Tree 目录仍切换展开，List 目录不执行。
  显式 `o<CR>` 有逻辑选区时打开所选文件，无选区时回退到光标项；其他显式窗口策略继续使用选区优先规则。
- 批量打开只确定一次目标 window，跳过目录，加载各文件并展示最后成功项；保留 selection/mode。
  支持水平 split、垂直 split、新 tab；移动光标不隐式预览或打开。
- 每次 Move/rename 使用 Filetree 移动准备握手：覆盖确认通过后，在首次 `workspace/willRenameFiles` 请求前检查目标 buffer，应用返回的 workspace edits；
  进入 IO 前始终检查当前目标 buffer；没有支持该请求的 client 时，只需这次最终检查，不重复完整 buffer 匹配。
  准备阶段的 buffer 检查只读，不删除占位 buffer 或触发其删除 callbacks；占位 buffer 的释放留到成功 IO 后的同步阶段。
  可释放的占位 buffer 不参与 IO 前 namespace 保护；其父路径在 Move 后变为文件等不可解析情形，不得阻断其他 buffer 的同步或后续 Move。
  可解析的源占位仍随源路径同步，只有接管目标名称时才按当前状态释放对应占位；loaded/listed/modified buffer 保持完整检查。
  Rust 复验 identity/physical paths 后执行 IO；成功结果才重命名 buffers、重选 LSP clients 并发送 `workspace/didRenameFiles`。
  取消后的迟到 response 不应用 edits。单 client 沿用 1 秒超时，无 edit 时继续；已应用 edits 不因后续 IO 失败自动回滚。
- Buffer 同步保留 bufnr、内容和 modified 状态，目录移动覆盖已打开后代；只解析父目录 alias，移动末尾 symlink 不重命名
  referent buffer。删除/回收文件保留对应 buffer。
  Windows physical path 在编辑器边界转换 verbatim drive/UNC 前缀并保留 UNC share root，preparation、buffer 匹配
  和完成通知使用同一套 Neovim 路径；native identity 校验仍使用原始 physical path。
- 改名留下的 unloaded、unlisted、未修改的占位 buffer 可释放；实际目标 buffer 冲突在 IO 前拒绝，目录移动同时检查已打开后代。
  目标预检查、buffer 同步与保存保护统一使用 `yoz.fs.path_suffix`，按 containing directory 的文件名规则逐级比较；
  APFS 覆盖大小写与 Unicode canonical equivalence，case-sensitive volume 保留大小写区别，Windows 尊重 directory case flag。
  APFS 的 Unicode 比较使用 macOS 内置 ICU 的 canonical normalization 与完整 case folding，包含 supplementary-plane 字母。
  通过 `yoz.fs.entry_path` 解析最深已存在的 parent 并保留 missing suffix，不假设 Neovim 已解析 missing parent 下的 alias；
  parent alias 变 dangling 后仍沿 link target 识别原 namespace，保留 buffer 同步及显式另存恢复；
  目标预检查同时逐级检查 buffer 原始路径的 ancestor entry，拒绝覆盖其依赖的 symlink 入口，遍历不得越过完整 UNC share root；
  无法解析的 parent 或 symlink loop 拒绝不确定的操作。每次同步匹配独立缓存路径解析，不跨 LSP 回复或 IO 复用。
  比较 entry namespace 而非 inode identity；后缀保留候选路径的原始组件，避免 NFC/NFD 字节长度差异截断路径。
  无法确定名称规则时在 IO 前拒绝；IO 后匹配失败则保留 buffer、报告目标 namespace 并保护原名。
  macOS 非 APFS 的潜在 Unicode 等价名报错，其他 Unix 使用 byte equality；不推断不支持的文件系统扩展规则。
  LSP 准备结束后再次检查冲突。IO 后才出现的冲突保留双方内容，记录 `b:filetree_move_target` 并报告待处理路径；
  在 buffer 名称恢复一致之前阻止向旧路径写入，不自动保存、覆盖用户 buffer 或改写 undo history。
  Buffer 匹配/改名失败、不可表示的路径、post-IO editor 异常及 LSP 拒收 rename 通知均记录为 editor 同步问题；
  后续异常不抹掉此前 buffer 失败的诊断与计数，也不重放已成功的文件操作。
  用户显式将该 buffer 改为其他路径后解除保存保护，允许另存其未保存内容。
  只改变旧路径的大小写或 Unicode spelling 不解除保护；向独立路径写出副本时保留旧路径保护。
  旧 parent 被文件占据而返回 `ENOTDIR` 时，允许向 parent 可解析的独立路径另存或改名恢复；其余解析失败仍保留保护。
  无法表示为 Neovim filepath 的结果仍可显示/清理，跳过依赖该 filepath 的编辑器动作。

## 装饰与订阅

- `dot.theme.hlgroup.explorer` 集中定义 `m_ex_*`、`m_fe_*` 与共享的 `m_ft_*`，遵循 theme loader 的 fallback。
- 普通行树形连接线保持与旧版一致的低亮度前景色；光标行与 Visual 范围使用独立 muted 前景色，保留行背景与普通行配色。
  横向滚动时裁掉屏幕外的线条。
- 图标和名称有独立 highlight range。特殊目录使用 `MiniIcons*`，普通目录图标用 `m_ft_dirname`，展开只改 glyph。
  Rosé Pine 普通目录沿用 subtle，ignored 图标使用 muted 对应的 `m_ex_ignored`。
  文件图标使用 Resource 的完整路径做 filetype detection，保留路径和大小写语义，不依赖仍然存在的 cwd。
  路径无法表示为 Neovim filepath 时，使用 display label 的名称/extension 表，并跳过自动 filetype detection。
- 图标与链接标识在 frame preparation 中准备，与正文和 annotations 同次发布；直接复用该 viewport 的行批次，
  不在 redraw callback 中查询 Resource、拼路径或执行 filetype detection。准备以 2 ms 为工作片预算，
  关闭、主题失效或目标变化后丢弃过期结果，不提交半份图标缓存。
  缓存只保留最近一次 viewport 准备涉及的节点及展示值，不持有另一份 Source；已经算完的纯图标值可用于
  取代旧计划的新 frame，显示中的行与图标仍只在发布时交换。Source revision 未变时复用已核对资源；
  revision 变化时检查节点的完整逻辑路径、类型与名称，未变的图标继续复用，离屏插入不能清空整屏缓存。
  祖先 rename 会改变后代路径；链接目标类型、目录加载完成和展开状态分别更新对应图标。
  滚动到冷范围时通过 Treeview 的装饰刷新补齐；ColorScheme 撤销旧准备资格并重算可见图标，不重写正文。
- 文件/目录名称共用 `m_ft_filename`；优先级为 ignored → error → warning → Git status → 中性色。
  Info/hint 不覆盖名称色，selection/copy/cut 用独立 sign，焦点用背景。
  Selection 使用 Nerd Font 勾选框，copy/cut 使用复制页与剪刀图标；self-only 使用半选框区分，
  copy/cut 的 self-only 在动作图标后附加半选框。标记区按显示宽度固定占位，右侧留空白容纳 glyph overhang。
- Diagnostics 按 E/W/H/I 显示非零分类，最多两类；Git 用具体变更字符与颜色表达状态，不额外显示 `S/U`。
  纯 staged 的 `A/M/R/C/T` 使用 staged 前景色；含 unstaged 的行按具体变更类型着色，删除与冲突始终保留各自颜色。
  装饰不写正文，不为聚合打开文件。
  Diagnostics 与 Git status 统一靠右显示，Git 名称色与 status 复用 `m_ft_git_*` 前景色，状态区保留当前行背景。
  Git 标记连续排列（如 `MDA`），与 diagnostics 之间保留一个空格；untracked 使用 ``，ignored 使用 ``。
- 文件链接、目录链接与 dangling link 在右侧独立显示 `  `，名称和 fileicon 保留各自语义。
  clean 使用 `m_ex_symlink`，Git 状态色按 ignored、冲突、删除、untracked、unstaged、staged 的优先级选择
  `m_ex_symlink_*`；主题生成 40% 紫色 + 60% 状态色，diagnostics 不覆盖链接标识的 Git 混色。
  图标和尾部留白共同叠加当前行背景；链接身份来自 Filetree Resource，不在绘制时探测文件系统。
  压缩目录链不跨越 symlink，普通后代不继承链接标识；链接目标出现、消失及同名替换通过资源刷新更新。
- 可见区域装饰使用 Neovim `on_range`，在 range 外校验 frame 与 viewport，再逐行写 ephemeral extmarks。
  不读取超出当前发布范围的 rows，关闭、发布中或已失步的 view 不绘制旧装饰。
- 订阅复用既有 Git status/ignore snapshots；diagnostics 按 namespace/buffer 替换。重连补齐停订阅期间的撤销；
  Busy 保留 pending 输入并延迟重试，手动 refresh 也重新同步 diagnostics。
  Ignore cache 失效独立触发可见路径预加载，完成后再提交 annotation 输入；后台 pane 再显示时按失效版本重新查询，
  不依赖 source/layout/viewport 变化。预加载期间释放最后一个 owner 后，迟到结果不得再次提交输入。
- Diagnostics/error/warning 前后跳转只查可见文件，Git 也可跳聚合目录，首尾循环。Find Files、Search Files、Find Explorer、
  Copy Path、Quickfix、File Info、System Open、Add to AI 调用现有能力；AI 动作只添加位置，不发送消息。
  Find Files/Find Explorer 使用光标目录或文件的父目录，Search Files 使用光标文件/目录，空树使用 display root。
  Copy Path、Quickfix、System Open 与 Normal Add to AI 使用完整逻辑源项，无选区时使用光标项，不递归枚举目录；
  Copy Path 保留 absolute/relative/filename 菜单与多路径换行，Quickfix 替换列表并以第 1 行第 1 列打开。
- File Info 只读取按键时捕获的 cursor Resource，不消费或修改逻辑选区，也不等待选区补载。
  Native details 保留资源 identity 校验；完成后在只读浮窗中显示路径、类型、易读大小、时间与权限。
  长路径转义控制字符并在屏幕范围内换行；`q` / `<Esc>` 关闭浮窗。
  原 view 关闭、首次失焦或新的 File Info 请求取代本次请求时，不显示迟到结果；失焦后返回原 view 也不恢复旧请求。

## 默认键位

| 按键 | 动作 |
| --- | --- |
| `h` / `l` / `<CR>` | 折叠/父目录；展开或打开 |
| `z` / `W` / `[i` / `]i` | 递归切换；全部折叠；父行；最后直接子项/兄弟 |
| `<BS>` / `.` / `gb` / `gc` / `gw` | 父 root；当前目录；上一 root；cwd；workspace |
| `t1` / `t2` / `t3` / `t4`、`H` | selected-only；Tree/List；压缩；隐藏项 |
| `<Tab>` / `ms` / `mc`（`y`）/ `mx` | select；select；copy；cut，同用途切换选中 |
| `<Esc><Esc>` | 先取消 copy/cut 并保留选区；普通 select 时清空选区 |
| `c` / `x` / `p` | 无选区时复制/移动到路径，有选区时标记 copy/cut；paste |
| `a` / `A` / `r` / `d` | 新建；新建目录；rename；delete/trash |
| `o<CR>` / `w` / `J`、`<C-x>` / `L`、`<C-v>` / `<C-t>` | 打开选区；选窗口；split；vsplit；tab |
| `[d`、`]d` / `[e`、`]e` / `[w`、`]w` / `[h`、`]h` | diagnostic；error；warning；Git 导航 |
| `of` / `os` / `oe` / `oc` / `oi` / `oo`、`O` / `<C-q>` / `oa` | 查找；搜索；目录；路径；详情；系统打开；quickfix；AI 位置 |
| `<Space>` / `R` / `?` / `q` | 动作和任务；刷新；帮助；关闭 pane |

Normal `<Space>` 使用 `nowait=false`，保留 `<leader>1` 等全局 leader 组合；单独按 Space 在 `timeoutlen`
后打开动作菜单（原生 Neovim 默认 300 ms）。其余 Explorer 自有绑定继续使用 `nowait=true`。
`?` 从当前 buffer 实际生效的 Normal/Visual 映射生成帮助，包含 Treeview 继承键位、刷新别名与本地覆盖；
相同按键和说明合并显示 modes，按键排序并省略重复的 Explorer/Treeview 前缀；不展示 which-key 内部前缀触发器。

## 退出协议

- 用户输入的退出命令及可判定的命令链在 `CmdlineLeave` 执行前拦截；仅关闭整个进程时询问，关闭一个 pane 不触发。
  默认 ZZ/ZQ 只在没有已有 mapping 时接入。
- 默认 Wait 取消本次退出，任务继续，结束后不自动退出。Cancel operations and exit 等 native 终态后重放原命令，
  仍经过 Neovim 未保存 buffer 检查；10 秒未停止则放弃本次退出，继续保留任务。
- `ExitPre`/`QuitPre` 抛错不能否决 Neovim 退出。直接脚本退出、自定义 mapping 或动态 Ex 执行可能绕过前置交互；
  `ExitPre` 必须取消并同步等到 native 终态，不能宣称此时仍能选择 Wait。强制终止进程不在可拦截范围。

## 验证

集成 specs 位于 `__test__/specs/era/m/explorer/`，native 状态测试在 `rust/yoz/src/ux/explorer/`。
Job、identity、watch、跨卷和性能由 Filetree/Treeview 对应测试覆盖；实际命令、结果及平台缺口统一记录在
[测试指南](../../../__test__/README.md)，不将编译通过当作平台 runtime 验收。
