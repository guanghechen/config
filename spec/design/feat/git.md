# Git 模块

`era.m.git` 提供 Git status、hunk、sign 与 blame，替代 gitsigns.nvim。

## 模块架构

```text
era.m.git/
├── init.lua      -- 入口，初始化 watcher、autocmd、暴露公共 API
├── state.lua     -- 全局状态管理（branch、staged/unstaged files、status cache）
├── repo.lua      -- Git 仓库抽象，封装常用操作，支持 worktree (commondir)
├── cmd.lua       -- Git 命令封装（async/sync）
├── index.lua     -- 主 index mutation 串行化
├── ignore.lua    -- Native ignore cache 的事件与 Future adapter
├── job.lua       -- Status / ignore / blame 共用的 polling、取消与退出清理
├── watcher.lua   -- 文件系统监听（gitdir、index、commondir）
├── buffer.lua    -- Buffer 级别的 Hunk 计算和缓存
├── hunk.lua      -- Hunk 数据、查询和 stage/unstage/reset 操作
├── hunk_nav.lua  -- Hunk navigation state、普通 buffer 与 diff window 导航
├── sign.lua      -- Sign 显示（使用 decoration provider）
├── diff.lua      -- Neovim histogram diff 与 native word-diff adapter
├── staging.lua   -- Native staging 接口、buffer capture 与 legacy iconv
├── status.lua    -- Native status 请求与 UI highlight
├── blame.lua     -- Blame 的 buffer ownership、UI presentation 与 extmarks
├── browse.lua    -- 在浏览器中打开文件
└── types.lua     -- 类型定义
```

Status / ignore / blame、staging 与 word-diff 纯计算位于独立的 `rust/git`（`yoz-git`），不依赖 Lua 或 Neovim；
`rust/yoz/src/git.rs` 及其子模块负责 `yoz.git` binding。Histogram diff、legacy iconv 与 index 写入仍由 Lua 调用。

## 状态管理

### state.lua

维护全局 Git 状态，使用 `stl.c.Observable` 实现响应式更新：

```lua
M.o_branch          -- Observable<string>: 当前分支名
M.o_refreshed       -- Observable<IRefreshEvent>: 刷新 generation 与 change_scope
M.o_staged_files    -- Observable<string[]>: 已暂存的文件列表
M.o_unstaged_files  -- Observable<string[]>: 未暂存的文件列表
```

`state.lua` 持有当前 `yoz.git.StatusSnapshot` handle，不再维护第二份 Lua status / directory cache。
Rust worker 完成查询、解析和 ancestor directory index 后，才发布 immutable snapshot；UI lookup 不触发
全仓库扫描。刷新失败保留旧 snapshot；状态未变时复用旧 handle，仍发布刷新事件。

Ignore cache 也由 Rust 持有，Lua 只转发编辑器 invalidation 事件。`state.status_table()` 显式导出新的 Lua table，修改它不会
改变 native snapshot；频繁路径查询应使用 `state.snapshot():lookup()`。

### 数据流

