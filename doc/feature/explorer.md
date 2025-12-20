# Explorer 模块设计文档

## 概述

`dot.module.explorer` 是一个原生文件资源管理器模块，采用基于 URI 的抽象设计，支持未来扩展至多种资源类型。模块通过 tick 机制实现高效的状态管理，使节点的展开/折叠、选中、加载等状态判断与更新都能在 O(depth) 复杂度内完成。

## 架构

```
dot.module.explorer/
├── node.lua         # 节点定义与状态查询
├── tree.lua         # 树结构管理与操作
├── state.lua        # 全局状态与 tick 管理
├── view.lua         # 渲染逻辑
├── widget.lua       # Widget 层封装
├── types.lua        # 类型定义
└── resource/
    └── file.lua     # 文件系统资源实现
```

### 依赖关系

```
types.lua (纯类型)
    ↓
node.lua (节点)
    ↓
state.lua (状态)
    ↓
tree.lua (树) ← resource/file.lua (资源管理器)
    ↓
view.lua (渲染)
    ↓
widget.lua (Widget)
```

## 核心概念

### URI 抽象

模块内部统一使用 URI 而非 filepath：

- 文件：`file:///Users/foo/bar.txt`
- 目录：`file:///Users/foo/bar/`（以 `/` 结尾）
- superroot：`file:///`（文件系统根）

这种设计为未来支持其他资源类型（如远程文件、虚拟文件系统）预留了扩展空间。

### Resource 抽象

`resource.IManager` 定义了资源操作的统一接口：

```lua
---@class dot.module.explorer.resource.IManager
---@field public compare      fun(left, right): integer
---@field public create       fun(self, uri): INode|nil
---@field public copy         fun(self, source_uri, target_uri): boolean
---@field public insert_if_missing fun(self, uri): boolean
---@field public load         fun(self, uri): INode[]
---@field public locate       fun(self, uri): INode|nil
---@field public move         fun(self, source_uri, target_uri): boolean
---@field public remove       fun(self, uri, on_removed): boolean
```

`resource.FileManager` 是基于本地文件系统的实现。未来可实现其他 Manager（如 SFTP、WebDAV）而无需修改上层逻辑。

## Tick 机制

模块采用 tick（时间戳计数器）机制管理节点状态，这是设计的核心创新点。

### 设计动机

传统方案维护 `expanded_set`、`selected_list` 等集合存在以下问题：
- 插入/删除节点时需同步更新多个集合
- 子树递归操作需要遍历所有后代节点
- 新节点状态继承逻辑复杂且易出错

Tick 机制通过整数比较和奇偶判断解决这些问题，核心思想是：**最新的操作决定当前状态**。

### 数据结构

#### 全局状态 (State)

```lua
---@class dot.module.explorer.State
---@field public tick_expanded    integer  -- 全局展开计数器
---@field public tick_loaded      integer  -- 全局加载计数器
---@field public tick_selected    integer  -- 全局选中计数器
```

State 维护三个全局计数器，每次状态变更时递增以生成新的 tick 值。

#### 节点状态 (Node)

每个节点包含两层状态：

```lua
---@class dot.module.explorer.node.IRootState
---@field public tick_expanded    integer  -- 子树级展开 tick
---@field public tick_selected    integer  -- 子树级选中 tick

---@class dot.module.explorer.node.INodeState
---@field public tick_expanded    integer  -- 节点级展开 tick
---@field public tick_loaded      integer  -- 节点级加载 tick
```

| 状态层    | 缩写 | 作用域             | 用途                             |
|-----------|------|--------------------|----------------------------------|
| RootState | rs   | 当前节点及所有后代 | 递归展开/折叠、递归选中/取消选中 |
| NodeState | ns   | 仅当前节点         | 单节点展开/折叠、懒加载标记      |

### 核心规则

#### 规则 1：奇偶语义

| tick 奇偶     | expanded 语义 | selected 语义 |
|---------------|---------------|---------------|
| 奇数 (1,3,5…) | 展开          | 选中          |
| 偶数 (0,2,4…) | 折叠          | 未选中        |

#### 规则 2：最大值决定状态

判断节点状态时，取相关 tick 值的**最大值**，然后判断奇偶：

