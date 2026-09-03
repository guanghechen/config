# Diffview Specification

## 概述

`era.m.diffview` 是 Git diff 可视化模块，提供 side-by-side diff 视图和 commit 日志查看功能。

## 核心功能

| 功能          | TabType              | 描述                                                                                            |
|:--------------|:---------------------|:------------------------------------------------------------------------------------------------|
| Git Workspace | `diffview_workspace` | 查看 staged/unstaged 文件变更与 repository History，右侧显示 side-by-side diff                  |
| Git Log       | `diffview_commits`   | 查看 commit 历史，支持 path_filter 过滤特定文件/目录，支持展开查看每个 commit 的变更文件及 diff |

> **File History**: 通过 `diffview_commits + path_filter` 实现。当设置 path_filter 时，tabline 会显示过滤的文件名，commit 列表只显示涉及该文件的 commits。

## 入口与 workspace composition

- `<leader>gg` 是唯一 repository-level Git 入口，打开 `diffview_workspace`。
- workspace 左侧从上到下组合 Staged、Unstaged 与 History，右侧共享一组 SBS windows；默认 focus Changes。
- History 复用 commits pane/state/action，但 working-tree state 与 commit-log state 继续独立持有。
- workspace view 持有共享 SBS preview generation；最后一次 Changes 或 History selection 是唯一 preview writer。
- SBS buffer 可以跨 Diffview tab 复用；buffer-local keymap 在执行时按当前 tab 解析 view context，不持有安装时的 context。
- `<leader>et` 将 Staged、Unstaged 与 History 视为一个 sidebar，统一隐藏或恢复。
- `<leader>gf` 继续打开带 path_filter 的独立 `diffview_commits`，服务 File History。
- repository History 先创建 pane，再异步获取 Git log，不阻塞 workspace layout 首次呈现。

## TabType

每种视图对应独立的 tabtype，便于精细化控制命令和 UI 行为：

```lua
stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE     -- "diffview_workspace"
stl.e.TabTypeEnum.DIFFVIEW_COMMITS       -- "diffview_commits"

-- 便捷集合
stl.e.TabTypeSet.DIFFVIEW  -- 包含所有两种 diffview 类型
```

## 模块结构

```
era.m.diffview/
├── init.lua          # 入口，导出公共 API
├── types.lua         # 类型定义
├── config.lua        # 常量配置
├── util.lua          # 通用工具函数 + 窗口辅助函数
├── layout.lua        # 窗口分割工具（树形布局描述）
├── nvimbar.lua       # nvimbar 集成
├── data.lua          # Git 数据获取
├── fn.lua            # 公共函数入口
├── cmd.lua           # 命令定义
│
├── pane/             # 可复用渲染单元（只负责渲染+数据，不管窗口布局）
│   ├── filetree.lua  # 通用文件树（用于 commits 展开的文件列表）
│   ├── changes.lua   # workspace 专用的 staged/unstaged 双树
│   ├── commits.lua   # Commit 列表
│   └── sbs.lua       # Side-by-side diff（含 git 内容加载、diff 模式）
│
└── view/             # 视图控制器（管理布局+pane组合+状态+交互）
    ├── workspace/
    │   ├── view.lua      # 布局管理、pane 组合、生命周期
    │   ├── state.lua     # workspace 专属状态
    │   ├── tabline.lua   # workspace tabline
    │   ├── winline.lua   # History pane winline
    │   ├── action.lua    # workspace 用户操作
    │   └── keymap.lua    # workspace 快捷键
    └── commits/
        ├── view.lua      # 支持 path_filter 的 commits 视图
        ├── state.lua     # commits 状态（含 path_filter 字段）
        ├── tabline.lua   # commits tabline（带 filter 显示）
        ├── action.lua
        └── keymap.lua
```

### 架构分层

