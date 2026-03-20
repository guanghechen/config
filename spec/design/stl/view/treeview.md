# Treeview 设计规范

Treeview 是 picker/searcher 的底层视图组件，提供统一的树形数据展示与交互能力。

## 核心概念

| 概念        | 说明                                                                 |
|:------------|:---------------------------------------------------------------------|
| `superroot` | 超级根节点，treeview 中所有节点的共同祖先，不可变更                  |
| `root`      | 当前视图根节点，仅展示其子孙节点；支持通过 attach/detach 切换        |
| `container` | 容器节点，拥有子节点的非终端节点                                     |
| `leaf`      | 叶子节点，无子节点的终端节点                                         |
| `location`  | 位置节点，leaf 节点下的子位置（如搜索结果中的行位置）                |

## 架构

```
stl.c.Tree (数据层，节点增删改查)
    │
    ▼
stl.view.Treeview (视图层，状态管理 + 渲染)
    │
    ├── era.m.picker (匹配、高亮)
    └── era.m.searcher (搜索、替换)
```

**职责划分**：

| 模块                | 职责                                               |
|:--------------------|:---------------------------------------------------|
| `stl.c.Tree`        | 纯数据结构，节点增删改查、遍历                     |
| `stl.view.Treeview` | 视图状态 + root 切换 + 渲染 + navigation 索引构建  |
| `picker/searcher`   | 业务逻辑、UI 交互、匹配/搜索功能                   |

## 数据结构

### INodeStatus

节点状态，存储在 Treeview 的 `_statusmap` 中，与 Tree 节点数据分离：

```lua
---@class stl.view.treeview.INodeStatus
---@field public nodetype               "container"|"leaf"
---@field public collapsed              boolean
---@field public tick_visible           integer
---@field public tick_matched           integer
---@field public tick_selected          integer
---@field public tick_selected_maximum  integer   -- 子树最大选中 tick
---@field public locations              ILocationStatus[]|nil  -- leaf 专用
---@field public cache_listview         INodeRenderCache|nil
---@field public cache_treeview         INodeRenderCache|nil
```

### ILocationStatus

位置状态，用于 leaf 节点下的子位置：

```lua
---@class stl.view.treeview.ILocationStatus
---@field public nodetype               "location"
---@field public leafuuid               string
---@field public locationuuid           string
---@field public tick_visible           integer
---@field public data                   unknown|nil
```

### INavigation

渲染时构建的跳转索引，支持 `[i` / `]i` 等导航：

```lua
---@class stl.view.treeview.INavigation
---@field public parent_lnum            integer[]     -- lnum -> parent_lnum
---@field public firstchild_lnum        integer[]     -- lnum -> firstchild_lnum
---@field public lastchild_lnum         integer[]     -- lnum -> lastchild_lnum
---@field public prev_sibling_lnum      integer[]     -- lnum -> prev_sibling_lnum
---@field public next_sibling_lnum      integer[]     -- lnum -> next_sibling_lnum
```

### IRenderResult

渲染结果，包含行内容、高亮、索引映射和导航信息：

```lua
---@class stl.view.treeview.IRenderResult
---@field public lines                  string[]
---@field public highlights             IHighlightInline[][]
---@field public indents                string[]
---@field public lnum2uuid              string[]
---@field public uuid2lnum              table<string, integer>
---@field public childline              integer[]
---@field public navigation             INavigation
```

## 方法设计

### 构造与生命周期

| 方法         | 签名                              | 说明                         |
|:-------------|:----------------------------------|:-----------------------------|
| `new`        | `(props: IProps) -> Treeview`     | 创建实例                     |
| `dispose`    | `() -> nil`                       | 释放资源                     |
| `isdisposed` | `() -> boolean`                   | 检查是否已释放               |

### Root 管理

| 方法         | 签名                              | 说明                         |
|:-------------|:----------------------------------|:-----------------------------|
| `root`       | `() -> string`                    | 获取当前 root uuid           |
| `superroot`  | `() -> string`                    | 获取 superroot uuid          |
| `attach`     | `(uuid: string) -> self`          | 将指定节点设为新的 root      |
| `detach`     | `() -> self`                      | 回退到上一个 root            |
| `reset_root` | `() -> self`                      | 重置到 superroot             |

