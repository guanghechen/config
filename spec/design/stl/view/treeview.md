# Tree / Treeview 设计规范

## 目标

`Tree` 与 `Treeview` 只统一多个 feature 真实共享的两项能力：

1. `Tree` 维护有序、可变、无环的层级结构。
2. `Treeview` 将当前可见 tree topology 计算为紧凑、可导航的 `TreeLayout`。

Explorer、Picker、Searcher、Diffview 保留各自的业务状态、node data、render 和 UI 生命周期。

## 数据流

```text
feature topology/state
    │
    ▼
Treeview.layout()
    │
    ▼
TreeLayout
    │
    ▼
feature renderer / surface
```

- `Treeview.layout()` 是纯函数：不修改输入、不保存状态、不执行 IO。
- Layout 只包含 node ID、层级和 navigation，不包含 node data、text 或 highlight。
- Renderer 和 surface 负责读取业务数据、生成文字，并写入 buffer/extmark。

## `Tree`

`stl.c.Tree` 是默认可变 topology owner，只拥有结构：

```lua
Tree.new(root_id, root_data?)

tree:get(id)
tree:contains(id)
tree:parent(id)
tree:children(id)

tree:insert(parent_id, id, data, index?)
tree:update(id, data)
tree:move(id, parent_id, index?)
tree:remove(id)
tree:clear()
```

Base mutation 返回 topology owner 本身，支持 chaining，但不暴露内部 node object。Consumer 通过
`get/contains/parent/children` 读取 data 与 topology。

`Filetree.insert_*` 返回最终 canonical UUID；调用方无需读取内部 node，也无需重复计算 path hash。

结构不变式：

1. ID 是 opaque string 且全局唯一。
2. Root 不可移除或 reparent。
3. 新 parent 必须存在。
4. `move` 不得形成 cycle。
5. Child order 由 mutation call 显式决定；Tree 不持有 sorter。
6. 结构字段只有 Tree 可以写；node data 由 consumer 持有。
7. Tree 不存储 `selected/matched/expanded/loaded/visible` 等业务状态。

## `Treeview.layout`

```lua
---@class stl.view.treeview.ILayoutProps
---@field public roots any[]
---@field public id ?fun(node: any): string
---@field public children fun(node: any): any[]
---@field public collapsed table<string, true>|nil
---@field public can_fold ?fun(parent: any, child: any): boolean
```

- `roots` 定义有序 forest；元素可以直接是 string ID，也可以是 source node。
- `id(node)` 将 source node 映射到 string ID；省略时，source node 本身必须是 string ID。
- `children(node)` 返回该次 layout 的可见、已排序 children；Layout 不复制返回数组。
- `collapsed[id] == true` 时保留当前 node，但不读取其 children。
- `can_fold(parent, child)` 仅在 parent 恰有一个可见 child 时调用；返回 `true` 将两者合并到同一行。
- Filter、list order 和 root attachment 均由 feature 在调用 layout 前决定。
- 同一 ID 在一次 layout 中不得重复出现；重复 ID 同时覆盖 cycle 和 multi-parent DAG 错误。

复杂度 contract 假设 `id(node)`、`children(node)` 与 `can_fold(parent, child)` 为 `O(1)`，且
`children(node)` 返回 source 已持有的 dense array。Feature 若需要动态 filter，应在 layout 前构建或复用
projected children；其计算和 allocation 不计入 layout 本身的复杂度。

高性能约束：

1. 使用 iterative DFS，不使用递归。
2. Hot path 不创建 per-node object、context 或 render result table。
3. 每个 source node 最多调用一次 `id(node)`。
4. 每个展开 node 最多调用一次 `children(node)`。
5. 每条 eligible single-child edge 最多调用一次 `can_fold(parent, child)`。
6. 不复制 node ID string、source node 或 children array。
7. 利用必需的 `id_to_lnum` 同时检测重复 ID，不额外维护 visited set。

## `TreeLayout`

`TreeLayout` 是 opaque object。Consumer 只能使用公开方法，不得读取内部字段。

```lua
layout:len()
layout:last_root_lnum()

layout:id(lnum)
layout:lnum(id)
layout:depth(lnum)
layout:folded_ids(lnum)

layout:parent_lnum(lnum)
layout:first_child_lnum(lnum)
layout:last_child_lnum(lnum)
layout:last_descendant_lnum(lnum)
layout:next_sibling_lnum(lnum)
layout:is_last(lnum)
```

内部使用紧凑平行数组，而不是 per-row table：

