# Git 模块

这是一个轻量级的 Git 集成模块，用于替代 gitsigns.nvim，提供 Git 状态追踪、Hunk 管理、Sign 显示和 Blame 功能。

## 模块架构

```
era.m.git/
├── init.lua      -- 入口，初始化 watcher、autocmd、暴露公共 API
├── state.lua     -- 全局状态管理（branch、staged/unstaged files、status cache）
├── repo.lua      -- Git 仓库抽象，封装常用操作，支持 worktree (commondir)
├── cmd.lua       -- Git 命令封装（async/sync）
├── watcher.lua   -- 文件系统监听（gitdir、index、commondir）
├── buffer.lua    -- Buffer 级别的 Hunk 计算和缓存
├── hunk.lua      -- Hunk 数据、查询和 stage/unstage/reset 操作
├── hunk_nav.lua  -- Hunk navigation state、普通 buffer 与 diff window 导航
├── sign.lua      -- Sign 显示（使用 decoration provider）
├── diff.lua      -- Diff 算法（基于 vim.diff + word-level diff）
├── status.lua    -- Git status 解析和聚合
├── blame.lua     -- Inline blame 和 buffer blame
├── browse.lua    -- 在浏览器中打开文件
└── types.lua     -- 类型定义
```

## 状态管理

### state.lua

维护全局 Git 状态，使用 `stl.c.Observable` 实现响应式更新：

```lua
M.o_branch          -- Observable<string>: 当前分支名
M.o_current_blame   -- Observable<BlameInfo|nil>: 当前光标位置的 blame 信息
M.o_staged_files    -- Observable<string[]>: 已暂存的文件列表
M.o_unstaged_files  -- Observable<string[]>: 未暂存的文件列表
```

内部缓存结构 `state_cache`:
- `status_table`: 文件级别的 git status 详情
- `file_display/file_stage/file_summary`: 文件状态的快速查询表
- `dir_display/dir_stage/dir_summary/dir_codes`: 目录状态的聚合信息
- `ignored`: 被 .gitignore 忽略的文件缓存

### 数据流

```

┌─────────────┐              ┌────────────────┐              ┌──────────────────┐
│   watcher   │  文件变化    │ state.refresh  │    触发      │ buffer.refresh   │
│             │ ──────────>  │    _async()    │ ──────────>  │     _all()       │
└─────────────┘              └────────────────┘              └──────────────────┘
                                    │
                                    ▼
                             ┌────────────────┐
                             │  Observable    │
                             │    .next()     │
                             └────────────────┘
                                    │
                                    ▼
                      订阅者（statusline、filetree 等）
```

## 文件监听

### watcher.lua

通过 `vim.uv.new_fs_event()` 监听 Git 目录变化，支持普通仓库和 worktree：

#### Git 目录结构

**普通仓库：**
```
project/
└── .git/                    # gitdir
    ├── HEAD                 # 当前分支引用
    ├── index                # staging area
    ├── refs/heads/          # 本地分支
    └── refs/remotes/        # 远程分支
```

**Worktree：**
```
main-repo/
└── .git/                              # commondir (主 git 目录)
    ├── refs/heads/                    # 所有分支的 refs 存储在这里
    ├── objects/                       # 所有 git objects
    └── worktrees/my-worktree/         # gitdir (worktree 专属目录)
        ├── HEAD                       # 内容: "ref: refs/heads/<branch>"
        ├── index                      # worktree 的 staging area
        └── commondir                  # 内容: "../.." (指向主 git 目录)

my-worktree/
└── .git                               # 文件，内容指向 gitdir
```

#### Watcher 架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              watcher.lua                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────┐  ┌──────────────────────────────┐   │
│  │         fs_watcher_dir             │  │    fs_watcher_commondir      │   │
│  │                                    │  │      (worktree only)         │   │
│  │  监听: gitdir/                     │  │  监听: commondir/refs/heads  │   │
│  │  处理: HEAD、refs、index 变化      │  │  处理: 分支 refs 变化        │   │
│  └──────────────┬─────────────────────┘  └──────────────┬───────────────┘   │
│                 │                                       │                    │
│                 ▼                                       ▼                    │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        事件过滤                                      │    │
│  │  - 忽略 index.lock、.watchman-cookie                                │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                 │                                       │                    │
│                 ▼                                       ▼                    │
│  ┌────────────────────────────────────┐  ┌──────────────────────────────┐   │
│  │  filename == "index"?              │  │      on_fs_event             │   │
│  │  ├─ Yes → on_index_event           │  │                              │   │
│  │  └─ No  → on_fs_event              │  │      分支文件变化            │   │
│  │          (HEAD/refs 变化)          │  │      触发全量刷新            │   │
│  └──────────────┬─────────────────────┘  └──────────────┬───────────────┘   │
│                 │                                       │                    │
└─────────────────┼───────────────────────────────────────┼────────────────────┘
                  │                                       │
                  ▼                                       ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                          buffer.lua 刷新策略                                  │
