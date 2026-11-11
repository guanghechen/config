# Diffview 快捷键

快捷键按 `view -> pane -> active preview` 三层解析：

- `view` 决定 workspace 或 standalone commits 的全局行为。
- `pane` 决定 Changes、History、Commits、Filetree 或 SBS 的局部行为。
- workspace SBS 根据最后一次 selection 的来源，将 preview action 分发给 Changes 或 History。

## 全局入口

- `<leader>gg`：打开 repository Git workspace。
- `<leader>gf`：打开当前文件的独立 File History。
- `<leader>er`：在 navigation pane 定位当前项；已聚焦目标 pane 时隐藏它。
- `<leader>et`：workspace 中切换完整 sidebar；standalone commits 中切换 Commits pane。

## 通用约定

- `g?`：显示当前 Diffview 的快捷键帮助。
- `<C-a>r`：刷新当前 view；aliases 为 `<D-r>`、`<M-r>`。
- `<C-j>` / `<C-k>`：选择下一个 / 上一个 domain item。
- `gf` / `gF`：在已有普通 tab / 新 tab 打开当前文件。
- `zC` / `zM`：关闭当前 view 的所有 diff folds。
- `zO` / `zR`：打开当前 view 的所有 diff folds。
- `t3`：切换默认 diff fold policy，并应用到当前 preview domain。

Help 使用 `mode + key` 作为 mapping identity；Normal 与 Visual 的同名 mapping 分别保留。

## Git Workspace

### Changes pane

- `<CR>`、`<2-LeftMouse>`：选择文件或切换目录展开状态。
- `J` / `K`：移动到下一项 / 上一项并选择。
- `<C-j>` / `<C-k>`：选择下一个 / 上一个 file diff。
- `[i` / `]i`：跳到 parent / last child-or-sibling。
- `gs` / `gu`：stage / unstage 当前文件或目录。
- `gr`：discard 当前文件改动。
- `oc`：复制当前文件路径。
- `gf` / `gF`：打开当前文件。
- `za` / `zc` / `zo`：切换 / 关闭 / 打开 tree fold。
- `zC`、`zM`、`zO`、`zR`：控制当前 view 的所有 diff folds。
- `t1`：切换 tree/list viewtype。
- `t2`：切换 compact directory paths。
- `t3`：切换默认 diff fold policy。
- `t4`：切换 untracked files。
- `q`：关闭 Diffview。

Changes 与 History pane 支持鼠标滚轮。

### History pane

History 显式定义以下 bindings，不继承 standalone commits 的 layout controls：

- `<CR>`、`<2-LeftMouse>`：选择 commit/file，或切换 expanded commit 下的 directory。
- `<Tab>`：将当前 commit 设为 active commit。
- `<C-j>` / `<C-k>`：选择下一个 / 上一个 commit。
- `[[` / `]]`：上一页 / 下一页。
- `[i` / `]i`：跳到 parent / last child-or-sibling。
- `K`、`gK`：显示 commit details。
- `g/`：按 hash prefix 或 commit message 搜索并跳转。
- `oc`：复制当前 file/directory path。
- `yy`：复制完整 commit hash。
- `gh` / `gl` / `oo`：折叠 / 展开 / 切换当前 commit 或 directory。
- `za` / `zc` / `zo`：切换 / 折叠 / 展开当前 commit 或 directory。
- `gH` / `gL`：折叠 / 展开所有 commits。
- `gf` / `gF`：打开当前 commit file。
- `gR`：将文件恢复到当前 commit 版本。
- `t1` / `t2`：切换 viewtype / compact paths。
- `t3`、`zM`、`zR`：控制 History preview folds。

`P`、`p1..p5`、`pp`、`t0` 仅属于 standalone commits，不得出现在 workspace History。

### SBS pane

- `<C-j>`、`<C-k>`、`gf`、`gF` 和 fold actions 根据 active preview 分发给 Changes 或 History。
- `gs`、`gu`、normal/visual `ghu` 仅在 Changes preview 中执行 workspace mutation。
- `t4` 始终切换 workspace 的 untracked files。
- refresh 同时更新 Changes 与 History。

## 独立 Commits / File History

### 视图布局控制

`P`、`pp` / `t0` 与 `p1`…`p5` 切换布局，按键与布局的对应见[布局设计](layout.md#独立-commitsdiffview_commits)。
这些 bindings 与通用 refresh、commit navigation、fold actions 一起应用于 standalone view 的各个 pane。

### Commits pane

Commits pane 使用与 workspace History 相同的 commit-domain bindings，并额外获得上述 layout controls。

### Filetree pane

- `<CR>`、`<2-LeftMouse>`：选择文件。文件树列出当前 commit 的文件，选中的文件成为当前文件；布局 5 没有 SBS，随之切到
  布局 2（Commits 在左）显示其 diff，`p5` 回到文件树。
- `gf` / `gF`：打开文件。
- `gR`：将文件恢复到当前 commit 版本。
- `t1` / `t2`：切换 viewtype / compact paths。

### SBS pane

- `za` / `zc` / `zo`：切换 / 折叠 / 展开当前 commit item。
- `zC`、`zM`、`zO`、`zR`：控制所有 diff folds。
- `gf` / `gF`：打开当前文件。

## 共享 SBS buffer 契约

SBS buffer 可以跨 Diffview tabs 复用，因此不能持有安装时的 view context：

1. Buffer-local expression mapping 只保存 key、mode 与 context-neutral description。
2. Expression 层根据当前 tabtype 重新解析 workspace 或 standalone commits context。
3. 当前 context 支持该 key 时返回 `<Plug>`，由普通 mapping 在 `textlock` 外执行 action；workspace action 再按
   active preview owner 选择 Changes 或 History。
4. 当前 context 不支持该 key 时直接返回原 lhs，保留 Neovim 原生 count/register 语义；不得静默 no-op。
5. 工作区文件（unstaged preview 右侧）是用户自己的 buffer，不是 Diffview 的 SBS buffer。Buffer-local mapping 对该
   buffer 的所有窗口生效，因此它只在光标位于显示它的 SBS window 时借用上述 mappings：光标离开、preview 换走它或
   session 关闭时收回。该 buffer 自有的同名 buffer-local mapping 保持不变，收回只删除借出的部分。Diffview 之外显示
   同一文件的窗口始终保留用户的 mapping，例如全局 `<C-a>r`、`<C-j>`、`<C-k>`。
