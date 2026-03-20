## 布局设计

每种视图支持多种布局，用户可通过 `t0` 循环切换。

### workspace (diffview_workspace)

| 布局 | 描述                       | 结构                                |
|:-----|:---------------------------|:------------------------------------|
| 1    | changes + sbs（默认）      | `changes (left) │ sbs (right)`      |
| 2    | 仅 changes                 | `changes only`                      |
| 3    | 仅 sbs                     | `sbs only`                          |

**布局 1: changes + sbs**
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
└─────────────┴─────────────────┴─────────────────┘
     changes        sbs-left         sbs-right
```

### commits (diffview_commits)

> 支持 `path_filter` 过滤特定文件/目录的 commit 历史。带 path_filter 时 tabline 会显示过滤的文件名。

| 布局 | Icon | 描述                       | 快捷键 | 结构                                |
|:-----|:-----|:---------------------------|:-------|:------------------------------------|
| 1    | 󰯋   | commits 在顶（默认）        | `p1`   | `commits (top) ─ sbs (bottom)`      |
| 2    | 󰕭   | commits 在左                | `p2`   | `commits (left) │ sbs (right)`      |
| 3    | 󰯌   | 仅 sbs                      | `p3`   | `sbs only`                          |
| 4    | 󰊢   | 仅 commits                  | `p4`   | `commits only`                      |
| 5    | 󰙅   | commits + filetree          | `p5`   | `commits (left) │ filetree (right)` |

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

