# Treeview 局部更新与发布

Status: Design。本文定义 Rust 增量投影、RenderPlan、Lua 发布 guard、cursor 回退与 viewport 装饰。
数据与缓存的权威边界见 [data](data.md) 和 [projection](projection.md)，性能目标见 [performance](performance.md)。

## 完整快照与局部工作

Frame 在逻辑上完整、不可变，支持其全部行的读取和输入定位；这不要求每次复制整份行数组、重新计算每行装饰，
或将所有行重新导出 Lua。Source tree 仍是 ground truth，投影与渲染数据都是可重建的派生结果。
一次刷新分别判断 source/state 变化、layout 变化（成员、顺序、压缩链、导航或输入归并所需的 source 关系，推进
layout revision）与 presentation 变化（正文推进 text revision；图标、高亮、匹配片段、连接线等装饰不推进 revision，
也不因此重算整个 layout）。逻辑 Frame 可以更新而没有正文写入；相同正文也不能证明两个 Frame 的行身份或祖先关系相同。
Frame 依赖的输入版本固定，延迟计算只从该 Frame 的不可变输入求值。

## Frame 存储约束

- 行序列与 NodeId 行定位索引是可共享的持久结构。局部插入、删除、替换只复制受影响部分；旧 Frame 继续引用旧版本，
  不在每次更新时深复制 source 或 Frame，也不为维持 O(1) 绝对行号而在头部插入时做 O(N) 后缀更新。
- 一个 Frame 内 RowKey 唯一，使用代表 NodeId；同一资源的多次出现遵循 provider occurrence identity。
  相同 RowKey 的正文、folded chain、导航与装饰仍可改变，分别验证对应依赖。
- 导航保存稳定目标，读取时换算当前 Frame 的行号；顺序批量读取先定位区间再遍历，不对每行从头搜索或遍历完整祖先链。
- Source 祖先索引、selection/expansion 标记和导航依赖同样版本化共享；整理共享存储受工作和内存预算约束，
  不能在一次普通局部更新中隐藏全表压缩。Frame 持有者释放后回收无引用版本。

## 依赖失效与重算范围

Owner 在数据/state 提交时记录变更类别与目标。节点字段、display 和 render context 表达计算依赖；
Lua producer 的 presentation 变化须通过 records/metadata revision 提交。无法证明依赖范围时扩大重算。

| 变化                                               | 需要处理的范围                                                       |
| -------------------------------------------------- | -------------------------------------------------------------------- |
| 单项正文或 metadata                                | 对应行及真实依赖它的排序、过滤、聚合、压缩链                         |
| Label（有 pattern/filter 或 `sort=name`）          | 成员或顺序，按 layout 变化处理                                       |
| Score（`sort=score`）                              | 可定位的排序集合及移动区间；全局排名依赖改变时可扩大为整个结果集     |
| `hidden`（`show_hidden=false` 且非 selected-only） | 成员，按 layout 变化处理                                             |
| `foldable`（Tree 且 `compress=true`）              | 相关压缩链，按 layout 变化处理                                       |
| Selection，selected-only 与 compress 均关闭        | 更新不可变标记/summary；可见行装饰按需读取，不枚举全部已选后代       |
| Selection，selected-only 开启                      | 重算成员与连接祖先受影响的投影范围                                   |
| Selection，`compress=true`                         | 选区类别边界可拆合压缩链，按 layout 变化处理                         |
| 展开/折叠                                          | 可见子树区间插入/删除，更新祖先、相邻行及连接边界                    |
| 新增、删除、reparent                               | 旧/新父链、涉及的可见子树及排序/过滤依赖；移动后的深度与路径正文另计 |
| Display 或展示范围改变                             | 重算受影响的候选集合；全局匹配/排序本身可能必须读取全部候选          |
| Render context 或 glyph 变化                       | Render context 变化重写正文；glyph 与颜色只重绘 viewport 装饰        |

