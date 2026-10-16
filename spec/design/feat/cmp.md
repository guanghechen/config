# Completion

`era.keystroke.cmp` 接管本配置的补全行为。Neovim 和 Neovide 的入口调用 `setup()`；
VSCode、Yozvim、Yuivim 继续由 host 管理补全。核心在第一次使用时加载。

## 边界与状态归属

- `session` 管理请求、候选、选择、resolve 和编辑生命周期；source 返回结果，UI 消费快照。
- `context` 只捕获 editor input 的 bufnr、winnr、输入文本、cursor、changedtick、buffer version 和原 modified 状态。
  Insert/Select 共用这些字段；cmdline 完全由原生完成，不创建 Context 或进入 source/ranking/edit pipeline。
  切换窗口、离开输入、进入嵌套 cmdline，以及输入区域以外的 buffer 变更会使旧结果失效。
  reload/detach 同步使旧请求和编辑资格失效，窗口清理延后并检查 session epoch。
  buffer version 不复用；同 buffer 的 `:edit!` 后恢复监听，buffer-local mapping 的 fallback 保留到 wipeout。
  后台 buffer 的修改使自身版本失效，只在事件所属 buffer 与 session 一致时取消当前操作。
- `edit` 负责补全写入。内部 range 使用零基 UTF-8 byte offset；LSP range 按 client encoding 转换。
  filter range 与 text-edit range 分开，避免把 LSP 或命令表达式的 namespace 当作筛选词。
  LSP 的 `filterText`（缺省时为 label）以 edit start 到 keyword start 的已输入前缀开头时，
  才将该前缀纳入 query。完整复合缩写因此保留匹配优先级，suffix alternatives 仍按 keyword 匹配。
- `menu` 将已排序候选交给 `complete()`；Neovim 持有 PUM、border、scrollbar、选择和 prefix preview。
  `completeopt` 的 `fuzzy` 提供非连续匹配高亮，`nosort` 保留 Rust 排序。
  `equal`、`dup` 保留 typo、filterText-only 候选与 LSP alternatives，`user_data` 只携带本轮菜单身份和索引。
  原生 leader 使用各候选 filter query 的公共后缀；宽 LSP edit 不把无关 namespace 加入高亮 query。
  宽 edit 的静态前缀若保留 leader 之前的原文，只预览其后缀；否则保持已输入 query，接受时执行完整替换。
  deprecated label 只叠加删除线等文字装饰，继承原生菜单的匹配色和选中背景。
  `nvim_select_popupmenu_item()` 在后续输入循环执行；`CompleteChanged` 确认选择。
  Native prefix preview 不删除光标后的 suffix；snippet 使用 native parser 提取静态插入前缀，展示 label 独立保留。
  只为已展示候选缓存静态前缀，不在收集或绘制时求值动态变量；动态前缀使用 label 的前缀，最终接受仍应用完整 LSP edit plan。
  `on_bytes` 追踪 native prefix 的实际范围，范围外编辑同步取消排队的插入。
  接受按键直接关闭菜单、确认 owner 并恢复 prefix preview，随后执行编辑事务；已 resolve 的候选先于排队输入写入。
  直接通过原生 API 接受时，`CompleteDone` 核对完整 native 结果与 owner 后才恢复前缀及原 `modified` 状态。
  未 resolve 的候选继续等待可取消的 resolve；
  迟到结果不得回滚后续输入。Repeat 在 native 已记录的文字上补录剩余编辑，空候选列表结束记录，无 synthetic end key。
  部分 source 更新先让 native 恢复 preview，再重建候选；光标在 query 内移动时沿用原生菜单关闭行为。
  `WinScrolled`、`WinResized`、`VimResized` 通过无插入的重选刷新 native 位置，不查询 source 或重排候选；
  文档保持阅读位置，signature 的位置刷新独立于菜单。
  文档通过 `nvim__complete_set()` 使用原生 info popup；Neovim 持有窗口、buffer、位置与生命周期。
  原生按可用空间选择左右位置和宽度，空间不足时隐藏；本地只设置样式并限制最多 20 行。
  Markdown conceal 生效后使用 `nvim_win_text_height()` 测量显示高度，不维护高度缓存。
  原生 resize 会隐藏动态 info，因此重新发布当前内容并恢复阅读位置；不维护自绘定位或第二份几何状态。
  signature 直接显示当前 label，保留一个独立浮窗及原生折行测量；不生成 Markdown 围栏或启动 parser。
