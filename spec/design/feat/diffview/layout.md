# Diffview 布局

Workspace 与 standalone commits 分别管理布局；快捷键适用范围见[快捷键契约](keybinding.md)。

## Workspace：`diffview_workspace`

| 布局 | 内容                    | 结构                                               |
| ---- | ----------------------- | -------------------------------------------------- |
| 1    | Workspace + SBS，默认   | `staged / unstaged / history (left) │ sbs (right)` |
| 2    | 仅 Workspace navigation | `staged / unstaged / history`                      |
| 3    | 仅 SBS                  | `sbs only`                                         |

默认布局：

```text
┌──────────────┬─────────────────┬─────────────────┐
│ Staged (N)   │ Left (old)      │ Right (new)     │
│ staged tree  │                 │                 │
├──────────────┤                 │                 │
│ Unstaged (N) │                 │                 │
│unstaged tree │                 │                 │
├──────────────┤                 │                 │
│ History      │                 │                 │
└──────────────┴─────────────────┴─────────────────┘
   navigation       sbs-left          sbs-right
```

### 尺寸与窗口归属

- Sidebar 宽度保存在 workspace-scoped `dot.context.diffview.panel_width`。手动调整更新该值；
  terminal resize 不覆盖偏好，重新打开或恢复 sidebar 时复用保存值。
- History 默认位于左侧底部，显示 1 行 commit content，加上 winline 后 window height 为 2。
  Standalone Commits 使用独立的 `COMMITS_HEIGHT`。
- Staged 与 Unstaged 平分剩余高度，奇数余量分给默认 work queue Unstaged。Terminal height resize
  和 sidebar 恢复时重新分配；History 隐藏后，两者平分整列高度。
- 三个 panes 共用列宽，分别持有 buffer 与 domain state。空 pane 至少保留一个 window row，entry 数不决定 pane height。

### Winline 与列表

Staged、Unstaged 各自持有 window-owned Nvimbar，左侧显示 `󰊢 Staged (N)` / `󰊢 Unstaged (N)`，
右侧复用 `search_count`。文件树 buffer 只包含 domain rows，不重复渲染 section header。

History commit row 从 buffer 第一列显示 abbreviated hash，不显示 active-commit sign，pane 仅留
一个 screen column 的视觉边距。未过滤 log 按 `hash -> short author -> graph -> message -> date` 渲染：

- Graph 使用 `○` / `◎` 与 box-drawing pipes；已知 gitmoji shortcode 转为 emoji。
- 展开的 filetree root 与 hash 首字符对齐。
- Directory collapse state 按 commit hash 隔离。Compact directory row 保留稳定 collapse identity，
  并将完整显示路径用于 `oc`。
- 带 `path_filter` 的 File History 不生成 graph，保留 expand/collapse chevron。

## 独立 Commits：`diffview_commits`

`path_filter` 可筛选文件或目录历史；设置后 tabline 显示过滤文件名。
`pp` / `t0` 循环切换布局，`P` 返回上一个布局，`p1`…`p5` 直接选择：

| 布局    | Icon | 按键 | 结构                        |
| ------- | ---- | ---- | --------------------------- |
| 1，默认 | 󰯋    | `p1` | Commits 在上，SBS 在下      |
| 2       | 󰕭    | `p2` | Commits 在左，SBS 在右      |
| 3       | 󰯌    | `p3` | 仅 SBS                      |
| 4       | 󰊢    | `p4` | 仅 Commits                  |
| 5       | 󰙅    | `p5` | Commits 在左，Filetree 在右 |

默认布局：

```text
┌─────────────────────────────────────────────────┐
│                   Commit List                   │
│                     commits                     │
├────────────────────────┬────────────────────────┤
│ Left (old)             │ Right (new)            │
│ sbs-left               │ sbs-right              │
└────────────────────────┴────────────────────────┘
```

布局 2 将 Commit List 放在左列，SBS 仍左右并排。布局 5 的 Filetree 显示当前选中 commit 的变更文件。
状态归属与资源清理见 [Diffview 设计](main.md)。
