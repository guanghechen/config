# 设计文档索引

`spec/design/` 保存已定稿设计，目录按代码分层组织：`stl/`、`dot/`、`ux/`、`yoz/` 对应同名层，`feat/` 为 era 层
feature。多文档主题使用独立子目录与 `README.md`，例如 [Treeview](ux/treeview/README.md)。
整体分层见[架构](../ARCHITECTURE.md)，代码约定见[代码风格](../CODESTYLE.md)。

## stl

- [stl.os](stl/os.md)：canonical filepath 与系统调用边界。
- [Signal Hub](stl/signal-hub.md)：进程内消息、身份、路由与清理。

## dot

- [Window 类型](dot/win.md)：窗口身份与属性集合。
- [Tab 类型](dot/tab.md)：tab 类型与命令适用范围。
- [Context](dot/context.md)：editor 与 workspace 状态的持久化，以及多实例保存合并。

## ux

- [Treeview](ux/treeview/README.md)：native Data/State/Frame、标记算法、任务、投影、渲染、View 与 Visual；
  接入步骤见 [Treeview 接入](ux/treeview/integration.md)。
- [Filetree](ux/filetree/README.md)：filesystem identity、加载、watch 与 annotations；文件操作见
  [Filetree 文件 Job](ux/filetree/jobs.md)。

## yoz

- [Yoz Fuzzy](yoz/fuzzy.md)：fzf 语法与打分、native corpus、排序与收窄。
- [Yoz Search](yoz/search.md)：匹配与替换语义、native job、取消与 match limit。

## feat

文件、搜索与 Git：

- [Explorer](feat/explorer/README.md)：Filetree/Treeview 接入、selection 用途、文件操作与编辑器生命周期；picker 内的
  目录浏览见 [Find Explorer](feat/explorer/find.md)。
- [Result 接入](feat/results.md)：List、Picker、Searcher、LSP 与 Diffview 的 ResultTree records、发布与范围动作。
- [Picker / Searcher Surface](feat/picker-surface.md)：共享 Result、Preview、feature 边界与按键时的查询同步。
- [Searcher 请求控制](feat/searcher.md)：请求新鲜度、polling 与清理、match limit 展示与发布性能边界。
- [原生搜索反馈](feat/search-feedback.md)：`/`、`?`、`n`、`N` 的 winline 状态。
- [Git](feat/git.md)：status、watcher、hunk、staging、blame 与 ignore cache。
- [Git Files](feat/git-files.md)：未提交文件的 Staged / Unstaged 双树、stage 与 diff preview。
- [Diffview](feat/diffview/README.md)：workspace 与 commits 的状态和交互；另见[布局](feat/diffview/layout.md)与[快捷键](feat/diffview/keybinding.md)。

编辑与窗口：

- [Completion](feat/cmp.md)：sources、session、preview、LSP 编辑与原生 matcher。
- [Textobject](feat/textobject.md)：对象选择、边界跳转与参数交换。
- [Surrounds](feat/surrounds.md)：surround 动作、buffer 准入与映射归属。
- [输入法切换](feat/im.md)：input source 捕获、恢复与平台行为。
- [Maximize](feat/maximize.md)：普通窗口投影与浮窗最大化。
- [Nvimbar](feat/nvimbar.md)：组件取数、状态提交、通知、布局与 tabline 注册。
- [Winline LSP 面包屑](feat/lsp-symbols.md)：documentSymbol 请求合并、新鲜度契约与超大文档节奏。
- [Notepad](feat/notepad.md)：source、storage engine、便签编辑与导航。
- [Terminal](feat/term.md)：terminal state、job 生命周期与 termline。

集成：

- [AI Widget](feat/ai.md)：agent/source、prompt、消息发送与 tmux session。
- [Image](feat/image.md)：图像模块依赖、状态归属、buffer 生命周期、标识与解析、版本缓存与转换限制。
- [Plugin 管理](feat/plugin.md)：lazy load、版本同步、操作与计时。
- [nvim-lint](feat/nvim-lint.md)：buffer 归属、被动请求 gating 与显式调度。

## 测试

- [测试架构与执行](test-harness.md)：目录与布局、依赖、执行与失败契约、harness、资源生命周期与时序。
- [测试指南](../../__test__/README.md)：可执行命令与示例。

## 文档约定

- 以中文描述职责、行为、约束与取舍；代码、API、标识符、路径和技术术语保留英文。
- 同一契约只在所属文档定义，其他文档使用链接引用。
- Design 不记录变更历史、测量日志、代码或类型副本、文件清单与验证步骤；测量方法与结果放在 `__test__/bench/`。
- 未定稿提案放在 `spec/draft/`，定稿后移入 `spec/design/`。
  阶段目标与执行步骤放在 `spec/plan/`（按需创建），由它们引用设计。
