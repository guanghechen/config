# Find Explorer 设计文档

## 概述

`find-explorer` 是基于 `era.m.picker.ListComposer` 的目录浏览与快速打开工具，入口位于 `lua/era/fn/find-explorer.lua`。

本设计定义 `find-explorer` 的最终交互契约，重点补齐文件动作能力：

- `oa`: create（创建）
- `od`: delete（删除）
- `c`: copy as（同目录复制并改名）
- `or`: rename（同目录重命名）
- `oc`: copy path（路径复制菜单，保持不变）
- `oA`: add to AI（原 `oa` 迁移）

## 目标与边界

目标：

- 在不离开 picker 的前提下完成常用文件操作。
- 操作语义稳定、可预测，避免“轻按一个键就跨目录移动”。
- 保持与现有 `explorer/filetree` 的动作命名风格一致（`oa/od/or/oc`）。

非目标：

- 不做批量 rename / 批量 copy。
- 不在 `find-explorer` 内支持跨目录 move（交给 `explorer` 或后续单独动作）。
- 不引入复杂事务回滚。

## 入口与触发

- 命令入口：`Ffindexplorer`（可选参数：`filepath`）。
- 函数入口：`era.fn.find_explorer(specified_filepath)`。

初始目录解析顺序保持不变：

1. 参数是存在目录 -> 使用该目录。
2. 参数是存在文件 -> 使用其父目录。
3. 否则尝试当前 tab 的 sourcefile window。
4. 最终 `reset_data + focus`。

## 核心状态

保留现有状态：

- `state_cwd: Observable<string>`
- `search_pattern: Observable<string>`
- `flag_fuzzy / flag_regex / flag_case_sensitive`
- `dir_datamap: table<string, IDirItem>`
- `file_datamap: table<string, IFileItem>`

新增状态：无。

设计原则：

- 动作执行采用“即时计算 + 强制刷新”模型，不新增全局状态机。

## 键位契约

`finder/result` 统一动作键如下：

```text
oA   add to AI
oa   create
oc   copy path menu
od   delete
or   rename
c    copy as (same directory)
```

说明：

- `oc` 保持现有菜单：`absolute / relative / filename`。
- `oa` 从“add to AI”迁移为“create”。
- `oA` 承接原“add to AI”。
- `c` 为快速 copy as，优先在 `result` 窗口生效。

## 动作语义

### `oa` Create

输入：`vim.ui.input("Create: ")`。

规则：

