## 布局设计

每种视图支持多种布局，用户可通过 `t0` 循环切换。

### workspace (diffview_workspace)

| 布局 | 描述                    | 结构                                               |
|:-----|:------------------------|:---------------------------------------------------|
| 1    | workspace + sbs（默认） | `staged / unstaged / history (left) │ sbs (right)` |
| 2    | 仅 workspace navigation | `staged / unstaged / history`                      |
| 3    | 仅 sbs                  | `sbs only`                                         |

**布局 1: changes + sbs**

Changes column 的宽度由 workspace-scoped `dot.context.diffview.panel_width` 保存。手动调整会更新该值；
终端整体 resize 不会覆盖用户偏好，重新打开或隐藏后恢复 Changes 时继续使用保存值。

```
┌─────────────┬─────────────────┬─────────────────┐
│󰊢 Staged (N) │   Left (old)    │   Right (new)   │
│ staged tree │                 │                 │
│             │                 │                 │
├─────────────┤                 │                 │
│󰊢 Unstaged(N)│                 │                 │
│unstaged tree│                 │                 │
│             │                 │                 │
├─────────────┤                 │                 │
│   History   │                 │                 │
└─────────────┴─────────────────┴─────────────────┘
    navigation       sbs-left         sbs-right
```

History 默认位于左侧最下方，只显示 1 行 commit content；加上 winline 后，Neovim window height 为 2。
Standalone Commits 仍使用独立的 `COMMITS_HEIGHT`。Staged 与 Unstaged 平分剩余高度，奇数余量交给默认
work queue Unstaged。Terminal height resize 与 sidebar 恢复会重新应用该分配；History 隐藏时两者平分完整
navigation column。三个 panes 共享列宽，但分别持有 buffer 与 domain state。

Staged 与 Unstaged 各自持有 window-owned Nvimbar：左侧显示 `󰊢 Staged (N)` / `󰊢 Unstaged (N)`，右侧使用
通用 `search_count` component。文件树 buffer 只包含 domain rows，不再渲染重复的 section header。空 pane
仍保留一个最小 window row，entry 数量不影响 pane height。

workspace History 的 commit row 直接从 buffer 第一列显示 abbreviated hash，不显示 active-commit sign；pane
只保留 1 个 screen column 作为视觉边距。未过滤 log 按 `hash -> short author -> graph -> message -> date` 渲染，
graph 使用 `○` / `◎` 与 box-drawing pipes；已知 gitmoji shortcode 渲染为 emoji。展开的 file tree root 与 hash
第一个字符位于同一 screen column。directory collapse state 按 commit hash 隔离；compact directory row 保留稳定
collapse identity，并将完整显示路径用于 `oc`。带 path_filter 的 File History 不生成 graph，并保留
expand/collapse chevron。

### commits (diffview_commits)

> 支持 `path_filter` 过滤特定文件/目录的 commit 历史。带 path_filter 时 tabline 会显示过滤的文件名。

| 布局 | Icon | 描述                 | 快捷键 | 结构                                |
|:-----|:-----|:---------------------|:-------|:------------------------------------|
| 1    | 󰯋    | commits 在顶（默认） | `p1`   | `commits (top) ─ sbs (bottom)`      |
| 2    | 󰕭    | commits 在左         | `p2`   | `commits (left) │ sbs (right)`      |
| 3    | 󰯌    | 仅 sbs               | `p3`   | `sbs only`                          |
| 4    | 󰊢    | 仅 commits           | `p4`   | `commits only`                      |
| 5    | 󰙅    | commits + filetree   | `p5`   | `commits (left) │ filetree (right)` |

* 布局 1: commits (top) + sbs (bottom)

  ```
  ┌─────────────────────────────────────────────────┐
  │                 Commit List                     │
  │                  commits                        │
  ├────────────────────────┬────────────────────────┤
  │                        │                        │
  │      Left (old)        │      Right (new)       │
  │       sbs-left         │       sbs-right        │
  │                        │                        │
  └────────────────────────┴────────────────────────┘
  ```

* 布局 2: commits (left) + sbs (right)

  ```
  ┌─────────────┬─────────────────┬─────────────────┐
  │             │                 │                 │
  │   Commit    │   Left (old)    │   Right (new)   │
  │    List     │                 │                 │
  │             │                 │                 │
  │   commits   │    sbs-left     │    sbs-right    │
  │             │                 │                 │
  └─────────────┴─────────────────┴─────────────────┘
  ```

* 布局 3: sbs only

  ```
  ┌────────────────────────┬────────────────────────┐
  │                        │                        │
  │      Left (old)        │      Right (new)       │
  │       sbs-left         │       sbs-right        │
  │                        │                        │
  └────────────────────────┴────────────────────────┘
  ```

* 布局 4: commits only

  ```
  ┌─────────────────────────────────────────────────┐
  │                                                 │
  │                  Commit List                    │
  │                    commits                      │
  │                                                 │
  └─────────────────────────────────────────────────┘
  ```

* 布局 5: commits + filetree

  ```
  ┌────────────────────────┬────────────────────────┐
  │                        │                        │
  │     Commit List        │   Files in Commit      │
  │       commits          │       filetree         │
  │                        │                        │
  └────────────────────────┴────────────────────────┘
  ```

  - 布局 5 中的 filetree 显示当前选中 commit 的变更文件列表。
