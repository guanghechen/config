# 结果集接入

Status: Design。

Picker、Searcher 和 Diffview 使用通用 Treeview records。Explorer 的真实 filesystem ownership 仍由
[Filetree](../../../spec/design/filetree.md) 提供；搜索结果、历史删除文件和 LSP symbols 不被解释为磁盘全量目录。

## 数据与状态

- `era.view.ResultSource` / `ResultPaths` 是业务 records 的 producer，支持批量准备和路径归组。
  它们不计算可见行，也不保存 selection、expansion 或 cursor。
- `era.view.ResultTree` 导入 records，持有一个 Data 和 State，并连接 native View。
  完整替换按稳定 provider key 对齐，存活节点保留 native identity 和标记。
- `era.view.ResultFiles` 提供 Picker/Searcher 共用的文件结果与 location presentation；两者没有静态互相依赖。
- Lua 业务 metadata 在提交时复制为 snapshot，并以 native data revision 保存。Action 通过已发布 Frame
  获取节点与 metadata；prepare 阶段不可把新 metadata 绑定到旧 buffer 行。
- Presentation 每批最多 256 条 records；metadata 图复制每 1024 个字段检查一次 2 ms 时间片，
  超出时间片时让出主线程。
  共享引用与循环只复制一次；准备期间 producer revision 改变则丢弃部分 snapshot，继续最新请求。
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

`Frame:flags(id)` 从该 immutable frame 读取 marked/expanded，包含当前被折叠或过滤的节点。
界面导航使用 `Frame:position` / `navigate`；业务批量遍历可以按需派生映射，不能反过来作为 row authority。
`Frame:marked_nodes(visible_only)` 在 native 中查询当前帧的选中身份，返回分页读取的 NodeIds；visible
查询遵循行顺序，完整查询包含折叠与过滤之外的标记。`Frame:node_keys(ids)` 仅导出 identity，单次最多
1024 个节点、1 MiB keys。批量动作只解析选中节点，不能逐行导出 header、完整节点或装饰数据。

## 发布、输入与生命周期

- Result 的 native 模式不写 buffer；行数、当前行和 preview 通知跟随 `on_frame`。普通 ListComposer 继续使用原 draw surface。
  Current-line observable 读取发布后的 surface cursor，不能将迟到的 Frame cursor acknowledgement 回写成新输入、移动 Visual 端点。
- Publication 等待已排队的 selection；native draw 被后续请求取代时等待最新 Frame 就绪，不能将
  `Superseded` 通知作为已完成的结果更新交给调用方。
  Metadata-only 变更也刷新共享 Data 的所有 viewport decorations；可见主结果的 publication/ready 等待其准备完成。
- Visual 选择由 native View 的 range action 捕获 frame。跟随选择的业务 action 等到 selection 被接受并发布，
  批量 self selection 按值合并为 native 命令，避免逐行占用 command queue。
- 多行 Visual Tab 保留结果集的范围语义：忽略 location；有任一未选节点则全部选中，否则全部取消，
  只修改范围内节点自身。Normal／单行选择仍递归切换所属文件或目录。List location 的 parent 动作
  通过该帧中的所属文件身份定位，不依赖 List 的视觉 parent。
- Matcher 保留输入 debounce；native Result 发布仅合并同轮请求，不再追加 128 ms render debounce。
- Directory preview 使用共享 Data 上的独立 State。切回文件先更换 buffer 再 detach，防止销毁浮窗。
- 可复用的 Picker/Searcher result 在 hide 时 suspend View：保留独占 scratch buffer、已发布 Frame 和正文，
  释放 window binding 与活动 polling。重开复用该 View，以原 Frame 为增量发布基线；buffer 被删除时重新接管空 buffer，
  changedtick 失配或外部修改时执行正常 resync。重开仍提交最新 producer/display 请求，不能遗漏隐藏期间的变更。
  隐藏期间业务读取与 publication 跟随 State 的最新 Frame；metadata 保留当前 revision 以及各 surface 仍显示或暂停的 revision。
  慢于主结果的 preview 保留自己的 metadata，替换 Frame 发布后回收旧 revision。
  普通 unmount/detach 释放 View 和 scratch buffer，保留 Data/State；Dispose 取消待发布工作并释放所有保留资源。
  晚到的异步 callback 不重新连接 surface，也不能写入重新绑定的窗口。
- Diffview refresh 等待 publication Future，稳定 key 定位等待 native 行可用；buffer 行与 action 对象来自同一帧。
- Diffview 初始仅准备 commit headers；未展开的缓存 files 不进入 inline records 或 header metadata。
  首次 inline 展开才准备该 commit 的 files，后续展开／折叠只提交 native State 命令，不重新构造 producer、
  解析 icons 或发起 import。Standalone filetree 独立准备自己的 records，reveal 显式准备目标 commit files。
- 文件结果的 producer 按 directory 优先、basename 排序；List 的显式 filter 排名独立于此顺序。
- 业务 action 从已发布 snapshot 读取目标；replace 后的剩余 offsets 写回 producer，再发布新 snapshot。

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
