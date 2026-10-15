# Treeview 结果集接入

Status: Design。

普通 List、Picker、Searcher、LSP 结果、Git Files 和 Diffview 通过 `era.view.ResultTree` 把 Lua 业务 records 导入
native Treeview。Explorer 的 filesystem ownership 由 [Filetree](../filetree.md) 提供；搜索结果、历史删除文件和
LSP symbols 不被解释为磁盘全量目录。接入步骤见 [Treeview 接入](integration.md)。

## 模块与状态

| 模块                                    | 职责                                                                         |
| --------------------------------------- | ---------------------------------------------------------------------------- |
| `era.view.ResultSource` / `ResultPaths` | 准备业务 records、路径归组与排序；不保存交互状态或可见行                     |
| `era.view.ResultList`                   | 普通 List 的平面 producer                                                    |
| `era.view.ResultTree`                   | 导入 records，持有 native Data/State，连接 View，协调 metadata 与 Frame 发布 |
| `era.view.ResultFiles`                  | Picker/Searcher 共用的文件与 location presentation                           |
| native State / Frame                    | 选择、展开、root、cursor、投影与行映射                                       |

- 每个 ResultTree 拥有独立的 native Data、State 与 View；同一结果的目录 preview 在共享 Data 上另建 State。
  Git Files 的两棵树、Picker 的主结果与 preview 互不共享交互状态。
- Producer 在私有准备阶段完成 records 与 metadata，整体成功后才接管；失败或被取代时保留已发布结果。
- 完整替换按稳定 provider key 对齐，存活节点保留 native identity 和标记。
- Lua metadata 在提交时复制为 snapshot，按 native data revision 保存；行输入通过已发布 Frame 获取对应版本，
  不能在准备阶段把新 metadata 绑定到旧 buffer 行。业务读取以输入 Frame 为准，操作目标来自该 Frame。
- 已发布过滤结果限定业务范围：排队中的过滤或 producer 变化不能扩大旧 Frame 的操作范围。
- Picker 与 Searcher 通过共用模块协作，不静态互相依赖。

## 发布

### `ResultTree:publish`

`publish(request)` 提交一次展示请求，返回 Future；Future 只以完成值结束，不以错误拒绝：

| 完成值                         | 含义                                                                  |
| ------------------------------ | --------------------------------------------------------------------- |
| `{ kind = "Applied", frame }`  | 覆盖本次请求的 Frame 已发布；挂载时 View 已完成准备且没有待处理的选择 |
| `{ kind = "Superseded" }`      | 更新的请求在本次完成前取代了它                                        |
| `{ kind = "Rejected", error }` | Producer 准备、导入、display 提交或投影失败，或 ResultTree 已 dispose |

| 请求字段          | 含义                                                          |
| ----------------- | ------------------------------------------------------------- |
| `mode`            | `tree` / `list`                                               |
| `rootuuid`        | ChildrenOf display root 的 producer key；缺省为 producer root |
| `orders`          | 有序 keys，转为 native `filter`，文件的 locations 紧随其后    |
| `all_rows`        | 不设置 filter                                                 |
| `only_matched`    | Tree 模式也应用 filter                                        |
| `only_selected`   | 对应 `selected_only`                                          |
| `foldempty`       | 对应 `compress`；与 `list_from_depth` 同用时忽略              |
| `list_text`       | 对应 `list_text`                                              |
| `list_from_depth` | 对应 `list_from_depth`                                        |
| `default_closed`  | 在本次导入中新出现时设为折叠的 keys                           |

