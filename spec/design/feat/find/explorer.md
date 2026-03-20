# Find Explorer 设计文档

## 概述

`find-explorer` 是一个基于 `era.m.picker.ListComposer` 的目录浏览与快速打开工具，入口实现位于 `lua/era/fn/find-explorer.lua`。

它的目标是：

- 在当前目录上下文中快速筛选文件/目录。
- 通过 preview 直接查看文本文件内容或目录清单。
- 在不离开 picker 的情况下完成路径复制、切目录、打开文件。

本文档描述当前代码行为，不描述历史方案或计划方案。

## 入口与触发

- 命令入口：`Ffindexplorer`（可选参数：`filepath`）。
- 函数入口：`era.fn.find_explorer(specified_filepath)`。
- 默认快捷键：
  - `<leader>fe` -> `K.find.explorer`
  - `<leader><leader>` 在非 git repo 场景会回退到 `K.find.explorer`

## 核心状态

`find-explorer` 在模块内维护以下状态：

- `state_cwd: Observable<string>`
  - 当前浏览目录。
- `search_pattern: Observable<string>`
  - finder 输入内容。
- `flag_fuzzy / flag_regex / flag_case_sensitive`
  - 匹配行为开关。
- `dir_datamap: table<string, IDirItem>`
  - 目录级缓存（目录项列表 + 各字段显示宽度）。
- `file_datamap: table<string, IFileItem>`
  - 路径级缓存（用于渲染和 `../` 父目录条目）。

## 数据获取与构建

### 目录读取

- 底层读取使用 `yoz.fs.readdir(dirpath)`。
- 成功时会缓存：
  - `raw_data.itself` -> 当前目录自身元信息（用于父目录条目跳转）。
  - `raw_data.items` -> 当前目录下一层子项。
- 失败时通过 `stl.reporter.error` 上报错误。

### 列表数据构建

`fetch_data()` 每次返回 `ListComposer` 需要的 `IResetData`：

- 第 1 项（可选）是 `../`，`uuid = parent_dirpath`。
- 其余项来自当前目录子项：
  - 目录显示为 `name/`
  - 文件显示为 `name`
- `uuid_current` 优先对齐当前 tab 的 sourcefile window 对应文件；找不到时回退到第 2 项。

## 渲染设计

### Result 渲染

`render_result` 最终调用 `render_file_list()`，每行由下列字段组成：

- `icon`
- `filename`
- `perm`
- `size`
- `date`

行为细节：

- 列宽按当前目录所有项计算，保证对齐。
- `filename` 会按结果窗口宽度做截断（`...`）。
- match 高亮只渲染在可见文件名范围内，避免截断后高亮越界。

### Preview 渲染

- 当前项为文本文件：
  - 最多读取 `300` 行。
  - 自动推断并设置 `filetype`。
  - 显示行号与 `cursorline`。
- 当前项为非文本文件：
  - 显示 `Not a text file, cannot preview.`。
- 当前项为目录：
  - 渲染目录下一层内容的元信息清单。
  - 非 Windows 额外显示 owner/group。

## 交互行为

### Confirm

- 选中 `file`：
  - 优先切回 sourcefile window。
  - 关闭 picker。
  - 调用 `dot.win.open_filepath()` 打开文件。
- 选中 `directory`：
  - 更新 `state_cwd` 进入目录，不关闭 picker。

### 导航

- `<Backspace>`：进入父目录（`dirname(state_cwd)`）。
- 订阅 `state_cwd`：目录变化时自动 `reset_data`。

### 功能键

- `oa`（finder/result）：将当前条目路径作为 location 添加到 AI。
- `oc`（finder/result）：打开 copy 菜单，支持：
  - `absolute`
  - `relative`
  - `filename`

`oc` 设计细节：

- 复用 `era.fn.select_copy_filepath()`，弹窗位置固定为 `relative = "cursor", row = 1, col = 4`。
- 若触发时焦点不在 result window，完成后会恢复原窗口焦点。

## 初始目录解析规则

`find_explorer(specified_filepath)` 的目录解析顺序：

1. 若参数是存在的目录：直接使用该目录。
2. 若参数是存在的文件：使用其父目录。
3. 否则尝试当前 tab 的 sourcefile window：
   - sourcefile 是目录 -> 使用该目录。
   - sourcefile 是文件 -> 使用其父目录。
4. 最终 `reset_data + focus`。

## 使用示例

### 示例 1：从当前文件所在目录启动

- 触发：`<leader>fe`
- 结果：自动定位到当前 sourcefile 所在目录，并优先选中当前文件（若存在于列表中）。

### 示例 2：在列表中切目录

- 触发：在 `src/` 上按 `<Enter>`
- 结果：进入 `src/` 并刷新列表；按 `<Backspace>` 可返回父目录。

### 示例 3：复制路径

- 触发：在任意条目按 `oc`
- 结果：弹出 copy 选项；选择 `2` 可复制相对 `cwd` 的路径，选择 `3` 可仅复制文件名。

## 已知边界

### 边界 1：缓存不会自动失效

- 触发：目录内容在外部被修改，但未切换目录/未强制刷新。
- 证据：`dir_datamap/file_datamap` 为进程内缓存，`fetch_diritem(dir, false)` 优先读缓存。
- 影响：列表与 preview 可能短暂显示旧内容。

### 边界 2：Result 仅展示单层目录

- 触发：当前目录包含多层子目录。
- 证据：`fetch_data()` 只读取并渲染 `state_cwd` 的直接子项。
- 影响：深层浏览依赖 Enter 逐层进入，不是 tree 展开式交互。

### 边界 3：workspace 标题文案与功能名不一致

- 触发：`state_cwd == workspace`。
- 证据：`gen_title()` 返回 `Find files (workspace)`。
- 影响：UI 文案与模块名 `Find Explorer` 不完全一致，但不影响行为。