失效必须包含真实的边界传播。例如在最后一个 sibling 后追加新项，原最后 sibling 的后代连接线可能都改变；
不能只重画新行。Connector 的 source sibling 与可见导航 sibling 分开，selected-only 仍遵循既有 source 连接规则。
祖先依赖按批次归并，不对每个更新节点重复扫描同一祖先链。深度改变导致真实缩进字节变化时，
必须计入整个受影响区间的正文成本，不能把纯结构遍历界限当作文本生成界限。

## RenderPlan

每个 View 从实际显示的 base Frame 与完整 target Frame 请求 RenderPlan；计划在 Rust worker 中生成，不可变，
持有必要 Frame 引用直至提交或丢弃。共享 State 的 View 可以有不同 base，不能共用只对另一 View 成立的差量。

| 字段      | 含义                                                                        |
| --------- | --------------------------------------------------------------------------- |
| `base`    | 实际显示的 Frame；首次显示与 Reset 请求可为空                               |
| `target`  | 完整目标 Frame                                                              |
| `context` | Render context：`version`、`indent`、`slots`、`separator`                   |
| `mode`    | `Swap`（只交换 Frame 与装饰）、`Delta`（局部 splice）或 `Reset`（整体替换） |
| `splices` | 不重叠的正文替换区间                                                        |
| `reason`  | 选择该 mode 的原因                                                          |
| `work`    | 比较行数、共享行数、写入行数与正文字节数，经 `view:status().last_plan` 观察 |

