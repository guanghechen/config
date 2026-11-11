# Yoz Fuzzy 测量记录

本文记录 [Yoz Fuzzy](../../../spec/design/yoz/fuzzy.md) 的评测方法、fzf 对齐、排序质量与最新结果，不定义契约；
预算见 [Yoz Fuzzy 性能](../../../spec/design/yoz/fuzzy.md#性能)，benchmark 通用约定见 [Benchmarks](../README.md)。

## 运行

L1、L2、L3 由 `node script/benchmark/fuzzy.mjs` 运行，缺失的语料会先生成；`fuzzy-corpus.mjs` 可单独预先生成语料。

```sh
node script/benchmark/fuzzy-corpus.mjs --out __test__/bench/results/fuzzy/corpus   # 语料，固定种子 0x5eed1234
node script/benchmark/fuzzy.mjs --build --baseline-rev 117a4fc88 --processes 3     # L1、L2、L3
node script/benchmark/fuzzy.mjs --level e2e --case files_10k_tree --build --processes 20
```

- **选择**：`--level rust|ffi|e2e` 与 `--case NAME`（L3 场景）可重复，默认全部；`--help` 列出全部选项与 L3 场景。
- **对照**：`--baseline PATH` 或 `--baseline-rev REV` 为 L3 加入 A/B 对照，两种实现逐进程交替先后；`--baseline-rev`
  经 `git archive` 提取提交，不改动仓库。
- **输出**：结果写入 `__test__/bench/results/fuzzy/<时间戳>/`（git 忽略），包括 `metadata.json`、`results.jsonl`、`summary.json`
  与 `report.md`；`report.md` 按 Yoz Fuzzy 的预算标注 pass / FAIL。
- **构建**：`--build` 把与源码绑定的原生库构建到 `results/fuzzy/native/`，过期的构建会被替换；
  `--current DIR` 可以对工作树的快照计时，主工作树在评测期间可以继续修改。

fzf 对齐与排序质量是 `fuzzy.mjs` 之外显式运行的 ignored 测试，读取同一语料目录：

```sh
YOZ_FUZZY_BENCH_CORPUS="$PWD/__test__/bench/results/fuzzy/corpus" cargo test --manifest-path rust/Cargo.toml -p yoz \
  --release --lib fuzzy::perf_tests::t_fzf_parity -- --ignored --nocapture
YOZ_FUZZY_BENCH_CORPUS="$PWD/__test__/bench/results/fuzzy/corpus" cargo test --manifest-path rust/Cargo.toml -p yoz \
  --release --lib fuzzy::perf_tests::t_fuzzy_quality -- --ignored --nocapture
```

`t_fzf_parity` 需要 `PATH` 上的 `fzf`；`YOZ_FUZZY_PARITY_CORPORA` 选择语料（默认为 100k 以下的 ASCII 语料），
`YOZ_FUZZY_PARITY_EXACT=1` 比较精确模式。

## 方法

- **语料**：
  - 真实路径：repo / runtime / plugins；
  - 合成路径：synthetic-10k / -100k / -1m；
  - 标签：labels / labels-100k；
  - 混合 Unicode：unicode；
  - 每个语料带逐字打字序列，覆盖路径片段、缩写、无匹配与扩展语法。
- **层级**：
  - **L1**：`rust/yoz/src/fuzzy/perf_tests.rs` 中 release 模式的 `#[ignore]` 测试，与 `search_in_lines`、Treeview matcher、completion matcher 同场比较；
    `sweep_t*` 探针扫描线程数。
  - **L2**：`__test__/bench/fuzzy/ffi.lua`，逐段计时，包含原生 id 解析，并统计每次按键的 Lua 分配。
  - **L3**：`__test__/bench/fuzzy/e2e.lua`，在挂 UI 的子进程中运行完整配置，以真实按键计时，由父进程观测刷屏。
    子进程经 `init.lua` 加载被测原生库，并把 workspace、frecency 与历史状态限制在本次运行的目录中；
    `probes.lua` 只观测各阶段时点，不改变被包装函数的返回值。
  - L2、L3 经 `cpu.lua` 请求 macOS 性能核，并以固定循环标定所在核的速度。
- **统计**：`--iterations` 是 L1/L2 每个进程内的计时轮数，`--processes` 是独立进程数。每个进程取中位数，再跨进程取中位数；
  L3 的按键样本合并统计。中位数在偶数个值时取中点；样本少于 20 个时不报告 p95，进程数达到 20 才报告进程级 p95。
  L1/L2 的单条查询耗时以毫秒记录，内存以字节记录。
  标定循环显著变慢的进程（疑似跑在能效核上）会被标记。

## fzf 对齐

`fuzzy::perf_tests::t_fzf_parity` 对每条查询比较 `fzf --filter QUERY --literal --scheme=<scheme>`（加 `--exact` 比较精确模式）
与本实现在无权重时的结果顺序。比较覆盖 repo、runtime、plugins、synthetic-10k/100k、labels/labels-100k 与 unicode 语料
的全部打字序列，以及一组手写的扩展语法查询。在 fzf 0.74.5 下，fuzzy 与 exact 两种模式全部一致。

## 排序质量

`fuzzy::perf_tests::t_fuzzy_quality`：

- 方法：按 L3 的口径给 2% 的条目分配 frecency，统计每个打字序列的目标在每次按键后的名次；分两种场景，目标本身常用（frecency 60）与目标不常用。
- 结论：权重 8–16 时，常用目标的 MRR 从约 0.24–0.45 提升到 0.51–0.81，不常用目标的 MRR 下降约 0.01–0.03；
  权重达到 32 以上，不常用目标明显变差。默认权重取 16。

## 最新结果

所有数据来自 Apple M5 Pro（6P + 12E）、外接电源、NVIM v0.12.6，2026-10-21 按统一结果格式测得，基线为提交 `117a4fc88`。
L1 / L2 每个语料 3 个进程、每进程 5 轮，p95 为查询级；L3 合并 3 个进程的按键样本，`files_10k_tree` 另以 20 个进程复测，
p95 同为 32.8 ms。L1 的基线是同一构建中的 `search_in_lines`，L2 的基线是旧 Lua 列表管线。

| 层级    | 场景                                |                         基线 |                       当前 |
| ------- | ----------------------------------- | ---------------------------: | -------------------------: |
| L1 Rust | 100k 路径，`fuzzy_rank` p95         |  119 ms（`search_in_lines`） |                    2.04 ms |
| L1 Rust | 1M 路径，`fuzzy_rank` p95           | 1366 ms（`search_in_lines`） |                    22.6 ms |
| L1 Rust | 100k 路径，`fuzzy_filter` p95       |                            — |                    0.59 ms |
| L2 FFI  | 100k 路径，每次按键 p95             |   817 ms，分配中位数 342 MiB | 2.75 ms，分配中位数 55 KiB |
| L3 UI   | repo（树视图），调度到可见 p95      |                      93.5 ms |                    18.6 ms |
| L3 UI   | 10k 路径（树视图），调度到可见 p95  |                      1649 ms |                    32.8 ms |
| L3 UI   | labels 12k（列表），调度到可见 p95  |                      99.5 ms |                    33.3 ms |
| L3 UI   | 100k 路径（树视图），调度到可见 p95 |       16.1 s，且数组输入超限 |                     147 ms |

L3 当前实现中匹配本身的 p95 不超过 2.7 ms，Lua `_display` 的 p95 不超过 4.1 ms，两者都出现在 100k 树视图。
剩余时间是 Treeview 对结果集的投影、渲染与 Neovim flush：100k 树视图调度到可见的中位数为 66 ms，其中匹配只占 1.0 ms。
