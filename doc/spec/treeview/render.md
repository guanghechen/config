# Treeview 局部更新与发布

Status: Design。本文定义 Rust 增量投影、不可变 frame、Neovim 正文差量与可见区域装饰。
数据与缓存的权威边界见 [data](data.md) 和 [projection](projection.md)，性能目标见 [performance](performance.md)。

## 完整快照与局部工作

Frame 在逻辑上完整、不可变，支持其全部行的读取和输入定位；这不要求每次复制整份行数组、重新计算每行装饰，
或将所有行重新导出 Lua。Source tree 仍是 ground truth，投影与渲染数据都是可重建的派生结果。

一次刷新分别判断三类变化：

- Source/state 变化：真实节点、标记、provider 结果与 filter/sort 输入，按各自契约提交。
- Layout 变化：结果成员、顺序、压缩链、导航或输入归并所需的 source 关系改变，推进 layout revision。
- Presentation 变化：正文、图标、高亮、匹配片段、连接线或窗口相关装饰改变；不因此自动重算整个 layout。

逻辑 frame 可以更新而没有正文写入；相同正文也不能证明两个 frame 的行身份或祖先关系相同。
Frame 依赖的 source、selection 等输入版本必须固定，延迟计算只从该 frame 的不可变输入求值。

## Rust 行存储与索引

采用可共享的平衡分块行序列及子树行数索引，保存 RowKey、正文数据引用与布局关系。
局部插入、删除、替换只更新受影响块和索引路径；移动可复用整段。旧 frame 引用旧根，未改变的块与 payload 共享。
不将整个 `Arc<Vec<Row>>` 作为需要频繁局部写入的唯一存储，不在每次更新时深复制 source 或 frame。

- 一个 frame 内 RowKey 唯一，使用代表 NodeId；同一资源的多次出现必须遵循 provider occurrence identity。
  相同 RowKey 的正文、folded chain、导航与装饰仍可改变，分别验证对应依赖。
- 行位置通过顺序统计计算。NodeId 到行位置使用该 frame 的稳定行定位索引，不给每个后缀节点重写绝对行号。
  分块拆分时只修正受影响块中的定位信息；版本化的父链接/权重等辅助索引必须一并保持一致。
- 布局导航保存稳定目标或范围定位信息，读取时换算当前 frame 的行号。允许平衡索引上的对数级 rank/select，
  不为维持所有绝对行号查询的 O(1) 而在头部插入时做 O(N) 后缀更新。
- 顺序批量读取先定位区间，再遍历相关块；不能对区间内每一行都从头搜索或重复遍历完整祖先链。
- 块容量、最小占用率与合并策略由规模测试校准；避免反复插入/删除留下无限增长的小碎块。
  整理共享存储也受工作和内存预算约束，不能在一次普通局部更新中隐藏全表压缩。
- Source 祖先索引、selection/expansion 标记和导航依赖同样需要版本化共享；仅把正文分块而继续复制这些全量索引，
  不满足局部更新要求。Frame 持有者释放后回收无引用版本，不保留无限历史。

## 依赖失效与重算范围

Owner 在数据/state 提交时给出可验证的变更类别与目标。Provider 谓词或 formatter 必须声明实际依赖；
无法证明依赖范围时扩大重算，不能冒险复用。Filter/sort 输入改变仍使旧结果失效，允许复用其中经验证未变的子计算。

| 变化                            | 需要处理的范围                                                       |
| ------------------------------- | -------------------------------------------------------------------- |
| 单项正文或 metadata             | 对应行及真实依赖它的排序、过滤、聚合、压缩链                         |
| Selection，selected-only 关闭   | 更新不可变标记/summary；可见行装饰按需读取，不枚举全部已选后代       |
| Selection，selected-only 开启   | 重算成员与连接祖先受影响的投影范围，必要时结构 diff                  |
| 展开/折叠                       | 可见子树区间插入/删除，更新祖先、相邻行及连接边界                    |
| 新增、删除、reparent            | 旧/新父链、涉及的可见子树及排序/过滤依赖；移动后的深度与路径正文另计 |
| 单项 sort key 更新              | 可定位的排序集合及移动区间；全局排名依赖改变时可扩大为整个结果集     |
| Pattern、排序方式或展示范围改变 | 重算受影响的候选集合；全局匹配/排序本身可能必须读取全部候选          |
| Theme/glyph/宽度变化            | 按 render context 判断装饰失效或正文重排；颜色改变不自动重写全部正文 |

