# Treeview 接入

Rust core 位于 `rust/yoz/src/ux/treeview/`，Lua surface 使用 `require("ux.treeview")`。
权威语义见 [Treeview 设计](spec/treeview/README.md)，Lua 字段与原生方法见
`lua/__types__/ux/treeview.lua` 和 `lua/__types__/yoz/ux.lua`。

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

每个 view 创建专用 buffer。`[i` / `]i` 执行结构导航，`<CR>` 展开/折叠分支；leaf 的激活由
`on_activate(frame, node_id)` 接入。传入明确的 `selection_recursive` 后才绑定 `<Tab>`。
`view:select("select_node", false)` 可显式提交自身选择，Normal/Visual 都使用实际显示的 frame。

## 更新与查询

`data:batch(operations, base_revision?)`、`data:import(records, scope?, base_revision?)` 返回 `stl.c.Future`。
省略 base 时捕获调用时的 source revision；两个同时发出的更新若基于同一旧版本，后者可能被拒绝，调用方应按事实重新准备。
普通拒绝是完成值 `{ kind = "Rejected", error = { code, message, node? } }`。
`Applied` 只保证提交完成；`view:frame()` 表示已实际发布的 frame。

```lua
local result = data:batch({
  { kind = "update", node = "main", label = "entry.lua" },
  { kind = "reparent", node = "main", parent = "root", position = "last" },
}):await()
```

结构引用字符串表示 provider key；已知 NodeId 使用 `{ id = node_id }`，更新目标也可直接使用 `id` 字段。
NodeId、revision、request token 都应原样传回。行输入使用 1-based 闭区间；RenderPlan splice/text range 使用
0-based、end-exclusive 坐标。可选文本字段用 `false` 显式清除；`fields` 内的 null 使用 `vim.NIL`。

`state:set_display(options)` 替换展示选项；`state:set_root(root)` 替换展示范围。
展开 Toggle 使用 `state:dispatch({ kind = "toggle_expanded", node = id, recursive = false }, { frame = frame })`，
提交时校验捕获的 expanded 值；`set_expanded` 继续表达绝对赋值。
`select_node(nodes, recursive)` / `deselect_node` 的 recursive 必须是 boolean；`toggle_node` 还需提供捕获的 frame。
`state:inspect_selection()`、`state:lock_selection(deadline_ms?)` 和 task 的 `prepare_sources()` 都返回 Future。
Ready 中的 `source` 是对应版本的不可变 source；两组 NodeIds 使用 `:len()`、`:get(i)`、`:slice(first, last)` 按需读取。
任务结束使用 `task:unlock()`，成功项清理调用 `task:unselect(ready.cleanup, successful_ids)`。

## Provider 与分块输入

`data:create_provider(scope)` 创建独占写入范围。`forest` 覆盖 forest；`descendants` 覆盖 anchor 以下整棵子树；
`children` 只声明 anchor 的直接 children，不清除保留 child 的后代。后两种 scope 使用 `{ kind, node = node_id }`。

少量数据可直接使用行式输入；列式输入包含 `keys`、`labels`，可选列长度必须一致。
`parents` 使用批内 1-based 索引，0 表示范围入口；`parent_keys` 使用 key 或 false，适合跨 chunk 的父子关系。
两种 parent 列只能提供一种。

完整大 snapshot 可使用 `data:begin_import(scope)` 或 `provider:begin_import()`，每次最多 append 512 条，
且该 chunk 的 Lua 输入计量（含字段与容器开销）不超过 1 MiB：

```lua
local upload = data:begin_import({ kind = "descendants", node = root_id })
local first = upload:append({ keys = { "folder" }, labels = { "folder" }, can_expand = { true } })
assert(first.kind ~= "Rejected", vim.inspect(first))
-- The producer can yield here before extracting the next chunk.
local second = upload:append({ keys = { "item" }, labels = { "item" }, parent_keys = { "folder" } })
assert(second.kind ~= "Rejected", vim.inspect(second))
local result = upload:commit():await()
```

每次 append 返回前取得该 chunk 的 Rust 所有权，只有 commit 才发布整份 snapshot。
取消导入调用 `upload:dispose()`；每个 data 最多保留两个私有导入。普通 import 调用直接取得全部输入所有权；
需要分片控制主线程时间的 adapter 应使用上述显式 chunk 接口。

普通 children 接入 `new_data({ read_children = function(request) ... end })`，返回 `{ records, done }` 或完成为该值的 Future。
请求提供 `work`、`sequence`、`node`、只读 `source` 与 `is_cancelled()`；provider 按 work 保存分页 cursor。
每页被 owner 消费后才请求下一页。普通错误不会自动重试，使用 `data:request_children({ node_id }, true)` 显式重试。
普通 view 正在准备发布时，下一页等待该次交接完成；Visual 持帧或失败的 view 不阻塞其他消费者。
Native completion 使用共享 timer 轮询：有在途工作时 1 ms，空闲 watcher 为 5 ms。

