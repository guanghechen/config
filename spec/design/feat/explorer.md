# Explorer 设计

Status: Design。本文记录默认入口的技术契约与当前默认行为。
[交互讨论](../../../doc/spec/explorer/module.md) 保留未定稿提案；本文不将其他草案自动升格。

## 所有权与模块边界

- 默认入口保持 `era.widget.explorer`，通过 `era.m.explorer.Widget` 组合
  [Filetree](../filetree.md) 与 [Treeview](../../../doc/spec/treeview/README.md)。
- Rust `ux/explorer` 组织 workspace、上一个 display root、文件 Job 和浏览动作。
  Filetree 持有 filesystem 事实，Treeview 持有唯一的 topology、root、展开、cursor、selection 和锁。
  Explorer 通过同一个 owner 提交 selection 与用途，不再维护 Lua tree 或独立 pending sources。
- Lua `session.lua` 管理 native handles 与导航 generation；`widget.lua` 管理 pane、标题和持久化偏好；
  `action.lua` / `keymaps.lua` 解释输入；`jobs.lua` 管理准备、确认、进度与取消；`buffers.lua` 接入 LSP/buffer；
  `subscriptions.lua` 接入 Git/diagnostics；`view.lua` 装饰 viewport；`exit.lua` 管理退出协议。
- 实例可传 `data` 共用资源并创建独立 state，也可传 `session` 共享完整浏览/选区/任务状态。
  每个 view 使用专用 buffer。显示开关以 native state 为准，标题直接读取它；Widget observables 只保存偏好和外部输入，
  native 变化不回写成新输入。单个开关提交带同版 revision 的 partial intent，共享 session 与 reveal 的变化同步到各标题。
- 关闭 pane 释放 view、保留 session，不清空选区、不取消 Job。最后 Widget dispose 后撤销输入订阅并取消准备；
  已执行 Job 由 registry 保留至终态，再释放 handles。同一 data 共用一个订阅 controller，来源 ledger 与 revision 随 data 存活。

## 浏览与输入

- 默认 Tree、显示隐藏项、压缩单子目录链，selected-only 关闭，pane 宽 30 列；可恢复显示偏好与宽度。
  正文从 display root 的直接 children 开始，root 放在 tabline；无 tabline 时使用 winbar。
  隐藏后重开恢复 state；首次打开失败保留可关闭的错误 pane，`R` 重试。
- Tree/List 均使用 Filetree 的目录优先 sibling source order。List 始终递归，正文使用相对 display root 的 ancestry text；
  Tree 的展开、折叠和结构导航在 List 中不执行。
- Root/reveal 的异步 resolve 使用 generation，迟到结果不覆盖新导航。Reveal 优先保持逻辑路径；目标位于外部时
  尝试 display root 本身及其直接 symlink children，多个 alias 取物理目标最具体者，无法映射才切到目标父目录。
- Workspace 保存 occurrence 与路径 fallback。Root 删除后明确提示，可返回父目录；workspace 同名重建后可重新定位，
  新资源不继承旧 occurrence。
- 打开、复制路径等动作在输入时捕获 Resource/frame，后来的光标移动不改变本次目标。Visual 通过 Treeview
  `range_action` 保持布局与端点，不在 Lua 重建范围算法。不新增 `<Esc>` 绑定，`i` / `I` 不进入正文编辑。

## Selection 与文件操作

- Normal `<Tab>` 与 `ms` 使用 select 用途；`mc` / `mx` 显式使用 copy/cut 用途。未选项加入当前选区并切换用途；
  已选项上切换用途保留选择及 selection stamp，再次请求同一用途才取消该项。select 用途清除 copy/cut。
- Normal `c` / `x` 有逻辑选区时标记 copy/cut，无选区时询问光标项的复制/移动目标路径；复制默认使用 `-copy` 名称。
  路径操作锁定按键时捕获的 selection revision，排队期间改选则拒绝，不改用新选区。
  Visual `<Tab>` 切换范围选择并保留用途；Visual `c` / `x` 将范围并入已有选区并刷新 stamp。
- `p` 只对 copy/cut 生效；取得 selection lock 后从已提交状态固定用途，与 Ready 源项配对。Treeview 的 subtree roots、
  self-only 和任务清理遵循其契约，不能按可见行猜测完整目录范围。
- 消费逻辑选区的只读动作要求源项完整；selection pending 时取得选区锁，自动补载必要的 children，Ready 后继续原动作。
  标题显示 loading selection，Space menu 可取消；等待期间允许浏览，取消、读取失败或关闭原 pane 后不消费部分集合，
  保留选区与用途。取得锁前 selection revision 已变化时明确失败，不能改用新的选区。已 full 的目录直接作为完整源项，
  不为导出目录路径补载后代；失败后用户重新执行动作创建新的准备任务。每个新准备任务首次查询显式重试
  选区所需的失败 children，后续轮询不重复重试；读取再次失败时终止本次动作，等待用户下一次尝试。
