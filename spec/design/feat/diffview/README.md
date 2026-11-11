# Diffview 设计

## 概述

`era.m.diffview` 是 Git diff 可视化模块，提供 side-by-side diff 视图和 commit 日志查看功能。

## 核心功能

| 功能          | TabType              | 描述                                                                                            |
| :------------ | :------------------- | :---------------------------------------------------------------------------------------------- |
| Git Workspace | `diffview_workspace` | 查看 staged/unstaged 文件变更与 repository History，右侧显示 side-by-side diff                  |
| Git Log       | `diffview_commits`   | 查看 commit 历史，支持 path_filter 过滤特定文件/目录，支持展开查看每个 commit 的变更文件及 diff |

Workspace 与 commits 使用不同 tabtype，分别控制命令与 UI；tabtype 定义见 [Tab](../../dot/tab.md)。

File History 使用 `diffview_commits + path_filter`；tabline 显示过滤文件名，列表只包含涉及该路径的 commits。

- 列表用 `git log --follow` 沿改名追溯；每个 commit 记下该文件在其中的路径（`ICommit.filepath`），打开时按这个
  路径找文件，改名前的 commit 显示旧名。
- commit 的变更文件开启改名检测（`diff-tree -M`）：改名是一个 `R` 条目，带旧路径 `prev_filepath`，与
  `git log --follow` 一致；diff 左侧取每个条目自己的旧路径，不套用 File History 所跟踪文件的旧路径。

## 入口与 Workspace 组装