查询使用 `provider:create_query(handler)` 和 `query:start({ pattern, options? })`。
Handler 同样返回一页或 Future；首批替换旧结果，后续页追加。`query:cancel()` 关闭当前轮结果资格；
查询来源、分页顺序和旧 generation 的清理均由 Rust 校验。
`data:source():query_result(scope)` 按需读取该 scope 最近已提交结果的 session、generation、pattern 和 completeness；
这份归属随 source 保留，释放 query session 后仍可读取。旧 frame 使用 `frame:source():query_result(scope)`。

## 验证与容量

```sh
cargo test --offline --manifest-path rust/Cargo.toml --workspace --all-targets
cargo build --offline --manifest-path rust/Cargo.toml -p yoz --lib
nvim -l __test__/run.lua ux/treeview/
cargo test --offline --release --manifest-path rust/Cargo.toml -p yoz --lib t_release_performance_sample -- --ignored --nocapture
CARGO_NET_OFFLINE=true node script/build.mjs
nvim -l __test__/bench/treeview.lua > treeview-ui-benchmark.json
```

macOS 的 Cargo 命令需追加 `--config .cargo/config.macos.toml`，使用仓库固定的 SDK；build script 已自动使用该配置。
如果系统升级后 Xcode 尚未配置，可在以上命令前设置 `DEVELOPER_DIR=/Library/Developer/CommandLineTools`，使用已有的 Command Line Tools。
Lua tests 加载 debug library，UI benchmark 加载 build script 部署的 release library，运行前分别重建。

默认 Rust 保留预算为 512 MiB，另有节点、payload、批次、action queue、读取并发和私有输入暂存限制。
共享索引与 payload 随最后一个持有者释放；保留旧 frame/source 会占用预算。Lua staging 限制为 64 MiB，装饰按 viewport 查询。
Rust 内部计量使用结构尺寸及 payload allocation 估算，allocator 和 Neovim/Lua 内存需结合进程测量。
正文按最多 512 行、64 KiB 分块准备；超过单片预算的单行拒绝发布。Viewport 每次最多读取 512 行、1 MiB 行数据，
另限制为最多 8192 个匹配和 8192 个 guide。超限返回 `ResourceLimit`，不截断 source 或篡改已有 frame。

`view:status()` 提供 publication、准备/失步状态、最近 RenderPlan 的比较行数、传输行数和字节数。
发布部分失败时暂停该 view 的行输入并尝试一次完整 resync；持续失败后由 `view:refresh()` 显式恢复。
`view:detach()` 解除 surface，已经接受的命令继续完成。
准备期间发生 cursor/装饰更新，只有 Rust 确认正文及布局版本均相同时才复用 staging，并发布最新完整 frame。

Tree/List 的局部 projection 覆盖 source/name/score 排序、branches-first、compression、selected-only 和固定 filter。
压缩链变化合并旧/新父链；filter 在不可变 frame 中保留匹配子项的共享顺序索引，按变更更新连接祖先。
行位置使用 projection 顺序的 rank 查询，不扫描被过滤的 siblings；排序 List 的单项 label/score 更新只移动该行。
正文 label 直接引用当前 source 的 allocation，文本更新只替换相关行块；connector 单独变化保留 layout revision。

更换 pattern、排序方式、display root，影响整个展示范围的继承变化，或超过 4096 条失效提示预算时，仍会全量重算。
局部成本包含受影响子树、祖先/排序依赖、索引路径和实际输出字节；不把所有操作描述成统一的 O(D)。

性能样本必须区分 Rust 计算、Lua staging、buffer 发布与 UI redraw；单独的结构或容器测试不代表全部性能目标已达标。

2026-09-16 补齐局部投影后的合成 UI 样本：Apple M2 Max / 32 GiB、Darwin 27 arm64、Neovim 0.12.5，release build；
50,001 个 source 节点、50,000 行投影、96-byte label、80×48 UI，每行两处高亮和右对齐文本。
单行更新、Selection、filter 各 100 次；sort 300 次，额外持有初始 frame。各轮均单独运行，包含自然 GC。
以下为输入到适用 frame 的 UI flush 延迟：

| 路径        | p50 ms | p95 ms | max ms |
| ----------- | -----: | -----: | -----: |
| 单行更新    |  0.903 |  3.369 |  7.131 |
| Selection   |  3.409 |  4.266 |  6.328 |
| 全局 filter | 16.776 | 41.464 | 43.421 |
| 全局 sort   | 45.241 | 48.788 | 50.735 |

压缩链拆合、排序视图单项插入各 100 次，p95 分别为 2.15 / 1.90 ms；修复前对应值为 8.88 / 9.69 ms。
另一个宽目录含 50,000 个直接 children；selected-only 单项变化 p95 为 5.41 ms。
结构测试同时断言重算节点小于 20、至少 49,800 行及匹配子项保持块共享，并与独立全量投影对照。
15 组模式组合覆盖 4,500 次 mixed updates、旧 frame、hidden/foldable、选中/展开、label/score 和 reparent。
Rust workspace/all-target 338 项通过（另 1 项性能测试默认忽略），Lua/UI 17 项通过；UI 包含 Visual 内 connector 更新。

