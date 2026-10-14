# mini.indentscope

## 镜像取材

- 分支：[nvim@mini.indentscope](https://github.com/guanghechen/mirror/tree/nvim%40mini.indentscope)。
- 完整 ref：`refs/heads/nvim@mini.indentscope`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`nvim-mini/mini.indentscope`。
- 本地：[lua/era/dressing/indentscope/](../../../../lua/era/dressing/indentscope/) 的 `init.lua`、`scope.lua`、`draw.lua`、`action.lua`。
- 来源锚点：`92fbaf895f83c59575ec599df532b297ebf62b14`，见本地 `init.lua` 首行和 MIT notice。
- 关联消费者：[dim.lua](../../../../lua/era/dressing/dim.lua)、[textobject](../../../../lua/era/keystroke/textobject/)。

## 如何更新

1. 对比上游 `lua/mini/indentscope.lua` 在 scope 计算、border、空行、tab/space、动作和 draw lifecycle 上的变化。
2. 分别移植到本地 scope/draw/action；保留 `get_scope()` 的 `body/border/reference` 数据形状和本地配置入口。
3. 核对本地多级 `f_indentscope_*` highlights、`ai/ii` 与边界跳转；保留 timer 取消、buffer/window 准入和重配置生命周期。
4. 若 scope 形状或边界语义改变，同时检查 dim 与 textobject 消费方，并保留 MIT attribution。

## 验证

```sh
nvim -l __test__/run.lua __test__/specs/era/dressing/indentscope_spec.lua
nvim -l __test__/run.lua __test__/specs/era/dressing/dim_spec.lua
nvim -l __test__/run.lua era/keystroke/textobject/
```

检查空行、混合缩进、EOF、scope 切换、动画取消，以及 Visual/operator 的 inner 与 border 范围。

## 最近核对（2026-10-14）

- 审查目标：`14eecb1cf33d1db35b8ac665b1aab4d3c9b47fe3`（`nvim@mini.indentscope`）。
- 基线与范围：来源锚点到目标只有 README logo 更新，`lua/mini/indentscope.lua` 未变化。
- 结果：无需代码移植；保留本地 scope/draw/action 与 dim/textobject 的消费约定。
- 验证：indentscope 27 cases、dim 1 case、textobject 75 cases 通过。