| 层      | 模块                 | 职责                                         |
|:--------|:---------------------|:---------------------------------------------|
| Pane    | `pane/*.lua`         | 纯渲染 + 数据管理，不知道窗口在哪            |
| View    | `view/*/view.lua`    | 创建/销毁窗口、布局切换、组合 pane、生命周期 |
| State   | `view/*/state.lua`   | 该视图的响应式状态（Observable）             |
| Tabline | `view/*/tabline.lua` | 该视图的 tabline 渲染                        |
| Action  | `view/*/action.lua`  | 该视图的用户操作（stage/unstage/选择文件等） |
| Keymap  | `view/*/keymap.lua`  | 该视图的快捷键绑定                           |
| Layout  | `layout.lua`         | 工具方法：根据树形结构创建窗口分割           |
| Nvimbar | `nvimbar.lua`        | nvimbar 集成（被各 tabline 使用）            |

### 四种 Pane

| Pane     | 文件                | 用途                   | 使用者                  |
|:---------|:--------------------|:-----------------------|:------------------------|
| filetree | `pane/filetree.lua` | 通用文件树/列表        | commits view            |
| changes  | `pane/changes.lua`  | staged + unstaged 双树 | workspace view          |
| commits  | `pane/commits.lua`  | Commit History 列表    | workspace、commits view |
| sbs      | `pane/sbs.lua`      | side-by-side diff      | 所有 view               |

## 模块依赖

| 依赖模块           | 用途           |
|:-------------------|:---------------|
| `era.m.git.diff`   | Diff 算法      |
| `era.m.git.cmd`    | Git 命令执行   |
| `era.m.git.status` | Git 状态解析   |
| `stl.c.Filetree`   | 文件树数据结构 |
| `stl.c.Observable` | 响应式状态管理 |

## Filetype

| Filetype           | Pane     | 用途                                    |
|:-------------------|:---------|:----------------------------------------|
| `DiffviewChanges`  | changes  | workspace 左侧的 staged + unstaged 双树 |
| `DiffviewFiletree` | filetree | commits 的文件列表                      |
| `DiffviewCommits`  | commits  | commit 列表面板                         |
| `diffview-sbs`     | sbs      | Side-by-side diff 视图（左右窗口共用）  |

> 注意：这些是自定义 filetype，由 `dot/tab.lua` 用于检测 diffview tab。

## 命令

| 命令                       | 描述                                                     |
|:---------------------------|:---------------------------------------------------------|
| `Fdiffviewclose`           | 关闭 Diffview Tab                                        |
| `Fdiffviewopencommits`     | 打开 Git Log 视图                                        |
| `Fdiffviewopenfilehistory` | 打开当前文件的历史视图（实际调用 commits + path_filter） |
| `Fdiffviewopenworkspace`   | 打开 Git Diff 视图（staged/unstaged）                    |
| `Fdiffviewrefresh`         | 刷新当前 Diffview                                        |
| `Fdiffviewtogglecommits`   | 切换 workspace History / commits 面板显示                |
| `Fdiffviewtogglefiles`     | 切换 workspace sidebar / commits filetree                |

## 布局设计

> 详见 [layout.md](./layout.md)

## Diff 模式策略

### 使用 Neovim 内置 Diff 模式

使用 Neovim 内置的 diff 模式（基于 xdiff）：

```lua
-- 窗口选项
local winopts = {
  diff = true,              -- 启用内置 diff 模式
  scrollbind = true,        -- 同步滚动
  cursorbind = true,        -- 同步光标
  foldmethod = "diff",      -- diff 折叠
  foldcolumn = "1",
  foldlevel = 0,
  foldenable = true,
}
```

### 设计决策：为什么使用内置 diff 模式

1. **算法一致性** - Neovim 内置 xdiff 与 git 默认算法一致
2. **滚动同步** - `scrollbind` + `cursorbind` 自动处理
3. **行对齐** - 内置 diff 模式自动处理行对齐和填充
4. **性能** - C 实现的 diff 算法
5. **维护成本** - 复用 Neovim 内置功能

## 高亮隔离策略

### 核心原则

