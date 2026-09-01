## Diffview Commits View

> 支持 `path_filter` 过滤特定文件/目录的 commit 历史。带 path_filter 时功能相当于 File History。

### Cross Pane (works for all panes in the diffview-commits view)

- `<C-a>r` : Refresh (aliases: `<D-r>`, `<M-r>`) the whole diffview-commits view
- `<C-j>` : Next commit, set the next commit (based from the last active commit) as active
- `<C-k>` : Prev commit, set the prev commit (based from the last active commit) as active
- `<leader>er` : Reveal the active commit/file in the Commits pane, or hide the pane when already focused
- `P` : Previous layout
- `p1` : Layout 1: 󰯋 commits top + sbs
- `p2` : Layout 2: 󰕭 commits left + sbs
- `p3` : Layout 3: 󰯌 sbs only
- `p4` : Layout 4: 󰊢 commits only
- `p5` : Layout 5: 󰙅 commits + filetree
- `pp` : Next layout
- `zM` : Close all diff folds in the current view
- `zR` : Open all diff folds in the current view
- `t3` : Toggle the default diff fold policy and apply it to the current view

### Commits Pane

- `<2-LeftMouse>` : Select / Toggle expand
- `<CR>` : Select / Toggle expand
- `<Tab>` : Set as active commit
- `K` : Show commit details
- `[[` : Previous page
- `]]` : Next page
- `g?` : Show keymap sheet of the commits pane (include shared cross pane keybindings)
- `gF` : Open file in new tab
- `gH` : Collapse all commits
- `gK` : Show commit details
- `gL` : Expand all commits
- `gR` : Restore file to commit version
- `gf` : Open file in previous tab
- `gh` : Collapse commit
- `gl` : Expand commit
- `t0` : Cycle layout (5 types)
- `t1` : Toggle viewtype (tree/list)
- `t2` : Toggle compact directory paths
- `yy` : Yank commit hash

### Filetree Pane

- `<2-LeftMouse>` : Select file
- `<CR>` : Select file
- `g?` : Show keymap sheet of the filetree pane (include shared cross pane keybindings)
- `gF` : Open file in new tab
- `gR` : Restore file to commit version
- `gf` : Open file in previous tab
- `t1` : Toggle viewtype (tree/list)
- `t2` : Toggle compact directory paths

### SBS Pane

- `g?` : Show keymap sheet of the sbs pane (include shared cross pane keybindings)
- `gF` : Open file in new tab
- `gf` : Open file in previous tab
- `zC` : Close all diff folds in the current view (`zM` alias)
- `zO` : Open all diff folds in the current view (`zR` alias)
- `za` : Toggle expand commit
- `zc` : Collapse commit
- `zo` : Expand commit
