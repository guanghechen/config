# Yoz Fuzzy 设计

`yoz.fuzzy` 在原生侧实现 fzf v0.74.5 的匹配、打分与扩展语法，供 picker 与 Treeview label 过滤使用。
Searcher（live grep）不使用它，仍走 [Yoz Search](search.md)。实现位于 `rust/yoz/src/fuzzy/`，
不依赖 Neovim，不引入新的外部依赖；Lua 类型见 [fuzzy.lua](../../../../lua/__types__/yoz/fuzzy.lua)。

## 职责边界

```text
picker composer -> ResultTree:match / ListComposer -> yoz.fuzzy Corpus -> Result
                                                                         |-> ids(source) -> Treeview display filter
                                                                         `-> highlight(key) -> decorate_row
Treeview DisplayOptions.pattern -> ux/treeview/matching.rs -> fuzzy::TextMatcher（逐个 label）
```

- `yoz.fuzzy` 负责：算法、语法解析、corpus、排序、收窄缓存、并行，以及结果到 Treeview NodeId 的解析。
- 使用方负责：何时构建 corpus、匹配文本的选取（例如 root 相对路径）、权重来源（frecency）与发布节奏。
- Regex 查询不经过 `yoz.fuzzy`：picker 继续使用 `yoz.search.search_in_lines` 的 regex 路径，Treeview 使用 `regex` crate。

## 匹配语义

### 算法

逐项移植 fzf v0.74.5 `src/algo/algo.go`（MIT，© Junegunn Choi），测试向量来自其 `algo_test.go` 与 `pattern_test.go`：

- **Fuzzy**：FuzzyMatchV2（改进的 Smith-Waterman DP，求最高分对齐）。`N × M > 100 × 1024` 或 `M > 1000` 时退回 FuzzyMatchV1
  （贪心）；一、两字符的 ASCII 模式走 fzf 的标量快速路径。
- **Exact / Prefix / Suffix / Equal**：与 fzf 相同，包括 `'x'` 两端单词边界、首尾空白的裁剪规则，以及 boundary
  打分取循环结束时 `bonus` 的行为。
- **Scheme**：
  - `default`：空白后的边界加成 10，分隔符 `/,:;|`，起点视为空白；
  - `path`：空白后的边界加成 8，分隔符只有 `/`，起点视为分隔符，并从右向左扫描，同分时取最右的对齐。
- **文本**：ASCII 文本按字节匹配；其他文本按 Unicode 字符匹配，大小写转换一对一，命中位置最后换算为原文 UTF-8 字节区间并合并成连续段。
- **与 fzf 的差异**：
  - 不做变音符号归一化，等价于 fzf `--literal`；
  - 字符类使用 Rust 的 Unicode 属性。`is_lowercase`、`is_alphabetic` 比 Go 的 `Ll`、`L` 略宽，只影响非 ASCII 文本。

### 查询语法

- 空格分隔的词全部匹配（AND），各词得分相加；`|` 连接同一组内的备选词（OR），组内第一个命中的词计分。
- `'x` 切换精确与模糊，`'x'` 为两端处于单词边界的精确匹配，`^x` 为前缀，`x$` 为后缀，`^x$` 为全等，`!x` 排除（精确），
  `!'x` 排除（模糊）。单独的 `$` 按字面处理；以 `|` 开头、结尾或连续出现的 `|` 不构成 OR。
