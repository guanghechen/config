# Minimap 模块设计文档

## 概述

`era.m.minimap` 是一个基于 satellite.nvim 架构的 scrollbar/minimap 模块，在窗口右侧显示一个浮动的滚动条，用于展示文档概览和快速导航。

## 架构

```
era.m.minimap/
├── init.lua          # 模块入口，enable/disable、命令注册、autocmd
├── view.lua          # 核心渲染引擎（scrollbar 窗口的创建、更新、销毁）
├── handlers.lua      # Handler 系统框架（注册、初始化、渲染协调）
├── util.lua          # 工具函数（位置映射、fold 处理、窗口计算）
├── mouse.lua         # 鼠标交互（点击、拖拽滚动）
├── autocmd.lua       # 自动命令（搜索状态监听、mark 事件）
├── types.lua         # 类型定义
└── handlers/         # Handler 实现
    ├── cursor.lua    # 光标位置
    ├── search.lua    # 搜索结果高亮
    ├── diagnostic.lua# LSP 诊断
    ├── git.lua       # Git 变更（基于 era/m/git/）
    ├── marks.lua     # Vim 标记
    └── quickfix.lua  # Quickfix 列表
```

注：异步操作使用 `stl.async` 标准库模块。

### 依赖关系

```
types.lua (纯类型)
    ↓
util.lua (工具) ← stl.async (异步，来自标准库)
    ↓
handlers.lua (Handler 框架)
    ↓
handlers/*.lua (各 Handler 实现)
    ↓
view.lua (视图渲染) ← mouse.lua (鼠标交互)
    ↓
init.lua (模块入口) ← autocmd.lua (事件监听)
```

### 与现有模块的集成

| 依赖模块                       | 用途                     |
|:-------------------------------|:-------------------------|
| `era.m.git.buffer`             | 获取 buffer 的 hunk 信息 |
| `era.m.git.hunk`               | 订阅 hunk 变化、计算 sign |
| `dot.context.workspace.plugin` | minimap 启用 flag        |
| `dot.theme.hlgroup`            | highlight group 定义     |
| `dot.command`                  | 命令注册                 |

## 核心概念

### Scrollbar 窗口

- 使用 `nvim_open_win` 创建的 floating window
- `relative = 'win'`：相对于源窗口定位
- `focusable = false`：不可获得焦点
- 宽度为 1 列
- 高度等于源窗口高度
- 位置固定在源窗口右侧

### 位置映射

将 buffer 行号映射到 scrollbar 行号：

```
buffer 行号 → virtual 行数（考虑 fold）→ scrollbar 行号

公式：scrollbar_pos = round(virtual_pos / total_virtual_lines * scrollbar_height)
```

### Handler 系统

每个 Handler 负责渲染一种类型的标记：

```lua
---@class era.m.minimap.IHandler
---@field public name                 string
---@field public config               era.m.minimap.IHandlerConfig
---@field public ns                   integer          -- namespace
---@field public enabled              fun(): boolean
---@field public setup                fun(config, update)? -- 初始化（可选）
---@field public update               fun(bufnr, winnr): era.m.minimap.IMark[]
```

```lua
---@class era.m.minimap.IMark
---@field public pos                  integer          -- scrollbar 行号
---@field public highlight            string           -- highlight group
---@field public symbol               string           -- 显示符号（单字符）
---@field public unique               boolean?         -- 是否强制显示（即使位置重复）
```

### 显示模式

仅支持 **Overlay 模式**：
- 标记使用虚拟文本覆盖在 scrollbar 背景上
- 宽度最小化（仅 1 列）
- 通过优先级系统解决同位置标记冲突

## 配置

采用硬编码配置，无需动态配置系统：

```lua
-- 在 var.lua 或 init.lua 中定义常量
local WINBLEND = 50           -- 透明度
local ZINDEX = 40             -- z-index
local MIN_WINWIDTH = 40       -- 最小窗口宽度阈值

-- Handler 优先级（越大越优先显示）
local PRIORITY = {
  cursor = 100,
  marks = 60,
  quickfix = 60,
  diagnostic = 50,
  git = 20,
  search = 10,
}

-- 符号定义
local SYMBOLS = {
  cursor = { '⎺', '⎻', '⎼', '⎽' },      -- 4 级精度
  search = { '·', ':', '⁝' },            -- 按匹配数量选择
  diagnostic = { '-', '=', '≡' },        -- 按数量选择
  git = { add = '│', change = '│', delete = '-' },
  quickfix = { '-', '=', '≡' },
}
```