失效必须包含真实的边界传播。例如在最后一个 sibling 后追加新项，原最后 sibling 的后代连接线可能都改变；
不能只重画新行。Connector 的 source sibling 与可见导航 sibling 分开，selected-only 仍遵循既有 source 连接规则。
祖先依赖按批次归并，不对每个更新节点重复扫描同一祖先链。

装饰变化可以用范围或依赖版本表达，不要求提前展开为每行一条 dirty 记录。连接线、选择标记与图标优先作为
覆盖固定槽位的装饰发布；深度改变导致真实缩进字节变化时，必须计入整个受影响区间的正文成本。
输出字节随深度或长行增长的成本不能隐藏在“只修改一个节点”中，也不能把纯结构遍历界限当作文本生成界限。

## 从实际显示的 frame 生成差量

每个 view 的 Lua surface 保存最近成功显示的 publication 身份：ViewHandle/绑定 epoch、frame_id、render context
版本、buffer changedtick 与逻辑行数。Render context 固定会影响正文或装饰解释的 glyph、格式与窗口参数，
由 Lua/上层提供；Rust core 不读取 Neovim theme 或窗口全局状态。

Rust 接收实际显示的 base frame 和完整 target frame，生成不可变 RenderPlan。共享 state 的 views 可以有不同 base，
不能共用只对另一 view 成立的差量；base/target/context 相同的计算才可复用。Plan 持有必要 frame 引用直至提交或丢弃。

逻辑计划包含：

- `base`：实际显示的 publication 身份与旧逻辑行数。
- `target`：目标 frame、render context、行数、query 归属及完整 core/feature envelope。
- `splices`：按旧行坐标定义的、不重叠的正文替换区间及对应 target 行区间引用。
- `decorations`：目标装饰输入版本和受影响范围；可以是全视图装饰失效，无须列出每行。
- 模式：Delta、只交换 frame/装饰，或 Reset。没有可用 base、首次显示或已失步恢复使用 Reset。

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
相邻或同位置的操作必须在 Rust 合并、排序为无歧义的计划，Lua 不临时寻找节点、排序或猜测变更。

差量生成按以下顺序选择：

1. 使用已验证的局部更新/投影变更范围，并跳过共享的未变块。已知单项更新不能先扫描全部行才发现这一项。
2. View 跳过多个 frame 时，组合有界历史中的变更，或直接比较仍持有的 base/target 共享结构；不逐帧重绘追赶。
3. 没有足够局部信息时，在未证明相等的区域按唯一 RowKey 求顺序锚点，可使用旧位置序列的 LIS，生成有序 splice。
   一般比较成本为 O(N log N) 级，不能用于替代每次已知局部变更的快速路径；不采用无预算的二次 LCS。
4. Hash/fingerprint 只帮助定位候选相等块；身份和内容跳过需要共享不可变引用、可信版本或实际相等校验。
   不能以哈希碰撞风险作为输入 identity 一致性的代价。

变更历史有行数和字节上限，过期就丢弃提示信息；持有旧 frame 不要求同时保留期间所有 delta。
丢失提示不自动要求重写 buffer，可以重新 diff base 与 target。Diff 达到工作/内存预算时及时转为更粗的区间或 Reset。

## 选择局部替换还是 Reset

Planner 同时估计比较工作、FFI 文本字节、Neovim 调用数及更新后的 redraw 成本。
相邻的小区间可以连同少量未变行合并，减少 API 调用；合并带来的额外文本字节也计入成本。

- 少量修改、插入、删除和局部移动使用 Delta；纯装饰变化不调用 set_lines。
- 大范围反序或几乎全部重排时，Reset 可以比多个大 splice 更便宜；不以最少编辑行数作为唯一目标。
- 预算阈值采用测量得到的内部策略，并记录选择原因；不增加让 consumer 猜阈值的可选配置层。
- Reset 是正常的成本选择，也是失步恢复手段，但不能成为未实现局部路径的通用借口。
  连续 filter/sort 全局变化和 Reset 的主线程耗时同样必须通过性能验收。

