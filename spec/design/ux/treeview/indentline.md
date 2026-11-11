# Treeview indentline、viewport 装饰与结构导航

Visual 圈选遵循 [view.md](view.md#visual-圈选)，展开状态与 scope 遵循 [expansion 契约](expansion.md)，
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
  highlight。没有 indent 高亮 extmark，显示列不能直接作为 byte offset。
- 图标优先级：loading 与 error 状态使用对应 glyph；否则使用节点 `icon`；未提供时按可展开与展开状态取默认 glyph。
  空字符串 `icon` 不绘制图标，consumer 可借此用自己的 overlay 替代默认 chevron。
- Consumer chunks、right text 与 selection 标记右对齐，合成顺序见[右对齐区与截断](#右对齐区与截断)；
  完整子树选中与仅自身选中使用不同标记。Frame 有选择时未选中行保留等宽空白，没有选择时不保留；
  标记不占缩进与图标之间的位置。Label 被右对齐区或窗口边缘截断时以 `truncated` 标记结尾。

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
| `truncated`     | `…`  | label 被截断时可见部分的末格          |

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

## Viewport 装饰

正文 buffer 保存全部已投影的真实行，不使用虚拟空白行伪装列表。连接线、图标、label 与匹配高亮、selection 标记和
右对齐文本通过 `ux.treeview` namespace 的 decoration provider 以 ephemeral extmarks 绘制；不为离屏行维护持久 extmarks，
也不在全选时导出全部节点的装饰。标准装饰的格式与 highlight groups 见[正文与装饰](#正文与装饰)。

- Provider 按实际 bufnr/winnr 查找 View；suspended、失步、发布中或无 Frame 的 View 不绘制。
  `on_win` 固定本轮 Frame，按整个 viewport 批量读取行数据，`on_range` 只为正在重绘的区间生成 marks。
  缓存命中省去读取，但不能省略本次 redraw 的 ephemeral marks。
- 行批次以 Frame 与区间为键缓存。连续滚动的小缺口可向两侧少量预读；预读超出读取预算时退回精确 viewport，
  且同一缓存上不再尝试预读。冷跳转不预读。读取上限见 [默认容量](action.md#默认容量)。
- 读取只对不可变 Frame 做有界 Rust 批量查询；不做 IO、全树布局、全量 FFI 导出，不进入可变 owner 提交或同步等待 Future。
- 视口出现未缓存范围时，提供 `prepare_frame` 的 consumer 经 `refresh_decorations()` 重新准备；其余 View 只唤醒 owner
  更新读取需求。Consumer 准备和 Filetree watch hints 使用实际 viewport，不把预读范围当作可见范围。
- Redraw callback 不修改 buffer、选项或 selection，不移除/更新持久 extmarks。回调异常隔离到该 View：标为失步并
  按 [失败恢复](render.md#失败恢复) 完整重绘，source/state 不回滚。
- 装饰本身变化时显式请求 redraw；正文 changedtick 不变不能成为跳过 selection/theme 重绘的理由。
  ColorScheme 重新定义默认 highlight 并清空各 View 的行批次缓存。大面积装饰变化只重画当前 viewport。
- 字节 span 基于目标行的实际 UTF-8 文本；cell 列宽与 byte column 分开。水平滚动按当前窗口的 `leftcol` 裁剪，
  不能拿另一 View 的列缓存复用。Native fold/wrap 不替代 Treeview 展开状态，View 绑定窗口时设置 `nowrap`、`nofoldenable`。
- 同一行可能分成多个 `on_range` 区间请求装饰（如超出窗口宽度的多字节行）。从行中间开始的区间所在行已在前一区间装饰，
  provider 只装饰从行首开始的行，否则行首 overlay 与右对齐 mark 会在分段处重复绘制。

Consumer 可通过 `decorate_row(view, frame, row, node, col, label, expanded)` 为已读取的 viewport 行追加 ephemeral
spans 或 overlay：`row` 为 0-based buffer 行，`col` 为 label 起始 byte，`expanded` 来自已发布行批次。
该 callback 不得修改正文、读取 IO 或提交异步业务操作；业务 metadata 应按 Frame 的 data revision 解析。
Filetype/icon 检测只在 viewport 首次需要该名称时执行并缓存，不在导入每个路径时运行。

### 右对齐区与截断

`decorate_row` 可返回 virt_text chunks。View 每行最多绘制一个右对齐 mark，从左到右依次为截断标记、consumer chunks、
`right_text`、selection 标记；consumer 不另行绘制 `right_align` mark，顺序因此不依赖 extmark priority，View 也能得到
右对齐区的总宽。

- Selection 标记列只在 Frame 的 selection summary 非空时保留，此时未选中行也留出等宽空白，使同一 View 内的右对齐列对齐；
  summary 在空与非空之间变化时整窗重绘。View 选项 `reserve_selection` 在无选择时也保留该列，供列位置需要与另一 View
  对齐的 consumer 使用。没有任何右侧内容的行不绘制右对齐 mark。
- Label 伸入右对齐区或超出窗口、且仍有可见部分时，右对齐 mark 以 glyph `truncated` 开头，占据 label 可见部分的最后一格。
  该 chunk 不带 highlight，经 `hl_mode = "combine"` 取被覆盖 cell 的颜色，即 label 的高亮；窗口边缘切开宽字符时，
  该格是 Neovim 的 NonText 填充，标记随之取 NonText 颜色。
- 判断只针对正在重绘的行。UTF-8 byte 数不小于显示宽度，先以 byte 总长排除离边缘足够远的行，其余行才用
  `nvim_strwidth` 计算 label 与右对齐 chunks 的宽度；不缓存宽度，也不在发布或数据阶段增加工作。

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

`[i` 与 `]i`（见[默认键位](view.md#默认键位)）的目标按当前显示 Frame 的可见 layout 计算：

| 按键 | 行为                                                                          |
| ---- | ----------------------------------------------------------------------------- |
| `[i` | 跳到可见父行（压缩行跳到 chain 外的父行）；顶层无父行则保持原光标             |
| `]i` | 优先最后可见直接 child；无 child 则跳最后可见 sibling，顶层使用最后一个顶层行 |

- `]i` 使用最后直接 child，不是最后 descendant 或 buffer 末行；折叠、空分支按无可见 child 处理。
- 两者不循环、不切换 root、不隐式展开或加载、不修改 selection/mode、不触发打开动作；每次按键只跳转一次。
- 有效目标落到 `{row, byte column 0}`；`]i` 目标为自身时行号不变，列仍归零。无有效目标时不写 cursor。
- List 不支持结构导航：按键不执行动作，也不回退到全局文本 indentscope 映射。
- Visual 中的结构导航只移动 cursor 端点，见 [view.md](view.md#移动与共享-state)。

`frame:navigate(row, direction)` 按上表计算目标（`direction` 为 `parent` 或 `last_child_or_sibling`），返回 1-based 行号，
无目标或 List 返回 nil。`frame:adjacent_leaf(row, forward)` 按当前 Frame 的可见行序查找 `can_expand = false` 的相邻节点，
Tree 与 List 共用：`row` 为 1-based 且不包含自身，nil 从首行/末行开始；起点为 0、超过行数或无目标时返回 nil，不循环；
不改变 cursor、selection 或 expansion，也不导出跳过的行，但跳过的行仍计入查询成本。

展开、折叠、打开等动作由 consumer 映射，见 [expansion](expansion.md#consumer-动作)。
`j` / `k`、`gg` / `G`、翻页交给 Neovim；移动只更新 cursor，显式标记动作才修改 selection。
Loading/error 附着于节点，不生成可导航的伪 child；普通加载和业务选区锁均不禁止结构浏览。
不引入 Insert 编辑模式；`<Esc>` 与 `<Esc><Esc>` 见[默认键位](view.md#默认键位)。

## 计算约束

- 同一 layout revision 提供 NodeId ↔ row、depth、可见 parent、首尾直接 child、最后 descendant、
  下一 sibling、最后顶层项及 folded IDs；source parent 与可见 parent 分开表达。
- Forest 的顶层导航与 connector 使用 [归并后的 display roots](projection.md#display-roots)，不重复遍历被其他显式入口覆盖的节点。
- 导航先取得稳定目标，再通过该 Frame 的行定位索引换算行号；旧行号不能在新布局上被解释成另一个节点，
  存储约束见 [render](render.md#frame-存储约束)。
- Tree 全量构建采用每层保存 child cursor 的迭代 DFS，结构布局为 `O(V + E)`，遍历栈为 `O(H)`；
  局部更新复用未变区间，filter/sort 和依赖重算成本另计。
- Indent 文本成本按输出字节数计；Lua 不重新遍历 topology，也不扫描文本来补算导航。
- Connector 变化须覆盖旧/新 sibling 边界及受影响后代，按可见范围生成装饰，不要求全表重写连接线。
