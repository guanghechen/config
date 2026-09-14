# Explorer redesign

Status: Draft。已确认的交互、延续的浏览能力和待审阅的 keymap 草案均在本文直接列出。
“沿用现有能力”不构成额外的隐式规范；实现与验收以本文展开的行为为准。
文中的“草案”表示推荐方案尚未最终确认，技术协议未定稿不以引用其他文档代替。

## 已确认的架构方向

- 数据、状态、树计算和文件操作放在 `rust/ux`。
- Lua 负责用户输入、UI 展示以及 Neovim window/buffer 对接。
- 文件操作经 Rust filesystem provider 执行，默认 provider 对接真实 filesystem。
- 多个 Explorer 可以共用同一份 Rust data/state，也可以独立，由调用方决定。
- 首期真实 filesystem 保留本文列出的 buffer、Git 与 LSP diagnostics 对接。
- 虚拟文件的 buffer、LSP/Git 集成不纳入首期；未来 VFS 不要求资源落到本地文件。

### Treeview、Filetree 与 Explorer 的组合（草案）

三层是 `rust/ux` 内的模块职责，不分别创建 crate：

- Filetree 持有资源 identity、父子关系、metadata、目录加载/刷新及文件领域的排序和状态聚合。
- Treeview 持有 display root、展开、显示过滤、逻辑光标、selection 与选区锁，计算投影和结构导航。
- Explorer 持有 workspace、上一次 display root、select/copy/cut mode、文件任务和确认请求，
  组织 Filetree 数据读取、Treeview 状态提交和 Lua 窗口/buffer 对接。
- Lua 持有实际 Neovim handles、Visual marks、viewport 和主题；输入由 Rust 校验后改变权威状态。

Treeview 不解释文件动作，Filetree 不维护另一份 selected flag，Explorer 不另做一套树选取算法。
Rename/move 等动作通过 Explorer 提供的上层 callback 接入；输入、路径解析、确认、Rust provider
操作及资源身份判断留在上层。Data owner 将实际结果转换为节点更新，Treeview 只处理 NodeId、
数据/结构变更和上层决定的选区更新，不绑定 filepath，也不自行识别资源 rename/move。
Selection 与 mode 必须在同一次可观察提交中更新。共享 selection 的 views 同时共享它的 mode 和任务锁；
只共享资源 data 的实例仍可独立浏览与选择。

以下章节保留完整的 Explorer 行为和例子，不以通用 Treeview 契约的引用代替交互说明。

## 已确认：浏览与打开

### Root

浏览围绕 workspace root 展开，与当前使用习惯一致。Root 通常为 Git root，也可以是普通 cwd。
展开目录不等于切换 workspace root。

Workspace root 是默认浏览起点；用户通过导航动作切换的目录称为 display root。以下能力均保留：

- 将光标目录设为 display root；光标在文件上时使用其父目录。
- 将 display root 切到上级目录；在 `/`、`C:/` 等 filesystem root 处停止。
- 回到 cwd，或回到 workspace root。
- 回到上一次 display root。这里只保存上一个 root，不隐含完整目录历史栈。
- Root 变更不把光标项加入选区，也不改变 copy/cut mode。

### Pane、标题区与默认设置

- 默认在当前 tab 左侧创建垂直 Explorer pane，宽度为 30 列，实际宽度不超过可用屏幕宽度。
- 不显示行号、相对行号、fold column、sign column 或 status column；文件状态使用行内装饰。
- 正文不自动换行，目录层级由树连接线和缩进表达。
- 同一 Explorer 实例可在多个 tab 显示；调用方决定它们连接共享还是独立的 Rust state。
- 隐藏 pane 时记住宽度；再次打开时恢复宽度。改变宽度同步到连接该宽度状态的 views。
- 标题区显示当前 display root 和显示开关；有 tabline 时在那里展示，否则使用 Explorer winbar。
- 显示开关可以通过标题区点击，也可以通过键盘触发。
- Explorer 获得或失去焦点时使用不同的当前行背景，不改变名称的 Git/diagnostic 语义色。
- 打开、聚焦、隐藏、切换可见性均为独立动作；隐藏不清空选区，也不取消任务。

默认设置：

| 设置                        | 默认值             | 含义                            |
| --------------------------- | ------------------ | ------------------------------- |
| 展示模式                    | Tree               | 使用树层级显示                  |
| 显示隐藏项                  | 开                 | 显示名称以 `.` 开头的文件和目录 |
| 仅显示选中项                | 关                 | 显示正常浏览投影                |
| 压缩单子目录链              | 开                 | 满足条件时把连续目录合并显示    |
| 排序                        | 目录优先、名称升序 | 名称比较忽略 ASCII 大小写       |
| 图标、Git、diagnostics 装饰 | 开                 | 本地资源存在对应数据时展示      |
| Pane 宽度                   | 30 列              | 允许用户调整                    |

Display root、逻辑光标、展开状态和选区由 Rust Treeview state 持有；workspace、mode 与任务由
Rust Explorer state 持有，Neovim window/buffer handle 由 Lua 管理。
上述默认设置可保存并恢复；跨重启恢复选区或未完成任务不属于已确认行为。

### Tree 浏览、展开与结构导航

- 正文从 display root 的直接子项开始；display root 本身显示在标题区。
- 普通展开目录时读取其直接子项；普通折叠只修改自身，隐藏后代并保留其展开状态和选区。
- 当前目录已展开时，“折叠/父目录”动作先折叠它；否则定位并折叠其父目录。
  当父目录已经是 display root 时，不因此跳出当前 root。
- “递归展开/折叠”覆盖当前目录及全部后代，包括未加载和以后新增的节点；递归展开随有界异步加载
  继续，递归折叠覆盖后代旧展开状态。普通与递归 scope 使用 [expansion 契约](../treeview/expansion.md)。
- “全部折叠”折叠后代，并保留 display root 的直接子项可见。
- `[i` 定位当前可见布局的父行，不折叠；顶层无可见父行则保持原光标，不进入标题区或切换 root。
- “最后子项/兄弟项”优先定位当前目录的最后一个可见直接子项；没有子项时定位同组最后一个
  可见兄弟项。顶层 item 对应 display root 下最后一项。
- `]i` 使用上述最后子项/兄弟项规则，折叠或空分支不会自动展开；不跳到最后 descendant，也不循环。
- 当前 `[i`/`]i` 有效定位使用 byte column 0；`]i` 目标为自身时行号不变。两者不修改 selection/mode。
- 新 Tree 模式在 Normal/Visual 均支持 `[i`/`]i`；Visual 只移动 cursor 和范围，按 `<Tab>`、`c`、`x` 才提交选区。
- 行移动、首尾行和翻页只改变浏览光标，不修改选区。

Tree indent 使用 `├─`、`╰─`、`│ ` 和两个空格，每层片段 2 列，depth 0 的顶层行也有 connector。
Selected-only 保留过滤前 source sibling 的连接线形态，但结构导航只使用可见节点。Highlight 的范围
按 UTF-8 bytes 计算；完整 indent、压缩行、边界及按键范围在 `doc/spec/treeview/indentline.md` 中展开。

