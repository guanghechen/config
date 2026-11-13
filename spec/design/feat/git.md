# Git 模块

`era.m.git` 提供 Git status、hunk、sign 与 blame，替代 gitsigns.nvim。

## 模块架构

`era.m.git` 按单仓库组织编辑器侧职责：

- 仓库与状态：`repo` 是 Git 仓库抽象，封装常用操作，支持 worktree（commondir）；`state` 持有 status snapshot
  并合并、节流刷新；`watcher` 监听 gitdir、index 与 commondir；`user` 提供当前仓库的 Git 身份，供 blame 判断作者。
- Buffer 与 hunk：`buffer` 计算并缓存各 buffer 的 hunks；`sign` 渲染 signs；`hunk` 提供查询、stage / unstage / reset
  与 hunk preview；`hunk_nav` 管理 hunk navigation；Visual stage 成功且选区未变时，`visual` 退出 Visual mode。
- Index 写入：`index` 串行化同一仓库的 index mutation；`staging` 负责 buffer capture、native staging 与 legacy iconv。
- 查询与展示：`status` 发起 native status 查询并提供 UI highlight；`ignore` 适配 native ignore cache；`blame` 管理
  blame 查询、buffer ownership 与 extmarks；`diff` 封装 Neovim histogram diff 与 native word-diff；`numstat` 为
  Git Files 与 Diffview 提供 untracked 行数统计。

Git 命令执行、repo info 与在浏览器打开 remote URL 由 `stl.git` 提供，不属于 `era.m.git`。Lua 侧的 Git 命令行统一由
`stl.git.exec.command` 生成，自行管理进程的调用方也用它；路径一律按字面 pathspec 处理（`--literal-pathspecs`），
`a[1].txt` 不会作为通配再匹配 `a1.txt`。

Status / ignore / blame、staging 与 word-diff 纯计算位于 `yoz` crate 内的 `rust/yoz/src/git/`，不单独创建 Git crate。
Status / ignore / blame 查询在 native worker 中执行并发布 immutable snapshot；staging 与 word-diff 在调用线程同步计算。
Status / ignore / blame job 的 polling、取消与退出清理由 `era.m.job` 提供（Find Files 的遍历也用它），native 侧共用
`rust/yoz/src/job.rs` 的 worker job。
核心模块不依赖 Lua 或 Neovim；`rust/yoz/src/git/lua/` 负责 `yoz.git` binding，worker 不持有 Lua values。
Histogram diff、legacy iconv 与 index 写入由 Lua 调用。

## 状态管理

`State.new({ collect, snapshot, throttle_ms })` 持有一份仓库状态：`collect(token)` 返回 status 查询的 Future，
`snapshot` 是首次查询前的状态。模块加载时创建唯一的默认实例，模块函数转发给它；测试为每个用例创建自己的实例。
请求在没有进行中的节流窗口时立即查询；窗口内的请求合并为窗口结束时的一次查询。窗口为上一次查询耗时的 4 倍，
限定在 `min(100 ms, throttle_ms)` 到 `throttle_ms`（默认 800 ms）之间：查询快的仓库能及时反映连续的改动，
查询慢的仓库在事件密集时不被反复查询占满。

`o_branch` 发布当前分支名，`o_refreshed` 发布刷新 generation 与 `change_scope`。`refresh()` 请求完整 status 查询，
`refresh_index()` 用于已知 index 变更后的查询；一轮查询合并的请求全部来自 `refresh_index()` 时，事件的
`change_scope` 为 `index`，消费方可比较 blob identity，否则为 `unknown`。

`state.lua` 持有当前 `yoz.git.StatusSnapshot` handle，不维护第二份 Lua status / directory cache。
Rust worker 完成查询、解析和 ancestor directory index 后，才发布 immutable snapshot；UI lookup 不触发
全仓库扫描。刷新失败保留旧 snapshot；状态未变时复用旧 handle，仍发布刷新事件。

每轮查询捕获启动前的 refresh 等待方；查询期间收到的请求合并到下一轮，不随当前查询提前完成。
失败时报告错误并完成该轮等待方；`dispose()`（退出时调用）取消查询并完成当前与排队等待方，迟到结果不重复完成。
普通文件的 `BufWritePost` 按实际写入路径检查仓库边界并请求完整 status refresh，不依赖 buffer attach
或 Explorer watcher；Diffview 的文件列表与统计随保存刷新。

