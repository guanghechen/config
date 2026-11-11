# Searcher 请求控制

`era.m.searcher` 的 file search 负责 debounce、request generation、polling、结果发布与 UI 生命周期；
文件遍历、匹配、native job 与取消语义见 [Yoz Search](../yoz/search.md)。

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
当前文件内容；延迟主要来自 debounce。同一轮中若有其他输入的通知先到，合并后仍按 debounce 提交。

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
Lua settings 拒绝零、负数、小数与超范围值；native 接受的取值与 `limit_reached` 的语义见
[Yoz Search Match limit](../yoz/search.md#match-limit)。

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
这次搜索沿用 `max_matches`，关闭 limit 时刷新成本与该文件的匹配数成正比。替换引入的新匹配不加入结果，
未在刷新结果中找到的 match 只更新 offset。
隐藏的 match 不参与替换，offset 也不随替换移动；刷新时不立即恢复隐藏，等刷新触发的搜索发布结果后，
它们才随新结果一起恢复，不会带着旧 offset 出现在结果中。

## 发布与性能边界

每次搜索发布一个最终结果，保留确定性排序。Lua FileSearch 校验 generation 后，ResultFiles 准备文件与 locations，
ResultTree 导入 native Data 并发布 Frame，遵循 [结果集接入](results.md)。
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