- `cmdline` 使用 `wildtrigger()`；`:` 对实际文字修改自动触发，`/`、`?`、`@` 保持手动，嵌套 `=` 不介入。
  搜索保留 private-buffer 准入，其匹配、排序和单项自动接受采用 Neovim 原生语义，不再经过 buffer source 或 Rust ranking。
  自定义命令 provider 负责返回完整候选和过滤，不再推断或拼接 argument prefix；文件名与 PATH 处理也交给原生。
  Dressing 只接管 cmdline/messages，`_cmdline_offset` 将原生 PUM 锚定在浮动 cmdline，层级低于原生 PUM 的 250。
  自动补全延后至 UI 注册 anchor 后执行；选择、接受、取消产生的文字变化不重新触发自动补全。
  每次触发按当前 cmdtype 设置 `wildmode`，嵌套输入不会把内层的自动插入策略带到外层 `:`。
- `yoz.completion.Snapshot` 持有不可变的匹配与排序 metadata；Lua 保留 LSP payload 和 editor state。
  Rust 完成 fuzzy、加权评分、去重和全局 top-200，Lua 只取回最终候选。
  `dot.context.frecency.completions` 持有唯一的 native `History`；capability negotiation 仍由 `era.m.lsp` 负责。
  capabilities 以最新 Neovim 的 defaults 为起点，只追加实际差异；不通过通用 `before_init` 重复开启 snippet support。
  server 专属能力在各自 LSP config 构造一次；包含实际初始化工作的 hook 继续保留。
  不注册空的公共 `on_init`；纯转发的 attach/detach 直接引用统一事件函数。
  rust-analyzer 使用默认的无上限 completion response，避免 server 在客户端筛选前截掉 auto-import；菜单仍由统一 top-200 限制。
  LuaLS 关闭 `completion.showWord`，普通词统一由 buffer source 提供；避免 server 的 Text 候选阻止跨 buffer fallback。
- [Winline LSP 面包屑](lsp-symbols.md)在发出请求时直接以 `pumvisible()` 和当前 source window 判断是否跳过，不维护跨层 visibility flag。

## 请求与缓存

取消句柄尽力停止底层请求；epoch 和 owner 检查决定结果能否发布。取消不等于服务器不会回调。
每个 source 独立发布结果，迟到结果保留显式选择的候选身份，而不是沿用列表下标。
输入事件立即失效旧发布、resolve 和接受操作；`cancel(true)` 可保留当前传输，但清除排队的旧 query，
避免在新 context 尚未捕获时续发过期位置。取消句柄保留到下一次 update 或 hide，其他 source 可直接取消。
Update 先建立新订阅，再取消旧订阅。LSP 每个 client 最多保留一个进行中的请求和最新输入，
兼容输入接替 callback；旧取消句柄只能停止仍归其所有的请求。Manual、不兼容输入、source 退出和显式隐藏真正取消传输。
响应与原始请求的 context 绑定，只有新 query 扩展该前缀时才发布或复用；incomplete 或退格扩大范围时只续发最新请求。
各 client 分别完成和发布，不等待最慢 client。已取消传输的响应不得更新 cache。
所有 completion RPC（含 incomplete 与 timeout 续发）通过当前 slot 的同步 dispatch 提交。
Session 先验证 ownership；若 buffer 中仍是本 session 的 native preview，恢复逻辑输入后才调用
`Client:request()`，使其 flush 的文档与 response context 一致，随后恢复有效的选择和 preview。
关闭 native menu 会同步触发 `CompleteDone`；恢复输入前再次校验 epoch，调用方失去 ownership 后
立即停止，不能继续写 buffer、提交请求或清理新 owner 的 preview/状态。
旧 slot 或恢复过程中失去 ownership 的请求不发送，也不阻塞后续输入重新请求。

