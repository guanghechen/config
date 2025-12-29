# Act Board 组件

## 概述

`era.board.Act` 是一个通用的输入-预览组件，提供输入框与预览窗口的组合 UI。适用于需要用户输入并实时预览结果的场景，如文件移动、复制、删除确认等操作。

## 架构

```
┌─────────────────────────────────────────┐
│ ╭─────────────── Title ───────────────╮ │
│ │ > input text here                   │ │  ← 输入框 (input)
│ ├─────────────────────────────────────┤ │
│ │ preview line 1                      │ │
│ │ preview line 2                      │ │  ← 预览窗口 (preview)
│ │ preview line 3                      │ │
│ ╰─────────────────────────────────────╯ │
└─────────────────────────────────────────┘
```

## API

### 创建实例

```lua
local act = era.board.Act.new({
  name = "my_action",                    -- 唯一标识
  title = "Action Title",                -- 标题栏显示
  initial_input = "default value",       -- 输入框初始值
  preview_lines = 5,                     -- 预览窗口行数
  width = 0.6,                           -- 宽度（0-1 表示百分比，>1 表示像素）
  get_width = function()                 -- 动态计算宽度（优先于 width）
    return 80
  end,
  render_preview = function(bufnr, input)
    -- 渲染预览内容
  end,
  on_input_change = function(input)
    -- 输入变化时的回调（可选）
  end,
  on_confirm = function(input)
    -- 确认时的回调
  end,
  on_cancel = function()
    -- 取消时的回调（可选）
  end,
  keymaps = {},                          -- 额外的快捷键（可选）
})
```

### 方法

| 方法            | 说明                     |
|-----------------|--------------------------|
| `act:open()`    | 打开 Act 面板            |
| `act:close()`   | 关闭 Act 面板            |
| `act:confirm()` | 确认操作并关闭           |
| `act:cancel()`  | 取消操作并关闭           |
| `act:dispose()` | 释放资源                 |

### 快捷键

| 按键        | 功能     |
|-------------|----------|
| `<CR>`      | 确认     |
| `<Esc>`     | 取消     |
| `q`（n 模式）| 取消    |

## render_preview 回调

`render_preview(bufnr, input)` 是核心渲染函数，每当输入变化时自动调用：

- `bufnr`：预览窗口的 buffer 编号
- `input`：当前输入框内容

### 设置预览内容

```lua
render_preview = function(bufnr, input)
  local lines = { "line 1", "line 2", "line 3" }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end
```

### 添加高亮

可以通过 `vim.hl.range` 为预览内容添加高亮：

```lua
local ns = vim.api.nvim_create_namespace("my_preview_ns")

render_preview = function(bufnr, input)
  local lines = { "source -> target" }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  vim.hl.range(bufnr, ns, "f_pk_matches", { 0, 0 }, { 0, 6 })  -- 高亮 "source"
end
```

## 使用示例

### Explorer 移动操作 (mx)

选中文件后使用 `mx` 触发移动操作：

```
选中文件：
- <CWD>/lua/dot/module/clipboard/mac.lua
- <CWD>/lua/dot/module/clipboard/nix.lua

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ ╭──────────────────────────────── 󰆐 Move 2 item(s) ────────────────────────────────────╮│
│ │ > lua/dot/module/clipboard/                                                          ││
│ ├──────────────────────────────────────────────────────────────────────────────────────┤│
│ │ lua/dot/module/clipboard/mac.lua -> lua/dot/module/clipboard/mac.lua                 ││
│ │ lua/dot/module/clipboard/nix.lua -> lua/dot/module/clipboard/nix.lua                 ││
│ ╰──────────────────────────────────────────────────────────────────────────────────────╯│
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

输入 `lua/dot/haha` 后预览更新：

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ ╭──────────────────────────────── 󰆐 Move 2 item(s) ────────────────────────────────────╮│
│ │ > lua/dot/haha                                                                       ││
│ ├──────────────────────────────────────────────────────────────────────────────────────┤│
│ │ lua/dot/module/clipboard/mac.lua -> lua/dot/haha/mac.lua                             ││
│ │ lua/dot/module/clipboard/nix.lua -> lua/dot/haha/nix.lua                             ││
│ ╰──────────────────────────────────────────────────────────────────────────────────────╯│
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### 预览格式

预览窗口显示格式为 `<源路径> -> <目标路径>`（移动）或 `<源路径> +> <目标路径>`（复制）。

**路径说明**：
- **输入框**：相对于 CWD 的目标目录路径（如 `lua/dot/haha`）
- **源路径**：相对于 CWD 的完整文件路径（如 `lua/dot/module/clipboard/mac.lua`）
- **目标路径**：相对于 CWD 的目标完整路径（如 `lua/dot/haha/mac.lua`）

### 高亮规则

预览中的"相对部分"（文件名相对于公共祖先目录的部分）使用粉色高亮（`f_pk_matches`）：

```
lua/dot/module/clipboard/mac.lua -> lua/dot/haha/mac.lua
                         ^^^^^^^                 ^^^^^^^
                         高亮部分                 高亮部分
```

"相对部分"的计算方式：
1. 找到所有选中文件的公共祖先目录（如 `lua/dot/module/clipboard`）
2. 每个文件相对于公共祖先的路径即为"相对部分"（如 `mac.lua`、`nix.lua`）

### Explorer 复制操作 (mc)

与移动操作类似，但使用 `+>` 箭头表示复制：

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ ╭──────────────────────────────── 󰆏 Copy 2 item(s) ───────────────────────────────────╮│
│ │ > lua/dot/module/clipboard/                                                         ││
│ ├─────────────────────────────────────────────────────────────────────────────────────┤│
│ │ lua/dot/module/clipboard/mac.lua +> lua/dot/module/clipboard/mac.lua                ││
│ │ lua/dot/module/clipboard/nix.lua +> lua/dot/module/clipboard/nix.lua                ││
│ ╰─────────────────────────────────────────────────────────────────────────────────────╯│
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Explorer 删除操作 (md)

删除确认操作，预览显示待删除的文件列表：

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ ╭─────────────────────────────── ⚠ Delete 2 item(s) ───────────────────────────────────╮│
│ │ > y                                                                                  ││
│ ├──────────────────────────────────────────────────────────────────────────────────────┤│
│ │ lua/dot/module/clipboard/mac.lua                                                     ││
│ │ lua/dot/module/clipboard/nix.lua                                                     ││
│ ╰──────────────────────────────────────────────────────────────────────────────────────╯│
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

输入 `y` 或 `yes` 确认删除。

## 实现细节

### 防抖渲染

预览窗口的渲染使用 `stl.c.Scheduler` 进行防抖处理（64ms），避免频繁输入时的性能问题。

### 窗口布局

- 宽度计算优先级：
  1. 如果提供了 `get_width` 回调，使用回调返回的宽度
  2. 否则使用 `width` 参数（0-1 表示百分比，>1 表示像素）
  3. 默认 60%
- 最大宽度：`min(120, vim.o.columns - 4)`
- 最小宽度：`min(vim.o.columns * 0.4, 60)`
- 预览行数：默认 5 行，最大 10 行
- 位置：相对于当前光标位置，自动避免超出屏幕

### 样式

- 输入框边框：`FloatActiveBorder`
- 预览窗口边框：`FloatBorder`
- 输入框背景：`f_pk_finder_normal`
- 预览窗口背景：`f_pk_result_normal`
