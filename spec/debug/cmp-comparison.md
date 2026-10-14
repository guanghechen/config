# Completion 性能测量

实现契约见 [Completion design](../design/feat/cmp.md)，行为验证见[行为指南](cmp-behavior.md)。
本页维护可复现方法和解释边界；逐轮数字、source identity、原始样本及分析报告留在本地
`__test__/bench/results/cmp/`，不将旧版本结果作为当前性能结论。

## 入口与依赖

所有命令从 repository root 运行，使用已有 Neovim、native binary、Blink 和语言服务器。
不同计时任务串行执行；不得同时跑 build、tests 或另一个 benchmark。

```sh
# CLI: output, existing Blink, samples, phase, Era baseline or -, history
nvim -l __test__/bench/cmp.lua /tmp/cmp-ui /path/to/blink.cmp 31 ui - off
nvim -l __test__/bench/cmp.lua /tmp/cmp-load /path/to/blink.cmp 11 load - populated
nvim -l __test__/bench/cmp.lua /tmp/cmp-matching /path/to/blink.cmp 21 matching - off
nvim -l __test__/bench/cmp.lua /tmp/cmp-sources /path/to/blink.cmp 21 sources - off
nvim -l __test__/bench/cmp.lua /tmp/cmp-memory /path/to/blink.cmp 7 memory - off

# Era 前后比较；不需要安装 Blink
nvim -l __test__/bench/cmp_native.lua /tmp/cmp-native - 21 ranking
nvim -l __test__/bench/cmp_native.lua /tmp/cmp-native-load - 11 load incomplete
nvim -l __test__/bench/cmp_native.lua /tmp/cmp-baseline /path/to/era-baseline 21 ranking

# 报告与校验；目录可读取 JSON 或 gzip
node __test__/bench/cmp/report.mjs /tmp/cmp-load
node __test__/bench/cmp/report.mjs --before /tmp/cmp-before --after /tmp/cmp-after
node --test __test__/node/cmp-*.test.mjs
```

Blink CLI 的 phase 为 `matching/sources/ui/memory/load/all`。
Samples 至少 5，每个通常计时的 workload 另有 5 次预热；memory phase 固定使用 7 个独立进程。
History 为 `off/empty/populated`，后两者仅适用于 load；populated 预置 64 项。
Native CLI 的 phase 为 `ranking/load/all`，末尾可加 literal load case filter；未匹配任何场景时失败。

Baseline 目录包含 `lua/era/keystroke/cmp/` 和与源码匹配的 `bin/nix.yoz.so`。
Native CLI 还会记录 Rust source identity，因此目录需同时包含
`rust/yoz/src/completion.rs` 和 `rust/yoz/src/completion/**/*.rs`。
Baseline 与当前版本必须共享正在测量的 native API、context 和原生 PUM 契约；
旧自绘菜单或旧 native API 的比较应使用对应归档 runner，当前 fixtures 不保留适配层。

## 每个工具的职责

| 工具 | 验证的问题 |
| --- | --- |
| `matching` | 相同语料下的构建/查询成本、召回集合、排序差异及 typo 预算影响 |
| `ranking`（native CLI） | 生产 normalize/prepare/warm rank，区分关闭、空和已填充历史 |
| `sources` | buffer 热缓存/changedtick、目录扫描与 snippet 查询 |
| `ui` | 附加真实 remote UI 后的首菜单、后续输入、选择与接受 |
| `load` | 固定 deadline 持续输入、CPU、内存、事件覆盖、取消和请求 ownership |
| `memory` | 独立 fuzzy 对象构建与查询的内存，不能代替生产 completion retained heap |
| `report.mjs` | 从 raw samples 重算统计、检查兼容 identity 和输入/ownership invariants |

这些 runner 共享数据、editor instrumentation 和 RPC。普通回归只依赖 shared fixtures/RPC，
不加载 bench 目录或生成结果。长期保留 runner 和 reporter tests；临时聚焦 driver、
profile、失败 pilot、截图及机器数据写入 ignored results 目录。

## 可比较条件

`metadata.json` 记录 Neovim、CPU、Era/Blink Lua 内容、native/harness hash、Blink revision、采样和 GC 条件。
同侧 pooling 只接受相同实现和条件；前后对照要求相同 host/runtime/harness/语料/GC 边界。
Blink 样本合并同时检查 Lua 内容和 native hash；revision/dirty 仅作诊断，不能替代内容指纹。
缺少 Blink Lua 指纹的旧样本可单独报告，但不能合并；重新测量时生成指纹，不为旧样本补标当前源码。
报告 fingerprint 使用稳定内容和最终 score，不含 response 的临时 ID；排序差异独立报告。

默认 Blink 对照为 1.10.2，commit `78336bc89ee5365633bcf754d93df01678b5c08f`。
使用其他版本或 binary 时重新记录 identity，不能沿用旧标签。
行为 oracle 采用个人配置；性能 runner 采用自己的受控配置，两者不可混称。
UI/load 默认统一最多两处 typo；matching 另外记录 Blink 默认预算。
History、候选数、typo 预算和是否重建 snapshot 必须随结论说明。

## 解释边界

- Menu event、remote UI flush 与屏幕/compositor latency 是不同指标；payload 在计时前准备，不含真实 server 计算和网络。
- 新 session 与新进程首次触发不同。考察首次使用需单独运行独立进程实验，不能以预热数据替代。
- Open-loop producer 在 parent 按 deadline 发送输入，child 阻塞不会推迟 offered load。
  同时报告 latency、CPU/key 和菜单 flush 覆盖率；覆盖率不等于丢键率。
- Reporter 检查最终文本、请求位置、取消后的发布和 generation；事件 query lag 单列，不能直接认定候选错误。
- CPU 为整个 child（含 observer）；heartbeat 也包含 OS 调度。未锁 CPU 频率、小样本 p95 不能外推稳定尾延迟。
- Lua heap 不含 Rust allocations；RSS 包含 editor、fixture、allocator 保留页。
  Fresh 50k 预制多份响应会显著放大 RSS，不能当作日常内存或 leak 证据。
- Standalone native fuzzy 比较不包含生产 Lua wrappers、完整排名元数据和编辑安全检查。
- Source benchmark 比较 Blink 内置 providers，不代表完整个人 source 合并或旧自定义 path_at。

采用优化前，先用普通回归验证语义；性能测量若暴露真实错误，保留失败样本，修复后另建目录重测。
不要把中间失败批次、历史源码或聚焦 workload 混入新的完整结果。
