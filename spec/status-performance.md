# Status Renderer 性能设计

> 状态：Final
>
> 保护的系统 contract：`statusline.md`

本文记录已经由 measurement 支持的性能决策，以及后续优化不可跨越的 correctness
边界。它只描述最终约束与结论，不预先批准任何新优化。

## 1. 目标与约束

性能工作的目标是降低 process/tmux IPC cost，同时保持：

- lifecycle generation fence；
- exact-state CAS；
- latest-render-wins revision；
- timeout 后 ambiguous mutation 的恢复语义；
- crash/hang isolation；
- `status01` fallback。

当前 measurement 不支持引入 daemon 或新 package dependency。

## 2. Measurement contract

- 使用 release build 与 isolated tmux server。
- 优先在同一 server 上交替执行 old/new A/B。
- 记录 workload、client/session count、run count、median、p95 与 mean。
- Standalone shell/hyperfine 数据只视为 directional evidence，除非 state boundary 一致。
- 不根据估算的 process count 批准实现。
- 每次只验证一个 behavior-preserving optimization。
- Benchmark claim 只适用于被测 workload，不外推到 throughput 或 tail latency。

## 3. Baseline

2026-07-22，四个 sessions、一个 client 的 isolated release measurement：

| Workload | Median |
|---|---:|
| process help | 6.6 ms |
| pure layout | 7.7 ms |
| one tmux client read | 8.5 ms |
| read-only status02 render | 16.8 ms |
| scheduler tick，nothing due | 13.8 ms |
| scheduler driver + nothing due | 72.7 ms |
| due metrics tick | 63.0 ms |
| 单次 `route` / `vm_stat` / `netstat` | 约 5.5 ms |

结论：当前 latency floor 主要来自 process startup 与 tmux IPC，而不是 pure Rust
composition。

## 4. 已接受的优化

### 4.1 Scheduler lock ownership

Final contract：

- fixed lock path 是唯一 driver owner；
- acquisition 通过 prewritten owner 原子发布；
- failed acquisition 前后都要重新检查 live owner；
- 只有 dead known owner 可进入 server-scoped recovery lease；
- unknown state 与 tmux lease failure 均 fail closed；
- candidate/update cleanup 可合并，但不得改变 fixed lock authority。

接受的代价：owner 在 live check 后立即死亡时，recovery 可延迟到下一次 tick。

### 4.2 Reuse driver snapshot

Driver 将已读取的 lifecycle/task snapshot 通过严格、namespaced environment value 传给
Rust。Rust 保留 raw task strings 作为 CAS witness；缺失或 malformed transport 回退到
authoritative live read。

50-run no-due A/B：

```text
median 59.164 -> 54.142 ms
mean   60.178 -> 54.437 ms
```

### 4.3 Split render and diagnostic snapshots

- Apply hot path：15 options。
- `dump-state`：37 options。
- Sequential live no-op median：`16.660 -> 14.993 ms`。

Diagnostic completeness 不得重新进入 render hot path。

### 4.4 Combine metric claim and input read

Metric claim 与 execution-input snapshot 共用一个 guarded tmux queue。Execution deadline
在该 queue 前启动，因此优化不会放宽 task budget。

20-run due-tick A/B：`58.5 -> 49.9 ms` median。

### 4.5 Length-only reconcile

只有在 render key、cache witnesses、layout、status 与 row formats 全部 settled 时，才允许
仅提交 stale lengths。其他 drift 必须保留 full reconcile bundle。

30-run 91/92-column A/B：

```text
plan commands  10 -> 1
commit median  16.270 -> 15.015 ms
total median   25.000 -> 23.230 ms
```

### 4.6 Fold final standard refresh

Final Standard/Bootstrap chunk 在 applied marker 前 conditionally 执行 `refresh-client -S`。
Detached context 跳过 refresh；queue failure 仍回退到 guarded individual retry 与独立
best-effort refresh。Scheduler commit 保持自己的 deadline-sensitive path。

30-run one-client non-empty A/B：

```text
commit median 25.010 -> 12.280 ms
total median  37.385 -> 25.930 ms
```

### 4.7 Aggregate session display state

每个 visible session item 重复执行 `S/W/P` traversal，在 4/10/20 items 下的 isolated
median 增量为 `+0.756 / +1.541 / +5.121 ms`，因此拒绝该方案。最终由 scheduler
single-flight owner 每 tick 聚合一次 running 与 bell evidence；session item 做 typed token
membership 并从现有 1 Hz status clock 派生 animation phase，window item 保持 native live
expansion。Bell evidence 读取同一 `S:` pass 的 `session_alerts`，不增加 `W/P` traversal。