```
状态 = (max_tick % 2 == 1) ? 激活 : 未激活
```

这确保了**最新的操作总是生效**。

#### 规则 3：rs 与 ns 的职责划分

| 操作类型        | 修改字段                  | 影响范围               |
|-----------------|---------------------------|------------------------|
| 单节点展开/折叠 | `node.ns.tick_expanded`   | 仅影响当前节点         |
| 递归展开/折叠   | `node.rs.tick_expanded`   | 影响当前节点及所有后代 |
| 选中/取消选中   | `node.rs.tick_selected`   | 影响当前节点及所有后代 |

#### 规则 4：tick_loaded 的特殊性

`tick_loaded` 不使用奇偶语义，而是**相等性判断**：

```lua
node:is_loaded(state.tick_loaded) = (node.ns.tick_loaded == state.tick_loaded)
```

当需要标记所有节点为"未加载"时，只需 `state.tick_loaded += 1`。

### 状态查询算法

#### is_expanded() 详解

```lua
function Node:is_expanded()
  -- 1. 从自身的节点级 tick 开始
  local max_tick = self.ns.tick_expanded

  -- 2. 向上遍历到根，收集所有祖先的子树级 tick
  local o = self
  while o ~= nil do
    max_tick = math.max(max_tick, o.rs.tick_expanded)
    o = o.parent
  end

  -- 3. 最大值为奇数 = 展开
  return max_tick % 2 == 1
end
```

**算法解释**：

1. 节点自身的 `ns.tick_expanded` 表示对该节点的单独操作
2. 祖先链上任意节点的 `rs.tick_expanded` 表示递归操作
3. 取最大值确保最新操作生效
4. 奇数表示最后一次操作是"展开"

**示例**：

```
State.tick_expanded = 5

superroot (rs=0, ns=1)
└── A/ (rs=0, ns=2)           ← is_expanded? max(2,0,0,1)=2, 偶数=折叠
    └── B/ (rs=4, ns=2)       ← is_expanded? max(2,4,0,0,1)=4, 偶数=折叠
        └── C/ (rs=4, ns=3)   ← is_expanded? max(3,4,4,0,0,1)=4, 偶数=折叠
```

若对 B 执行递归展开（`B.rs.tick_expanded = 5`）：

```
superroot (rs=0, ns=1)
└── A/ (rs=0, ns=2)           ← max(2,0,0,1)=2, 偶数=折叠
    └── B/ (rs=5, ns=2)       ← max(2,5,0,0,1)=5, 奇数=展开 ✓
        └── C/ (rs=4, ns=3)   ← max(3,4,5,0,0,1)=5, 奇数=展开 ✓ (继承)
```

C 节点自动继承了 B 的展开状态，无需遍历修改。

#### is_selected() 详解

```lua
function Node:is_selected()
  -- 选中状态仅由 rs.tick_selected 决定
  local max_tick = 0
  local o = self
  while o ~= nil do
    max_tick = math.max(max_tick, o.rs.tick_selected)
    o = o.parent
  end
  return max_tick % 2 == 1
end
```

**注意**：选中状态没有节点级 tick，因为选中操作总是影响整个子树。

#### is_loaded() 详解

```lua
function Node:is_loaded(tick_loaded)
  return self.ns.tick_loaded == tick_loaded
end
```

**规则**：
- 当 `node.ns.tick_loaded == state.tick_loaded` 时，节点已加载
- 调用 `state:advance_tick_loaded()` 后，所有节点立即变为"未加载"

### 状态更新操作

#### 展开单个节点

```lua
function tree:toggle_expanded(uri, recursive=false, force="expand")
  local node = self:locate(uri)

  -- 获取下一个奇数 tick（保证展开语义）
  local tick = state:next_tick_expanded_odd()  -- 若当前是奇数则不变，否则+1

  -- 修改节点级 tick
  node.ns.tick_expanded = tick
end
```

#### 折叠单个节点

```lua
function tree:toggle_expanded(uri, recursive=false, force="collapse")
  local node = self:locate(uri)

  -- 获取下一个偶数 tick（保证折叠语义）
  local tick = state:next_tick_expanded_even()  -- 若当前是偶数则不变，否则+1

  -- 修改节点级 tick
  node.ns.tick_expanded = tick
end
```