- `\ ` 表示字面空格，`\` 本身不再改写为路径分隔符。
- `fuzzy=false` 时普通词为精确子串；扩展语法仍然生效。
- 大小写：`smart` 按每个词判断，词中有大写字母时区分大小写；`respect` 始终区分，`ignore` 始终不区分。
  picker 的大小写开关打开对应 `respect`，关闭对应 `smart`。
- 去掉首尾未转义空白后为空的查询匹配全部条目。

### fzf 对齐

`fuzzy::perf_tests::fzf_parity` 对每条查询比较 `fzf --filter QUERY --literal --scheme=<scheme>`（加 `--exact` 比较精确模式）
与本实现在无权重时的结果顺序。比较覆盖 repo、runtime、plugins、synthetic-10k/100k、labels/labels-100k 与 unicode 语料
的全部打字序列，以及一组手写的扩展语法查询。在 fzf 0.74.5 下，fuzzy 与 exact 两种模式全部一致。

## Corpus

### Lua API

```lua
local corpus = yoz.fuzzy.new_corpus({ scheme = "path" })            -- "default" | "path"
corpus:append(texts, keys)                                           -- 每项一个 key，或 {node, shown...}
corpus:set_weights(weights)                                          -- 每项一个字节，0..100
local result = corpus:query({ pattern = "src cfg", fuzzy = true, case = "smart", rank = true, weight = 16 })
result:count(); result:keys(first, last); result:same(other)
result:has(key); result:highlight(key)
local filter = result:ids(source)                                    -- yoz.ux.treeview.NodeIds
```

- 一个 corpus 最多 16,777,216 项（打包排序使用 24 位序号）；单次 `keys` 读取最多 1,048,576 项。非法 UTF-8 替换为 U+FFFD，
  命中位置以替换后的文本为准。
- 每项必须带 keys：Treeview 节点 key，或依次为该节点与随它显示的节点（如 location）的数组。`keys`、`has`、`highlight`
  按每项的第一个 key 读写；`ids(source)` 对同一 Treeview source（identity + revision）只解析一次全部 key，之后每个结果
  按排名拼出 NodeId 句柄。句柄可直接作为 `DisplayOptions.filter`，不经过 Lua 数组，因此不受 200,000 项上限约束。

### 排序

- `rank=true`：
  - 主键为 fzf 分数加权重加成 `round(weight × w / 100)`，按降序排列；
  - 分数按 fzf 的 `AsUint16` 饱和到 16 位；
  - 同分时：`path` scheme 依次比较 pathname（命中起点到最后一个 `/` 或 `\` 的距离，饱和到 255，与 fzf 相同）、去空白长度、条目序号；
    `default` scheme 依次比较长度、条目序号。
- `rank=false`：只判定成员，保持条目顺序，fuzzy 词用 `asciiFuzzyIndex` 判定，跳过 DP。
- 空查询或只有排除词时，没有可比的分数：`weight > 0` 时按原始权重降序、同权重保持条目顺序，否则保持条目顺序。
- 实现：命中打包为 64 位键，用稳定的 LSD radix sort 排序，跳过所有命中都相同的字节。
  命中按条目顺序进入，所以序号决胜由稳定性保证。

### 收窄缓存

- **缓存键**：沿用 fzf 的 `buildCacheKey`，由各组中单个、非排除词的文本以 tab 连接而成。fuzzy 模式下任何类型的词都参与；
  exact 模式只有精确词参与。
- **写入**：只有 cacheable 的查询会写入缓存，即不含 OR、不含排除词、每个词都保持基础类型。
- **查找**：查询前在最多 16 条缓存中找键为当前键前缀或后缀的结果，取最小的一条作为候选集。缓存按 `fuzzy` 与大小写模式区分。
- **失效**：`append` 清空缓存。
- **正确性**：靠 `t_corpus_narrowing_matches_a_full_scan` 等测试和 fzf 对齐保证。一个反例是 `core |`：以 `|` 结尾时
  `|` 不构成 OR，所以它的键是 `core` 而不是原文。

### 并行

- 查询先在调用线程上处理，按每块 256 个候选领取；
- 超过 100µs 仍未完成时，启动最多 `min(可用核数, 16)` 个 worker 一起领取剩余的块；
- worker 在 macOS 上设为 `USER_INTERACTIVE` QoS，避免停留在能效核；
- 各块的命中按块序拼接，所以结果与单线程完全一致。

## 接入

### ResultTree

- `ResultTree:match(params, checkpoint)`：
  - 非空的 regex 查询走 `search_in_lines`，返回 key 数组，同一条目只出现一次；
  - 其余查询走 corpus。corpus 在 Lua source revision、ResultTree revision、root、scheme 与 `weigh` 不变时复用，
    构建时逐项调用 `checkpoint`，可以让出或取消。
- 匹配文本依次取 `data.filepath`、`entry.text`、`data.name`。root 下的文件路径匹配 root 相对路径，
  root 外的路径保持绝对路径。
- 返回的 orders 在结果集与顺序不变时保持身份，`_display` 因此不重新提交 display；高亮则始终跟随最新查询，
  并刷新当前 Frame 的装饰。
- `_display` 收到结果句柄时，用 `orders:ids(source)` 生成 filter。
- `decorate_row` 用 `highlight(key)` 取得区间，加上 root 前缀长度换算到完整路径，再映射到显示文本。

### Composer

- **ListComposer**：
  - 在 2 ms 一片的准备循环中分批 `append`，与 Source 同步替换；
  - `scheme` 默认 `default`，窗口历史等路径列表使用 `path`；
  - `autosort=false` 时以 `rank=false` 保持条目顺序；
  - regex 查询不再转小写，`\S` 等转义保持原义。
- **FiletreeComposer**：
  - `path` scheme；
  - frecency 作为权重，`weight = 16`；
  - `prepare_filepaths` 在接管 records 后分片构建 corpus，每个文件的 frecency 只读取一次；空查询按 frecency 稳定排序。
- **TreeComposer**（LSP symbols）：`default` scheme。
- **Git Files**：`path` scheme、smart-case；目标收集用 `result:has(key)` 判断成员。
- **默认值**：
  - picker 的 select 设置默认 `flag_fuzzy=true`，已持久化的值不变；
  - Searcher 的 `search_file` 保持默认 `false`；
  - Find Pinned Files 默认 fuzzy。

### Treeview label 过滤

`DisplayOptions.pattern` 的非 regex 路径使用 `fuzzy::TextMatcher`：

- 查询只解析一次，DP scratch 放在 worker 的 thread-local 中；
- 采用 `path` scheme 与上述大小写规则，`fuzzy=false` 时普通词为精确子串；
- 每个 label 只高亮一个对齐，高亮按字节区间合并；
- regex 路径不变，仍高亮全部匹配。

Find Explorer 与其他设置 pattern 的 Treeview 视图因此与 picker 语义一致。

## 性能

所有数据来自 Apple M5 Pro（6P + 12E）、外接电源、NVIM v0.12.6，基线为提交 `117a4fc88`。

| 层级 | 场景 | 基线 | 当前 | 预算 |
| --- | --- | ---: | ---: | --- |
| L1 Rust | 100k 路径，`fuzzy_rank` p95 | 120 ms（`search_in_lines`） | 2.06 ms | ≤ 4 ms |
| L1 Rust | 1M 路径，`fuzzy_rank` p95 | 1383 ms | 21.0 ms | ≤ 40 ms |
| L1 Rust | 100k 路径，`fuzzy_filter` p95 | — | 0.59 ms | — |
| L2 FFI | 100k 路径，每次按键 p95 | 817 ms，分配 350 MB | 2.87 ms，分配 44 KB | ≤ 8 ms |
| L3 UI | repo，调度到可见 p95 | 102 ms | 11.4 ms | ≤ 50 ms |
| L3 UI | 10k 路径（树视图），调度到可见 p95 | 1491 ms | 31.2 ms | ≤ 50 ms |
| L3 UI | labels 12k（列表），调度到可见 p95 | 83 ms | 18.7 ms | ≤ 50 ms |
| L3 UI | 100k 路径（树视图），调度到可见 p95 | 14.6 s，且数组输入超限 | 144 ms | 只报告 |

L3 中匹配本身的 p95 不超过 2.3 ms，Lua `_display` 不超过 2 ms。剩余时间是 Treeview 对结果集的投影、渲染与 Neovim flush：

- 10k 规模的单字符查询约有 6k 行，p50 约 15 ms；
- 100k 规模的单字符查询约有 8.2 万行，p50 约 108 ms。

L3 的预算沿用 [Treeview 性能契约](../../treeview/performance.md) 对 filter/sort 的规定（不超过 50k 候选时 p95 ≤ 50 ms）。
100k 规模的端到端延迟由 Treeview 投影决定，L3 只报告、不判定。

## 评测

```sh
node script/benchmark/fuzzy-corpus.mjs --out __test__/bench/results/fuzzy/corpus   # 语料，固定种子 0x5eed1234
node script/benchmark/fuzzy.mjs --build --baseline-rev 117a4fc88 --runs 3          # L1、L2、L3
node script/benchmark/fuzzy.mjs --level e2e --case files_10k_tree --build --runs 20
```

- **输出**：结果写入 `__test__/bench/results/fuzzy/<时间戳>/`（git 忽略），包括 `metadata.json`、`results.jsonl`、`summary.json`
  与 `report.md`。
- **构建**：`--build` 把与源码绑定的原生库构建到 `results/fuzzy/native/`，过期的构建会被替换；
  `--current DIR` 可以对工作树的快照计时，主工作树在评测期间可以继续修改。
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
- **统计**：每个进程取中位数，再跨进程取中位数；L3 的按键样本合并统计。进程数达到 20 才报告进程级 p95。
  标定循环显著变慢的进程（疑似跑在能效核上）会被标记。
- **排序质量**：`fuzzy::perf_tests::fuzzy_quality`。
  - 方法：按 L3 的口径给 2% 的条目分配 frecency，统计每个打字序列的目标在每次按键后的名次；分两种场景，目标本身常用（frecency 60）与目标不常用。
  - 结论：权重 8–16 时，常用目标的 MRR 从约 0.24–0.45 提升到 0.51–0.81，不常用目标的 MRR 下降约 0.01–0.03；
    权重达到 32 以上，不常用目标明显变差。默认权重取 16。

## 已知问题

- 列表视图的结果收缩后，光标会跟随原条目移到末行，窗口顶部同时停在该行，上方结果不可见。基线版本同样存在这个问题。