## Context Flag

在 `dot.context.workspace.plugin` 中添加：

```lua
---@class dot.context.plugin.data
---@field public minimap              boolean
---@field public render_markdown      boolean
---@field public treesitter_context   boolean
---@field public which_key            boolean
```

- 默认值：`false`
- 通过 toggle 系统可切换

## 命令

| 命令              | 功能                                  |
|:------------------|:--------------------------------------|
| `Fminimapattach`  | Attach minimap 到当前窗口             |
| `Fminimapdetach`  | Detach 当前窗口的 minimap             |
| `Fminimapenable`  | 全局启用 minimap（设置 context flag） |
| `Fminimapdisable` | 全局禁用 minimap（设置 context flag） |
| `Fminimaptoggle`  | 切换全局 minimap 状态                 |

**注意**：minimap 不会自动 attach 任何窗口，需要通过命令或 autocmd 手动触发。

## Highlight Groups

在 `lua/dot/theme/hlgroup/module.lua` 中定义（按字母顺序）：

```lua
-- minimap (m_mm_*)
m_mm_bar = { ... },           -- 当前可视区域（滑块）
m_mm_bg = { ... },            -- scrollbar 背景
m_mm_cursor = { ... },        -- 光标位置
m_mm_diagnostic_error = { ... },
m_mm_diagnostic_hint = { ... },
m_mm_diagnostic_info = { ... },
m_mm_diagnostic_warn = { ... },
m_mm_git_add = { ... },
m_mm_git_change = { ... },
m_mm_git_delete = { ... },
m_mm_mark = { ... },
m_mm_quickfix = { ... },
m_mm_search = { ... },
```

在各主题目录下的 `module.lua` 中可覆盖这些定义。

## 模块实现细节

### init.lua

```lua
-- 职责
-- 1. 模块入口，导出公共 API
-- 2. 注册命令
-- 3. 设置 autocmd（WinEnter, WinLeave, WinScrolled 等）
-- 4. 监听 context flag 变化
-- 5. 定义常量（WINBLEND, ZINDEX, MIN_WINWIDTH, PRIORITY, SYMBOLS）

-- 公共 API
M.enable()                -- 全局启用
M.disable()               -- 全局禁用
M.attach(winnr)           -- attach 到指定窗口
M.detach(winnr)           -- detach 指定窗口
M.refresh()               -- 刷新所有 attached 窗口
```

### view.lua

```lua
-- 职责
-- 1. 创建/销毁 scrollbar floating window
-- 2. 渲染 scrollbar 背景和滑块
-- 3. 协调 handler 渲染

-- 核心数据结构
local attached_wins = {}  -- { [source_winnr] = scrollbar_winnr }

-- 核心函数
M.create_view(winnr)      -- 创建 scrollbar 窗口
M.destroy_view(winnr)     -- 销毁 scrollbar 窗口
M.render(winnr)           -- 渲染 scrollbar
M.refresh_all()           -- 刷新所有 scrollbar
M.get_props(winnr)        -- 获取 scrollbar 属性
M.can_show(winnr)         -- 判断是否可显示
```

### util.lua

```lua
-- 职责
-- 1. 位置映射算法
-- 2. Fold 处理
-- 3. 窗口计算

-- 核心函数
M.row_to_barpos(winnr, row)           -- buffer 行 → scrollbar 行
M.virtual_line_count(winnr, start, vend)  -- 计算 virtual 行数
M.get_winheight(winnr)                -- 获取窗口高度（排除 winbar）
M.visible_line_range(winnr)           -- 获取可见行范围
M.virtual_topline_lookup(winnr)       -- 构建位置映射表（用于拖拽）
```

### handlers.lua

```lua
-- 职责
-- 1. Handler 注册与管理
-- 2. Handler 初始化
-- 3. 协调 handler 渲染

-- 核心函数
M.register(spec)          -- 注册 handler
M.init()                  -- 初始化所有 handler
M.render(bufnr, winnr)    -- 调用所有 handler 渲染
```

### mouse.lua

```lua
-- 职责
-- 1. 处理鼠标点击事件
-- 2. 处理拖拽滚动

-- 核心函数
M.handle_leftmouse()      -- 处理左键点击
M.set_topline(winnr, lnum)  -- 滚动到指定行
```

### handlers/cursor.lua

