# Treeview 测量记录

本文记录 Treeview 及其 consumer 的测量方法与最新基线，不定义契约。目标与口径见
[性能契约](../../spec/design/treeview/performance.md)，运行入口见[测试指南](../README.md#benchmarks)；
旧数字留在 git 历史（`git log -p -- __test__/bench/treeview.md`）。

除另注外，基线于 2026-10-22 测得：Apple M5 Pro（6P + 12E）、外接电源、Neovim 0.12.6、release library、附着 UI、
自然 GC，计时任务串行。统计采用[统一结果格式](../README.md#benchmarks)：偶数个值的 median 取中点，少于 20 个值不报告 p95。
数字只对所注明的条件成立，少量进程不支持生产 p95 结论。

## 合成投影：`treeview.lua`

```sh
nvim -l __test__/bench/treeview.lua [tree|ancestry] [processes]
```

每个进程是新的子 Neovim，统计合并全部进程的样本。数据为 50,001 个 source 节点、50,000 行投影、96-byte label，
80×48 UI，每行一个高亮组和右对齐文本。

- 单行更新分无过滤与过滤态（pattern `node-` 匹配全部行）。两次更新之间留出
  [8 ms 发布节奏](../../spec/design/treeview/render.md#发布节奏)，测孤立的一次变化。
- Filter 以 `set_display` 在 `node-000`（100 行）与 `node-`（50,000 行）之间交替收窄与放宽。
- 名次 filter 是 Picker 的做法：Yoz Fuzzy corpus 的 `Result:ids` 直接交给 SetDisplay。匹配集同上，名次由 frecency
  式权重与 source 顺序交错；Ancestry 的 List 按名次排列，Tree 保持 source 顺序。
- 计时不含 consumer 输入 debounce 与 corpus 查询。发布段从 Lua 请求 RenderPlan 到 UI flush。

每条路径每进程 100 次（filter 收窄、放宽各 50 次），5 个进程，median / p95（ms）：

| 路径                         | Tree 输入到 flush |  Tree 发布段 | Ancestry 输入到 flush | Ancestry 发布段 |
| ---------------------------- | ----------------: | -----------: | --------------------: | --------------: |
| 单行更新，无过滤             |       1.64 / 2.58 |  1.38 / 2.23 |           1.76 / 2.47 |     1.45 / 2.09 |
| 单行更新，过滤态             |       2.19 / 4.04 |  1.86 / 3.76 |           1.96 / 4.23 |     1.68 / 3.80 |
| Selection                    |       2.32 / 3.14 |  0.62 / 1.26 |           2.27 / 3.05 |     0.60 / 1.35 |
| Filter 收窄到 100 行         |       7.67 / 9.57 |  3.23 / 5.12 |          9.76 / 11.26 |     3.26 / 4.72 |
| Filter 放宽到 50,000 行      |     15.72 / 21.11 | 9.10 / 14.53 |         17.05 / 23.59 |    9.34 / 15.82 |
| 名次 filter 收窄到 100 行    |       6.81 / 8.24 |  3.18 / 4.56 |           8.59 / 9.00 |     2.97 / 3.29 |
| 名次 filter 放宽到 50,000 行 |     15.56 / 20.26 | 9.26 / 13.95 |         26.39 / 32.22 |   12.25 / 18.02 |

- 对应[性能契约](../../spec/design/treeview/performance.md#延迟口径与目标)：发布段即"常见局部发布及当前窗口 redraw"
  （p95 ≤ 8 ms）；单行更新与 Selection 的输入到 flush 即"已加载数据上的局部交互到 Frame flush"（p95 ≤ 16 ms）；
  filter 的输入到 flush 即 50,000 驻留候选的 filter/sort（p95 ≤ 50 ms）。
- 最慢的是 Ancestry 的名次 filter 放宽，即 Picker 的 List：投影 14.0 ms、staging 7.6 ms（median），按名次随机访问节点
  构建并导出 ancestry 文本。Tree 保持 source 顺序，与按 pattern 放宽相当。
- 2 ms 以内的数字随运行时段波动：同日各轮的单行更新 median 在 0.84–1.76 ms 之间，比较版本须交替运行。

## Rust 测量：`ux::treeview::perf_tests`

```sh
cargo test --manifest-path rust/Cargo.toml -p yoz --release --lib \
  ux::treeview::perf_tests::<test> -- --exact --ignored --nocapture
```

release 测量默认 ignored，打印样本统计并只断言正确性；逐个运行，不并发其他任务。

| 测试                                       | 输出                      | 场景                                               |   n | p50 ms | p95 ms |
| ------------------------------------------ | ------------------------- | -------------------------------------------------- | --: | -----: | -----: |
| `t_ancestry_unrelated_subtree_performance` | `unrelated_subtree`       | 6 个小范围 List states 之外的更新，Label           | 100 |  0.003 |  0.004 |
|                                            |                           | 同上，Ancestry                                     | 100 |  0.004 |  0.004 |
| `t_ancestry_forest_leaf_performance`       | `forest_leaf`             | 1,000 层链下 2,000 个 Forest roots 之一更新，Label | 100 |  0.016 |  0.027 |
|                                            |                           | 同上，Ancestry                                     | 100 |  0.017 |  0.028 |
| `t_ancestry_deep_rename_performance`       | `ancestry_deep_rename`    | 8,000 层祖先链 rename                              |  10 |  7.866 |  8.127 |
|                                            | `ancestry_filtered_batch` | 同一链过滤到 1 行可见的批次                        |  10 | 13.734 | 16.006 |
| `t_filetree_support_performance`           | `ancestry_wide_leaf`      | 三 states 的 50k leaf 更新                         | 100 |  0.032 |  0.034 |
|                                            | `task_prepare`            | 在 native owner 上准备 50k 个操作 roots            |  10 | 50.992 | 53.509 |
|                                            | `task_unrelated_insert`   | 持有 50k roots 时的无关插入                        | 100 |  0.004 |  0.009 |
| `t_ancestry_filter_performance`            | `ancestry_filter_expand`  | 祖先过滤放宽到 50k 行，投影                        |  50 |  7.029 |  7.503 |
|                                            |                           | 同上，RenderPlan                                   |  50 |  0.223 |  0.256 |
|                                            |                           | 同上，导出                                         |  50 |  0.463 |  0.491 |
| `t_ranked_filter_performance`              | `ranked_filter_expand`    | 按名次放宽到 50k 行，List                          |  50 | 10.662 | 11.418 |
|                                            |                           | 同上，Tree                                         |  50 |  5.855 |  6.376 |

- n = 10 时 p95 接近最大值。`ancestry_deep_rename` 与 `ancestry_filtered_batch` 另测 1k–4k 层，随深度线性增长。
  `task_prepare` 是一次性准备，与局部 UI 交互分开。
- 压力用例 `ux::treeview::incremental::tests::scale::t_large_multi_root_mutations_keep_retained_frames`（显式
  ignored）：2 GiB 预算下 200,005 个 source 节点、三个不同 root 与 Tree/List 模式的 states、三个持有的旧 frame，
  覆盖 leaf/目录 rename、reparent、插删与 metadata 变化；mutations 65.6 ms，保留约 251.4 MiB，释放全部句柄后记账归零。
  深度安全另由常规测试覆盖 10k 层构建、文本存储与迭代释放。

## 真实数据链路：`treeview_consumers.lua`

```sh
nvim -l __test__/bench/treeview_consumers.lua <filetree|searcher|git|lsp> [iterations]
```

默认 100 个正式样本，另有 5 次预热；`lsp` 使用 Mason 安装的 Lua language server。Adapter 只验收到 Treeview surface，
不切换现有业务入口。单进程，median / p95（ms）：

| 链路与数据形状                                                | 输入到首批 flush | 输入到末批 flush | 数据就绪到末批 flush |
| ------------------------------------------------------------- | ---------------: | ---------------: | -------------------: |
| Filetree：真实 fs event + native readdir，128/129 个文件      |    50.57 / 52.83 |    50.57 / 52.83 |          2.55 / 3.93 |
| Searcher：native search 当前 Treeview Rust 源码，763 行，6 页 |    10.74 / 13.50 |    20.28 / 22.96 |        11.81 / 12.90 |
| Git：当前 checkout 的 status + numstat，9 行                  |    18.20 / 20.52 |    18.20 / 20.52 |          0.71 / 1.14 |
| LSP：真实 documentSymbol response，485 行                     |   18.37 / 227.12 |   18.37 / 227.12 |          4.15 / 5.80 |

- Filetree 包含 OS watch 通知等待，LSP 包含 language server 等待；LSP 的 p95 由首个请求等待 server 决定，
  不是已加载数据的局部交互延迟。Searcher 与 Git 的数据形状随当前源码和 checkout 状态变化。
- Searcher 每页提取最多 128 行，原生结果导出计入测量，native poll 累计 median 2.20 / p95 2.96 ms；末批时间包含
  后续分页与发布背压。
- JSON 另存 plan 请求/完成时点、staging、buffer 写入、Lua heap、buffer bytes 与关闭成本。关闭后 data/state/
  query/provider/view 与专用 buffer 必须被回收：Git 模式约 5% 的运行在这一检查失败，原因是 bench 自身经
  `vim.defer_fn` 轮询的闭包偶被 LuaJIT trace 留住，与被测代码无关，重跑即可。

## Cursor 路径 guide：`treeview_guides.lua`

用法与口径见[测试指南](../README.md#benchmarks)。50k 行、每动作 300 样本（30 次预热）、80×50 UI，单进程，
所有样本零正文写入：

| 操作                           | settled median ms | settled p95 ms |
| ------------------------------ | ----------------: | -------------: |
| 相邻移动（`set_cursor`）       |             0.234 |          0.390 |
| Normal `j` / `k`               |             0.291 |          0.688 |
| 视口内跨分支跳转               |             0.484 |          0.804 |
| 一个 callback 内 8 次 API 请求 |             0.538 |          0.952 |
| 原生光标移动后立即 redraw      |             0.593 |          1.085 |
| 冷跳转                         |             0.891 |          1.518 |
| 滚动                           |             0.304 |          0.883 |
| Visual 移动                    |             0.238 |          0.404 |

- 相邻与 Visual 移动只提交 2 个 guide extmarks，视口内跨分支 36 个，冷跳转 48 个；冷跳转读取一次 viewport
  并整窗 redraw，滚动每次导出约 6.91 个 native 行。
- 10,000 层 source 只显示 50 段路径的情形有 native 回归覆盖；不声称渲染 10,000 列缩进也满足同一延迟目标。

## 结果消费者：`treeview_results.lua`

`nvim -l __test__/bench/treeview_results.lua 50000` 驱动生产 ResultPaths/ResultFiles adapter：虚拟文件记录，
无文件系统扫描，100×40 UI。

3 个进程的中位数：50,000 文件生成 50,500 行，producer 124 ms，首次完整 UI flush 681 ms；30 次 cursor 移动
median 0.16 / p95 0.20 ms，native 确认 median 0.39 / p95 1.04 ms，cursor 零正文写入；保留 Lua heap 70.1 MiB；
收集 101 个选中身份 2.9 ms。不是延迟保证。

## Diffview

`nvim -l __test__/bench/treeview_diffview.lua 10000 10` 驱动真实 Diffview 展开 action，100×40 UI。

三次独立运行的中位数（展开、折叠各 10 次，不足 20 个样本不报告 p95）：折叠首屏 2.42 ms，首次展开 155 ms，
展开 median 3.66 ms（单次最大 4.18 ms），折叠 median 2.02 ms；热循环零 plan 重建、导入与 icon 查找。

`nvim -l __test__/bench/diffview_navigation.lua <count> [baseline] [directories]` 测量真实 action 的路径解析，
不含 preview I/O、逻辑 cursor 确认与 UI flush。

5 个独立进程的中位数：

| 场景                            | 冷 J ms | 热 J ms | metadata 后 J ms | metadata 后 Ctrl-j ms | Lua item 读取 |
| ------------------------------- | ------: | ------: | ---------------: | --------------------: | ------------: |
| List，5,000 文件                |   0.011 |   0.002 |            0.018 |                  0.51 |             1 |
| List，50,000 文件               |   0.018 |   0.002 |            0.019 |                  0.48 |             1 |
| 跳过 5,000 个折叠目录后定位文件 |   0.179 |   0.133 |            0.214 |                  0.70 |             1 |

Native leaf 查询仍扫描实际跳过的行，不承诺任意目录分布下为常数时间。

## 无驱动的旧记录

以下场景的驱动已删除或从未入库，复测需要新 runner。数字按旧格式测得（p50 取下中位数，p95 不设样本下限），
不能与上文直接比较。

- **压力档**（2026-09-16）：12 轮三 view 流式测试（旧 query 第 10 页取消，新 query 40 × 500 项，同时输入、滚动与 Visual
  持帧），1,071 次 Applied 输入到 flush 的 p95 为 36.74 ms、最大 44.39 ms，未被后续输入覆盖的 327 次 p95 为 10.52 ms；
  压力档不套用 16 ms 目标。独立 allocator 下 50k 行 3 个 states 与 200k 行 1 个 state 各重排 20 轮，live allocations
  稳定在 183.02 / 601.67 MiB（显式 1 GiB retained 预算，不代表默认容量通过）；50k 行 UI 连续 100 次 detach/attach
  后旧 view 全部释放。
- **迁移验收**（`c55d9c6ad` → `543fcb2ca`，50k 文件 File Picker）：首次 UI 4.99 → 1.45 s，相同集合刷新 5.28 → 0.63 s，
  初始最大 timer gap 4.99 s → 22.6 ms，目录折叠/展开 388/391 → 11/3.7 ms。代价：generic 5k Tree 首次 UI
  23.3 → 71.0 ms；dense Searcher 进程 CPU 72 → 123 ms、保留 Lua 7.1 → 13.3 MiB；50k Tree→List 切换仍有 O(N)
  准备路径（158 ms）。
- **普通 List 与 Find Explorer**（2026-10-11/12，早于 2026-10-22 的投影优化）：1k / 10k / 50k 项首开 UI
  25.0 / 44.5 / 156.6 ms，进程 footprint 11.4 / 40.6 / 171.3 MiB；50k 过滤 83.9 ms、清空过滤 95.4 ms。大型 List 的
  内存仍高于旧 Lua 平面列表。Find Explorer 1k / 10k 文件首开 45.6 / 202.2 ms。
- **Grouped List 局部展开**（2026-10-12）：5 万 / 19 万个无关文件时 native action→Frame 0.056 / 0.062 ms，UI flush
  0.43–1.09 ms；工作量与无关文件无关由 `t_grouped_expansion_work_is_independent_of_unrelated_expanded_files` 守护。
- **折叠后的 watch 扫描**（2026-10-12）：80–420 层目录递归折叠后，命令到 settled 为 0.07–1.18 ms；折叠目录不产生读取
  需求由 `t_collapsed_subtree_demands_no_children_at_any_depth` 守护。
- **Visual 范围选中**（2026-10-12，`ResultTree:toggle_selection()` 的同步 callback）：继承 root 标记时 2 项范围约
  0.002 ms，深度 320 的 5,000 项 3.65 ms；空 selection 下首次选择 50,000 / 190,000 项 28.5 / 140.9 ms。