1. 定义专属高亮组：所有 diffview 高亮组使用 `m_dv_*` 前缀
2. 通过 winhighlight 隔离：每个窗口设置 `winhl`，将全局高亮组映射到专属高亮组
3. 使用专属 namespace：所有 extmark 使用 `era.m.diffview` namespace
4. 不修改全局高亮组：绝不修改 `DiffAdd`、`DiffDelete` 等全局高亮

### 高亮组前缀

| 前缀            | 用途              |
|:----------------|:------------------|
| `m_dv_`         | 面板通用          |
| `m_dv_add*`     | Diff 新增内容高亮 |
| `m_dv_del*`     | Diff 删除内容高亮 |
| `m_dv_ft_*`     | 文件树面板高亮    |
| `m_dv_commit_*` | Commit 列表高亮   |
| `m_dv_winbar*`  | Winbar 高亮       |

### winhighlight 隔离

左侧窗口（显示 old 版本）和右侧窗口（显示 new 版本）使用不同的 winhighlight 映射：

- 左侧：`DiffAdd` → `m_dv_del`（新增行在旧版本中不存在，显示为删除样式）
- 右侧：`DiffAdd` → `m_dv_add`（正常显示新增样式）

## 数据类型

### IFileEntry

```lua
---@class era.m.diffview.IFileEntry
---@field public filepath       string              -- 相对路径
---@field public status         string              -- Git 状态码 (A/M/D/R/?)
---@field public stage_type     "staged"|"unstaged"|nil
---@field public insertions     integer|nil         -- 新增行数
---@field public deletions      integer|nil         -- 删除行数
```

### ICommit

```lua
---@class era.m.diffview.ICommit
---@field public hash           string              -- 完整 commit hash
---@field public abbrev_hash    string              -- 缩写 hash
---@field public author         string              -- 作者名
---@field public date           integer             -- Unix 时间戳
---@field public message        string              -- Commit 消息 (首行)
---@field public files          era.m.diffview.IFileEntry[]|nil  -- 变更文件列表 (懒加载)
---@field public file_status    string|nil          -- 文件状态 (path_filter 模式)
---@field public filepath       string|nil          -- 文件路径 (path_filter 模式)
---@field public parent_filepath string|nil         -- 父路径 (重命名/复制)
---@field public file_insertions integer|nil        -- 新增行数 (path_filter 模式)
---@field public file_deletions integer|nil         -- 删除行数 (path_filter 模式)
```

## 状态管理

每个 domain 独立维护自己的状态，存储在 `view/*/state.lua` 中。使用 `stl.c.Observable` 实现响应式更新。
workspace tab 同时组合一个 workspace state 与一个无 path_filter 的 commits state；二者只通过 workspace
持有的 layout 和 preview ownership 协作，不相互写入 domain state。
workspace view 拥有组合 layout 与 panel buffers；无论通过 close action 还是直接关闭 tab，都必须释放这些资源。

### workspace state

```lua
---@class era.m.diffview.view.workspace.State
---@field public tabnr             integer                 -- Tab 页号
---@field public layout            integer                 -- 当前布局 (1-3)
---@field public fold_unchanged    boolean                 -- 当前 view 是否折叠 unchanged hunks
---@field public entries           stl.c.Observable        -- IFileEntry[] (staged + unstaged)
---@field public current_entry     stl.c.Observable        -- IFileEntry|nil
---@field public collapsed_dirs    table<string, boolean>  -- 折叠的目录
---@field public display_mode      "tree"|"list"           -- 显示模式
```

### commits state

```lua
---@class era.m.diffview.view.commits.State
---@field public tabnr             integer                 -- Tab 页号
---@field public fold_unchanged    boolean                 -- 当前 view 是否折叠 unchanged hunks
---@field public layout            integer                 -- 当前布局 (1-5)
---@field public path_filter       string|nil              -- 路径过滤（文件/目录），nil 为全量
---@field public commits           stl.c.Observable        -- ICommit[]
---@field public current_commit    stl.c.Observable        -- ICommit|nil
---@field public current_file      stl.c.Observable        -- IFileEntry|nil (布局5用)
---@field public expanded_commits  stl.c.Observable        -- table<string, boolean>
---@field public page              stl.c.Observable        -- integer (1-indexed)
---@field public total             stl.c.Observable        -- integer (commit 总数)
```