```lua
-- 光标位置 handler
-- 使用 4 种符号表示光标在两行之间的相对位置精度
-- symbols = { '⎺', '⎻', '⎼', '⎽' }

function M.update(bufnr, winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local pos, fraction = util.row_to_barpos(winnr, cursor[1] - 1)
  local symbol_index = math.max(1, util.round((0.5 - fraction) * 4))
  return {
    { pos = pos, highlight = "m_mm_cursor", symbol = symbols[symbol_index] }
  }
end
```

### handlers/search.lua

```lua
-- 搜索结果 handler
-- 缓存搜索结果以优化性能
-- 根据匹配数量选择不同符号

function M.update(bufnr, winnr)
  local pattern = vim.fn.getreg('/')
  if pattern == '' or vim.v.hlsearch == 0 then return {} end

  -- 异步搜索匹配
  local marks = {}
  for lnum, line in async.ipairs(lines) do
    local count = count_matches(line, pattern)
    if count > 0 then
      local pos = util.row_to_barpos(winnr, lnum - 1)
      marks[#marks + 1] = {
        pos = pos,
        highlight = "m_mm_search",
        symbol = symbols[math.min(count, #symbols)],
      }
    end
  end
  return marks
end
```

### handlers/diagnostic.lua

```lua
-- 诊断 handler
-- 缓存诊断信息，监听 DiagnosticChanged 事件
-- 按严重程度使用不同 highlight

function M.update(bufnr, winnr)
  local diagnostics = vim.diagnostic.get(bufnr)
  local marks = {}

  for _, diag in ipairs(diagnostics) do
    if diag.severity <= config.min_severity then
      local pos = util.row_to_barpos(winnr, diag.lnum)
      local hl = severity_to_hl[diag.severity]
      marks[#marks + 1] = {
        pos = pos,
        highlight = hl,
        symbol = symbols[...],
      }
    end
  end
  return marks
end
```

### handlers/git.lua

```lua
-- Git 变更 handler
-- 基于 era.m.git.buffer 获取 hunk 信息
-- 订阅 hunk 变化自动刷新

function M.setup(config, update)
  -- 订阅 hunk 变化
end

function M.update(bufnr, winnr)
  local hunks = era.m.git.buffer.get_unstaged_hunks(bufnr)
  if not hunks then return {} end

  local marks = {}
  for _, hunk in ipairs(hunks) do
    local min_pos = util.row_to_barpos(winnr, hunk.added.start - 1)
    local max_pos = util.row_to_barpos(winnr, hunk.added.start + hunk.added.count - 1)

    for pos = min_pos, max_pos do
      marks[#marks + 1] = {
        pos = pos,
        highlight = "m_mm_git_" .. hunk.type,
        symbol = config.symbols[hunk.type],
      }
    end
  end
  return marks
end
```

### handlers/marks.lua

```lua
-- Vim 标记 handler
-- 监听标记设置/删除事件

function M.update(bufnr, winnr)
  local marks = {}
  for _, mark in ipairs(vim.fn.getmarklist(bufnr)) do
    if is_valid_mark(mark, config) then
      local pos = util.row_to_barpos(winnr, mark.pos[2] - 1)
      marks[#marks + 1] = {
        pos = pos,
        highlight = "m_mm_marks",
        symbol = mark.mark:sub(2),  -- 去掉 ' 前缀
      }
    end
  end
  return marks
end
```

### handlers/quickfix.lua

```lua
-- Quickfix handler
-- 显示当前 buffer 在 quickfix 中的条目

function M.update(bufnr, winnr)
  local qflist = vim.fn.getqflist()
  local marks = {}

  for _, item in ipairs(qflist) do
    if item.bufnr == bufnr then
      local pos = util.row_to_barpos(winnr, item.lnum - 1)
      marks[#marks + 1] = {
        pos = pos,
        highlight = "m_mm_quickfix",
        symbol = symbols[...],
      }
    end
  end
  return marks
end
```

## Fold 支持

位置映射算法需考虑 fold：

```lua
function util.virtual_line_count(winnr, start, vend)
  -- 优先使用 nvim_win_text_height（Neovim 0.11+）
  if vim.api.nvim_win_text_height then
    return vim.api.nvim_win_text_height(winnr, {
      start_row = start,
      end_row = vend,
    }).all
  end

  -- 回退：手动遍历计算
  local vline = 0
  local line = start
  while line <= vend do
    vline = vline + 1
    local foldclosedend = vim.fn.foldclosedend(line)
    if foldclosedend ~= -1 then
      line = foldclosedend  -- 跳过整个 fold
    end
    line = line + 1
  end
  return vline
end
```

