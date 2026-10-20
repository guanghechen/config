# Git Files 设计

Status: Design。入口代码位于 `lua/era/m/git_files/`，树视图为 `era.view.GitFiles`（`lua/era/view/git_files.lua`）。
`era.fn.find_git`（命令 `Ffindgitnotcommitted`，默认 `<leader>3` 与 `<leader>fg`）创建并切换唯一的
`era.m.git_files.Widget`。共享 Result / Preview surface 见 [Picker / Searcher Surface](picker-surface.md)，
结果集通用约束见 [Treeview 结果集](../treeview/results.md)，Git 查询与 index 队列见 [Git](git.md)。

## 布局

- Widget 复用 Result / Preview surface 与 `era.view.GitFiles`，不依赖 Picker composer。左栏从上到下为单行 inputbox、
  Staged、Unstaged；右栏为跨越整个左栏高度的单个 diff preview，不按左栏分段。
- 输入框高度固定为一行，两棵树分配剩余高度，各自拥有 native Data/State/View，独立保存展开、选择、
  当前子目录、光标与滚动位置。空组仍保留窗口和零文件数标题。
- 四个 pane 组成一个连续圆角外框，共用单线分隔，不显示 footer。下方 pane 的顶边承担左栏的横向分隔，
  左栏的右边承担 preview 的竖向分隔；只有整个浮窗的四个外角使用圆角。Preview 收起或恢复时同步更新边框连接。
- 两棵树不显示 winbar。顶边左侧依次放名称、刷新 / index 操作状态（`Refreshing…`、`Updating index…`、
  `Refresh failed`）、文件数、新增 / 删除汇总与 unknown 文件数；右侧放当前行 / 可见总行数，空树显示 `0 / 0`。
  光标、过滤、折叠与缩放后同步更新。窄窗口优先保留位置计数，左侧文字按剩余宽度截断。

## 数据与刷新

- 一次 `era.m.git.status.collect({ include_numstat = true })` 提供两侧路径、status 与 numstat。Mixed 文件在两边各出现一次；
  Staged 统计 HEAD → index，Unstaged 统计 index → worktree。文件、目录与 pane 总计只使用对应侧的变更，
  目录 status 是本侧子树的 code union。标题统计整组文件，路径过滤与子目录切换不改变总计。
