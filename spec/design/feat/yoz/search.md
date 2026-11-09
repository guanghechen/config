# Yoz Search 设计

## 职责边界

`yoz.search` 负责文件遍历、匹配、取消检查与 native job state，不依赖 Neovim，worker thread 不调用 Lua。
`era.m.searcher` 负责 debounce、request generation、polling、结果发布与 UI 生命周期：

```text
composer -> Lua file-search controller -> Rust job -> controller -> composer
```

同步 `search_in_files` 保留为兼容入口与语义基准。未取消的请求必须在后台 API 中得到相同、顺序一致的结果。

## 匹配与替换语义

- 文件搜索与替换在整段文本上匹配：`.` 匹配换行；正则模式按行解析 `^`/`$`，`\r\n` 算一个行尾，
  `$` 在 `\r` 之前匹配，`^` 也在单独的 `\r` 之后匹配；跨行模式可以写 `\n` 或 `\r\n`。
  结果中的匹配范围同样取自整段文本上的匹配，与替换一致：`foo\s*$` 不包含其后的换行。
- buffer 搜索按行匹配，`.` 与 `\s` 不跨行；模式文本含有真实换行字符时，才在以 `\n` 连接的整段 buffer 上匹配。
  行号与列按 buffer 的行计：行内的 `\r` 是字符，不断行；行尾单个 `\r`（以 unix 格式读入的 CRLF 文件）不计入该行的匹配内容。
  buffer 替换按同样的规则展开列出的每个 match，捕获组取自 match 在原行中的那次匹配；只改写 match 所在的范围，
  其他位置的 mark 与 extmark 不动。搜索后 buffer 有过改动时，替换先重新搜索并提示，不按旧位置写入；
  替换预览也先重新搜索再显示。
- 文件开头的 UTF-8 BOM 不属于正文：文件搜索的行列与 offset 从 BOM 之后算起，与 Neovim 读入后的 buffer 一致；
  替换与替换预览按同样的正文匹配，写回时保留 BOM。
- 搜索不列出空匹配，替换也不改动空匹配。
- 替换只处理 UTF-8 文本。能匹配 UTF-8 以外字节的模式（如 `(?-u:\xFF)`）只用于搜索：替换模式下首次发布其结果时提示一次原因，
  修改替换串不再提示；结果行与预览不显示替换，替换操作拒绝执行。非 UTF-8 文件（包括 UTF-16）仍可搜索，结果行与预览
  按只搜索的样式显示，替换时报告 `not UTF-8 text` 并保持文件不变。文件搜索按读到的原始字节为每个文件给出 `utf8`，
  与替换读文件的规则一致；搜索停在有匹配的文件中间时（如到达 match limit），读完该文件再判断。
- 替换串只识别 `$n`、`$nn` 与 `$$`，规则同 JavaScript：`$nn` 在第 nn 组存在时取该组，否则按 `$n` 后接一个数字；
  未参与匹配的组展开为空，不存在的组与其他 `$` 写法保留字面量，捕获内容不再二次展开。

## 结果类型

以下用 TypeScript 描述主要结果结构；完整 Lua API 类型见
[search.lua](../../../../lua/__types__/yoz/search.lua)。

```typescript
export interface ITextRange {
  readonly lx: number // 1-based start line
  readonly ly: number // 1-based end line
  readonly cx: number // 0-based start byte column
  readonly cy: number // 0-based inclusive end byte column
  readonly ox: number // 0-based start byte offset in source text
  readonly oy: number // 0-based inclusive end byte offset in source text
}

export interface ITextMatch extends ITextRange {
  readonly s: string // Preview text with line endings rendered as ↲
  readonly sx: number // Byte offset in s of the first matched character
  readonly sy: number // Byte offset in s of the last matched character
}

export interface IFileMatch {
  readonly p: string // relative filepath
  readonly utf8: boolean // Whether the file is UTF-8 text, a leading BOM aside: the only text replacement takes
  readonly size: number // Size of the file as searched
  readonly mtime_sec: number // Modification time of the file as searched, as stat gives it
  readonly mtime_nsec: number
  readonly matches: ITextMatch[]
}

// This result is for the search_in_files* api.
export interface ISearchFileResult {
  readonly items: IFileMatch[]
  readonly elapsed_time: number // milliseconds
  // True when traversal stopped at max_matches before exhaustiveness was established.
  readonly limit_reached: boolean
}

export interface ISearchInLinesMatchPoint {
  readonly l: number
  readonly r: number
}

export interface ISearchInLinesLineMatch {
  readonly lnum: number
  readonly score: number
  readonly matches: ISearchInLinesMatchPoint[]
}

// This result is for the search_in_lines* / search_in_text api.
export interface ISearchTextResult {
  readonly matches: ITextMatch[]
  readonly lines: ISearchInLinesLineMatch[]
  readonly elapsed_time: number // milliseconds
}

// This result is for the locate_in_lines api.
export interface ITextRangesResult {
  readonly matches: ITextRange[]
  readonly elapsed_time: number // milliseconds
}
```