## 可见区域装饰

正文 buffer 保存全部已投影的真实行，首期不使用虚拟空白行伪装整份列表。行高亮、匹配片段、selection 标记、
connector、图标与右对齐信息默认通过 Neovim decoration provider 的 ephemeral extmarks 发布。
不为每个离屏行维护一组持久 extmarks，也不在全选时向 Lua 导出全部节点的装饰。

- Provider 按实际 bufnr/winnr 查找 view；`on_range` 只为正在重绘的区间生成 ephemeral marks。
  不在每次更新重新注册 provider；跳转和滚动到未缓存范围时仍按当前实际 frame 正确绘制。
- 可缓存 viewport/小范围 overscan 的装饰批次，键包含 frame 依赖、render context 与区间。缓存命中省计算，
  不能省略本次 redraw 的 ephemeral marks；这些 marks 不会自动留到下一次 redraw。
- 在 `on_win` 固定本轮 frame/context 并按整个 viewport 批量准备冷缓存，`on_range` 消费该批数据；
  Neovim 分段调用 on_range 时不因此逐行跨 FFI，也不反复准备同一祖先路径。实际多次 redraw/range 的调用成本仍计入。
- 冷范围读取只允许对不可变 frame 做有界 Rust 批量查询，返回所需行的装饰；不做 IO、全树布局、全量 FFI 导出，
  不进入可变 owner 提交或同步等待 Future。也不能每行跨 FFI 查一遍完整 parent 链。
- Redraw callback 不修改 buffer、选项或 selection，不移除/更新持久 extmarks；只添加本轮 ephemeral marks。
  持久标记仅用于确有跨重绘生命周期的少量锚点等对象，单独计入预算与清理规则。
- 回调异常在 view 边界隔离并报告，不能每帧无限重试或展示上一版本的选择判据。若不能保证交互所依据的装饰正确，
  暂停该 surface 的行输入，按当前有效 frame 完整重绘恢复；source/state 不回滚。
- 装饰本身变化时显式请求对应可见范围 redraw；正文 changedtick 不变不能成为跳过 selection/theme 重绘的理由。
  大面积装饰变化可重画当前 viewport，不按全部离屏行产生 redraw 调用。
- 字节 span 基于目标行的实际 UTF-8 文本，边界必须有效；cell 列宽与 byte column 分开。
  上层提供 glyph/格式输入，颜色组由 Lua 对接；窗口宽度、水平滚动和右对齐按当前窗口解释，不能拿另一 view 的列缓存复用。
- 连接线和 selection 依赖按区间求值，必要祖先只准备一次；按实际层级、输出字节与重绘范围计费。
  Native fold/wrap 不作为 Treeview 展开状态的替代；基线 surface 使用 nowrap 并由 Treeview 管理折叠。

## Surface 提交与失败恢复

提交分为可让出的准备阶段和不让出的短发布阶段，不能为了分批 FFI 而把半份 target 写进 live buffer。

1. 在有界 Lua staging 中物化计划需要的正文批次和必要 viewport 装饰。准备期间可让出，保持旧 frame 可交互；
   同一个 view 最多一份正在准备的 plan 和一个最新 target 引用，不为每个 pending target 建行数组。
2. 在第一次写入前验证 View/绑定 epoch、base publication、render context、buffer changedtick、行数、splice 边界与
   target envelope/query 前提。已过期则整份丢弃并从实际 base 重算，不能只修改 plan 的 base token。
3. 进入 view 的 publishing guard，固定必要 cursor、scroll anchor 和 Visual 端点。反向应用正文 splice，或用 Reset
   覆盖实际 buffer 全部内容；随后交换 target frame/envelope、装饰输入与 publication token，再恢复位置和 guard。
4. 仅在全部成功后确认 published frame，并请求合适范围的 redraw。新数据/选择提交的 Future 完成不等于此处已显示。

需要异步 viewport 装饰的 consumer 可提供 `prepare_frame(view, frame, first, last)`，范围为 0-based half-open。
其 Future 返回同步 commit callback；返回 false 表示暂未就绪，下次调度重试并继续显示旧 publication。
准备完成后重新校验目标 data/layout 和 viewport，过期结果不提交；callback 在正文、frame 与装饰一起交换时执行，
不能进行 IO 或让出。`on_frame` observer 只在这些输入全部就绪后运行；关闭或重新绑定后忽略迟到结果。