## 鼠标交互

### 点击跳转

1. 检测点击是否在 scrollbar 区域内
2. 根据点击位置计算对应的 buffer 行号
3. 滚动窗口到该位置

### 拖拽滚动

1. 捕获 `<LeftMouse>` 事件
2. 进入拖拽循环，持续读取鼠标位置
3. 实时更新窗口 topline
4. 在 `<LeftRelease>` 时结束拖拽

```lua
function M.handle_leftmouse()
  local props = view.get_props(winnr)
  if not is_on_scrollbar(mouse_pos, props) then return end

  -- 拖拽循环
  while true do
    local char = read_input()
    if char == '<LeftRelease>' then break end

    local target_line = get_topline_from_barpos(winnr, mouse_row)
    set_topline(winnr, target_line)
  end
end
```

## 窗口宽度阈值

当源窗口宽度小于 `min_winwidth` 时，自动隐藏 minimap：

```lua
function view.can_show(winnr)
  local width = vim.api.nvim_win_get_width(winnr)
  if width < config.min_winwidth then
    return false
  end
  -- 其他检查...
  return true
end
```

## 实现步骤

### Phase 1: 基础框架

1. 创建目录结构 `lua/era/m/minimap/`
2. 实现 `types.lua` - 类型定义
3. 实现 `util.lua` - 基础工具函数（不含 fold）
4. 实现 `view.lua` - 基础渲染（scrollbar 背景和滑块）

### Phase 2: Handler 系统

5. 实现 `handlers.lua` - Handler 框架
6. 实现 `handlers/cursor.lua` - 光标 handler
7. 实现 `handlers/search.lua` - 搜索 handler（使用 `stl.async`）
8. 实现 `handlers/diagnostic.lua` - 诊断 handler

### Phase 3: Git 集成

9. 实现 `handlers/git.lua` - Git handler（集成 era/m/git/）

### Phase 4: 其他 Handler

10. 实现 `handlers/marks.lua` - 标记 handler
11. 实现 `handlers/quickfix.lua` - Quickfix handler

### Phase 5: 鼠标交互

12. 实现 `mouse.lua` - 鼠标交互

### Phase 6: Fold 支持

13. 扩展 `util.lua` - 添加 fold 处理

### Phase 7: 入口与集成

14. 实现 `init.lua` - 模块入口、命令注册
15. 在 `dot.context.workspace.plugin` 中添加 minimap flag
16. 在 `dot/theme/hlgroup/module.lua` 中添加 highlight groups
17. 在各主题 `module.lua` 中添加主题特定 highlight

### Phase 8: 测试与优化

18. 全面测试所有功能
19. 性能优化（缓存、节流）
20. 边界情况处理

## 性能考量

1. **异步更新**：Handler update 在协程中运行，防止大文件卡顿
2. **缓存**：搜索结果、诊断信息、位置映射表都有缓存
3. **节流**：窗口滚动事件使用防抖
4. **增量更新**：只更新变化的部分
5. **Fold 缓存**：virtual line count 计算结果缓存

## 与 satellite.nvim 的差异

| 差异点           | satellite.nvim         | era.m.minimap              |
|:-----------------|:-----------------------|:---------------------------|
| Git handler      | 基于 gitsigns.nvim     | 基于 era/m/git/            |
| 自动 attach      | 支持                   | 不支持，需手动触发         |
| 显示模式         | overlap + sign column  | 仅 overlay                 |
| 配置系统         | 独立配置               | 集成 context 系统          |
| Highlight        | Satellite* 前缀        | m_mm_* 前缀                |
| 命令前缀         | Satellite*             | Fminimap*                  |

## 已知限制

1. 仅支持手动 attach，不自动 attach
2. 仅支持 overlay 模式，不支持 sign column 模式
3. 不支持 wrap lines 精确计算（与 satellite.nvim 相同）

----------------------------------------------------------------------------------------------------

## Design Decisions

The following are intentional design choices:

- **Manual attach only**: Minimap does not auto-attach to windows. Users control attachment via commands or autocmds. This provides full control and avoids unexpected UI changes.

- **Overlay mode only**: Sign column mode adds complexity and width. Overlay mode is sufficient for most use cases and keeps the UI minimal.

- **Git handler using era/m/git/**: Instead of depending on gitsigns.nvim, we use the existing git module for consistency and to avoid external dependencies.

- **Async framework from stl.async**: The async coroutine wrapper is well-designed for preventing frame drops. We use the standard library implementation rather than reinventing.