`locate_in_lines` 与 `search_in_lines` 搜索相同，只返回每个 match 的位置，供 buffer 搜索与 picker 的 regex 过滤使用。32k 个匹配时，
`search_in_lines` 一次调用约 132 ms，原生搜索与行文本传入约 6 ms，其余是预览与逐行匹配转成 Lua table；
只转换位置约 22 ms。

`ITextMatch` 的行号从 1 开始，列与 source offset 按 byte 从 0 开始；`cy/oy` 包含最后一个匹配 byte。
`sx/sy` 指向预览中匹配首尾字符的起始 byte，不是 end-exclusive 范围。
CR、LF、CRLF 在预览中显示为 `↲`，该字符占 3 个 UTF-8 bytes，因此预览坐标不能直接用于原文替换。
替换模式的结果行把匹配片段里的 `↲` 按匹配的原始字节数还原为 LF 或 CRLF 再算替换；片段字节数等于原始字节数时
不含换行，其中的 `↲` 是字符本身。跨行且含字面 `↲` 的匹配无法区分两者，结果行的替换预览可能不准，实际替换不受影响。

File search 的预览在匹配前后最多各扩展 64 bytes，并限制在匹配首尾行内。
单行匹配不包含行尾时不附加该行的换行；其他范围的 raw preview 可能保留尾部 `↲`。

## 后台 Search job

### Lua API

```lua
local job = yoz.search.start_search_in_files(options)

local status, result, err = job:poll()
-- status: "running" | "completed" | "cancelled" | "failed"

job:cancel()
job:dispose()
```

`start_search_in_files` 将 Lua options 转为 Rust owned data；在启动 worker 前，将缺失、空或相对 `cwd`
按调用时的当前目录解析。Options 转换和 thread spawn 失败以 Lua error 返回，由 controller 捕获，
仅对仍有效的当前请求报告一次。

Worker 不持有 `Lua`、`LuaTable`、callback 或 `vim.*` value，通过 one-shot channel 返回一个 terminal outcome：

```text
Completed(ISearchFileResult) | Cancelled | Failed(ISearchFailedResult)
```

Job 缓存 terminal outcome。`poll()` 可重复读取，不消费 payload，因此 Lua allocation/conversion
错误不会丢失 terminal state。Controller 在首次成功读取 terminal outcome 后 dispose job。

### 生命周期

- `cancel()` 幂等，只请求 cooperative cancellation。Job 保持 `running`，直到 worker 返回 terminal
  acknowledgement；terminal 后调用无副作用。
- `dispose()` 幂等、非阻塞：标记 disposed、请求取消、丢弃 receiver，不 join worker。
  Disposed job 的其他方法调用视为误用并报错。
- `Drop` 请求取消只用于泄漏兜底，正常生命周期必须显式清理。
- Channel 断开或 worker panic 转为缓存的 `failed` outcome，不得永久停留在 `running`。

## 取消契约

取消使用 `Arc<AtomicBool>`，在 setup、目录 entry、file boundary、读取 chunk 之间、match sink
及 terminal publication 前检查。

支持取消的 reader 返回有类型且不可重试的 sentinel error，不使用会被标准 reader 重试的
`io::ErrorKind::Interrupted`，避免取消后空转。请求已取消时，取消优先于该请求观察到的普通 I/O
错误；同步路径使用永不取消的 token，保留原失败语义。

Cooperative cancellation 不保证物理停止延迟：目录排序、正在执行的 filesystem syscall，以及已加载
multiline file 上的 regex evaluation 都无法强制中断。Lua 在 terminal 边界同步检查请求新鲜度；
即使输入 observer 尚未请求物理取消，已被替代的请求也不能发布结果或报告错误。

## Lua 请求控制器

每个 file-search composer 独占一个具体 controller。Controller 是 generation、active native job、
最新 immutable pending request 与 poll timer 的唯一 writer。

### 输入与 snapshot

