# Treeview indentline 与 cursor movement

Status: Design。适用于 Rust Treeview 的 Lua surface，使用 [核心契约](module.md) 的节点、revision 与 snapshot。
Visual 生命周期遵循 [Visual 圈选契约](visual.md)。
展开状态与普通/递归 scope 遵循 [expansion 契约](expansion.md)。

## 职责

Rust 根据 NodeId、parent/children 和 layout revision 计算结构、缩进信息与导航目标。
Lua 负责 glyph、highlight、buffer-local 按键和 Neovim cursor；加载与业务动作通过上层 callback。
Treeview 不解析 filepath，也不从文本缩进反推结构。

## 缩进线

- Explorer 的 display root 放在标题区，正文直接子项的 depth 为 0，顶层行也绘制 connector。
- 每层片段占 2 列：普通 connector 有后续兄弟用 `├─`，末项用 `╰─`；祖先有后续兄弟用 `│ `，否则用两个空格。
- Depth 为 `d` 的行包含 `d` 个祖先片段和一个自身 connector，indent 宽度为 `2 * (d + 1)`。
- 行文本为 `indent + icon + 空格 + label`；无图标时为 `indent + label`。正文不自动换行。
- Indent 独立高亮，范围为 `[0, indent 的 UTF-8 字节长度)`；显示列不能直接作为 extmark byte offset。
- Cursorline、selection、图标和名称样式分别处理，不叠加普通文本 indentline/indentscope guide。
- Guide 的普通行使用 `TreeviewGuide`，CursorLine 与 Visual 范围使用 `TreeviewGuideActive`；后者默认 link 到前者，
  consumer 可独立映射其前景色。Overlay 保留行背景，Normal/Visual 变化不改正文或 layout。
- 当前窗口 cursor 到 display root 的连接路径使用独立的 `TreeviewGuidePath`，默认粉色；Explorer 映射到
  随主题变化的 `m_ex_indent_path`。路径颜色优先于普通/Active guide，其他列保留各自的颜色和行背景。
- 每行只着色路径经过的 guide 列。当前节点和可见祖先用末端 glyph（默认 `╰─`）绘制整个高亮 connector，
  表示路径转向或结束，去掉 `├` 向下的多余笔画；不改变 native sibling 信息与导航。经过其他 sibling 时，
  用 guide glyph 替换其 connector 的首字符并着色，横线保留原色，避免竖向高亮出现旁支凸起；默认显示为粉色
  `│` 接原色 `─`。压缩链按 display parent 和 display depth 处理。
- Children-of 的顶层连线接到标题中的隐式 root；Forest 在当前所属顶层入口处停止，不跨到其他入口。
- 路径始终基于当前窗口实际 cursor 与已显示 frame；Visual 使用其冻结布局，List 不绘制路径。
- 图标占两列（glyph 与一个空格）；selection 标记固定在最右侧，未选择时保留两列空白，不占缩进与图标之间的位置。

普通显示按可见兄弟位置绘制。Selected-only 保留选区过滤前的 source sibling 位置；压缩行使用
chain 最外层节点的位置。因此分别提供“绘制时是否末项”和“可见布局中是否末项”，导航始终只用后者。

## 压缩链

- 单子链压缩为一行，以最深 NodeId 为代表；保留完整 chain，链中各 ID 都映射到该行。
- 整条 chain 只占一层显示深度，source parent 关系保持完整。
- Explorer 仅压缩目录链；parent 在 selected-only 过滤前的 source children 也必须只有一项。
- 文件独立成行，选择边界不能被压缩隐藏；自身未选、仅自身选中与子树全选按
  [selection 契约](selection.md) 区分。
- `[i` 跳到 chain 外的可见父行；`h` 使用 source parent，必要时逐段缩短压缩链。

## 结构导航

Tree 模式的目标根据当前可见 layout 计算：

| 按键                | 行为                                                                        |
| ------------------- | --------------------------------------------------------------------------- |
| `[i`                | 跳到可见父行；顶层无父行则保持原光标                                        |
| `]i`                | 优先最后可见直接 child；无 child 则跳最后可见 sibling，顶层使用 `last_root` |
| `h`                 | 当前分支展开则折叠自身；否则定位并折叠 source parent，到 display root 停止  |
| `l` / `<CR>` / 双击 | Tree 分支切换展开，不自动进入首个 child；叶节点调用上层打开动作             |
| `z`                 | 按当前分支的相反展开状态，递归设置子树，包含未加载后代                      |
| `W`                 | 折叠后代，保留 display root 的直接子项                                      |

- `]i` 使用最后直接 child，不是最后 descendant 或 buffer 末行；折叠、空分支按无可见 child 处理。
- `[i`、`]i` 不循环、不切换 root、不隐式展开或加载、不修改 selection/mode、不触发打开动作。
- 有效目标落到 `{row, byte column 0}`；`]i` 目标为自身时行号不变，列仍归零。
- 无有效目标时不写 cursor；`[i` 无父行时原行和原列均保留。
- 每次按键执行一次结构跳转，不增加数字前缀重复能力。

## 普通移动与状态恢复

