# Explorer 模块设计文档

## 概述

`era.m.explorer` 是当前 Neovim 配置中的文件浏览器实现。
当前实现采用 **filepath-only** 模型，不再使用 URI 作为内部标识。
系统边界转换统一由 `stl.os.path` / `stl.os.fs` 承担。

模块由 `Tree + View + Widget + Action + FileManager` 组成，目标是:

- 内部状态统一且可预测
- 与系统交互时做最小必要转换
- 在特殊文件名（如 `#`）下保持稳定

## 路径策略（核心约束）

以下约束是 explorer 的基础不变式。

1. 内部只使用 `filepath`，不使用 URI。
2. 内部路径分隔符固定为 `/`（Windows 内部同样如此）。
3. 目录路径在内部以 `/` 结尾，文件路径不以 `/` 结尾。
4. 仅在系统边界做一次路径转换（`/` -> `PATH_SEP`），统一使用 `stl.os.path.to_os(...)`。

系统边界包括:

- `stl.os.fs.*` 文件系统 facade（推荐）
- `vim.fn.*` / `vim.uv.fs_*` / `vim.system(...)`（若直接调用，调用前必须先 `stl.os.path.to_os(...)`）
- `vim.ui.open(...)`
- `vim.cmd("split/tabnew/vsplit ...")`
- `dot.win.open_filepath(...)`

## 模块职责

- `resource/file.lua`
  - 文件系统读写与监听
  - 通过 `stl.os.path` / `stl.os.fs` 维护“内部路径 <-> OS 路径”边界转换
- `tree.lua`
  - 维护树结构与选择/展开状态
  - 按 filepath 定位节点
- `node.lua`
  - 节点结构与路径拼装
- `view.lua`
  - 负责渲染数据计算（line/highlight/diag/git）
- `widget.lua`
  - 负责窗口生命周期与交互绑定
- `action.lua`
  - 负责用户动作（open/create/delete/copy/move/rename/paste）

## 数据模型

### Node

关键字段:

- `filepath: string`
- `nodename: string`
- `nodetype: "D" | "F"`
- `parent: Node|nil`
- `children: Node[]`
- `selected/expanded/loaded/has_selected`

说明:

- `superroot.filepath = ""`，用于全局树骨架。
- 真实文件系统 root 由普通节点表示，例如 `/` 或 `C:/`。

### Tree

关键状态:

- `_superroot` 与 `_root`
- `o_root_filepath`
- `o_cursor_filepath`
- `select_mode = "select" | "copy" | "cut"`

定位索引:

- `view` 维护 `lnum_to_filepath` 与 `filepath_to_lnum`。

## 关键流程

### 打开文件

1. 从 render 状态获取内部 filepath。
2. 调用 `stl.os.path.to_os(...)` 转为 OS 路径。
3. 执行 `open/split/tabnew/vsplit/system-open`。

### 读写文件系统

1. `Action/Tree` 层传入内部 filepath（slash-only）。
2. `FileManager` 在边界通过 `stl.os.path.to_os(...)` 做路径转换。
3. 文件系统调用优先走 `stl.os.fs`。
4. 返回值与节点状态仍保持内部 slash-only。

### 创建/重命名输入

1. 用户输入先归一化为内部 slash-only 路径。
2. 内部组合目标路径并更新 tree。
3. 真正 IO 时在 `FileManager` 转 OS 路径。

## 已知边界与语义

1. `#` 是普通文件名字符，不参与路径解析语义。
2. `/` 与 `C:/` 视为 root，不再向上回退。
3. explorer 内部不依赖 `file://` 或 URI fragment 规则。

## 维护约定

后续改动请遵守以下约定:

1. 新增路径字段时，命名统一使用 `filepath`。
2. 禁止在 explorer 内部重新引入 URI 结构。
3. 若新增系统调用，必须在调用前执行 `stl.os.path.to_os(...)`（或直接使用 `stl.os.fs`）。
4. 测试优先覆盖:
   - `#head`、`a#1.txt`、`a#2.txt`
   - 含空格与中文路径
   - root 边界（`/`、`C:/`）

## 调试建议

1. 路径异常优先检查边界转换是否遗漏。
2. 定位异常优先检查 `filepath_to_lnum/lnum_to_filepath` 一致性。
3. 删除/移动异常优先检查 `FileManager` OS path 输入与返回路径是否混用。