- 当前目录行是 paste/new 的目标，文件行用父目录，空树用 display root。`a` 接受相对路径，末尾 `/` 表示目录；
  `A` 明确新建目录。自动补父目录，禁止覆盖最终目标；新文件成功后 reveal 并打开，新目录只 reveal。
  创建完成使用 Job 已发布的 NodeId 定位，保留创建时的逻辑 occurrence，不按同一路径重新绑定资源。
- `r` 接受一个源项及单一 basename，保持父目录；无选区时用光标项。Space menu 的 Copy/Move to path 只接受一个源项，
  输入为完整目标路径，相对输入以 cwd 解析，允许补父目录；多项使用 Copy/Move to directory，逐项映射为原 basename。
  Rename 默认值按平台从 native raw path 提取，Unix 文件名中的反斜杠和原始 bytes 不被重解释为分隔符或 display label。
- Normal `d` 使用选区，无选区时用光标项，先确认。`dot.context.explorer.trash=true` 时明确送回收站，否则明确永久删除；
  回收站工具不可用或失败不降级永久删除。
- Visual `d` / `oa` 直接消费输入时捕获的临时范围；范围内父节点覆盖后代，按最外层子树去重。
  Rust 只读范围查询复用 Treeview 的 identity / ancestry 校验，不改写逻辑选区。删除确认和 Job 使用固定的源项，
  不随光标移动或同名资源替换重定向；取消不删除文件，原有无关标记及 copy/cut 用途保留。
- 目录合并、逐项冲突、type/symlink 校验、跨卷 move 和部分成功遵循 Filetree 契约。覆盖提示同时显示源和目标，默认 Skip。
  成功项清理，失败/跳过保留；context Stale 单独报告，不能重绑同名新项。
- 准备、执行、确认和取消期间锁定选区与新修改操作，允许浏览。取消准备会结束等待中的输入 Future，等原 token 解锁再恢复；
  迟到 callback 没有执行资格。Job 取消要等 native 终态；标题显示进度，Space menu 提供取消和最近结果。
  Job 终态与新确认由 Treeview 的共享 poller 检测并及时交付，不等待低频进度刷新；无执行任务时撤销该订阅。
  无可见 pane 时 Job 继续使用全局 UI 确认，不强制重开 Explorer。

## 文件窗口与 LSP

- 打开复用 `dot.win.pick_sourcefile`，排除 Explorer、浮窗、固定 buffer 和其他非 sourcefile pane；单候选直接使用，
  多候选选择，无候选可新建垂直窗口。放弃选择保留原焦点。
  默认打开优先使用当前 tab 记住的源码窗口，`w` 明确通过 window picker 选窗；先替换目标 buffer，成功后再切换焦点，
  避免激活即将被替换的旧 buffer。加载失败保留原焦点及目标 buffer。
- Normal `l` / `<CR>` / 双击只打开捕获的光标文件，保留已有逻辑选区；Tree 目录仍切换展开，List 目录不执行。
  显式 `o<CR>` 有逻辑选区时打开所选文件，无选区时回退到光标项；其他显式窗口策略继续使用选区优先规则。
- 批量打开只确定一次目标 window，跳过目录，加载各文件并展示最后成功项；保留 selection/mode。
  支持水平 split、垂直 split、新 tab；移动光标不隐式预览或打开。
- Move/rename 使用 Filetree 移动准备握手：覆盖确认通过后请求 `workspace/willRenameFiles`，应用返回的 workspace edits；
  Rust 复验 identity/physical paths 后执行 IO；成功结果才重命名 buffers、重选 LSP clients 并发送 `workspace/didRenameFiles`。
  取消后的迟到 response 不应用 edits。单 client 沿用 1 秒超时，无 edit 时继续；已应用 edits 不因后续 IO 失败自动回滚。
- Buffer 同步保留 bufnr、内容和 modified 状态，目录移动覆盖已打开后代；只解析父目录 alias，移动末尾 symlink 不重命名
  referent buffer。删除/回收文件保留对应 buffer。
  Windows physical path 在编辑器边界转换 verbatim drive/UNC 前缀并保留 UNC share root，preparation、buffer 匹配
  和完成通知使用同一套 Neovim 路径；native identity 校验仍使用原始 physical path。
- 目标名已有另一 buffer 时保留双方内容，记录 `b:filetree_move_target` 并报告待处理路径，不强删 buffer。
  无法表示为 Neovim filepath 的结果仍可显示/清理，跳过依赖该 filepath 的编辑器动作。

## 装饰与订阅

- `dot.theme.hlgroup.explorer` 集中定义 `m_ex_*`、`m_fe_*` 与共享的 `m_ft_*`，遵循 theme loader 的 fallback。
- 树形连接线使用 muted 前景色，在光标行与 Visual 选区中持续可见并保留行背景；横向滚动时裁掉屏幕外的线条。
- 图标和名称有独立 highlight range。特殊目录使用 `MiniIcons*`，普通目录图标用 `m_ft_dirname`，展开只改 glyph。
  Rosé Pine 普通目录沿用 subtle，ignored 图标使用 muted 对应的 `m_ex_ignored`。
- 文件/目录名称共用 `m_ft_filename`；优先级为 ignored → error → warning → Git status → 中性色。
  Info/hint 不覆盖名称色，selection/copy/cut 用独立 sign，焦点用背景。
