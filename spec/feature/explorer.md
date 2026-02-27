# Explorer 模块设计文档

## 概述

`era.m.explorer` 是当前 Neovim 配置中的文件浏览器实现。模块采用 URI 作为内部标识（主要是 `file://`），并由 `Tree + View + Widget + Action + FileManager` 组成。

本文档以代码为唯一事实来源，目标是描述当前行为，而不是历史方案。

## 目录结构

```text
era.m.explorer/
├── action.lua         # 交互动作（open/create/delete/copy/cut/paste/rename...）
├── node.lua           # Node 结构与树关系/选中同步方法
├── tree.lua           # 树维护、加载、刷新、插入/删除、选择/展开状态
├── view.lua           # 渲染、diagnostic/git 预计算、右侧虚拟文本
├── widget.lua         # 窗口生命周期、keymap、订阅、watch 同步
├── types.lua          # 类型声明（SelectMode、IManager、View types）
└── resource/
    └── file.lua       # 本地文件系统 Manager（load/copy/move/remove/watch）
```

## 架构关系

```text
resource/file.lua  ->  tree.lua  ->  view.lua  ->  widget.lua
                             ^             |
                             |             v
                          node.lua      action.lua
```

说明：

- 当前实现没有 `state.lua`，也没有 tick 奇偶状态机。
- 状态是直接挂在 `Node` 上的布尔字段。
- transfer 主路径在 `Action` 内直接调用 `resource_manager`，默认不走 `Tree:apply_copy_paste()` / `Tree:apply_cut_paste()`。

## 核心数据模型

### Node

`Node` 是运行时树节点，核心字段：

- `uri: string`
- `nodename: string`
- `nodetype: "D" | "F"`
- `parent: Node|nil`
- `children: Node[]`
- `chidxmap: table<string, integer|nil>`
- `depth: integer`
- `loaded: boolean`
- `expanded: boolean`
- `selected: boolean`
- `has_selected: boolean`

关键点：

- `selected` 表示节点本身是否选中。
- `has_selected` 表示子树内是否存在选中节点，用于剪枝遍历。

### Tree

`Tree` 负责树状态和资源操作桥接：

- 根相关：`_superroot`（协议根），`_root`（当前工作根）
- UI 状态：`o_root_uri`、`o_cursor_uri`
- 选择模式：`select_mode = "select" | "copy" | "cut"`
- 结构 tick：`ticks.structure`（仅用于结构变化缓存失效）

## Root 与 Superroot

语义如下：

| 节点          | 语义                          | 主要用途                          |
|:--------------|:------------------------------|:----------------------------------|
| `_superroot`  | 协议级虚拟根（如 `file:///`） | URI 物化与全局树骨架              |
| `_root`       | 当前展示根目录                | 业务遍历起点（selection 等）      |

行为规则：

- `Tree:get_selected_nodes*()` 从 `_root` 遍历，不跨出当前展示根。
- `Tree:remove()` 禁止删除 `_superroot`。
- `apply_copy_paste/apply_cut_paste` 禁止处理 `_root` 本身。

## 状态机制（当前实现）

### 展开状态

- 单节点展开：`node.expanded = true/false`
- 递归展开：`node:set_expanded_recursive(expanded)`

### 选中状态

- 选中/取消选中会递归作用于整棵子树：`node:set_selected_recursive(selected)`
- 祖先 `has_selected` 通过 `Node.sync_ancestors()` 增量同步
- `Tree:toggle_selected()` 会先 `__load_subtree__`，保证目录子树可被递归标记

### 状态不变量

- 不要直接写 `node.selected` 或 `node.has_selected`。
- 选中态更新应通过 `set_selected_recursive()` + `sync_ancestors()` 维护一致性。
- 若绕过上述路径手动改字段，`has_selected` 可能失真，导致选择遍历与 UI 标记不一致。

### 加载状态

- `node.loaded` 表示目录子节点是否已装载
- `Tree:mark_all_dirty()` 会递归把目录 `loaded=false`
- `Tree:refresh(force)` 会按 `expanded` 路径增量重载

### 结构 tick

- `ticks.structure` 在结构变更时递增（insert/remove/move/copy/refresh...）
- `View:__precompute__()` 通过 `ticks.structure` 缓存 `filepaths` 预计算结果

## Resource 抽象与 FileManager

`resource.IManager` 接口（当前实现）：

- `compare(left, right)`
- `create(uri)`
- `copy(source_uri, target_uri)`
- `insert_if_missing(uri)`
- `load(uri)`
- `locate(uri)`
- `move(source_uri, target_uri)`
- `remove(uri, on_removed)`

