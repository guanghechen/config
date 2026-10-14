# blink.indent

## 镜像取材

- 分支：[nvim@blink.indent](https://github.com/guanghechen/mirror/tree/nvim%40blink.indent)。
- 完整 ref：`refs/heads/nvim@blink.indent`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`saghen/blink.indent`，入口 `lua/blink/indent/init.lua` 及关联模块。
- 本地：[lua/era/dressing/indentline/](../../../../lua/era/dressing/indentline/) 的 `init.lua`、`parser.lua`、`render.lua`。
- 来源锚点：`8b69b9262891fe81fe728fe6a52fa2a84dd5d5e0`，见本地 `init.lua` 首行；MIT notice 已保留。
- 本地 indent guides 与 [indentscope](mini-indentscope.md) 是不同模块，后者有独立上游。

## 如何更新

1. 对比上游缩进计算、空行推断、tabstop、viewport、decoration provider 和失效处理的相关改动。
2. 解析规则对应 `parser.lua`，绘制与 frame 行为对应 `render.lua`，事件/准入对应 `init.lua`。
3. 保留本地 `f_indentline_*` highlights、filetype/buftype 排除、可见区域绘制和模块初始化方式。
4. 对上游新增 scope 或动画能力先检查本地 indentscope 的职责，避免两个模块同时拥有同一装饰状态。
5. 将采纳的修复与来源 SHA 记录到本库文档，保留 MIT attribution。

## 验证

```sh
nvim -l __test__/run.lua era/dressing/indentline/
```

该目录覆盖 parser、render、provider、frame、setup 和实际 screen；修改绘制时保留滚动、分屏、resize、fold 和空行场景。
