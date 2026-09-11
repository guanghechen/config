# Find Explorer 设计

`find-explorer` 基于 `era.m.picker.ListComposer`，提供目录浏览、快速打开与单项文件操作。
入口为 `lua/era/fn/find-explorer.lua`。

## 入口与状态

命令 `Ffindexplorer` 接受可选 `filepath`；函数入口为 `era.fn.find_explorer(specified_filepath)`。
初始目录按以下顺序选择，再执行 `reset_data + focus`：

1. 参数是已有目录：使用该目录。
2. 参数是已有文件：使用其父目录。
3. 否则尝试当前 tab 的 sourcefile window。
4. 仍未解析到目录时保留 `state_cwd`；其初始值为 CWD。

核心状态：

- `state_cwd: Observable<string>`、`search_pattern: Observable<string>`。
- `flag_fuzzy / flag_regex / flag_case_sensitive`。
- `dir_datamap: table<string, IDirItem>`、`file_datamap: table<string, IFileItem>`。

`state_cwd`、`IFileItem.path/dir` 与 cache key 均使用 slash-only canonical path。
命令参数、buffer name 等入口只 canonicalize 一次；调用 filesystem/native API 前临时转为 OS path，
转换结果不存入状态或 cache。动作即时计算，成功后刷新，不增加全局状态机。

## 动作与按键

Finder/result 使用同一组动作键；`c` 优先在 result window 生效。

| 按键 | 动作                      |
| ---- | ------------------------- |
| `oa` | Create                    |
| `od` | Delete                    |
| `c`  | Copy As：同目录复制并改名 |
| `or` | Rename：同目录重命名      |
| `oc` | Copy Path Menu            |
| `oA` | Add To AI                 |

本工具不支持批量 copy/rename、跨目录 move 或复杂事务回滚；
跨目录操作交给 [Explorer](../explorer.md)。

### `oa`：创建

`Create: ` prompt 只接受 `name` 或 `name/`：前者创建文件，后者创建目录。
`name` 不得为空、为 `.`/`..`，或包含 `/`、`\`；其他格式拒绝并报错。

父目录由当前项决定：

- 目录：在该目录内创建。
- 文件：在其父目录创建。
- `../` 或没有当前项：在 `state_cwd` 创建。

目标已存在则拒绝。成功后刷新当前目录，并尝试定位新建项。

### `od`：删除

使用 `inputtype = "confirmation"` 的输入框，仅接受大小写不敏感的 `y` / `yes` 确认。
没有当前项时 no-op；`../` 不可删除。文件直接删除，目录递归删除。
成功后刷新，并尽量停留在原行号附近。

### `c`：同目录复制

`Copy as: ` prompt 的默认名称如下：

| Source    | 默认名称       |
| --------- | -------------- |
| `a.ts`    | `a-copy.ts`    |
| `LICENSE` | `LICENSE-copy` |
| `foo/`    | `foo-copy`     |

没有当前项时 no-op；不允许复制 `../`。只接受非空名称，不允许 `/` 或 `\`。
目标位于 source 的父目录，使用新名称；目录按目录复制。目标已存在则拒绝，不 overwrite。
成功后刷新，并尝试定位新项。

### `or`：同目录重命名

`Rename to: ` prompt 默认填入当前名称。
没有当前项时 no-op；不允许重命名 `../`。只接受非空名称，不允许 `/` 或 `\`。
目标始终位于 source 的父目录；已存在则拒绝。成功后刷新，并尝试定位新名称项。

### `oc`：路径复制菜单

菜单保留 `absolute / relative / filename`，弹窗配置为 `relative = "cursor", row = 1, col = 4`。
触发时焦点不在 result window 的，完成后恢复焦点。

### `oA`：添加到 AI

读取当前项路径并调用 `era.fn.add_locations_to_ai`。

## 刷新与失败处理

动作成功后只刷新当前目录：

1. 读取 `dirpath = state_cwd:snapshot()`。
2. 清除 `dir_datamap[dirpath]`，调用 `fetch_diritem(dirpath, true)` 强制重读。
3. 执行 `picker:reset_data(fetch_data())`。
4. 存在 `target_path` 时，尝试将 `lnum_current` 对齐到目标；删除则选择邻近项。

失败通过 `stl.reporter.error` 报告，不改变 `state_cwd`；成功可通过 `stl.reporter.info` 通知。
错误示例：`Invalid name: path separator is not allowed`、`Target already exists`、
`Cannot delete parent entry ../`。

## 决策与成本

- Copy/Rename 只接受名称，避免把同目录操作隐式变成跨目录 move/copy。
- 目标冲突直接报错，避免引入覆盖确认和目录覆盖语义。
- 只清理当前目录 cache，保留其他目录的缓存收益。
- 文件操作主要耗时在 filesystem I/O；UI 只重建当前目录单层列表，复杂度约 `O(n)`，`n` 为直接子项数。
  不增加全目录扫描，但超大目录的 `fetch_data + render_result` 仍可能阻塞 UI。

## 验证要求

- `oa/od/c/or/oc/oA` 在 finder/result 的动作语义一致。
- `c/or` 拒绝包含路径分隔符的输入；创建、删除对 `../` 的处理符合各自动作规则。
- Create/copy/rename 后定位目标，delete 后定位邻近项，列表立即反映变更。
- `oc` 与 `oA` 保留原能力；失败不改变 `state_cwd`。