```text
watcher / index mutation
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

### 事件与刷新

| 事件                       | Debounce     | 刷新                                                                            |
| -------------------------- | ------------ | ------------------------------------------------------------------------------- |
| Index 变化                 | 100 ms       | `invalidate_index_all()`、清理 blame 失败 cache、`refresh_index()`              |
| HEAD/refs/packed-refs 变化 | 150 ms       | `invalidate_compare_text_all()`、blame/ignore invalidation、完整 status refresh |
| HEAD/refs 变化             | 与上一项合并 | 更新 branch 与 user info                                                        |
| 其他有效目录变化           | 150 ms       | `mark_dirty_all()` 与 status refresh                                            |

`invalidate_compare_text_all()` 清除 HEAD、index compare text 与 object identity；
`invalidate_index_all()` 只清理 index compare text 与 object identity。
同一 debounce 周期内的事件通过 pending flags 合并，HEAD 刷新优先于普通 status 刷新。

过滤 `index.lock*`、`.watchman-cookie*`，以及 `COMMIT_EDITMSG`、`MERGE_MSG`、`ORIG_HEAD`、
`FETCH_HEAD`、`REBASE_HEAD`、`sequencer`、`logs` 等无关事件。目录事件缺少 filename 时保守刷新。
切换仓库或停止监听时，关闭所有 watcher/timer 并清空 pending state。

## Buffer 管理

### buffer.lua

每个 buffer 维护独立的 hunk 缓存：

```lua
---@class era.m.git.buffer.ICache
---@field public compare_text       string[]|nil  -- HEAD 内容
---@field public compare_text_index string[]|nil  -- Index 内容
---@field public hunks              Hunk[]|nil    -- Index vs Buffer（未暂存变更）
---@field public hunks_staged       Hunk[]|nil    -- HEAD vs Index（已暂存变更）
---@field public untracked          boolean       -- 是否是新文件
```

Hunk 计算策略：

1. `hunks = diff(Index, Buffer)` - 当前 buffer 相对于 index 的变更（未暂存）
2. `hunks_head = diff(HEAD, Buffer)` - 当前 buffer 相对于 HEAD 的变更（全部变更）
3. `hunks_staged = filter_secondary(hunks, hunks_head)` - 仅存在于 HEAD→Index 的变更（已暂存）

### 生命周期

- `BufReadPost/BufNewFile`: 自动 attach
- `BufWritePost`: 强制刷新 compare_text
- `BufDelete`：解除 attachment。
- `on_lines`: debounced 增量更新
- `on_reload`: 强制刷新

## Sign 显示

### sign.lua

使用 `nvim_set_decoration_provider` 实现高性能 sign 渲染：

```lua
signs_normal:  -- 未暂存变更的 sign（优先级 10）
signs_staged:  -- 已暂存变更的 sign（优先级 9，仅在无未暂存 sign 时显示）
```

Sign 类型：

| 类型         | 符号 | 含义                   |
| :----------- | :--- | :--------------------- |
| add          | ┃    | 新增行                 |
| change       | ┃    | 修改行                 |
| delete       | ▁    | 删除行（在下一行显示） |
| topdelete    | ▔    | 文件开头的删除         |
| changedelete | ~    | 修改且有删除           |
| untracked    | ┆    | 未追踪文件的新增行     |

## Hunk 操作

### hunk.lua

提供 hunk 的查找和修改操作：

```lua
M.find(lnum, hunks)          -- 查找光标所在的 hunk
M.find_nearest(lnum, hunks, direction, opts)  -- 查找最近的 hunk
M.textobjects()                -- 本地 textobject 的 unstaged hunk ranges（0-based、end-exclusive）
M.stage(range, callback)     -- Stage hunk
M.unstage(range, callback)   -- Unstage hunk
M.reset(range)               -- Reset hunk（恢复到 index 内容）
M.stage_buffer(callback)     -- Stage 整个文件
M.reset_buffer()             -- Reset 整个文件
```

`ih`/`ah` 以 linewise Visual mode 选择当前或下一个 unstaged hunk；可用 `vihghs` 在 stage 前确认完整范围。
纯删除没有 modified-side 行，因此选择其 sign 所在的 anchor line，以保持 `ghs` 等 hunk 操作可用。

### hunk_nav.lua

提供普通 buffer 与 diff window 的 hunk navigation：

```lua
M.nav(direction)             -- 导航到下一个/上一个 unstaged hunk
M.nav_all(direction)         -- 导航到下一个/上一个 hunk（包含 staged）
M.nav_diff(direction)        -- 使用原生 [c/]c 导航当前 diff window
M.get_nav_indicator(winnr)   -- 读取指定 window 的 transient index/total
M.clear_nav()                -- 显式清理 transient navigation state
```

#### Canonical hunk map 的构建

Hunk navigation 持有一个 transient state `{ winnr, bufnr, index, total }`。
普通 buffer 从 attached hunks 计算位置。Two-pane diff 在原生 `[c` / `]c` motion 前取得共享
canonical hunk map，并记录 source 位置；motion 后用同一 map 解析 target。
Map 从两侧 `era.m.git.staging.from_buffer()` document lines 构建。

- Document 区分 empty bytes、single final newline 与 missing final newline。
- 输入按 layout 语义排序：side-by-side 为 left→right，stacked 为 top→bottom，不依赖 buffer 分配顺序。
- Map 使用 `era.m.git.diff.run_diff()` 的 histogram 契约。Pane-local `linematch` 只影响原生光标目标，不拆分 canonical Git hunk。
- 同一个 hunk 在两侧共享 index/total；zero-count side 映射到 BOF、普通 filler 或 EOF anchor。同一 anchor 可以对应多个 hunk。

Map 只由 navigation module 缓存。Cache identity 包含有序 window pair、两侧 `bufnr`、`changedtick`
与 `endofline`；任一变化都重建。一次构建生成两侧有序 line ranges，后续按键不再同步遍历全部 hunks。

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
没有换行则沿用默认 LF/CRLF。`Document.lines` 保留 final empty sentinel；重建以捕获的 lines 为准，保留各行
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

Codec 是同步计算，仍有主线程扫描、native allocation 和 Lua string 构造成本；不保证整体 staging 加速。

Binding 使用 packed bytes 和 offsets，live Lua references 不随行数或 hunk 数增长；modified-side 仅读取重建
所需的行数/EOF metadata，新增行来自 hunks。仍有同步 marshalling/native allocation 成本，不保证每个操作加速。

## Diff 算法

### diff.lua

- 使用 `vim.text.diff()` 的 histogram 算法计算行级 diff
- 提供 `filter_secondary()` 分离 staged/unstaged hunks
- 支持 word-level diff 用于 hunk preview

Word diff 的字节预处理、两次范围归并与边界扩展在 Rust；Lua 保留 Neovim diff 调用、hunk 行配对和 popup 渲染。
不改变行级 hunks、stage/unstage、signs 或 hunk state。

- 相同文本和单边空字符串仍由 Lua 直接返回，避免 FFI；空边对应的整行范围不受 500-byte 限制。
- `yoz.git.word_diff.inputs(old, new)` 只取各自前 500 bytes，以 LF 分隔每个 byte；不改为 Unicode character diff。
- Lua 对这些输入调用原有 `vim.text.diff(..., { algorithm = "histogram", result_type = "indices" })`。
- `finish(old, new, raw)` 返回 zero-based、end-exclusive byte ranges：先合并两侧 gap 均不超过 2 的范围，
  按原 ASCII category 规则扩展到完整源文本的边界，再合并重叠范围。扩展可超过 diff 输入的 500-byte 上限。
- Diff 失败时 `raw=nil` 保留各侧最多 500 bytes 的矩形 fallback；`raw={}` 表示无 word highlights。
  仅前 500 bytes 之后变化仍可能不显示 word highlights，这是既有行为。Malformed raw coordinates 明确拒绝。

这是同步计算，仍有 FFI 和结果 table allocation 成本；长单词收益明显，短行或离散修改不保证加速。

## Blame 功能

### blame.lua

Lua 捕获当前 buffer 的 `Document` 并按原 encoding / BOM / EOL 编码；Rust worker 执行
`git blame --porcelain --contents - -- <path>`，解析后发布 immutable `BlameSnapshot`。不改为磁盘文件
blame，也不启用新的 Git flags。Commit metadata 只存一份，每行保存 attribution 与 source information。

- Inline 延迟 500ms，查询整个 buffer；之后仅查询当前行的 commit metadata，在行尾显示。
- Buffer overlay 仍位于 window column 80，排除当前 cursor line；与 inline 共用已完成的 snapshot cache。
- Cache 由 `bufnr + attachment owner + changedtick` 限定；writes / HEAD invalidation 会主动清理。
  两类 inflight 分别跟踪，已取消的请求不能继续 coalesce，确保同 tick invalidate 和快速 toggle 能立即重试。
- Lua 仅额外缓存 rendered-text projection，按 commit 格式化后一次性映射到行，避免逐行导出完整 metadata。
  Snapshot、formatter、当前用户身份、`TZ` / 时区标识或 time locale 改变时重建；日期仍使用 Lua `os.date()`。
- Metadata 按字面量插入：`%1` 或 `<sha>` 等出现在 author / summary 中时不作为 replacement 或二次模板执行。
- Native cancellation 等待 worker acknowledgement，由 adapter 映射为原 `blame:cancelled` sentinel；
  cancelled / stale 结果不落失败缓存。普通失败仍按 owner / tick 去重，诊断保持 silent。
  退出时统一取消 native jobs，并停止 blame debounce 与后续 UI 更新。

Native API：

- `yoz.git.start_blame({ cwd, path, contents })`：绝对仓库 cwd、Git filename、已编码的内容 bytes；返回
  `poll/cancel/dispose` job。每个子进程 30s deadline，沿用共享 process cleanup。
- `snapshot:commit_at(lnum)` / `commits()`：单行 / 去重后的 commit metadata，含 `uncommitted` 标识。
- `snapshot:annotations(labels)`：将逐 commit 的 UI labels 映射为逐行字符串；数量必须与 commit count 一致。
  沿用 raw array prefix 校验；labels 在同步调用期间只读。逐项校验后释放 handle，按连续 commit 块借用
  label 写入结果，辅助 `mlua` handles 为 O(1)，不复制 labels table，也不持有按 commit 数增长的 handle vector。
- `snapshot:entries()`：显式复制完整逐行记录，供诊断 / 数据对照；filename / previous_filename 保留原
  porcelain spelling（包括 Git 的引号和转义），不直接作为 filesystem path 使用。
- `snapshot:stats()`：line count、commit count、native elapsed ms。截断或不一致的协议输出拒绝整份结果。

成本：native heap / worker threads、每个 buffer 的 Lua 行文本 cache、约一个 poll interval 的发布等待。
Buffer capture/encoding、初次 UI projection 和 extmark 写入仍在主线程；重绘依然是全量 extmarks，不做 viewport virtualization。

## Git Status 解析

### 查询语义

默认 `status.collect()` 使用 `git --no-optional-locks status --porcelain=v2 -z`，一次读取普通文件的
staged、unstaged 和 untracked 状态。路径按 NUL protocol 保留原始 bytes；HEAD/index object IDs
只填入发生变化的一侧，全零 ID 仍表示缺失。后台查询不写回 index。

以下场景保留 `git diff --raw --abbrev=64 -z`：

- 指定 `base` 或 `include_numstat`：直接使用原有 raw 查询，numstat 与 object identity 来自同一输出。
- rename/copy、同一侧存在新增及潜在 source、conflict、submodule：读取 porcelain 后查询两侧 raw diff，
  复用已取得的 untracked paths。这样保留 `diff.renames` / `diff.renameLimit`、conflict 和 submodule 语义；
  特殊场景存在额外一轮等待，不保证加速。

任何必需查询失败或 porcelain 输出不完整时，整个 Future 拒绝，不发布部分 snapshot。

### Native 契约

- `yoz.git.start_status({ cwd, base?, include_numstat?, include_untracked? })` 启动 worker；`cwd` 是
  canonical absolute 仓库路径，默认不取 numstat、包含 untracked。环境变量在 Lua 入口捕获，worker
  不持有 Lua value，也不调用 Neovim API。Unix pathname 保留原始 bytes，Windows 在 binding 统一分隔符。
- Job 提供 `poll()` / `cancel()` / `dispose()`。`poll()` 返回 `running|completed|cancelled|failed`、snapshot、
  error；terminal outcome 可重复读取。`dispose()` 幂等、非阻塞并请求取消；之后不可 poll / cancel。
- 每个 Git 子进程最多执行 30s；取消会终止并回收 Git。Unix 同时终止其 process group，避免 hook 占住 pipes；
  Windows 当前只终止直接子进程，descendant cleanup 尚未覆盖。
- Lua 每 5ms poll，一次最多排队一个 scheduled callback；取消后等待 worker acknowledgement，且不会发布
  与取消竞态的 completed result。`VimLeavePre` 关闭 refresh throttle、settle 等待方并取消 jobs，最多等待
  100ms 完成 native cleanup，随后释放 Lua handles。

Snapshot API：

- `lookup(path, is_directory?)`：单路径状态，`codes` 为 bitmask；目录返回 code union，文件保留 staged / unstaged 顺序。
- `equals(other)`：比较 status entries（含 object identity），忽略 numstats 和查询 timing。
- `changed_files()` / `display()`：按需导出导航列表 / display map；untracked 属于 unstaged 导航列表。
- `entries()` / `export()`：显式复制为 Lua tables；后者额外包含 status groups 和可选 numstats，供 Diffview 使用。
- `stats()`：Git process count 与 native elapsed ms，仅用于诊断。`yoz.git.empty_status()` 创建空 snapshot。

代价是 worker/pipe-reader threads、native heap 和至多一个 poll interval 的常规发布延迟。`equals`、单路径
lookup 与显式 Lua export 仍在调用线程执行；不应把 Lua GC 指标当作整体内存占用。
重复 lookup 还需跨 Lua/Rust 边界并构造返回 table，比已有 Lua table cache 的直接读取慢；Lua
侧不重建另一份 status cache，因此大树的 warm-cache 重绘是明确的性能取舍。

状态码映射：

| 码  | 含义     | Bitmask |
| :-- | :------- | :------ |
| U   | 冲突     | 1       |
| ?   | 未追踪   | 2       |
| M   | 修改     | 4       |
| D   | 删除     | 8       |
| A   | 新增     | 16      |
| R   | 重命名   | 32      |
| C   | 复制     | 64      |
| T   | 类型变更 | 128     |
| !   | 忽略     | 256     |

Stage 状态：

- `staged`: 仅有已暂存变更
- `unstaged`: 仅有未暂存变更
- `mixed`: 同时有已暂存和未暂存变更

## Ignore cache 与失效策略

`ignore.lua` 保留 `state.preload_ignored()` / `is_ignored()` / `clear_ignored_cache()` 与
`o_ignored_refreshed` 的入口。路径采用 canonical absolute key，末尾斜杠不影响 lookup；Unix 保留原始 bytes。

- `yoz.git.ignore_cache(cwd)` 创建绑定仓库的 cache；`lookup(path)` 只读内存，unknown 返回 false。
- `cache:start(paths)` 返回 ignore job，共用 `poll/cancel/dispose` contract。Worker 处理 fingerprint、
  路径去重、symlink ancestor、`git check-ignore --stdin -z`、解析与 cache 构建；调用线程只发布 snapshot。
  `poll()` 的 result 包含 `changed`、可选 `warning`，以及诊断用 `processes/lstat_calls`。
- Cache handle 属于创建线程，worker 只接收 immutable snapshot。`clear()` 立即替换当前 snapshot；
  旧结果或并发发布发生冲突时，native job 用最新 snapshot 重试完整请求，避免覆盖其他请求的 cache。
- 沿用 2000-entry 容量阈值；超限时重建整个当前 batch，允许单个 batch 超过阈值。完全命中的 batch 不清 cache。
- Exit 0/1 可缓存 positive / negative；其他 exit code 只接受已输出的 positive，缺失输出仍为 unknown。
  Spawn、pipe、timeout 等 native failure 拒绝 Future 并报告；取消则保留原来的 nil-result contract，不发布 cache。
- Symlink descendant 查询最外层 link，避免 Git 穿越 symlink；对共享 ancestor 的探测在单个 batch 内复用。
- 根 `.gitignore` / `.git/info/exclude` 的 mtime + size fingerprint 在 worker 检查。Lua 将 ignore 文件的
  `BufWritePost`、`FocusGained` 和已有 watcher 事件转发为 `clear()`；完整 nested / worktree exclude 外部监听仍未扩展。
- 对查询路径按发布前后的 lookup 值生成变化事件，包含 ignored → visible / unknown，保证异步 invalidation 后重绘。
  显式 clear 后允许同一路径再次通知；workspace 已切换时不发布旧 cache 的事件。

Warm preload 也异步检查 fingerprint，不再保证立即完成；但同步 lookup 仍然即时可用。取消通常在 worker
确认后的下一次 poll settle；共享 `job.lua` 在退出时统一取消 status / ignore，最多等待 100ms。

## 公共 API

```lua
local git = era.m.git

