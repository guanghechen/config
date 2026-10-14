# mini.splitjoin

## 镜像取材

- 分支：[nvim@mini.splitjoin](https://github.com/guanghechen/mirror/tree/nvim%40mini.splitjoin)。
- 完整 ref：`refs/heads/nvim@mini.splitjoin`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`nvim-mini/mini.splitjoin`，主要入口 `lua/mini/splitjoin.lua`。
- 本地：[lua/era/keystroke/splitjoin/](../../../../lua/era/keystroke/splitjoin/) 的 `init.lua` 与 `action.lua`。
- 来源证据：两个文件首行指向该库，`action.lua` 保留 MIT notice；未记录固定 upstream commit。
- 关系：本地派生实现，入口负责 lazy loading、`gS/gJ` 与 operatorfunc，action 负责扫描和编辑。

## 如何更新

1. 固定目标 SHA，检查上游 bracket-region、separator、quote/escape 和 split/join 编辑相关修复；基线不明时先建立对应函数与用例。
2. 将相关算法改动落到 `action.lua`；映射或 operator 行为才修改 `init.lua`，沿用本地 `stl.nvim.fn.bindkeys`。
3. 保留最小括号区域选择、嵌套与引号处理、trailing comma、缩进选项、Visual region，以及原生 operator/dot-repeat 约定。
4. 上游 hook/config 层只在本地确有同等需求时适配；保留 MIT notice，并记录已移植的具体修复。

## 验证

```sh
nvim -l __test__/run.lua __test__/specs/era/keystroke/splitjoin_spec.lua
```

覆盖嵌套调用、字符串逗号、转义、Visual/Normal、undo/repeat；保留现有 malformed-bracket 扫描预算用例。

## 最近核对（2026-10-14）

- 审查目标：`be4536a1b8608a482dfac7aec5ce91b1c2f9bdab`（`nvim@mini.splitjoin`）。
- 基线与范围：首次建立固定参考；历史导入 revision 仍未知。已对照括号/分隔符扫描、extmark 编辑和 comments 的 `b/f` flags。
- 结果：无需代码移植。上游 pre-hook 返回空 positions 的修复不对应本地公开接口；保留本地扫描预算、Visual/operator、undo/repeat 与注释缩进处理。
- 验证：`__test__/specs/era/keystroke/splitjoin_spec.lua`：13 cases 通过。