LSP completion 按所需字段读取 JSON null 为缺省，不逐项扫描整个 payload。
`Item.optional()` 仅转换协议的 null；调用方相信字段的声明类型，不重复做 runtime type 探测。
列表 defaults 与选中项的 resolve 归一化已知 optional protocol fields，
只在字段变化或应用 defaults 时浅复制对应 record，不修改 server payload。
opaque `data`、command arguments 和未知扩展字段保留原始 null；显式 `data: null` 不继承列表默认值。
`Item.new()` 只构造候选；LSP source 负责 label 与当前行 range 的准入，编辑边界负责写入前的有效性校验。
resolve 先归一化再合并，缺省字段不覆盖原始编辑信息；nullable capability 不授予 trigger 或 resolve 能力。
LuaLS 选中项的 Markdown 若以包含 detail 的完整 Lua fenced block 开头，将该签名提升为 detail，
剩余说明交给文档窗口；仅浅复制发生变化的 records，其他 server、plaintext 和不完整代码块不处理。
accept、snippet 和 documentation 共用插入文本读取规则：
缺省或 null 的 `insertText` 回退到 label；已提供的 `textEdit` 必须包含有效的 `newText`。

完整候选列表可在同一输入范围内随前缀增长复用；退格后仍扩展原请求前缀时也可复用。LSP cache 按 client 分开，`isIncomplete`
控制重新请求；null/error 结果允许重试。`manual=true` 统一为 manual context，强制所有本轮准入的 source
重新查询；source 内部仍可复用有效的扫描缓存，buffer fallback 的准入关系不变。删除、改变目录、改变输入范围
或外部修改 buffer 都不能沿用不兼容的列表。未变化的候选集保留 Rust snapshot。
单 client 的完整 LSP cache 保留同一个 items 数组，避免每次输入复制和逐项比较整个列表。
等待新响应时继续筛选兼容的旧候选；它只用于临时展示，不改变 source 的 incomplete 状态。
退格扩大 query 时也保留逐项通过 Rank/Edit context 检查的临时候选，不把旧列表视为完整响应。
新响应替换旧候选，同一轮收到的多个 source 回调合并刷新，避免反复排序和绘制。
LSP response 的 `pending` 表示仍在等待 client 或最新 query 的响应，与 server 的 `isIncomplete` 分开。
请求超过 2 s 时发布可启用 fallback 的临时结果；当前 query 没变时保留迟到响应的 ownership，
已有新 query 排队则取消卡住的请求并发送最新 query。超时后继续输入也会重新请求，取消与完成都会关闭 timer。

每个 source slot 独立保留最近已准备的 items 与 snapshot，不以当前请求是否已收到 response 判断其存在。
Sources 由入口固定组装，policy 与候选引用已注册的 source；各 adapter 处理可恢复的 I/O 失败，内部程序错误直接向上传播。
兼容输入中的新 slot 继承这份计算缓存；即使连续输入跳过多个旧 callback，也不重新构建同一候选集。
新响应只有 items 成员及顺序一致时才能复用 snapshot。source 发布后的 items 数组不再就地修改，
更新时返回新数组；候选的匹配、排序、身份或 context 字段变化须发布新的 Item。
这份缓存不授予显示或接受资格：临时展示仍检查 context，响应仍检查 epoch、slot owner 与当前输入。
显式隐藏、取消、source 退出或不兼容输入会释放对应的已准备记录，每个 source 只保留最近一份。
原生 `CompleteDone(discard)` 可能先于 Backspace 修改文本；已开始的输入或 Backspace 只结束展示，
保留 source snapshots 与取消句柄交给后续 text event。其他原生 discard（如 `<C-x>`、清空菜单或其他 completion 接管）立即释放请求。
Session 持有 `on_bytes` 的范围判断；逻辑 context 清空后，最后的 input observation 保持到整批按键的 text event 到达。
连续退格及随后重打不改变输入范围时，不失效完整 LSP cache 或重建相同 snapshot；这不放宽发布或接受的 ownership 检查。