- 未设 `all_rows` 且为 List、分组平铺或 `only_matched` 时设置 filter；缺省 `orders` 时使用 root 下的全部 leaf。
  ResultTree 固定 `sort = "source"`、`show_hidden = false`，排名通过 filter 顺序表达，字段语义见
  [Display 选项](projection.md#display-选项)。相同 display 配置不重复构造 filter 或提交 SetDisplay。
- 尚未开始处理的请求合并为最新一次，不另加 debounce；输入 debounce 由 consumer 负责。
  Publication 等待已排队的 selection；native 发布被后续请求取代时等待最新 Frame 就绪，不把 `Superseded` 当作已完成的结果更新。
- `ready()` 在没有待处理请求、命令、聚焦意图或选择，且当前 Frame 对应最新 producer 与 State 时以 `Applied` 完成；
  失败或 dispose 后以 `Rejected` 完成。
- 行数、当前行和 preview 通知跟随 View 的 `on_frame`。Current-line observable 读取发布后的 View cursor，
  不能把迟到的 Frame cursor acknowledgement 回写成新输入或移动 Visual 端点。明确的行导航立即提交给 native View，
  observable 仅通知其余 UI。
- Metadata-only 变更也刷新共享 Data 上所有 View 的 viewport decorations；可见主结果的 publication/ready 等待其准备完成。

### 准备与原子提交

- Presentation 与 metadata 图复制按 2 ms 工作片让出主线程；共享引用与循环只复制一次，简单 metadata 未变时复用
  上一版的 immutable copy，但不合并原本不同的对象，也不改变共享引用关系。准备期间 producer revision 改变则丢弃部分结果，
  继续最新请求。
- 保留上一代 records 的精确序列化签名与 topology 顺序：records 完全相同时跳过 native 写入；topology 不变且只有少量
  records 改变时，以一个基于原 data revision 的原子 batch 更新；其余情况分块 append 完整 import，再一次 commit。
  准备后 native base revision 变化则拒绝旧 batch。签名不代替 native identity，也不推断 selection 或可见行。
- 只有 commit 后才发布；失败保留先前 surface，并以 `Rejected` 完成 publication Future。
- 完全相同的路径输入复用 producer topology，任何 producer mutation 都使这项复用失效。Locations 与业务 metadata
  仍按每次刷新重建，不能因路径集合相同而复用旧搜索结果；路径输入改变时丢弃 viewport icon cache。

### Presentation 与显示文本

Producer 的 `present(key, data, entry)` 返回 record 的 `label`、`score`、`icon`、`highlight`、`right_text`、
`fields` 与 `completeness`；`key`、`parent`、`can_expand`、`foldable` 与 `hidden` 由 ResultTree 按 producer topology、
entry 与隐藏集合覆盖。`fields` 中以下键由 ResultTree 的 viewport 装饰解释，其余键是业务 metadata：

| 键                             | 含义                                                                    |
| ------------------------------ | ----------------------------------------------------------------------- |
| `file_icon` / `directory_icon` | 图标查询名；目录按该行 `expanded` 切换 open/closed glyph                |
| `highlights`                   | `{ coll, colr, hlname }` 数组，相对 source label；`colr < 0` 表示到行尾 |
| `overlay`                      | 右对齐的 virt_text chunks                                               |
| `match_regions`                | 匹配坐标转换，见下文                                                    |

- 显示文本须为单行（见[写入范围](data.md#写入范围)）。Producer 在展示入口转义：文件名经 `strtrans`，Select provider 把 NUL、CR、LF 转义为 `\0`、`\r`、`\n`，
  callback 保留原值。
- 目录与带 locations 的文件使用空 `icon` 禁止默认 chevron，由 `directory_icon` / `file_icon` overlay 绘制图标。
- Location 的位置前缀和 snippet 是 native label；其 highlight spans 从该 Frame 对应的 Lua metadata 中按 viewport 计算，
  不为每条 location 导入一份 native highlight 图。Git status、diagnostics、搜索匹配与 commit graph 的 rich highlights
  同样在 viewport 绘制，不为每个结果节点创建常驻 extmark。
- 普通 List 的自定义 renderer 使用 `present(self, item)` 返回 `label / highlights / overlay / match_regions`，不写 buffer。
  `match_regions` 为 source byte start、exclusive end、display byte start 三元组，用于前缀和插入列的匹配坐标转换。
- Current/present sign 保持常数数量；多项选择由 viewport decoration 展示，不按全部结果放置常驻 signs。

## Consumer

### 普通 List 与 payload

- ListComposer 的 `ResultList` producer 使用有序 keys/labels/items 数组和一个 key→index 表，不为每项建立
  parent/children record。准备按 2 ms 工作片进行，较新的 reset 或 dispose 终止旧准备；只有准备成功才替换 producer，
  不能发布半份列表。完成后整份版本不可变，metadata 通过同版索引读取，不重复构造或深拷贝全量映射。
- `payloads` 保存原始 IItem 引用，可包含 callback、userdata 或 LSP action；不 deepcopy、不序列化到 Rust，
  其可变内容由调用方拥有。每次 reset 在根记录推进 payload version，即使 label 不变也生成新的 data revision。
- `payload(key)` 按当前显示 Frame 的 data revision 解析（未挂载时为 State 最新 Frame），因此新 reset 发布前继续返回旧 IItem。
  ResultTree 只保留最新 source 与仍在显示的 Frame 对应的 metadata 版本，不支持按任意旧 Frame 解析 payload。
- 空 query 直接使用 source 顺序，不构造全量 matches 或 filter。Snacks provider 的相同名称或文本通过输入序号保持独立 identity。

### 多选 List

- `ListComposer:toggle_selection()` 经 ResultTree 提交 native 选择，不维护 Lua `selected_set`。
- `ListComposer:selected_items()` 返回 Future，等待已排队的选择与 publication，再读取原始 IItem payloads。
  查询包含被过滤或隐藏的已选节点；真正 Remove 的节点不再返回。
- 确认动作等待该 Future，不用旧 Frame 判断选区为空。空选区可按业务规则使用确认时捕获的当前项；
  等待期间重复确认只接受一次，关闭 picker 后不再执行确认 callback。准备失败允许重新触发。
- AI 的发送目标和提交目标使用这两个入口；“send to all”是动作行，不参与多选标记。
  标记、过滤后的选区和确认目标来自同一 native State。

### Picker 与 Searcher

- Picker 复用既有 fuzzy/literal/regex matcher，把匹配身份和排序作为 `orders` 交给 display filter。
  `ResultTree:match` 对同一 producer revision 的普通字符串追加在前次结果内继续匹配。
- Searcher 的跨文件检索使用 `yoz.search` Job 与 Lua FileSearch generation，终态结果经 ResultFiles 准备后导入，
  遵循 [Yoz Search](../feat/yoz/search.md)；它不使用 Treeview 的 native Query session，两种查询入口的边界见 [query.md](query.md)。
- 大批普通文件列表使用 `FiletreeComposer:prepare_filepaths`：复制输入数组，在独立 producer 中分片构建路径、entries
  和排序，完成后一次性接管 records，保持原 Source 对象的引用有效。frecency 排序使用稳定的 cooperative merge sort，
  每个文件的 frecency score 只读取一次，相同分数保留 source 顺序。新的请求、同步 mutation、切根、hide 或 dispose
  使旧准备失效；准备期间旧 Frame 保持可读，首次 render 等待准备完成，当前 query 在新 source 发布前应用。
  时间片限制长循环，不承诺中断单次 Lua/VM/native 调用，也不修改全局 GC 参数。Find Files 使用此流程；
  需要立即附加 locations/diagnostics 的 producer 使用同步 reset。
- 完整 Forest import 若保留所有既有节点的 data、parent、completeness 和 sibling prefix，只生成追加操作；
  操作仍经过相同的原子提交、状态更新及资源检查。其他 import 使用完整 reconciliation。

### LSP 与 diagnostics

- Document symbols（`lua/era/fn/find-lsp-symbols.lua`）由 TreeComposer 的 ResultSource 按 LSP documentSymbol 层级准备，
  没有 LSP 结果时使用 Tree-sitter 提取；有 children 的 symbol 为 container。
- References（`lua/era/m/lsp/reference.lua`）与 diagnostics（`lua/era/fn/find-diagnostics.lua`）使用 FiletreeComposer
  的同步 `reset_filepaths`：文件按路径归组，references 以 `path:lnum:col:col_end` 生成 location 子节点，
  diagnostics 在 reset 后附加到所属文件。
- 三者均不扫描真实目录，只展示 producer 给出的路径与位置。

### Diffview 与 Git Files

Diffview 的 records 准备、materialized cache 与发布见 [Diffview Treeview 发布](../feat/diffview/main.md#treeview-发布)，
Git Files 的双树、刷新与 stage / unstage 见 [Git Files](../feat/git-files.md)。

## 行输入与范围动作

- Visual 选择由 native View 的 range action 捕获 Frame。跟随选择的业务 action 等到 selection 被接受并发布，
  批量 self selection 按值合并为 native 命令，避免逐行占用 command queue。
- Picker／Searcher 的 hide、AI 导出、quickfix 和替换经 `ResultTree:range_action` 捕获同一已发布 Frame，
  继承 View 的失步与发布中输入保护。Normal 范围扩展到显示子树（`Frame:subtree_end`），Visual 保留实际圈选端点；
  quickfix／replace-all 在捕获后遍历该 Frame 的全部行。Searcher 的单节点替换仍由活动端点决定
  location／file／container 分支，只有 container 分支使用圈选范围，并保留当前查询与完整性检查。
  同步业务 callback 返回 nil 时按 NoChange 完成；返回 native command Future 时保留其 receipt；抛错则 Future 被拒绝
  并释放 submission。业务写入只更新 producer，不修改捕获的 metadata。
- Hide 先分页读取范围内全部行的 keys，只收集尚未隐藏的 keys；全部读取成功后才统一隐藏并推进 producer revision，
  任一页读取失败不改变隐藏集合，随后由 consumer 通知发布。
- 多行 Visual Tab 保留结果集的范围语义：忽略 location；有任一未选节点则全部选中，否则全部取消，只修改范围内节点自身。
  范围聚合先按捕获 Frame 收集节点；该 Frame 的 selection summary 为空时直接全选，否则调用一次 `Frame:all_marked`，
  不逐项查询 flags，也不导出范围外的选中项。Normal／单行选择仍递归切换所属文件或目录；
  List location 的 parent 动作通过该 Frame 中的所属文件身份定位，不依赖 List 的视觉 parent。
- `ResultTree:iter_rows(frame, first?, last?)` 固定该 Frame 对应的 metadata 版本，分页返回 row、key、业务 data 和只读 entry；
  location 的 data 指向所属文件，entry 仍描述 location。批量导出须按 nodetype 区分文件与 location，避免重复输出所属文件。
- `ResultTree:root_key(frame)` 解析该 Frame 的 display root，`parent_key(key, frame)` 读取 source parent，包含画面之外的祖先。
  Confirmation、文件操作与 preview 的相对路径基准、attach-parent 都使用同一 Frame 的 root 与 data；
  不能把 producer 待发布的 root key 当作显示 root。节点存在性和文件 location 的展开判断同样来自该 Frame。
- Frame 与 Source 的只读查询见 [API 索引](module.md#api-索引)；界面导航使用 `Frame:position` / `navigate`，
  业务批量遍历按需派生映射，不能反过来作为 row authority。

## 文件操作

- 文件结果的 producer 按 directory 优先、basename 排序；List 的显式 filter 排名独立于此顺序。
- 业务 action 从已发布 snapshot 读取目标；replace 后的剩余 offsets 写回 producer，再发布新 snapshot。
- 文件 Picker 的 create/delete/rename/move 使用 [Filetree Jobs](../filetree.md)：prompt 前从显示 Frame 捕获真实资源，
  IO 与 identity 校验由 Rust 执行，rename/move 复用 Explorer 的 buffer/LSP 同步。成功后只重映射已有结果，
  保留 location identity 与 metadata，不扫描目录补入其他文件。等待已排队的 selection 后再迁移标记；
  同步结果须仍持有原 producer record，旧 Frame 的操作不向替换后的集合补项。Create 在捕获的目标目录内补齐相对路径；
  `../` 使用同一 snapshot 的祖先 Resource。跨卷绝对路径由用户输入明确新目标后解析。

## 生命周期

- 可复用的 Picker/Searcher result 在 hide 时 suspend View：保留独占 scratch buffer、已发布 Frame 和正文，
  释放 window binding 与活动 polling。重开复用该 View，以原 Frame 为增量发布基线；buffer 被删除时重新接管空 buffer，
  changedtick 失配或外部修改时执行正常 resync。重开仍提交最新 producer/display 请求，不能遗漏隐藏期间的变更。
- 隐藏期间业务读取与 publication 跟随 State 的最新 Frame；metadata 保留当前 revision 以及各 View 仍显示或暂停的 revision。
  慢于主结果的 preview 保留自己的 metadata，替换 Frame 发布后回收旧 revision。
- 普通 unmount/detach 释放 View 和 scratch buffer，保留 Data/State；Dispose 取消待发布工作并释放所有保留资源。
  晚到的异步 callback 不重新连接 surface，也不能写入重新绑定的窗口。
- 目录 preview 的窗口与 buffer 交接见 [Picker / Searcher Surface](../feat/picker-surface.md)。
