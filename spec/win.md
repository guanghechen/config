# Window Specification

## WinType 定义

通过 `vim.w[winnr].wintype` 维护每个 window 的类型。

```lua
---@alias stl.nvim.win.TypeEnum
---| "ux:board"
---| "ux:cmdline"
---| "ux:explorer"
---| "ux:input"
---| "ux:notify"
---| "ux:picker-finder"
---| "ux:picker-preview"
---| "ux:picker-result"
---| "ux:popupmenu"
---| "ux:searcher-finder"
---| "ux:searcher-preview"
---| "ux:searcher-result"
---| "ux:select"
---| "ux:terminal"
---| "ux:textarea"
---| "ux:winpicker"
---| "ux:winsep"
```

| Type                  | 描述                      |
|:----------------------|:--------------------------|
| `ux:board`            | 通用面板（通知历史等）    |
| `ux:cmdline`          | 命令行窗口                |
| `ux:explorer`         | 文件浏览器                |
| `ux:input`            | 输入框                    |
| `ux:notify`           | 通知弹窗                  |
| `ux:picker-finder`    | Picker 搜索框             |
| `ux:picker-preview`   | Picker 预览窗口           |
| `ux:picker-result`    | Picker 结果列表           |
| `ux:popupmenu`        | 弹出菜单                  |
| `ux:searcher-finder`  | Searcher 搜索框           |
| `ux:searcher-preview` | Searcher 预览窗口         |
| `ux:searcher-result`  | Searcher 结果列表         |
| `ux:select`           | 选择菜单                  |
| `ux:terminal`         | 终端窗口                  |
| `ux:textarea`         | 文本编辑区域              |
| `ux:winpicker`        | 窗口选择器标签            |
| `ux:winsep`           | 窗口分隔线                |

## TypeEnum

```lua
stl.nvim.win.TypeEnum.BOARD             -- "ux:board"
stl.nvim.win.TypeEnum.CMDLINE           -- "ux:cmdline"
stl.nvim.win.TypeEnum.EXPLORER          -- "ux:explorer"
stl.nvim.win.TypeEnum.INPUT             -- "ux:input"
stl.nvim.win.TypeEnum.NOTIFY            -- "ux:notify"
stl.nvim.win.TypeEnum.PICKER_FINDER     -- "ux:picker-finder"
stl.nvim.win.TypeEnum.PICKER_PREVIEW    -- "ux:picker-preview"
stl.nvim.win.TypeEnum.PICKER_RESULT     -- "ux:picker-result"
stl.nvim.win.TypeEnum.POPUPMENU         -- "ux:popupmenu"
stl.nvim.win.TypeEnum.SEARCHER_FINDER   -- "ux:searcher-finder"
stl.nvim.win.TypeEnum.SEARCHER_PREVIEW  -- "ux:searcher-preview"
stl.nvim.win.TypeEnum.SEARCHER_RESULT   -- "ux:searcher-result"
stl.nvim.win.TypeEnum.SELECT            -- "ux:select"
stl.nvim.win.TypeEnum.TERMINAL          -- "ux:terminal"
stl.nvim.win.TypeEnum.TEXTAREA          -- "ux:textarea"
stl.nvim.win.TypeEnum.WINPICKER         -- "ux:winpicker"
stl.nvim.win.TypeEnum.WINSEP            -- "ux:winsep"
```

## 使用方式

### 设置 window type

```lua
vim.w[winnr].wintype = stl.nvim.win.TypeEnum.PICKER_FINDER
```

### 读取 window type

```lua
local wintype = vim.w[winnr].wintype ---@type stl.nvim.win.TypeEnum|nil
```

## Window 属性集合

`dot/win.lua` 中定义了基于 `wintype` 的属性集合：

```lua
local wintype_attrs = {
  focusable = { ... },    -- 可聚焦的窗口类型
  projectable = { ... },  -- 可投影的窗口类型
  sourcefile = { ... },   -- 源文件窗口类型
  swappable = { ... },    -- 可交换的窗口类型
}
```

对应检查函数：

- `dot.win.is_focusable(winnr)`
- `dot.win.is_projectable(winnr)`
- `dot.win.is_sourcefile(winnr)`
- `dot.win.is_swappable(winnr)`

## 设计原则

1. **直接访问** - 使用 `vim.w[winnr].wintype` 直接读写，无需 getter/setter
2. **类型安全** - 所有类型值通过 `TypeEnum` 常量引用
3. **无冗余存储** - `dot.win.IMeta` 不存储 `wintype`，直接从 `vim.w` 读取
