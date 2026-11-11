# 文件结果共享 Surface

Status: Design。定义 Result/Preview 的窗口、发布与生命周期，以及 Picker 按键与查询的同步；节点语义以 [Treeview](../ux/treeview/README.md) 为准。

## 共享范围

Picker、Searcher 与 Git Files 共享两类 UI surface：

1. `Result`：结果窗口、native View 接入、派生行号、current/present signs 与 winbar。
2. `Preview`：preview buffer/window lifecycle、debounced draw 与 window options。

Feature 保留 Finder 输入、pane composition、search/replace 与业务 action。
所有结果使用 [native Treeview 接入契约](results.md)，selection/expansion/行映射归 native State。

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
  `era.m.picker.Result` / `era.m.searcher.Result` 等公开入口。

## `Result` 契约

共享层负责：

- result window 与初始空 scratch buffer 的创建；attach 后 buffer 所有权交给 native View；
- focus、hide/suspend、resize、dispose 的协调；
- 派生的 `lnum_current`、`lnum_present`、`lnum_total`，不作为节点定位的权威数据；
- current/present signs 与对应 scheduler；多项 selection 使用 viewport decoration；
- Result 内容刷新调度；buffer 正文与 viewport decorations 由 native View 独占；
- `draw_now()`：跳过调度立即绘制，返回发布完成后 resolve 的 Future，供需要读取最新结果的动作使用；
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
  标题与位置计数的布局见 [Git Files 布局](git-files.md#布局)。

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
   [结果集生命周期](results.md#生命周期)。Buffer 失效时正常重建；dispose 释放隐藏的资源。
3. `dispose` 只执行一次，并释放 window、buffer、observable、autocmd、nvimbar、scheduler 与 registered flag callbacks。
4. queued observable/scheduler callback 在 dispose 后不得读取已释放字段或写入 buffer/window。
5. draw 或 callback failure 只报告，不得留下 `modifiable/readonly` 错误状态。
6. reporter `from` 使用调用方的 feature identity。

## Feature 自有边界

### Git Files

Git Files 自有单行 inputbox、左栏双树 / 右栏整高 preview 布局、Git snapshot 刷新、文件级 stage / unstage 和异步 diff 内容读取。
Result / Preview 仅负责窗口与展示生命周期；完整业务契约见 [Git Files](git-files.md)。

### Finder 与 BasicComposer

Finder 与 BasicComposer 保持 feature-owned，不提取共同基类：统一 Finder 需要 content codec、prompt 与 title policy，
统一 BasicComposer 则要让 Searcher 的 replacer 状态参与 pane validity/focus restoration、动态 layout/border 与 keymap flow。

- Picker 是 single-line 输入；多行变更会归一化为空格分隔的单行内容。
- Searcher 保留 multiline 内容，并拥有 custom prompt sign、rich title accent、replacer pane 与 replace history。

## Picker 按键与查询同步

Picker 的三个 composer（ListComposer、FiletreeComposer、TreeComposer）的查询都经 64 ms debounce 匹配。读取或移动
结果行的按键（确认、打开、Finder 中的导航键、selection 切换等）以按键时的查询为准，快于 debounce 的输入（如 Find Files
中输入文件名后立即回车、确认框中输入 `No` 后立即回车）不会作用于屏幕上的旧结果：

1. 按键先把 Finder buffer 的内容同步到查询。typeahead 未处理完时 `TextChangedI` 不会触发，查询的通知也要到下一个
   tick 才到达匹配调度。
2. 匹配尚未覆盖当前查询时，取消 debounce 立即匹配，用 `Result:draw_now()` 发布，并在按键内原地等待发布完成（超时
   1 s，在事件之间检查），再按光标行取结果。动作不推迟到之后执行，因为它会恢复 picker 打开前的模式。
3. 动作因 selection 或折叠变更尚未生效而推迟时，之后只重新检查这些变更，不再同步查询；按键之后输入的字符只经正常的
   debounce 匹配，不会提前用于这个动作。
4. ListComposer 分批 `append` 期间不补做匹配，动作按当前显示的行执行：等待会持续到整个准备结束。FiletreeComposer
   从 `prepare_filepaths` 开始到它接入的路径树发布之前，按键在按键内原地等待路径发布（`Result:draw_now()` 接在加载
   之后，最长 10 s，在事件之间检查，Ctrl-C 可中断），再按第 1、2 步处理查询；等待的是剩余的加载与发布时间，之后
   输入的字符留在 typeahead 中，不影响这次动作。超时或中断后按当前显示的行执行。`reset_filepaths` 等其他数据变更
   规模小，照常补做匹配并等待发布。

## 复杂度与性能

- 共享层不持有 tree node、search match 或 file data，不新增与结果规模相关的状态。
- Result 通过 native Frame 发布，普通 List 的 custom presentation 不直接写 buffer。
- Surface 保留实例状态和有界 viewport 缓存；按结果规模增长的 records/metadata 由 ResultTree producer 管理。
- Cursor、selection 与 expansion 更新不得重新导入业务 records；相同 display 请求复用已解析的 filter。