`resource.file.lua` 的关键行为：

- `load` 使用 `uv.fs_scandir`，目录优先 + 名称排序。
- `copy` 目录递归复制，文件按 64KB chunk 流式复制。
- `move` 会先确保目标父目录存在，再执行重命名，并触发 LSP rename 流程。
- `remove` 支持 trash（按平台），失败时回退/报错。
- 提供 fs watch（仅监控展开目录），带 debounce。

## 渲染层（View）

渲染职责：

- tree 缩进与图标
- `diagnostic` 聚合与高亮
- git 状态显示
- 右侧 sign（`selected/copy/cut`）
- `only_selected` 过滤显示
- 空目录折叠展示（fold empty dirs）

说明：

- 选中模式影响右侧 sign：
  - `select` -> 普通选中标记
  - `copy` -> copy 标记
  - `cut` -> cut 标记

## Widget 职责

`widget.lua` 负责：

- 窗口创建/隐藏/聚焦
- `Action` 上下文注入
- keymap 绑定
- 光标状态同步（`CursorMoved` / `CursorMovedI` -> `o_cursor_uri` + cursorline）
- context 订阅（`flag_hidden`、`flag_selected` 等）
- 每次渲染后同步 watch 目录列表

watch 规则：

- 仅同步当前“已展开目录”
- 默认上限 `MAX_WATCHES = 50`
- 全部 explorer 窗口关闭后暂停 watch

## 交互设计（当前实现）

本节只描述现在代码真实行为。

### 选择模型

- 选择集合来自节点 `selected` 状态。
- 模式来自 `tree.select_mode`：`select/copy/cut`。
- `ms/mc/mx` 与 `y/x/c(有选中时)` 本质是“切模式 + 切当前节点选择态”。

核心状态机（简化）：

| 输入场景                               | 触发键              | 主要行为                                             | 结果状态                 |
|:---------------------------------------|:--------------------|:-----------------------------------------------------|:-------------------------|
| 无选中项，光标在任意节点               | `c`                 | 打开 `Copy to:`，直接执行单项 copy                   | 不进入选择模式流         |
| 无选中项，光标在任意节点               | `x`                 | 打开 `Move to:`，直接执行单项 move                   | 不进入选择模式流         |
| 有选中项，光标节点未选中               | `c` / `x`           | 先选中光标节点，再把 `select_mode` 设为 `copy/cut`   | 选择集合扩大 + 模式切换  |
| 有选中项，光标节点已选中且已在目标模式 | `c` / `x`           | 取消光标节点选择                                     | 选择集合收缩，模式保持   |
| 有选中项，光标节点已选中但不在目标模式 | `c` / `x`           | 保持选择，仅切换 `select_mode`                       | 模式切换                 |
| 任意（normal）                         | `ms` / `mc` / `mx`  | 与上面同构：切换光标选择态，并切到 `select/copy/cut` | 选择态与模式联动         |
| `select_mode != select` 且存在选中项   | `p` / `mp`          | 打开 Act，预览并确认 transfer                        | 执行批量 copy/move       |
| `select_mode == select` 或无选中项     | `p` / `mp`          | 直接 warn                                            | 无操作                   |

### `copy` / `cut`

#### `c`（`Action:copy_node()`）

- 若当前已有选中项：
  - 只切换光标节点选中态（按当前模式逻辑）
  - 把 `select_mode` 设为 `copy`
- 若没有选中项：
  - 弹 `Copy to:` 输入框
  - 输入值直接走 `yoz.uri.from_filepath(input)`（不先做 `cwd` resolve）
  - 相对路径将按当前 Neovim 进程 `cwd` 解释
  - 直接执行单文件/目录复制

#### `x`（`Action:cut()`）

- 若当前已有选中项：
  - 只切换光标节点选中态
  - 把 `select_mode` 设为 `cut`
- 若没有选中项：
  - 弹 `Move to:` 输入框
  - 输入值直接走 `yoz.uri.from_filepath(input)`（不先做 `cwd` resolve）
  - 相对路径将按当前 Neovim 进程 `cwd` 解释
  - 直接执行单文件/目录移动

### `paste`

`p` / `mp` -> `Action:paste()`：

- 前置条件：`select_mode != select`
- 目标初始目录：当前光标目录（光标是文件则取父目录）
- 实际执行：打开 `Act` 交互框（不是无确认直接粘贴）
  - move 预览：`from -> to`
  - copy 预览：`from +> to`
  - 支持输入绝对路径或相对 `cwd` 路径

执行算法（`__transfer_selected__`）：

