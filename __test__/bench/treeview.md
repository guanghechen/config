# Treeview 测量记录

本文件归档特定版本与环境下的测量结果，不定义当前 runtime 契约或性能保证。
目标与测量口径见 [性能契约](../../spec/design/treeview/performance.md)，运行入口见
[Treeview 接入](../../spec/design/treeview/integration.md)及[测试指南](../README.md#native-result-consumers)。
历史本地 artifact 路径按原记录保留，不保证其他 checkout 可用。

## 2026-09-16 局部投影与数据链路

2026-09-16 补齐局部投影后的合成 UI 样本：Apple M2 Max / 32 GiB、Darwin 27 arm64、Neovim 0.12.5，release build；
50,001 个 source 节点、50,000 行投影、96-byte label、80×48 UI，每行两处高亮和右对齐文本。
单行更新、Selection、filter 各 100 次；sort 300 次，额外持有初始 frame。各轮均单独运行，包含自然 GC。
以下为输入到适用 frame 的 UI flush 延迟：

| 路径        | p50 ms | p95 ms | max ms |
| ----------- | -----: | -----: | -----: |
| 单行更新    | 0.903  | 3.369  | 7.131  |
| Selection   | 3.409  | 4.266  | 6.328  |
| 全局 filter | 16.776 | 41.464 | 43.421 |
| 全局 sort   | 45.241 | 48.788 | 50.735 |

与[性能契约](../../spec/design/treeview/performance.md#延迟口径与目标)的对应：单行更新与 Selection 两行对应
“常见局部发布及当前窗口 redraw”（p95 ≤ 8 ms）和“局部交互到 Frame flush”（p95 ≤ 16 ms）；全局 filter 与 sort 两行对应
50,000 驻留候选的 filter/sort 目标（p95 ≤ 50 ms）。`__test__/bench/treeview.lua` 的 filter 路径以 `set_display` 切换 pattern，
计时不含 consumer 输入 debounce；当前脚本只包含 text、selection 与 filter 三条路径。“全量结构布局”目标没有对应记录。

压缩链拆合、排序视图单项插入各 100 次，p95 分别为 2.15 / 1.90 ms；修复前对应值为 8.88 / 9.69 ms。
另一个宽目录含 50,000 个直接 children；selected-only 单项变化 p95 为 5.41 ms。
结构测试同时断言重算节点小于 20、至少 49,800 行及匹配子项保持块共享，并与独立全量投影对照。
15 组模式组合覆盖 4,500 次 mixed updates、旧 frame、hidden/foldable、选中/展开、label/score 和 reparent。
Rust workspace/all-target 338 项通过（另 1 项性能测试默认忽略），Lua/UI 17 项通过；UI 包含 Visual 内 connector 更新。

2026-09-16 补充真实数据链路验收。运行 `nvim -l __test__/bench/treeview_consumers.lua <consumer> [samples]`，
consumer 为 `filetree`、`searcher`、`git` 或 `lsp`，默认 100 个正式样本，另有 5 次预热。
脚本使用 release library、附着 UI 和自然 GC；`lsp` 使用已安装的 Mason Lua language server。
Adapter 位于测试 fixture，验收到 Treeview surface，不切换现有业务入口。

| 链路与数据形状                                                | 输入到首批 flush p95 | 输入到末批 flush p95 | 数据就绪到末批 flush p95 |
| ------------------------------------------------------------- | -------------------: | -------------------: | -----------------------: |
| Filetree：真实 fs event + native readdir，128/129 个文件      | 52.69 ms             | 52.69 ms             | 2.40 ms                  |
| Searcher：native search 当前 Treeview Rust 源码，507 行，4 页 | 7.51 ms              | 28.98 ms             | 24.92 ms                 |
| Git：当前 checkout 的 status + numstat，52 行                 | 36.39 ms             | 36.39 ms             | 2.86 ms                  |
| LSP：真实 documentSymbol response，315 行                     | 220.58 ms            | 220.58 ms            | 5.11 ms                  |

Filetree 完整时间包含 OS watch 通知等待；LSP 完整时间包含 language server 等待，不能当作已加载数据的局部交互延迟。
Searcher 原生 job 完成后提供完整结果，测试 adapter 每页提取最多 128 行；原生结果导出的主线程成本也计入测量，
本组 native poll 累计 p95 为 1.87 ms，末批时间包含后续分页与发布背压。
JSON 另保存 plan 请求/完成的 Lua 观察时点、staging、buffer 写入、Lua heap、实际 buffer bytes 与关闭成本；
这些观察时点不冒充 Rust worker 内部提交时点。所有样本最终 queue 为 0，没有持久逐行 extmarks，关闭后弱引用中的
data/state/query/provider/view 和专用 buffers 均已回收。GC 检查在关闭函数返回后的独立 RPC 中执行，
避免关闭栈临时引用影响弱引用检查；关闭与 GC 成本分别记录。
另对当前 `view.lua` 做了 100 次真实 Tree-sitter 解析、Lua 提取与 UI 发布，28 个函数节点，完整 flush p95 为 4.17 ms。

补充压力结果与适用范围：

- 50k 行局部路径的访问节点数、行块/子项索引共享与实际正文差量已分别验证，不能只用延迟推断复杂度。
- 12 轮三 view 流式测试：旧 query 第 10 页取消，新 query 40 × 500 项；同时输入、滚动与 Visual 持帧。
  1,071 次 Applied 输入到首个包含该 commit 的 frame flush，p95 为 36.74 ms，最大 44.39 ms。
  其中 744 次 cursor 状态在发布前被后续输入覆盖，未被覆盖的 327 次 p95 为 10.52 ms。另有 369 次 MissingNode 拒绝，来自旧 frame 引用已被查询替换的节点。
  输入完成与 publication/flush 独立记录后关联，避免完成通知晚于发布时漏算，也不要求已经显示的 frame 仍是此刻最新。
  每轮最终显示 20k 项、queue 为 0、旧 generation 无残留。压力档结果不套用静态基线的 16 ms 目标。
- Rust 独立 allocator：96-byte label、path payload、highlight/right text、旧 frame；50k 行 3 个 states 和
  200k 行 1 个 state 各重排 20 轮，live requested allocations 分别稳定在 183.02 / 601.67 MiB，
  单阶段峰值为 221.07 / 691.02 MiB。测试显式使用 1 GiB retained、256 MiB batch 预算，不能据此声称默认容量通过。
  20k 项、3 个 states 的查询替换经过容量增长后稳定在 140.00 MiB，峰值 204.44 MiB；旧 frame 释放后降至 83.00 MiB。
  释放 engine 后分别剩余 40 / 0 / 0 bytes；40 bytes 为首次初始化的共享静态空 fields。
- 50k 行 UI 连续 100 次 detach/attach 与各 500 项插删，旧 view 弱引用全部释放，关闭后只剩原始 buffer。
  GC 后 Lua heap 保持约 0.78–1.06 MiB，关闭后约 0.87 MiB。5 ms 采样得到的 Lua heap / 进程 RSS 峰值分别为
  36.16 / 175.13 MiB；采样可能遗漏短暂峰值。Rust requested allocations、Lua heap 和进程 RSS 按各自口径报告，
  不相加或用 allocator 保留的 RSS 推断泄漏。

本轮原始结果、压力脚本与 snapshot 位于 `local/20260916/treeview-local-completion/`；前轮记录保留在
`local/20260916/treeview-verification/`。它们是验收记录，不是设计契约。

## 2026-10-11 全面迁移采样

以 `87db4409` 的 List/Find Explorer/共享 surface Lua 入口作为 baseline overlay，共用同一 native library；
legacy `readdir`/search 实现未变。使用 [`treeview_migration.lua`](treeview_migration.lua)，
100×30 attached UI、相同只读 fixture，每组 5 个独立 Neovim 进程交替运行，以下为中位数。
环境为 macOS 27.0.1 arm64、Neovim 0.12.5 Release、LuaJIT 2.1、libuv 1.53.0。
数据准备不计时；首开包含模块加载与 producer/native 导入。2 ms 观察器确认目标 Frame 后显式 redraw/flush，
不测外部 compositor；样本数量不支持生产 p95 结论。原始结果保留于本次交付的 benchmark artifacts。
过滤和清空通过 Finder 的 `set_content()` 更新真实输入 buffer 与 Observable，避免初始 TextChanged 覆盖测试输入。

| 场景                       | 首开 ms，旧→新 | 过滤 ms，旧→新 | 清空过滤 ms，旧→新 | 进程 footprint MiB，旧→新 |
| -------------------------- | -------------- | -------------- | ------------------ | ------------------------- |
| 普通 List，1,000 项        | 216.3 → 34.6   | 198.2 → 66.8   | 195.3 → 67.0       | 7.6 → 11.4                |
| 普通 List，10,000 项       | 224.7 → 72.9   | 203.0 → 71.7   | 207.5 → 75.8       | 15.7 → 47.5               |
| 普通 List，50,000 项       | 238.7 → 248.2  | 209.5 → 91.2   | 214.7 → 107.0      | 47.3 → 196.8              |
| Find Explorer，1,000 文件  | 361.3 → 47.6   | 196.8 → 67.9   | 274.4 → 71.7       | 18.4 → 13.9               |
| Find Explorer，10,000 文件 | 1414.0 → 202.2 | 214.5 → 70.1   | 689.8 → 78.6       | 93.1 → 49.3               |

- 延迟改善包含移除第二层 128 ms render debounce；输入 debounce 仍为 64 ms，不能将全部降幅解释为计算加速。
- 10,000 文件首开的 main-thread CPU 从 1207.5 ms 降为 54.1 ms；最大 tick gap 的中位数从 734.5 ms 降为 26.4 ms。
  新旧 cursor/reopen 均为零正文写入；新版重开可显示时间约 2–3 ms。恢复 watch 后尚未接受的 reconciliation 不属于这一显示时点。
- Footprint 是上述操作后 GC 的 Darwin/libuv `physical_footprint`，包含 allocator 保留空间；不等同于 Lua heap 或 Rust 独占内存。
  普通 List 使用完整 native data/state，10,000 项的首开 main-thread CPU 为 46.8 ms（旧版 22.5 ms），空间成本仍高于旧平面列表。
- 50,000 项 List 的首开 main-thread CPU 为 175.6 ms（旧版 57.6 ms），最大 tick gap 中位数为 30.0 ms（旧版 27.9 ms）。
  Native source 与一个 List State 的独立记账约为 62 MiB，不含 Lua、Neovim buffer 和 allocator 留存。
  大型 List 的内存回退仍未消除；冷启动接近旧版不能代表迁移的全部性能成本已解决。
- 首次空 Data 导入直接构建 source/key/sibling 索引，保留完整校验与失败原子性；有状态的数据继续按原契约对齐。
  同父节点的连续尾部插入批量维护 sibling 索引，外部写入仍使旧 children read epoch 失效。
  Plain List producer 分片准备；纯文本签名和稀疏可选列减少 Lua 序列化与默认值副本。

## 2026-10-12 迁移收尾与索引压缩采样

本节对比 `48f30fa57` 和 `7209211cd`；baseline 已使用 native Treeview，不是上一节的旧 Lua renderer。
保留 baseline Lua overlay 与 native library，使用同一 fixture，5 个独立进程交替运行，每轮反转执行顺序。
环境为 macOS arm64、Neovim 0.12.5 Release、LuaJIT 2.1、libuv 1.53.0。下表均为进程间中位数。

Diffview 使用 [`diffview_navigation.lua`](diffview_navigation.lua) 测量真实 action 的路径解析，
排除 preview I/O、逻辑 cursor acknowledgement 和 UI flush。相邻文件查询留在 native Frame，Lua 只读取最终目标；
commit 和刷新定位按 identity 查询，目录 transfer 直接跳过原生子树区间。

| 场景                            | 冷 J 导航 ms，前→后 | Lua item 读取，前→后 |
| ------------------------------- | ------------------- | -------------------- |
| List，5,000 文件                | 54.84 → 0.069       | 5,000 → 1            |
| List，50,000 文件               | 730.64 → 0.019      | 50,000 → 1           |
| 跳过 5,000 个折叠目录后定位文件 | 35.43 → 0.186       | 5,001 → 1            |

- 5,000 文件仅更新 metadata 后，J 为 53.37 → 0.029 ms，Ctrl-j 为 68.51 → 0.740 ms；没有重建 Lua 行表或重排全部文件。
- Native leaf 查询仍扫描实际跳过的行，不承诺任意目录分布下为常数时间。同一折叠目录场景的热 J 为
  0.052 → 0.188 ms：移除完整 Lua 缓存后重新在 native 扫描，换取冷导航和 publication 后的稳定成本。
- 采样包含 VM/JIT 和首次模块调用成本，小数值不能用于推导不同规模间的精确比例，也不代表完整按键响应延迟。

普通 List 继续使用 [`treeview_migration.lua`](treeview_migration.lua) 的 attached UI 链路，
口径与上一节相同；第三个参数的 baseline 目录可同时提供 Lua overlay 和 `lua/yoz.so`。

| List 项数 | 首开 UI ms，前→后 | 首开主线程 CPU ms，前→后 | 进程 footprint MiB，前→后 |
| --------- | ----------------- | ------------------------ | ------------------------- |
| 1,000     | 34.6 → 34.4       | 19.0 → 18.8              | 11.5 → 11.2               |
| 10,000    | 67.9 → 68.6       | 43.2 → 43.8              | 47.5 → 44.9               |
| 50,000    | 236.9 → 239.5     | 166.7 → 170.3            | 200.3 → 186.1             |

- 50,000 项 native Source 加一个 List State 的独立记账从 62.1 降至 53.1 MiB，约减少 14%；
  完整交互后的进程 footprint 减少约 7%。Footprint 包括 allocator 保留空间，不是 Rust 独占内存。
- 本轮没有改善 List 首开 CPU；50,000 项的最大 tick gap 为 28.65 → 28.61 ms，过滤为 91.7 → 91.7 ms，
  清空过滤为 107.0 → 104.9 ms，重开为 5.14 → 5.18 ms。Cursor/reopen 均为零正文写入。
- Find Explorer 的 1,000 文件采样首开为 46.1 → 45.6 ms，footprint 为 13.3 → 13.1 MiB。
  共享 guide 链路另跑 3 个进程对、每动作 100 次：50k 行相邻移动 settled p95 为 0.557 → 0.523 ms，
  跨分支跳转为 1.587 → 1.529 ms，滚动为 0.662 → 0.708 ms，Visual 为 0.551 → 0.494 ms，均无正文写入。
- 大型 List 相对旧 Lua renderer 的内存和首开 CPU 回退仍未消除。业务输入准备、同步 matcher 调用和 Lua ranking
  仍需独立优化，不能将移除旧 Diffview 访问层等同于整体性能已收敛。

## 2026-10-12 Flat List producer 收敛

Baseline 为 `2e7980c4b` 的完整 Lua overlay 与对应 release native library；current 为基于该 HEAD 的
本轮工作区。Apple M5 Pro / macOS arm64、Neovim 0.12.6 Release、LuaJIT 2.1、libuv 1.53.0，
继续使用 `treeview_migration.lua list`、100×30 attached UI 和相同只读 fixture。
每档 5 对独立进程交替运行，下表为进程间中位数；没有并发运行 build 或其他 benchmark。

| List 项数 | 首开 UI ms，前→后 | 首开主线程 CPU ms，前→后 | Lua heap MiB，前→后 | 进程 footprint MiB，前→后 |
| --------- | ----------------- | ------------------------ | -------------------- | ------------------------- |
| 1,000     | 31.80 → 25.04     | 15.75 → 12.71            | 2.65 → 2.41          | 11.59 → 11.42             |
| 10,000    | 53.25 → 44.45     | 31.79 → 26.42            | 10.27 → 7.82         | 45.05 → 40.63             |
| 50,000    | 203.31 → 156.59   | 132.78 → 108.71          | 40.14 → 29.30        | 183.94 → 171.30           |

- Flat producer 使用数组与单个 key→index 表；已完成版本的 metadata 按同版索引读取。
  Snapshot 直接分片处理 flat records，省去逐项 coroutine resume 与通用 metadata graph copy；
  完整 import 不再扫描全空的 optional columns。Native Data/State/Frame、选区、payload identity 与原子发布边界保持不变。
- 50k 的首开主线程 CPU 下降约 18%，Lua heap 下降约 27%，进程 footprint 下降约 7%。
  过滤中位数为 84.44 → 83.94 ms，清空过滤为 94.22 → 95.39 ms；未将这一小幅波动解释为加速。
  Cursor/reopen 的全部样本均零正文写入；30 个进程的 errors 均为空。
- 此轮未改变通用 Rust storage；Source 与 State 的独立 retained 成本继续使用既有
  `ux::treeview::engine::tests::t_release_flat_import_sample` 拆分测量。它与 Lua heap、进程 footprint
  是不同口径，不能相加。大型 List 相对旧 Lua 平面列表的总体内存回退仍然存在。
- 原始输出、环境信息、baseline overlay 与逐阶段临时探针保存在本机
  `/var/folders/by/7s_s327x3r9clwb_nbcs1l600000gn/T/treeview-fixes-7wn0d3c3/`。
  该路径仅为本次实验 artifact，不保证跨机器或临时目录清理后仍可用；这里不据 5 对进程样本声称生产 p95。

## 2026-10-12 Grouped List 局部展开

比较同一 canonical topology 在局部展开修复前后的 release library：101 个已展开分组，首组只有一个文件，
其余 100 组共持有下表所列文件。每组保留一层目录，但 display 使用 `list_from_depth=1` 平铺文件；
只交替展开／折叠首组，不改变 source、filter 或其他分组。每次操作后确认最新 Frame 并 acknowledge publication。
环境为 Apple M5 Pro、macOS 27.0.1 arm64、Neovim 0.12.6 Release 与 LuaJIT 2.1。

| 无关文件数 | native action→Frame 中位数 ms，前→后 | visited nodes，前→后  | 附着 UI flush 中位数区间 ms，前→后 |
| ---------- | ------------------------------------ | --------------------- | ---------------------------------- |
| 50,000     | 13.75 → 0.056                        | 50,201–50,203 → 1–3   | 13.68–13.78 → 0.43–0.51            |
| 190,000    | 50.27 → 0.062                        | 190,201–190,203 → 1–3 | 52.64–53.05 → 0.94–1.09            |

- Native 数据为每档 3 对独立进程、每进程 24 次操作的进程中位数再取中位数；交替执行 before/after。
  Cursor-only 的 visited nodes 均为 0。另有 1k/10k/50k 的 Rust scale regression，断言访问量、未变行块共享和 RenderPlan 写入量。
- UI 为每档 2 对独立进程、100×30 attached UI，每进程 24 次操作；上表列各进程中位数的范围。
  使用 Treeview facade 与 surface，测到 UI flush；每次最多写一行正文，errors 为空。未包含 Git IO 或 Lua producer 准备，
  也不把少量进程样本解释为生产 p95。测量期间没有并发 build 或其他 benchmark。
- 修复仅对 source/root/display 不变的展开更新局部分组；source topology、成员筛选或展示范围变化仍有全量路径。
  此记录不替代普通 List 的整体性能结论。
- 环境信息、前后 library hash、两套 probe 与原始输出保存在本机
  `/var/folders/by/7s_s327x3r9clwb_nbcs1l600000gn/T/treeview-converge-r2-666d3scv/`；该临时 artifact 不保证跨机器或清理后可用。

## 2026-10-12 普通 Tree 折叠后的 watch 扫描

先以 List 加载 80 / 160 / 320 / 420 层真实目录，再切回普通 Tree，递归折叠隐藏 root；每次操作后仅有一行可见。
比较恢复关闭目标早退前后的 release library，前后 native inputs 仅 `treeview/state.rs` 不同，包含修复及其 opt-in 测量。
环境为 Apple M5 Pro、macOS 27.0.1 arm64、Neovim 0.12.6 Release 与 LuaJIT 2.1。
每档 3 对独立进程，交替 before/after 并在中间一对反转顺序；每进程 2 次预热后记录 24 次递归折叠。
计时从提交命令到 Filetree `is_settled()`，以 1 ms polling 观察；fixture 准备和 List 初次加载不计入。
下表为各进程中位数再取中位数，测量期间没有并发 build 或其他 benchmark。

| 目录深度 | command→settled 中位数 ms，前→后 |
| -------: | -------------------------------: |
|       80 |                      1.22 → 0.07 |
|      160 |                      3.45 → 1.18 |
|      320 |                     29.35 → 1.18 |
|      420 |                     66.49 → 1.18 |

- 新增 `t_collapsed_tree_children_demand_performance`，在 Rust 内直接扫描各层已折叠目录的 children demand：
  同样 2 次预热、24 次采样，320 层 p50 为 26.429 → 0.235 ms，420 层为 63.172 → 0.449 ms。
  该测量默认 ignored，通过 `cargo test --release --lib t_collapsed_tree_children_demand_performance -- --ignored --nocapture --test-threads=1`
  在 `rust/yoz/` 下显式运行；macOS 需要沿用 `.cargo/config.macos.toml` 与可用 SDK 的构建配置。
  它断言关闭目录不产生读取需求，时间数据用于比较成本，不在常规测试中引入机器相关阈值。
- 原因是关闭目标进入祖先循环后重复解析 inherited expansion；恢复普通 Tree 的提前返回，并保持目标使用 raw stamp、祖先使用 `expanded()`。
  Grouped List 仍按深度判断。扫描已知目录及单次 inherited 查询仍有成本，本记录不声称这些路径达到常数时间。
- command→settled 包括发布与 watch reconciliation；Rust 测量只覆盖 demand 扫描。1 ms polling 影响前者的观察精度，
  两者不是相同口径，少量进程样本也不支持生产 p95 结论。
- 前后 library、build receipts、完整样本、环境与测量脚本保存在本机
  `/var/folders/by/7s_s327x3r9clwb_nbcs1l600000gn/T/treeview-r5-fix-g09j0e1d/`；临时 artifact 的可用性与前述记录相同。

## 2026-10-12 Visual 范围选中聚合

本节记录 R6 批量查询完成时的 snapshot；空 selection 的后续优化见下一节。
比较三套生产 `ResultTree:toggle_selection()`：`de9b1b19` 的全量 `marked_nodes(true)` 导出、R6 修复前的
逐项 `flags()`、修复后的单次 `all_marked(ids)`。三者使用同一份修复后 release library 和相同 fixture；
仅替换生产 Lua 模块。保留真实 native Frame、范围节点与 metadata 解析，隔离 command dispatch 和 UI，
因此以下是同步 callback 成本，不是按键到 UI flush 的完整延迟。
环境为 Apple M5 Pro、macOS 27.0.1 arm64、Neovim 0.12.6 Release 与 LuaJIT 2.1。
每版 3 个独立进程交错运行，每场景 2 次预热、24 次正式采样，采样中保留自然 GC；表中为进程中位数再取中位数。
测量期间没有并发 build、tests 或其他 benchmark，全部调用均校验最终 action 和范围身份。

| Source 深度 | 可见行数 | 范围项数 | HEAD 全量导出 ms | 修复前逐项 flags ms | 修复后批量查询 ms |
| ----------: | -------: | -------: | ---------------: | ------------------: | ----------------: |
|           0 |    1,000 |        2 |           0.2806 |              0.0026 |            0.0021 |
|           0 |   10,000 |        2 |           2.9990 |              0.0025 |            0.0019 |
|           0 |   50,000 |        2 |          18.4636 |              0.0023 |            0.0019 |
|         320 |    5,000 |    5,000 |           4.6866 |             15.1008 |            3.6499 |
|      10,000 |      500 |      500 |           0.8393 |            108.3616 |            0.8224 |

- 表中节点均继承 root 的选中标记。批量查询按输入共享祖先解析，不再为每个节点重复遍历 parent chain；
  小范围也不重新扫描范围外的可见行或选中项。深链改善与范围外行数无关的成本须分别验证。
- 同时覆盖首项未选、末项未选和全未选。320 层 / 5,000 项的 callback 分别为
  2.560 → 3.203、15.752 → 3.670、2.548 → 3.188 ms；10,000 层 / 500 项分别为
  0.454 → 0.773、101.752 → 0.843、0.408 → 0.266 ms。这里的前值均为逐项 flags。
  新接口完整解析并校验所有输入身份，短路路径仍有批量输入成本，不能将全选场景的降幅推广到每种标记分布。
- 常规测试验证继承与 self-only 标记、折叠/过滤节点、旧 Frame、移除后的 MissingNode、重复 ID、空数组、
  dense-array 校验和 200,000 项输入上限；Visual consumer 测试禁止逐项 flags 和范围外选中项导出。
  测试不使用机器相关时间阈值，以上少量进程样本也不代表生产 p95。
- 三套生产模块、release library 与 build receipt、测量脚本、环境和完整样本保存在本机
  `/var/folders/by/7s_s327x3r9clwb_nbcs1l600000gn/T/treeview-r6-fix-p99g4gae/`；运行其中的
  `run-range-selection.py` 可复核汇总。临时 artifact 的可用性与前述记录相同。

## 2026-10-12 空 selection 的范围聚合

R7 复审确认：空 selection 下，即使 native stamp 查询可以短路，调用 `all_marked(ids)` 仍会完整解析和
校验 Lua ID 数组，大范围首次选择因此新增同步开销。Consumer 现在读取捕获 Frame 的 `summary.is_empty`，
确定为空时直接选择范围内符合条件的节点；这些身份来自同一 immutable Frame。非空 selection 继续批量查询，
native API 的完整输入校验与 MissingNode 契约保持不变。

复用上一节的环境、release library 和生产 callback 测量口径；native inputs 没有变化。
每版 3 个独立进程交错运行，每场景 2 次预热、24 次正式采样，保留自然 GC，以下为进程中位数再取中位数。
计时排除 dispatch、UI 与 fixture 准备，测量期间没有并发 build、tests 或其他 benchmark。

| 未选范围项数 | HEAD ms | R7 修复前 ms | R7 修复后 ms |
| -----------: | -------: | ------------: | ------------: |
|       50,000 |   29.163 |        36.753 |        28.470 |
|      190,000 |  145.477 |       172.898 |       140.911 |

- 同轮验证原有场景：10,000 层 / 500 项全选从 0.815 → 0.806 ms，50,000 行中的两项全选为
  0.0018 → 0.0018 ms；320 层 / 5,000 项全未选从 3.133 → 2.572 ms。这里的前值均为 R7 修复前。
- 新增 consumer 回归用例禁止空 captured Frame 的任何标记查询；随后改变实时 selection，仍须依据捕获的
  空 summary 选择并排除 location。原有 mixed/all-selected 测试继续要求单次 native 批量查询。
- 该修复消除新增解析开销；超大范围仍需按节点组装 command，上表约 141 ms 的既有同步成本没有消失。
  数据不代表完整交互延迟或生产 p95，也不声称任意范围选择达到常数时间。
- 三套生产模块、native library/receipt、原始样本与脚本保存在本机
  `/var/folders/by/7s_s327x3r9clwb_nbcs1l600000gn/T/treeview-r7-fix-rt0jf9k0/`；临时 artifact 的可用性与前述记录相同。
