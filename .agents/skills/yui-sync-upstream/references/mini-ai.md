# mini.ai

## 镜像取材

- 分支：[nvim@mini.ai](https://github.com/guanghechen/mirror/tree/nvim%40mini.ai)。
- 完整 ref：`refs/heads/nvim@mini.ai`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`nvim-mini/mini.ai`，重点查看 `lua/mini/ai.lua`、文档和文本对象测试。
- 本地：[lua/era/keystroke/textobject/](../../../../lua/era/keystroke/textobject/)，重点是 `pattern.lua`、`search.lua`、`find.lua`、`action.lua` 和 `keymap.lua`。
- 关系：本地 textobject 替代 mini.ai 的运行时；按行为对照维护，不把整个目录视为逐文件 vendor copy。
- 基线：当前没有记录可确认的 mini.ai commit。首次核对须固定一个参考 SHA，并记录行为差异，不能声明它是历史导入版本。
- 本地契约：[Textobject](../../../../spec/design/feat/textobject.md)。Treesitter queries 的来源另见 [nvim-treesitter-textobjects](nvim-treesitter-textobjects.md)。

## 如何更新

1. 对照上游文本对象生成、候选搜索、inner/around 边界、count、空对象和 operator/Visual 处理的相关改动。
2. 用上游修复的最小输入在本地复现，再判断是否需要移植。沿用本地的 pattern/search/action 分层，修改相应算法或动作。
3. 保留本地 `cover_or_next`、参考行优先/邻域搜索、对象 ID、原生 fallback，以及 Git hunk、indentscope 等本地 provider。
   查阅契约确定 `(`/`)` 的空白差异、`u/U` receiver 范围和 Visual 扩选，不能直接套用上游默认 mappings/config。
4. 为采纳的行为增加本地回归；若上游行为与本地契约不同，记录保留依据，不仅以输出不一致判断本地错误。

## 验证

```sh
nvim -l __test__/run.lua era/keystroke/textobject/
```

重点验证 `di(`/`vi)`、嵌套参数、转义引号、空对象、UTF-8/EOF、count、连续 Visual 扩选和 dot-repeat。
只有新增或移植了受许可约束的源码时，按所取上游文件保留其许可与署名。
