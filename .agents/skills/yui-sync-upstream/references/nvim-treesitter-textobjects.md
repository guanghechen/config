# nvim-treesitter-textobjects

## 镜像取材

- 分支：[nvim@nvim-treesitter-textobjects](https://github.com/guanghechen/mirror/tree/nvim%40nvim-treesitter-textobjects)。
- 完整 ref：`refs/heads/nvim@nvim-treesitter-textobjects`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`nvim-treesitter/nvim-treesitter-textobjects`。
- 数据：[queries/](../../../../queries/) 下的 `*/textobjects.scm`；本地消费者是 [textobject/treesitter.lua](../../../../lua/era/keystroke/textobject/treesitter.lua)、`find.lua` 和 `swap.lua`。
- 历史来源锚点：`898ee307df58f854d11cd7edd06472574d48014e` 的 `queries/`。
  [本地契约](../../../../spec/design/feat/textobject.md) 记录了最初 28 个 query 文件和 Apache-2.0 来源；实际语言集合以当前文件为准。
- 关系：queries 数据移植，选择/跳转/交换由本地实现；parser 仍由现有 nvim-treesitter 集成管理。

## 如何更新

1. 列出当前 `queries/*/textobjects.scm`，逐语言比较来源锚点到目标 SHA 的 query 变化，并核对对应 parser 的 node types。
2. 只合并目标语言的 textobjects query 及确有需要的 `inherits` 依赖；保留其他 query group 的文件和本地 query 调整。
3. 复核 `@function`、`@class`、`@block/@conditional/@loop`、`@comment` 的 inner/outer，以及 `@parameter.inner`。
   `locals` 的 scope、`folds` 和 Neovim 原生 AST 选择属于其他来源，不随 textobjects 更新替换。
4. 上游 Lua select/move/swap 的修复按本地消费者逐项适配；保留显式 Visual 模式、参数容器约束、查询窗口和无匹配时的取消语义。
5. 记录各语言采纳的 query 差异和目标 SHA；保持 Apache-2.0 attribution，并相应更新设计文档的来源记录。

## 验证

```sh
nvim -l __test__/run.lua era/keystroke/textobject/
```

使用修改语言的真实 parser 检查 captures、参数交换和边界跳转。缺少 parser 时明确记录该语言的验证缺口；安装遵循已有授权。