### Children 加载期间的交互（已确认）

- 普通展开、刷新和递归 List 加载时显示节点 loading，允许继续浏览、折叠、切换 root 和改选。
- 等待期间已经折叠的节点，加载成功后只更新有效数据，保持折叠；不重新展开或拉回光标/焦点。
- 折叠解除当前消费者对隐藏范围的 Tree 展开需求；其他 views、List 或任务仍可共享读取。
  展开意图与数据加载进度分别展示，尚未完成的递归展开不因根已展开而被报告为全部加载完成。
- 切换 display root 后，旧请求不能恢复旧 root 或覆盖当前 layout；共享数据是否继续读取由上层决定。
- 加载失败在对应节点展示错误并允许重试；刷新失败保留上次有效数据，首次失败不能当作空目录。
- 返回的 children 按当前 selection 和显示状态展示，不恢复请求发起时的选区。
- Loading 本身不锁定选区；已提交文件任务及其源项准备仍按任务锁限制改选，其他加载不能解除该锁。

### 单子目录链压缩

- 一条已展开路径上，一个目录只有一个可展示子项且该子项也是目录时，可以压缩为一行，
  例如 `src/lib/internal/`。
- 文件不能被并入目录链；一个目录的唯一子项是文件时，该文件仍独立显示。
- Parent 在 selected-only 过滤前的 source children 也须只有一项，不能仅因过滤后只剩一个目录而压缩。
- 已选目录和需要独立表达选择边界的目录不被压缩隐藏。
- 压缩只改变显示，不改变真实父子关系、资源路径和文件操作对象。
- 链内每个节点都能定位到该行；该行默认使用最深层目录作为操作代表。
- 压缩 chain 只占一层显示深度；`[i` 跳到 chain 外的可见父行，`h` 仍可逐次折叠 source parent。
- 关闭压缩后恢复逐层显示，保留展开、选区及光标对应的资源身份。

### 隐藏项、选区过滤与排序

