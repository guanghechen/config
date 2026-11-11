# Window 类型与属性

## WinType 定义

每个 window 的类型保存在 `vim.w[winnr].wintype`，通过 `stl.e.WinTypeEnum` 常量读写。

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

## Window 属性集合

`lua/dot/win.lua` 按 `wintype` 定义以下属性集合，并提供对应检查函数：

- `dot.win.is_focusable(winnr)`：可聚焦的窗口类型
- `dot.win.is_projectable(winnr)`：可投影的窗口类型
- `dot.win.is_sourcefile(winnr)`：源文件窗口类型
- `dot.win.is_swappable(winnr)`：可交换的窗口类型

`wintype` 直接从 `vim.w` 读写，不增加 getter/setter，也不在 `dot.win.IMeta` 中重复存储。
