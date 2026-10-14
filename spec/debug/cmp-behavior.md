# Completion 行为验证与排障

最终行为、边界和状态归属以 [Completion design](../design/feat/cmp.md) 为准。
本页保留可执行验证和定位入口；原始 trace、失败日志与逐轮记录保存在本地
`__test__/bench/results/cmp/`、`__test__/compare/results/cmp/`，不随 checkout 提供。

## 普通回归

从 repository root 执行；普通 specs 不需要安装 Blink：

```sh
nvim -l __test__/run.lua era/keystroke/cmp/
nvim -l __test__/run.lua era/m/lsp/
nvim -l __test__/run.lua support/rpc_spec.lua
cargo test --offline --manifest-path rust/Cargo.toml -p yoz completion:: --lib
```

Lua suite 覆盖真实输入、preview、取消、LSP 编辑、undo/dot repeat、snippet、异步 ownership、
source fallback、排序与 native UI。Rust 单测验证 fuzzy、scalar/SIMD 一致性、排序及历史。
共享 RPC、runtime 和行为 fixtures 同时服务普通回归，不属于可单独移走的 benchmark 数据。

## 真实语言服务器

```sh
nvim -l __test__/fixtures/era/keystroke/cmp/lua_ls.lua
nvim -l __test__/fixtures/era/keystroke/cmp/emmet.lua
```

入口使用已有 Mason executable，或接受命令末尾的 explicit executable；不安装或下载依赖。
LuaLS 使用生产 client name/settings，先等待语义候选完成索引，再验证文档签名、接受、
snippet/final tabstop、signature 和跨 buffer fallback，避免初始化结果冒充 server 就绪。
Emmet 验证完整/部分缩写、suffix alternative 和 UTF-16 前缀，默认接受走实际 Enter mapping。

## 定位入口

| 现象 | 生产入口 | 主要回归 |
| --- | --- | --- |
| 禁用补全吞键、mapping fallback 或排队输入乱序 | `keymap.lua`、`init.lua` | `input_spec.lua`、`behavior_spec.lua` |
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