LSP 文档首次延迟 200 ms resolve；窗口已经打开时，切换候选延迟 50 ms 更新并回到文档顶部。
接受时优先使用已 resolve 的 item，否则等待最多 100 ms；
超时使用原始 item。等待期间输入、window、buffer 或 mode 变化时放弃接受，避免迟到编辑。
signature 只显示当前 overload，直接把 UTF-16 range 或字符串 parameter label 转换为高亮位置；
支持跨行 label 和行末边界，retrigger 仍携带完整、未修改的 response。
手动 signature 请求使用 `Invoked`；自动请求按各 client 的 trigger/retrigger characters 判断，
仅 `TriggerCharacter` 携带字符，已显示 signature 的其他更新使用 `ContentChange`。
retrigger characters 仅在 signature 已显示时生效；字符串 parameter label 的高亮以响应 client 的 trigger characters 定位。

## 触发

事件入口区分进入 Insert、实际输入、退格、光标移动、其他文本变化和接受。
同一按键产生的 CursorMoved/TextChanged 通知不能覆盖真正的触发原因。
policy 接收 session 当前的 context；光标移动只维持已有查询范围，手动隐藏后不会靠移动重新打开。

进入已有单词不自动弹菜单；位于合法 trigger character 后进入 Insert 时可以触发。
普通输入排除空格、换行和 Tab；进入 Insert 或接受候选时额外排除引号和 `(`、`{`、`[`。
这些限制用于自动触发，手动 show 仍可查询。退格会重新查询，包括空前缀和空格前缀；
`C-w` 等删除操作不会被当作退格。关键词保留内部连字符，查询范围包含光标后的词尾。
接受目录分隔符、成员访问符等合法 trigger character 后继续补全。

Cmdline 使用独立的 trigger characters，包括空格；仅进入 `:` 不弹列表。
`/`、`?` 的菜单保持手动触发。进入、移动和隐藏遵循同一会话边界，嵌套 cmdline 按层级隔离。

## 编辑与输入

初次展示预选第一项但不写入；用户导航候选时插入可撤销的 preview。列表刷新先恢复 preview，
按逻辑输入排序，再恢复同一选择。继续输入会把 preview 变为普通输入；取消只恢复仍归本 session
所有、且没有被用户修改的 preview。普通 hide 保留已插入的文本。
上下导航在首尾之间经过无选择状态；无选择时接受第一项。
菜单显示 label、可选的 `labelDetails.detail` 与 description，宽度、截断、选择色和滚动条由原生 PUM 绘制。
Rust 负责候选匹配和排序；菜单不再另算 matcher 高亮。

接受前校验 range、overlap 和 snippet。main edit 与 additionalTextEdits 使用同一坐标快照；
重复的最终 `$0` 以及冲突的 placeholder 在任何写入前被拒绝。
允许 range 边界上的零长度 insertion，同起点时先按结束位置排序再判定 overlap。
`endofline=true` 时允许附加编辑使用 `{ line = line_count, character = 0 }` 的合法 EOF 坐标；
EOF 空行之外的位置继续在写入前拒绝。
extmark 追踪主编辑结束位置及 import 位移；snippet 的空 main edit 将其留在展开位置。
编辑直接使用最新 Neovim 的 `apply_text_edits()`，由其保留 source buffer 的 `buflisted` 状态。
接受后执行关联 LSP command，并记录 frecency。
LSP 每项以 client ID 与 response 内的返回位置生成短的 native 去重 key，
不能按 label 或插入文本合并不同的 additionalTextEdits、command 和 opaque data。
一次聚合只包含每个 client 的一份 response；key 可在后续 response 中复用，请求隔离仍由 session ownership 保证。
显式选择跟随 LSP Item 对象；复用已发布的 Item 时，迟到 client 的聚合结果可以继续追踪原选择。
全新 response 不借用旧项的选择身份，包括等待期间已选中的旧候选。
frecency 继续以当前 filetype、source、稳定的 client name 和候选内容标识历史，
保证语言服务器重启后仍能复用接受记录；同内容的 LSP alternatives 继续共享这份偏好。
Item 一次拼接历史 key，避免先创建内容 identity；原有字节格式及未指定 ID 时的 fallback 保持不变。
`setup()` 注册 `editor.action.triggerSuggest` 与 `editor.action.triggerParameterHints` 的 client handlers，
分别手动请求补全与 signature。它们仅作用于 command 指定的当前 buffer、Insert 模式及补全准入范围。
接受历史保留 MD5 key 与 `MAX_TIMESTAMPS / timestamps / idx` ring 的持久化格式，
native `load()` 完整验证输入后替换状态，失败时保留原记录。snapshot 构建时预计算 history digest，
每次 rank 只取一次当前时间，避免每个命中候选都跨 Lua/Rust 边界计算 MD5 和读取时钟。
ring 的累计基分只在 load/access 时重算，查询只计算最后一次接受至当前的衰减；不增加持久化字段。
保留的时间按接受顺序重放：先以 `(1 + elapsed_seconds)^-0.2` 衰减，再为本次接受增加 4 分；
查询时再次衰减并四舍五入，最多加 6 分，空 query 也使用历史。时钟回退时 elapsed 按 0 处理。
存储仍按 workspace/filetype/client/content 隔离，默认只保留最近 10 次接受；这与 Blink 的全局累计历史仍有区别。
filetype 改变会使旧 snapshot 失去准入资格。文件访问历史继续由 `stl.c.Frecency` 管理。
保留独立 undo boundary，支持 Unicode 和括号内 cursor 的 dot repeat。
多行 plain-text 的接受、cursor 位置及 undo 已验证；dot repeat 尚不能保留多行结构。
repeat 的 scratch-completion 技术参考 Blink，许可位于模块的 `LICENSE.blink`。