`Observable` 同步更新值，但在 Neovim event loop 通知订阅者。Composer 合并同一轮中影响搜索的通知；
首个 observer callback 在 64 ms debounce 前依次执行：

1. 增加 generation。
2. 请求取消 active job。
3. 清空 pending request。
4. 安排 debounced snapshot 与 submit。

Replacement 与 replace flag 不进入 native search options，只决定预览文本与高亮；它们的通知同样执行上述步骤，
但在下一轮 event loop 立即 snapshot 与 submit，不等 debounce。这类编辑仍会重新搜索，因此结果始终反映
当前文件内容；延迟原本主要来自 debounce。同一轮中若有其他输入的通知先到，合并后仍按 debounce 提交。

Immutable request snapshot 包含 root/cwd/specified path、复制的 include/exclude patterns、query、
replacement、全部 search flags、`max_filesize` 与 `max_matches`。结果归一化和发布只使用该 snapshot。
每次 request-scoped publication 或 error report 前，与 composer 当前输入的新 snapshot 比较；
这是 terminal 阶段唯一读取 Observables 的位置。

### Worker 数量与请求新鲜度

每个 controller 最多有一个实际运行的 worker。A 运行时提交 B，只保存 B 为 pending 并取消 A；
再提交 C 则覆盖 B。A 达到 terminal 后才启动 C，以限制 worker 累积；代价是最新请求可能等待缓慢的物理取消。

Start、poll、terminal、error 与 publication callbacks 均要求 controller 存活、generation 匹配、
request snapshot 等于当前输入。这也约束已排入主循环的 callbacks，覆盖同步 `Observable:next()`
与延迟 subscriber callback 之间的窗口。Stale result/error 直接丢弃，不发布也不报告。

### 空查询与旧结果

Query 变为空后，terminal freshness check 即拒绝旧请求。首个排队的输入 observer 随后取消
active request，清空 search projection 与有序结果列表，保留 root context。
不恢复搜索前的文件 snapshot，因为 result reset 已替换该数据。
允许物理取消和 projection 清理延迟一个 event-loop turn，但不允许 stale publication。

新请求运行或失败时，可保留最近一次成功的非空 projection；其 immutable snapshot 一旦与当前输入
不同，就只能只读展示。所有 destructive replace 在 native file write 前都必须重新比较 snapshot。
不匹配时 warning 并拒绝操作，不能用新 query、replacement、root 或 flags 解释旧 match locations。

列出的 match offsets 只对应搜索时的文件内容。文件搜索为每个文件记下打开时的大小与修改时间；替换一个文件前再取一次，
不同就不替换该文件、保留它的 matches，并提示刷新搜索。替换写盘后更新记录，同一文件可以继续替换。

替换不覆盖 Neovim 中的未保存修改。文件已加载且 buffer 有未保存修改时，替换改在 buffer 中进行，不写盘，由用户保存；
一次替换在每个 buffer 中是一个 undo 步骤，只改写 match 所在的范围。列出的 matches 来自磁盘内容，因此先按行比较磁盘与
buffer 的文本：match 跨越的行都未改动，且 buffer 中对应位置以同样的范围匹配时才替换（`yoz.replace.expand_text_by_matches`
按整段文本给出每个 match 的范围与替换串）；其余 matches 保留在结果中，并提示保留的数量。CRLF buffer 无法表示的位置
（如只含行尾的 `\r`）同样保留。已加载且无修改的 buffer 写盘后立即 `checktime`，直接显示替换后的内容；未加载的文件照常写盘。

### Busy 状态与动画

Composer 为最新 logical search 持有一个只影响展示的 busy interval：

- 首个影响非空搜索的通知到达时开始，早于 debounce 和物理 submit。
- 等待旧 job 确认取消或最新请求处于 pending 时继续保持。
- 仅当前请求完成/失败、query 变空或 dispose 才结束；stale terminal callback 不能结束它。

Finder title 延迟 120 ms 显示 spinner，避免快速搜索闪烁。Spinner 装饰当前动态 title，保留搜索期间
的 title 变化；每帧推进时循环 theme-aware accent，只有 spinner prefix 着色，文字保留 Finder title 高亮。
动画复用 controller 已 schedule 的 running-poll heartbeat，不创建第二个 timer，不重绘 result tree。
Heartbeat callback 失败只报告一次并停用后续动画，不改变 native job 生命周期。

## Polling、失败与清理

Poll timer callback 先切回 Neovim 主循环，等价于 `vim.schedule_wrap`，不在 fast-event context
调用 Neovim API。Job 保持 active 前必须成功创建 timer；timer setup 失败则取消并 dispose 新 job。

