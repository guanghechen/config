# nvim-tmux-navigation

## 镜像取材

- 分支：[nvim@nvim-tmux-navigation](https://github.com/guanghechen/mirror/tree/nvim%40nvim-tmux-navigation)。
- 完整 ref：`refs/heads/nvim@nvim-tmux-navigation`；2026-10-14 已确认远端存在，使用前重新解析固定 SHA。
- 本文的上游代码、文档和测试均从该镜像分支取材，文件路径相对分支根目录。

## 来源与本地范围

- 原始项目（仅归属说明）：`alexghergh/nvim-tmux-navigation`。
- 本地：[lua/stl/tmux.lua](../../../../lua/stl/tmux.lua)。
- 来源锚点：`4898c98702954439233fdaf764c39636681e2861` 的 `lua/nvim-tmux-navigation/tmux_util.lua`，见本地首行。
- 关系：本地 tmux 工具函数派生，包含 socket、方向/边界、zoom 与异步查询能力。

## 如何更新

1. 对比上游 tmux command 构造、pane 边界和 zoom 语义，核对实际 tmux 输出格式。
2. 按本地同步/异步 helper 分别移植；保留 `$TMUX` socket 选择、query timeout、失败返回值及参数数组传递。
3. 导航 mappings 与 `stl.tmux` API 分开维护；上游默认键位不覆盖本仓库映射。
4. 记录变动涉及的 tmux 版本/输出差异与来源 SHA；代码移植保留对应许可。

## 验证

```sh
nvim -l __test__/run.lua __test__/specs/stl/tmux_spec.lua
```

优先使用现有 mock 验证单 pane、zoom、多 pane 和异常响应。需要真实导航时，按仓库规则使用用户指定的精确 `%N`，不自动选择目标 pane。

## 最近核对（2026-10-14）

- 审查目标：`4898c98702954439233fdaf764c39636681e2861`（`nvim@nvim-tmux-navigation`）。
- 基线与范围：镜像 tip 与来源锚点相同，没有上游增量。
- 结果：无需代码移植；保留本地 socket、timeout、同步/异步 helper 和参数数组传递。
- 验证：`__test__/specs/stl/tmux_spec.lua`：8 cases 通过，使用现有 mock。
