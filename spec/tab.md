# Tab Specification

## TabType 定义

通过 `vim.t[tabnr].tabtype` 维护每个 tab 的类型。

```lua
---@alias stl.nvim.tab.TypeEnum
---| "diffview"
---| "normal"
```

| Type       | 描述             |
|:-----------|:-----------------|
| `normal`   | 普通编辑 tab     |
| `diffview` | Git diff 视图    |

## TypeEnum 与 TypeSet

```lua
-- 具体类型枚举
stl.nvim.tab.TypeEnum.NORMAL    -- "normal"
stl.nvim.tab.TypeEnum.DIFFVIEW  -- "diffview"

-- 类型集合（便捷常量，均为数组）
stl.nvim.tab.TypeSet.ALL        -- { "normal", "diffview" }
stl.nvim.tab.TypeSet.NORMAL     -- { "normal" }
stl.nvim.tab.TypeSet.DIFFVIEW   -- { "diffview" }
```

## Command 实现规范

### 强制指定 tabtypes

实现 command 时**必须**指定 `tabtypes`，不允许省略：

```lua
command.implement({
  uuid = K.foo.uuid,
  tabtypes = stl.nvim.tab.TypeSet.NORMAL,  -- 必填，数组形式
  action = function() end,
})
```

### tabtypes 支持 list

`tabtypes` 字段接受数组，允许一个实现同时适用于多个 tab 类型：

```lua
-- 单一类型（推荐使用 TypeSet）
tabtypes = stl.nvim.tab.TypeSet.NORMAL

-- 多类型
tabtypes = { stl.nvim.tab.TypeEnum.NORMAL, stl.nvim.tab.TypeEnum.DIFFVIEW }

-- 全局通用
tabtypes = stl.nvim.tab.TypeSet.ALL
```

### 执行匹配规则

命令执行时精确匹配当前 tab 的 `tabtype`，无 fallback。

## Tabline 渲染

根据 `tabtype` 渲染不同内容：

| tabtype    | 显示内容                   |
|:-----------|:---------------------------|
| `normal`   | buffer 列表 + tab 指示器   |
| `diffview` | Diffview 专用标题          |
| 其他       | fallback 到 `normal` 渲染  |

## 设计原则

1. **显式优于隐式** - 所有 command 必须声明适用的 tabtypes
2. **面向扩展** - tabtypes 使用 list 形式，便于新增类型
3. **优雅降级** - 未知 tabtype 的 tabline 渲染 fallback 到 normal
