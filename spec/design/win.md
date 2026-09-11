# Window 类型与属性

## WinType 定义

每个 window 的类型保存在 `vim.w[winnr].wintype`，通过 `stl.e.WinTypeEnum` 常量读写。

```lua
---@alias stl.e.WinTypeEnum
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

| 类型                  | 描述                   |
| :-------------------- | :--------------------- |
| `ux:board`            | 通用面板（通知历史等） |
| `ux:cmdline`          | 命令行窗口             |
| `ux:explorer`         | 文件浏览器             |
| `ux:input`            | 输入框                 |
| `ux:notify`           | 通知弹窗               |
| `ux:picker-finder`    | Picker 搜索框          |
| `ux:picker-preview`   | Picker 预览窗口        |
| `ux:picker-result`    | Picker 结果列表        |
| `ux:popupmenu`        | 弹出菜单               |
| `ux:searcher-finder`  | Searcher 搜索框        |
| `ux:searcher-preview` | Searcher 预览窗口      |
| `ux:searcher-result`  | Searcher 结果列表      |
| `ux:select`           | 选择菜单               |
| `ux:terminal`         | 终端窗口               |
| `ux:textarea`         | 文本编辑区域           |
| `ux:winpicker`        | 窗口选择器标签         |
| `ux:winsep`           | 窗口分隔线             |

## TypeEnum

```lua
stl.e.WinTypeEnum.BOARD             -- "ux:board"
stl.e.WinTypeEnum.CMDLINE           -- "ux:cmdline"
stl.e.WinTypeEnum.EXPLORER          -- "ux:explorer"
stl.e.WinTypeEnum.INPUT             -- "ux:input"
stl.e.WinTypeEnum.NOTIFY            -- "ux:notify"
stl.e.WinTypeEnum.PICKER_FINDER     -- "ux:picker-finder"
stl.e.WinTypeEnum.PICKER_PREVIEW    -- "ux:picker-preview"
stl.e.WinTypeEnum.PICKER_RESULT     -- "ux:picker-result"
stl.e.WinTypeEnum.POPUPMENU         -- "ux:popupmenu"
stl.e.WinTypeEnum.SEARCHER_FINDER   -- "ux:searcher-finder"
stl.e.WinTypeEnum.SEARCHER_PREVIEW  -- "ux:searcher-preview"
stl.e.WinTypeEnum.SEARCHER_RESULT   -- "ux:searcher-result"
stl.e.WinTypeEnum.SELECT            -- "ux:select"
stl.e.WinTypeEnum.TERMINAL          -- "ux:terminal"
stl.e.WinTypeEnum.TEXTAREA          -- "ux:textarea"
stl.e.WinTypeEnum.WINPICKER         -- "ux:winpicker"
stl.e.WinTypeEnum.WINSEP            -- "ux:winsep"
```

## 使用方式

### 设置 window type

```lua
vim.w[winnr].wintype = stl.e.WinTypeEnum.PICKER_FINDER
```

### 读取 window type

```lua
local wintype = vim.w[winnr].wintype ---@type stl.e.WinTypeEnum|nil
```

## Window 属性集合

`lua/dot/win.lua` 按 `wintype` 定义以下属性集合：

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

`wintype` 直接从 `vim.w` 读写，不增加 getter/setter，也不在 `dot.win.IMeta` 中重复存储。
