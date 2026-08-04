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