### Diff fold state

`dot.context.diffview.flag_fold_unchanges` 是持久的 global default。创建 workspace 或 commits view 时，
其值被复制到对应 `State.fold_unchanged`，之后由该 view 独立持有当前 fold policy。

- `t3` / status flag：切换 global default，并立即同步当前 view。
- `zR`：只展开当前 view 的 left/right diff panes，不修改 global default。
- `zM`：只折叠当前 view 的 left/right diff panes，不修改 global default。
- 当前 view 内切换文件或 layout 时保留 per-view policy；关闭后重新打开则再次使用 global default。

### Untracked visibility

`dot.context.diffview.flag_untracked` 持久化 workspace Changes pane 是否显示 untracked files，默认开启。
该 flag 只过滤 view projection；完整 Git snapshot 仍保留在 workspace state，refresh identity、staging 和
discard contract 不受影响。隐藏当前选中的 untracked entry 时，workspace 会选择 Changes pane 中第一个
剩余可见 file row，或在没有可见 file row 时清空 SBS preview。

- `t4` / status flag：显示或隐藏 untracked files。
- `³`：新 Diffview 的默认 fold policy。
- `󰡯⁴`：untracked visibility。

## History / Commits 分页

workspace History 与 Git Log 视图 (`diffview_commits`) 复用同一套分页 commit state：

History pane 使用 window-owned Nvimbar composition：左侧显示 commit 总数和当前 `page/page_count`，
右侧复用通用 `search_count` component；pagination 与 search state 均驱动同一 Nvimbar 更新。

### 分页设计

- **每页数量**：`config.COMMITS_PER_PAGE = 50`
- **Tabline 显示**：`󰊢 Commits (1523) | Page 1/31`
- **翻页快捷键**：
  - `]]` - 下一页
  - `[[` - 上一页

### 数据流

```
打开 commits 面板
    ↓
fetch_log_count() - 获取 commit 总数
    ↓
fetch_log_page(1, 50) - 获取第一页（含 shortstat）
    ↓
渲染 commits 面板 + 更新 tabline 分页信息

用户按 ]p
    ↓
page = min(page + 1, total_pages)
    ↓
fetch_log_page(page, 50)
    ↓
重绘 commits 面板 + 更新 tabline
```

### 注意事项

- 带 path_filter 时也支持分页（单文件历史可能很长）
- 翻页时清除所有 expanded_commits 状态
- 每次翻页都重新获取 shortstat 数据
- `g/` 在当前 log（包括 path_filter）中跨页搜索：至少 4 位 hash prefix 优先匹配且必须唯一，否则按 commit message 进行 case-insensitive substring 匹配并选择最新结果
- search、翻页和 refresh 共享 per-view content generation；只有最新 request 可以提交 state，关闭 view 会使所有在途 request 失效并拒绝后续 request
- 搜索使用同一 Git-log snapshot 的 position 与 total，并原子更新 total、page、commits 和 current commit
- 分页分别跟踪 requested page 与 applied page：连续翻页累积 intent，search/refresh supersede pending page 时恢复 applied page

## Buffer 管理

### Buffer 类型

| 类型          | buftype   | modifiable | 用途                            |
|:--------------|:----------|:-----------|:--------------------------------|
| filetree      | `nofile`  | `false`    | 文件树面板                      |
| commits       | `nofile`  | `false`    | Commit 列表                     |
| sbs_old       | `nowrite` | `false`    | Side-by-side 左侧（旧版本）     |
| sbs_new_local | -         | `true`     | Side-by-side 右侧（工作区文件） |
| sbs_new_index | `nowrite` | `false`    | Side-by-side 右侧（index 版本） |
| null          | `nofile`  | `false`    | 空文件占位（新增/删除文件时）   |

### 窗口选项保存与恢复

对于工作区文件，需要保存原始窗口选项，关闭 diffview 时恢复。

## 快捷键