- 输入格式仅允许 `name` 或 `name/`。
- `name` 不能为空，且不得包含 `/`、`\`，并且不能等于 `.` 或 `..`。
- 输入为 `name/` -> 创建目录。
- 输入为 `name` -> 创建文件。
- 其他格式 -> 拒绝并报错。

父目录选择：

- 当前项是目录 -> 在该目录下创建。
- 当前项是文件 -> 在该文件所在目录创建。
- 当前项为 `../` -> 在当前 `state_cwd` 创建。
- 当前项不存在（例如空目录）-> 在当前 `state_cwd` 创建。

冲突策略：

- 目标已存在 -> 报错并终止。

成功后：

- 刷新当前目录。
- 光标定位到新建项。

### `od` Delete

输入：`vim.ui.input(inputtype="confirmation")`。

规则：

- 当前项不存在 -> no-op。
- `../` 不允许删除。
- 文件：删除单文件。
- 目录：递归删除目录。
- 仅接受 `y` / `yes`（大小写不敏感）确认。

成功后：

- 刷新当前目录。
- 光标尽量停留在原行号邻近项。

### `c` Copy As（同目录）

输入：`vim.ui.input("Copy as: ", default = suggested_name)`。

`suggested_name` 规则：

- 文件 `a.ts` -> `a-copy.ts`
- 无扩展名文件 `LICENSE` -> `LICENSE-copy`
- 目录 `foo/` -> `foo-copy`

规则：

- 当前项不存在 -> no-op。
- `../` 不支持 copy。
- 仅允许输入名称，不允许 `/` 或 `\`。
- 目标路径始终为 `dirname(source) + new_name`。
- 源是目录时，目标目录名需保留目录语义（内部实现按目录复制）。

冲突策略：

- 目标已存在 -> 报错并终止（v1 不做 overwrite）。

成功后：

- 刷新当前目录。
- 光标定位到复制后的新项。

### `or` Rename（同目录）

输入：`vim.ui.input("Rename to: ", default = current_name)`。

规则：

- 当前项不存在 -> no-op。
- `../` 不支持 rename。
- 仅允许输入名称，不允许 `/` 或 `\`。
- 目标路径始终为 `dirname(source) + new_name`。

冲突策略：

- 目标已存在 -> 报错并终止。

成功后：

- 刷新当前目录。
- 光标定位到新名称项。

### `oc` Copy Path Menu

保持现有行为：

- 菜单项：`absolute / relative / filename`。
- 弹窗位置：`relative = "cursor", row = 1, col = 4`。
- 若触发时焦点不在 result window，完成后恢复焦点。

### `oA` Add To AI

行为与原 `oa` 完全一致：

- 取当前项路径并调用 `era.fn.add_locations_to_ai`。

## 输入校验与安全约束

统一校验函数（逻辑约束）：

- 名称不得为空。
- 对 `c/or`：名称不得包含路径分隔符（`/`、`\\`）。
- 对 `oa`：输入必须满足 `name` 或 `name/`，其中 `name` 不得包含 `/`、`\\`，且不能等于 `.` 或 `..`。

统一拒绝目标：

- `../` 虚拟父项。

## 刷新与缓存策略

动作成功后执行统一刷新流程：

1. 定位 `dirpath = state_cwd:snapshot()`。
2. 清理目录缓存：`dir_datamap[dirpath] = nil`。
3. 强制重读：`fetch_diritem(dirpath, true)`。
4. `picker:reset_data(fetch_data())`。
5. 若存在 `target_path`，尝试将 `lnum_current` 对齐到目标项。

说明：

- 不做全缓存清空，避免在大目录切换时引入额外抖动。

## 错误处理与反馈

统一策略：

- 失败必须通过 `stl.reporter.error` 给出可读错误。
- 成功可选 `stl.reporter.info`（create/delete/copy/rename 建议保留）。
- 所有失败都不改变 `state_cwd`。

错误示例：

- `Invalid name: path separator is not allowed`
- `Target already exists`
- `Cannot delete parent entry ../`

## 性能评估

动作复杂度：

- `create/rename/copy/delete` 的主耗时为文件系统 IO。
- UI 刷新只重建当前目录单层列表，复杂度约 `O(n)`（`n` 为当前目录子项数）。

风险点：

- 超大目录下 `fetch_data + render_result` 仍可能卡顿。
- 本设计不新增全目录扫描，因此不会比当前显著更差。

## 关键决策对比

### 决策 1：`c/or` 是否允许输入路径

示例 A：仅允许名称（推荐）

- 输入：`new.txt`
- 结果：只在当前项所在目录操作。
- 对比：语义稳定，不会误变成跨目录 move。

示例 B：允许 `subdir/new.txt`

- 输入：`archive/new.txt`
- 结果：行为等同 move/copy to another dir。
- 对比：灵活但风险高，和“同目录操作”目标冲突。

推荐：采用示例 A。

### 决策 2：冲突文件处理

示例 A：直接报错（推荐）

- 冲突即终止，提示 `Target already exists`。
- 对比：实现简单，避免覆盖风险。

示例 B：弹窗询问覆盖

- 需要额外确认流与目录覆盖语义。
- 对比：交互复杂，容易出现分支遗漏。

推荐：v1 采用示例 A。

### 决策 3：刷新策略

示例 A：全量清空缓存

- 实现简单，但每次动作都损失缓存收益。

示例 B：只清理当前目录缓存（推荐）

- 动作后只强刷 `state_cwd`，性能与一致性平衡更好。

推荐：采用示例 B。

## 实现前验收标准

实现必须满足：

- `oa/od/c/or/oc/oA` 在 finder/result 行为一致。
- `c/or` 输入路径分隔符会被拒绝。
- 删除/重命名/复制成功后，列表立即反映变更，且光标定位到目标项或邻近项。
- `oc` 与 `oA` 现有能力无回归。
