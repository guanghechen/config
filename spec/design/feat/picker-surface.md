# 文件结果共享 Surface

Status: Design。定义 Result/Preview 的窗口、发布与生命周期；节点语义以 [Treeview](../treeview/README.md) 为准。

## 共享范围

Picker、Searcher 与 Git Files 共享两类 UI surface：

1. `Result`：结果窗口、native View 接入、派生行号、current/present signs 与 winbar。
2. `Preview`：preview buffer/window lifecycle、debounced draw 与 window options。

Feature 保留 Finder 输入、pane composition、search/replace 与业务 action。
所有结果使用 [native Treeview 接入契约](../treeview/results.md)，selection/expansion/行映射归 native State。

## 依赖方向

```text
era.m.picker    ─┐
era.m.searcher  ─┼─> era.view.picker.{result,preview} ─> era.m.nvimbar / dot / stl
era.m.git_files ─┘
```

- 共享 surface 不依赖 `era.m.picker`、`era.m.searcher` 或 `era.m.git_files`。
- Picker 与 Searcher 不互相依赖。
- `era.m.nvimbar` 不依赖共享 surface，依赖图保持无环。
- Feature namespace 通过 module map 与 LuaDoc alias 保留
  `era.m.picker.Result` / `era.m.searcher.Result` 等公开入口，不保留 runtime adapter。

## `Result` 契约

共享层负责：

- result window 与初始空 scratch buffer 的创建；attach 后 buffer 所有权交给 native View；
- focus、hide/suspend、resize、dispose 的协调；
- 派生的 `lnum_current`、`lnum_present`、`lnum_total`，不作为节点定位的权威数据；
- current/present signs 与对应 scheduler；多项 selection 使用 viewport decoration；
- Result 内容刷新调度；buffer 正文与 viewport decorations 由 native View 独占；
- flags、position 与可选 status 的 winbar 渲染。

Feature 通过 props 提供：

- `draw`、`on_drawed`，以及 `era.view.ResultTree` 或真实 Filetree 的 `era.view.Directory` owner；
- keymaps 与 flags；
- `augroup_prefix`、`diagnostic_scope` 与 `winline_hl`；
- 可选 status snapshot；`winbar = false` 不创建 winbar renderer，保留行号 observables，`mark_nvimbar_dirty()` 此时无操作。

差异映射：

- Picker：`winline_hl = "f_wl_picker"`，无 status。
- Searcher：`winline_hl = "f_wl_searcher"`，可提供 status。
- Git Files：两个 Result 各自绑定一棵固定 stage scope 的树，禁用 winbar；feature 订阅行号 observables，
  在 border 右侧显示 position，左侧显示标题、统计及刷新 / index 操作状态，query 保留在 inputbox。

共享层通过 ResultTree 的 mount/publish 接入 native surface，不解释节点、query 或业务 metadata。
行数和 cursor observables 在 Frame 发布后更新，不扫描全 buffer 放置 selected signs。

## `Preview` 契约

共享层拥有：

- preview buffer/window 的 create、focus、hide、resize、dispose；
- Draw 的 debounce 调度；
- Draw 失败报告；
- title、cursor、number、wrap、whitespace 等 window options。

Feature 通过 props 提供 `draw`、`on_drawed`、keymaps、`diagnostic_scope` 与 relative-number policy：

- Picker：relative number 跟随 `result.number`。
- Searcher：relative number 始终关闭。

Draw 只有在绘制了目标范围时才返回 `has_range = true`，启用范围专用的 cursorline 背景；普通文件、目录
和无范围结果使用主题的常规 `CursorLine`。结果切换及窗口重开都按最近一次 Draw 的范围状态选择样式。

普通文件 preview 使用 draw。目录 preview 使用 owner 的独立 native State；切回文件时先替换 buffer，再 detach 旧 View，保持浮窗存活。
异步 subtree 准备以 preview epoch 校验，关闭或换目标后不得安装旧 View。

## 生命周期不变式

1. `create_buf/create_win` 幂等，返回既有 resource 时不重复绑定。
2. `hide` 保留 scheduler、逻辑 State 和 reusable buffer；native View 的 suspend 与重开遵循
   [结果集生命周期](../treeview/results.md#生命周期)。Buffer 失效时正常重建；dispose 释放隐藏的资源。
3. `dispose` 只执行一次，并释放 window、buffer、observable、autocmd、nvimbar、scheduler 与 registered flag callbacks。
4. queued observable/scheduler callback 在 dispose 后不得读取已释放字段或写入 buffer/window。
5. draw 或 callback failure 只报告，不得留下 `modifiable/readonly` 错误状态。
6. reporter `from` 使用调用方的 feature identity。

## Feature 自有边界

### Git Files

Git Files 自有单行 inputbox、左栏双树 / 右栏整高 preview 布局、Git snapshot 刷新、文件级 stage / unstage 和异步 diff 内容读取。
Result / Preview 仅负责窗口与展示生命周期；完整业务契约见 [Git Files](git-files.md)。

### Finder

Finder 保持 feature-owned，不提取共同基类或共享 superset。

- Picker 是 single-line 输入；多行变更会归一化为空格分隔的单行内容。
- Searcher 保留 multiline 内容，并拥有 custom prompt sign 与 rich title accent。
- 两者的 `set_content` 状态写入时序不同；统一实现需要 content codec、prompt 与 title policy。

### BasicComposer

BasicComposer 保持 feature-owned，不建立共同基类。

- Searcher 额外拥有 replacer pane、replace-mode observable/unsubscribe lifecycle 与 replace history。
- pane validity/focus restoration、动态 layout/border 和 keymap flow 都由 replacer 状态参与决定。
- Result/Preview 接入相同的 owner contract，composer 的业务生命周期各自管理。

## 复杂度与性能

- 共享层不持有 tree node、search match 或 file data，不新增与结果规模相关的状态。
- Result 通过 native Frame 发布，普通 List 的 custom presentation 不直接写 buffer。
- Surface 保留实例状态和有界 viewport 缓存；按结果规模增长的 records/metadata 由 ResultTree producer 管理。
- Cursor、selection 与 expansion 更新不得重新导入业务 records；相同 display 请求复用已解析的 filter。
