# ts-comments.nvim

## 镜像取材

- 仓库：[guanghechen/mirror](https://github.com/guanghechen/mirror.git)。
- 预期 ref：`refs/heads/nvim@ts-comments.nvim`；2026-10-14 远端查询未找到，尚待建立或确认映射。
- 分支可用前仅保留本地来源盘点。以下同步步骤以确认镜像分支为前提，不从原始项目补取材料。

## 来源与本地范围

- 原始项目（仅归属说明）：`folke/ts-comments.nvim`。
- 本地：[lua/era/dressing/commentstring.lua](../../../../lua/era/dressing/commentstring.lua)。
- 来源锚点：`2002692ad1d3f6518d016550c20c2a890f0cbf0e` 下的 `lua/ts-comments/comments.lua` 与 `config.lua`；本地保留 Apache-2.0 来源说明。
- 关系：语言/node-type 配置与 commentstring 解析的派生实现。

## 如何更新

1. 分别对比语言表和运行时解析变化，核对新增语言别名、多个 commentstring 与 node-specific overrides。
2. 将数据合入本地 `language_map`，将必要解析修复适配到当前函数；保持 `vim.filetype.get_option` 的原始 fallback 和幂等 setup。
3. 保留本地 `comments` option 解析、`%s` 空白规范化、缩进处光标处理、父节点遍历和 injected language 行为。
4. 用具体 JSX/TSX、HTML 或注入语言案例核实改动；更新来源记录并保留 Apache-2.0 attribution。

## 验证

```sh
nvim -l __test__/run.lua __test__/specs/era/dressing/commentstring_spec.lua
```

检查无 parser/无 node 的 fallback、多候选分隔符、文件类型别名，以及重新 setup 后是否重复包装原生函数。