#### 递归展开子树

```lua
function tree:toggle_expanded(uri, recursive=true, force="expand")
  local node = self:locate(uri)

  local tick = state:next_tick_expanded_odd()

  -- 修改子树级 tick，自动影响所有后代
  node.rs.tick_expanded = tick
end
```

#### 递归折叠子树

```lua
function tree:toggle_expanded(uri, recursive=true, force="collapse")
  local node = self:locate(uri)

  local tick = state:next_tick_expanded_even()

  -- 修改子树级 tick
  node.rs.tick_expanded = tick
end
```

#### 选中节点

```lua
function tree:toggle_selected(uri, force="select")
  local node = self:locate(uri)

  local tick = state:next_tick_selected_odd()

  -- 选中总是作用于子树
  node.rs.tick_selected = tick
end
```

#### 取消选中

```lua
function tree:toggle_selected(uri, force="unselect")
  local node = self:locate(uri)

  local tick = state:next_tick_selected_even()

  node.rs.tick_selected = tick
end
```

#### 全部取消选中

```lua
function tree:clear_selection()
  -- 只需推进全局 tick 到偶数
  state:next_tick_selected_even()
end
```

由于所有节点的 `rs.tick_selected` 都小于新的偶数 tick，所有节点自动变为未选中。

#### 标记所有节点未加载

```lua
function tree:mark_all_dirty()
  state:advance_tick_loaded()  -- tick_loaded += 1
end
```

### 节点创建与继承

#### 创建普通子节点

```lua
function Node.new(parent, nodetype, nodename, tick_expanded_even)
  local rs = {
    tick_expanded = parent.rs.tick_expanded,  -- 继承父节点
    tick_selected = parent.rs.tick_selected,  -- 继承父节点
  }

  local ns = {
    tick_expanded = tick_expanded_even,       -- 偶数=初始折叠
    tick_loaded = nodetype == "F" and 1 or 0, -- 文件默认已加载
  }

  return { ..., rs = rs, ns = ns }
end
```

**继承规则**：
- `rs` 完全继承父节点，确保新节点自动获得祖先的递归状态
- `ns.tick_expanded` 设为偶数，新目录默认折叠
- 文件节点 `ns.tick_loaded = 1`（无需加载子节点）

#### 创建 superroot 节点

```lua
function Node.superroot(protocol, tick_expanded_odd)
  local rs = {
    tick_expanded = 0,  -- 无父节点，初始为 0
    tick_selected = 0,
  }

  local ns = {
    tick_expanded = tick_expanded_odd,  -- 奇数=初始展开
    tick_loaded = 0,
  }

  return { ..., rs = rs, ns = ns }
end
```

superroot 的 `ns.tick_expanded` 设为奇数，确保初始状态为展开。

#### 节点移动时的处理

```lua
function tree:apply_cut_paste(target_uri)
  local node = ...

  -- 更新 rs 为新父节点的值，断开与原祖先的状态继承
  node.rs.tick_expanded = new_parent.rs.tick_expanded
  node.rs.tick_selected = new_parent.rs.tick_selected
end
```

### 初始状态详解

| 对象          | 字段           | 初始值                             | 理由                     |
|---------------|----------------|------------------------------------|--------------------------|
| State         | tick_expanded  | 1                                  | 奇数，方便立即使用       |
| State         | tick_loaded    | 1                                  | 非零值作为有效标记       |
| State         | tick_selected  | 0                                  | 偶数，所有节点初始未选中 |
| superroot.rs  | tick_expanded  | 0                                  | 无递归展开操作           |
| superroot.rs  | tick_selected  | 0                                  | 无选中操作               |
| superroot.ns  | tick_expanded  | state:next_tick_expanded_odd()     | 奇数，superroot 初始展开 |
| superroot.ns  | tick_loaded    | 0                                  | 需要加载子节点           |
| root.rs       | tick_expanded  | 0（继承 superroot）                | 无递归展开操作           |
| root.rs       | tick_selected  | 0（继承 superroot）                | 无选中操作               |
| root.ns       | tick_expanded  | state:next_tick_expanded_odd()     | 奇数，root 初始展开      |
| root.ns       | tick_loaded    | 0                                  | 需要加载子节点           |
| 普通节点.rs   | tick_expanded  | 继承父节点                         | 保持递归状态一致         |
| 普通节点.rs   | tick_selected  | 继承父节点                         | 保持选中状态一致         |
| 普通节点.ns   | tick_expanded  | state:next_tick_expanded_even()    | 偶数，普通节点初始折叠   |
| 普通节点.ns   | tick_loaded    | 0 或 1                             | 目录=0，文件=1           |