```lua
{
  _ids = string[],
  _last_root_lnum = integer,
  _depths = integer[],
  _parent_lnums = integer[],
  _last_child_lnums = integer[],
  _last_descendant_lnums = integer[],
  _id_to_lnum = table<string, integer>,
  _folded_ids_by_lnum = table<integer, string[]>,
}
```

`0` 是内部 navigation sentinel，确保 numeric arrays 保持 dense；公开方法将其转换为 `nil`。

只有无法由现有数组以 `O(1)` 推导的 navigation 才存储。`last_child_lnum` 在 traversal 时顺手维护；以下
navigation 不重复存储：

- `first_child_lnum = lnum + 1`，前提是下一行 parent 等于当前行。
- `next_sibling_lnum = last_descendant_lnum + 1`，前提是候选行 parent 相同。
- `is_last = next_sibling_lnum == nil`。

## 复杂度 Contract

令：

- `V` 为 fold 前的可见 source node 数。
- `R` 为 fold 后的输出 row 数，且 `R <= V`。
- `E` 为实际遍历的 parent-child edge 数；tree 中 `E < V`。
- `H` 为可见 tree 最大深度。

| 操作                         | 时间复杂度       | 额外空间复杂度 |
|:-----------------------------|:-----------------|:---------------|
| `Treeview.layout`            | `O(V + E)`       | `O(V + H)`     |
| Layout row arrays            | -                | `O(R)`         |
| ID map 与 folded chain       | -                | `O(V)`         |
| Iterative traversal stack    | -                | `O(H)`         |
| `id(lnum)` / `depth(lnum)`   | `O(1)`           | `O(1)`         |
| `lnum(id)`                   | average `O(1)`   | `O(1)`         |
| Parent/child/sibling 查询    | `O(1)`           | `O(1)`         |

实现预算以当前开发机为基准：

- 5,000 nodes layout `< 1ms`。
- 50,000 nodes layout `< 8ms`。
- 50,000 nodes layout heap `< 8MiB`。
- Depth 10,000 不得 stack overflow。

Regular test 使用更宽松的 regression ceiling，避免硬件差异导致 flaky；精确预算由 benchmark 验证。

## Fold-single-child

Fold 不得丢失 node identity：

```lua
layout:folded_ids(lnum)
```

- Fold predicate 只决定单子节点 edge 是否可折叠，不承担 filter、sort 或 render。
- 一条 folded chain 使用最深层 ID 作为该行的 representative，即 `layout:id(lnum)` 的返回值。
- `folded_ids(lnum)` 返回包含 representative 在内的完整 source ID chain；返回数组为只读 borrowed view。
- Fold chain 中所有 ID 都映射到同一 `lnum`。
- 只有实际发生 fold 的行才分配 ID array，总时间和空间仍保持 `O(V)`。

## 状态所有权

公共层不拥有业务状态：

- Explorer：`loaded/expanded/selection/pending transfer/watch`。
- Picker：`matched/order/selection`。
- Searcher：request generation、location、replace、visibility。
- Diffview：collapsed directory set 和 stage-specific state。

Feature 将状态转换为 `roots/children/collapsed` 后调用 layout。Treeview 不提供 selection、match、root
history、render cache 或 lazy-load API。

## 渲染边界

Layout 不接收 `bufnr`，不调用 `vim.api`、`vim.fn` 或 filesystem API。

Renderer 使用 positional arguments 和 multiple returns，避免 per-node context/result table。允许每次 render 创建一个共享、只读的
render-scoped context，用于 root data 与 feature-owned source；同一 context 复用于所有 row，不进入 `TreeLayout`：

```lua
text, highlights = renderer(ctx, id, data, state, lnum, metadata...)
```

- `data/state` 由 surface 在调用前解析，renderer 不反向 lookup。
- `metadata...` 只传当前 node kind 实际需要的 positional value，例如 `location_state` 或 `folded_depth`。
- `depth/is_last` 若只用于生成 tree connector，应由 surface 直接消费，不要求 feature renderer 重复接收。
- Renderer 不返回 per-row object；额外 surface metadata 确有 consumer 时才增加 multiple return value。

Surface 负责批量写入 lines、应用 highlights，以及添加 sign、virt text、diagnostic 或异步 icon；只有这些 surface
能力确实需要 feature renderer 提供额外信息时，才扩展 multiple return contract。

## 非目标

1. 不提供通用 filesystem tree 或 remote filesystem adapter。
2. 不定义 selection、match、search、replace 或 lazy-load 语义。
3. 第一版不提供 tick-based cache 或 incremental render。
4. 不兼容旧 `era.view.Tree` / stateful `stl.view.Treeview` API；迁移完成后删除旧实现。
