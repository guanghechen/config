# nvim-lint

## 镜像取材

- 分支：[nvim@nvim-lint](https://github.com/guanghechen/mirror/tree/nvim%40nvim-lint)。
- 完整 ref：`refs/heads/nvim@nvim-lint`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`mfussenegger/nvim-lint`，主要核对 `lua/lint.lua` 与所用 linter definitions。
- 本地：[lua/era/plugin/nvim-lint.lua](../../../../lua/era/plugin/nvim-lint.lua)。
- 本地契约：[Buffer 归属与调度](../../../../spec/design/nvim-lint-buffer-ownership.md)。
- 历史接口审计参考：`a219b2c9e5b4765e5c845aba119dad55806fcaf1`；它不是当前安装版本声明，实际 plugin revision 须从当前插件管理状态核实。
- 关系：上游 API 的本地适配层，依赖 `_resolve_linter_by_ft`、`linters` 与 `try_lint()` 的具体语义。

## 如何更新

1. 固定实际安装版本和目标 SHA，核对上述 API、复合 filetype 解析、condition、process owner 和 diagnostics target 的变化。
2. 保留 pending/deferred buffer sets、真实可见性判断、显式请求准入和 `nvim_buf_call()` 的目标 buffer context。
3. 核实 setup/重配置的 timer、subscription 与队列清理，保持单个 dispatch 失败不影响同批其他 buffer。
4. 上游若改变 buffer ownership API，按本地最终契约调整 adapter；更新上游插件和修改调度策略是不同的变更，分别说明影响。
5. 沿用当前 linters、排除规则、cspell 参数与本地配置目标；记录验证过的 API 假设和目标 SHA，实际包更新遵循已有授权。

## 验证

```sh
nvim -l __test__/run.lua __test__/specs/era/plugin/nvim-lint_spec.lua
```

覆盖同一 debounce window 的多个 buffer、隐藏被动加载、隐藏显式请求、unloaded/deleted buffer、重新 setup 和批内失败隔离。
需要真实 linter 验证时使用任务 fixture 与已安装工具，并区分 adapter 测试和外部工具行为。
