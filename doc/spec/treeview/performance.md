# Treeview 性能契约

Status: Design。本文定义局部更新的成本边界、测量口径与实现验收目标；发布协议见 [render.md](render.md)。
数值是实现目标，不代表尚未实现的 Rust Treeview 已经达标。

## 工作量与快速路径

记录 source 节点数、投影行数 N、候选数、可见重绘行数 V、受影响行数 D、splice 数 K，以及实际文本/装饰字节数。
结构深度、匹配数量、格式宽度、独立 states/views 与持帧数量单独记录，不能只报“5 万节点”。

- 已知单行正文更新：定位相关行/块和依赖，不先扫描 N 行、不深复制全部 frame。
- 头部或中间插入 D 行：更新相关块与顺序统计路径，不给全部后缀重写绝对行号；FFI 只传本次需要写入的文本。
- 局部移动：复用 Rust 的未变内容与布局片段，Neovim 需要重插入的正文仍按其实际字节量计费。
- Selection、诊断、连接线等纯装饰变化：不写正文，不为所有 N 行构造装饰；可见区查询/重绘成本随 V 及必要祖先变化。
- Filter 或 sort 全局变化：匹配、排序与一般 diff 可以读取全部候选/结果，必须记录这部分真实成本。
  已知 delta 不应无条件走一般 diff；一次完整快照对齐也不能伪报为 O(D)。
- 基线使用平衡分块序列，局部变更只复制边界块与索引路径。稳定 NodeId 定位与源祖先索引的维护成本必须纳入，
  不能仅证明正文容器局部更新就声称全部索引已达到相同复杂度。
- 当前 inverse location index 按 64 个连续 ID 的范围分组，位图将实际成员映射到紧凑的 location 数组。
  空 ID 不占数组槽；修改只复制受影响的页和索引路径，旧 Source/Frame 继续共享未变页。页数组计入 native memory budget。

复杂度以实际工作区间、输出字节和索引维护描述；全局排序、很深的真实缩进与大段移动不承诺常数时间。
块整理、cache eviction、Lua GC、Arc 释放及失败恢复的成本同样记录，不移到未计时的“收尾”来制造低延迟。

## 基线与压力档

- 基线：50,000 个已加载节点/投影行，平均正文约 96 bytes；一个约 80 列、40–50 行窗口，每行两处高亮与一处右对齐装饰。
- 压力档：200,000 行、source 深度 10,000、宽目录、高密度匹配、长 UTF-8 文本，以及两个以上不同 publication 进度的 views。
  深度安全与深缩进实际输出字节分别测试；不能仅测折叠后的短列表。
- 变化档：单项、25 个当前可见项、连续/分散 500 项、头/中/尾插入删除、1,000 项移动、全选、全局反序与 filter/sort 连续变化。
- 流式档：至少 20,000 项按 500 项分批到达，同时输入、滚动、Visual 持帧、取消查询；观察稳定发布进展与队列/内存上界。

四类 consumer 使用真实数据链路：Filetree 的读取/watch、Searcher 原生检索、Lua LSP/TS 数据提取和 Diffview Git 结果。
合成数据用于隔离成本，不能替代这些集成场景。

## 延迟口径与目标

每轮至少记录 action 接受/提交、source 数据就绪、projection 完成、RenderPlan 完成、Lua staging 完成、buffer/frame
提交及 Neovim redraw/flush 的时点。报告 p50、p95、最大值与样本数量；外部 UI/compositor 的显示延迟另行测量。

基线机器与 Neovim build 固定并随结果记录，使用已加载且缓存预热的数据设置初期目标：

| 路径                                                 | 验收目标                                                               |
| ---------------------------------------------------- | ---------------------------------------------------------------------- |
| 可让出的主线程准备工作                               | 每片以 2 ms 为工作预算，达到预算即让出，不在 callback 中完成整份大导出 |
| 常见局部发布及当前窗口 redraw                        | p95 ≤ 8 ms，包含本次 Lua 物化、正文写入、装饰与位置恢复                |
| 已加载数据上的局部交互到 frame flush                 | p95 ≤ 16 ms，不等待无关 provider IO                                    |
| 50,000 驻留候选的 filter/sort 输入到适用 frame flush | p95 ≤ 50 ms，包含全局重排与必要 Reset                                  |
| 全量结构布局基准                                     | 保留 50,000 节点单次 < 8 ms 的计算目标，另计匹配、格式、传输与发布     |

首次接入时用足够长的样本验证这些目标；短实验的 7 次样本或纳秒级容器操作不作为生产 p95 证明。
如果某条路径超过目标，记录具体阶段与数据形状并优化或重审策略，不通过忽略 Reset、GC 或大重排使验收通过。
压力档要求保持有界、可取消、有发布进展，不把基线数值无条件推广到任意规模。

内容搜索同时报告真实输入到首批、末批结果的时间，并拆分 IO 与 Treeview 增量处理开销；不将 IO 排除后的内部指标
标为完整搜索延迟。LSP/TS 测量须包含 Lua 提取与必要复制，不能只计调用原生入口之后的部分。