├───────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  invalidate_compare_text_all()          invalidate_index_all()                │
│  ┌─────────────────────────────┐        ┌─────────────────────────────┐      │
│  │ 清除:                       │        │ 清除:                       │      │
│  │ - compare_text (HEAD)       │        │ - compare_text_index        │      │
│  │ - compare_text_index        │        │ - object_name               │      │
│  │ - object_name               │        │                             │      │
│  │                             │        │ 触发场景:                   │      │
│  │ 触发场景:                   │        │ - git add/reset (stage)     │      │
│  │ - git commit                │        │ - 内部 stage/unstage 操作   │      │
│  │ - git checkout              │        │                             │      │
│  │ - git reset --hard          │        │                             │      │
│  │ - 外部 commit (worktree)    │        │                             │      │
│  └─────────────────────────────┘        └─────────────────────────────┘      │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

#### 事件触发矩阵

| Git 操作                     | gitdir 变化 | index 变化 | commondir 变化 | 刷新动作                    |
|:-----------------------------|:------------|:-----------|:---------------|:----------------------------|
| `git add`                    | -           | ✓ index    | -              | `invalidate_index_all`      |
| `git reset <file>`           | -           | ✓ index    | -              | `invalidate_index_all`      |
| `git commit` (本地)          | ✓ HEAD      | ✓ index    | -              | `invalidate_compare_text_all` |
| `git commit` (外部 worktree) | -           | ✓ index    | ✓ refs/        | `invalidate_compare_text_all` |
| `git checkout`               | ✓ HEAD      | ✓ index    | -              | `invalidate_compare_text_all` |
| `git pull/fetch`             | ✓ FETCH_HEAD | -          | -              | `mark_dirty_all` + status 刷新 |

#### Debounce 策略

- **gitdir/commondir 事件**: 150ms debounce，合并多个事件
- **index 事件**: 100ms debounce，快速响应 stage/unstage

#### fs_event 行为差异

**重要发现**：libuv 的 `fs_event` 监听单个文件 vs 监听目录时行为不同：

| 监听方式                          | `git add` | `git reset`/`git unstage` |
|:----------------------------------|:----------|:--------------------------|
| 文件级 (`fs_event` on `index`)    | ✓ 触发    | ✗ 可能丢失                |
| 目录级 (`fs_event` on `gitdir/`)  | ✓ 触发    | ✓ 触发                    |

原因：Git 不同操作使用不同的写入策略：
- `git add`：直接写入 index 文件
- `git reset`：可能通过 rename `index.lock` → `index` 实现原子写入

**解决方案**：仅使用目录级 `fs_watcher_dir` 监听 gitdir，当检测到 `index` 文件变化时调用 `on_index_event()`。这比文件级监听更可靠，且避免了重复事件。

#### Worktree 支持

通过 `repo.lua` 的 `resolve_commondir()` 函数读取 `gitdir/commondir` 文件获取主 git 目录路径。
当检测到 commondir 存在且与 gitdir 不同时，额外启动 `fs_watcher_commondir` 监听 `commondir/refs/heads/` 目录。

**重要**：libuv `fs_event` 不会递归监听子目录，所以必须直接监听 `refs/heads/` 目录才能检测到分支文件的变化。

这解决了 worktree 场景下 commit 无法检测的问题：
- 普通仓库：commit 后 `gitdir/refs/heads/<branch>` 变化，`fs_watcher_dir` 能检测到
- Worktree：commit 后 `commondir/refs/heads/<branch>` 变化，需要 `fs_watcher_commondir` 检测

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
3. `hunks_staged = filter_common(hunks_head, hunks)` - 仅存在于 HEAD→Index 的变更（已暂存）

### 生命周期

- `BufReadPost/BufNewFile`: 自动 attach
- `BufWritePost`: 强制刷新 compare_text
- `BufDelete`: detach
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
|:-------------|:-----|:-----------------------|
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
M.ai_textobject()              -- mini.ai 的 unstaged hunk regions
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

Hunk navigation module 持有单一 transient state `{ winnr, bufnr, index, total }`。普通 buffer navigation
从 attached hunks 计算位置；two-pane diff navigation 先执行一次原生 `[c`/`]c`，再从两侧
`era.m.git.staging.from_buffer()` document lines 构建共享的 canonical hunk map。Document contract
保留 empty bytes、single final newline 与 missing final newline 的差异。Diff 输入按 layout semantic order
排列：side-by-side 为 left→right，stacked layout 为 top→bottom，不依赖 buffer allocation order。Map
复用普通 buffer 的 `era.m.git.diff.run_diff()` histogram contract；pane-local `linematch` 只影响 native
cursor target，不拆分 canonical Git hunk。每个 hunk 在两侧具有同一 index/total，zero-count side 映射到
BOF、ordinary filler 或 EOF anchor。同一 anchor 可对应多个 hunk；native motion no-op/error 时不合成额外
logical selection。Source 精确位于 canonical hunk 时 no-op 可继续显示 current index；source 位于所有
canonical ranges 外时不发布 indicator。
非 two-pane diff layout fallback 到 pane-local native enumeration；内部 fallback motion 使用 `keepjumps`，
并临时关闭、恢复 `cursorbind`/`scrollbind`。

