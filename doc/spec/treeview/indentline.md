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
- 每层片段占 2 列：自身有后续兄弟用 `├─`，末项用 `╰─`；祖先有后续兄弟用 `│ `，否则用两个空格。
- Depth 为 `d` 的行包含 `d` 个祖先片段和一个自身 connector，indent 宽度为 `2 * (d + 1)`。
- 行文本为 `indent + icon + 空格 + label`；无图标时为 `indent + label`。正文不自动换行。
- Indent 独立高亮，范围为 `[0, indent 的 UTF-8 字节长度)`；显示列不能直接作为 extmark byte offset。
- Cursorline、selection、图标和名称样式分别处理，不叠加普通文本 indentline/indentscope guide。
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