- Untracked 属于 Unstaged，标记为 `?`；其行数统计由 [Untracked 行数统计](git.md#untracked-行数统计) 补齐，
  不修改真实 index。Binary 或无法取得的统计显示 `—`，含未知统计的目录显示 `?`，标题显示 unknown 文件数；
  不将未知统计解释成零。
- 两侧 producer 与 metadata 均在私有准备阶段完成，按 2 ms 时间片让出主线程；只有两侧都准备成功才接管 records。
  相同路径复用 producer topology，存活节点保留 native identity 与导航状态。Metadata 随 data revision / Frame 发布，
  后台刷新不把新 status 绑定到旧 buffer 行。
- Git status 与行数统计只通过 viewport decorations 右对齐绘制，不进入正文或路径匹配。两棵树共用新增、删除和 status
  列宽：新增 / 删除数值右对齐，status 左对齐，有未知统计时统一预留标记列。列宽由两侧总计计算，随 metadata 一起发布；
  过滤、折叠和滚动不改变列位置。
- 打开与 `R` 触发刷新；`DirChanged` 只在浮窗可见时触发，Git refresh 事件只在可见且没有 index 写入时触发。
  每次刷新持有 workspace 和 cancellation token；新刷新、hide 与 dispose 取消旧请求，旧请求不能重新打开窗口。
  必需的 status 查询失败时保留旧树，标题显示 `Refresh failed` 并禁止 stage / unstage，直到下一次刷新成功。
- 切换 workspace 时清空 query，两棵树的子目录回到 workspace root。

## 输入与过滤

- Inputbox 的内容实时作为 [fzf 语法](yoz/fuzzy.md#查询语法)、smart-case 的路径 query 同时过滤两棵树；
  输入中的 CR / LF 归一化为空格。
  隐藏后重开保留 query。过滤后的树保留连接祖先。
- `/` 聚焦输入并进入 Insert；inputbox 中 `<CR>` 返回最近使用的树，`<Tab>` / `<S-Tab>` 分别进入 Staged / Unstaged。
- `tf` 切换目录压缩，默认开启。

## 键位

树 pane（Normal；标注 Visual 的同时绑定 Visual）：

| 按键                                | 动作                                                                |
| ----------------------------------- | ------------------------------------------------------------------- |
| `<CR>` / `l`                        | 目录切换展开；文件在当前 tab 的源文件窗口打开并关闭浮窗             |
| `h`                                 | 已展开目录折叠；否则跳到父行                                        |
| `z` / `W`                           | 递归切换当前目录；递归折叠当前子目录 root                           |
| `[i` / `]i`                         | 父行；最后直接子项或兄弟                                            |
| `.` / `<BS>` / `gw`                 | 以光标目录为子目录 root；父目录；workspace root，均不越过 workspace |
| `m`（Visual）                       | 切换当前行或 Visual 范围节点自身的选择                              |
| `gs` / `gu`（Visual）               | Unstaged 中 stage；Staged 中 unstage                                |
| `oc`（Visual）                      | 复制目标路径                                                        |
| `oe` / `of` / `os` / `oo` / `<C-q>` | Find Explorer；查找文件；内容搜索；system open；quickfix            |
| `/` / `R` / `tp` / `tf`             | 聚焦输入；刷新；切换 preview；切换压缩                              |
| `<Tab>` / `<S-Tab>`                 | 切换到另一棵树                                                      |
| `q`（Visual）                       | 关闭浮窗                                                            |

- 打开文件前检查 worktree 中文件存在；缺失时提示并保留窗口。
- `oe` / `of` / `os` 以光标目录（文件取其父目录）为起点并关闭浮窗；`<C-q>` 使用可见标记或当前行的文件列表。
- 树 pane 的 Treeview View 关闭 core 默认键位（`keymaps = false`），因此没有 `<Esc><Esc>` 清除选择；
  stage / unstage 成功后清除本次操作节点的选择。
- Preview 中 `q` 关闭、`<Tab>` 回到之前的左栏 pane、`tp` 收起 preview；inputbox 中 `<C-c>`（Insert / Normal）与
  `q`（Normal）关闭，`tp` 切换 preview。
- 四个 pane 都沿用 Picker 的 `<C-a>h/j/k/l`，以及 `Cmd` / `Alt` 同方向别名，覆盖 Insert / Normal / Visual mode。
  左栏上下依次导航 inputbox → Staged → Unstaged；向右进入已显示的 preview，preview 向左返回之前的左栏 pane（包含 inputbox）。
  浮窗边界在非 zen 的 tmux 环境转交 `stl.tmux.change_pane`；无 tmux 或 zen mode 时，左栏上下边界循环，
  preview 向右返回之前的左栏 pane，其余无相邻 pane 的方向不移动。

## Stage 与 unstage

- `gs` 只在聚焦 Unstaged 时 stage，`gu` 只在聚焦 Staged 时 unstage；index 写入、刷新进行中、刷新失败或 workspace
  已改变时不执行。尚有排队的选择时先等待其发布。
- 操作目标来自输入 Frame：Visual 范围的全部行；否则为可见标记；都没有时为当前行。目录展开成该 pane 中符合
  已发布路径过滤的 changed files，包含折叠后代，去重后执行。排队中的过滤结果不能扩大旧 Frame 的操作范围。
- 所有写入经过 `era.m.git.index` 队列，捕获原 workspace，使用 `--literal-pathspecs` 与 NUL 分隔的 stdin pathspec；
  rename 同时处理新旧路径，copy 不操作 source。Stage 使用 `git add`；unstage 在有 HEAD 时使用 `git reset HEAD`，
  unborn repository 使用 `git rm --cached -f`，仅移除 index 条目。
- 完成后刷新两边，保留存活节点的导航状态；来源 pane 清空且仍聚焦时转到另一边。成功写入后同时刷新 Git index 状态。
- 已提交到 index 队列的操作继续作用于捕获的仓库，关闭窗口不取消写入。

## Diff preview

- `tp` 切换右侧只读单栏 inline diff preview，默认显示；编辑器窄于 88 列时暂时隐藏。关闭 preview 窗口等同收起。
- Statuscolumn gutter 左列为旧行号、右列为新行号，后接 `+` / `-` 标记；新增 / 删除缺失的一侧留空，行号固定在窗口左侧，
  不随正文水平滚动。删除行与新增行使用整行底色，成对替换行叠加 Git word diff 高亮；正文保留文件语法高亮。
- Git 文件头不进入正文；每个 hunk 以独立底色的原始 `@@ … @@` 行作为标题，保留范围和函数上下文。
  Binary、仅 rename / copy、空文件新增或删除、mode 变更显示简短描述，未合并文件提示先解决冲突；
  缺失末尾换行通过行尾注记展示。
- 只有 preview 可见且光标目标稳定后才查询 Git，比较对应侧：Staged 使用 `--cached`，untracked 以 `--no-index`
  对比空文件并接受 exit code 1，rename 同时传入旧路径。禁用 external diff 与 textconv，单次查询限时 10 s，
  保留最多 256 KiB / 4000 行并标记截断。
- 切换文件或侧、刷新、hide 与 dispose 取消旧查询；迟到结果必须通过 token、workspace 和可见性检查，不能覆盖新目标。

## 关闭

`q`、`<C-c>`、关闭 inputbox 或任一树窗口，以及离开 tab 都关闭整个浮窗；关闭时取消进行中的刷新。
经 `q`、`<C-c>` 或再次切换关闭且焦点在浮窗内时返回打开前的窗口；关闭窗口与离开 tab 不改变焦点。浮窗关闭后保留 widget、两棵树的 native State 与 query，再次打开时刷新。