**attach/detach 行为**：

```
初始状态: root = superroot, history = []

attach(A) -> root = A, history = [superroot]
attach(B) -> root = B, history = [superroot, A]
detach()  -> root = A, history = [superroot]
detach()  -> root = superroot, history = []
```

### 状态管理

| 方法                | 签名                                          | 说明                   |
|:--------------------|:----------------------------------------------|:-----------------------|
| `ensure_status`     | `(uuid, nodetype) -> INodeStatus`             | 确保节点状态存在       |
| `retrieve_status`   | `(uuid) -> INodeStatus\|nil`                  | 获取节点状态           |
| `remove_status`     | `(uuid) -> nil`                               | 删除节点状态           |
| `clear_statusmap`   | `() -> nil`                                   | 清空所有状态           |

### 可见性状态

| 方法               | 签名                              | 说明                         |
|:-------------------|:----------------------------------|:-----------------------------|
| `is_visible`       | `(uuid) -> boolean`               | 检查节点是否可见             |
| `mark_invisible`   | `(uuid) -> nil`                   | 标记节点及子孙不可见         |
| `reset_visibility` | `() -> nil`                       | 重置可见性（所有节点变可见） |

### 匹配状态

| 方法           | 签名                              | 说明                         |
|:---------------|:----------------------------------|:-----------------------------|
| `is_matched`   | `(uuid) -> boolean`               | 检查节点是否匹配             |
| `mark_matched` | `(uuid) -> nil`                   | 标记节点为匹配               |
| `reset_match`  | `() -> nil`                       | 重置匹配状态                 |

### 选中状态

| 方法                       | 签名                                    | 说明                   |
|:---------------------------|:----------------------------------------|:-----------------------|
| `is_selected`              | `(uuid) -> boolean`                     | 检查节点是否选中       |
| `set_selected`             | `(uuid, selected, recursive) -> nil`    | 设置选中状态           |
| `toggle_selected`          | `(uuid, recursive) -> nil`              | 切换选中状态           |
| `reset_selection`          | `() -> nil`                             | 重置选中状态           |
| `refresh_selected_maximum` | `() -> nil`                             | 刷新子树选中 tick      |

### 折叠状态

| 方法           | 签名                                    | 说明                         |
|:---------------|:----------------------------------------|:-----------------------------|
| `is_collapsed` | `(uuid) -> boolean`                     | 检查节点是否折叠             |
| `collapse`     | `(uuid, action, recursive) -> nil`      | 设置折叠状态                 |

**action 取值**：`"collapse"` | `"expand"` | `"toggle"`

### Location 管理

| 方法            | 签名                                    | 说明                         |
|:----------------|:----------------------------------------|:-----------------------------|
| `set_locations` | `(leafuuid, locations) -> nil`          | 设置 leaf 的 locations       |
| `get_locations` | `(leafuuid) -> ILocationStatus[]\|nil`  | 获取 leaf 的 locations       |

### 渲染

| 方法              | 签名                                              | 说明           |
|:------------------|:--------------------------------------------------|:---------------|
| `render_listview` | `(params: IRenderListviewParams) -> IRenderResult`| 渲染列表视图   |
| `render_treeview` | `(params: IRenderTreeviewParams) -> IRenderResult`| 渲染树形视图   |

**渲染参数**：

```lua
---@class stl.view.treeview.IRenderListviewParams
---@field public bufnr                  integer
---@field public orders                 string[]|nil  -- 自定义顺序
---@field public only_visible           boolean
---@field public only_matched           boolean
---@field public only_selected          boolean
---@field public render_leaf            ILeafRenderer
---@field public render_location        ILocationRenderer|nil

---@class stl.view.treeview.IRenderTreeviewParams
---@field public bufnr                  integer
---@field public foldempty              boolean       -- 是否折叠单子节点路径
---@field public only_expanded          boolean       -- 是否只渲染展开节点
---@field public only_visible           boolean
---@field public only_matched           boolean
---@field public only_selected          boolean
---@field public render_container       IContainerRenderer
---@field public render_leaf            ILeafRenderer
---@field public render_location        ILocationRenderer|nil
```

### 缓存管理

