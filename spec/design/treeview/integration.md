# Treeview 接入

Rust core 位于 `rust/yoz/src/ux/treeview/`，Lua surface 使用 `require("ux.treeview")`。
权威语义见 [Treeview 设计](README.md)，Lua 字段与原生方法见
[treeview.lua](../../../lua/__types__/ux/treeview.lua) 和 [yoz/ux.lua](../../../lua/__types__/yoz/ux.lua)。

## 选择入口

各 consumer 的数据路径见 [Treeview 索引](README.md)。真实目录浏览使用 `require("ux.filetree")`（见 [Filetree](../filetree.md)），
业务结果通过 ResultTree 导入（见 [结果集接入](results.md)）；直接提供通用层级数据时使用下述 `ux.treeview` API。
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

`treeview.attach` 默认创建专用 scratch buffer，也可用 `bufnr` 交接已有的空 buffer，条件见
[State、View 与共享](module.md#stateview-与共享)。默认 buffer-local 键位：

| 按键         | 模式            | 行为                                                                     |
| ------------ | --------------- | ------------------------------------------------------------------------ |
| `[i` / `]i`  | Normal / Visual | 结构导航，见 [indentline](indentline.md#结构导航)                        |
| `<CR>`       | Normal          | 切换展开或调用 `on_activate`，见 [expansion](expansion.md#consumer-动作) |
| `<Esc><Esc>` | Normal / Visual | 退出 Visual 并清空 selection，见 [visual](visual.md#移动与共享-state)    |
| `<Tab>`      | Normal / Visual | 仅在传入 boolean `selection_recursive` 时绑定，按该 scope 切换选择       |

`keymaps = false` 关闭全部默认键位，由 consumer 自行映射。Leaf 的激活由 `on_activate(frame, node_id)` 接入；
`view:select("select_node", false)` 可显式提交自身选择，Normal/Visual 都使用实际显示的 Frame。

## 更新与查询

`data:batch(operations, base_revision?)`、`data:import(records, scope?, base_revision?)` 返回 `stl.c.Future`。
省略 base 时捕获调用时的 source revision；两个同时发出的更新若基于同一旧版本，后者可能被拒绝，调用方应按事实重新准备。
普通拒绝是完成值 `{ kind = "Rejected", error = { code, message, node? } }`。
`Applied` 只保证提交完成；`view:frame()` 表示已实际发布的 Frame。

```lua
local result = data:batch({
  { kind = "update", node = "main", label = "entry.lua" },
  { kind = "reparent", node = "main", parent = "root", position = "last" },
}):await()
```

结构引用字符串表示 provider key；已知 NodeId 使用 `{ id = node_id }`，更新目标也可直接使用 `id` 字段。
NodeId、revision、request token 都应原样传回。行输入使用 1-based 闭区间；RenderPlan splice 使用
0-based、end-exclusive 坐标。可选文本字段用 `false` 显式清除；`fields` 内的 null 使用 `vim.NIL`。
显示文本须为单行，见[写入范围](data.md#写入范围)。

`state:set_display(options)` 替换全部展示选项（字段见 [Display 选项](projection.md#display-选项)）；
`state:set_root(root)` 替换展示范围。展开 Toggle 使用
`state:dispatch({ kind = "toggle_expanded", node = id, recursive = false }, { frame = frame })`，
提交时校验捕获的 expanded 值；`set_expanded` 继续表达绝对赋值。
`select_node(nodes, recursive)` / `deselect_node` 的 recursive 必须是 boolean；`toggle_node` 还需提供捕获的 Frame。
`state:inspect_selection()`、`state:lock_selection(deadline_ms?)` 和 task 的 `prepare_sources()` 都返回 Future。
Ready 中的 `source` 是对应版本的不可变 source；两组 NodeIds 使用 `:len()`、`:get(i)`、`:slice(first, last)` 按需读取。
任务结束使用 `task:unlock()`，成功项清理调用 `task:unselect(ready.cleanup, successful_ids)`。

## Provider 与分块输入

`data:create_provider(scope)` 创建独占写入范围。`forest` 覆盖 forest；`descendants` 覆盖 anchor 以下整棵子树；
`children` 只声明 anchor 的直接 children，不清除保留 child 的后代。后两种 scope 使用 `{ kind, node = node_id }`。

少量数据可直接使用行式输入；列式输入包含 `keys`、`labels`，可选列长度必须一致。
`parents` 使用批内 1-based 索引，0 表示范围入口；`parent_keys` 使用 key 或 false，适合跨 chunk 的父子关系。
两种 parent 列只能提供一种。

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

每次 append 返回前取得该 chunk 的 Rust 所有权，只有 commit 才发布整份 snapshot。取消导入调用 `upload:dispose()`；
每个 data 同时保留的私有导入数有上限。普通 import 直接取得全部输入所有权；需要分片控制主线程时间的 adapter 使用 chunk 接口。

普通 children 接入 `new_data({ read_children = function(request) ... end })`，返回 `{ records, done }` 或完成为该值的 Future。
请求提供 `work`、`sequence`、`node`、只读 `source` 与 `is_cancelled()`；provider 按 work 保存分页 cursor。
每页被 owner 消费后才请求下一页。普通错误不会自动重试，使用 `data:request_children({ node_id }, true)` 显式重试。
普通 View 正在准备发布时，下一页等待该次交接完成；Visual 持帧或失败的 View 不阻塞其他消费者。
Native completion 通过可合并通知唤醒 Lua；空闲 View 不持续轮询。

查询使用 `provider:create_query(handler)` 和 `query:start({ pattern, options? })`。
Handler 同样返回一页或 Future；首批替换旧结果，后续页追加。`query:cancel()` 关闭当前轮结果资格；
查询来源、分页顺序和旧 generation 的清理均由 Rust 校验，语义见 [query.md](query.md)。
`data:source():query_result(scope)` 按需读取该 scope 最近已提交结果的 session、generation、pattern 和 completeness；
这份归属随 source 保留，释放 query session 后仍可读取。旧 Frame 使用 `frame:source():query_result(scope)`。

## 状态与容量

`view:status()` 提供 publication、准备/失步状态与最近 RenderPlan（mode、原因、比较/写入行数与字节数）。
发布部分失败时暂停该 View 的行输入并尝试一次完整 resync；持续失败后由 `view:refresh()` 显式恢复。
`view:detach()` 解除 View，已经接受的命令继续完成。发布流程见 [render 契约](render.md)，
成本与目标见 [performance](performance.md)。

Rust 保留预算、节点、payload、批次、读取、staging 与 viewport 读取等默认上限及超限行为统一见 [默认容量](action.md#默认容量)。共享索引与 payload 随最后一个持有者释放，
保留旧 Frame/source 会占用预算。Rust 内部计量使用结构尺寸及 payload allocation 估算，allocator 与 Neovim/Lua 内存需结合进程测量。

## 构建与验证

```sh
cargo build --offline --locked --manifest-path rust/Cargo.toml -p yoz --lib
cargo test --offline --locked --manifest-path rust/Cargo.toml --workspace --all-targets
nvim -l __test__/run.lua ux/treeview/
nvim -l __test__/run.lua ux/filetree/
nvim -l __test__/run.lua era/m/explorer/
node script/build.mjs --offline
nvim -l __test__/bench/treeview.lua > treeview-ui-benchmark.json
```

macOS 直接运行 Cargo 时的配置与 SDK 选择见 [Native module build](../../../README.md#native-module-build)。
Native specs 直接加载 debug library；完整 bootstrap 的 UI specs 和 benchmarks 使用部署的 release library，
修改 Rust 后分别构建，避免验证旧动态库。更多筛选命令见[测试指南](../../../__test__/README.md#run)，
测量结果见 [Treeview 测量记录](../../../__test__/bench/treeview.md)。
