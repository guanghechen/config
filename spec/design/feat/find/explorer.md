# Find Explorer 设计

Status: Design。定义 picker 内的单目录浏览与单项文件操作。

`find-explorer` 以 `BasicComposer` 组合窗口，`era.view.Directory` 直接连接 Rust Filetree Data、State 与 View。
入口为 `lua/era/fn/find-explorer.lua`。主结果和目录 preview 均使用 [native Treeview](../../../../doc/spec/treeview/README.md)。

## 入口与状态

命令 `Ffindexplorer` 接受可选 `filepath`；函数入口为 `era.fn.find_explorer(specified_filepath)`。
初始目录按以下顺序选择，再异步打开目录并 focus：

1. 参数是已有目录：使用该目录。
2. 参数是已有文件：使用其父目录。
3. 否则尝试当前 tab 的 sourcefile window。
4. 仍未解析到目录时保留最近目录；其初始值为 CWD。

核心状态由共享 Filetree Data 与主结果 State 持有；query 和 fuzzy/regex/case-sensitive 开关保留 Observable。
主结果是当前目录的单层 List；有界遍历、上下文行与目录 suffix 的精确规则见
[Treeview projection](../../../../doc/spec/treeview/projection.md)。不创建 Lua 目录缓存或行映射。

所有路径遵循 [Filetree path/resource 契约](../../filetree.md)。进入目录时按资源 NodeId 切根；
异步定位校验 navigation sequence，不能覆盖用户较新的光标输入。旧 Frame 保持自己的资源解释。
目录 preview 使用同一 Data 的独立 State，只读取选中目录的直接 children。
权限、size、日期、owner/group 由 worker 按 viewport 格式化，不重新 stat；icons 与高亮仅在 viewport 生成。
`../` 的这些字段来自同一 Frame 捕获的父目录 metadata，与其导航和文件路径动作一致。

## 动作与按键

Finder/result 使用同一组动作键；`c` 优先在 result window 生效。

| 按键        | 动作                      |
| ----------- | ------------------------- |
| `Enter`     | 打开文件／进入目录        |
| `Backspace` | 返回父目录                |
| `oa`        | Create                    |
| `od`        | Delete                    |
| `c`         | Copy As：同目录复制并改名 |
| `or`        | Rename：同目录重命名      |
| `oc`        | Copy Path Menu            |
| `oA`        | Add To AI                 |

本工具不支持批量 copy/rename、跨目录 move 或复杂事务回滚；
跨目录操作交给 [Explorer](../explorer.md)。

### `oa`：创建

`Create: ` prompt 只接受 `name` 或 `name/`：前者创建文件，后者创建目录。
`name` 不得为空、为 `.`/`..`，或包含 `/`、`\`；其他格式拒绝并报错。

父目录由当前项决定：

- 目录：在该目录内创建。
- 文件：在其父目录创建。
- `../` 或没有当前项：在当前目录创建。

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

动作全部使用 `era.m.filetree.jobs` 及 Rust Filetree Jobs。Prompt 前从显示 Frame 捕获资源 identity；
同名文件在等待输入期间被替换时，native 拒绝对替换项执行操作。Find Explorer 不接受 overwrite，
rename 使用与 Explorer 相同的 editor buffer / LSP 同步。

成功后由 native publication 更新已加载目录；当前仍处于原目录时刷新，并尝试定位新项。
删除定位到原行号附近，避免上下文根行抢占 cursor fallback；期间存在更新的用户导航时保留该导航。
部分失败不能按首个成功 item 宣称整个动作成功。
失败通过 `stl.reporter.error` 报告，不切换目录；未完成 Jobs 与 Explorer 共用退出时的取消和收尾。

## 决策与成本

- Copy/Rename 只接受名称，避免把同目录操作隐式变成跨目录 move/copy。
- 目标冲突直接报错，避免引入覆盖确认和目录覆盖语义。
- 主结果不把整份 readdir 导出到 Lua 再导入另一个 Data；列宽和永久高亮也不按全目录维护。
- 目录 IO、过滤、投影和 metadata 格式化在 native worker；Lua 装饰成本随 viewport 行数增长。
  Filter/排序和结构变化仍可读取当前目录的全部候选，首开不是常数成本。
- Hide 保留 native buffer/Frame，重开先复用正文；恢复 watch 时的后台 reconciliation 另计。

## 验证要求

- `oa/od/c/or/oc/oA` 在 finder/result 的动作语义一致。
- `c/or` 拒绝包含路径分隔符的输入；创建、删除对 `../` 的处理符合各自动作规则。
- Create/copy/rename 后定位目标，delete 后定位邻近项，列表立即反映变更。
- `oc` 与 `oA` 保留原能力；失败不改变当前目录。
