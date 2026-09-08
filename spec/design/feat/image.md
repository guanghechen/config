# Image 模块边界

## 依赖方向

```text
init → doc → inline → placement → image → convert
doc / inline / placement / convert → state
placement / image / convert / state → terminal
state / terminal → env
```

`init` 是 lifecycle composition root。

## 状态归属

- `placement` 是 placement identity 的 single writer，并将已分配的 ID 注册给 `image`。
- `image` 持有 image identity、conversion/send 状态和已注册 placements。
- `state` 持有配置、image dimensions 与 size calculation，并通过 `terminal` 读取尺寸。
- `env` 持有 terminal environment metadata 与 output transform。
- `terminal` 持有 terminal measurement 与 graphics-protocol output，只读取 `env`，不反向依赖 `state`。
- `doc` 持有 document queries，并将 query contract 注入 `inline`；`inline` 不反向解析 `doc`。

这些边界保持现有 runtime behavior 与 `era.m.image` 的 top-level facade shape，并使静态 module dependency
graph 无环。
