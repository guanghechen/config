# 结果集接入

Status: Design。

普通 List、Picker、Searcher 和 Diffview 使用通用 Treeview records。Explorer 的 filesystem ownership 由
[Filetree](../../../spec/design/filetree.md) 提供；搜索结果、历史删除文件和 LSP symbols 不被解释为磁盘全量目录。

## 数据与状态

| 模块                                    | 职责                                                                         |
| --------------------------------------- | ---------------------------------------------------------------------------- |
| `era.view.ResultSource` / `ResultPaths` | 准备业务 records、路径归组与排序；不保存交互状态或可见行                     |
| `era.view.ResultTree`                   | 导入 records，持有 native Data/State，连接 View，协调 metadata 与 Frame 发布 |
| `era.view.ResultFiles`                  | Picker/Searcher 共用的文件与 location presentation                           |
| native State / Frame                    | 选择、展开、root、cursor、投影与行映射                                       |

完整替换按稳定 provider key 对齐，存活节点保留 native identity 和标记。
Lua metadata 在提交时复制为 snapshot，按 native data revision 保存；行输入通过已发布 Frame 获取对应版本，
不能在 prepare 阶段把新 metadata 绑定到旧 buffer 行。Picker 与 Searcher 通过共用模块协作，不静态互相依赖。

### 普通 List 与 payload

- 普通 ListComposer 同样使用 ResultTree；其 `ResultList` producer 使用有序 keys/labels/items 数组和一个 key→index 表，
  不为每项建立 parent/children record。完成准备后整份版本不可变；metadata 通过同版索引读取，不重复构造、深拷贝全量映射。
  平面 snapshot 在 256 项 / 2 ms 时间片中直接准备 presentation，树形 producer 继续使用通用遍历与 metadata 图复制。
  `payloads` 单独保存原始 IItem 引用，可包含 callback、userdata 或 LSP action；不 deepcopy、不序列化到 Rust。
  每次 reset 在根记录推进 payload version，即使 label 不变也生成新的 data revision；旧 Frame 仍解析到旧 IItem 引用。
  Payload 内部的可变内容由调用方拥有。空 query 直接使用 source 顺序，不构造全量 matches 或重传 filter。
  Select provider 在展示入口转义 NUL、CR 和 LF，callback 保留原值；Snacks 的相同名称或文本通过输入序号保持独立 identity。
- List reset 的 producer 准备也遵循 2 ms 时间片，较新的 reset 或 dispose 终止旧准备，不能发布半份列表。
  只有准备成功才替换 producer；已显示 Frame 在此期间继续使用原 payload。空叶子不单独分配 children 数组。

### 准备与原子提交

- Presentation 每批最多 256 条 records，每条结束后检查 2 ms 时间片；metadata 图复制每 1024 个字段检查一次 2 ms 时间片，
  超出时间片时让出主线程。
  共享引用与循环只复制一次；准备期间 producer revision 改变则丢弃部分 snapshot，继续最新请求。
  纯文本 leaf 使用带类型标记的直接字符串签名，其余 presentation 使用完整编码；可选导入列只在有界 chunk 中补全默认值。
  至多 16 个字段的简单 metadata 只有逐字段相同才复用上一帧的 immutable copy；复用不能合并
  原本不同的对象，也不能改变共享引用关系。嵌套 metadata 仍按图复制。
- 保留一代 records 的精确序列化签名和 topology 顺序。Topology 不变且最多 256 个 records 改变时，
  只保留改变的 presentation records，使用一个原子 native batch；records 完全相同时跳过 native 写入。
  完整 import 输入仅在 topology 改变或超出 batch 范围时重新准备，以最多 256 条 records 的列式输入
  分批 append；每批省略全部等于 native 默认值的可选列。准备后 native base revision 变化则拒绝旧 batch。
  签名不代替 native identity，也不推断 selection 或可见行。
  只有 commit 后才发布 source；新的刷新合并为最后一次请求，失败保留先前 surface 并拒绝 publication Future。
- 完全相同的路径输入复用 producer topology；任何 producer mutation 都使这项复用失效。Locations
  与业务 metadata 仍按每次刷新重建，不能因路径集合相同而复用旧搜索结果。
  同一次 topology 复用也保留 viewport icon cache；路径输入改变时丢弃旧 cache。

### 大批文件输入

- 大批普通文件列表使用 `FiletreeComposer:prepare_filepaths`：复制输入数组，在独立 producer 中分片构建路径、
  entries 和排序，完成后一次性接管 records，保持原 Source 对象的引用有效。宽目录和 frecency 使用稳定的
  cooperative merge sort；每个文件的 frecency score 只读取一次，相同分数保留 source 顺序。
  Find Files / Find Git 使用此流程；需要立即附加 locations/diagnostics 的 producer 继续使用同步 reset。
  准备期间旧 Frame 保持可读；新的请求、同步 mutation、切根、hide 或 dispose 使旧准备失效。
  首次 render 等待准备完成，避免先发布空根再重建投影；当前 query 在新 source 发布前应用。
  时间片限制长循环，不承诺中断单次 Lua/VM/native 调用，也不修改全局 GC 参数。
