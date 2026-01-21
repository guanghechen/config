# Tab Specification

## TabType 定义

通过 `vim.t[tabnr].tabtype` 维护每个 tab 的类型。

```lua
---@alias stl.e.TabTypeEnum
---| "acp"
---| "diffview_commits"
---| "diffview_workspace"
---| "normal"
```

| Type                 | 描述                                                      |
|:---------------------|:----------------------------------------------------------|
| `normal`             | 普通编辑 tab                                              |
| `acp`                | ACP (Anthropic Claude Panel) 交互界面                     |
| `diffview_workspace` | Git Diff 视图（staged/unstaged）                          |
| `diffview_commits`   | Git Log 视图（支持 path_filter 实现单文件/目录历史过滤）  |

## TypeEnum 与 TypeSet

```lua
-- 具体类型枚举
stl.e.TabTypeEnum.NORMAL               -- "normal"
stl.e.TabTypeEnum.ACP                  -- "acp"
stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE   -- "diffview_workspace"
stl.e.TabTypeEnum.DIFFVIEW_COMMITS     -- "diffview_commits"

-- 类型集合（便捷常量，均为数组）
stl.e.TabTypeSet.ALL                   -- 所有类型
stl.e.TabTypeSet.NORMAL                -- { "normal" }
stl.e.TabTypeSet.ACP                   -- { "acp" }
stl.e.TabTypeSet.DIFFVIEW              -- 所有 diffview 类型
stl.e.TabTypeSet.DIFFVIEW_WORKSPACE    -- { "diffview_workspace" }
stl.e.TabTypeSet.DIFFVIEW_COMMITS      -- { "diffview_commits" }
```

## Command 实现规范

### 强制指定 tabtypes

实现 command 时**必须**指定 `tabtypes`，不允许省略：

```lua
command.implement({
  uuid = K.foo.uuid,
  tabtypes = stl.e.TabTypeSet.NORMAL,  -- 必填，数组形式
  action = function() end,
})
```

### tabtypes 支持 list

`tabtypes` 字段接受数组，允许一个实现同时适用于多个 tab 类型：

```lua
-- 单一类型（推荐使用 TypeSet）
tabtypes = stl.e.TabTypeSet.NORMAL

-- 多类型
tabtypes = { stl.e.TabTypeEnum.NORMAL, stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE }

-- 所有 diffview 类型
tabtypes = stl.e.TabTypeSet.DIFFVIEW

-- 全局通用
tabtypes = stl.e.TabTypeSet.ALL
```

### 执行匹配规则

命令执行时精确匹配当前 tab 的 `tabtype`，无 fallback。

## Tabline 渲染

### 注册模式

`era.m.tabline` 提供注册 API，允许各模块为特定 `tabtype` 注册自定义 nvimbar：

```lua
---@param tabtype stl.e.TabTypeEnum
---@param nvimbar era.m.nvimbar.Nvimbar
---@return boolean success
era.m.tabline.register(tabtype, nvimbar)
```

特点：

- 每个 tabtype 只能注册一次，重复注册返回 false
- 未注册的 tabtype 使用默认 nvimbar（normal 类型）
- 保持单向依赖：调用方依赖 tabline，而非反向

### 渲染流程

1. 获取当前 tab 的 `tabtype`
2. 从 `tabline_nvimbar_map` 查找已注册的 nvimbar
3. 若未找到，使用默认 nvimbar
4. 调用 `nvimbar:render()` 渲染

### 注册示例

```lua
-- 在 diffview 模块中注册
local nvimbar = era.m.nvimbar.Nvimbar.new({
  name = "tabline_diffview_workspace",
  -- ... 配置
})
era.m.tabline.register(stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE, nvimbar)
```

### 各 tabtype 的 tabline 内容

| tabtype              | 显示内容                                          |
|:---------------------|:--------------------------------------------------|
| `normal`             | buffer 列表 + tab 指示器                          |
| `acp`                | ACP 专用标题（会话信息）                          |
| `diffview_workspace` | Diffview 专用标题                                 |
| `diffview_commits`   | Diffview 专用标题（带 path_filter 时显示文件名）  |
| 其他                 | fallback 到 normal 渲染                           |

## 设计原则

1. **显式优于隐式** - 所有 command 必须声明适用的 tabtypes
2. **面向扩展** - tabtypes 使用 list 形式，便于新增类型
3. **优雅降级** - 未知 tabtype 的 tabline 渲染 fallback 到 normal
