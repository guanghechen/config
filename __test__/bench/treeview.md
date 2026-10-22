# Treeview 测量记录

本文件按场景记录 Treeview 及其 consumer 的测量方法与最新被采纳的基线，不定义 runtime 契约或性能保证。
目标与测量口径见 [性能契约](../../spec/design/treeview/performance.md)，运行入口见
[Treeview 接入](../../spec/design/treeview/integration.md)及[测试指南](../README.md#benchmarks)。
按日期的历史记录、被取代的中间数字与本机 artifact 路径保留在 git 历史中
（`git log -p -- __test__/bench/treeview.md`）。各项数字只对所注明的提交、主机与条件成立；
少量进程样本不支持生产 p95 结论。

2026-10-21 按统一结果格式（`bench/record.lua`、`bench/stats.lua`）重测了仓库内有驱动的场景：Apple M5 Pro（6P + 12E）、
外接电源、Neovim 0.12.6、release library，计时任务串行运行。`median` 在偶数个值时取中点，样本少于 20 个时不报告 p95；
单进程的 p95 只描述这一次运行。没有入库驱动的段落（压力档、结果消费者的迁移验收、普通 List 与 Find Explorer、
Grouped List、watch 扫描、Visual 聚合）保留原记录，它们按旧格式测得（p50 取下中位数，p95 不设样本下限），
不能与新格式直接比较。

## 合成投影：`treeview.lua`

`nvim -l __test__/bench/treeview.lua [tree|ancestry] [processes]`，使用 release library、附着 UI 与自然 GC；
每个进程是新的子 Neovim，统计量合并全部进程的样本。脚本覆盖无过滤与过滤态的单行更新、selection 与 filter，
filter 以 `set_display` 在收窄与放宽之间交替，计时不含 consumer 输入 debounce。只改数据的连续发布受
[8 ms 发布节奏](../../spec/design/treeview/render.md#发布节奏)约束，脚本在两次单行更新之间留出该窗口，测量孤立的一次变化。

2026-10-22：50,001 个 source 节点、50,000 行投影、96-byte label、80×48 UI，每行一个高亮组和右对齐文本；
过滤态 pattern 为 `node-`（匹配全部行），filter 在 `node-000`（100 行）与 `node-`（50,000 行）之间切换。
每条路径每进程 100 次（filter 收窄、放宽各 50 次），5 个进程。以下为 median / p95（ms），发布段从 Lua 请求 RenderPlan
到 UI flush：

| 路径                    | Tree 输入到 flush |   Tree 发布段 | Ancestry 输入到 flush | Ancestry 发布段 |
| ----------------------- | ----------------: | ------------: | --------------------: | --------------: |
| 单行更新，无过滤        |       1.11 / 3.20 |   0.91 / 2.92 |           1.40 / 2.58 |     1.17 / 2.06 |
| 单行更新，过滤态        |       1.90 / 4.24 |   1.61 / 3.93 |           1.86 / 4.08 |     1.55 / 3.57 |
| Selection               |       2.29 / 3.61 |   0.63 / 1.43 |           2.32 / 4.08 |     0.61 / 1.39 |
| Filter 收窄到 100 行    |      9.29 / 11.43 |   3.38 / 4.92 |         11.30 / 12.95 |     3.34 / 4.57 |
| Filter 放宽到 50,000 行 |     36.03 / 45.45 | 23.54 / 30.38 |         40.20 / 53.35 |   24.25 / 36.86 |

- 与[性能契约](../../spec/design/treeview/performance.md#延迟口径与目标)的对应：发布段即 render 的 Lua 发布加 redraw，
  对应“常见局部发布及当前窗口 redraw”（p95 ≤ 8 ms）；单行更新与 Selection 的输入到 flush 对应“已加载数据上的
  局部交互到 Frame flush”（p95 ≤ 16 ms）；filter 的输入到 flush 对应 50,000 驻留候选的 filter/sort 目标（p95 ≤ 50 ms）。
- 放宽到 50,000 行没有稳定达到 50 ms：Ancestry 合并 p95 为 53.35 ms，各进程 p95 为 41.3–63.2 ms；Tree 合并 45.45 ms，
  各进程 37.9–51.1 ms。尾部主要在 Lua staging（Ancestry median 19.34 / p95 31.30 ms），其次是输入到 Lua 观察到投影
  （15.95 / 17.70 ms）。同日把等待轮询从 1 ms 放宽到 20 ms 复测 Ancestry，p95 为 49.71 ms，测量 RPC 的影响在进程间波动之内。
- 旧记录的单行更新为 9.161 / 11.469 ms，其中“输入到投影完成”的 8.374 ms 实为连续更新落在发布节奏内的等待：
  同日去掉间隔的对照复现了 9.24 ms，节奏等待占 8.43 ms；孤立更新时输入到 Lua 观察到投影的 median 为 0.19 ms。
- 全局 sort、压缩链拆合、排序视图单项插入与宽目录 selected-only 变化已没有驱动，旧记录见 git 历史。

## Rust 测量测试：`ux::treeview::perf_tests`

`rust/yoz/src/ux/treeview/perf_tests.rs` 中的 release 测量默认 ignored，各自打印样本并只断言正确性：
`t_ancestry_unrelated_subtree_performance`、`t_ancestry_forest_leaf_performance`、`t_ancestry_deep_rename_performance`、
`t_filetree_support_performance`、`t_ancestry_filter_performance`。逐个运行，不并发其他 build、tests 或 benchmark：

```sh
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib <name> -- --exact --ignored --nocapture
```

2026-10-21（环境同上）：三 states 的 50k leaf 更新（`ancestry_wide_leaf`，n=100）p50 0.031 / p95 0.036 ms；
在 native owner 上准备 50k 个显式操作 roots（`task_prepare`，n=10）p50 55.672 / p95 90.302 ms，与局部 UI 交互分开；
8k 祖先过滤批次（`ancestry_filtered_batch`，n=10）p50 13.403 / p95 17.286 ms；50k 行祖先过滤的投影阶段
（`ancestry_filter_expand`，n=50）p50 15.187 / p95 15.954 ms。这些测试按 p50 / p95 打印，n=10 时 p95 接近最大值。
深度安全另由常规测试覆盖 10k 层构建、文本存储与迭代释放。

`ux::treeview::incremental::tests::t_large_multi_root_mutations_keep_retained_frames` 是显式 ignored 的压力用例：
2 GiB 预算下 200,005 个 source 节点、三个不同 root 与 Tree/List 模式的 states、三个持有的旧 frame，
覆盖 leaf/目录 rename、reparent、插删与 metadata 变化；约保留 321.1 MiB，释放全部句柄后记账归零。

## 真实数据链路：`treeview_consumers.lua`

`nvim -l __test__/bench/treeview_consumers.lua <consumer> [iterations]`，consumer 为 `filetree`、`searcher`、`git` 或 `lsp`，
默认 100 个正式样本，另有 5 次预热；使用 release library、附着 UI 和自然 GC，`lsp` 使用已安装的 Mason Lua language server。
Adapter 验收到 Treeview surface，不切换现有业务入口。

2026-10-21（环境同合成投影），单进程 100 个正式样本，各列为 median / p95（ms）：

| 链路与数据形状                                                | 输入到首批 flush | 输入到末批 flush | 数据就绪到末批 flush |
| ------------------------------------------------------------- | ---------------: | ---------------: | -------------------: |
| Filetree：真实 fs event + native readdir，128/129 个文件      |    50.83 / 54.19 |    50.83 / 54.19 |          3.24 / 5.74 |
| Searcher：native search 当前 Treeview Rust 源码，758 行，6 页 |    10.97 / 13.32 |    20.67 / 23.02 |        11.76 / 13.20 |
| Git：当前 checkout 的 status + numstat，2 行                  |    16.31 / 18.45 |    16.31 / 18.45 |          0.53 / 0.75 |
| LSP：真实 documentSymbol response，485 行                     |   17.95 / 230.20 |   17.95 / 230.20 |          4.44 / 6.02 |

- Filetree 完整时间包含 OS watch 通知等待；LSP 完整时间包含 language server 等待，其 p95 由首个请求等待 server 决定，
  不能当作已加载数据的局部交互延迟。Searcher 与 Git 的数据形状随当前源码和 checkout 状态变化。
- Searcher 测试 adapter 每页提取最多 128 行；原生结果导出的主线程成本计入测量，native poll 累计 median 2.15 / p95 2.86 ms，
  末批时间包含后续分页与发布背压。
- JSON 另保存 plan 请求/完成的 Lua 观察时点、staging、buffer 写入、Lua heap、实际 buffer bytes 与关闭成本；
  这些观察时点不冒充 Rust worker 内部提交时点。所有样本最终 queue 为 0，关闭后 data/state/query/provider/view
  与专用 buffers 均被回收；GC 检查在关闭函数返回后的独立 RPC 中执行。

## 压力档（2026-09-16）

以下来自当时的本机压力脚本（未入库），复测需按[性能契约](../../spec/design/treeview/performance.md#基线与压力档)重建：

- 12 轮三 view 流式测试：旧 query 第 10 页取消，新 query 40 × 500 项；同时输入、滚动与 Visual 持帧。
  1,071 次 Applied 输入到首个包含该 commit 的 frame flush，p95 为 36.74 ms，最大 44.39 ms；未被后续输入覆盖的
  327 次 p95 为 10.52 ms。每轮最终显示 20k 项、queue 为 0、旧 generation 无残留。压力档不套用 16 ms 目标。
- Rust 独立 allocator：50k 行 3 个 states 和 200k 行 1 个 state 各重排 20 轮，live requested allocations 稳定在
  183.02 / 601.67 MiB，单阶段峰值 221.07 / 691.02 MiB；测试显式使用 1 GiB retained、256 MiB batch 预算，
  不能据此声称默认容量通过。
- 50k 行 UI 连续 100 次 detach/attach 与各 500 项插删，旧 view 弱引用全部释放；GC 后 Lua heap 约 0.78–1.06 MiB。
  Rust requested allocations、Lua heap 和进程 RSS 按各自口径报告，不相加。

## Cursor 路径 guide：`treeview_guides.lua`

用法与口径见[测试指南](../README.md#benchmarks)。2026-10-21：50k 行、每动作 300 样本（30 次预热）、80×50 UI、
自然 GC，单进程，所有样本零正文写入。

| 操作                           | settled median ms | settled p95 ms |
| ------------------------------ | ----------------: | -------------: |
| 相邻移动（`set_cursor`）       |             0.265 |          0.449 |
| Normal `j` / `k`               |             0.371 |          1.001 |
| 视口内跨分支跳转               |             0.482 |          0.937 |
| 一个 callback 内 8 次 API 请求 |             0.563 |          0.949 |
| 原生光标移动后立即 redraw      |             0.867 |          2.263 |
| 冷跳转                         |             0.886 |          1.568 |
| 滚动                           |             0.363 |          0.988 |
| Visual 移动                    |             0.253 |          0.451 |

- 相邻/Visual 移动只提交 2 个 guide extmarks，视口内跨分支 36 个，冷跳转 48 个；冷跳转读取一次 viewport 并整窗
  redraw，滚动每次导出约 6.91 个 native 行。
- 旧格式记录（2026-10-12 前后）：80×150 UI 下 burst p95 3.387 ms、滚动 1.368 ms，200k 行时 burst 为 1.612–1.772 ms；
  真实 Explorer fixture（256 个预加载 Lua 文件、icons 与 annotation 管线，无 Git/LSP）burst p95 2.853 ms、
  滚动 4.780 ms、Normal 移动 1.449 ms，consumer 准备与重绘仍占主要成本。
- 10,000 层 source 只显示 50 段路径的情形有 native 回归覆盖；不声称渲染 10,000 列缩进也满足同一 UI 延迟目标。

## 结果消费者

`treeview_results.lua` 驱动生产 ResultPaths/ResultFiles adapter（虚拟文件记录，无文件系统扫描）。2026-10-21：
50,000 文件生成 50,500 行，producer 127 ms，首次完整 UI flush 706 ms，30 次 cursor 移动 median 0.17 / p95 0.24 ms，
native 确认 median 0.39 / p95 0.49 ms，cursor 零正文写入，保留 Lua heap 70.1 MiB；收集 101 个选中身份 5.1 ms。
单进程观察，不是延迟保证。

迁移收尾的整体验收（原始 `c55d9c6ad` 对比 runtime `543fcb2ca`，每变体 3 个独立进程，第二轮反转顺序；
驱动为当时的本机脚本，经真实 FiletreeComposer 与虚拟路径，排除文件系统发现与外部 compositor）：

| 场景（50k 文件 File Picker） | 前 → 后                 |
| ---------------------------- | ----------------------- |
| 首次 UI                      | 4.99 s → 1.45 s         |
| 相同集合刷新                 | 5.28 s → 0.63 s         |
| 初始最大 timer gap           | 4.99 s → 22.6 ms        |
| 目录折叠 / 展开              | 388 / 391 → 11 / 3.7 ms |
| 重开（零正文写入）           | 5.0 → 7.8 ms            |
| Cursor p95（零正文写入）     | 0.84 → 1.10 ms          |

- 仍存在的成本：generic 5k Tree 首次 UI 23.3 → 71.0 ms（折叠/展开约 142 → 2.5 ms）；dense Searcher 首次 UI
  148 → 108 ms，但进程 CPU 72 → 123 ms、保留 Lua 7.1 → 13.3 MiB、RSS 增量 25.8 → 36.4 MiB；Picker 初始 RSS
  278 → 303 MiB，完整交互序列结束时 351 → 313 MiB；50k Tree→List 切换仍有 O(N) 准备路径（158 ms，最大 timer gap 86 ms）。
- 没有统一加速或严格帧时间保证。RSS 是驻留量，不是存活对象数，也不是峰值。

## Diffview

`treeview_diffview.lua 10000 10` 驱动真实 Diffview 展开 action（100×40 UI）。2026-10-21，三次独立运行的中位数
（每次展开、折叠各 10 次，不足 20 个样本不报告 p95）：折叠首屏 2.69 ms，首次展开 156 ms，展开 median 6.33 ms
（单次最大 19.8 ms），折叠 median 2.13 ms；热循环零 plan 重建、导入与 icon 查找。
旧格式记录的物化缓存（对比 `07b029f0f`，5 个各 10,000 文件的 commit，3 个进程）：
保留物化节点 20,206，额外 Lua heap 42.7 MiB，RSS 增量 211 MiB，第五次展开加缓存结算 0.83 s；
单 commit 热展开约 14 ms，折叠约 6.5–6.7 ms。展开中的/当前 commit 不计入 20,000 节点的折叠缓存预算。

`diffview_navigation.lua <count> [baseline] [directories]` 测量真实 action 的路径解析，排除 preview I/O、
逻辑 cursor acknowledgement 与 UI flush。2026-10-21，只测当前版本，5 个独立进程的中位数：

| 场景                            | 冷 J ms | 热 J ms | Lua item 读取 |
| ------------------------------- | ------: | ------: | ------------: |
| List，5,000 文件                |   0.013 |   0.011 |             1 |
| List，50,000 文件               |   0.014 |   0.002 |             1 |
| 跳过 5,000 个折叠目录后定位文件 |   0.189 |   0.137 |             1 |

- 5,000 文件仅更新 metadata 后，J 为 0.018 ms，Ctrl-j 为 0.48 ms；折叠目录场景同类操作为 0.21 / 0.69 ms。
  Native leaf 查询仍扫描实际跳过的行，不承诺任意目录分布下为常数时间。

## 普通 List 与 Find Explorer

首开、过滤与清空过滤的采样入口 `treeview_migration.lua` 已随迁移期工具删除，复测需要新 runner。
最新数据：2026-10-12 Flat List producer 收敛（Apple M5 Pro、Neovim 0.12.6、100×30 attached UI，每档 5 对独立进程交替）：

| List 项数 | 首开 UI ms | 首开主线程 CPU ms | Lua heap MiB | 进程 footprint MiB |
| --------- | ---------: | ----------------: | -----------: | -----------------: |
| 1,000     |      25.04 |             12.71 |         2.41 |              11.42 |
| 10,000    |      44.45 |             26.42 |         7.82 |              40.63 |
| 50,000    |     156.59 |            108.71 |        29.30 |             171.30 |

- 50k 过滤 83.94 ms、清空过滤 95.39 ms；cursor/reopen 零正文写入。50k native Source 加一个 List State 的独立记账约
  53.1 MiB，不含 Lua、Neovim buffer 和 allocator 留存。大型 List 相对旧 Lua 平面列表的内存回退仍然存在。
- Find Explorer（macOS arm64、Neovim 0.12.5）：1,000 文件首开 45.6 ms、footprint 13.1 MiB（2026-10-12）；
  10,000 文件首开 202.2 ms、footprint 49.3 MiB（2026-10-11）。

## Grouped List 局部展开（2026-10-12）

101 个已展开分组，首组一个文件，其余 100 组持有下列文件；`list_from_depth=1`，只交替展开／折叠首组。
Apple M5 Pro、Neovim 0.12.6；native 为每档 3 对独立进程、每进程 24 次操作，UI 为每档 2 对进程、100×30 attached UI。
驱动为当时的本机脚本；5k 规模的访问量、未变行块共享与 RenderPlan 写入量另由 Rust 常规测试
`t_grouped_expansion_work_is_independent_of_unrelated_expanded_files` 断言。

| 无关文件数 | native action→Frame 中位数 ms | visited nodes | 附着 UI flush 中位数区间 ms |
| ---------- | ----------------------------: | ------------: | --------------------------- |
| 50,000     |                         0.056 |           1–3 | 0.43–0.51                   |
| 190,000    |                         0.062 |           1–3 | 0.94–1.09                   |

## 普通 Tree 折叠后的 watch 扫描（2026-10-12）

先以 List 加载 80 / 160 / 320 / 420 层真实目录，再切回普通 Tree 递归折叠隐藏 root；计时从提交命令到 Filetree
`is_settled()`（1 ms polling）。Apple M5 Pro、Neovim 0.12.6，每档 3 对独立进程，每进程 2 次预热后 24 次采样，
驱动为当时的本机脚本：深度 80 为 0.07 ms，160–420 为 1.18 ms。关闭目录不产生读取需求由常规测试
`t_collapsed_subtree_demands_no_children_at_any_depth` 断言；command→settled 包含发布与 watch reconciliation。

## Visual 范围选中聚合（2026-10-12）

测量生产 `ResultTree:toggle_selection()` 的同步 callback 成本（隔离 dispatch 与 UI，非完整按键延迟）。
Apple M5 Pro、Neovim 0.12.6，每版 3 个独立进程交错，每场景 2 次预热、24 次采样，驱动为当时的本机脚本。
表中节点均继承 root 的选中标记；空 selection 时 consumer 依据捕获 Frame 的 `summary.is_empty` 直接选择范围内节点。

| Source 深度 | 可见行数 | 范围项数 | 批量查询 ms |
| ----------: | -------: | -------: | ----------: |
|           0 |    1,000 |        2 |      0.0021 |
|           0 |   10,000 |        2 |      0.0019 |
|           0 |   50,000 |        2 |      0.0019 |
|         320 |    5,000 |    5,000 |      3.6499 |
|      10,000 |      500 |      500 |      0.8224 |

- 空 selection 的大范围首次选择：50,000 项 28.470 ms，190,000 项 140.911 ms；超大范围仍需按节点组装 command，
  不声称任意范围选择达到常数时间。