- 完整 Forest import 若保留所有既有节点的 data、parent、completeness 和 sibling prefix，只需生成追加操作，
  省去临时 Source 的重复构造；操作仍经过相同的原子提交、状态更新及资源检查。其他 import 使用完整 reconciliation。

## 匹配与读取

`DisplayOptions.filter` 是可选的有序 NodeId 数组。Tree 保留命中节点的连接祖先；List 只保留直接命中项，
即使同时启用 selected-only 也不额外列出目录祖先。`sort=source` 时 List 遵循 filter 顺序，其他 sort 保持其显式排序。
空数组表示无结果，nil 表示不限制成员。过滤不改写 source topology；删除的 ID 不再产生行。
Lua 输入遵循已有 200,000 项数组上限，排队和保留 filter 的内存计入 data owner 预算。

Picker 复用既有 fuzzy/literal/regex matcher，把匹配身份和排序送入 display filter。
普通字符串追加可在同一 producer revision 的前次结果内继续匹配。相同 display 配置复用解析后的 filter，
cursor、selection 和 expansion 不重新生成 records 或全量行映射。

Searcher 的跨文件检索使用 `yoz.search` Job 与 Lua FileSearch generation；终态结果经 ResultFiles 准备后导入。
Diffview 的 Git 结果同样经 Lua producer 交接。它们没有隐式使用 Treeview 的 native Query session，
两种查询入口的边界见 [query.md](query.md)。

`Frame:flags(id)` 从该 immutable frame 读取 marked/expanded，包含当前被折叠或过滤的节点。
界面导航使用 `Frame:position` / `navigate`；业务批量遍历可以按需派生映射，不能反过来作为 row authority。
`Frame:marked_nodes(visible_only)` 在 native 中查询当前帧的选中身份，返回分页读取的 NodeIds；visible
查询遵循行顺序，完整查询包含折叠与过滤之外的标记。`Frame:node_keys(ids)` 仅导出 identity，单次最多
1024 个节点、1 MiB keys。批量动作只解析选中节点，不能逐行导出 header、完整节点或装饰数据。
`Frame:all_marked(ids)` 对显式 ID 数组做 native 聚合，只返回这些身份是否全部已选；空数组返回 true。
它读取该 immutable frame 的状态，不受折叠或过滤影响；重复 ID 不改变结果。所有 ID 都须存在于该帧 Source，
即使已遇到未选节点，后续缺失 ID 仍报 MissingNode。输入沿用 200,000 项数组上限，不导出逐节点 flags。
批量查询共享祖先的 inherited stamp 缓存，工作量限于输入节点及所需祖先，不扫描范围外的行或选中项。

## 发布、输入与生命周期

### 发布与行输入

- 所有 Result 都由 native Treeview owner 提供正文；行数、当前行和 preview 通知跟随 `on_frame`，没有旧 draw 分支。
  Current-line observable 读取发布后的 surface cursor，不能将迟到的 Frame cursor acknowledgement 回写成新输入、移动 Visual 端点。
  明确的行导航立即提交给 native View，observable 仅通知其余 UI，避免异步通知晚于初始定位。
- Publication 等待已排队的 selection；native draw 被后续请求取代时等待最新 Frame 就绪，不能将
  `Superseded` 通知作为已完成的结果更新交给调用方。
  Metadata-only 变更也刷新共享 Data 的所有 viewport decorations；可见主结果的 publication/ready 等待其准备完成。
- Visual 选择由 native View 的 range action 捕获 frame。跟随选择的业务 action 等到 selection 被接受并发布，
  批量 self selection 按值合并为 native 命令，避免逐行占用 command queue。
- 多行 Visual Tab 保留结果集的范围语义：忽略 location；有任一未选节点则全部选中，否则全部取消，
  只修改范围内节点自身。Normal／单行选择仍递归切换所属文件或目录。List location 的 parent 动作
  通过该帧中的所属文件身份定位，不依赖 List 的视觉 parent。
  范围聚合先按捕获 Frame 收集并过滤节点；该 Frame 的 selection summary 为空时直接全选，否则调用一次
  `all_marked`。不逐项查询 flags，也不导出范围外的选中项；空 summary 路径不重复解析和校验已捕获的节点数组。
- Matcher 保留输入 debounce；native Result 发布仅合并同轮请求，不再追加 128 ms render debounce。

### 多选 List

- `ListComposer:toggle_selection()` 经 ResultTree 提交 native 选择，不维护 Lua `selected_set`。
- `ListComposer:selected_items()` 返回 Future，等待已排队的选择与 publication，再读取原始 IItem payloads。
  查询包含被过滤或隐藏的已选节点；真正 Remove 的节点不再返回。
- 确认动作等待该 Future，不用旧 Frame 判断选区为空。空选区可按业务规则使用确认时捕获的当前项；
  等待期间重复确认只接受一次，关闭 picker 后不再执行确认 callback。准备失败允许重新触发。