- 隐藏项按名称是否以 `.` 开头判定；这与 Git ignored 是两种独立信息。
- “仅显示选中项”保留选中的节点及到达它们所需的祖先路径。
- Selected-only 开启时采用 [selected > hidden](../treeview/selection.md#selected-only-与-hidden)：
  已选隐藏项及必要祖先不会被隐藏过滤挡住；不改写隐藏项开关，关闭 selected-only 后按其当前设置过滤。
- 已选目录下的后代继承选择覆盖；被局部反选的分支按真实选择状态过滤。
- 过滤不清空选区，不把隐藏节点从文件操作范围移除；Tree 中不强制展开，List 始终递归。
- 没有选中项时开启“仅显示选中项”，正文可以为空，root 和显示开关仍可访问。
- 排序固定为目录在前、文件在后；同类名称按忽略 ASCII 大小写的字节序升序比较。
- 同类名称忽略大小写后相同的稳定排序细节在 Rust 实现中确定；首期不新增按大小、时间或
  自然数字排序的 UI 选项。
- 排序和过滤由 Rust 计算，Lua 只展示投影，不在渲染时重建整棵树或重复排序。

### 已确认：List 总是递归

现有 UI 已有 Tree/List 开关和持久化状态，但当前渲染入口没有把 viewtype 传给 renderer，
renderer 也只有 Tree 布局路径。因此，List 的具体显示语义不能描述成已经实现的行为。

新实现保留该开关，List 的范围明确如下：

- 总是递归 display root 下的资源，主动读取未加载目录，不使用 Tree 的展开状态限制范围。
- 每行显示相对 display root 的路径；去掉树连接线和层级缩进。
- 保留目录行与文件行，应用隐藏项和仅选中项过滤；过滤不改变逻辑选区。
- List 不压缩单子目录链；Tree 的折叠状态不隐藏 List 子项，切回 Tree 后恢复原展开和压缩设置。
- 切换展示模式保留选择、mode 和文件操作源；递归读取会扩充共享资源数据。
- List 在 Normal/Visual 均不支持 `[i`/`]i`；对应按键不执行动作，也不回退到全局文本 indentscope 映射。

递归加载的实现草案：

- Rust 有界并发读取，分批展示结果和进度；未完成时显示 loading，失败分支显示错误并允许重试。
- 按各层目录优先、名称升序进行 DFS；不在 Lua 递归或阻塞 Neovim 等待整棵树完成。
- Symlink 循环停止于重复进入祖先目标的位置，保留链接行并展示原因，不无限展开逻辑路径。
- 离开 List 或切换 root 时结束该 view 的遍历请求，旧 generation 的结果不得覆盖新列表。
- Tree 专用展开/折叠动作在 List 不执行；目录仍可通过 display-root 导航进入。
- 递归预算与 watcher 预算分开，不能把部分结果伪装成完整列表，也不为每个递归目录启动 watcher。

### Reveal 与 symlink 浏览

- 显式 reveal 某个 filepath 时，展开到目标所需的祖先目录，定位目标并聚焦 Explorer。
- 目标位于当前 display root 内时保持 root。
- 本地 buffer 的路径被系统转换为 symlink 目标路径时，优先通过 root 自身或其直接子项中的
  symlink 映射回逻辑路径；匹配多个 alias 时采用 canonical target 最具体的匹配。
- 无法映射回当前 root 时，将 display root 切到目标的父目录再定位。
- 浏览目录 symlink 时可以查看目标的子项；悬空 symlink 作为叶子显示。
- 文件变更操作仍以用户选中的链接路径为对象，不能因展示时跟随链接而误改链接目标。

### 刷新与外部变化

- 手动刷新在 Tree 重读当前展开范围，在 List 重新递归校验 display root，并更新布局及状态装饰。
- Tree 自动监听当前展开的目录，折叠或不再浏览时释放相应监听；List 同样遵守监听预算，不无限分配。
- 默认合并 150 ms 内的连续变更。现有监听预算为 50 个目录，达到预算或启动监听失败时给出
  可见诊断，手动刷新仍可使用；Rust watcher 的实现可以调整，但需保留有界资源和失败反馈。
- 临时写入噪声不触发每次重绘：`.swp`、`.tmp`、末尾 `~`、`4913`，以及 `.git`、`.hg`、
  `.svn`、`.DS_Store`、`.Spotlight-*`、`.Trashes`、`.fseventsd`、`__pycache__`、`node_modules`、
  `.cache`、`.vscode-server` 的同名事件可合并/忽略。它们不是文件展示或选区排除规则。
- 没有可见 Explorer 时允许暂停仅供视图使用的监听，并标记数据需要刷新；再次显示时重读。
  文件操作任务及其结果收集继续运行。
- Git 状态或 LSP diagnostics 变化可单独更新装饰，不要求每次都重读目录。
- 布局刷新按上层提供的 NodeId 定位光标：原节点仍可见时保留它，即使行号改变。
- 原节点因过滤、折叠或移除而不可见时，优先定位最近的可见祖先，否则定位附近可见行；空视图无光标节点。
- 原节点重新可见时不自动跳回，保留当前光标；恢复不修改 selection/mode，不自动展开或触发文件打开。

### Git、diagnostics、图标与状态导航

- 文件图标表达类型，目录图标表达展开/折叠；图标和名称使用独立高亮范围。
- 文件和目录名称共用中性基础色。名称颜色优先级为：Git ignored → LSP error → LSP warning
  → Git 状态 → 中性正文色。Info/hint 不覆盖名称颜色。
- Git staged/unstaged、diagnostic 计数和 select/copy/cut 标记使用独立装饰；选择不会覆盖名称状态色。
- Diagnostics 按 error、warning、hint、info 顺序显示非零分类，最多显示两类；目录展示后代聚合值。
- 聚合使用已经取得的 diagnostics，不为补充装饰而自动打开文件或启动额外 LSP 请求。
- 支持跳转到前/后一个可见的 diagnostic 文件、error 文件、warning 文件以及 Git changed item。
- Diagnostics 导航仅定位文件；Git 导航也可以定位含变更后代的目录。
- 导航到末尾后循环到开头，反向同理；没有匹配项时保留光标并给出提示。
- 跳转只使用当前浏览投影，不为寻找匹配而自动扫描所有折叠目录。
- Lua 接入 Neovim diagnostics、图标和主题；Rust 持有归一化数据并承担目录聚合、筛选与跳转计算。
- 未来 VFS 若无 Git/diagnostics 数据，相关装饰和动作应明确不可用；不把虚拟文件临时落盘以获得这些能力。

### 查找、搜索与辅助动作

Explorer 本体保留隐藏项与选区过滤，不新增未定义的实时文本过滤器。现有查找/搜索入口展开如下：

- `/`、`n`、`N` 使用 Neovim 文本搜索浏览当前显示的行；不读取未加载的目录，也不改变选区。
- “Find Files”打开独立的文件名查找界面：光标在目录时以该目录为范围，在文件时以其父目录为范围；
  可在该界面进行名称匹配并选择结果，Explorer 的选区不被替换为搜索结果。
- “Search Files”打开独立的内容搜索界面：目录参数限定该目录树，文件参数限定该文件；
  搜索结果及替换由该界面管理，首期不把它的数据模型迁入新 Filetree。
- “Find Explorer”打开单层目录浏览界面：目录项进入该目录，文件项使用其父目录；列表展示名称、
  类型/图标、权限、大小、日期、owner/group，允许继续进入子目录或返回父目录。
- “Copy Path”对选区中的源项操作；无选区时使用光标项。菜单可选择 absolute、相对 cwd 的 relative、
  filename，默认 relative；多个结果以换行连接后写入剪贴板，不递归展开目录。
- “Quickfix”将选区中的每项作为一条记录，位置为第 1 行第 1 列；无选区时使用光标项。
  替换 quickfix list 并打开其窗口，不递归枚举目录。
- “Add to AI”将选区中的位置加入 AI 上下文；无选区时使用光标项。这是添加位置，不发送消息。
- “File Info”查看一个 item 的路径、类型、大小、mtime、atime、可用时的 birthtime、权限及八进制 mode。
- “System Open”把本地路径交给系统关联程序打开；未来 VFS 未提供本地打开能力时该动作不可用。
- 按键帮助列出当前 mode 下可执行的动作及其键位；widget 历史支持前进、后退和返回先前 pane。

上述入口在本文定义了 Explorer 传出的对象、范围与效果；它们不要求新 Filetree 复刻 Finder、Searcher
或 AI 工具的内部 UI。

### 打开文件

- 移动光标不自动预览文件。
- 用户显式打开 filepath，完成 load buffer 或 locate buffer。
- 目标 window 通过下文列出的窗口选择／新建策略确定。
- 打开完成后，焦点进入目标 buffer pane。
- Explorer 不通过直接替换当前 window 的 buffer 来隐式决定打开位置。

窗口策略明确如下：

1. 调用方已给出有效的 sourcefile window 时，可以使用该目标；不能仅因某个窗口当前获得焦点就覆盖它。
2. 需要选择目标时，只考虑当前 tab 内可承载文件的 windows；排除 Explorer、浮动窗口、固定 buffer
   窗口及其他被标记为非 sourcefile 的工具 pane。
3. 只有一个候选时使用该候选；有多个时在候选窗口显示选择标签，由用户选择。
4. 没有候选时允许新建垂直 window；选择或创建未成功则终止打开流程并保留原焦点。
5. 用户可显式选择水平 split、垂直 split 或新 tab；也可先选一个 pane，再在其旁边创建 split/vsplit。
6. 选择标签显示后，未选到有效目标视为放弃此次窗口选择；不增加 Explorer 的 `<Esc>` 映射。
7. 窗口策略确定目标后才在该 pane 展示文件；加载已有 buffer 时复用其内容与未保存修改。

Tree 正文中的目录“打开”表示切换展开状态；List 目录已经递归展示，不再切换展开。
将目录设为 display root 是独立的导航动作。

### 多选打开

- 一次确定目标 window，采用本节列出的窗口选择／新建策略。
- 将 selected items 中的文件加载为 buffers。
- 目标 window 最终展示最后一个成功打开的文件，焦点进入该 pane。
- 目录项跳过，不递归打开目录内的文件。

批量打开完成、部分失败或取消 window picker，均保留 selection 和 mode，不消费 copy/cut 选区。

### 本地文件与已打开 buffer 的联动

- Rename/move 成功后，Lua 同步关联 buffer 的路径，保留 `bufnr`、内容和未保存修改。
- 目录 rename/move 同步影响其下已打开的 buffers。
- 删除文件后保留对应 buffer，展示源文件已删除的状态，由用户决定何时关闭。
- 仅对已成功的路径变更进行同步；批次部分失败不能使未成功的路径发生 buffer 重命名。

以上规则只针对首期真实 filesystem。目标路径已有另一个 buffer 时的冲突处理，以及具体
Neovim 对接协议仍待设计。

## 已确认：选区与 mode

选取范围、派生集合与判空以 [Rust Treeview selection](../treeview/selection.md) 为准。
Explorer 消费 `subtree_roots` 和 `self_only_nodes`，不维护第二份可独立修改的选区。

### 基本概念

- 光标项：当前浏览或标记的 item。
- Selected items：当前逻辑选区，包括直接标记以及从祖先继承选中状态的节点。
- Mode：选区的用途，分别为普通 `select`、待复制 `copy`、待移动 `cut`。
- Copy/cut 均隐含 select；选择能力在这些 mode 中始终存在。
- `cut` 表示待移动的源项；实际 move 在粘贴时执行。

一个选区只有一种 mode，不能同时包含 copy 项和 cut 项。选区跨目录导航保留。
本文动作的“源项”默认指 `subtree_roots`，已选目录覆盖的后代不重复计数。例如整棵 `src/` 被选中时，
rename 的单项判断把它视为一个目录源项。`self_only_nodes` 保留 container 自身的选择，其业务用途
由 Explorer 按动作定义；不得隐式变成整目录操作源。Selection 判空考虑两组，动作源项单独判空和计数。

### 按键按 mode 分派

| Mode     | `<Tab>`                | `p`      |
| -------- | ---------------------- | -------- |
| `select` | Toggle 当前项是否选中  | 不生效   |
| `copy`   | Toggle 选中，保持 copy | 执行复制 |
| `cut`    | Toggle 选中，保持 cut  | 执行移动 |

其余按键的 mode 适用范围仍待确定。

### 标记动作

标记动作负责改变选区，因此使用光标项：

1. `<Tab>` 按 `marked` toggle 光标项，不改变现有选区的 mode；仅自身选中的节点也会执行取消。
   没有选区时，首次选择进入普通 select。
2. `c`／`x` 将未选中的光标项加入选区，并将整个选区切换为对应 copy／cut mode。
3. 在已选项上重复按当前 copy/cut mode 对应的 `c`／`x`，取消该项。
4. 在已选项上按 `c`／`x`，若请求类型与当前 mode 不同，保留已选 items，并切换整个选区的 mode。
   这一分支只提交 feature 变化，不调用 Add，不刷新 selection stamp、generation 或 selection revision。
5. 取消后两组均确定为空才退出 multiselection；只剩 `self_only_nodes` 时保留 mode。

例子：

- A、B 为 copy，光标在未选中的 C，按 `x` 后 A、B、C 均为 cut。
- A、B 为 copy，光标在 A，按 `x` 后保留 A、B，二者均为 cut。
- A、B 为 copy，光标在 A，再按 `c` 后仅 B 保持 copy。
- A、B 为 copy，光标在未选中的 C，按 `<Tab>` 后 A、B、C 均为 copy。
- A、B 为 cut，光标在 A，按 `<Tab>` 后仅 B 保持 cut。

`<Tab>` 不承担将 copy/cut 转回普通 select 的职责。

### 目录选择

- 选中目录的动作覆盖整个目录，包括尚未展开、尚未加载的后代。
- 已选中某个子项后再选中其祖先目录，选区归并为祖先目录，避免重复操作。
- 支持从已选目录中排除子项或子树，保留祖先自身的选择。

选中动作通过惰性标记覆盖整棵子树，必须保持与逐节点选择等价的语义。排除后代或后续 reparent
可能使目录自身已选而子树未全选，此时它属于 `self_only_nodes`，不能用该目录执行递归 copy/move/delete。
UI 区分自身选中与子树全选；仅自身选中的目录仍保留在 selected-only 投影中。

例如，先选中 `src/a.lua` 再选中 `src/`，最终以 `src/` 表示整棵已选子树。
Copy、move、delete 均不能仅根据当前已加载或可见的子项确定目录操作范围。

### 从已选目录中排除子项

对被已选祖先覆盖的子项执行取消选择时，只取消目标子树：

1. 向目标根写入新的取消 subtree stamp，覆盖目标自身及全部后代，包括未加载后代。
2. 祖先与旁支的权威标记保持原值，不额外写入祖先自身；旁支继续继承原选择。
3. 沿祖先链失效相关聚合缓存，重新派生 `full`、`subtree_roots` 与 `self_only_nodes`。
4. 原已选祖先仍为 `marked=true`，但不再 full，自身进入 `self_only_nodes`；其余完整分支进入
   `subtree_roots`。Selection 仍非空，整个选区的 mode 保持不变。

目录自身 marked 与子树 full 分别判断。只有 full 目录才能代表递归操作源；仅自身选中的目录
仍是有效选择，但不能将它当作整目录操作源。子项重新选中后，原已选祖先可以自然恢复 full；
祖先自身原未选时，不因 children 全选而自动选中。

例如，`src/` 整体为 copy，其结构如下：

```text
src/
  main.lua
  lib/
    keep.lua
    skip.lua
  assets/
```

在 `src/lib/skip.lua` 上按 `<Tab>` 后，`subtree_roots` 为 `src/main.lua`、
`src/lib/keep.lua` 和 `src/assets/`，其中 `assets/` 仍代表其整棵子树。
`self_only_nodes` 为 `src/` 和 `src/lib/`；`skip.lua` 未选中，mode 仍为 copy。

后续 copy/move/delete 只处理 `subtree_roots`；`src/` 与 `lib/` 保留自身选择，不作为额外的递归操作根。
即使随后取消全部剩余源项，这两个目录的自身选择仍使 selection 非空，mode 继续保留。

标记写入只处理目标根，祖先路径只失效派生缓存；枚举操作源时再读取必要子项。未展开、隐藏或被过滤的
非目标分支仍保持原来的选择覆盖范围。排除目录不遍历其后代。

Treeview 已确定采用版本标记方向：`2g` 取消、`2g + 1` 选中，较新版本覆盖旧版本。
Selection 使用 [Treeview 的 subtree/self 标记](../treeview/selection.md#标记与交互)；Explorer 本文的交互显式传
recursive=true，反选仍只更新目标子树，祖先自身和旁支保留原选择。是否为完整操作根另按 full 聚合判断。
标记与 mode 原子提交；操作源按有效选择状态枚举，准备所需子项时锁定选区并校验 data/selection revision。
失败保留选区并报告原因，不能提交不完整的源项。新 NodeId 的 stamp 从 0 自然继承，既有 ID 补载保留状态。
覆盖和计数使用 `{full, known_roots, known_self_only, pending}`：完整选中子树计为一个 root，
未被完整子树覆盖的自身选择另计；未知旁支按需补载。Selection 判空考虑两类数量及 pending，
仅 roots 为 0 时不退出 mode；两组精确为空才退出。以后结构变化自然产生选区且当前无用途时进入 select，不自动恢复 copy/cut。
任务期间保留既定用途，终止后按逐项结果处理，不因中间集合暂时为空而误判全部成功。
这些通知不自动生成标记版本；显式清空和业务成功项清理由 Explorer 单独提交。目录内部分成功仍需定义业务反馈。

### Visual/range selection

- 圈选生命周期遵循 [Visual 圈选契约](../treeview/visual.md)：进入 Visual 后，
  当前 view 保持行映射，后台更新继续进行；改变布局的 snapshot 只保留最新一份，等提交或退出后显示。
- Visual 范围圈定本次标记动作涉及的 items。
- 范围中包含父节点时忽略其所有后代输入，只保留范围内最外层节点；它们分别代表整棵子树。
- `c`／`x` 将这些根加入现有选区，整个选区切换为 copy／cut。
- Visual 的 `c`／`x` 对归并后的根执行显式 Add；已 full 的目标也写入新 stamp，整批共用一个新 generation。
- `<Tab>` 对归并后的根各 toggle 一次，保持现有 mode；没有选区时从普通 select 开始。
- 目录与子项按上述目录选择规则归并，避免重复操作。
- 提交后两组均确定为空才退出 multiselection；取消最后一个子项后仍有祖先自身选择时保留 mode。

Lua 在任何 mode 切换或 frame 交换前捕获圈选 frame 与行范围，由 Rust 按该 frame 的 source 关系
归并原 NodeIds，再校验当前目标、祖先归并结果及动作前提，一次提交选取变更；事务中暂时为空不提前清除 mode。
Visual `c`／`x` 的并集与 Normal 同键重复时的 toggle 必须分别实现。

纯 metadata 更新在布局一致时可以显示，重绘须保留 Visual mode 和两个端点。共享 state 的 cursor/root
更新不拉动本 view 的圈选；其他 views 正常更新。单纯插入或重排行不要求重新圈选。
目标删除、祖先关系改变了归并结果、Toggle 的 marked 判断变化等真正失效时，拒绝本次标记，
结束 Visual、显示最新列表并提示调整，已有 selection 不因失败回滚。

例子：

- A 已选、B 未选，范围包含 A、B，按 `<Tab>` 后仅 B 选中，mode 不变。
- A 已为 copy，范围包含 A、B，按 `c` 后 A、B 均为 copy。
- A 已为 copy，范围包含 B、C，按 `x` 后 A、B、C 均为 cut。
- 范围同时包含目录 P 与子项 C：P 未选时 `<Tab>` 选中整个 P；P 已选时反选整个 P，不再处理 C。
- 范围只包含 C、不包含 P 时，仅处理 C；Tree 与递归 List 使用相同的祖先归并规则。
- 圈选同层文件 B、C 时后台插入同层文件 X：圈选期间仍显示原布局，提交只以 B、C 为行输入，随后显示最新的 B、X、C。

### 执行文件操作

Multiselection 下，递归文件操作的源项严格来自 `subtree_roots`；光标不会被执行动作自动加入源项。

- `p` 只在 copy/cut mode 生效。用户导航到目标目录 D 后按 `p`，对已选源项执行 copy/move。
- `d` 删除 `subtree_roots`，光标所在行不影响删除对象。
- Selection 非空但该动作源项确定为空时，不执行 IO，保留两组选取和 mode，不使用无选区的光标 fallback。
- 标记源项与实际文件 IO 是两个阶段；`c`／`x` 本身不会开始向目标目录传输数据。

Rename 的单项选择规则见下文；其余文件操作在无显式选区时的行为，仍待明确。

### 目标目录

新建与 `p` 共用目标目录规则：

- 光标在目录 D 时，以 D 为目标目录。
- 光标在文件 `D/a.txt` 时，以其父目录 D 为目标目录。
- 默认空树以 workspace root 为目标目录。草案补充：用户已显式改变 display root 时，以当前 display root 为目标。
- 新建输入的相对路径，以该目标目录为基准解析。

`subtree_roots` 决定 copy/move 的源项，光标决定目的地，二者互不替代。

例如，A、B 已标记为 copy，光标在 `src/main.lua`：`p` 以 `src/` 为目标目录；
在该位置新建 `notes/todo.md` 时，目标路径为 `src/notes/todo.md`。

## 已确认：新建、rename 与 move

### 新建

- 支持输入相对路径。
- 输入以 `/` 结尾时创建目录，否则创建文件；文件可以没有扩展名。
- 例如 `notes/` 表示目录，`notes/todo.md` 表示文件。
- 相对路径按上述目标目录规则解析；自动创建缺失的父目录。
- 创建成功后展开必要的目录，并在 Explorer 中定位到新 item。
- 新目录创建后，焦点保留在 Explorer。
- 新文件创建后默认打开，采用本文列出的窗口选择／新建策略，焦点进入目标 buffer pane。

新文件默认打开是新建流程的一部分；移动光标仍不触发自动预览。

### Rename

- 同时支持文件和目录。
- Rename 只修改 item 在当前父目录内的名称，保持父目录不变。
- 输入表示名称，不接受跨目录路径。
- 首期每次只处理单个 item：没有选区时处理光标项；只有一个源项时处理该源项，与光标位置无关；多源项时禁用 rename。
- 例如 `src/a.lua` 改为 `src/b.lua`、`src/old/` 改为 `src/new/` 均属于 rename。

### Move

- Move 负责跨目录移动，与 rename 是不同范围的操作。
- 当前确认的交互为：`x` 标记源项，导航到目标目录，再按 `p` 执行。
- 例如 `src/a.lua` 移到 `tests/` 属于 move。

新建/rename/move 的键位在本文完整 keymap 草案中列出，待整体审阅；直接指定目标路径的 move
入口及其输入契约仍待明确。

## 已确认：执行与反馈

### 执行期间

- 文件操作开始时固定本批次的源项和目标。
- IO 执行期间锁定选区，禁止修改选中状态，显示 spinner／进度。
- 等待冲突确认时仍锁定选区，UI 显示“等待确认”。
- 批次结束后记录逐项 IO 结果，并按 cleanup context 尝试原子清理选区；发布终止结果后停止 spinner、解除本任务锁。
  清理 Stale 不维持执行中的锁，也不把已成功 IO 改报为失败。

### 关闭 pane 与取消任务

- 关闭 Explorer pane 只关闭视图，正在执行的文件操作继续运行。
- 重新打开连接同一份 Rust state 的 Explorer 时，可以继续查看任务进度。
- 取消任务使用 action menu 中的独立 action，暂不设置默认快捷键。
- 收到取消请求后，等待当前项结束或到达可中止的位置，再停止后续处理。
- 等待 Rust 确认停止期间，UI 显示“正在取消”，选区继续锁定。
- 确认取消完成后，按同一 cleanup context 协议处理已成功项，再解除本任务锁；context 有效时移除成功项，
  其余未完成项保留，context 失效时不额外改选并提示重新选择。
- 已完成部分不因取消而回滚。

没有可见 pane 时的冲突确认展示仍待确定。

### 退出 Neovim

- 退出整个 Neovim 时，如有未完成任务，提醒用户并提供“等待”与“退出”的选择。
- 任务存在时通过确认交互让用户决定，不采用一律阻止退出的规则。
- 关闭单个 Explorer pane 仍按上文处理，不触发退出整个 Neovim 的确认。

选项的具体语义已确认：

- “等待”：取消本次退出请求，任务继续运行，用户留在 Neovim；任务结束后不自动退出。
- “退出”：取消未完成任务，等待 Rust 确认安全停止后，继续 Neovim 的正常退出流程。
- 默认选择“等待”。

停止超时、强制退出及与 Neovim 原有未保存 buffer 检查的衔接，仍需在退出协议中设计。

### 目标冲突

Copy/move 采用命令行文件操作的逐项处理方式：遇到目标冲突，逐项询问是否 override。

1. 显示当前项的源路径和目标路径。
2. 用户确认后，Rust 执行该项的覆盖操作。
3. 用户拒绝则跳过该项，继续后续 items。
4. 不因一个冲突直接拒绝整个批次。

这里确定的是逐项确认、跳过和继续处理的交互，不表示已选定 GNU/BSD `cp`、`mv`、`rm`
的某组 flags，也不表示 provider 必须通过 shell 命令实现。

目录合并、不同类型的同名目标、symlink 及覆盖期间的竞态语义仍待设计。

### 逐项结果与选区

以下选区变化适用于 cleanup context 有效的正常清理；逐项 IO 结果在清理 Stale 时仍保留原值。

| 结果    | 本项的选区变化 | 展示与后续处理             |
| ------- | -------------- | -------------------------- |
| Success | 移出选区       | 本项已完成                 |
| Failed  | 保留选中       | 展示失败原因，供后续处理   |
| Skipped | 保留选中       | 标记为 skipped，供后续处理 |

- `p`／`d` 在 cleanup context 有效时将成功项从选区移除。任务终止后重新查询两组，selection 确定为空才退出 multiselection；
  不能仅因递归源项全部成功就执行全局清空，清理后残留的自身选择仍保持 mode。
- 成功项清理与交互反选都只取消目标子树，保留祖先自身和旁支；业务清理还须校验原任务身份、成功源项及 context。
- 部分失败：保留原 mode，按逐项结果更新选择；判空仍考虑清理后两组的实际状态。
- 用户拒绝覆盖：该项为 skipped，保留选中和原 mode。
- 已成功清理的项不会因其他项失败而重新加入选区；cleanup Stale 时成功项可以暂留，不能据此重放 IO。
- “Failed”不代表本项完全没有副作用；部分写入和后续重试的处理还需定义。

以下例子 context 有效且没有额外的自身选择：

- 删除 A、B、C；A、B 成功，C 失败：仅 C 保留选中，保持原 mode。
- 复制 A、B 到 D；拒绝覆盖 `D/A`，B 成功：仅 A 保留选中及 copy mode，并显示 skipped。
- A、B 均复制成功：退出 multiselection。

若 `subtree_roots={A}`、`self_only_nodes={P}`，复制 A 成功后只清理 A，P 自身仍选中，copy mode 保留。

### 结果清理遇到 topology 变化

遵循 [已确认的业务结果清理协议](../treeview/selection.md#业务结果清理)：

- Ready 固定原任务源项与 cleanup context；回写时在同一提交中校验相关 topology 前提并清理全部成功项。
  无关 metadata、重排和浏览变化不触发 Stale；本任务预期更新由 Rust owner 校验后推进 context。
- Context 失效时拒绝整批选区清理，保留当前存活选区与逐项 IO 结果，单独记录 cleanup Stale。
  不恢复旧 selection、不复活失效 ID；不能先清一部分，再让剩余项返回 Stale。
- 发布终止结果并释放本任务锁后，提示“目录结构已变化，选区未自动清理，请重新选择”。
  没有可见 view 时保留结果和清理状态，重连后仍可读取。
- 不自动刷新 context 后重试 Unselect，也不重新准备并重放原 IO。成功项可以暂留选区，
  后续由用户整理选择并显式发起新任务；重复 callback 和旧 token 不能清理或解锁后续任务。

### `<Esc>`

Explorer 不新增或覆盖 `<Esc>` 绑定，也不将其用作取消选区或退出 multiselection 的快捷键。

## 完整 keymap 草案

本节是待整体审阅的键位草案，不意味着原实现的所有绑定直接迁移。已确认的 `c`、`x`、`<Tab>`、
`p`、`d` 与 `<Esc>` 约束优先，其余键位按本节给出可审阅的默认方案。

### 分派规则

- Neovim Normal/Visual mode 与 Explorer 的 select/copy/cut 是两个维度，不能混为同一种 mode。
- 下列普通按键表作用于 Explorer 的 Normal mode；Visual 单独列出。
- 浏览、折叠、root 导航和检视可以使用光标项；文件操作的源项有选区时只能来自选区。
- 无选区时，打开、删除、路径导出等使用光标项，作为延续现有使用方式的草案默认。
- 操作执行、等待确认或正在取消时，禁用选择变更、重复提交及新的文件修改动作；允许滚动、
  浏览、显示切换、查看进度、取消任务及关闭 pane。已经提交的目的地不会随光标变化。
- 共享同一 selection/operation state 的 views 使用同一锁定状态。
- `m`、`o`、`t` 等前缀本身不执行文件操作。
- Explorer buffer 不可编辑；`i`、`I` 不进入文件内容编辑。旧实现的 Insert-mode 导航转发不作为
  新 UI 的独立交互模式。
- 未声明的普通按键保持 Neovim 行为；不得通过全键盘拦截影响 `<Esc>`。

### 浏览、导航与显示

| 按键                                   | 行为                                                                 |
| -------------------------------------- | -------------------------------------------------------------------- |
| `j` / `k`                              | 向下/上移动光标                                                      |
| `gg` / `G`                             | 第一/最后可见行                                                      |
| `<C-d>` / `<C-u>`                      | 向下/上半页                                                          |
| `<C-f>` / `<C-b>`                      | 向下/上一页                                                          |
| `h`                                    | 当前目录展开时折叠它，否则定位并折叠父目录；不跨越 display root      |
| `l` / `<CR>` / `<2-LeftMouse>`（双击） | 光标在目录时切换展开；光标在文件时调用打开动作，有选区则打开所选文件 |
| `z`                                    | 递归切换当前目录子树的展开状态，包含未加载后代                       |
| `W`                                    | 全部折叠，保留 display root 直接子项                                 |
| `[i`                                   | Tree 中跳到可见父行；List 不执行                                     |
| `]i`                                   | Tree 中跳最后直接子项，无子项则跳最后兄弟；List 不执行               |
| `<BS>`                                 | Display root 上移一级                                                |
| `.`                                    | 将光标目录设为 display root；文件使用父目录                          |
| `gb`                                   | 回到上一个 display root                                              |
| `gc`                                   | Display root 切换到 cwd                                              |
| `gw`                                   | Display root 切换到 workspace root                                   |
| `H` / `t4`                             | 切换显示隐藏项                                                       |
| `t1`                                   | 切换仅显示选中项                                                     |
| `t2`                                   | 切换 Tree/List；List 始终递归 display root                           |
| `t3`                                   | Tree 中切换单子目录链压缩；List 中不修改此设置                       |
| `R` / `<C-a>r` / `<D-r>` / `<M-r>`     | 手动刷新                                                             |
| `/`、`n`、`N`                          | 在当前显示文本中搜索及前后跳转                                       |
| `?`                                    | 展示当前上下文的按键帮助                                             |
| `i` / `I`                              | 不执行动作，不进入编辑模式                                           |

`t1`～`t4` 在默认 Explorer 中采用固定含义，不依赖运行时注册顺序。自定义实例的额外 flags
需要在自己的按键表中明确列出，不能挤占这些已有编号。

List 中 Tree 专用的展开/折叠、递归切换和全部折叠不执行；目录不通过 `l`、`<CR>` 或双击折叠。
List 的 `[i`/`]i` 在 Normal/Visual 均不执行；普通光标移动、文件打开、选取、root 导航与其他显示开关仍可用。

### 选择与文件修改

| 按键    | 无选区                  | select                  | copy                     | cut                     |
| ------- | ----------------------- | ----------------------- | ------------------------ | ----------------------- |
| `<Tab>` | 选中光标项，进入 select | Toggle 当前项           | Toggle 当前项，保持 copy | Toggle 当前项，保持 cut |
| `c`     | 选中光标项，进入 copy   | 加入光标项，整体切 copy | 未选项加入；已选项取消   | 加入光标项，整体切 copy |
| `x`     | 选中光标项，进入 cut    | 加入光标项，整体切 cut  | 加入光标项，整体切 cut   | 未选项加入；已选项取消  |
| `p`     | 不执行                  | 不执行                  | 复制选区到目标目录       | 移动选区到目标目录      |
| `d`     | 删除光标项              | 删除选区                | 删除选区                 | 删除选区                |
| `r`     | Rename 光标项           | 单个源项可 rename       | 单个源项可 rename        | 单个源项可 rename       |
| `a`     | 打开新建输入            | 同左，以目标目录为基准  | 同左                     | 同左                    |
| `A`     | 新建目录快捷入口        | 同左，以目标目录为基准  | 同左                     | 同左                    |

- `a` 统一接受相对路径，以末尾 `/` 区分文件和目录；`A` 是同一新建流程的目录快捷入口，
  提示输入相对目录路径并按目录处理，不另建一套文件操作实现。
- `r` 在多于一个最外层源项时不可用；文件与目录都支持，保持父目录不变。
- `c`／`x` 始终先标记，不再根据选区是否为空而突然弹出 Copy to/Move to 输入框。
- “Copy to path”与“Move to path”能力保留为独立 action，完整输入模型和批量路径映射待确定。
  原 `om` 不在此阶段默认为已确认绑定。
- 取消全部选择、取消任务均通过独立的 action menu 入口提供，暂不分配默认键。

### 打开与窗口策略

| 按键    | 行为                                                             |
| ------- | ---------------------------------------------------------------- |
| `o<CR>` | 有选区时批量打开选中文件；无选区时打开光标文件或切换光标目录展开 |
| `w`     | 通过窗口选择动作确定目标 pane，再打开源文件                      |
| `J`     | 先选目标 pane，再创建水平 split 并打开                           |
| `L`     | 先选目标 pane，再创建垂直 split 并打开                           |
| `<C-x>` | 显式创建水平 split 并打开                                        |
| `<C-v>` | 显式创建垂直 split 并打开                                        |
| `<C-t>` | 在新 tab 中打开                                                  |

有选区时，上述文件打开动作使用所选文件，不自动加入光标项。多文件先确定一个目标 pane，
加载全部所选文件并展示最后一个成功项；不会为每个文件隐式创建一个新 window/tab。
所有路径均使用本文列出的候选窗口过滤、选择、放弃和新建规则。

### 状态跳转与辅助入口

| 按键        | 行为                                                          |
| ----------- | ------------------------------------------------------------- |
| `[d` / `]d` | 前/后一个有 diagnostic 的可见文件                             |
| `[e` / `]e` | 前/后一个有 error 的可见文件                                  |
| `[w` / `]w` | 前/后一个有 warning 的可见文件                                |
| `[h` / `]h` | 前/后一个 Git changed 文件或含变更后代的可见目录              |
| `of`        | 打开以目标目录为范围的文件名查找界面                          |
| `os`        | 打开以光标文件/目录为范围的内容搜索界面                       |
| `oe`        | 打开光标目录或文件父目录的单层目录浏览界面                    |
| `oc`        | 复制路径菜单：absolute / relative / filename，默认 relative   |
| `oi`        | 查看单项 metadata；有一个选中源项时使用它，多选时不隐式挑一个 |
| `O` / `oo`  | 将源项交给系统关联程序；多选适用范围待整体 keymap 审阅        |
| `<C-q>`     | 将源项写入 quickfix list 并打开 quickfix                      |
| `oa`        | 将源项作为位置加入 AI 上下文                                  |

### Visual 范围

| 按键      | 行为                                                                    |
| --------- | ----------------------------------------------------------------------- |
| `v` / `V` | 使用 Neovim Visual/Visual-line 圈定行范围                               |
| `[i`      | Tree 中跳到可见父行，只移动 Visual 端点；List 不执行                    |
| `]i`      | Tree 中跳到最后直接子项，否则最后兄弟项；List 不执行                    |
| `c`       | 范围内 items 并入选区，整体切 copy                                      |
| `x`       | 范围内 items 并入选区，整体切 cut                                       |
| `<Tab>`   | 对范围内最外层节点各 toggle 一次，保持 mode                             |
| `d`       | 草案默认：只删除已有逻辑选区；无选区时不执行，Visual 范围不自动替换选区 |
| `oa`      | 草案默认：导出已有逻辑选区的位置；需要先标记范围                        |
| `q`       | 关闭当前 Explorer pane                                                  |

Visual 的 `c`／`x` 是并集操作，不能简单循环调用 Normal-mode 的同键 toggle 来实现。
Tree 的 `[i`／`]i` 保持 Visual mode 和 anchor，不直接修改 selection；显式按 `<Tab>`、`c`、`x` 才提交范围。
`c`、`x` 与 `<Tab>` 都先忽略被范围内祖先覆盖的后代；父节点一旦在范围中，就按整棵子树处理。
Neovim 自身结束 Visual mode 的行为保持有效，Explorer 不为 `<Esc>` 增加 action。
退出后刷新最新 snapshot；Visual handler 先捕获范围，ModeChanged 不得提前交换 frame 或将该命令改成 Normal 单点动作。

### Widget 历史与关闭

| 按键                               | 行为                                                                 |
| ---------------------------------- | -------------------------------------------------------------------- |
| `<C-a>i` / `<D-i>` / `<M-i>`       | 聚焦上一个仍可用的 widget                                            |
| `<C-a>o` / `<D-o>` / `<M-o>`       | 聚焦下一个仍可用的 widget                                            |
| `q` / `<C-a>q` / `<D-q>` / `<M-q>` | 关闭当前 Explorer pane，返回先前可见 widget；没有时返回先前工作 pane |

关闭 pane 不清空 Rust state、不取消文件操作，也不触发退出 Neovim 的确认。

### 旧映射的明确处理

- `<Esc>`：不迁移旧的 cancel pending transfer 绑定。
- `mx`、`mc`、`ms`：旧 mark 前缀组暂不列为默认键；是否保留额外 mode action 在整表审阅时确定。
- Normal/Visual `y`：旧的独立 pending copy 行为不迁移。文件复制统一经过所选 items 和 copy mode；
  未绑定的 `y` 保持 Neovim 文本复制行为。
- `om`：Move to path 的能力保留，键位及输入契约待确定。
- 旧 Visual `d`、`oa` 直接消费 Visual 范围的行为改列为上面的草案，不暗中绕过逻辑选区。

## 已确认：手动取消全部选择

- 独立的“取消全部选择”action，清空选区并退出 mode。
- 保持当前 root 和展开状态，不主动移动光标；原节点因 selected-only 过滤不可见时按光标恢复规则处理。
- 执行期间不可用。
- 通过 action menu 暴露，暂不设置默认快捷键。

它与取消任务是两个独立 action；两者都不绑定 `<Esc>`。

## 待讨论的交互

1. 删除的确认时机与粒度、永久删除与 trash 的范围。
2. 同名目录合并、file/directory 类型冲突、symlink 的行为。
3. 目录内部分成功的反馈粒度；节点继承和完整覆盖判断按既定 Treeview 版本/聚合规则执行。
4. 除 rename 外各文件操作在无显式选区时的行为。
5. 直接指定目标的 copy/move，以及新建/rename/move 的相应键位。
6. 不同 mode 的完整快捷键表及 List 中目录动作的整体验收。
7. 手动切换 display root 后的空树目标；List 递归加载的预算、重试和关闭协议由技术设计细化。
8. 退出停止协议的超时与强制退出、没有可见 pane 时的冲突确认，以及共享 state 下的导航与操作限制。
9. Explorer 跨重启持久化；进程内共享采用共享 data、共享完整 state 或全部独立三种组合。
10. Rename/move 的目标路径已有另一个 buffer 时的冲突处理。

## 交互验收场景

实现阶段至少覆盖以下已确认契约：

- 跨目录导航保留选区；执行操作不会自动添加光标项。
- 标记未选项、切换 mode、同 mode 再次标记，以及取消后两组均为空时退出 mode。
- Normal 已选项切换 copy/cut 仅改变 mode；Visual c/x 在目标已 full 时仍刷新 stamp，并影响后续 reparent 的版本竞争。
- `<Tab>` 在 select/copy/cut 中只 toggle 目标子树，保留现有 mode；取消最后一个子项后仍有祖先自身选择时不退出。
- 目录选择覆盖未加载的后代；选中祖先目录后归并已选子项，避免重复操作。
- 从已选目录排除后代时，只写目标的取消标记，祖先自身与旁支保持选中；隐藏/未展开内容不丢失，mode 不变。
- 惰性选择与逐节点选择的逻辑结果等价，文件操作只消费 subtree_roots；self-only 祖先不作为递归操作根。
- 子项重新选中后，原已选祖先恢复 full；原未选祖先不会因 children 全选而被自动选中。
- Reparent 后目录仅自身选中：`subtree_roots={}`、`self_only_nodes={P}`，mode 与选择样式保留；
  `<Tab>` 按 marked 取消 P，递归动作在源项为空时不执行、不回退光标项。
- 源项准备失败保留选区；共享 views 不能绕过 Treeview 选区锁；mode 与 selection 同步发布。
- 仅有源项 A 与 self-only 祖先 P 时，成功清理 A 保留 P 和 mode；成功 Remove、部分失败同样不额外取消祖先。
- A 成功、B 失败后 B 外部移入 A：清理返回 Stale，不取消 B；逐项结果保留，终止任务释放锁并提示重新选择。
- 验证无关 metadata 不触发清理冲突、本任务预期更新、外部失效后晚到结果、旧 token 及重复回调。
- Visual 先剔除被范围内祖先覆盖的后代；`c`／`x` 并入整棵子树，`<Tab>` 对根各 toggle 一次并保持 mode。
- Visual 期间插入、排序、过滤、压缩及持续 List 补载不打断圈选；提交或退出后只显示最新布局。
- 验证正反向 Visual/Visual-line 的 metadata 重绘、共享 view 不拉动端点，以及提交后不发布旧 selection/mode。
- Select mode 的 `p` 不执行文件 IO；copy/cut 的 `p` 作用于显式源项和目标目录。
- 新建与 `p` 在目录行、文件行和空树中使用一致的目标目录规则。
- 打开文件按本文列出的目标窗口过滤、选择、放弃及新建规则处理，并聚焦目标 pane。
- Root 导航、Tree 展开折叠、单子目录链压缩、隐藏项和仅选中项过滤均按本文完整规则验收。
- 已选 `.gitignore` 在关闭隐藏项、开启 selected-only 时可见；退出 selected-only 后重新隐藏，选择不变。
- 排序、Git/diagnostic 跳转、reveal、symlink 逻辑路径及自动/手动刷新均有独立行为验证。
- 文件名查找、内容搜索、单层目录浏览、路径复制、quickfix、metadata 与 AI 位置入口按本文限定范围调用。
- Keymap 不因旧映射或 widget 追加顺序覆盖已确认语义；不同 Explorer mode 与 Visual 范围分别验证。
- 多选打开一次确定目标 window，加载选中的文件，展示最后一个成功项；目录不递归打开。
- 批量打开全成功、部分失败或取消 picker 均保留选区与 mode。
- List 递归加载 display root，不受 Tree 折叠影响；分批加载、错误、取消和 symlink 循环均有明确反馈。
- Children 加载中仍可浏览、折叠和改选；旧结果不恢复旧视图，刷新失败保留有效数据，共享读取由上层协调。
- 清空选取与取消任务作为独立 action menu 入口，无默认键；清空保留 root/展开，光标按可见性规则协调。
- 刷新按 NodeId 保留光标，不可见时回退到祖先/附近行，节点重现不自动跳回，不因此改选或打开文件。
- 普通折叠保留后代展开记忆，递归展开/折叠覆盖未知后代；晚到 children 结果只提交数据，不恢复旧展开状态。
- 本地 rename/move 同步关联 buffers 的路径并保留未保存修改；删除文件保留对应 buffer。
- 新建输入以 `/` 区分目录与文件；rename 保持父目录，跨目录移动使用 move。
- 文件和目录均可单项 rename；一个源项时处理该源项，多源项时禁用 rename。
- 新建自动补齐父目录并定位新 item；新文件默认按窗口策略打开，新目录保留 Explorer 焦点。
- 操作及确认期间禁止修改选区；终止后恢复可操作状态。
- 关闭 pane 后任务继续；连接同一 state 的新视图可以查看进度。
- 请求取消后持续锁定选区直至 Rust 确认停止；随后按 cleanup context 清理，Stale 时保留当前选区并释放本任务锁。
- 退出 Neovim 时提醒未完成任务并提供等待/退出选择；关闭 Explorer pane 不触发该确认。
- 退出确认默认等待；等待取消本次退出且不自动退出，选择退出则等待 Rust 安全停止后继续退出。
- 冲突逐项确认，拒绝当前项后继续处理其余项。
- 任务终止后两组确定为空才退出；部分失败、skipped 及清理后残留的自身选择保留原 mode。
- Explorer 不新增或覆盖 `<Esc>` 绑定。