| 方法                      | 签名           | 说明                   |
|:--------------------------|:---------------|:-----------------------|
| `mark_cache_listview_dirty` | `() -> nil`  | 标记列表缓存为脏       |
| `mark_cache_treeview_dirty` | `() -> nil`  | 标记树形缓存为脏       |
| `mark_cache_all_dirty`    | `() -> nil`    | 标记所有缓存为脏       |

### 收集辅助

| 方法              | 签名                              | 说明                   |
|:------------------|:----------------------------------|:-----------------------|
| `collect_leafs`   | `(root?) -> string[]`             | 收集所有叶子节点       |
| `collect_selected`| `(root?) -> table<string, true>`  | 收集所有选中节点       |
| `collect_matched` | `(root?) -> string[]`             | 收集所有匹配节点       |
| `collect_visible` | `(root?) -> string[]`             | 收集所有可见节点       |

### 导航辅助（静态方法）

| 方法              | 签名                                    | 说明               |
|:------------------|:----------------------------------------|:-------------------|
| `nav_parent`      | `(navigation, lnum) -> integer\|nil`    | 获取父节点行号     |
| `nav_firstchild`  | `(navigation, lnum) -> integer\|nil`    | 获取首子节点行号   |
| `nav_lastchild`   | `(navigation, lnum) -> integer\|nil`    | 获取末子节点行号   |
| `nav_prev_sibling`| `(navigation, lnum) -> integer\|nil`    | 获取前兄弟行号     |
| `nav_next_sibling`| `(navigation, lnum) -> integer\|nil`    | 获取后兄弟行号     |

## Tick 机制

采用全局 tick + 节点 tick 对比实现高效脏检测：

```lua
-- 全局 tick（在 Treeview 实例上）
_tick_visible = 1
_tick_matched = 0
_tick_selected = 1

-- 节点 tick（在 INodeStatus 上）
tick_visible = 0   -- 当 tick_visible == _tick_visible 时，节点不可见
tick_matched = 0   -- 当 tick_matched == _tick_matched 时，节点匹配
tick_selected = 0  -- 当 tick_selected == _tick_selected 时，节点选中
```

**优势**：
- 重置状态只需 `tick + 1`，无需遍历所有节点
- 状态检查是 O(1) 的整数比较

## fold_empty 支持

当 `foldempty = true` 时，单子节点路径会被折叠显示：

```
正常显示:          fold_empty 显示:
├── src            ├── src/components/
│   └── components │   ├── Button.tsx
│       ├── Button │   └── Input.tsx
│       └── Input
```

**实现细节**：
- 遍历时检测 `onlychild` 参数
- 如果唯一子节点也是 container，进入 dry 模式（不渲染当前节点）
- 累积 `folded_depth`，在最终渲染时传递给 renderer

## 设计原则

1. **数据与状态分离**：Tree 存储数据，Treeview 存储状态
2. **tick 脏检测**：避免全量遍历判断状态变更
3. **root 历史栈**：支持多级 attach/detach 导航
4. **渲染时构建索引**：navigation 索引在渲染时计算，确保与视觉布局一致
5. **不直接写入 buffer**：渲染方法返回 IRenderResult，调用者决定如何使用

## 使用示例

```lua
-- 创建 Treeview
local tree = stl.c.Tree.new({ name = "example" })
local treeview = stl.view.Treeview.new({ name = "example", tree = tree })

-- 构建树
tree:insert(tree.root, "dir1", { type = "dir", name = "src" })
tree:insert("dir1", "file1", { type = "file", name = "main.lua" })

-- 初始化状态
treeview:ensure_status("dir1", "container")
treeview:ensure_status("file1", "leaf")

-- 渲染
local result = treeview:render_treeview({
  bufnr = bufnr,
  foldempty = true,
  only_expanded = true,
  only_visible = true,
  only_matched = false,
  only_selected = false,
  render_container = function(ctx, node, status, is_lastchild, folded_depth)
    return { text = node.data.name, highlights = nil }
  end,
  render_leaf = function(ctx, node, status, is_lastchild)
    return { text = node.data.name, highlights = nil }
  end,
})

-- 写入 buffer
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.lines)

-- 使用导航
local parent_lnum = stl.view.Treeview.nav_parent(result.navigation, current_lnum)
```