Canonical map 由 hunk navigation module 单独缓存。Cache identity 包含 ordered window pair、两侧 `bufnr`、
`changedtick` 和 `endofline`；任一输入变化都会重建。一次构建生成两侧有序 line ranges。Navigation
在 motion 前解析两侧共享 canonical source。每侧优先以 native target line 做 binary lookup；target 落在
alignment gap 时，根据 source line 和 direction 单调推进，并在 canonical 边界 clamp 到 current hunk。
两侧 `cursorbind` 时，target candidate 冲突由 shared resolver 统一处理：next 取较大 index，prev 取较小
index。若一次 native motion 仍停留在精确命中的 source hunk 内，则以 `keepjumps` 继续同方向 native motion，
直到 canonical index 改变或 active cursor no-op；从精确 source hunk 发生的 transition 最终 clamp 为相邻
canonical index，target candidate 只证明已经离开 current hunk，不能造成跨级跳转。Continuation 次数由
`linematch:N` 限定。Source 位于 hunk 外时首次到达 estimated index 即停止，避免跳过首个 hunk。首次
motion 保留用户 jump，continuation 不写入额外 jumplist entry。后续按键不再同步遍历所有 hunks。

右侧 presentation 统一为红色 `<git-icon> index/total`，不带方括号。普通 source window 使用 winline
component；`diffview://` static winbar 复用同一 renderer。Indicator 不使用 buffer virtual text，因此不受 line
length、horizontal scroll 或 inline blame 影响。

State 只对仍显示 captured buffer 的 source window 可见。Cursor movement、window focus、Git refresh 和
同一 buffer 的 peer window lifecycle 都不清理 indicator。新 navigation 会替换旧 state；source window
进入不同 buffer、source window 关闭或统一 `<Esc>` handler 调用 `clear_nav()` 时才清理。Buffer lifecycle
监听通过 `BufEnter` 验证 captured `winnr + bufnr` identity，并通过 `WinClosed` event match 识别
captured window，避免 `BufLeave` 把单纯的 window focus change 误判为 source buffer replacement。

### 操作模式规则

**Normal Mode:**
- 只对当前光标所在行所属的 hunk 生效
- Stage: 作用于 unstaged hunk
- Unstage: 作用于 staged hunk
- Reset: 作用于 unstaged hunk

**Visual Mode:**
- 选中 [Li, Lj] 行后，找到这些行所覆盖的所有 hunks
- Stage/Unstage: 依次处理每个被选中的 hunk
- Reset: **只作用于 unstaged hunks**，忽略所有 staged hunks

### Stage/Unstage 实现

**Stage Hunk:**
1. 如果是 untracked 文件，先执行 `git add --intent-to-add`
2. 生成 unified diff patch
3. 执行 `git apply --cached --unidiff-zero`

**Unstage Hunk:**
1. 获取 HEAD 和 Index 内容
2. 应用 inverted hunks 计算新的 index 内容
3. `git hash-object -w` 写入新内容
4. `git update-index --cacheinfo` 更新索引

## Diff 算法

### diff.lua

- 使用 `vim.diff()` 配合 histogram 算法计算行级 diff
- 提供 `filter_common()` 分离 staged/unstaged hunks
- 支持 word-level diff 用于 hunk preview

## Blame 功能

### blame.lua

提供两种 blame 模式：

**Inline Blame（虚拟文本）：**
- 延迟 2000ms 后显示
- 仅查询当前行（`git blame -L lnum,lnum`）
- 光标移动时自动更新

**Buffer Blame（整个文件）：**
- 一次性获取整个文件的 blame 信息
- 在第 80 列显示
- 当前行不显示（配合 inline blame）

## Git Status 解析

### status.lua

解析 `git diff --name-status` 和 `git ls-files` 输出：

状态码映射：

| 码 | 含义     | 优先级 |
|:---|:---------|:-------|
| U  | 冲突     | 1      |
| ?  | 未追踪   | 2      |
| M  | 修改     | 4      |
| D  | 删除     | 8      |
| A  | 新增     | 16     |
| R  | 重命名   | 32     |
| C  | 复制     | 64     |
| T  | 类型变更 | 128    |
| !  | 忽略     | 256    |

Stage 状态：
- `staged`: 仅有已暂存变更
- `unstaged`: 仅有未暂存变更
- `mixed`: 同时有已暂存和未暂存变更

## 公共 API

```lua
local git = era.m.git

-- 状态查询
git.get_branch()                    -- 获取当前分支名
git.state.o_staged_files:snapshot() -- 获取已暂存文件列表
git.state.o_unstaged_files:snapshot() -- 获取未暂存文件列表
git.state.status_table()            -- 获取完整 status 表

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

## 设计决策

1. **单仓库支持**：简化实现，不支持 monorepo 或嵌套仓库
2. **无配置选项**：所有配置为常量，简化维护
3. **仅支持 staged hunks**：unstaged 文件不计算 hunk（性能考量）
4. **使用 vim.diff**：利用 Neovim 内置 diff 算法，无需外部依赖
5. **decoration provider**：高性能 sign 渲染，仅渲染可见区域
