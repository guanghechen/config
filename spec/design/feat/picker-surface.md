# Picker / Searcher 共享 Surface

## 目标

Picker 与 Searcher 只共享已经形成稳定同构实现的 UI surface：

1. `Result`：result buffer/window lifecycle、line observables、sign scheduler 与 winbar。
2. `Preview`：preview buffer/window lifecycle、debounced draw 与 window options。

Feature 保留 Finder 输入语义、pane composition、search/replace 输入和所有业务 action。
树状结果使用 [native Treeview 接入契约](../../../doc/spec/treeview/results.md)，selection/expansion 归 native State。

## 依赖方向

```text
era.m.picker  ─┐
               ├─> era.view.picker.{result,preview} ─> era.m.nvimbar / dot / stl
era.m.searcher ─┘
```

- 共享 surface 不依赖 `era.m.picker` 或 `era.m.searcher`。
- Picker 与 Searcher 不互相依赖。
- `era.m.nvimbar` 不依赖共享 surface，依赖图保持无环。
- Feature namespace 通过 module map 与 LuaDoc alias 保留
  `era.m.picker.Result` / `era.m.searcher.Result` 等公开入口，不保留 runtime adapter。

## `Result` 契约

共享层拥有：

- result buffer/window 的 create、focus、hide、resize、dispose；
- `lnum_current`、`lnum_present`、`lnum_total`；
- current/present/selected signs 与对应 scheduler；
- Result 内容刷新调度；树状结果的 buffer 正文与 viewport decorations 由 native View 独占；
- flags、position 与可选 status 的 winbar 渲染。

Feature 通过 props 提供：

- `draw`、`isselected`、`on_drawed`；树状结果额外提供 `era.view.ResultTree`；
- keymaps 与 flags；
- `augroup_prefix`、`diagnostic_scope` 与 `winline_hl`；
- 可选 status snapshot。

差异映射：

- Picker：`winline_hl = "f_wl_picker"`，无 status。
- Searcher：`winline_hl = "f_wl_searcher"`，可提供 status。

共享层通过 ResultTree 的 mount/publish 接入 native surface，不解释节点、query 或业务 metadata。
Native 模式跳过全 buffer 的 selected-sign 扫描，行数和 cursor observables 只在 frame 发布后更新。

## `Preview` 契约

共享层拥有：

- preview buffer/window 的 create、focus、hide、resize、dispose；
- Draw 的 debounce 调度；
- Draw 失败报告；
- title、cursor、number、wrap、whitespace 等 window options。

Feature 通过 props 提供 `draw`、`on_drawed`、keymaps、`diagnostic_scope` 与 relative-number policy：

- Picker：relative number 跟随 `result.number`。
- Searcher：relative number 始终关闭。

普通文件 preview 使用 draw。目录 preview 使用 ResultTree 的独立 native State；切回文件时先替换 buffer，再 detach 旧 View，保持浮窗存活。
异步 subtree 准备以 preview epoch 校验，关闭或换目标后不得安装旧 View。

## 生命周期不变式

1. `create_buf/create_win` 幂等，返回既有 resource 时不重复绑定。
2. `hide` 保留 scheduler、逻辑 State 和 reusable buffer；native View suspend 后保留已发布 Frame，重开重新绑定窗口，
   并提交最新 producer/display 请求。Buffer 失效时正常重建；dispose 释放隐藏的资源。
3. `dispose` 只执行一次，并释放 window、buffer、observable、autocmd、nvimbar、scheduler 与 registered flag callbacks。
4. queued observable/scheduler callback 在 dispose 后不得读取已释放字段或写入 buffer/window。
5. draw 或 callback failure 只报告，不得留下 `modifiable/readonly` 错误状态。
6. reporter `from` 保持迁移前的 feature identity。

## Feature 自有边界

### Finder

Finder 保持 feature-owned，不提取共同基类或共享 superset。

- Picker 是 single-line 输入；多行变更会归一化为空格分隔的单行内容。
- Searcher 保留 multiline 内容，并拥有 custom prompt sign 与 rich title accent。
- 两者的 `set_content` 状态写入时序不同；统一实现需要 content codec、prompt 与 title policy。
- 强行共享会将上述差异转换为 optional branches/hooks，增加理解成本。

### BasicComposer

BasicComposer 保持 feature-owned，不建立共同基类。

- Searcher 额外拥有 replacer pane、replace-mode observable/unsubscribe lifecycle 与 replace history。
- pane validity/focus restoration、动态 layout/border 和 keymap flow 都由 replacer 状态参与决定。
- 这些差异尚未形成范围明确、稳定的共享 composer 契约。

## 复杂度与性能

- 共享层不持有 tree node、search match 或 file data，不新增与结果规模相关的状态。
- `Result`/`Preview` 的 create、focus、hide、resize、dispose 和 schedule 操作保持原有渐进复杂度；
  普通列表由 `draw` 写入内容；树状结果通过 native Frame 发布。
- policy 只增加固定大小的 instance state；不得引入按 node/result 复制的数据或额外 observer。
- Cursor、selection 与 expansion 更新不得重新导入业务 records；相同 display 请求复用已解析的 filter。

## 验收标准

- Picker/Searcher 的 keymap、window type、filetype、sign、cursor、empty-result 与 error behavior 不变。
- Result/Preview 的 feature-owned callback 输入输出 contract 不变。
- 不新增 Picker ↔ Searcher 依赖，不改变 Tree/Treeview。
- 只保留一套 Result 与一套 Preview 行为实现；feature alias 仅保留类型与公开入口。
- shared contract tests 覆盖两侧 alias、Result policy、Preview number policy、draw failure、
  changed/stable cursor scheduling 与 dispose 后 queued callback。
- 全量测试、LuaLS Error-level、formatting 与 dependency checks 通过。
- 使用当前实现与迁移前配置基线完成 5,000+ 节点 E2E，记录运行环境、常用操作时间与稳态空间对比。
