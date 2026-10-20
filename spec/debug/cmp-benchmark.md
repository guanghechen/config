# Completion 性能测量

实现契约见 [Completion design](../design/feat/cmp.md)，行为验证见[行为指南](cmp-behavior.md)。
本页维护可复现方法和解释边界；结果写入本地 `__test__/bench/results/cmp/`（git 忽略），
不随 checkout 提供，也不作为当前性能结论。

## 入口

所有命令从 repository root 运行，使用已有 Neovim 与本平台安装的原生库（`node script/build.mjs`
生成的 `lua/yoz.so`，Windows 为 `lua/yoz.dll`）。计时任务串行执行；不得同时跑 build、tests 或另一个 benchmark。

```sh
# CLI: output, Era baseline or -, samples, phase (ranking|load|ui|all), load case filter
nvim -l __test__/bench/cmp.lua /tmp/cmp - 21 all
nvim -l __test__/bench/cmp.lua /tmp/cmp-load - 11 load incomplete
nvim -l __test__/bench/cmp.lua /tmp/cmp-baseline /path/to/era-baseline 21 ranking

# 报告与校验；目录可读取 JSON 或 gzip
node script/benchmark/cmp-report.mjs /tmp/cmp
node script/benchmark/cmp-report.mjs --before /tmp/cmp-before --after /tmp/cmp-after
node --test __test__/node/cmp-*.test.mjs
```

Samples 至少 5，每个 workload 另有 5 次预热。末尾的 case filter 只作用于 load，按字面子串匹配场景名，
未匹配任何场景时失败。

Baseline 目录是另一个 checkout，包含 `lua/era/keystroke/cmp/`、与源码匹配的已安装原生库，以及
`rust/yoz/src/completion.rs` 和 `rust/yoz/src/completion/**/*.rs`（记录 Rust source identity）。
Baseline 与当前版本必须共享正在测量的 native API、context 和原生 PUM 契约。

## 各 phase 的职责

| Phase            | 验证的问题                                                                |
| ---------------- | ------------------------------------------------------------------------- |
| `ranking`        | 生产 normalize/prepare/warm rank，区分关闭、空和预置 64 项的历史          |
| `load`           | 固定 deadline 持续输入下的延迟、CPU、内存、事件覆盖、取消与请求 ownership |
| `ui`             | 附加真实 remote UI 后的首菜单、后续输入、选择与接受                       |
| `cmp-report.mjs` | 从 raw samples 重算统计，检查兼容 identity 与输入、ownership 不变量       |

Load 预置 64 项历史；UI 只在 `frecency_10000` 场景开启历史。Runner 共享数据、editor instrumentation
与 `__test__.support.ui` 客户端；普通回归不加载 bench 目录，也不生成结果。

## 可比较条件

`metadata.json` 记录 Neovim、CPU、completion Lua 内容、native/harness hash、采样和 GC 条件。
同侧 pooling 只接受相同的 completion Lua、native hash 与采样条件；前后对照要求相同 host、runtime、harness、
语料与 GC 边界。History、候选数和是否重建 snapshot 必须随结论说明。

## 解释边界

- Menu event、remote UI flush 与屏幕/compositor latency 是不同指标；payload 在计时前准备，不含真实 server 计算和网络。
- 新 session 与新进程首次触发不同。考察首次使用需单独运行独立进程实验，不能以预热数据替代。
- Open-loop producer 在 parent 按 deadline 发送输入，child 阻塞不会推迟 offered load。
  同时报告 latency、CPU/key 和菜单 flush 覆盖率；覆盖率不等于丢键率。
- Reporter 检查最终文本、请求位置、取消后的发布和 generation；事件 query lag 单列，不能直接认定候选错误。
- CPU 为整个 child（含 observer）；heartbeat 也包含 OS 调度。未锁 CPU 频率、小样本 p95 不能外推稳定尾延迟。
- Lua heap 不含 Rust allocations；RSS 包含 editor、fixture、allocator 保留页。
  Fresh 50k 预制多份响应会显著放大 RSS，不能当作日常内存或 leak 证据。

采用优化前，先用普通回归验证语义；性能测量若暴露真实错误，保留失败样本，修复后另建目录重测。
不要把中间失败批次、历史源码或聚焦 workload 混入新的完整结果。
