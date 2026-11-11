# Yoz Fuzzy 设计

`yoz.fuzzy` 在原生侧实现 fzf v0.74.5 的匹配、打分与扩展语法，供 picker 与 Treeview label 过滤使用。
Searcher（live grep）不使用它，走 [Yoz Search](search.md)。实现位于 `rust/yoz/src/fuzzy/`，
不依赖 Neovim，不引入新的外部依赖；Lua 类型见 [fuzzy.lua](../../../lua/__types__/yoz/fuzzy.lua)。

## 职责边界

```text
picker composer -> ResultTree:match / ListComposer -> yoz.fuzzy Corpus -> Result
                                                                         |-> ids(source) -> Treeview display filter
                                                                         `-> highlight(key) -> decorate_row
Treeview DisplayOptions.pattern -> ux/treeview/matching.rs -> fuzzy::TextMatcher（逐个 label）
```

- `yoz.fuzzy` 负责：算法、语法解析、corpus、排序、收窄缓存、并行，以及结果到 Treeview NodeId 的解析。
- 使用方负责：何时构建 corpus、匹配文本的选取（例如 root 相对路径）、权重来源（frecency）与发布节奏。
- Picker 的 regex 查询同样在 corpus 上执行（`query({ regex = true })`），方言与大小写规则同 `yoz.search`；Treeview label 过滤的
  regex 路径直接使用 `regex` crate。

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
- `\ ` 表示字面空格，`\` 本身不改写为路径分隔符。
- `fuzzy=false` 时普通词为精确子串；扩展语法仍然生效。
- 大小写：`smart` 按每个词判断，词中有大写字母时区分大小写；`respect` 始终区分，`ignore` 始终不区分。
  picker 的大小写开关打开对应 `respect`，关闭对应 `smart`。
- 去掉首尾未转义空白后为空的查询匹配全部条目。

## Corpus

### Lua API

```lua
local corpus = yoz.fuzzy.new_corpus({ scheme = "path" })            -- "default" | "path"
corpus:append(texts, keys)                                           -- 每项一个 key，或 {node, shown...}
corpus:set_weights(weights)                                          -- 每项一个字节，0..100
local result = corpus:query({ pattern = "src cfg", fuzzy = true, case = "smart", rank = true, weight = 16 })
local matched, error = corpus:query({ pattern = [[^src/.*\.rs$]], regex = true, case = "respect" })
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
- `regex=true`：按 `yoz.search` 的方言编译（`case="respect"` 时区分大小写，否则不区分），至少有一个非空匹配的条目算命中，
  按条目顺序返回，不计分、不用权重；`highlight` 标出全部非空匹配。非法表达式不抛错，`query` 返回 `nil, error`。

### 收窄缓存

- **缓存键**：沿用 fzf 的 `buildCacheKey`，由各组中单个、非排除词的文本以 tab 连接而成。fuzzy 模式下任何类型的词都参与；
  exact 模式只有精确词参与。
