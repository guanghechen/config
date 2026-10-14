# snacks.nvim

## 镜像取材

- 仓库：[guanghechen/mirror](https://github.com/guanghechen/mirror.git)。
- 预期 ref：`refs/heads/nvim@snacks.nvim`；2026-10-14 远端查询未找到，尚待建立或确认映射。
- 分支可用前仅保留本地来源盘点。以下同步步骤以确认镜像分支为前提，不从原始项目补取材料。

## 来源与本地范围

原始项目（仅归属说明）：`folke/snacks.nvim`。同一个库的多个移植点在此维护，不能共用一个未经核实的同步版本。

| 本地文件                            | 上游文件                      | 源码中的来源锚点                           |
| ----------------------------------- | ----------------------------- | ------------------------------------------ |
| `lua/era/dressing/scroll.lua`       | `lua/snacks/scroll.lua`       | `fe7cfe9800a182274d0f868a74b7263b8c0c020b` |
| `lua/era/dressing/dim.lua`          | `lua/snacks/dim.lua`          | `fe7cfe9800a182274d0f868a74b7263b8c0c020b` |
| `lua/era/m/input.lua`               | `lua/snacks/input.lua`        | `fe7cfe9800a182274d0f868a74b7263b8c0c020b` |
| `lua/era/m/lsp/illuminate.lua`      | `lua/snacks/words.lua`        | `fe7cfe9800a182274d0f868a74b7263b8c0c020b` |
| `lua/era/dressing/statuscolumn.lua` | `lua/snacks/statuscolumn.lua` | `85b8ec210975aa137af4b7bef1fb7b7098be331a` |
| `lua/stl/c/proc.lua`                | `lua/snacks/util/spawn.lua`   | `5589c9d37bccf56f98982cd88a72e69cddf13436` |

## 如何更新

1. 只取本次涉及的组件，从该行锚点比较到目标 SHA；上游移除或重命名模块时追踪对应实现，不能把路径消失解释成删除本地模块。
2. 按本地 owner 适配上游修复，保留这些差异：
   - scroll：本地 easing/timer、重复滚动、option 恢复，以及 explorer/treeview 自主管理 cursor 的准入限制。
   - dim：scope 来自本地 indentscope，保留 ephemeral decoration 与动画取消。
   - statuscolumn：本地 sign/mark/fold/Git 组合、cache；涉及 Neovim FFI 的改动核对当前版本实际布局与符号。
   - input：本地 `before_confirm`、`block_cancel`、completion 与 confirmation 流程。
   - illuminate：本地 LSP reference namespaces、mode gating、跳转和 jumplist 行为。
   - Proc：`stl.c.Proc` 的 stdout/stderr、exit、timeout、abort 和 handle 关闭约定。
3. 保留本地 `stl/dot/era` 依赖边界与 source-specific callbacks，避免为单个修复引入 Snacks 的整套 runtime。
4. 逐组件记录目标 SHA、采纳范围与验证；更新一项不推进其余五项的记录。采纳源码时保留相应 license/attribution。

## 验证

按所改组件选择：

```sh
nvim -l __test__/run.lua __test__/specs/era/dressing/scroll_spec.lua
nvim -l __test__/run.lua __test__/specs/era/dressing/dim_spec.lua
nvim -l __test__/run.lua __test__/specs/era/dressing/statuscolumn_spec.lua
nvim -l __test__/run.lua __test__/specs/ark/vendor/statuscolumn_spec.lua
nvim -l __test__/run.lua __test__/specs/era/m/explorer/prompt_spec.lua
```

Explorer prompt 测试只覆盖 input 的一个消费者。当前没有找到 Proc 和 illuminate 的专用 suite；改动它们时补针对性 headless 验证，
分别检查进程回调/handle 生命周期或 documentHighlight/跳转，而不是用 scroll suite 代替。