- `j` / `k` 按可见行移动；`gg` / `G` 到正文首尾；半页/整页移动交给 Neovim。
- Explorer 的 diagnostic/Git 跳转按可见匹配项首尾循环，与 `[i`、`]i` 的边界规则分开。
- 移动只更新 cursor；Visual 移动只改变待提交范围，显式标记动作才修改 selection。
- 更新后原 NodeId 可见则保留；不可见则依次回退到最近可见祖先、附近可见行，空视图无逻辑 cursor。
- 原节点重新可见不自动跳回；加载结果不恢复旧展开或旧 cursor，也不触发打开 callback。
- Loading/error 附着于节点，不生成可导航的伪 child；普通加载和业务选区锁均不禁止结构浏览。
- 结构导航使用 buffer-local 映射；不引入 Insert 编辑模式，不新增或覆盖 `<Esc>`。

## List 与 Visual

- List 候选范围总是递归，不受 Tree 展开状态限制；输出顺序遵循 [filter/sort 投影](projection.md#tree-与-list)，
  不固定为 DFS。视觉 indent 为 0，不画连接线、不压缩链。
- List 不执行 Tree 专用折叠动作；切回 Tree 恢复展开状态，selection 不变。
- List 在 Normal/Visual 均不支持 `[i`、`]i`；按键分派不执行动作，也不回退到全局文本 indentscope 映射。
- Tree 在 Normal/Visual 均支持 `[i`、`]i`；Visual 保持 mode 和 anchor，只移动 cursor 端点及范围。
- Visual 范围只有显式按 `<Tab>`、`c`、`x` 才提交到 selection；List 仍可用普通移动圈定并提交范围。
- Visual 进入时保留本 view 的布局；普通移动和结构导航使用该 frame 的索引与实际端点，
  后台插入、重排、过滤和压缩变化留待圈选结束显示。其他 view 的逻辑 cursor 不拉动 Visual 两端。
- 相同布局的 metadata 重绘原子恢复 Visual mode、anchor 和 cursor；程序触发的 ModeChanged 不结束圈选。
- 正常退出或标记提交后刷新最新布局，按 NodeId 恢复光标。单纯布局变化不拒绝提交；
  目标失效或动作前提改变时结束本次圈选、刷新并提示，不用新行上的节点替代原目标。

## 计算约束

- 同一 layout revision 提供 NodeId ↔ row、depth、可见 parent、首尾直接 child、最后 descendant、
  下一 sibling、最后顶层项及 folded IDs；source parent 与可见 parent 分开表达。
- Forest 的顶层导航与 connector 使用 [归并后的 display roots](roots.md)，
  不重复遍历被其他显式入口覆盖的节点；入口移出覆盖范围后按原顺序恢复。
- 导航先取得稳定目标，再通过该 frame 的顺序统计索引换算行号；允许对数级定位，不因插入而更新所有后缀的绝对行号。
  旧行号不能在新布局上被解释成另一个节点，内部行存储与索引遵循 [render 契约](render.md#rust-行存储与索引)。
- Tree 全量构建采用每层保存 child cursor 的迭代 DFS，结构布局为 `O(V + E)`，遍历栈为 `O(H)`；
  局部更新复用未变区间，filter/sort 和依赖重算成本另计。
- Indent 文本生成成本按输出字节数计；Lua 不重新遍历 topology，也不扫描文本来补算导航。
- Connector 变化须覆盖旧/新 sibling 边界及受影响后代；优先按可见范围生成装饰，不要求全表重写连接线。
- `frame:guide_path(row, first, last)` 是只读批量查询，参数与返回区间均为 1-based inclusive，viewport 最多 512 行。
  返回按行排序的 `{first, last, depth}` 区间，`last` 是路径节点的 connector 行，之前的行只携带竖向连接；
  `first` 裁剪到 viewport。List、空范围或 cursor 不在该范围时返回空数组。
- 路径查询沿 display parent 回溯，遇到 viewport 上方 parent 即停止，不扫描跨过的 sibling 子树或更高祖先。
  每次查询至多处理 viewport 行数那么多的路径节点，另计现有 rank/select 索引定位成本。
- Lua 按 view 的 layout revision、cursor 行和覆盖 viewport 缓存路径；metadata frame、横向移动与重复 redraw
  可复用缓存。每行用一个 overlay extmark 承载 guide、间隔和 connector 的分色 chunks；只生成水平可见范围中的
  glyph 与必要间隔，不创建离屏持久标记。被左边界截断起点的 glyph 整段省略，保持既有裁剪语义。
  Cursor 换行比较新旧路径，只额外重画可见颜色变化区间；viewport cache 不可用时请求整个窗口 redraw。
  路径计算缓存与待重绘区间分开：`on_win` 提前计算新路径不清除失效，`on_range` 只消除已绘制区间；
  redraw 结束后合并调度剩余范围。即使 cursor 在一次 callback 内往返而没有新的 `CursorMoved`，也不遗留中间颜色。
  Cursor 换行立即更新路径缓存，同一事件循环内的 range redraw 合并调度；Neovim 的自然 redraw 已覆盖的行
  不再重复请求。调度不使用固定时长 timer，不等待 native state 确认，关闭 view 后忽略待执行 callback。
  纯路径变化不写正文、不重新投影、不等待异步 state 发布。