### State 的 tick 管理方法

```lua
-- 获取下一个奇数 tick（展开/选中）
function State:next_tick_expanded_odd()
  if self.tick_expanded % 2 == 0 then
    self.tick_expanded = self.tick_expanded + 1
  end
  return self.tick_expanded
end

-- 获取下一个偶数 tick（折叠/取消选中）
function State:next_tick_expanded_even()
  if self.tick_expanded % 2 == 1 then
    self.tick_expanded = self.tick_expanded + 1
  end
  return self.tick_expanded
end

-- 无条件递增（用于强制刷新）
function State:advance_tick_expanded()
  self.tick_expanded = self.tick_expanded + 1
  return self.tick_expanded
end
```

**设计要点**：
- `next_tick_*_odd/even` 保证返回值奇偶性，可能不改变计数器
- `advance_tick_*` 无条件递增，用于需要强制变更的场景

### 场景示例

#### 场景 1：折叠所有

```lua
-- 初始状态：根目录及部分子目录展开
-- 目标：折叠根目录下所有内容

function widget:__action_collapse_all__()
  local root_uri = tree.state.o_root_uri:snapshot()

  -- 1. 递归折叠（设置 rs 为偶数）
  tree:toggle_expanded(root_uri, true, "collapse")

  -- 2. 单独展开 root（设置 ns 为奇数）
  tree:toggle_expanded(root_uri, false, "expand")
end
```

执行后：
- root 的 `ns.tick_expanded` 为奇数（展开）
- root 的 `rs.tick_expanded` 为偶数（子树折叠）
- 所有子节点继承了 root 的 `rs.tick_expanded`，自动折叠

#### 场景 2：新建节点自动继承父节点状态

```lua
-- 父节点 A 已展开并被选中
-- 在 A 下创建新节点 B

local new_node = Node.new(parent_A, "D", "B", tick_expanded_even)
-- new_node.rs.tick_expanded = A.rs.tick_expanded
-- new_node.rs.tick_selected = A.rs.tick_selected
```

如果之前对 A 执行过递归选中，B 会自动成为选中状态。

#### 场景 3：刷新整棵树

```lua
function tree:refresh(force)
  if force then
    state:advance_tick_loaded()  -- 所有节点立即变为"未加载"
  end

  -- 遍历展开的节点，重新加载内容
  walk(root)
end
```

### 复杂度分析

| 操作               | 传统方案复杂度    | Tick 机制复杂度 |
|--------------------|-------------------|-----------------|
| 查询节点是否展开   | O(1)              | O(depth)        |
| 查询节点是否选中   | O(1)              | O(depth)        |
| 单节点展开/折叠    | O(1)              | O(1)            |
| 递归展开/折叠子树  | O(subtree_size)   | O(1)            |
| 全部取消选中       | O(n)              | O(1)            |
| 标记所有节点未加载 | O(n)              | O(1)            |
| 新建节点状态继承   | O(1) 但逻辑复杂   | O(1) 且简单     |

**权衡**：状态查询从 O(1) 变为 O(depth)，但树的深度通常远小于节点总数，且递归操作和批量操作获得了显著优化。

### 优势总结

1. **O(1) 递归操作**：修改单个 `rs.tick_*` 即可影响整个子树
2. **O(1) 全局重置**：`advance_tick_*` 一次调用使所有节点状态失效
3. **自动状态继承**：新节点通过继承父节点的 `rs` 值自动获得正确状态
4. **无需维护集合**：不存在 `expanded_set`、`selected_list` 等同步问题
5. **移动节点简单**：更新 `rs` 为新父节点的值即可断开原状态继承
6. **代码简洁**：状态判断和更新逻辑统一，易于理解和维护