- Diagnostics 按 E/W/H/I 显示非零分类，最多两类；Git 用具体变更字符与颜色表达状态，不额外显示 `S/U`。
  纯 staged 的 `A/M/R/C/T` 使用 staged 前景色；含 unstaged 的行按具体变更类型着色，删除与冲突始终保留各自颜色。
  装饰不写正文，不为聚合打开文件。
  Diagnostics 与 Git status 统一靠右显示，Git 名称色与 status 复用 `m_ft_git_*` 前景色，状态区保留当前行背景。
  Git 标记连续排列（如 `MDA`），与 diagnostics 之间保留一个空格；untracked 使用 ``，ignored 使用 ``。
- 文件链接、目录链接与 dangling link 在右侧独立显示 `  `，名称和 fileicon 保留各自语义。
  clean 使用 `m_ex_symlink`，Git 状态色按 ignored、冲突、删除、untracked、unstaged、staged 的优先级选择
  `m_ex_symlink_*`；主题生成 40% 紫色 + 60% 状态色，diagnostics 不覆盖链接标识的 Git 混色。
  图标和尾部留白共同叠加当前行背景；链接身份来自 Filetree Resource，不在绘制时探测文件系统。
  压缩目录链不跨越 symlink，普通后代不继承链接标识；链接目标出现、消失及同名替换通过资源刷新更新。
- 订阅复用既有 Git status/ignore snapshots；diagnostics 按 namespace/buffer 替换。重连补齐停订阅期间的撤销；
  Busy 保留 pending 输入并延迟重试，手动 refresh 也重新同步 diagnostics。
  Ignore cache 失效独立触发可见路径预加载，完成后再提交 annotation 输入；后台 pane 再显示时按失效版本重新查询，
  不依赖 source/layout/viewport 变化。预加载期间释放最后一个 owner 后，迟到结果不得再次提交输入。
- Diagnostics/error/warning 前后跳转只查可见文件，Git 也可跳聚合目录，首尾循环。Find Files、Search Files、Find Explorer、
  Copy Path、Quickfix、File Info、System Open、Add to AI 调用现有能力；AI 动作只添加位置，不发送消息。

## 默认键位

| 按键 | 动作 |
| --- | --- |
| `h` / `l` / `<CR>` | 折叠/父目录；展开或打开 |
| `z` / `W` / `[i` / `]i` | 递归切换；全部折叠；父行；最后直接子项/兄弟 |
| `<BS>` / `.` / `gb` / `gc` / `gw` | 父 root；当前目录；上一 root；cwd；workspace |
| `t1` / `t2` / `t3` / `t4`、`H` | selected-only；Tree/List；压缩；隐藏项 |
| `<Tab>` / `ms` / `mc` / `mx` | select；select；copy；cut，同用途切换选中 |
| `c` / `x` / `p` | 无选区时复制/移动到路径，有选区时标记 copy/cut；paste |
| `a` / `A` / `r` / `d` | 新建；新建目录；rename；delete/trash |
| `o<CR>` / `w` / `J`、`<C-x>` / `L`、`<C-v>` / `<C-t>` | 打开选区；选窗口；split；vsplit；tab |
| `[d`、`]d` / `[e`、`]e` / `[w`、`]w` / `[h`、`]h` | diagnostic；error；warning；Git 导航 |
| `of` / `os` / `oe` / `oc` / `oi` / `oo`、`O` / `<C-q>` / `oa` | 查找；搜索；目录；路径；详情；系统打开；quickfix；AI 位置 |
| `<Space>` / `R` / `?` / `q` | 动作和任务；刷新；帮助；关闭 pane |

Normal `<Space>` 使用 `nowait=false`，保留 `<leader>1` 等全局 leader 组合；单独按 Space 在 `timeoutlen`
后打开动作菜单（原生 Neovim 默认 300 ms）。其余 Explorer 绑定继续使用 `nowait=true`。

## 退出协议

- 用户输入的退出命令及可判定的命令链在 `CmdlineLeave` 执行前拦截；仅关闭整个进程时询问，关闭一个 pane 不触发。
  默认 ZZ/ZQ 只在没有已有 mapping 时接入。
- 默认 Wait 取消本次退出，任务继续，结束后不自动退出。Cancel operations and exit 等 native 终态后重放原命令，
  仍经过 Neovim 未保存 buffer 检查；10 秒未停止则放弃本次退出，继续保留任务。
- `ExitPre`/`QuitPre` 抛错不能否决 Neovim 退出。直接脚本退出、自定义 mapping 或动态 Ex 执行可能绕过前置交互；
  `ExitPre` 必须取消并同步等到 native 终态，不能宣称此时仍能选择 Wait。强制终止进程不在可拦截范围。

## 验证

集成 specs 位于 `__test__/specs/era/m/explorer/`，native 状态测试在 `rust/yoz/src/ux/explorer/`。
Job、identity、watch、跨卷和性能由 Filetree/Treeview 对应测试覆盖；实际命令、结果及平台缺口统一记录在
[测试指南](../../../__test__/README.md)，不将编译通过当作平台 runtime 验收。