## 调度与背压

- 每个 state 最多一个运行中的 projection 和一个最新需求，每个 view 最多一个准备中的 RenderPlan 和一个最新 target 引用。
  更新合并发生在派生计算层，不合并或跳过 selection actions。
- Lua surface 对连续 source 更新保留最新 target，在前次发布后的 8 ms 内合并中间 frame；首帧、恢复、已接受的
  本 view range action，以及 cursor、mode、children-of root 的变化及时发布。到期主动唤醒，不依赖下一次 source 事件。
  合并不丢弃 mutation 或 selection action。等待该 deadline 不占读取准备位，可推进下一页；每个 view 仍只保留
  一个最新 target。实际 RenderPlan/feature 准备及待发布输入继续按原规则背压，不能借显示合并越过容量限制。
  发布或 detach 撤销旧 deadline，晚到 timer 不得重新唤醒已关闭 view。
- 昂贵匹配、排序、diff 和依赖计算放在 Rust worker，主线程只做有预算的交接与短提交；worker 不调用 Lua/Neovim。
- 流式结果不能要求每一页都立即显示；以有界批次与发布节奏合并。完成通知、输入和渲染都获得调度机会，
  不能因数据持续到达而永远丢弃尚未发布的计算；必要时对 provider 施加背压，优先完成当前有效交接。
- 所有准备与提交检查当前 view/query/context。取消已失效工作时释放其自身资源，不重复执行旧操作。
- Lua staging 在第一次 live 写入前完成并受预算限制。最终一次不可分 Neovim 调用仍可能较贵，必须测量，
  不能把在 live buffer 上边写边让出作为满足 2 ms 准备预算的办法。

## 内存与传输

分别统计稳态、单次峰值与多轮更新后的 retained memory：

- Rust：source、key/NodeId/导航索引、selection/expansion、共享行块、业务 payload、旧 frame、候选与 diff 暂存。
- Lua：原始 provider 输入、必要导入字段、当前 staging、viewport 装饰缓存及 GC 后 retained heap。
- Neovim：真实 buffer 文本与内部索引、必要持久 extmarks、ephemeral redraw 暂存。

按对象归属核算共享数据，避免重复计费；进程 RSS 作为总量校验，不能把一次多测例进程峰值直接当作 Treeview 稳态预算。
共享 payload 的记账对象也计入 Rust 预算。账本注销前必须保持 allocation 存活，防止地址复用导致错误合并；
标识从 owner 推导，捕获后不再增长的 children 使用定长存储，按实际长度计费。
帧句柄便宜不代表持帧后的写入便宜；至少保留旧 frame 测试同一组更新，记录块复制量、旧版本引用和回收时点。

要求长期重复插入/删除、查询替换和 view 打开/关闭后，无任务/客户端引用的数据可回收；不会积累每轮旧列表、
每节点 Lua table、全表持久装饰或未消费的中间 plan。Frame 仍被任务引用时遵守保留规则，不能为了达标强行失效输入。