## 模块职责

### node.lua

节点数据结构与状态查询方法：

- `Node.new(parent, nodetype, nodename, tick_expanded_even)`：创建子节点
- `Node.superroot(protocol, tick_expanded_odd)`：创建超级根节点
- `Node.clone(node, new_parent, tick_expanded_even)`：深拷贝节点
- `Node.calc_uri(parent_uri, nodename, nodetype)`：计算 URI
- `Node.collect_selected(root)`：收集选中节点
- `node:is_expanded()`、`node:is_selected()`、`node:is_loaded(tick)`：状态查询
- `node:set_expanded(tick, recursive)`、`node:set_selected(tick)`：状态设置
- `node:is_ancestor_of(target)`、`node:is_descendant_of(root)`：层级关系判断

### tree.lua

树结构管理与高级操作：

- `Tree.new(props)`：创建树实例
- `tree:attach(uri)`：设置根目录
- `tree:locate(uri)`：定位节点
- `tree:insert(parenturi, resource)`：插入节点
- `tree:remove(uri)`：删除节点
- `tree:refresh(force)`：刷新树
- `tree:toggle_expanded(uri, recursive, force)`：切换展开状态
- `tree:toggle_selected(uri, force)`：切换选中状态
- `tree:apply_cut_paste(target_uri)`：剪切粘贴
- `tree:apply_copy_paste(target_uri)`：复制粘贴
- `tree:clear_selection()`：清除选中

### state.lua

全局状态管理：

- `State.new(props)`：创建状态实例
- `state:next_tick_expanded_odd()`：获取下一个奇数 tick（展开）
- `state:next_tick_expanded_even()`：获取下一个偶数 tick（折叠）
- `state:advance_tick_expanded()`：递增 tick
- `state:advance_tick_loaded()`：递增加载 tick（标记所有节点为脏）
- `state:next_tick_selected_odd()`：获取下一个奇数 tick（选中）
- `state:next_tick_selected_even()`：获取下一个偶数 tick（取消选中）

可共享的 Observable：
- `o_root_uri`：当前根 URI
- `o_cursor_uri`：当前光标 URI
- `o_flag_foldempty`：是否折叠空目录
- `o_flag_hidden`：是否显示隐藏文件

### view.lua

渲染逻辑：

- 树形缩进：`├─`、`╰─`、`│ `
- 文件/目录图标（空目录展开时使用 `FolderEmptyOpen` 图标以区分状态）
- Git 状态标记
- 诊断信息聚合
- 选中状态标记
- 空目录折叠显示

### widget.lua

Widget 层封装，提供标准 Widget API：

- `focus()`、`hide()`、`toggle()`、`show()`
- `reveal(uri)`：展开并定位到指定 URI
- `set_root(uri)`：设置根目录
- `refresh()`：刷新视图
- 快捷键绑定
- Winbar 渲染

## 快捷键

快捷键按以下顺序排列：鼠标键 → `<M-*>` → `<D-*>` → `<C-a>*` → `<C-*>` → 特殊键 → 大写字母 → 小写字母 → 符号

