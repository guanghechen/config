# Treeview 接入

Lua surface 使用 `require("ux.treeview")`。权威语义见 [Treeview 设计](README.md)，Lua 字段与原生方法见
[treeview.lua](../../../../lua/__types__/ux/treeview.lua) 和 [yoz/ux.lua](../../../../lua/__types__/yoz/ux.lua)。

## 选择入口

各 consumer 的数据路径见 [Treeview 索引](README.md)。真实目录浏览使用 `require("ux.filetree")`（见 [Filetree](../filetree/README.md)），
业务结果通过 ResultTree 导入（见 [结果集接入](../../feat/results.md)）；直接提供通用层级数据时使用下述 `ux.treeview` API。
显示模式与数据来源分开，Treeview 不推断 filesystem。

## 最小示例

先运行 `node script/build.mjs` 构建本地 native module；已加载旧动态库的 Neovim 需要重启。
在仓库正常 bootstrap 完成后执行：

```lua
local treeview = require("ux.treeview")

stl.async.run(function()
  local data = treeview.new_data()
  local imported = data:import({
    { key = "root", label = "Workspace", can_expand = true },
    { key = "src", parent = "root", label = "src", can_expand = true },
    { key = "main", parent = "src", label = "main.lua", fields = { path = "src/main.lua" } },
    { key = "readme", parent = "root", label = "README.md" },
  }):await()
  assert(imported.kind == "Applied", vim.inspect(imported))

  local source = data:source()
  local state = data:create_state({ kind = "children_of", node = source:id("root") }):await()
  assert(state.dispatch, vim.inspect(state))
  state:set_expanded({ source:id("src") }, true, false):await()
  local view = treeview.attach(state, { selection_recursive = true })
  -- Retain these handles in the feature that owns this view.
  _G.treeview_example = { data = data, state = state, view = view }
end)
```

`treeview.attach` 默认创建专用 scratch buffer，也可用 `bufnr` 交接已有的空 buffer；buffer 条件、默认键位与
`on_activate` 见 [View](view.md)。

## 更新与查询

`data:batch` 与 `data:import` 返回 `stl.c.Future`，完成值见 [Dispatch 与 Future](action.md#dispatch-与-future)。

```lua
local result = data:batch({
  { kind = "update", node = "main", label = "entry.lua" },
  { kind = "reparent", node = "main", parent = "root", position = "last" },
}):await()
```

结构引用字符串表示 provider key；已知 NodeId 使用 `{ id = node_id }`，更新目标也可直接使用 `id` 字段。
可选文本字段用 `false` 显式清除；`fields` 内的 null 使用 `vim.NIL`。显示文本须为单行，见[写入范围](data.md#写入范围)。

`state:set_display(options)` 替换全部展示选项（字段见 [Display 选项](projection.md#display-选项)）；
`state:set_root(root)` 替换展示范围；其余命令见[命令](module.md#命令)。展开 Toggle 使用
`state:dispatch({ kind = "toggle_expanded", node = id, recursive = false }, { frame = frame })`，
提交时校验捕获的 expanded 值；`set_expanded` 表达绝对赋值。
`state:inspect_selection()`、`state:lock_selection(deadline_ms?)` 和 task 的 `prepare_sources()` 都返回 Future。
Ready 中的 `source` 是对应版本的不可变 source；两组 NodeIds 使用 `:len()`、`:get(i)`、`:slice(first, last)` 按需读取。
任务结束使用 `task:unlock()`，成功项清理调用 `task:unselect(ready.cleanup, successful_ids)`。

## Provider 与分块输入

`data:create_provider(scope)` 创建独占写入范围，scope 语义见[写入范围](data.md#写入范围)。
少量数据可直接使用行式输入；列式输入见 `ux.treeview.IColumns`，`parent_keys` 适合跨 chunk 的父子关系。

完整大 snapshot 使用 `data:begin_import(scope)` 或 `provider:begin_import()` 分块 append，再一次 commit；
每块的条数与 Lua 输入字节上限见 [默认容量](action.md#默认容量)：

```lua
local upload = data:begin_import({ kind = "descendants", node = root_id })
local first = upload:append({ keys = { "folder" }, labels = { "folder" }, can_expand = { true } })
assert(first.kind ~= "Rejected", vim.inspect(first))
-- The producer can yield here before extracting the next chunk.
local second = upload:append({ keys = { "item" }, labels = { "item" }, parent_keys = { "folder" } })
assert(second.kind ~= "Rejected", vim.inspect(second))
local result = upload:commit():await()
```

每次 append 返回前取得该 chunk 的 Rust 所有权，只有 commit 才发布整份 snapshot；取消导入调用 `upload:dispose()`。
普通 import 直接取得全部输入所有权；需要分片控制主线程时间的 adapter 使用 chunk 接口。

普通 children 接入 `new_data({ read_children = function(request) ... end })`，返回 `{ records, done }` 或完成为该值的 Future；
provider 按 work 保存分页 cursor。普通错误不会自动重试，使用 `data:request_children({ node_id }, true)` 显式重试。
查询使用 `provider:create_query(handler)` 和 `query:start({ pattern, options? })`，handler 同样返回一页或 Future，
语义见 [query.md](query.md)。分页与读取调度见 [Children 读取调度](action.md#children-读取调度)。

## 状态与容量

`view:status()` 提供 publication、准备/失步状态与最近 RenderPlan（mode、原因、比较/写入行数与字节数）。
发布流程与失败恢复见 [render 契约](render.md)，成本与目标见 [performance](performance.md)，
默认上限及超限行为见 [默认容量](action.md#默认容量)。共享索引与 payload 随最后一个持有者释放，保留旧 Frame/source 会占用预算。