预算同时约束节点数、实际 bytes、在途工作、单次 FFI 批次与 patch/diff 暂存；具体容量用真实 consumer 校准。
临时背压和硬容量失败沿用 [action 契约](action.md#预算背压与恢复)。渲染阶段准备失败保留最近有效显示，不回滚
已提交 source/state；API 部分写入后的失步恢复另遵循 render 契约。

## 2026-10-11 全面迁移采样

以 `87db4409` 的 List/Find Explorer/共享 surface Lua 入口作为 baseline overlay，共用同一 native library；
legacy `readdir`/search 实现未变。使用 [`treeview_migration.lua`](../../../__test__/bench/treeview_migration.lua)，
100×30 attached UI、相同只读 fixture，每组 5 个独立 Neovim 进程交替运行，以下为中位数。
环境为 macOS 27.0.1 arm64、Neovim 0.12.5 Release、LuaJIT 2.1、libuv 1.53.0。
数据准备不计时；首开包含模块加载与 producer/native 导入。2 ms 观察器确认目标 Frame 后显式 redraw/flush，
不测外部 compositor；样本数量不支持生产 p95 结论。原始结果保留于本次交付的 benchmark artifacts。
过滤和清空通过 Finder 的 `set_content()` 更新真实输入 buffer 与 Observable，避免初始 TextChanged 覆盖测试输入。

| 场景 | 首开 ms，旧→新 | 过滤 ms，旧→新 | 清空过滤 ms，旧→新 | 进程 footprint MiB，旧→新 |
| --- | --- | --- | --- | --- |
| 普通 List，1,000 项 | 216.3 → 34.6 | 198.2 → 66.8 | 195.3 → 67.0 | 7.6 → 11.4 |
| 普通 List，10,000 项 | 224.7 → 72.9 | 203.0 → 71.7 | 207.5 → 75.8 | 15.7 → 47.5 |
| 普通 List，50,000 项 | 238.7 → 248.2 | 209.5 → 91.2 | 214.7 → 107.0 | 47.3 → 196.8 |
| Find Explorer，1,000 文件 | 361.3 → 47.6 | 196.8 → 67.9 | 274.4 → 71.7 | 18.4 → 13.9 |
| Find Explorer，10,000 文件 | 1414.0 → 202.2 | 214.5 → 70.1 | 689.8 → 78.6 | 93.1 → 49.3 |

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

本节对比 `48f30fa57` 和本轮改动；baseline 已使用 native Treeview，不是上一节的旧 Lua renderer。
保留 baseline Lua overlay 与 native library，使用同一 fixture，5 个独立进程交替运行，每轮反转执行顺序。
环境为 macOS arm64、Neovim 0.12.5 Release、LuaJIT 2.1、libuv 1.53.0。下表均为进程间中位数。

Diffview 使用 [`diffview_navigation.lua`](../../../__test__/bench/diffview_navigation.lua) 测量真实 action 的路径解析，
排除 preview I/O、逻辑 cursor acknowledgement 和 UI flush。相邻文件查询留在 native Frame，Lua 只读取最终目标；
commit 和刷新定位按 identity 查询，目录 transfer 直接跳过原生子树区间。

| 场景 | 冷 J 导航 ms，前→后 | Lua item 读取，前→后 |
| --- | --- | --- |
| List，5,000 文件 | 54.84 → 0.069 | 5,000 → 1 |
| List，50,000 文件 | 730.64 → 0.019 | 50,000 → 1 |
| 跳过 5,000 个折叠目录后定位文件 | 35.43 → 0.186 | 5,001 → 1 |

- 5,000 文件仅更新 metadata 后，J 为 53.37 → 0.029 ms，Ctrl-j 为 68.51 → 0.740 ms；没有重建 Lua 行表或重排全部文件。
- Native leaf 查询仍扫描实际跳过的行，不承诺任意目录分布下为常数时间。同一折叠目录场景的热 J 为
  0.052 → 0.188 ms：移除完整 Lua 缓存后重新在 native 扫描，换取冷导航和 publication 后的稳定成本。
- 采样包含 VM/JIT 和首次模块调用成本，小数值不能用于推导不同规模间的精确比例，也不代表完整按键响应延迟。

普通 List 继续使用 [`treeview_migration.lua`](../../../__test__/bench/treeview_migration.lua) 的 attached UI 链路，
口径与上一节相同；第三个参数的 baseline 目录可同时提供 Lua overlay 和 `lua/yoz.so`。

| List 项数 | 首开 UI ms，前→后 | 首开主线程 CPU ms，前→后 | 进程 footprint MiB，前→后 |
| --- | --- | --- | --- |
| 1,000 | 34.6 → 34.4 | 19.0 → 18.8 | 11.5 → 11.2 |
| 10,000 | 67.9 → 68.6 | 43.2 → 43.8 | 47.5 → 44.9 |
| 50,000 | 236.9 → 239.5 | 166.7 → 170.3 | 200.3 → 186.1 |

- 50,000 项 native Source 加一个 List State 的独立记账从 62.1 降至 53.1 MiB，约减少 14%；
  完整交互后的进程 footprint 减少约 7%。Footprint 包括 allocator 保留空间，不是 Rust 独占内存。
- 本轮没有改善 List 首开 CPU；50,000 项的最大 tick gap 为 28.65 → 28.61 ms，过滤为 91.7 → 91.7 ms，
  清空过滤为 107.0 → 104.9 ms，重开为 5.14 → 5.18 ms。Cursor/reopen 均为零正文写入。
- Find Explorer 的 1,000 文件采样首开为 46.1 → 45.6 ms，footprint 为 13.3 → 13.1 MiB。
  共享 guide 链路另跑 3 个进程对、每动作 100 次：50k 行相邻移动 settled p95 为 0.557 → 0.523 ms，
  跨分支跳转为 1.587 → 1.529 ms，滚动为 0.662 → 0.708 ms，Visual 为 0.551 → 0.494 ms，均无正文写入。
- 大型 List 相对旧 Lua renderer 的内存和首开 CPU 回退仍未消除。业务输入准备、同步 matcher 调用和 Lua ranking
  仍需独立优化，不能将移除旧 Diffview 访问层等同于整体性能已收敛。

## 实验与实现验收的关系

已有传输与发布实验支持原生交接、候选常驻、分块共享、局部正文和可见区域装饰；它们用于选择实现方向。
完整 runtime 验收还必须包含以下未被单独容器/publisher 测例替代的部分：

- Rust 依赖失效与 inverse row index、增量 Tree/List/压缩/connector，以及一般 diff 的时间与内存上界。
- 真实 FFI 字段编码、主线程 staging、查询替换、选区锁、Future 与异步回调顺序。
- 多窗口、Visual 正反向及 UTF-8 两端点、主题/宽度变化、用户输入到实际 redraw 的完整链路。
- 错 base、外部修改、每个 splice 阶段的故障注入与关闭重绑定；恢复不能误执行行输入或留下旧装饰。

这些验证属于实现的交付条件；Design 定稿不代表端到端性能已经验证完成。