-- 状态查询
git.get_branch()                    -- 获取当前分支名
git.state.o_staged_files:snapshot() -- 获取已暂存文件列表
git.state.o_unstaged_files:snapshot() -- 获取未暂存文件列表
git.state.snapshot()                -- 获取 immutable native snapshot
git.state.status_table()            -- 按需复制完整 status 表

-- Hunk 操作
git.hunk.stage(range, callback)     -- Stage hunk/selection
git.hunk.unstage(range, callback)   -- Unstage hunk/selection
git.hunk.reset(range)               -- Reset hunk/selection
git.hunk_nav.nav("next")            -- 跳转到下一个 hunk
git.hunk_nav.nav("prev")            -- 跳转到上一个 hunk
git.hunk_nav.nav_diff("next")       -- 使用原生 ]c 跳转并发布 diff hunk position
git.hunk_nav.nav_diff("prev")       -- 使用原生 [c 跳转并发布 diff hunk position
git.show_hunk()                     -- 显示当前 hunk 的 diff 预览

-- Blame
git.toggle_blame()                  -- 切换 inline blame
git.blame.buffer_show()             -- 显示整个文件的 blame
git.blame.buffer_hide()             -- 隐藏文件 blame

-- 浏览器
git.open_in_browser()               -- 在浏览器中打开当前文件/行
git.open_in_browser({ what = "commit" })  -- 打开当前行的 commit
```

## 设计边界

- 按单仓库维护状态，不聚合多个仓库或嵌套仓库的状态。
- 配置使用模块常量。
- Staged 与 unstaged hunks 分别计算和缓存，具体操作范围见上文。
- 行级 diff 使用 Neovim 内置 histogram；sign 通过 decoration provider 只渲染可见区域。
- Diffview 的布局与交互见 [Diffview](diffview/main.md)，原生搜索反馈见 [Winline 搜索](ux/search.md)。