Snippet 展开与跳转使用 `vim.snippet`。常用文件、workspace、时间、注释和 register variables
在选择或接受时展开并按逻辑输入缓存，支持 placeholder 内的变量；收集候选不读取 register。
文档中的 snippet preview 复用这份展开结果，与输入预览及接受保持一致；显式 LSP detail 仍优先显示。
预览/detail 与说明均有内容时显示分隔线；横线随窗口宽度裁剪，不写入文档正文。
说明开头的 Markdown 分隔线与该边界合并；plaintext 中的分隔线、强调和反引号保持字面内容。
文档滚动交给原生 `smoothscroll` 与行滚动命令，长段落可以按显示行滚动，输入光标保持不变。
非 Snippet kind 的单行纯文本即使标为 snippet format，也按普通文本接受，保留已有括号的光标移动
与 Tab fallback，undo boundary 仍由原始 format 决定；
真实 placeholder、变量、多行内容和 snippet kind 继续使用 snippet 展开。
转义后的 `$` 保留为 literal。自动括号沿用旧 Blink 的固定 filetype blocklist、语言括号对与
import、except、pseudo-selector 限制，kind 与 semantic token resolution 共用这些规则。
优先使用 kind；需要 semantic tokens 时只接受原 client、原 buffer 和未变化的输入。
`blink.pairs` 独立处理键入括号与配对高亮。

`Tab` 依次处理菜单、snippet、inline completion、原按键；`C-y` / `C-l` 优先 inline completion。
保留 `C-j` / `C-k` 的 mapping fallback、数字选取、文档滚动及 signature 切换。
Insert 与 cmdline 分别对接 Session 和 native command completion；无相应动作时转交原 mapping/原按键。
`C-j` / `C-k` 的 mappings-only fallback 仅用于补全已准入的 context，禁用时保留原生换行、
digraph 与嵌套表达式寄存器的确认行为。
`C-p` 在 signature 窗口关闭时请求 signature，即使没有可用 server 也消费按键，避免进入原生补全。
Cmdline 中 Tab / S-Tab 在已显示的单候选时直接接受，其他时候沿各自方向选择或触发原生补全。
`C-e` 恢复 native preview，`End` 隐藏菜单后执行原按键；不维护独立 ghost 窗口。
搜索菜单未显示时，`C-y` 使用原按键 fallback，不能接受后台缓存的候选。
cmdline mappings 使用 `silent=false` 保持 incsearch 更新；fallback 插入未处理按键之前，保持输入顺序。
没有补全或 snippet 动作时，Tab 同样经过统一 fallback，保留原 mapping 和已排队的输入顺序。

