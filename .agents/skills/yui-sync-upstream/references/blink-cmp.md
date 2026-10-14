# blink.cmp

## 镜像取材

- 分支：[nvim@blink.cmp](https://github.com/guanghechen/mirror/tree/nvim%40blink.cmp)。
- 完整 ref：`refs/heads/nvim@blink.cmp`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`saghen/blink.cmp`，从 `lua/blink/cmp/` 内按实际机制查找实现与测试。
- 本地：[lua/era/keystroke/cmp/](../../../../lua/era/keystroke/cmp/)；明确借用来源的是 `repeat.lua` 的 scratch-completion 技术，许可位于 `LICENSE.blink`。
- 参考基线：未记录该技术对应的固定 upstream commit。仓库比较工具中的 baseline 与源码来源 revision 是不同概念。
- 本地契约：[Completion](../../../../spec/design/feat/cmp.md)；比较入口见 [cmp-comparison](../../../../spec/debug/cmp-comparison.md)。
- 关系：本地补全是独立实现。Lua 管 editor/session，Rust 管 ranking；原生 Neovim 管 PUM 和 preview。

## 如何更新

1. 根据用户指定的问题查看上游 repeat/undo、snippet、LSP lifecycle 或匹配相关改动，固定对应 SHA 与触发用例。
2. 将上游改动映射到本地实际 owner；例如 scratch-completion 改动对应 `repeat.lua`，并关联 session 的 preview/restore/accept 流程。
3. 保留本地 source policy、Rust ranking、原生 PUM、宽 LSP edit、UTF-8 byte range 与取消/迟到结果的所有权约束。
4. 按本地契约判断功能差异；上游 API 或默认交互不直接替代本地实现，也不因更新参考库而重新启用 Blink runtime。
5. 移植许可覆盖的实现时保留 `LICENSE.blink` 与来源注释；记录实际采纳的机制，而非宣称整个 Blink 已同步。

## 验证

```sh
nvim -l __test__/run.lua era/keystroke/cmp/
```

按改动覆盖接受/取消、输入排队、resolve、snippet、undo/dot-repeat、Unicode 和真实 UI。
算法或性能比较按已有 comparison/benchmark 文档执行；修改 Rust 时运行仓库规定的 Rust checks。
