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

History 默认位于左侧最下方，`COMMITS_HEIGHT` 是其 preferred minimum。Staged/Unstaged 根据各自实际
rendered line count 自动收缩：empty pane 只保留 header，non-empty pane 优先保证 header 与一个 item；空余
高度交给 History。内容超出可用高度时，在满足 Changes visibility floor 后尽量保留 History minimum，再优先
完整显示较小的 Changes pane，其余空间由较大 pane 使用并允许滚动。Terminal height resize 会重新应用该
分配。History 可以独立隐藏或恢复；隐藏 Changes 时仍作为左侧 navigation panel。三个 panes 共享列宽，但
分别持有 buffer 与 domain state。

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