- **写入**：只有 cacheable 的查询会写入缓存，即不含 OR、不含排除词、每个词都保持基础类型。
- **查找**：查询前在最多 16 条缓存中找键为当前键前缀或后缀的结果，取最小的一条作为候选集。缓存按 `fuzzy` 与大小写模式区分。
- **失效**：`append` 清空缓存。
- regex 查询不读也不写缓存：正则加长不意味着命中集缩小。
- **正确性**：靠 `t_corpus_narrowing_matches_a_full_scan` 等测试和 [fzf 对齐](../../../__test__/bench/fuzzy/README.md#fzf-对齐)保证。
  一个反例是 `core |`：以 `|` 结尾时 `|` 不构成 OR，所以它的键是 `core` 而不是原文。

### 并行

- 查询先在调用线程上按块领取候选；
- 超过 100µs 仍未完成时，启动最多 `min(可用核数, 16)` 个 worker 一起领取剩余的块；
- worker 在 macOS 上设为 `USER_INTERACTIVE` QoS，避免停留在能效核；
- 各块的命中按块序拼接，所以结果与单线程完全一致；regex 查询走同一套分块与 worker。

## 接入

### ResultTree

- `ResultTree:match(params, checkpoint)`：
  - 查询都走 corpus，非空的 regex 查询以 `regex = true` 提交；非法表达式经 reporter 报告，返回空 key 数组；
  - corpus 在 Lua source revision、ResultTree revision、root、scheme 与 `weigh` 不变时复用，
    构建时逐项调用 `checkpoint`，可以让出或取消。
- 匹配文本依次取 `data.filepath`、`entry.text`、`data.name`。root 下的文件路径匹配 root 相对路径，
  root 外的路径保持绝对路径；regex 同样如此，所以 `^lua/` 匹配 root 下 `lua` 目录中的文件，root 自身的路径不参与匹配。
- 查询中写成 root 下绝对路径的部分先转为相对路径再匹配：fuzzy/exact 逐词处理（保留词首的 `!`、`'`、`^`），
  regex 处理开头（可带 `^`），root 原样或完整转义均可；`~/` 视为 home 目录；只剩 root 本身时等同空查询，列出全部条目。
  root 外的绝对路径保持原样。
- 查询词是否为路径由 `dot.path.typed_path` 判定：首段为已存在顶层目录的绝对路径，或 `~/` 开头；`/init.lua` 这类
  首段不存在的写法仍是普通查询。Find Files 的查询是 root 外的单个路径时（仍在输入 root 前缀时不算），它清空自己的查询并
  转交 Find Buffers；Find Buffers 把查询中的路径按当前目录转为列表显示的相对形式（如 `../other/b.lua`）再匹配。
- 返回的 orders 在结果集与顺序不变时保持身份，`_display` 因此不重新提交 display；高亮则始终跟随最新查询，
  并刷新当前 Frame 的装饰。
- `_display` 收到结果句柄时，用 `orders:ids(source)` 生成 filter。
- `decorate_row` 用 `highlight(key)` 取得区间，加上 root 前缀长度换算到完整路径，再映射到显示文本。

### Composer

查询的 debounce 与按键时的同步见 [Picker 按键与查询同步](../feat/picker-surface.md#picker-按键与查询同步)。

- **ListComposer**：
  - 在 2 ms 一片的准备循环中分批 `append`，与 Source 同步替换；
  - `scheme` 默认 `default`，窗口历史等路径列表使用 `path`；
  - `autosort=false` 时以 `rank=false` 保持条目顺序；
  - regex 查询同样走 corpus，不转小写，`\S` 等转义保持原义；非法表达式由 composer 报告，列表为空。
- **FiletreeComposer**：
  - `path` scheme；
  - frecency 作为权重，`weight = 16`，取值依据见[排序质量](../../../__test__/bench/fuzzy/README.md#排序质量)；
  - `prepare_filepaths` 在接管 records 后分片构建 corpus，每个文件的 frecency 只读取一次；空查询按 frecency 稳定排序。
- **TreeComposer**（LSP symbols）：`default` scheme。
- **Git Files**：`path` scheme、smart-case；目标收集用 `result:has(key)` 判断成员。
- **默认值**：
  - picker 的 select 设置默认 `flag_fuzzy=true`；
  - Searcher 的 `search_file` 默认 `false`；
  - Find Pinned Files 默认 fuzzy。

### Treeview label 过滤

`DisplayOptions.pattern` 的非 regex 路径使用 `fuzzy::TextMatcher`，匹配与高亮语义见
[Treeview Display 选项](../ux/treeview/projection.md#display-选项)。Find Explorer 与其他设置 pattern 的 Treeview 视图
因此与 picker 语义一致。

## 性能

预算按评测层级给出：L1 为不经 FFI 的 Rust core，L2 为经 Lua/native 边界的单次按键，L3 为挂 UI 的完整配置。
评测方法、语料与最新结果见 [Yoz Fuzzy 测量记录](../../../__test__/bench/fuzzy/README.md)。

| 层级    | 场景                                | 预算    |
| ------- | ----------------------------------- | ------- |
| L1 Rust | 100k 路径，`fuzzy_rank` p95         | ≤ 4 ms  |
| L1 Rust | 1M 路径，`fuzzy_rank` p95           | ≤ 40 ms |
| L2 FFI  | 100k 路径，每次按键 p95             | ≤ 8 ms  |
| L3 UI   | 不超过 50k 候选，调度到可见 p95     | ≤ 50 ms |
| L3 UI   | 100k 路径（树视图），调度到可见 p95 | 只报告  |

L3 的预算沿用 [Treeview 性能契约](../ux/treeview/performance.md) 对 filter/sort 的规定（不超过 50k 候选时 p95 ≤ 50 ms）。
100k 规模的端到端延迟由 Treeview 投影决定，L3 只报告、不判定。

## 已知问题

- 列表视图的结果收缩后，光标会跟随原条目移到末行，窗口顶部同时停在该行，上方结果不可见。
