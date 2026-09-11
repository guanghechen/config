# Image 模块边界

`era.m.image` 的顶层 facade 保持稳定，内部依赖无环。

## 依赖方向

```text
init → doc → inline → placement → image → convert
doc / inline / placement / convert → state
placement / image / convert / state → terminal
state / terminal → env
```

`init` 负责生命周期组装。

## 状态归属

- `placement` 是 placement identity 的唯一 writer，并向 `image` 注册已分配的 ID。
- `image` 持有 image identity、转换/发送状态及已注册 placements。
- `state` 持有配置、图像尺寸与尺寸计算，通过 `terminal` 读取 terminal 尺寸。
- `env` 持有 terminal environment metadata 与 output transform。
- `terminal` 负责 terminal measurement 与 graphics-protocol output，只读取 `env`，不反向依赖 `state`。
- `doc` 持有 document queries，并向 `inline` 注入 query contract；`inline` 不反向解析 `doc`。