2026-09-16 补充真实数据链路验收。运行 `nvim -l __test__/bench/treeview_consumers.lua <consumer> [samples]`，
consumer 为 `filetree`、`searcher`、`git` 或 `lsp`，默认 100 个正式样本，另有 5 次预热。
脚本使用 release library、附着 UI 和自然 GC；`lsp` 使用已安装的 Mason Lua language server。
Adapter 位于测试 fixture，验收到 Treeview surface，不切换现有业务入口。

| 链路与数据形状 | 输入到首批 flush p95 | 输入到末批 flush p95 | 数据就绪到末批 flush p95 |
| --- | ---: | ---: | ---: |
| Filetree：真实 fs event + native readdir，128/129 个文件 | 52.69 ms | 52.69 ms | 2.40 ms |
| Searcher：native search 当前 Treeview Rust 源码，507 行，4 页 | 7.51 ms | 28.98 ms | 24.92 ms |
| Git：当前 checkout 的 status + numstat，52 行 | 36.39 ms | 36.39 ms | 2.86 ms |
| LSP：真实 documentSymbol response，315 行 | 220.58 ms | 220.58 ms | 5.11 ms |

Filetree 完整时间包含 OS watch 通知等待；LSP 完整时间包含 language server 等待，不能当作已加载数据的局部交互延迟。
Searcher 原生 job 完成后提供完整结果，测试 adapter 每页提取最多 128 行；原生结果导出的主线程成本也计入测量，
本组 native poll 累计 p95 为 1.87 ms，末批时间包含后续分页与发布背压。
JSON 另保存 plan 请求/完成的 Lua 观察时点、staging、buffer 写入、Lua heap、实际 buffer bytes 与关闭成本；
这些观察时点不冒充 Rust worker 内部提交时点。所有样本最终 queue 为 0，没有持久逐行 extmarks，关闭后弱引用中的
data/state/query/provider/view 和专用 buffers 均已回收。GC 检查在关闭函数返回后的独立 RPC 中执行，
避免关闭栈临时引用影响弱引用检查；关闭与 GC 成本分别记录。
另对当前 `view.lua` 做了 100 次真实 Tree-sitter 解析、Lua 提取与 UI 发布，28 个函数节点，完整 flush p95 为 4.17 ms。

补充压力结果与适用范围：

- 50k 行局部路径的访问节点数、行块/子项索引共享与实际正文差量已分别验证，不能只用延迟推断复杂度。
- 12 轮三 view 流式测试：旧 query 第 10 页取消，新 query 40 × 500 项；同时输入、滚动与 Visual 持帧。
  1,071 次 Applied 输入到首个包含该 commit 的 frame flush，p95 为 36.74 ms，最大 44.39 ms。
  其中 744 次 cursor 状态在发布前被后续输入覆盖，未被覆盖的 327 次 p95 为 10.52 ms。另有 369 次 MissingNode 拒绝，来自旧 frame 引用已被查询替换的节点。
  输入完成与 publication/flush 独立记录后关联，避免完成通知晚于发布时漏算，也不要求已经显示的 frame 仍是此刻最新。
  每轮最终显示 20k 项、queue 为 0、旧 generation 无残留。压力档结果不套用静态基线的 16 ms 目标。
- Rust 独立 allocator：96-byte label、path payload、highlight/right text、旧 frame；50k 行 3 个 states 和
  200k 行 1 个 state 各重排 20 轮，live requested allocations 分别稳定在 183.02 / 601.67 MiB，
  单阶段峰值为 221.07 / 691.02 MiB。测试显式使用 1 GiB retained、256 MiB batch 预算，不能据此声称默认容量通过。
  20k 项、3 个 states 的查询替换经过容量增长后稳定在 140.00 MiB，峰值 204.44 MiB；旧 frame 释放后降至 83.00 MiB。
  释放 engine 后分别剩余 40 / 0 / 0 bytes；40 bytes 为首次初始化的共享静态空 fields。
- 50k 行 UI 连续 100 次 detach/attach 与各 500 项插删，旧 view 弱引用全部释放，关闭后只剩原始 buffer。
  GC 后 Lua heap 保持约 0.78–1.06 MiB，关闭后约 0.87 MiB。5 ms 采样得到的 Lua heap / 进程 RSS 峰值分别为
  36.16 / 175.13 MiB；采样可能遗漏短暂峰值。Rust requested allocations、Lua heap 和进程 RSS 按各自口径报告，
  不相加或用 allocator 保留的 RSS 推断泄漏。

本轮原始结果、压力脚本与 snapshot 位于 `local/20260916/treeview-local-completion/`；前轮记录保留在
`local/20260916/treeview-verification/`。它们是验收记录，不是设计契约。