Ignore cache 也由 Rust 持有，Lua 只转发编辑器 invalidation 事件。`state.snapshot():entries()` 显式导出新的 Lua table，
修改它不会改变 native snapshot；频繁路径查询应使用 `state.snapshot():lookup()`。`status.calc_info(snapshot, …)` 由
调用方传入 snapshot，status 不反向依赖 state。

### 数据流

```text
watcher / index mutation / BufWritePost
  -> state.refresh() / refresh_index()
  -> status.collect() -> yoz.git worker -> StatusSnapshot
  -> state snapshot / Observable
  -> buffer / Explorer / Diffview / statusline
```

## 文件监听

`watcher.lua` 通过 `vim.uv.new_fs_event()` 监听仓库。普通仓库的 gitdir 与 commondir 相同；
linked worktree 的 `.git` 是指向专属 gitdir 的文件，HEAD/index 位于该 gitdir，refs/objects 位于共享 commondir。
`repo.lua` 的 `resolve_commondir()` 解析二者关系。

### Watcher 分工

| Watcher                | 监听目标                      | 处理内容                                         |
| ---------------------- | ----------------------------- | ------------------------------------------------ |
| `fs_watcher_dir`       | `gitdir/`                     | HEAD、index 等目录事件                           |
| `fs_watcher_commondir` | 不同于 gitdir 的 `commondir/` | 共享 packed-refs/reftable 变化                   |
| `fs_watcher_head_ref`  | 当前 HEAD 引用所在目录        | 当前 branch ref 变化；普通仓库和 worktree 均使用 |

Libuv `fs_event` 不递归监听。当前 ref 的父目录不存在时，监听最近的已有祖先目录；
HEAD 变化及 ref 目录事件后重新绑定，覆盖嵌套 branch 路径与目录创建。

Index 使用目录级监听：Git 可能通过 rename `index.lock` → `index` 替换文件，
只监听旧 index 文件可能漏掉后续事件。`filename == "index"` 进入独立的 index 刷新流程。

任一 `fs_event` 创建、启动或运行时失败后，关闭该仓库的事件 watcher，改用 200ms 间隔的异步 metadata polling。
轮询 gitdir 的 HEAD/index、commondir 的 packed-refs、reftable/tables.list 和当前 branch ref，
以 inode、size、mtime/ctime 等 fingerprint 识别修改、替换、创建与删除。最多保留一轮 stat 请求，
使用与事件监听相同的 HEAD/index debounce；HEAD 变化后更新 ref 目标。切换仓库或 dispose 后，旧轮询结果不发布。

### 事件与刷新

| 事件                       | Debounce     | 刷新                                                                            |
| -------------------------- | ------------ | ------------------------------------------------------------------------------- |
| Index 变化                 | 100 ms       | `invalidate_index_all()`、清理 blame 失败 cache、`refresh_index()`              |
| HEAD/refs/packed-refs 变化 | 150 ms       | `invalidate_compare_text_all()`、blame/ignore invalidation、完整 status refresh |
| HEAD/refs 变化             | 与上一项合并 | 更新 branch 与 user info                                                        |
| 其他有效目录变化           | 150 ms       | `mark_dirty_all()` 与 status refresh                                            |

`invalidate_compare_text_all()` 清除 HEAD、index document 与 object identity；
`invalidate_index_all()` 只清理 index document 与 object identity。
同一 debounce 周期内的事件通过 pending flags 合并，HEAD 刷新优先于普通 status 刷新。

过滤 `index.lock*`、`.watchman-cookie*`，以及 `COMMIT_EDITMSG`、`MERGE_MSG`、`ORIG_HEAD`、
`FETCH_HEAD`、`REBASE_HEAD`、`sequencer`、`logs` 等无关事件。目录事件缺少 filename 时保守刷新。
切换仓库或停止监听时，关闭所有 watcher/timer 并清空 pending state。

## Buffer 管理

每个 attached buffer 缓存 HEAD 与 index 的 document、index object identity、unstaged 与 staged hunks，
以及是否为 untracked 文件。

Hunk 计算策略：

1. `hunks = diff(Index, Buffer)` - 当前 buffer 相对于 index 的变更（未暂存）
2. `hunks_head = diff(HEAD, Buffer)` - 当前 buffer 相对于 HEAD 的变更（全部变更）
3. `hunks_staged = filter_secondary(hunks, hunks_head)` - 仅存在于 HEAD→Index 的变更（已暂存）