无论完成、取消、worker failure、channel 断开、`poll()` 错误、timer/start failure 或 controller dispose，
离开 active job 都按同一顺序处理：

1. 分离 active identity 与 job。
2. 尽力 dispose job；即使 disposal 或 reporter 抛错，也必须清空 active state。
3. 仅当 generation 仍为当前时，对 infrastructure error 报告一次。
4. 启动当前 pending request；无工作时停止 polling。

每次 `poll()` 都由 `pcall` 保护。成功读取 terminal outcome 后，先清理 controller/job，再由 `xpcall`
保护 UI publication；UI 异常不能搁置 active/pending work。

Options 转换、start、worker、poll 与 apply 前的 normalization 失败均保留最后发布结果。
UI mutation 开始后不保证事务性；apply 异常作为 invariant failure 捕获并报告，不保证 rollback。

Controller disposal 同步按以下顺序完成，早于 composer 已有的 scheduled UI teardown：

1. 标记 disposed。
2. 停止并关闭 poll timer。
3. 使 generation 失效。
4. 取消并 dispose active job。
5. 清空 pending work 与 callback 引用。

## Match limit 与结果完整性

File search 持久化 `flag_limit_matches` 和正整数 `max_matches`。Limit 默认开启：
开启时向 Rust 传入 `max_matches`，关闭时传入 `nil` 表示不限制遍历。
Lua settings 拒绝零、负数、小数与超范围值；native API 仅接受 `nil` 或正 32-bit integer。

`ISearchFileResult.limit_reached` 只在遍历达到 `max_matches`、尚未确认穷尽时为 true。
它表示“无法确认结果完整”，不保证还存在更多匹配。相同请求的同步与后台 API 返回相同 flag。

Result winline 分别展示：

- 可交互的 limit flag：决定后续请求是否受限。
- 橙色 `LIMIT <max_matches>`：标记当前已发布且 `limit_reached = true` 的 projection。

状态标记属于已发布 projection，不随 live settings 改变；新请求 pending 或失败时保留，直到 projection
被替换或清空。切换 flag 使当前请求失效并发起新搜索；关闭时保留正整数 limit，供再次开启使用。

`limit_reached = true` 时拒绝 global `replace all` 并 warning；用户需关闭限制并取得完整结果后再执行。
Node-scoped 与单项替换只处理可见 matches，不受此限制，但仍须通过 stale-projection 检查。
文件、目录与全部替换都按列出且可见的 match offsets 写入，不整文件替换：文件中可能还有结果没有列出的匹配，
如截止文件中未发现的、单项替换引入的匹配。

单项替换后，同文件其余可见 matches 的行号、列与预览文本按同一请求只搜该文件的结果刷新，与新搜索一致；
这次搜索沿用 `max_matches`：limit 为默认的 500 时每次替换多约 4 ms，关闭 limit 时与该文件的匹配数成正比，
2 万处约多 100 ms。替换引入的新匹配不加入结果，未在刷新结果中找到的 match 只更新 offset。
隐藏的 match 不参与替换，offset 也不随替换移动；刷新时不立即恢复隐藏，等刷新触发的搜索发布结果后，
它们才随新结果一起恢复，不会带着旧 offset 出现在结果中。

## 发布与性能边界

每次搜索发布一个最终结果，保留确定性排序。Lua FileSearch 校验 generation 后，ResultFiles 准备文件与 locations，
ResultTree 导入 native Data 并发布 Frame，遵循 [结果集接入](../../treeview/results.md)。
不启用 Rust file-level parallel traversal 或 streaming UI。

主线程发布的验收边界为默认 `max_filesize = "1M"`、`max_matches = 500`。测量必须包含：

- `job:poll()` 的 Rust-to-Lua terminal conversion。
- Result normalization 与 replacement preview。
- 排序。
- ResultPaths/ResultFiles 准备、location 构建与 records 导入。
- Native projection、Lua staging 与适用 Frame 的实际发布。

普通搜索与 replacement-preview 的最坏 fixture 在 500 matches 下都必须低于 50 ms。
5000-match 场景只记录 stress result，不承诺响应性，也不引入静默结果上限。
若 500-match 边界不达标，必须进行 chunked conversion 与 time-sliced publication。

内部并行搜索不在当前范围。它主要改善吞吐量；引入前需另行决定确定性排序、全局 match limit、
资源使用与取消协调契约。