2026-08-12，tmux 3.7b，20 sessions、1 attached client、300 paired runs。Baseline 与
sample 使用相同的 publish、delayed-CAS queue；baseline 发布 literal token set，sample
执行 `S/W/P` traversal：

```text
                 mean     median      p95
paired delta   +1.115    +0.903   +1.946 ms
```

该结果只隔离 traversal cost，不是 feature-enabled 对 no-sampler 的总 overhead。测量来自
精简前的 two-option queue；control queue 在 paired 两侧相同，因此仍可用于 traversal
预算判断，但不能作为当前 single-option implementation 的精确总成本。

真实 4 秒 scheduler cadence 的 31 秒 probe 中，1/4 attached clients 均只有 8 次 owner
sample，interval median 分别为 `4.141 / 4.170 s`。该数据只证明 multi-client contention
未增加 sampler cadence；不构成普遍 tail-latency claim。

Session display state 不进入 Rust snapshot/cache。Sample 使用单 option delayed CAS，producer
停止后 marker 最多保留 12 秒。

2026-08-14，tmux 3.7b，20 sessions、15 paired blocks、每侧 50 次 isolated expansion。
在相同 running `S/W/P` aggregation 上增加 `session_alerts` bell match，median delta 为
`+0.515 ms/sample`；默认约每 4 秒采样一次。该结果包含两侧相同的外部
`display-message` 开销，只作为 bell evidence 增量的 directional evidence。

2026-08-14，tmux 3.7b，isolated server、300 paired runs。所有 item 均为 running；两侧执行
相同 membership match，candidate 额外展开四帧 clock format。相对静态 glyph：

```text
items             4       10       20       40
median delta  +0.124   +0.181   +0.391   +0.884 ms
p95 delta     +1.076   +1.267   +1.684   +2.031 ms
```

最终两帧 clock 将完整周期从 4 秒缩短到 2 秒。2026-08-14，20 items、15 paired blocks、
每侧 80 次 expansion，相对四帧 format 的 median delta 为 `-0.365 ms/expansion`；redraw
仍为 1 Hz，不增加 timer、process 或 IPC。

旧互斥实现中的 typed `R/B` state 仅在非-running item 的 false branch 增加一次 bell
membership match。
2026-08-14，20 个 belling items、15 paired blocks、每侧 80 次 expansion，相对旧 static-bell
branch 的 median delta 为 `+0.364 ms/expansion`。该 measurement 记录的是 2026-08-14
实现；当前 session item 为同时展示两类 evidence，会独立执行两次 membership match。

该 measurement 是 per-expansion directional evidence，不是完整 tmux CPU throughput claim。
Active-scheduler animation 不增加 timer、process、IPC、option write 或 `S/W/P` traversal；
成本随 visible item、client 与实际 status expansion 次数增长。Scheduler inactive 时 terminal
title 才执行一次 live `W/P` fallback；该成本不进入 status02 active hot path。

2026-08-14，tmux 3.7b，isolated server、300 paired runs。Baseline 通过 `list-windows`
展开 title；candidate 在相同 workload 中额外展开 `@GHC_WINDOW_PREFIX_FMT`。所有 pane title
均包含 spinner，bell/zoom 为 false：

```text
windows       panes/window   median delta   p95 delta
4             1                +0.389 ms     +1.896 ms
10            1                +1.003 ms     +2.566 ms
20            1                +1.949 ms     +3.971 ms
10            4                +1.910 ms     +4.052 ms
```

该结果隔离 per-window prefix expansion，仍是 directional evidence，不等于完整 status draw。
成本随 window/pane 数和实际 redraw 次数增长；多 client 各自展开，但 running-session publish
仍由 single-flight lock 去重。

### 4.8 Combined-state responsive budget

双状态 prefix 的额外宽度按可见 session 的 sampled `R/B` membership 计算；每个 metric
先检查静态上下界，只在临界宽度区间展开该计算。Metric body 保持原 conditional depth，
idle/单状态 baseline、隐藏优先级与 time fallback 均保留。

2026-09-21，macOS、tmux next-3.9、release renderer、1 个持久 control client。48 个场景，
每场景 20 组 warmup 与 200 组随机顺序配对样本。比较完整第一行 format expansion；下表
为全部 sessions 同时 running＋bell 时，相对同输出静态阈值的增量：

