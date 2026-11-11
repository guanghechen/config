# Tab 类型

## TabType 定义

通过 `vim.t[tabnr].tabtype` 维护每个 tab 的类型。

| 类型                 | 描述                                                     |
| :------------------- | :------------------------------------------------------- |
| `normal`             | 普通编辑 tab                                             |
| `diffview_workspace` | Git Diff 视图（staged/unstaged）                         |
| `diffview_commits`   | Git Log 视图（支持 path_filter 实现单文件/目录历史过滤） |
| `maximize`           | 普通 window 最大化使用的临时 tab                         |

## TypeEnum 与 TypeSet

`stl.e.TabTypeEnum` 提供上述类型的常量；`stl.e.TabTypeSet` 提供类型集合（便捷常量，均为数组）：

- `ALL`：所有类型，用于全局通用的命令。
- `NORMAL`、`MAXIMIZE`、`DIFFVIEW_WORKSPACE`、`DIFFVIEW_COMMITS`：仅含同名的单一类型。
- `DIFFVIEW`：所有 diffview 类型，用于两种 Diffview 共用的命令。
- `NAVIGABLE`：`normal` 与所有 diffview 类型，不含 `maximize`；用于应用级 tab focus/new。

## Command 匹配

Command 实现必须显式提供数组形式的 `tabtypes`：

```lua
command.implement({
  uuid = K.foo.uuid,
  tabtypes = stl.e.TabTypeSet.NORMAL,  -- 必填，数组形式
  action = function() end,
})
```

一个实现可适用于多个 tab 类型：使用 TypeSet，或列出多个 `stl.e.TabTypeEnum`。

命令执行时精确匹配当前 tab 的 `tabtype`，无 fallback。
`maximize` 下的命令限制与生命周期见 [Maximize](../feat/maximize.md)；各 tabtype 的 tabline 见
[Tabline 注册](../feat/nvimbar.md#tabline-注册)。
