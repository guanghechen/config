# 设计文档索引

`spec/design/` 是已定稿设计的唯一来源，本文按职责提供导航。
整体分层见[架构](../ARCHITECTURE.md)，代码约定见[代码风格](../CODESTYLE.md)。

## 基础能力与状态

- [Window 类型](win.md)：窗口身份与属性集合。
- [Tab 类型与 Tabline](tab.md)：命令适用范围、tab 类型与 tabline 注册。
- [Nvimbar](nvimbar.md)：组件取数、状态提交、通知与布局。
- [Signal Hub](signal-hub.md)：进程内消息、身份、路由与清理。
- [stl.os](stl/os.md)：canonical filepath 与系统调用边界。
- [Tree / Treeview](stl/view/treeview.md)：树结构、可见布局与复杂度契约。

## 文件、搜索与 Git

- [Explorer](feat/explorer.md)：文件树、selection、transfer 与文件操作。
- [Find Explorer](feat/find/explorer.md)：picker 内的目录浏览与单项文件操作。
- [Picker / Searcher Surface](feat/picker-surface.md)：共享 Result、Preview 及 feature 边界。
- [Yoz Search](feat/yoz/search.md)：native job、取消、结果完整性与性能边界。
- [原生搜索反馈](feat/ux/search.md)：`/`、`?`、`n`、`N` 的 winline 状态。
- [Git](feat/git.md)：status、watcher、hunk、staging、blame 与 ignore cache。
- [Diffview](feat/diffview/main.md)：workspace 与 commits 的状态和交互；另见[布局](feat/diffview/layout.md)与[快捷键](feat/diffview/keybinding.md)。

## 编辑与窗口交互

- [Textobject](feat/textobject.md)：对象选择、边界跳转与参数交换。
- [Surrounds](feat/surrounds.md)：surround 动作、buffer 准入与映射归属。
- [输入法切换](feat/im.md)：input source 捕获、恢复与平台行为。
- [Maximize](feat/maximize.md)：普通窗口投影与浮窗最大化。
- [Notepad](feat/notepad.md)：source、storage engine、便签编辑与导航。
- [Terminal](feat/term.md)：terminal state、job 生命周期与 termline。
- [Act Board](feat/ux/board-act.md)：输入与实时预览组件。

## 集成

- [AI Widget](feat/ai.md)：agent/source、prompt、消息发送与 tmux session。
- [Image](feat/image.md)：图像模块依赖与状态归属。
- [Plugin 管理](feat/plugin.md)：lazy load、版本同步、操作与计时。
- [nvim-lint](nvim-lint-buffer-ownership.md)：buffer 归属、被动请求 gating 与显式调度。

## 测试

- [测试架构](test-harness/arch.md)：目录、依赖、harness 与资源归属。
- [测试执行流程](test-harness/flow.md)：CLI、suite 进程、cleanup 与失败契约。
- [测试指南](../../__test__/README.md)：可执行命令与示例。

## 文档约定

- 以中文描述职责、行为、约束与取舍；代码、API、标识符、路径和技术术语保留英文。
- 同一契约只在所属文档定义，其他文档使用链接引用。历史验证注明环境与适用范围。
- 未定稿提案放在 `spec/draft/`；阶段目标与执行步骤放在 `spec/roadmap/`、`spec/plan/`，由它们引用设计。