### 生命周期

- `BufReadPost/BufNewFile/BufFilePost`: 自动 attach
- `BufWritePost`: 重新读取 index identity 并强制刷新 hunks
- `BufDelete`：解除 attachment。
- `on_lines`: throttled 更新；buffer 不可见时只标记 dirty，进入窗口后补算
- `on_reload`: 强制刷新

## Sign 显示

Sign 通过 `nvim_set_decoration_provider` 渲染，范围规则见[设计边界](#设计边界)。
未暂存与已暂存变更的 signs 分属两个 namespace，优先级分别为 10 与 9；已暂存 sign 仅在该行没有未暂存 sign 时显示。
未追踪文件的新增行使用独立的 untracked sign。符号与 highlight 定义在 `sign.lua`。

## Hunk 操作

`hunk` 提供 hunk 查询，hunk / selection 的 stage、unstage、reset，以及整个文件的 stage、reset。
Stage 与 unstage 异步写入 index 并返回 Future，reset 直接改写 buffer。
Hunk stage、unstage、reset 未生效时，由 `hunk` 以 warn 提示一次原因，例如光标处没有 hunk、绘制后 index 已变化；
写 index 的 Git 命令自身失败时由 `stl.git.act` 带 stderr 提示，结果的 `err` 为空，调用方不再重复提示。
Hunk preview 以浮窗显示光标所在的 unstaged hunk（没有时取 staged hunk）及 word-level 高亮，再次调用关闭；
从浮窗 stage 或 reset 只额外提示成功。

`ih`/`ah` 以 linewise Visual mode 选择当前或下一个 unstaged hunk；可用 `vihghs` 在 stage 前确认完整范围。
纯删除没有 modified-side 行，因此选择其 sign 所在的 anchor line，以保持 `ghs` 等 hunk 操作可用。

### Hunk navigation

`hunk_nav` 在普通 buffer 中导航 unstaged hunks 或全部 hunks（含 staged）；diff window 使用原生 `[c` / `]c`
并发布 hunk 位置。位置以 transient index/total 显示。

#### Canonical hunk map 的构建

Hunk navigation 持有一个 transient state `{ winnr, bufnr, index, total }`。
普通 buffer 从 attached hunks 计算位置。Two-pane diff 在原生 `[c` / `]c` motion 前取得共享
canonical hunk map，并记录 source 位置；motion 后用同一 map 解析 target。
Map 从两侧 `era.m.git.staging.from_buffer()` document lines 构建。

- Document 区分 empty bytes、single final newline 与 missing final newline。末尾是否换行按写盘结果：
  `endofline`，或未设 `binary` 时的 `fixendofline`（默认开启，写盘会补上 `noendofline` 省去的换行，
  `endofline` 仍保持关闭）。因此不以换行结尾的文件打开后，末行即显示为改动，与 `:w` 的结果一致。
- 输入按 layout 语义排序：side-by-side 为 left→right，stacked 为 top→bottom，不依赖 buffer 分配顺序。
- Map 使用 `era.m.git.diff.run_diff()` 的 histogram 契约。Pane-local `linematch` 只影响原生光标目标，不拆分 canonical Git hunk。
- 同一个 hunk 在两侧共享 index/total；zero-count side 映射到 BOF、普通 filler 或 EOF anchor。同一 anchor 可以对应多个 hunk。

Map 只由 navigation module 缓存。Cache identity 包含有序 window pair、两侧 `bufnr`、`changedtick`
与两侧写盘时是否以换行结尾；任一变化都重建。一次构建生成两侧有序 line ranges，后续按键不再同步遍历全部 hunks。

#### 原生 motion 与位置解析

1. Motion 前解析两侧共享的 canonical source。
2. 每侧优先按原生 target line 做 binary lookup；落在 alignment gap 时，按 source line 与 direction
   单调推进，并在 canonical 边界 clamp 到 current hunk。
3. 两侧启用 `cursorbind` 且候选冲突时，由 shared resolver 决定：next 取较大 index，prev 取较小 index。
4. 原生 motion 仍停在精确命中的 source hunk 内时，以 `keepjumps` 继续同方向 motion，直到 canonical
   index 改变或 active cursor no-op。Continuation 次数由 `linematch:N` 限定。
5. 从精确 source hunk 离开时，最终只前进到相邻 canonical index；target candidate 仅证明已经离开，
   不能造成跨级跳转。Source 在 hunk 外时，首次到达 estimated index 即停止，避免跳过首个 hunk。

第一次 motion 保留用户 jump，continuation 不增加 jumplist entry。Motion no-op/error 时不合成额外
logical selection；source 精确位于 canonical hunk 时，no-op 可保留 current index，位于所有 ranges 外时不发布 indicator。

非 two-pane layout 回退到 pane-local native enumeration。内部 fallback motion 使用 `keepjumps`，
并临时关闭、随后恢复 `cursorbind` / `scrollbind`。

#### 展示与清理

右侧统一显示红色 `<git-icon> index/total`，不带方括号。普通 source window 使用 winline component，
`diffview://` static winbar 复用 renderer。不使用 buffer virtual text，因此不受行长、水平滚动或 inline blame 影响。

State 只对仍显示 captured buffer 的 source window 可见。Cursor movement、window focus、Git refresh
及同 buffer 的 peer window 生命周期均不清理 indicator。新 navigation 替换旧 state；以下情况才清理：

- Source window 切换到不同 buffer：通过 `BufEnter` 校验 captured `winnr + bufnr`。
- Source window 关闭：通过 `WinClosed` 的 event match 识别。
- 统一 `<Esc>` handler 调用 `clear_nav()`。

不使用 `BufLeave` 判断 source buffer 替换，因为单纯切换 window focus 也会触发它。

### 操作模式规则

#### Normal mode

- 只对当前光标所在行所属的 hunk 生效
- Stage: 作用于 unstaged hunk
- Unstage: 在 staged Diffview 的 index-side window 中操作；普通 buffer 的 unstage 会提示打开 staged diff
- Reset: 作用于 unstaged hunk

#### Visual mode

- 选中 [Li, Lj] 行后，找到这些行所覆盖的所有 hunks
- Stage/Unstage: 裁剪所选 modified-side 行后一次重建；不逐 hunk 写 index
- Reset: **只作用于 unstaged hunks**，忽略所有 staged hunks

### Stage/Unstage 实现

`buffer.lua` 在 repository FIFO 内重新读取 index，比较 object ID 和解码后的 text；与绘制时 snapshot
不一致则拒绝。通过检查后计算 histogram hunks，调用 native staging 重建文本，再按 encoding/BOM 编码，
经 `hash-object --path` 的 clean filter 和 `update-index --cacheinfo` 写入。保留 executable mode；untracked
entry 直接创建，不预先写 intent-to-add。失败释放 FIFO；native 计算不执行 Git 或修改 buffer。

`yoz.git.staging.apply_selection(original, modified, hunks, top, bot, mode)` 同步返回最终 bytes string：

- `stage` / `stage_partial`：输入 index → buffer；分别选择首个触及的完整 hunk / 所有触及 hunk 的选中行。
- `unstage`：输入 HEAD → index，按 index-side 行裁剪后反转、排序，重建 index。
- `reset`：输入 index → buffer，丢弃所有触及的完整 hunk，保留其余变更。

无触及变更返回 `nil`；空字符串是有效的空文件结果。等长 change 可逐行裁剪，不等长 change 保留完整
removed span，纯删除整块选择；保留 BOF 零锚点和 EOF flag 传播。坐标要求 exact integer；参与重建的 span
越界或行数不匹配抛错，不会返回部分可写文本。原始 hunks 不被修改；正常生产路径不把中间选区重新展开成 Lua
hunk tables。

`from_text` 的 EOL majority normalization 也在 Rust，CR/CRLF 票数严格超过 LF 时选择 CRLF，平票选择 LF；
没有换行则使用默认 LF/CRLF。`Document.lines` 保留 final empty sentinel；重建以捕获的 lines 为准，保留各行
来源的 EOL 和 final newline，不重新解析或二次 normalize 最终 text。

Unicode encoding/BOM 由 Rust 标准库实现，按 Neovim 文件写入语义使用明确字节序，不依赖系统 iconv：

- `utf-8`、`utf-16[le]`、`ucs-2[le]`、`ucs-4[le]` 及其 Unicode aliases 归一化；后三类默认 BE，`le` 指定 LE。
  `utf-16be` 使用 UTF-16 BE，`unicode` 为 UCS-2 BE，`utf-32[be/le]` 对应 UCS-4 BE/LE。
- 解码只移除一个匹配的 BOM；编码时 `bomb=true` 总是额外前置 marker，保留正文首字符 U+FEFF。
  无 marker 的正文首 U+FEFF 与 BOM 无法区分，读取时视作 marker，但 byte round-trip 保持不变。
- UTF-8 继续保留任意 bytes；其他 Unicode codec 拒绝截断 code unit、非法 scalar/surrogate、与给定 encoding
  冲突的开头 BOM，以及不可表示的 UCS-2 字符。不猜字节序、不做有损替换，返回 `nil, error`，不进入 index 写入。
  UTF-16/UCS-2 无 BOM 文件开头的 U+FFFE 与反向 BOM 同样无法区分，会被拒绝；正文内部的 noncharacters 仍可保留。
- Lua 保留 buffer options / 读写和 legacy `vim.iconv`。Native 返回 `nil` 且无 error 才走 legacy fallback；
  Unicode 错误不 fallback。UTF-8 无 BOM 变化时 binding 直接复用输入 Lua string。

Binding 使用 packed bytes 和 offsets，live Lua references 不随行数或 hunk 数增长；modified-side 仅读取重建
所需的行数/EOF metadata，新增行来自 hunks。

## Diff 算法

- 使用 `vim.text.diff()` 的 histogram 算法计算行级 diff
- 提供 `filter_secondary()` 分离 staged/unstaged hunks
- 支持 word-level diff 用于 hunk preview

Word diff 的字节预处理、两次范围归并与边界扩展在 Rust；Lua 保留 Neovim diff 调用、hunk 行配对和 popup 渲染。
不改变行级 hunks、stage/unstage、signs 或 hunk state。

- 相同文本和单边空字符串由 Lua 直接返回，避免 FFI；空边对应的整行范围不受 500-byte 限制。
- `yoz.git.word_diff.inputs(old, new)` 只取各自前 500 bytes，以 LF 分隔每个 byte；按 byte 而非 Unicode character diff。
- Lua 对这些输入调用 `vim.text.diff(..., { algorithm = "histogram", result_type = "indices" })`。
- `finish(old, new, raw)` 返回 zero-based、end-exclusive byte ranges：先合并两侧 gap 均不超过 2 的范围，
  按 ASCII category 规则扩展到完整源文本的边界，再合并重叠范围。扩展可超过 diff 输入的 500-byte 上限。
- Diff 失败时 `raw=nil` 保留各侧最多 500 bytes 的矩形 fallback；`raw={}` 表示无 word highlights。
  仅前 500 bytes 之后的变化可能不显示 word highlights。Malformed raw coordinates 明确拒绝。

## Blame 功能

Lua 捕获当前 buffer 的 `Document` 并按原 encoding / BOM / EOL 编码；Rust worker 执行
`git blame --porcelain --contents - -- <path>`，解析后发布 immutable `BlameSnapshot`。Blame 基于 buffer
内容而非磁盘文件。Commit metadata 只存一份，每行保存 attribution 与 source information。

- Inline 延迟 500ms，查询整个 buffer；之后仅查询当前行的 commit metadata，在行尾显示。
- Buffer overlay 位于 window column 80，排除当前 cursor line；与 inline 共用已完成的 snapshot cache。
- Cache 由 `bufnr + attachment owner + changedtick` 限定；writes / HEAD invalidation 会主动清理。
  两类 inflight 分别跟踪，已取消的请求不能继续 coalesce，确保同 tick invalidate 和快速 toggle 能立即重试。
- Lua 仅额外缓存 rendered-text projection，按 commit 格式化后一次性映射到行，避免逐行导出完整 metadata。
  Snapshot、formatter、当前用户身份、`TZ` / 时区标识或 time locale 改变时重建；日期使用 Lua `os.date()`。
- Metadata 按字面量插入：`%1` 或 `<sha>` 等出现在 author / summary 中时不作为 replacement 或二次模板执行。
- Native cancellation 等待 worker acknowledgement，由 adapter 映射为 `blame:cancelled` sentinel；
  cancelled / stale 结果不落失败缓存。普通失败按 owner / tick 去重，诊断保持 silent。
  退出时统一取消 native jobs，并停止 blame debounce 与后续 UI 更新。

Native API：

- `yoz.git.start_blame({ cwd, path, contents })`：绝对仓库 cwd、Git filename、已编码的内容 bytes；返回
  `poll/cancel/dispose` job。每个子进程 30s deadline，使用共享 process cleanup。
- `snapshot:commit_at(lnum)` / `commits()`：单行 / 去重后的 commit metadata，含 `uncommitted` 标识。
- `snapshot:annotations(labels)`：将逐 commit 的 UI labels 映射为逐行字符串；数量必须与 commit count 一致。
  使用 raw array prefix 校验；labels 在同步调用期间只读。逐项校验后释放 handle，按连续 commit 块借用
  label 写入结果，辅助 `mlua` handles 为 O(1)，不复制 labels table，也不持有按 commit 数增长的 handle vector。
- `snapshot:entries()`：显式复制完整逐行记录，供诊断 / 数据对照；filename / previous_filename 保留原
  porcelain spelling（包括 Git 的引号和转义），不直接作为 filesystem path 使用。
- `snapshot:stats()`：line count、commit count、native elapsed ms。截断或不一致的协议输出拒绝整份结果。

成本：native heap / worker threads、每个 buffer 的 Lua 行文本 cache、约一个 poll interval 的发布等待。
Buffer capture/encoding、初次 UI projection 和 extmark 写入在主线程；重绘写入全量 extmarks，不做 viewport virtualization。

## Git Status 解析

### 查询语义

默认 `status.collect()` 使用 `git --no-optional-locks status --porcelain=v2 -z`，一次读取普通文件的
staged、unstaged 和 untracked 状态。路径按 NUL protocol 保留原始 bytes；HEAD/index object IDs
只填入发生变化的一侧，全零 ID 仍表示缺失。后台查询不写回 index。

以下场景使用 `git diff --raw --abbrev=64 -z`：

- 指定 `base` 或 `include_numstat`：直接使用 raw 查询，numstat 与 object identity 来自同一输出。
- rename/copy、同一侧存在新增及潜在 source、conflict、submodule：读取 porcelain 后查询两侧 raw diff，
  复用已取得的 untracked paths。这样保留 `diff.renames` / `diff.renameLimit`、conflict 和 submodule 语义，
  代价是额外一轮查询。

任何必需查询失败或 porcelain 输出不完整时，整个 Future 拒绝，不发布部分 snapshot。

### Untracked 行数统计

`era.m.git.numstat` 为 Git Files 与 Diffview 提供同一套 NUL numstat 解析和 untracked 批量查询。
查询在临时 `GIT_INDEX_FILE` 中为显式 paths 建立 intent-to-add 条目，再运行一次 `git diff --numstat -z`；
结束或取消后清理临时目录，不写真实 index。Git 查询失败降级为未知统计，取消或内部错误仍传播给调用方。
Binary 的未知统计和空文本文件的 `0 / 0` 保持区别。Git Files 的展示与文件级操作见
[Git Files](git-files.md)。

### Native 契约

- `yoz.git.start_status({ cwd, base?, include_numstat?, include_untracked? })` 启动 worker；`cwd` 是
  canonical absolute 仓库路径，默认不取 numstat、包含 untracked。环境变量在 Lua 入口捕获，worker
  不持有 Lua value，也不调用 Neovim API。Unix pathname 保留原始 bytes，Windows 在 binding 统一分隔符。
- Job 提供 `poll()` / `cancel()` / `dispose()`。`poll()` 返回 `running|completed|cancelled|failed`、snapshot、
  error；terminal outcome 可重复读取。`dispose()` 幂等、非阻塞并请求取消；之后不可 poll / cancel。
- 每个 Git 子进程最多执行 30s；取消会终止并回收 Git。Unix 同时终止其 process group，避免 hook 占住 pipes；
  Windows 只终止直接子进程，不清理 descendants。
- Lua 每 5ms poll，一次最多排队一个 scheduled callback；取消后等待 worker acknowledgement，且不会发布
  与取消竞态的 completed result。`VimLeavePre` 关闭 refresh throttle、settle 等待方并取消 jobs，最多等待
  100ms 完成 native cleanup，随后释放 Lua handles。

Snapshot API：

- `lookup(path, is_directory?)`：单路径状态，`codes` 为 bitmask；目录返回 code union，文件保留 staged / unstaged 顺序。
- `equals(other)`：比较 status entries（含 object identity），忽略 numstats 和查询 timing。
- `changed_files()` / `display()`：按需导出导航列表 / display map；untracked 属于 unstaged 导航列表。
- `entries()` / `export()`：显式复制为 Lua tables；后者额外包含 status groups 和可选 numstats，供 Diffview 使用。
- `stats()`：Git process count 与 native elapsed ms，仅用于诊断。`yoz.git.empty_status()` 创建空 snapshot。

代价是 worker/pipe-reader threads、native heap 和至多一个 poll interval 的常规发布延迟；`equals`、单路径
lookup 与显式 Lua export 在调用线程执行。Lua 侧不另建 status cache，重复 lookup 需跨 Lua/Rust 边界并构造
返回 table，大树的 warm-cache 重绘因此较慢，这是明确的性能取舍。

状态码（冲突、未追踪、修改、删除、新增、重命名、复制、类型变更、忽略）的 bitmask 由 `yoz.git.codes` 导出，
定义见 `rust/yoz/src/git/model.rs` 的 `CODES`。

Stage 状态：

- `staged`: 仅有已暂存变更
- `unstaged`: 仅有未暂存变更
- `mixed`: 同时有已暂存和未暂存变更

## Ignore cache 与失效策略

`ignore.lua` 提供 `preload()` / `is_ignored()` / `clear()` 与 `o_refreshed` / `o_invalidated`，`setup()` 注册编辑器
invalidation 事件。路径采用 canonical absolute key，末尾斜杠不影响 lookup；Unix 保留原始 bytes。

- `yoz.git.ignore_cache(cwd)` 创建绑定仓库的 cache；`lookup(path)` 只读内存，unknown 返回 false。
- `cache:start(paths)` 返回 ignore job，共用 `poll/cancel/dispose` contract。Worker 处理 fingerprint、
  路径去重、symlink ancestor、`git check-ignore --stdin -z`、解析与 cache 构建；调用线程只发布 snapshot。
  `poll()` 的 result 包含 `changed`、可选 `warning`，以及诊断用 `processes/lstat_calls`。
- Cache handle 属于创建线程，worker 只接收 immutable snapshot。`clear()` 立即替换当前 snapshot；
  旧结果或并发发布发生冲突时，native job 用最新 snapshot 重试完整请求，避免覆盖其他请求的 cache。
- 使用 2000-entry 容量阈值；超限时重建整个当前 batch，允许单个 batch 超过阈值。完全命中的 batch 不清 cache。
- Exit 0/1 可缓存 positive / negative；其他 exit code 只接受已输出的 positive，缺失输出仍为 unknown。
  Spawn、pipe、timeout 等 native failure 拒绝 Future 并报告；取消时 Future 以 nil 完成，不发布 cache。
- Symlink descendant 查询最外层 link，避免 Git 穿越 symlink；对共享 ancestor 的探测在单个 batch 内复用。
- 根 `.gitignore` / `.git/info/exclude` 的 mtime + size fingerprint 在 worker 检查。Lua 将 ignore 文件的
  `BufWritePost`、`FocusGained` 和已有 watcher 事件转发为 `clear()`；nested 与 worktree exclude 的外部修改不单独监听。
- 对查询路径按发布前后的 lookup 值生成变化事件，包含 ignored → visible / unknown，保证异步 invalidation 后重绘。
  显式 clear 后允许同一路径再次通知；workspace 已切换时不发布旧 cache 的事件。

Warm preload 也异步检查 fingerprint，不保证立即完成；同步 lookup 即时可用。取消通常在 worker
确认后的下一次 poll settle；共享 `job.lua` 在退出时统一取消 status / ignore，最多等待 100ms。

## 设计边界

- 按单仓库维护状态，不聚合多个仓库或嵌套仓库的状态。
- 配置使用模块常量。
- Staged 与 unstaged hunks 分别计算和缓存，具体操作范围见上文。
- 行级 diff 使用 Neovim 内置 histogram；sign 只渲染可见区域：hunk 更新只协调各窗口显示的行，其余行的 sign 删除，
  窗口显示到新的行时由 decoration provider 补上，更新的开销与显示的行数相关，与改动的行数无关。
- Diffview 的布局与交互见 [Diffview](diffview/README.md)，原生搜索反馈见 [Winline 搜索](search-feedback.md)。
