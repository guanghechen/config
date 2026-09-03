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
│             │                 │                 │
│   Staged    │   Left (old)    │   Right (new)   │
│   Changes   │                 │                 │
│             │                 │                 │
├─────────────┤                 │                 │
│             │                 │                 │
│  Unstaged   │                 │                 │
│   Changes   │                 │                 │
│             │                 │                 │
├─────────────┤                 │                 │
│   History   │                 │                 │
└─────────────┴─────────────────┴─────────────────┘
    navigation       sbs-left         sbs-right
```

History 默认位于左侧最下方，target height 是 navigation column 的 `1/4`，最低 3 行；standalone Commits
仍使用独立的 `COMMITS_HEIGHT`。Staged/Unstaged 根据各自 rendered line count 分配剩余高度：优先完整显示
较小的 pane，其余空间由较大的 pane 使用并允许滚动；需求相同时平均分配。Terminal height resize 会重新
应用该分配。History 可以独立隐藏或恢复；隐藏 Changes 时仍作为左侧 navigation panel。三个 panes 共享列宽，
但分别持有 buffer 与 domain state。

workspace History 的 commit row 直接从 buffer 第一列显示 abbreviated hash，不显示 expand/collapse chevron
或 active-commit sign；pane 只保留 1 个 screen column 作为视觉边距。展开的 file tree root 与 hash 第一个字符
位于同一 screen column；展开状态由其下方是否存在 file rows 表达。Standalone Commits 保留原有 chevron 与 sign。

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