保留五处相对于旧 Blink 的正确性修正：snippet 的最终 `$0` 位置不提前一字符；
取消后紧随的输入不丢失；接受后紧随的 Enter 执行已接受的命令文本；
同起点 auto-import 的 snippet 在 import 之后展开，光标跟随实际展开位置；
禁用补全的嵌套表达式寄存器保留原生 digraph 和确认按键。

## Sources 与排序

保留代码、Markdown/notepad、finder/searcher 的 source 分配，以及 buffer/filetype 准入规则。
buffer 是 LSP 与普通 path 的 fallback：请求中的 primary source 都返回空结果后才请求 buffer；
任一 primary 出现候选就撤销 buffer 的请求、展示和 preview 资格，迟到 callback 不能重新发布。
policy 在请求前区分 `path` / `path_at` 并声明 buffer 的 primary 依赖；
`path_at` 独立于该 fallback 关系，扫描仍 pending 时也不阻塞 buffer；Insert 场景没有 primary source 时直接请求 buffer。
路径 source 共用异步目录扫描，`@` 使用 workspace cwd，普通路径使用当前文件目录。
普通路径以 `/` 或 `\` 分隔符准入；引号只保留路径中的空格，不能单独将普通字符串升级为路径。
workspace `@` 与 finder 仍允许裸 basename，普通字符串继续使用既定的 buffer fallback。
扫描按批让出主线程，取消底层排队请求，2 s 超时返回不完整结果；在排序前不截断目录候选。
路径 token、基准目录和环境展开值须为有效 UTF-8；无法表示的目标跳过路径请求。
目录扫描在 join/stat 前排除非法 UTF-8 名称，包括 symlink 和未知类型，其他条目继续参与补全。
读取路径文档前异步确认当前目标是普通文件；FIFO、socket、device 和目录只作为路径候选。
判定不沿用目录扫描时的类型，避免扫描后替换目标导致阻塞读取。
buffer source 按 tab 顺序选取至多 10 个准入 buffer；无效、未加载、非普通、private 或超限 buffer
不占数量额度。单个 buffer 小于 131072 bytes，总大小不超过 500000 bytes。
缓存记录每行词表与词的引用计数；无词行共享只读空词表，空行不分配独立词表。
tick 与 `iskeyword` 未变化且无 pending edits 时直接复用缓存，不遍历行索引。
`on_lines` 只记录变更范围，请求时重扫受影响的行；reload、`iskeyword` 变化及过长的积压日志重建缓存。
默认 `iskeyword` 下的纯 ASCII 行使用等价的快速分词，Unicode、自定义规则与 NUL 行使用 Vim regex。
regex 沿 buffer line 的 byte offset 前进，不为每个词复制剩余字符串，NUL 边界保持原有语义。
buffer 词条必须是有效 UTF-8；含原始非法字节的词条被跳过，同一行的其他合法词条仍然可用。
校验使用 `yoz.string.is_utf8`，正常文本按行校验，含非法字节时才逐词检查。

`friendly-snippets` 作为数据依赖按需加载；本地和 package.json snippets 按 filetype 缓存。
词典继续使用 `yoz.dict.search`，slash commands 保留独立 edit range。

Cmdline 候选、Lua namespace、option/custom-command prefix、文件转义和 PATH 扫描均由 Neovim 原生补全处理。
`:` 自动显示，`/`、`?`、`@` 由按键触发；不经过 Insert sources，也不维护 ghost text 或临时改写 PATH。

Lua 按 filter start 分组，并为每组的 `(origin context, edit start)` 建立 region。
准备阶段以列数组一次传入 label、filter、sort text、ID、history key、offset、deprecated 和 region，
filetype 按 region 传递。Rust 校验各列长度与 region 后构建不可变 snapshot，不直接读取 Lua 的 LSP payload。
label、filter、sort text 与 filetype 使用 UTF-8；ID 与 history key 保留 opaque bytes。
ID 用于 byte 去重，history key 按原始 bytes 与 filetype namespace 计算 MD5；合法 query 的编辑前缀
可以包含原始字节，不因此丢弃候选。结构、region 与 finite offset 校验保持不变。
snapshot 预计算 ID 的去重 hash；query 使用固定大小的 hash key，碰撞时仍比较原始 bytes。
查询时只校验这些 region，向 Rust 传 snapshot、query 和 eligibility mask；候选自身不逐项跨边界。
非法 UTF-8 query 所属的 group 本轮不参与匹配，其他 group 仍保留；输入恢复有效后可继续使用 snapshot。
Rust 先检查 region 准入和 fuzzy matching，再按原分组及候选顺序去重，首个合格且匹配的 ID 生效。
context、epoch 和 slot owner 的最终发布及接受检查仍在 Lua 中，不由 native snapshot 授权。

最终 score 为 fuzzy score + source offset + frecency（上限 6）+ proximity（2）− deprecated penalty（2）。
proximity 在读取附近文本前检查 10 KB 预算；native 预建 byte-pair 集合排除不可能的 substring，
仍使用完整 literal matching 确认命中，非法 UTF-8 边界不能被跨越。
空 query 不加 proximity，frecency 与 deprecated penalty 仍然生效。
按 score 降序、可选 sortText 升序排列；缺失 sortText 排在显式值之前，同分同 key 保留 source/group 与候选顺序。
Lua 列数组以 `false` 表示缺失 sortText，不用 label 补齐。source 按 policy 顺序合并，展示最多 200 项。
Rust 在所有 source 上使用同一个 bounded heap，结果与加权后全量排序再截取一致；
不能先按各 source 的 fuzzy score 截断。只返回最多 200 个 group/index/score，Lua 映射回原 Item。

实现位于现有 `yoz` crate：`completion.rs` 处理 Lua binding，`completion/rank.rs` 管理 snapshot 和排序，
`completion/history.rs` 管理接受历史，`completion/fuzzy.rs` 独立实现 fuzzy，SIMD kernels 放在其子目录。
fuzzy 支持 Unicode subsequence 与 bounded typo，优先连续、边界和完整前缀匹配。
相同 ASCII 大小写的匹配增加 4 分，原大小写位与边界 bonus 共用已缓存的 byte metadata；
scalar 与两种 SIMD 路径使用相同规则。匹配仍不区分大小写，大小写只影响偏好。
纯 ASCII 候选按 byte 构建 lowercase 字符与 boundary/case metadata，省去 Unicode 分类和展开迭代；
含非 ASCII 字符的候选沿用 Unicode 路径，两者保持相同的 metadata 布局与评分语义。
独立 `Matcher` 的高亮接口复用 scalar 评分的 traceback，支持 typo 和原始 Unicode byte ranges；
生产 rank 不保留 traceback。高亮 score table 限于 4 MiB，超过预算的长 label 仍参与排序但不计算高亮。
独立 `Matcher` 的数组及 packed 查询接口保留用于算法差分和基准，不参与 completion 的生产排序路径。
x86_64 上按运行时 AVX2 检测加速 typo DP；字符比较仍使用完整 Unicode code point，分数与标量实现一致。
短标签和长标签按各自的数值边界选择计算路径，其他 CPU 使用标量路径。
128 个 codepoints 以内允许 `min(2, floor(query_codepoints / 4))` 处 typo；codepoints 按 Unicode lowercase 展开后计算。
更长的 query 使用线性前缀匹配，保留 exact、大小写与边界加分，高亮直接映射前缀的原始 UTF-8 ranges；
不再因长度丢弃 exact/prefix 候选，也不对长 query 运行 fuzzy/typo DP。
这是本配置的排序规则，不保证与 Blink 的 score 或顺序相同。

## 验证入口

```sh
nvim -l __test__/run.lua era/keystroke/cmp/
cargo test --offline --manifest-path rust/Cargo.toml -p yoz completion:: --lib
```

Lua specs 使用独立 Neovim 进程验证输入、preview、LSP 编辑、取消、undo/dot repeat、
snippet、sources 与原生 UI；Rust 单测保留 scalar/SIMD、排序和历史的独立 oracle。
普通回归不依赖 Blink、benchmark runner 或生成结果；真实 server fixtures 使用生产配置和已有 executable。
完整命令见 [test README](../../../__test__/README.md)，具体失败定位见[行为指南](../../debug/cmp-behavior.md)。
