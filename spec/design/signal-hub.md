# Signal Hub

`stl.c.SignalHub` 是独立的进程内消息模块。核心只使用 Lua 标准功能，不依赖
Neovim、runtime globals、reporter、timer 或第三方库。每个 Hub 独立拥有注册表和订阅；
共享实例由使用者显式组装。首版没有 builtin signal。

## 注册与身份

- `register_signal(name)` 注册非空、唯一的事件类型名称，返回该名称。
  重复注册报错；名称由业务模块自行命名，不内置业务 namespace。
- `register_role(name)` 注册一个参与者实例，返回 `{ id, name }` 身份。
  `name` 仅用于诊断，允许重复；`id` 在当前 Hub 内单调递增，不复用。
  实际路由和身份检查使用注册得到的 table identity，不能用同字段的复制品或其他 Hub 的身份替代。
- role 可以同时生产和消费消息。注册不自动订阅；身份和订阅是分开的生命周期。
- 身份只保留 readonly metadata，不持有组件或窗口实例。注销后仍可通过已经收到的消息追踪其身份。

## 消息与订阅

```lua
local message = {
  signal = "example.changed",
  scope = "example",
  payload = { value = 1 },
  track = {
    from = sender_role,
    to = receiver_role,
    original = sender_role,
  },
}
```

- `signal` 标识事件类型；`scope` 是非空字符串分组。`payload` 可以是任意 Lua 值，包括 `nil`、`false`。
- `track.from` 是当前发送者，`track.original` 是最初发送者；两者不参与匹配。
  它们记录实体身份，不为每次发送增加消息 ID。
- `track.to` 可选：填写时只投递给该 role 的匹配订阅；省略时广播给所有匹配订阅。
- `subscribe(role, { signal?, scope? }, callback)` 注册消费函数，返回支持 `:unsubscribe()` 的 handle。
  省略的过滤字段匹配任意值；目标过滤由订阅所属 role 与消息的 `track.to` 共同决定。
- 订阅不会回放历史消息。相同内容的多次发送仍是多次通知，Hub 不按 payload 相等去重。
- 消息、payload、身份均按 readonly 使用。Hub 创建自己的 envelope 和 track；payload 共享引用，
  不做深拷贝。消费者不能修改收到的消息来影响其他订阅。

```lua
local SignalHub = require("stl.c.signal_hub")
local hub = SignalHub.new()
local changed = hub:register_signal("example.changed")
local sender = hub:register_role("source")
local receiver = hub:register_role("view")

local subscription = hub:subscribe(receiver, {
  signal = changed,
  scope = "example",
}, function(message)
  -- 记录使用者自己的 pending state；实际工作由使用者安排。
end)

local delivered, errors = hub:emit(sender, {
  signal = changed,
  scope = "example",
  payload = { value = 1 },
  track = { to = receiver },
})
assert(errors == nil, errors and tostring(errors[1].error))

subscription:unsubscribe()
hub:unregister_role(receiver)
hub:dispose()
```

## 投递与转发

`emit(role, emission)` 自动设置 `track.from` 和 `track.original`。调用方的 emission 不被修改，
其中只有 `track.to` 被读取；转发必须通过 `forward` 保留原始身份。

`forward(role, message, route)` 创建新消息，保留 signal、payload 和 original，更新 from。
`route` 是必填对象：`scope` 省略时继承原 scope，`to` 省略时广播，**不继承旧目标**。
例如 `hub:forward(bridge, message, { to = destination })` 定向转发，
`hub:forward(bridge, message, {})` 在原 scope 广播。
历史 from/original 可以已经注销，但必须确实来自当前 Hub；当前转发者必须仍有效。

投递是同步的，发送返回前完成本轮匹配回调。Hub 不接管主循环切换、debounce/throttle、
数据刷新或 UI 绘制。Neovim fast event 的发送者应在适配层先切回合适的执行上下文。

- 每次发送开始时确定订阅快照。回调中新加的订阅参与后续发送，不加入当前发送。
- 取消订阅或注销接收 role 立即生效，快照中尚未调用的失效订阅会跳过。
- 同一过滤组合内按注册顺序调用；业务不应依赖不同过滤组合之间的顺序。
- 嵌套发送独立取订阅快照，在返回后继续外层投递。使用者负责避免循环转发。
- 多条通知合并执行一次业务操作，属于消费行为；若该操作产生新 signal，应重新 `emit`，
  不能随意把其中一条通知标作唯一的转发来源。

`emit` 和 `forward` 返回 `delivered, errors`：前者是成功调用的订阅数量，后者为
`{ role, error }[]|nil`，保留 callback 原始错误值。某个 callback 失败不会阻断其他匹配订阅。
错误由调用方报告，核心不写日志、不生成递归的 error signal。无订阅或目标已注销时返回 `0, nil`。
非法参数、未知 signal、未注册或已经注销的发送者则直接报错，校验失败前不创建订阅或开始投递。

## 清理

- `subscription:unsubscribe()` 幂等，并释放 callback 引用。
- `unregister_role(role)` 清理该 role 的全部订阅；对同一已注销身份重复调用无副作用。
  之后不能用它新建订阅或发送消息，指向它的消息不投递。其他 role 不受影响。
- 已注销身份仅保存在 weak registry 中，历史消息可以继续引用它，Hub 不阻止其被 GC。
- `unregister_signal(signal)` 移除精确订阅并终止该 signal 尚未完成的当前投递。
  wildcard 订阅仍可消费其他 signal，重新注册同名 signal 不恢复旧精确订阅或旧投递。
- `dispose()` 幂等，释放注册与订阅并终止在途投递。之后仅 `isdisposed()`、重复 `dispose()`
  和已有 subscription 的清理可继续调用，其他公开操作报错。

## 性能与验证

定向消息查找目标 role 的索引；广播查找 Hub 的索引。索引按 signal 和 scope 分组，
一次发送最多读取四个匹配 bucket，不遍历无关 role、scope 或 signal。
投递快照大小与匹配订阅数量成正比。每个订阅在全局索引和 role 索引中各持有一个链表节点，
取消订阅直接摘除节点，保留注册顺序。每组 scope 维护非空 bucket 数量，以 O(1) 判定索引是否为空，
避免批量删除不同 scope 时反复扫描空槽位；注销 role、注销 signal 和销毁 Hub 的索引清理随其订阅数量线性增长。
注册和注销位于使用者的生命周期边界。

```sh
# Repository runner
nvim -l __test__/run.lua __test__/specs/stl/c/signal_hub_spec.lua

# The same behavior specs also run without Neovim
LUA_PATH='./lua/?.lua;./lua/?/init.lua;./?.lua;;' luajit __test__/specs/stl/c/signal_hub_spec.lua

# CPU measurements, seven measured rounds after warm-up
LUA_PATH='./lua/?.lua;./lua/?/init.lua;./?.lua;;' luajit __test__/bench/signal_hub.lua
```

Benchmark 使用 `os.clock()` 测量 Hub 校验、消息构造、索引匹配及回调的累计 CPU。
输出的单次耗时是每批平均值，再报告七批的中位数和最大值；它不代表逐消息尾延迟或 UI latency。
测试覆盖路由、转发、不合法身份、回调失败、投递期间修改订阅、注销与资源释放。
清理 benchmark 覆盖单个／多个 role 与共享／不同 scope 的组合；spec 另设 20,000 个不同 scope 的 CPU 回归上限。
核心在仅含 Lua 标准功能的环境中加载并执行，防止意外引入 runtime dependency。

无阻塞实现的未决设计问题。nvimbar 接入属于后续独立改动。