- `diffview_workspace` 是 repository-level Git workspace，入口键位见[全局入口](keybinding.md#全局入口)。
- workspace 左侧从上到下组合 Staged、Unstaged 与 History，右侧共享一组 SBS windows；默认 focus Changes。
- History 复用 commits pane/state/action，但 working-tree state 与 commit-log state 独立持有。
- workspace view 持有共享 SBS preview generation；最后一次 Changes 或 History selection 是唯一 preview writer。
  刷新与 untracked 切换不是 selection：History 持有 preview 时，Changes 只更新 pane、光标与当前条目。
- Staged、Unstaged 与 History 视为一个 sidebar，统一隐藏或恢复。
- repository History 先创建 pane，再异步获取 Git log，不阻塞 workspace layout 首次呈现。

## 架构分层

| 层      | 职责                                                                       |
| :------ | :------------------------------------------------------------------------- |
| Pane    | 渲染与数据管理，不决定窗口布局                                             |
| View    | 创建/销毁窗口、布局切换、组合 pane、生命周期                               |
| State   | 该视图的响应式状态（Observable）                                           |
| Action  | 该视图的用户操作（stage/unstage/选择文件等）                               |
| Keymap  | 该视图的快捷键绑定                                                         |
| Session | 每个 tab 一份：持有 layout、state、History 与 keymap 钩子，关闭时统一回收  |
| Layout  | 工具方法：根据树形结构创建窗口分割                                         |
| Nvimbar | 该视图的 tabline 与 window-owned winline composition                       |

每个 diffview tab 有一个 session，它就是 action 与 view 操作的 context：

```text
fn / tabline ──> session ───────────────> sbs_keymap
                    ↓
      keymap → action → view → pane/state
```

- 打开 workspace 或 log 时创建 tab 与 session，或回到已打开的同一视图；session 按 tab 查找。Workspace session 另持有
  History：一个复用 workspace layout 与共享 preview 的 commits context。
- `action` 与 `view` 通过 context 的钩子请求 keymap refresh，不反向依赖 `keymap`。
- Session 持有 content loader，打开条目必须经它加载内容；workspace 的 History 与 workspace 共用 loader。
  Buffer 记录所含 object 与源文件格式，相同内容不重读、不重写；重写前先清除该记录，写入失败时不会留下错误的缓存身份。
- 刷新分为取数与应用两步：workspace 取得 entries 后应用，commits 的刷新与翻页取得一页后应用。应用一侧只依赖传入的
  数据与请求归属，测试可直接喂数据。
- `keymap` 不 require `action`，以参数接收 action 模块，workspace 另收 History 使用的 commits action。
  Session 传入真实模块，路由测试传入记录调用的替身。
- Session 拥有 Git 订阅、Changes 尺寸监听、预览代次与 untracked discard 队列；`close()` 统一回收。一个模块级
  `TabClosed` autocmd 关闭失去 tab 的 session；漏掉 `TabClosed` 的 session 在下一次查找时关闭。
- `sbs_keymap` 只安装 buffer-local mappings，按键时的解析与工作区文件的借用见
  [共享 SBS buffer 契约](keybinding.md#共享-sbs-buffer-契约)。

### 四种 Pane

| Pane     | 用途                     | 使用者                  |
| :------- | :----------------------- | :---------------------- |
| filetree | 通用文件树/列表          | commits view            |
| changes  | staged / unstaged 文件树 | workspace view          |
| commits  | Commit History 列表      | workspace、commits view |
| sbs      | side-by-side diff        | 所有 view               |

## 模块依赖

| 依赖模块                                  | 用途                                         |
| :---------------------------------------- | :------------------------------------------- |
| `era.m.git.{status,state,numstat}`        | Git status 快照、刷新通知与行数统计          |
| `era.m.git.{index,staging,buffer,visual}` | Index 写入队列、index 文档与范围 unstage     |
| `stl.git.exec` / `stl.git.info`           | Git 命令执行与 object 内容读取               |
| `ux.treeview`                             | native topology、交互状态与 viewport surface |
| `stl.c.Observable`                        | 响应式状态管理                               |

## Filetype

| Filetype           | Pane     | 用途                                      |
| :----------------- | :------- | :---------------------------------------- |
| `diffview-changes` | changes  | workspace 左侧的 staged / unstaged 文件树 |
| `diffview-files`   | filetree | commits 的文件列表                        |
| `diffview-commits` | commits  | commit 列表面板                           |
| `diffview-sbs`     | sbs      | 内部 buffer 的初始 filetype 与空内容占位  |

这些值由 `config.FT` 引用 `stl.filetype` 常量。SBS 加载内容后按 `vim.filetype.match` 设置该 buffer 的 filetype
（不开启全局 filetype detection），buffer 可使用对应语言的 filetype，因此不能仅凭 `diffview-sbs` 判断 SBS 身份。
Pane 归属由 view/layout 确定；tab 类型与命令适用范围见 [Tab](../../dot/tab.md)。

## 命令

| 命令                       | 描述                                                     |
| :------------------------- | :------------------------------------------------------- |
| `Fdiffviewclose`           | 关闭 Diffview Tab                                        |
| `Fdiffviewopencommits`     | 打开 Git Log 视图                                        |
| `Fdiffviewopenfilehistory` | 打开当前文件的历史视图（实际调用 commits + path_filter） |
| `Fdiffviewopenworkspace`   | 打开 Git Diff 视图（staged/unstaged）                    |
| `Fdiffviewrefresh`         | 刷新当前 Diffview                                        |
| `Fdiffviewtogglecommits`   | 切换 workspace History / commits 面板显示                |
| `Fdiffviewtogglefiles`     | 切换 workspace sidebar / commits filetree                |

## 布局

Workspace 与 standalone commits 的布局及尺寸规则见[布局设计](layout.md)。

## Diff 模式

使用 Neovim 内置 diff 模式（基于 xdiff），由 `scrollbind`、`cursorbind` 处理同步滚动与光标，
内置 diff 负责行对齐、填充和折叠。

复用 Neovim 的 C 实现与窗口行为，避免另行维护 diff 对齐和滚动同步。

## 高亮隔离

1. 定义专属高亮组：所有 diffview 高亮组使用 `m_dv_*` 前缀
2. 通过 winhighlight 隔离：每个窗口设置 `winhl`，将全局高亮组映射到专属高亮组
3. 使用专属 namespace：所有 extmark 使用 `era.m.diffview` namespace
4. 不修改全局高亮组：绝不修改 `DiffAdd`、`DiffDelete` 等全局高亮

### 高亮组前缀

| 前缀           | 用途              |
| :------------- | :---------------- |
| `m_dv_`        | 面板通用          |
| `m_dv_add*`    | Diff 新增内容高亮 |
| `m_dv_del*`    | Diff 删除内容高亮 |
| `m_dv_ft_*`    | 文件树面板高亮    |
| `m_dv_cm_*`    | Commit 列表高亮   |
| `m_dv_sign_*`  | Sign 高亮         |
| `m_dv_winbar*` | Winbar 高亮       |

### winhighlight 隔离

左侧窗口（显示 old 版本）和右侧窗口（显示 new 版本）使用不同的 winhighlight 映射：

- 左侧：`DiffAdd` → `m_dv_del`（新增行在旧版本中不存在，显示为删除样式）
- 右侧：`DiffAdd` → `m_dv_add`（正常显示新增样式）

## 数据类型

文件条目 `era.m.diffview.IFileEntry` 与 commit `era.m.diffview.ICommit` 的字段见
[types.lua](../../../../lua/era/m/diffview/types.lua)。

## 状态管理

每个 domain 独立维护自己的状态，存储在 `view/*/state.lua` 中。使用 `stl.c.Observable` 实现响应式更新。
workspace tab 同时组合一个 workspace state 与一个无 path_filter 的 commits state；二者只通过 workspace
持有的 layout 和 preview ownership 协作，不相互写入 domain state。
workspace view 拥有组合 layout 与 panel buffers；无论通过 close action 还是直接关闭 tab，都必须释放这些资源。

### Diff fold 状态

`dot.context.diffview.flag_fold_unchanges` 是持久的 global default。创建 workspace 或 commits view 时，
其值被复制到对应 `State.fold_unchanged`，之后由该 view 独立持有当前 fold policy。

- 切换 global default 时立即同步当前 view。
- 展开或折叠当前 view 的 left/right diff panes 不修改 global default。
- 当前 view 内切换文件或 layout 时保留 per-view policy；关闭后重新打开则再次使用 global default。

对应键位见[通用约定](keybinding.md#通用约定)。

### Untracked 可见性

`dot.context.diffview.flag_untracked` 持久化 workspace Changes pane 是否显示 untracked files，默认开启。
该 flag 只过滤 view projection；完整 Git snapshot 仍保留在 workspace state，refresh identity、staging 和
discard contract 不受影响。隐藏当前选中的 untracked entry 时，workspace 会选择 Changes pane 中第一个
剩余可见 file row，或在没有可见 file row 时清空 SBS preview。

Workspace tabline 的 status flags：

- `³`：新 Diffview 的默认 fold policy。
- `󰡯⁴`：untracked 可见性。

## 文件操作

- Changes pane 的 `gr` 从已发布行取得目标，并在异步准备前固定 workspace 与相对路径。
  Untracked 项通过 `era.m.filetree.jobs` 捕获 Resource 并提交 native Filetree delete Job，资源身份、IO、取消及退出收尾
  遵循 [Filetree 文件 Job](../../ux/filetree/jobs.md)。同一 workspace state、同一路径的未完成请求合并，后续光标或 workspace 变化不重定向动作。
- Discard 拒绝普通目录，目录 symlink 按链接项删除；不枚举或删除其 referent。
  捕获后的资源被替换时报告失败，保留替换项；再次操作必须来自新的显式输入。
- Workspace 在资源捕获完成前关闭时不启动 Job；已接受的 Job 继续完成，关闭后的 state 不再刷新 UI。
  有实际成功的 IO 就请求刷新，取消不回滚已完成删除；同步/收尾错误单独报告，不把已完成删除描述为未执行。
- Tracked 文件的 discard、stage 与 unstage 由 Git 领域和 repository index FIFO 执行。

## History / Commits 分页

Workspace History 与 Git Log (`diffview_commits`) 复用分页 commit state。Staged、Unstaged 与 History 的 winline
见[布局](layout.md#winline-与列表)。

### 分页设计

- **每页数量**：`config.COMMITS_PER_PAGE = 100`
- **Tabline 显示**（Git Log）：`󰊢 <index>/<total> │ 󰓩 <page>/<page_count>`，index 为当前 commit 在整个 log 中的序号
- **取数**：打开时先获取 commit 总数，再获取第一页（含 shortstat）；翻页获取目标页后重绘 commits 面板与分页信息。

### 分页与请求一致性

- 带 path_filter 时也支持分页（单文件历史可能很长）
- 未过滤 log 使用 `--topo-order` 和 parent hashes 生成 compact commit graph；为保证跨页 lane 连续，先读取
  `HEAD..page_end` 的轻量 metadata，再只为当前页获取 shortstat。带 path_filter 的 File History 不生成 graph。
- 翻页时向 native State 提交 commit 折叠命令
- 每次翻页都重新获取 shortstat 数据
- `g/` 在当前 log（包括 path_filter）中跨页搜索：至少 4 位 hash prefix 优先匹配且必须唯一，否则按 commit message 进行 case-insensitive substring 匹配并选择最新结果
- search、翻页和 refresh 共享 per-view content generation；只有最新 request 可以提交 state，关闭 view 会使所有在途 request 失效并拒绝后续 request
- 搜索使用同一 Git-log snapshot 的 position 与 total，并原子更新 total、page、commits 和 current commit
- 分页分别跟踪 requested page 与 applied page：连续翻页累积 intent，search/refresh supersede pending page 时恢复 applied page

## Buffer 管理

### Buffer 类型

| 类型          | buftype   | modifiable | 用途                            |
| :------------ | :-------- | :--------- | :------------------------------ |
| filetree      | `nofile`  | `false`    | 文件树面板                      |
| commits       | `nofile`  | `false`    | Commit 列表                     |
| sbs_old       | `nowrite` | `false`    | Side-by-side 左侧（旧版本）     |
| sbs_new_local | -         | `true`     | Side-by-side 右侧（工作区文件） |
| sbs_new_index | `nowrite` | `false`    | Side-by-side 右侧（index 版本） |
| null          | `nofile`  | `false`    | 空文件占位（新增/删除文件时）   |

### 窗口选项保存与恢复

Buffer 离开窗口时，Neovim 记下它在该窗口的窗口选项，交给下一个显示它的窗口。工作区文件进入 SBS window 时，
先记下它带来的窗口选项（`config.TRACKED_WINOPTS`），再设为 diff side；preview 换走它之前、session 关闭时、SBS
window 关闭时（`WinClosed`，包括整个 tab 被关闭），恢复这些选项，以免 `scrollbind`、`cursorbind`、
`foldmethod=diff` 与 Diffview 的 `winhighlight` 被带到普通窗口。不能指望 Neovim 跳过 diff 窗口的选项：'diffopt'
的 `closeoff` 会在 tab 关闭时关掉最后一个 diff side 的 `diff`。

## 快捷键

完整 key scope、bindings 与 fallback contract 详见[快捷键契约](keybinding.md)。

## 设计取舍

- Pane 负责内容与数据，View 负责窗口布局、pane 组装和交互；SBS 可跨 view 复用，pane 渲染可独立测试。
- Workspace 与 commits 分别持有 domain state，减少状态分发与相互干扰；workspace 通过 layout/preview ownership 组合二者。
- Changes 专门处理 staged/unstaged 状态与 stage/unstage 动作；commits filetree 处理 commit 文件选择，二者不共用业务 pane。
- Staged、Unstaged、History 各有 window/buffer，统一作为 sidebar 控制，并共享 SBS preview。
- Diffview 只展示变更文件，不复用完整 filesystem Explorer 的数据与文件操作模型。
- 使用独立 tab 隔离布局；关闭 tab 时释放该 view 的资源。

## Treeview 发布

Changes、Commits 和独立 files pane 均通过 `pane/tree.lua` 导入 records。Commit header 是不可压缩的 branch，
文件和目录是其后代；同名目录在不同 commit 下使用不同 provider key。Git 原始路径保留在业务 metadata 中，
provider key 使用可逆 byte 编码，显示 label 单独转义。

Native State 在 pane 隐藏、buffer 重建和 layout 切换之间保留；默认新 commit 折叠，普通目录展开。
Tree/List 共用相同的目录和文件 records，切换只改变 native display，不删除目录、不改写 label/parent；
业务 records 未变时不产生 data revision，也不丢失目录的 NodeId 或折叠标记。Changes 与独立 files pane 的 List 使用
`list_text = "ancestry"`；inline commits 的 List 使用 `list_from_depth = 1` 保留 commit header 分组并在组内平铺文件，
文件路径由同一 source 的祖先 labels 生成，切回 Tree 恢复原目录折叠状态。
Commits 初始只准备 commit headers，未展开的缓存 files 不进入 inline records 或 header metadata；首次 inline 展开才准备
该 commit 的 files。缓存仍保留时，后续展开／折叠只提交 native State 命令，不重新构造 producer、解析 icons 或发起 import；
回收后的冷重开重新导入 records。Standalone filetree 独立准备自己的 records，reveal 显式准备目标 commit 的 files。
独立 Git Log 的 Commits consumer 在每次 attach/resume 后恢复 `signcolumn=yes:1` 及当前 preview commit 的指示 sign；
workspace History 使用 `signcolumn=no` 与单列 statuscolumn spacer。
行号、父子导航与 action metadata 从已发布 Frame 派生。相邻文件通过 `Frame:adjacent_leaf` 定位，Lua 只读取目标，
不缓存全量行表；跳过的原生行仍计入查询成本。`apply_to_buffer` 返回发布 Future，refresh 完成后才
标记 snapshot 已应用；定位使用稳定 key，等待对应行可用，buffer 行与 action 对象来自同一 Frame。
Metadata overlay 只在 viewport 绘制。

通用契约见 [Treeview 结果集](../results.md)。

### Materialized records cache

Commits 的 collapsed、非 current 文件树使用 20,000 个 file/directory nodes 的 LRU 预算。
Expanded/current commit 是仍在使用的内容，不作为可回收缓存；正在 materialize 的操作保护其完整发布与展开过程，
等待已启动的 eviction 结束，并在加载新 commit 前回收已超预算的旧缓存。

Eviction 保留 commit header 和既有的 raw `commit.files` 查询缓存，移除额外的 producer/native records。
目录折叠设置按 provider key 与旧 native ID 保存为紧凑 checkpoint；冷重建产生新 ID 后先恢复折叠，再展开 commit。
节点仍存在时 native State 是唯一 expansion authority。翻页和 dispose 清理过期 checkpoint。

失败的 eviction 保留原 surface；producer 只在仍属于该请求时恢复。即使 native 删除已提交、surface 发布失败，
也保留已移除目录的 checkpoint。Materialization/reveal 的异步结果必须属于当前 content generation。
隐藏面板中的显式 materialization/eviction 可以只发布逻辑 State；普通隐藏刷新仍跳过准备。

Budget 限制 materialized records cache，不宣称限制用户展开的内容或 raw `commit.files` 查询缓存的全部内存。