| 按键                              | 功能                                                         |
|-----------------------------------|--------------------------------------------------------------|
| `<2-LeftMouse>`                   | 双击打开文件或展开目录                                       |
| `<M-r>` / `<D-r>` / `<C-a>r`      | 重绘（仅刷新视图）                                           |
| `<C-q>`                           | 发送选中项到 quickfix                                        |
| `<C-t>`                           | 新标签打开                                                   |
| `<C-v>`                           | vsplit 打开                                                  |
| `<C-x>`                           | split 打开                                                   |
| `<CR>` / `l` / `o`                | 打开文件或展开目录                                           |
| `<Tab>`                           | 切换选中状态                                                 |
| `<BS>`                            | 设置父目录为根                                               |
| `.`                               | 设置当前目录为根                                             |
| `[d`                              | 跳转到上一个有诊断的文件                                     |
| `[e`                              | 跳转到上一个有错误诊断的文件                                 |
| `[h`                              | 跳转到上一个 git 变更文件                                    |
| `[i`                              | 跳转到父节点行                                               |
| `[w`                              | 跳转到上一个有警告诊断的文件                                 |
| `]d`                              | 跳转到下一个有诊断的文件                                     |
| `]e`                              | 跳转到下一个有错误诊断的文件                                 |
| `]h`                              | 跳转到下一个 git 变更文件                                    |
| `]i`                              | 跳转到最后一个子节点行                                       |
| `]w`                              | 跳转到下一个有警告诊断的文件                                 |
| `A`                               | 创建目录                                                     |
| `H`                               | 切换显示隐藏文件                                             |
| `J`                               | 选择窗口并 split 打开                                        |
| `L`                               | 选择窗口并 vsplit 打开                                       |
| `O`                               | 在系统文件管理器中打开                                       |
| `R`                               | 刷新                                                         |
| `W`                               | 折叠所有                                                     |
| `a`                               | 创建文件                                                     |
| `c`                               | 有选中项时：标记为复制模式；无选中项时：输入目标路径直接复制 |
| `d`                               | 删除                                                         |
| `gb`                              | 设置上一个根目录为根                                         |
| `gc`                              | 设置 cwd 为根                                                |
| `gw`                              | 设置工作区为根                                               |
| `h`                               | 折叠目录或跳转到父节点                                       |
| `m`                               | 标记选中（用于批量操作）                                     |
| `o`                               | 打开文件或展开目录                                           |
| `oa`                              | 将位置添加到 AI（复制到剪贴板并追加到 notepad）              |
| `oc`                              | 复制路径到剪贴板                                             |
| `oe`                              | 打开文件资源管理器（picker）                                 |
| `of`                              | 打开文件查找器                                               |
| `oi`                              | 显示文件详情                                                 |
| `oo`                              | 在系统文件管理器中打开                                       |
| `os`                              | 打开搜索器                                                   |
| `p`                               | 粘贴（将选中项复制/移动到当前目录）                          |
| `q`                               | 关闭                                                         |
| `r`                               | 重命名                                                       |
| `x`                               | 有选中项时：标记为剪切模式；无选中项时：输入目标路径直接移动 |
| `z`                               | 递归展开/折叠                                                |

### Visual Mode 快捷键

| 按键                              | 功能                                                         |
|-----------------------------------|--------------------------------------------------------------|
| `c`                               | 复制选中项（标记为复制模式）                                 |
| `d`                               | 删除选中项                                                   |
| `m`                               | 标记选中项                                                   |
| `oa`                              | 将选中项添加到 AI                                            |
| `x`                               | 剪切选中项（标记为剪切模式）                                 |

## 扩展指南

### 添加新的 Resource 类型

1. 在 `resource/` 目录下创建新实现（如 `sftp.lua`）
2. 实现 `dot.module.explorer.resource.IManager` 接口
3. 在创建 Tree 时传入新的 resource_manager

```lua
local SftpManager = require("dot.module.explorer.resource.sftp")
local tree = Tree.new({
  name = "sftp-explorer",
  protocol = "sftp://",
  resource_manager = SftpManager.new({ host = "..." }),
})
```

### 添加新的节点状态

1. 在 `IRootState` 或 `INodeState` 中添加新的 tick 字段
2. 在 `State` 中添加对应的 tick 管理方法
3. 在 `Node` 中添加查询和设置方法

## 性能考量

1. **懒加载**：目录内容仅在展开时加载
2. **增量刷新**：通过 tick 机制仅刷新脏节点
3. **合并预计算**：Git ignore 预加载与诊断聚合合并为单次树遍历（`__precompute__`）
4. **诊断缓存**：单次 `vim.diagnostic.get()` 调用后按 severity 聚合，避免重复查询
5. **批量刷新**：创建嵌套目录/文件时，所有中间路径的 `toggle_expanded` 操作完成后才执行单次 `refresh()`
6. **流式文件复制**：大文件采用 64KB 分块读写，避免一次性加载全部内容到内存
7. **渲染分离**：`__render__` 方法独立于 `__refresh__`，状态变更后可直接渲染而无需重复 attach/refresh
8. **空目录折叠**：减少渲染行数

## 已知限制

1. 暂不支持文件系统监听（需手动刷新）
2. 暂不支持大目录分页加载
3. 暂不支持多工作区根