| Total / visible sessions | Width | Direct median | Bounded median | Bounded p95 |
|---|---|---:|---:|---:|
| 4 / 4 | wide | +0.243 ms | +0.045 ms | +0.309 ms |
| 4 / 4 | boundary | +0.239 ms | +0.114 ms | +0.375 ms |
| 40 / 10 | wide | +1.070 ms | +0.076 ms | +0.522 ms |
| 40 / 10 | boundary | +1.050 ms | +0.584 ms | +0.989 ms |

比较对象先按 fixture state 算好正确 threshold，因此不会把 metrics 显示数量变化混入
动态计算成本。20/40 个同组 sessions 在该 workload 下受既有 cache budget 限制，实际
只显示 10 个。结果包含 control socket 往返，不包含逐次 CLI startup、terminal drawing、
第二行、sampling 或 Rust apply/commit；不用于推断整机 CPU 或通用 tail latency。

代价：原型 row0-right 从约 1.35 KiB 增至 4 visible 时约 3.84 KiB、10 visible 时约
6.84 KiB。保持四个既有 cache options 与 guards；真实大 session 组的 guarded apply
与状态变化下 cache/revision 不变均已验证。

正式 release 在 4/4、40/10 fixture 下生成的 format 与上述 bounded 原型逐字节一致。
另以修改前后 release 做 5 组 warmup、40 组随机顺序配对补测。每组只有 1 个 attached
session、800 列、双行；同版本 apply 先在计时外稳定状态，再清该 session 的 render key，
测量 11-command cache bundle 的 guarded 重发。已稳定的 apply 单独计时：

| Total / visible | Republish before | Republish after | Paired median Δ | Settled apply Δ |
|---|---:|---:|---:|---:|
| 4 / 4 | 44.54 ms | 46.00 ms | +1.81 ms | +0.36 ms |
| 40 / 10 | 52.15 ms | 80.27 ms | +27.70 ms | +0.35 ms |

该表包含 CLI startup、snapshot 与 commit IPC，不含 terminal drawing、sampler、driver
工作或多个 attached sessions。Rust render phase 的配对增量约 0.01–0.03 ms；40/10 的
增量主要在 commit。独立 command probe 确认 payload 使发布分块从 2 增至 4，总 tmux
调用从 3 增至 5；4/4 均为 2 个分块、3 次调用。Probe 的 Python shim 不参与计时。
该成本发生在实际 cache 重发时，marker 状态变化仍只使用原生 format，不触发 Rust apply。

40/10 发布后的 right/session cache 为 7482/7033 bytes（含 26-byte witness），最大
tmux argv 为 10160 bytes。额外 40 个长名称、12 visible 的 fixture 也成功提交，最大
argv 为 10514 bytes；均未触发逐命令重试。保留既有 8 KiB 分块预算与完整 guards。

## 5. 明确拒绝或延后的方向

| Direction | Final decision | Revisit condition |
|---|---|---|
| Persistent daemon | Reject | process cost 明显超过 lifecycle complexity |
| Dynamic plugin loading | Reject | 出现真实 third-party runtime extension requirement |
| Precompute grouping/order | Defer | phase trace 显示 pure render 稳定超过 5–10 ms |
| Native metric commands | Defer | command cost 成为主要瓶颈且 FFI 语义可证明 |
| Simple hook single-flight gate | Reject | 必须先有 dirty-generation replay contract |
| State transport without exact CAS | Reject | 不允许削弱 tmux single-writer boundary |
| Status-format expansion | Defer | 目标规模下 tmux server CPU 变得不可忽略 |

4/10/20 scale prototype 未改善 median，因此 session grouping precompute 不属于当前优化方向。

## 6. Performance guardrails

- 不得为了 speed 移除 lifecycle generation 或 render revision guards。
- 不得 retry timeout-ambiguous scheduler claim/completion。
- 不得在没有 exact witness 的情况下拆分 shell/Rust state ownership。
- Renderer failure 时保留旧 visible cache 与 `status01` fallback。
- 保留 process timeout、process-group reap 与 capture limits。
- Noisy p95 只能作为 scoped evidence，不得包装成普遍 tail-latency 结论。
- 新 optimization 必须先给出 reproducible workload 与 baseline。

## 7. 当前结论

没有预先批准的下一项优化。Pure rendering、session-group precomputation 与 daemonization
均不是当前 priority。后续工作必须先由 trace 或 isolated A/B 指向一个 material phase cost，
再设计最小、可回退、behavior-preserving 的改动。