Guard 期间 Treeview 的 on_lines、CursorMoved、ModeChanged 等回调不能把程序写入解释为用户 action，也不能从半更新正文
解析输入。延迟到达的程序事件按 view/gesture、目标位置和发布身份识别，不能用一个长期忽略事件的开关吞掉后续用户输入。
Rust 可变借用在调用 Lua/Neovim 之前释放。这里的一致发布是 Treeview 自身的输入/显示协议，不声称多次 Neovim API
调用具有数据库式事务；任意外部 buffer observer 可能观察到 on_lines 的中间通知。

Preflight 失败时不改 live buffer。若实际 API 在已有写入后失败，必须将 surface 标为失步，不能把旧 frame 当作当前正文映射：

- 不推进 published token；暂停该 surface 的行输入与装饰发布，保留 Rust data/state 和必要 frame 引用。
- 绑定仍有效时安排一次完整 resync 到仍适用的 target；Reset 使用实际 buffer 的全部范围，不能信任失败前的旧行数。
- Resync 成功后恢复输入。失败原因仍存在时保留明确错误状态并等待显式刷新/重新连接，禁止无限自动重试。
- Buffer/view 已关闭或重绑定时只释放旧工作；不得写入新绑定。修复显示不重放业务 action、不清 selection。

失步后的 Reset 不再要求旧正文符合 base 行数/changedtick；它重新固定当前绑定、实际 changedtick/extent 与有效 target，
在第一次恢复写入前再次核对。此例外只用于明确的完整 resync，不能用它跳过 Delta 的 base 校验。
专用 buffer 在 publishing guard 之外发生正文写入时也标为失步，不能继续绘制或解析过时的行映射。

逻辑空 frame 的 row_count 为 0，而 Neovim 空 buffer 仍有一条空行；该空行没有 NodeId，不可作为输入目标。
空到非空及非空到空使用明确的 sentinel 转换，不能把第一批结果追加在这条空行后面。

## Cursor、Visual 与多 view

- 普通刷新以目标 snapshot 的逻辑 cursor 为准；无新的 cursor 意图时保持原 NodeId，并尽量保持顶端锚点的屏幕位置。
  删除/过滤后的回退遵循既有 cursor 契约，不依赖 extmark 偶然漂移；byte column 按目标文本合法边界钳位。
- Visual 期间只允许 layout revision 不变的 target 发布；无正文 splice 但身份/祖先归并变化的 target 也必须暂缓。
  同布局正文/装饰更新保留模式、方向及两个端点，退出后从实际显示的 frame 直接追赶最新适用 target。
- 每个 view 独立确认 base 和 changedtick。一个 view 持帧不阻塞另一个 view 更新；关闭 view 释放自身 staging 与计划。
- 共享 source/state 不要求共享窗口格式、viewport 或 publication 进度。所有 frame 行输入继续由原 snapshot 定位，
  按 [Visual/input 契约](visual.md)校验，不能用最新行号解释旧输入。

## 验收

- 差量应用后的正文、装饰和 frame 映射与独立全量渲染一致；覆盖多区间插入/删除/替换、移动、反序、相同文本不同 identity。
- 覆盖展开/折叠、压缩链拆合、reparent 深度变化、旧末 sibling 的后代 connector、selected-only 及排序/filter 失效。
- 覆盖 frame-only、全选装饰变化、theme/glyph/宽度、UTF-8、水平滚动、冷 viewport 跳转、空 buffer sentinel。
- 覆盖错 base、外部 changedtick、计划准备期间新 target、落后 view、Visual 同布局更新及语义布局变化、关闭/重绑定。
- 在第一个及中间 splice 后注入失败；确认行输入被隔离、旧 token 未推进、全量恢复使用实际 extent 且不重放 action。
- 测量已知局部更新的访问节点/复制行数/FFI 字节，确认头部插入不复制后缀索引；旧 frame 持有时仍满足共享与内存预算。
- 性能与真实 provider/窗口集成要求见 [performance.md](performance.md)，不能仅以合成 publisher 测例宣告端到端达标。
