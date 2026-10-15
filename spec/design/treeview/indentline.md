# Treeview indentline 与结构导航

Status: Design。适用于 Treeview 的 Lua View 与 native Frame 查询，使用 [核心契约](module.md) 的节点、revision 与 snapshot。
Visual 生命周期遵循 [Visual 圈选契约](visual.md)，展开状态与 scope 遵循 [expansion 契约](expansion.md)，
cursor 回退遵循 [render 契约](render.md#cursor-回退)。

## 职责

Rust 根据 NodeId、parent/children 和 layout revision 计算结构、缩进、压缩链与导航目标，并生成正文。
Lua 负责 glyph、highlight、buffer-local 按键和 Neovim cursor；加载与业务动作通过上层 callback。
Treeview 不解析 filepath，也不从文本缩进反推结构。

## 正文与装饰

正文只由 ASCII 空格与 label 组成，不包含 connector、guide 或图标：

```text
line = " " × ((depth + (Tree ? 1 : 0)) × indent + slots) .. label
```

- `indent` 与 `slots` 来自 render context，Lua View 固定为 2 与 2；`slots` 是图标位，与节点有无图标无关。
  List 的 depth 恒为 0。正文不自动换行。
- Label 为节点 label；压缩行见 [压缩链](#压缩链)；List 的 `ancestry` 正文见 [projection](projection.md#list-正文)。
- Tree 模式下 depth 为 `d` 的行在第 `level × indent` 列绘制各祖先 guide，在第 `d × indent` 列绘制自身 connector，
  图标在第 `(d + 1) × indent` 列，label 从 `(d + 1) × indent + slots` byte 开始。ChildrenOf 的 root 自身不显示，
  depth 0 的顶层行同样绘制 connector。List 不绘制 guide 与 connector，图标在第 0 列。
- Connector、guide、图标、selection 标记与 right text 均为 ephemeral overlay；label 高亮与匹配片段为 ephemeral
  highlight。没有 indent 高亮 extmark，显示列不能直接作为 byte offset。`decorate_row` 的 `col` 为 label 起始 byte。
- 图标优先级：loading 与 error 状态使用对应 glyph；否则使用节点 `icon`；未提供时按可展开与展开状态取默认 glyph。
  空字符串 `icon` 不绘制图标，consumer 可借此用自己的 overlay 替代默认 chevron。
- Right text 与 selection 标记右对齐；完整子树选中与仅自身选中使用不同标记，未选中时保留等宽空白，
  不占缩进与图标之间的位置。

View 选项 `glyphs` 覆盖以下默认值，Explorer 在用途切换时替换两个 selection 标记：

| 键              | 默认 | 用途                                  |
| --------------- | ---- | ------------------------------------- |
| `branch`        | `├─` | 后面还有可见兄弟的 connector          |
| `last`          | `╰─` | 末项 connector；cursor 路径节点的转向 |
| `guide`         | `│`  | 祖先竖线                              |
| `expanded`      | `▾`  | 已展开分支的默认图标                  |
| `collapsed`     | `▸`  | 折叠分支的默认图标                    |
| `leaf`          | 空   | leaf 的默认图标                       |
| `loading`       | `…`  | 加载中的节点                          |
| `error`         | `!`  | 加载失败的节点                        |
| `selected`      | `●`  | 子树完整选中                          |
| `self_selected` | `◐`  | 仅自身选中                            |

Highlight groups 均以 `default = true` 定义并在 ColorScheme 后重新应用；consumer 通过 `winhighlight` 映射到自身主题组
（Explorer 将三个 guide 组映射到 `m_ex_indent*`）：

| Group                 | 默认                   | 用途                                              |
| --------------------- | ---------------------- | ------------------------------------------------- |
| `TreeviewLabel`       | link `Normal`          | 未提供 `highlight` 的 label                       |
| `TreeviewGuide`       | link `NonText`         | guide 与 connector                                |
| `TreeviewGuideActive` | link `TreeviewGuide`   | `cursorline` 开启时的 cursor 行，以及 Visual 范围 |
| `TreeviewGuidePath`   | `fg = #f5a9b8`         | cursor 到 display root 的连接路径，优先于前两者   |
| `TreeviewError`       | link `DiagnosticError` | 加载失败行的图标与 label                          |
| `TreeviewMatch`       | link `Search`          | pattern 匹配片段                                  |
| `TreeviewRightText`   | link `Comment`         | `right_text`                                      |
| `TreeviewSelection`   | link `DiagnosticOk`    | selection 标记                                    |

Guide overlay 保留行背景，Normal/Visual 变化不改正文或 layout。

### Connector 与 cursor 路径

普通显示按可见兄弟位置绘制 connector。Selected-only 保留选区过滤前的 source sibling 位置；压缩行使用
chain 最外层节点的位置。因此 Frame 分别提供“绘制时是否末项”和“可见布局中是否末项”，导航只用后者。

Tree 模式下，View 窗口 cursor 到 display root 的连接路径使用 `TreeviewGuidePath`，List 不绘制路径。每行只着色路径经过的
guide 列：当前节点和可见祖先用 `last` glyph 绘制整个高亮 connector，表示路径转向或结束；路径经过其他 sibling 时，
只把其 connector 的首字符替换为 `guide` glyph 并着色，横线保留原色，避免竖向高亮出现旁支凸起。压缩链按 display
parent 和 display depth 处理。ChildrenOf 的顶层路径接到隐藏 root 所在的顶部；Forest 在所属顶层入口处停止。
路径基于该窗口实际 cursor 与已显示 Frame；Visual 使用其冻结布局。

路径查询沿 display parent 回溯，遇到 viewport 上方的 parent 即停止，工作量至多为 viewport 行数加索引定位成本。
Lua 按 layout revision、cursor 行和 viewport 缓存路径；cursor 换行只重画颜色实际变化的行区间，同一事件循环内的重画合并调度，
不使用固定时长 timer。纯路径变化不写正文、不重新投影、不等待异步 state 发布。

## 压缩链

`compress = true` 时 Tree 把单子链合并为一行；List 不压缩，分组平铺要求 `compress = false`（见 [Display 选项](projection.md#display-选项)）。节点 n 与其唯一 child c 连成链需同时满足：

- n 与 c 都可展开且 `foldable = true`；consumer 用 `foldable = false` 排除节点（例如 Diffview 的 commit header）。
- n 当前已展开；折叠节点结束链条，压缩本身不写展开标记。
- n 只有 c 一个 child：有 pattern 或 filter 且未启用 selected-only 时按过滤后保留的 children 判定，未命中的 sibling 不阻止压缩；
  否则按 source children 判定。c 本身须通过当前过滤。
- n 与 c 的选择类别相同（自身未选、仅自身选中与子树全选按 [selection 契约](selection.md) 区分），选择边界不被压缩隐藏。

链以最深 NodeId 为代表 RowKey，保留完整 chain，链中各 ID 都映射到该行；整条链只占一层显示深度，
source parent 关系保持完整。正文为链上各 label 依次以 render context `separator`（默认 `/`）连接。
Leaf 始终独立成行。局部更新按实际压缩连接的变化扩大重建范围，不因祖先仍可压缩而重建其未变化的大子树。

## 结构导航

Core View 在未设 `keymaps = false` 时为 Normal/Visual 绑定 `[i` 与 `]i`，目标按当前显示 Frame 的可见 layout 计算：

| 按键 | 行为                                                                          |
| ---- | ----------------------------------------------------------------------------- |
| `[i` | 跳到可见父行（压缩行跳到 chain 外的父行）；顶层无父行则保持原光标             |
| `]i` | 优先最后可见直接 child；无 child 则跳最后可见 sibling，顶层使用最后一个顶层行 |

- `]i` 使用最后直接 child，不是最后 descendant 或 buffer 末行；折叠、空分支按无可见 child 处理。
- 两者不循环、不切换 root、不隐式展开或加载、不修改 selection/mode、不触发打开动作；每次按键只跳转一次。
- 有效目标落到 `{row, byte column 0}`；`]i` 目标为自身时行号不变，列仍归零。无有效目标时不写 cursor。
- List 不支持结构导航：按键不执行动作，也不回退到全局文本 indentscope 映射。
- Visual 中的结构导航只移动 cursor 端点，见 [visual.md](visual.md#移动与共享-state)。

`frame:navigate(row, direction)` 按上表计算目标（`direction` 为 `parent` 或 `last_child_or_sibling`），返回 1-based 行号，
无目标或 List 返回 nil。`frame:adjacent_leaf(row, forward)` 按当前 Frame 的可见行序查找 `can_expand = false` 的相邻节点，
Tree 与 List 共用：`row` 为 1-based 且不包含自身，nil 从首行/末行开始；起点为 0、超过行数或无目标时返回 nil，不循环；
不改变 cursor、selection 或 expansion，也不导出跳过的行，但跳过的行仍计入查询成本。

展开、折叠、打开等动作由 consumer 映射，见 [expansion](expansion.md#consumer-动作)。
`j` / `k`、`gg` / `G`、翻页交给 Neovim；移动只更新 cursor，显式标记动作才修改 selection。
Loading/error 附着于节点，不生成可导航的伪 child；普通加载和业务选区锁均不禁止结构浏览。
不引入 Insert 编辑模式；单次 `<Esc>` 保持 Neovim 行为，`<Esc><Esc>` 见 [visual.md](visual.md#移动与共享-state)。

## 计算约束

- 同一 layout revision 提供 NodeId ↔ row、depth、可见 parent、首尾直接 child、最后 descendant、
  下一 sibling、最后顶层项及 folded IDs；source parent 与可见 parent 分开表达。
- Forest 的顶层导航与 connector 使用 [归并后的 display roots](roots.md)，不重复遍历被其他显式入口覆盖的节点。
- 导航先取得稳定目标，再通过该 Frame 的行定位索引换算行号；旧行号不能在新布局上被解释成另一个节点，
  存储约束见 [render](render.md#frame-存储约束)。
- Tree 全量构建采用每层保存 child cursor 的迭代 DFS，结构布局为 `O(V + E)`，遍历栈为 `O(H)`；
  局部更新复用未变区间，filter/sort 和依赖重算成本另计。
- Indent 文本成本按输出字节数计；Lua 不重新遍历 topology，也不扫描文本来补算导航。
- Connector 变化须覆盖旧/新 sibling 边界及受影响后代，按可见范围生成装饰，不要求全表重写连接线。