Render context 固定会影响正文解释的格式参数，由 Lua 提供；Rust core 不读取 Neovim theme 或窗口全局状态。
Lua surface 当前固定 `indent = 2`、`slots = 2`、`separator = "/"`；正文格式见 [indentline](indentline.md#正文与装饰)。

Splice 的逻辑形式为 `replace(old_start, old_end, target_start, target_end)`，区间均为 **0-based、end-exclusive**。
所有旧坐标都相对同一个 base；target 区间也都相对同一个完整 target，不混用处理中间坐标。
这是传输协议的索引口径；Lua 用户行输入仍沿用 1-based，由 binding 明确转换。

```text
base:    A B C D E F
target:  A X C D Y Z F
splices: replace([1,2), target[1,2))
         replace([4,5), target[4,6))
```

Lua 先准备全部替换文本，再按 old_start **从后向前**调用 `nvim_buf_set_lines`，因此前面的旧坐标不受后面长度变化影响。
插入使用空旧区间，删除使用空 target 区间；移动表达为删除与插入，不赋予相同文本新的业务 identity。
Splice 由 Rust 排序、合并为无歧义的计划，Lua 不临时寻找节点、排序或猜测变更。

差量策略：

1. 没有 base、显式 resync、render context 或模式改变、空与非空 Frame 互转时使用 Reset；投影已证明平铺结果
   被大面积替换时也直接 Reset。
2. 其余情况先按共享行块对齐 base 与 target。布局未变时只比较变更行；布局变化时，对未共享区间按 RowKey
   求有序锚点生成 splice，纯插入区间走线性路径，不使用无预算的二次 LCS。
3. 变更行来自投影记录：target 由 base 单步投影得到时使用该步的正文变更节点，否则比较两版 source 的变更 keys；
   上下文行与 branch suffix 的变化补充对应行。已知单项更新不能先扫描全部行才发现这一项。
4. 间隔很小的相邻 splice 连同其间未变行合并，减少 Neovim 调用。
5. Splice 数过多或写入行覆盖大部分 target 时转为 Reset；无 splice 时为 Swap，不调用 `nvim_buf_set_lines`。

阈值属于内部策略，不提供让 consumer 猜阈值的配置层。Reset 是正常的成本选择，也是失步恢复手段，
但不能成为未实现局部路径的通用借口。Staging 字节上限见 [默认容量](action.md#默认容量)。

## Lua 发布

提交分为可让出的准备阶段和不让出的短发布阶段，不能为了分批 FFI 而把半份 target 写进 live buffer。
每个 View 同一时间只有一份活动准备（render guard），并只保留一个最新 target 引用；后来的 target 替换待显示项，
不积压重绘队列，也不为每个待发布 Frame 构建 Lua 行数组。一个 View 持帧或准备不阻塞另一个 View。

Render guard 固定：View epoch、已显示 publication（Frame、行数、changedtick、render context）、请求时的 buffer
changedtick 与行数、目标 Frame、decoration revision，以及 consumer `prepare_frame` 的结果（feature commit）。

1. 请求 RenderPlan，再在有界 Lua staging 中按 2 ms 工作片分块读取正文；每块以一个字符串传入，各行以 `\n` 结尾，
   由 Lua 按行切分，依据是显示文本为单行（见[写入范围](data.md#写入范围)）。准备期间保持旧 Frame 可交互。
2. 发布前检查：epoch 与 guard 仍有效；本 View 的 range action 尚未完成或 Visual 持帧遇到布局变化时等待；
   publication 与 render context 未变；buffer changedtick 与行数等于 guard 记录，否则标为失步；
   非 Reset 发布要求 buffer 行数等于已发布行数（空 Frame 计为一行）；staging 与 splice 长度一致。
3. Target 不再适用（不是 State 当前发布的 Frame、未包含本 View 已接受 action 的提交，或查询代次已变化）时执行 retarget：
   取 State 当前 Frame，若它适用、属于同一 State 且 layout 与 text revision 均未变（cursor 与装饰更新推进的 state revision
   不阻止 retarget），复用原 splices 与 staging 并以它为 target；
   否则丢弃本次准备并重新请求。
4. 准备目标 viewport 的行批次，必要时等待 consumer `prepare_frame`；decoration revision 变化使已准备的 feature commit 失效。
5. 进入 publishing guard：反向应用 splice（Reset 覆盖实际 buffer 全部内容），交换 Frame，执行 feature commit，
   恢复 cursor、scroll anchor 与 Visual 端点。全部成功后记录新 publication、通知 `on_frame` 并请求 redraw。
   新数据/选择提交的 Future 完成不等于此处已显示。

需要异步 viewport 装饰的 consumer 可提供 `prepare_frame(view, frame, first, last, rows)`，范围为 0-based half-open。
`rows` 是该范围已导出的只读行批次，consumer 直接复用，不再为同一 viewport 跨 FFI 读取。
其 Future 返回同步 commit callback；返回 false 表示暂未就绪，下次调度重试并继续显示旧 publication。
Callback 在正文、Frame 与装饰一起交换时执行，不能进行 IO 或让出；返回 true 表示自身装饰未变。
`on_frame` 只在全部输入就绪后运行；关闭或重新绑定后忽略迟到结果。

Swap 发布且 `frame:same_rows(previous)` 证明行数据可复用时（同 State、共享 source 与行序列、root/display 与
selection/expansion 版本均相同），复用已准备的 viewport 行批次；cursor 已在目标行时保留已绘制的窗口与 Visual 端点。
仅当 consumer commit 返回 true、没有显式装饰失效且 selection glyph 未变时才跳过整窗重绘。

`view:refresh_decorations()` 合并请求并复用同一准备/发布流程，没有新 Frame 时以同一 Frame 的 Swap 发布；其待调度和准备状态均计入
`status().preparing`。滚动到冷范围且 consumer 提供了 `prepare_frame` 时，redraw 只调度这次刷新。
准备期间的新失效使旧 callback 失去提交资格；准备失败结束本次 pending 并保留错误，普通 redraw 不重试失败的准备，
显式 `refresh_decorations()` 清除失败状态并允许重试。

Publishing guard 期间的 on_lines、CursorMoved、ModeChanged 不被解释为用户 action，也不从半更新正文解析输入。
这是 Treeview 自身的输入/显示协议，不声称多次 Neovim API 调用具有事务性；外部 buffer observer 可能观察到中间通知。

### 发布节奏

只有 data revision 变化、cursor、模式与 root 均未变的连续 source 更新受 8 ms 节奏约束：距上次发布不足 8 ms 时
保留最新 target 并定时唤醒，不依赖下一次 source 事件。首帧、resume、失步恢复、本 View 已接受的 range action、
显式装饰刷新，以及 cursor、模式或 root 的变化立即发布。合并只发生在显示层，不丢弃 mutation 或 selection action，
等待期间不占读取准备位。发布、suspend 或 detach 撤销旧定时器，迟到的定时器不得唤醒已关闭 View。

## 失败恢复

Preflight 失败时不改 live buffer。若实际 API 在已有写入后失败，必须将 surface 标为失步，不能把旧 Frame 当作当前正文映射：

- 不推进 publication；`view:frame()` 返回 nil，暂停该 surface 的行输入与装饰发布，保留 Rust data/state。
- 绑定仍有效时自动安排一次完整 Reset 到当前 Frame；Reset 使用实际 buffer 的全部范围，不信任失败前的旧行数，
  并在第一次恢复写入前重新核对实际 changedtick/extent。此例外只用于完整 resync，不能用来跳过 Delta 的 base 校验。
- Resync 成功后恢复输入。失败原因仍存在时保留错误状态，等待显式 `view:refresh()`，禁止无限自动重试。
- 暂未就绪的装饰、过期 target 或被取代的准备不消耗恢复机会。准备以 guard identity 绑定当前 View 工作，
  失败或替换后的迟到 callback 不得重新发布或释放新工作的状态；同步失败按 guard 实际准备的目标阻止普通重试。
- Native projection error 保留旧 Frame 并等待新的输入或显式 refresh，不对不可适用的旧 snapshot 持续自唤醒。
- 专用 buffer 在 publishing guard 之外发生正文写入时同样标为失步。修复显示不重放业务 action、不清 selection。

`BufUnload` 或 buffer detach 通知同步关闭 View 的发布资格并推进 epoch，使退出时 pending Future 的迟到完成只能释放工作。
窗口恢复、buffer 删除与 native View detach 延迟到可安全调用 Neovim API 时执行一次；`BufUnload` 回调不切换 buffer/window。
显式 `view:detach()` 立即完成清理。Surface 关闭不取消已接受的 data/state 操作。

逻辑空 Frame 的 row_count 为 0，而 Neovim 空 buffer 仍有一条空行；该空行没有 NodeId，不可作为输入目标。
空与非空互转使用 Reset，不能把第一批结果追加在这条空行后面。

## Cursor 回退

逻辑 cursor 属于 State，由投影在每个新 Frame 中解析：

- 原 NodeId 在新 Frame 中可见则保留。
- 否则沿 source parent 链（节点已删除时使用旧 Frame 的 source）回退到最近可见祖先。
- 仍无目标时取旧 Frame 中原行位置，钳位到新 Frame 的末行；首次非空 Frame 定位首行。空 Frame 无逻辑 cursor。
- 原节点再次可见不自动跳回；加载结果不恢复旧 cursor，也不触发打开 callback。

Surface 发布时，Normal 模式把窗口 cursor 移到目标 Frame 的 cursor 行，byte column 沿用原值并钳位到目标行合法的
UTF-8 边界；顶端行按原 topline 的 NodeId 在新 Frame 中定位，定位结果使 cursor 落在窗口外时，按 Neovim 对当前窗口的
滚动规则让 cursor 可见，非当前窗口（如 Picker 输入期间的结果窗口）同样适用。Visual 模式恢复两个端点，规则见 [visual](visual.md)。

View 记录实际恢复或观察到的 cursor 坐标；坐标未变的重复、迟到 `CursorMoved` 不提交新导航，不能用旧 Frame
覆盖已完成但尚未显示的 native cursor。真实位置变化按实际显示的 Frame 提交 SetCursor，不等待待发布 snapshot。
程序导航经 `view:set_cursor(row)` 同时移动窗口 cursor 到 `{row, 0}`、记录位置并提交意图，避免其迟到事件重复提交。

## Viewport 装饰

正文 buffer 保存全部已投影的真实行，不使用虚拟空白行伪装列表。连接线、图标、label 与匹配高亮、selection 标记和
右对齐文本通过 `ux.treeview` namespace 的 decoration provider 以 ephemeral extmarks 绘制；不为离屏行维护持久 extmarks，
也不在全选时导出全部节点的装饰。标准装饰的格式与 highlight groups 见 [indentline](indentline.md#正文与装饰)。

- Provider 按实际 bufnr/winnr 查找 View；suspended、失步、发布中或无 Frame 的 View 不绘制。
  `on_win` 固定本轮 Frame，按整个 viewport 批量读取行数据，`on_range` 只为正在重绘的区间生成 marks。
  缓存命中省去读取，但不能省略本次 redraw 的 ephemeral marks。
- 行批次以 Frame 与区间为键缓存。连续滚动的小缺口可向两侧少量预读；预读超出读取预算时退回精确 viewport，
  且同一缓存上不再尝试预读。冷跳转不预读。读取上限见 [默认容量](action.md#默认容量)。
- 读取只对不可变 Frame 做有界 Rust 批量查询；不做 IO、全树布局、全量 FFI 导出，不进入可变 owner 提交或同步等待 Future。
- 视口出现未缓存范围时，提供 `prepare_frame` 的 consumer 经 `refresh_decorations()` 重新准备；其余 View 只唤醒 owner
  更新读取需求。Consumer 准备和 Filetree watch hints 使用实际 viewport，不把预读范围当作可见范围。
- Redraw callback 不修改 buffer、选项或 selection，不移除/更新持久 extmarks。回调异常隔离到该 View：标为失步并
  按 [失败恢复](#失败恢复) 完整重绘，source/state 不回滚。
- 装饰本身变化时显式请求 redraw；正文 changedtick 不变不能成为跳过 selection/theme 重绘的理由。
  ColorScheme 重新定义默认 highlight 并清空各 View 的行批次缓存。大面积装饰变化只重画当前 viewport。
- 字节 span 基于目标行的实际 UTF-8 文本；cell 列宽与 byte column 分开。水平滚动按当前窗口的 `leftcol` 裁剪，
  不能拿另一 View 的列缓存复用。Native fold/wrap 不替代 Treeview 展开状态，View 绑定窗口时设置 `nowrap`、`nofoldenable`。

`frame:rows(first, last)` 以 1-based 闭区间读取一段行，返回稠密列：`ids`、`labels`（正文中 indent 与 slots 之后的文本）、
`depths`、`parents` / `last_children` / `last_descendants`（1-based 行号，无目标为 0）、`connector_last`、`marked` / `full` /
`pending`、`expanded`、`can_expand`、`icons` / `highlights` / `right_texts` / `errors`（缺省为 false）、`load_states`、
`matches`（相对 label 的 byte 区间）、`folded_ids`，以及 `guides`（需要绘制竖线的祖先 depth，深者在前）。
`frame:guide_path(row, first, last)` 返回 cursor 行 `row` 到 display root 的路径在 `[first, last]` 内的片段，参数与结果均为
1-based 闭区间：按行排序的 `{ first, last, depth }`，`last` 是路径节点的 connector 行，之前的行只携带竖向连接，
`first` 裁剪到范围内；List 或 cursor 不在范围内时返回空数组。两者的单次上限见 [默认容量](action.md#默认容量)。

Consumer 可通过 `decorate_row(view, frame, row, node, col, label, expanded)` 为已读取的 viewport 行追加 ephemeral
spans 或 overlay：`row` 为 0-based buffer 行，`col` 为 label 起始 byte，`expanded` 来自已发布行批次。
该 callback 不得修改正文、读取 IO 或提交异步业务操作；业务 metadata 应按 Frame 的 data revision 解析。
Filetype/icon 检测只在 viewport 首次需要该名称时执行并缓存，不在导入每个路径时运行。