快捷键按 view 独立定义在 `view/*/keymap.lua` 中。

### 通用快捷键（所有 view 共享）

| 按键         | 功能                                                  |
|:-------------|:------------------------------------------------------|
| `g?`         | 显示快捷键帮助                                        |
| `<C-a>r`     | 刷新（别名 `<D-r>`）                                  |
| `<leader>er` | 在 navigation panel 定位当前项；已位于该 panel 时隐藏 |

### workspace 快捷键

**changes pane**

| 按键            | 功能                |
|:----------------|:--------------------|
| `<CR>`          | 选择文件 / 切换展开 |
| `<2-LeftMouse>` | 选择文件 / 切换展开 |
| `J`             | 向下移动并选择      |
| `K`             | 向上移动并选择      |
| `gs`            | Stage 文件          |
| `gu`            | Unstage 文件        |
| `gr`            | Reset 文件          |
| `oc`            | 复制文件路径        |
| `t1`            | 切换显示模式        |
| `t2`            | 切换紧凑目录路径    |
| `t3`            | 切换默认 diff 折叠  |
| `t4`            | 显示/隐藏 untracked |
| `zC`            | 折叠当前 view diff  |
| `zM`            | 折叠当前 view diff  |
| `zO`            | 展开当前 view diff  |
| `zR`            | 展开当前 view diff  |
| `gf`            | 在之前的 tab 打开   |
| `gF`            | 在新 tab 打开       |

**sbs pane**

| 按键    | 功能                |
|:--------|:--------------------|
| `<C-j>` | 下一个 diff         |
| `<C-k>` | 上一个 diff         |
| `za`    | 切换折叠            |
| `zo`    | 展开折叠            |
| `zc`    | 收起折叠            |
| `t3`    | 切换默认 diff 折叠  |
| `t4`    | 显示/隐藏 untracked |
| `zC`    | 折叠当前 view diff  |
| `zM`    | 折叠当前 view diff  |
| `zO`    | 展开当前 view diff  |
| `zR`    | 展开当前 view diff  |
| `gf`    | 在之前的 tab 打开   |
| `gF`    | 在新 tab 打开       |

### commits 快捷键

> 详见 [keybinding.md](./keybinding.md)

## 设计决策

### 为什么 Pane 和 View 分离？

1. **职责单一** - Pane 只负责渲染和数据，View 负责窗口布局和用户交互
2. **复用性** - sbs pane 被所有 view 复用
3. **可测试** - Pane 的渲染逻辑可以独立测试，不依赖窗口环境

### 为什么每个 View 独立维护状态？

1. **隔离性** - 不同 view 的状态互不影响
2. **清晰性** - 状态定义在使用它的 view 旁边，便于理解
3. **简化** - 不需要复杂的状态分发逻辑

### 为什么 changes pane 不复用 filetree pane？

1. **数据结构不同** - changes 需要同时展示 staged 和 unstaged 两个分区
2. **交互不同** - changes 支持 stage/unstage 操作，filetree 只支持选择
3. **渲染不同** - changes 需要绘制分区标题和分隔线

### 为什么文件树使用单 buffer 双树？

1. **简化窗口管理** - 只需管理一个窗口
2. **统一滚动** - 两棵树在同一个 buffer 中
3. **视觉一致** - 采用主流 diff 视图设计

### 为什么不复用 `era.m.explorer`？

1. **不同的数据模型** - explorer 是完整文件系统树，diffview 只需要变更文件列表
2. **不同的交互** - explorer 支持文件操作，diffview 只需要选择和查看
3. **简化实现** - diffview 的文件树渲染更简单

### 为什么在独立 tab 中运行？

1. **布局隔离** - 不影响用户现有的窗口布局
2. **状态独立** - 关闭 tab 即可完全清理状态
3. **用户预期** - 独立 tab 提供干净的工作环境

## 已知限制

1. 暂不支持 merge conflict 解决
2. 暂不支持非 git 仓库的 diff
3. 暂不支持 inline diff 视图（只支持 side-by-side）