1. 取 `selected_nodes_toplevel`
2. 计算公共祖先目录 `common_ancestor`
3. 对每个选中节点计算 `relative_path`
4. 目标 = `target_dir + relative_path`
5. 逐项执行 `resource_manager:move/copy`
6. 成功后清空选择并 refresh

额外说明（当前代码路径）：

- `move` 分支在 `resource_manager:move()` 成功后，还会调用 `tree:remove(source_uri)`。

路径示例：

- `c` / `x` 直接输入：`tmp/a.txt` -> 按当前进程 `cwd` 解释。
- `paste` Act 输入：`tmp` -> 会先做 `resolve(cwd, input)` 再执行。

### `rename`

`r` -> `Action:rename()`：

- 允许“单选中节点”或“当前光标节点”重命名
- 若选中超过 1 个，直接 warn 并返回
- 输入框默认值为“相对当前 root 的路径”
- 底层通过 `resource_manager:move(old_uri, new_uri)` 实现

### `move_selected` / `copy_selected`

- `Action` 中存在 `move_selected()` / `copy_selected()`
- 当前默认 keymap 未绑定这两个方法
- 默认交互入口仍是：切换模式后 `p/mp`

## 与实现一致的 Keymap（文件操作相关）

以下是 copy/cut/rename/move 相关主要按键：

| 按键           | 动作                                 |
|:---------------|:-------------------------------------|
| `c`            | `copy_node`                          |
| `x`            | `cut`                                |
| `h`            | `collapse_or_parent`                 |
| `j` / `k`      | tree 行导航（本地显式绑定）          |
| `l`            | `open`                               |
| `y` / `mc`     | 切到 `copy` 模式（并切选择态）       |
| `mx`           | 切到 `cut` 模式（并切选择态）        |
| `ms` / `<Tab>` | 切到 `select` 模式（并切选择态）     |
| `p` / `mp`     | `paste`（打开 Act 执行 transfer）    |
| `r`            | `rename`                             |

Insert mode 补充：

- 当前 explorer 默认 normal keybindings 统一使用 `modes = { "i", "n" }`。
- 因此 normal 下的大多数快捷键在 insert 下可直接触发同样行为。
- `j/k` 在 explorer 内有本地显式绑定，不依赖全局继承。
- `j/k` 导航后由 `CursorMovedI` 统一同步 `o_cursor_uri` 与 cursorline。
- `gg` / `G` 在 explorer 内有 insert-only 显式绑定，行为向 normal 对齐。

Visual mode：

| 按键                    | 动作                                  |
|:------------------------|:--------------------------------------|
| `c` / `mc` / `y` / `my` | 切到 `copy` 模式并批量切选择态        |
| `x` / `mx`              | 切到 `cut` 模式并批量切选择态         |
| `<Tab>` / `ms`          | 切到 `select` 模式并批量切选择态      |

## 重要实现备注

1. `Tree:apply_copy_paste()` / `Tree:apply_cut_paste()` 已实现严格校验和树内重排，但当前 `Action` 主路径未调用它们。
2. 当前 `Action` 的 transfer 使用 `resource_manager` 逐项处理，允许“部分成功”。
3. fs watch 已支持，不再是“仅手动刷新”。
4. `view` 使用 `ticks.structure` 做缓存失效，不使用历史 tick 奇偶状态机。

## Known Pitfalls

1. `move` 路径（包括 `paste` 的 move 分支）在 `resource_manager:move()` 成功后仍调用 `tree:remove(source_uri)`。
2. source 在 move 后通常已不存在，`remove` 可能报错或出现误导性日志；维护时要优先核对此路径。
3. `Tree:apply_copy_paste()` / `Tree:apply_cut_paste()` 与 `Action` 主路径并存，二者校验/错误语义不同，改动时不要混淆。

## 已知限制（当前实现）

1. watch 仅覆盖展开目录，且有上限（50）。
2. transfer（copy/move）是逐项执行，失败时可能出现部分完成。
3. `move_selected` / `copy_selected` 无默认 keymap 入口。
4. 文档中的交互为“当前行为”，不代表最终 UX 目标。

----------------------------------------------------------------------------------------------------

## Design Decisions

- **Single `action.lua` file**：动作方法保持在一个文件中，便于共享上下文与复用局部流程。
- **Keymaps in `widget.lua`**：keymap 与动作绑定同地维护，避免分散配置造成语义漂移。
- **`get_common_ancestor_path()` fallback `"/"`**：公共祖先收敛到根时返回 `/`。
- **`Ns` / `Nn` short names in URI parsing paths**：局部算法变量，作用域小且语义稳定。
- **四个祖先/后代判定函数分开保留**：边界语义不同，避免过度抽象。