- AI 的发送目标和提交目标使用这两个入口；“send to all”是动作行，不参与多选标记。
  标记、过滤后的选区和确认目标来自同一 native State。

### Surface 生命周期

- Directory preview 使用共享 Data 上的独立 State。切回文件先更换 buffer 再 detach，防止销毁浮窗。
- 可复用的 Picker/Searcher result 在 hide 时 suspend View：保留独占 scratch buffer、已发布 Frame 和正文，
  释放 window binding 与活动 polling。重开复用该 View，以原 Frame 为增量发布基线；buffer 被删除时重新接管空 buffer，
  changedtick 失配或外部修改时执行正常 resync。重开仍提交最新 producer/display 请求，不能遗漏隐藏期间的变更。
  隐藏期间业务读取与 publication 跟随 State 的最新 Frame；metadata 保留当前 revision 以及各 surface 仍显示或暂停的 revision。
  慢于主结果的 preview 保留自己的 metadata，替换 Frame 发布后回收旧 revision。
  普通 unmount/detach 释放 View 和 scratch buffer，保留 Data/State；Dispose 取消待发布工作并释放所有保留资源。
  晚到的异步 callback 不重新连接 surface，也不能写入重新绑定的窗口。

### Diffview

- Diffview refresh 等待 publication Future，稳定 key 定位等待 native 行可用；buffer 行与 action 对象来自同一帧。
- Diffview 初始仅准备 commit headers；未展开的缓存 files 不进入 inline records 或 header metadata。
  首次 inline 展开才准备该 commit 的 files；缓存仍保留时，后续展开／折叠只提交 native State 命令，不重新构造 producer、
  解析 icons 或发起 import。缓存回收遵循 [Diffview policy](../../../spec/design/feat/diffview/main.md#materialized-records-cache)，
  冷重开重新导入 records。Standalone filetree 独立准备自己的 records，reveal 显式准备目标 commit files。
- Diffview Tree/List 共用相同的目录和文件 records。Changes/Files 使用 native List ancestry；inline commits
  使用 `list_from_depth=1` 保留 commit header 分组，在组内平铺文件。模式切换不删除目录、不改写 label/parent，
  业务 records 未变时不产生 data revision，也不丢失目录的 NodeId 或折叠标记。

### 文件操作

- 文件结果的 producer 按 directory 优先、basename 排序；List 的显式 filter 排名独立于此顺序。
- 业务 action 从已发布 snapshot 读取目标；replace 后的剩余 offsets 写回 producer，再发布新 snapshot。
- Diffview 的 untracked discard 同样捕获 Filetree Resource 并提交 native Job；其单项删除与 pane 生命周期
  遵循 [Diffview 文件操作](../../../spec/design/feat/diffview/main.md#文件操作)。
- 文件 Picker 的 create/delete/rename/move 使用 Filetree Jobs。Prompt 前捕获真实资源，IO 与 identity 校验由 Rust 执行；
  rename/move 复用 Explorer 的 buffer/LSP 同步。成功后只重映射已有结果，保留 location identity 与 metadata，不扫描目录补入其他文件。
  等待已排队的 selection 后再迁移标记；同步结果须仍持有原 producer record，旧 Frame 的操作不向替换后的集合补项。
  Create 在捕获的目标目录内补齐相对路径；`../` 使用同一 snapshot 的祖先 Resource。跨卷绝对路径由用户输入明确新目标后解析。

## 装饰

所有 indent guide 和 cursor ancestry 高亮来自同一个 `ux.treeview` decoration provider。
Consumer 可以通过 `decorate_row` 为已导出的 viewport row 添加 ephemeral spans 或 metadata overlay，
不得在该 callback 中修改正文或提交异步业务操作。Filetype/icon 检测只在 viewport 首次需要该名称时执行并缓存，
不能在导入每一个路径时运行。文件与目录 icon 按类型分别缓存；目录使用该 viewport row 的 `expanded` 切换
open/closed glyph，共享 Data 的主结果和 preview 各自跟随自己的 Frame，无需逐行调用 `Frame:flags`。
目录与带 locations 的文件 records 使用空 `icon` 禁止默认 chevron，避免与 consumer overlay 重复绘制。
Git status、diagnostics、搜索匹配与 commit graph 的 rich highlights
遵循同一发布边界，不为每个结果节点创建常驻 extmark。
Location 的位置前缀和 snippet 仍是 native label；highlight spans 从该 Frame 对应的 Lua metadata 中按 viewport 计算，
不为每条 location 再构造和导入一份 native highlight 图。主结果和目录 preview 使用同一 metadata 准备边界。

List 的自定义 renderer 使用 `present(self, item)` 返回 `label / highlights / overlay / match_regions`，不写 buffer。
`match_regions` 为 source byte start、exclusive end、display byte start 三元组，用于前缀和插入列的匹配坐标转换。
Current/present sign 保持常数数量；多项选择由 viewport decoration 展示，不按全部结果放置常驻 signs。
