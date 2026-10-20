# Completion 行为验证与排障

最终行为、边界和状态归属以 [Completion design](../design/feat/cmp.md) 为准。
本页保留可执行验证和定位入口；原始 trace、失败日志与逐轮记录保存在本地
`__test__/bench/results/cmp/`，不随 checkout 提供。

## 普通回归

从 repository root 执行：

```sh
nvim -l __test__/run.lua era/keystroke/cmp/
nvim -l __test__/run.lua era/m/lsp/
nvim -l __test__/run.lua support/ui_spec.lua
cargo test --offline --manifest-path rust/Cargo.toml -p yoz completion:: --lib
```

Lua suite 覆盖真实输入、preview、取消、LSP 编辑、undo/dot repeat、snippet、异步 ownership、
source fallback、排序与 native UI。Rust 单测验证 fuzzy、scalar/SIMD 一致性、排序及历史。
共享 UI 客户端、runtime 和行为 fixtures 同时服务普通回归与 benchmark。

行为用例位于 `__test__/fixtures/era/keystroke/cmp/behavior/`，按插入、编辑与 snippet、命令行分为
`insert.lua`、`edit.lua`、`cmdline.lua`；每个用例给出 payload、按键和每步应达到的状态，由
`__test__/specs/era/keystroke/cmp/behavior/` 下对应的 spec 在真实 UI 中逐步验证。这些期望在迁移时对照
冻结的 Blink 1.10.2 配置确认；只由已移除的差分 runner 覆盖的用例，期望取自移除时 Era 的实际行为。

## 真实语言服务器

```sh
nvim -l __test__/manual/era/keystroke/cmp/lua_ls.lua
nvim -l __test__/manual/era/keystroke/cmp/emmet.lua
```

入口使用已有 Mason executable，或接受命令末尾的 explicit executable；不安装或下载依赖。
LuaLS 使用生产 client name/settings，先等待语义候选完成索引，再验证文档签名、接受、
snippet/final tabstop、signature 和跨 buffer fallback，避免初始化结果冒充 server 就绪。
Emmet 验证完整/部分缩写、suffix alternative 和 UTF-16 前缀，默认接受走实际 Enter mapping。

## 定位入口

| 现象 | 生产入口 | 主要回归 |
| --- | --- | --- |
| 禁用补全吞键、mapping fallback 或排队输入乱序 | `keymap.lua`、`init.lua` | `input_spec.lua`、`behavior/*_spec.lua` |
| 接受失败、UTF-16/import/overlap、snippet、undo 异常 | `edit.lua`、`snippet.lua`、`session.lua` | `edit_spec.lua`、`input_spec.lua` |
| Native preview 中续发 completion，附加编辑错位 | `session.lua` dispatch、`source/lsp.lua` | `request_spec.lua` |
| `CompleteDone` 同步 hide/show 覆盖新状态 | `session.lua` 的恢复输入及其调用方 | `request_spec.lua` |
| Reload、迟到 callback、取消或菜单重新出现 | context revision、session epoch、slot ownership | `session_spec.lua`、`source_spec.lua`、`input_spec.lua` |
| 退格时重复请求、临时列表消失或缓存失效 | `init.lua`、`session.lua`、`source/lsp.lua` | `session_spec.lua`、`request_spec.lua`、`input_spec.lua` |
| 字符串/路径准入、buffer fallback、动态目录结果 | `policy.lua`、`source/*` | `source_spec.lua`、`input_spec.lua` |
| 候选缺失、顺序或 native snapshot 异常 | `item.lua`、`rank.lua`、`rust/yoz/src/completion/` | `rank_spec.lua`、`history_spec.lua`、Rust 单测 |
| 文档、标签、窗口大小、滚动和位置 | `menu.lua`、`documentation.lua`、`signature.lua` | `window_spec.lua`、`viewport_spec.lua` |

Lua 生产路径位于 `lua/era/keystroke/cmp/`；specs 位于 `__test__/specs/era/keystroke/cmp/`。
优先复现具体按键和 payload，再选择相应 suite；测试失败应保留原始诊断，不自动重试或跳过。

性能测量的入口与口径见[性能指南](cmp-benchmark.md)。
