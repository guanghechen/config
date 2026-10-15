# Treeview 数据接入与所有权

Status: Design。本文定义通用 Rust data owner、provider key、写入范围、导入与 Rust/Lua 数据交接；文档入口见 [Treeview](README.md)。
原子提交与节点生命周期见 [module.md](module.md)，查询会话见 [query.md](query.md)，容量见 [action.md](action.md#默认容量)。

## Data owner 与 provider

Rust 提供通用 data owner，创建 DataHandle 并接收 provider 的完整快照与增量批次。
Filetree、Searcher、Symbols 和 Diffview 使用同一接入契约，按需要共享或独立持有 DataHandle。
Provider 解释业务资源、采集结果并决定稳定 key；owner 负责 key 对齐、NodeId 分配、source topology、
必要数据的所有权以及原子发布。State 通过该 owner 的只读 Source 读取唯一权威 tree。

- 原生 provider 可将 owned 数据交给 owner，或共享不可变的原始结果；不能通过外部可变引用绕过 owner 修改已发布数据。
- Treeview 不要求 provider 或 Lua 再保存另一棵同步更新的交互树。
- Selection、expansion、display root 和 cursor 由 State 持有；数据刷新不能携带旧交互状态覆盖它们。
- 各 consumer 可以提供不同形状的 forest。Core 不依赖 filepath、URI、LSP symbol kind 或 Git stage enum。

### 名称对照

| 逻辑概念       | Rust                                                         | Lua                                                                                                               |
| -------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| Data owner     | `DataHandle`（owner 线程上的 `Engine`）                      | `treeview.new_data(options?)` → `ux.treeview.Data`                                                                |
| 写入范围       | `DataScope::{Forest, Descendants(node), Children(node)}`     | `{ kind = "forest" }`、`{ kind = "descendants" \| "children", node }`                                             |
| Provider       | `ProviderHandle` / `ProviderId`                              | `data:create_provider(scope)` → `ux.treeview.Provider`                                                            |
| 记录           | `Record { key, parent, data, completeness }`                 | 行式 `IRecord[]` 或列式 `IColumns`                                                                                |
| 节点数据       | `NodeData`；增量字段 `NodePatch`                             | record / operation 的同名字段                                                                                     |
| Native payload | `NodeData.payload: Option<Arc<[u8]>>`                        | 无                                                                                                                |
| 完整快照       | `Import { base_revision, scope, records }`、`ProviderImport` | `data:import(records, scope?, base?)`、`provider:import(records, base?)`                                          |
| 分块导入       | binding `Upload`，合并为一次 `Import` / `ProviderImport`     | `data:begin_import(scope?, base?)`、`provider:begin_import(base?)` → `upload:append()` / `commit()` / `dispose()` |
| 增量           | `Batch { base_revision, operations }`、`Operation`           | `data:batch(operations, base?)`、`provider:batch(operations, base?)`                                              |
| Children 页    | `ChildrenPage`；native reader 使用 `children_delta`          | `read_children(request)` 返回 `{ records, done }`                                                                 |
| Query 结果     | `QueryResult`（`Source.query_results`）                      | `source:query_result(scope)`                                                                                      |

省略 `base` 时 Lua 捕获调用时的 data revision；`data:import` 省略 `scope` 时为 forest。

## Provider key 与 NodeId

Provider key 是 DataHandle 内唯一的 opaque key，由 provider 决定，owner 建立 key 到 NodeId 的索引。
Lua 来源使用字符串表达 key，按值精确比较，不隐式正规化路径、名称、大小写或 Unicode。
多个 provider 共用 DataHandle 时由接入层分配互不冲突的 key 空间；不同 DataHandle 可使用相同 key。

- 同一存活 key 保留 NodeId，更新 label、业务位置、metadata、parent 或 sibling 顺序不更换身份。
  Parent 改变仍执行 Reparent 与标记继承规则，不能仅因 ID 不变而跳过状态补丁。
- 新 key 由 owner 分配 NodeId；provider 不从路径、行号或对象地址生成 NodeId。NodeId 不经 Lua number 传输。
- 真正 Remove 后 key 的映射失效，相同 key 再出现分配新 NodeId。旧 Frame、任务和已知 NodeId
  不能通过重新查询 key 被悄悄替换为新节点。
- 完整快照内同一 key 只能声明一次。增量批次对同一节点的多次操作按顺序解释；显式 Remove 后再 Insert
  是新 identity，不等同于 Update。校验失败不发布任何候选节点或 key 映射。
- 同一业务资源可以有多个 occurrence，例如 `staged:src/a.lua` 与 `unstaged:src/a.lua`，分别使用不同 key/NodeId；
  业务资源 identity 留在 payload，不用于隐式合并树节点。
- Provider 对跨刷新 key 的稳定性负责。LSP symbol 从第 10 行移至第 11 行时，若 provider 保持原 key，
  owner 更新位置并保留 identity；若提交新 key，则按新节点处理。Treeview 不凭名称或邻近位置恢复选择与展开。

## 写入范围

接入输入固定目标 DataHandle、写入范围、更新方式和来源 context，再提供节点数据：

- Identity 与结构：provider key、parent 关系、有序 sibling 关系与 children 完整性。完整快照必须能确定有序 forest；
  同一节点不能有两个 parent，也不能形成环。输入同时携带 parent 与 children 描述时两者必须一致。
- 节点属性：是否可展开及显示、filter/sort 需要的结构化字段。声明为 leaf 时 children 必须为空且 complete；
  业务上的“文件”不直接决定它在该 tree 中是否为 leaf。Label、icon、highlight 与 right text 必须是单行文本，
  不含 LF、CR 或 NUL；import、batch、update 与 native provider 写入一律校验，违反时整批输入以 `InvalidUpdate` 拒绝，
  不截断或部分提交。转义由 producer 在展示入口完成。
- 业务详情：打开、预览或执行业务动作所需的数据，或指向不可变 Rust 业务数据的引用，由 provider 解释；
  选择与导航只使用 NodeId、结构和已定义的交互前提。
- 来源 context：base data revision、children request token 或 Query generation，按实际来源使用，不互换。

批内 parent 索引等紧凑编码只是传输形式，不是持久 identity，必须验证索引边界和目标归属。

写入范围由 owner 显式校验：`forest` 覆盖整个 forest，`descendants` 覆盖 anchor 以下整棵子树，
`children` 只声明 anchor 的直接 children。范围不从当前显示行、filter 结果或本批列出的 key 推断，
范围外的数据不因本次刷新缺项而删除。例如刷新文件 A 的 symbols 只替换 A 的范围，不删除文件 B 的 symbols；
替换一个 parent 的 children 槽位不清空存活 child 的后代。

- Provider 的写入范围互斥：`data:create_provider(scope)` 与现有 provider 范围重叠时返回 `InvalidUpdate`。
  `forest` 与任何范围重叠；`children` 锚点相同即重叠；`descendants` 与锚点相同或位于其子树内的任何锚点重叠。
- Provider 的 import 与 batch 不能写出自身范围；Remove 若会使其他 provider 的范围锚点失效，返回 `InvalidUpdate`，
  由有权协调这些范围的上层提交显式更新。范围锚点失效时不按同名对象重绑定。
- 每个 provider 至多一个 Query 会话，重复创建返回 `InvalidUpdate`；会话语义见 [query.md](query.md)。
- 不经 provider 的 `data:import` / `data:batch` 不做 provider 范围校验，由接入层保证不越权。

## 完整快照、增量与分页

完整快照表示 provider 对所声明范围给出的完整权威结果。Owner 按 key 与当前数据对齐：

- 存活 key 更新字段及关系，新 key 分配节点，范围内缺失的成员移除；成功的空快照清空该范围。
- 需要保留的节点先迁移到合法位置，再移除旧 parent；owner 从快照生成满足逐步约束的内部更新顺序。
- 未枚举或仍 unknown/partial 的范围不能伪装成完整快照。只知道直接 children 时声明该槽位，只知道部分变化时使用增量或分页。

增量批次只修改显式列出的节点、字段或关系，未列出的成员保持不变。字段未提供表示保留，清除可选字段须明确表达。
显式 operations 保留输入顺序，不当作完整快照改排。Provider 已有 delta 时直接提交；只有完整快照时由 Rust 对齐，
不要求 Lua 维护树来求差异。

分页使用对应来源协议，不能仅根据“这是一个 batch”决定是否删除旧数据：

- 普通 children 读取按 request epoch/sequence 合并已知子项；刷新期间保留旧集合，完整成功终态才按本轮全部页确认缺失项移除。
- 新查询首批是 [query 契约](query.md#结果替换与分页)中的显式结果范围替换，可以声明本轮仍 partial；
  它结束的是旧查询结果集合，不能推广为普通 partial children 刷新也可删除缺项。后续页只追加本轮数据。
- 首批未保留而被真正 Remove 的旧节点，后续页即使再次出现同 key 也只能取得新 NodeId；分页不延长已删除 identity 的生命周期。

分块导入在 `commit()` 前只暂存于私有候选，完整接收并校验后一次提交；分块本身不是发布部分数据的许可。
需要逐页发布的 provider 必须使用有明确 partial、归属和终态的分页协议。候选、在途结果和旧 snapshot 共同受预算约束。

所有输入都经 owner 的[串行原子提交](module.md#节点更新批次)：写入前校验范围、identity、topology、实际 context 与容量；
查询结果在提交处重验 generation。失败丢弃本批候选，保留已提交的数据和状态；错误分类、背压与重试见 [action.md](action.md)。
原子性不回滚 provider 已发生的业务 IO。

## Rust 原生路径

Filetree 的目录 worker 直接向 owner 提交 owned 数据，Git annotations 共享 native snapshots，不经过 Lua readdir table。
Owner 建立结构和 identity 索引，不从可变外部容器借用数据。Searcher、LSP symbols 与 Diffview 的业务 records
由 Lua producer 准备后批量导入，见[结果集接入](results.md)。

- `NodeData.fields` 保存结构化字段，供 filter/sort 及 Lua 按需读取。Native provider 的私有二进制数据由
  `NodeData.payload` 持有；core 不解释该编码，Lua 导入与节点出站记录不包含它，业务 adapter 通过自己的资源 API 解读。
- Payload 随 NodeData 版本不可变共享。完整快照提供该版本的完整 payload；增量 `NodePatch.payload` 未提供时保留，
  显式 `Some(None)` 清除。Payload 更新不更换 NodeId，不改写旧 Source/Frame 持有的版本。
- Payload 字节计入批次与 source 容量；retained 计费与 `Value::Bytes` 共用 allocation ledger，
  同一 buffer 被多个节点、字段或版本引用时只计费一次，最后一个受跟踪引用释放后才撤销。
- 完整快照对齐需读取整个输入范围，成本不只与变化量有关；只有来源与语义均未变化且版本可验证时，才能跳过重复导入。

## Lua 来源与 FFI

LSP/Tree-sitter 等来源由主线程 adapter 提取必要字段并批量交给 Rust。ResultSource/ResultPaths 保存业务 records，
ResultTree 准备版本化 metadata 与有界列式输入；这些 producer 不保存交互状态或可见行映射。
行式与列式输入使用同一逻辑契约，所有入口执行相同的长度、类型、引用和语义校验；列长度、缺失字段与清除标记须无歧义。

- 异步工作或后续队列处理需要的数据，在离开本次 Lua 调用前取得 Rust 所有权或不可变 Rust 引用；
  不能将 Lua 临时借用交给 worker。导入后 Lua 修改或回收原 table/string 不改变已提交数据或在途候选。
- 原始 LSP response、TS 对象、Lua 函数和 Neovim 可变对象引用不作为节点 payload；adapter 提供后续工作真正需要的结构化值。
- 按节点数与字节数限制导入批次与暂存，解码与暂存本身计入预算，不能先无界导入再检查硬容量。
- Source 不变时，Finder 后续输入只更新 filter/sort，候选不重复传输；跨文件内容搜索仍由 provider 执行新查询。
- 提交结果只返回结果与必要句柄，不默认返回整份 key 到 NodeId 映射；单项定位按需查询。

Rust 原生路径与 Lua 路径共享逻辑语义，不要求两者都经过 Lua 列式编码。
Binding 方法和列字段见 [Lua 类型](../../../lua/__types__/ux/treeview.lua)，使用方式见[接入指南](integration.md)。

## Snapshot 与出站读取

Data、Source、Frame 和原生结果通过 userdata 句柄在 Lua 侧引用；数据、topology、key 索引和行到 NodeId
的映射留在 Rust。句柄持有相应 Rust 所有权，不依赖临时 provider/Lua 对象继续存活。

- 绘制时批量读取当前发布所需的文本与装饰，不每帧导出完整节点记录、parent 链或业务 payload；
  正文与可见装饰的导出遵循 [render 契约](render.md)。
- 行输入传实际 Frame 与 row/range，由 Rust 解析目标。打开、预览或业务动作按需读取目标详情并绑定所请求的
  Source/节点身份；副作用执行前继续校验当前动作前提，不用同 key 的重建节点替代原目标。
- 旧 Source 可共享不可变业务数据，provider 外部更新不能改写旧版本，也不为单项读取重新物化整棵树。
- 只读标量与分页接口：
  - `source:key(id)` / `source:parent(id)` 读取标量身份，节点缺失返回 nil；单个 key 超过出站 key 预算报错。
    `source:node(id)` / `frame:node(id)` 读取单节点详情，缺失返回 nil。
  - `source:children(id?, first, last)` 按 source 顺序读取直接 children，省略 `id` 读取 forest 顶层。
  - `frame:node_keys(ids)` 只导出 identity；全部返回或报错，不返回部分结果。
  - `frame:row_keys(first, last)` 对 1-based 闭区间返回不超过 key 字节预算的最长连续前缀，
    调用方从 `first + #keys` 续读；非空范围至少返回一个 key，单个 key 超过预算报错。
  - `frame:subtree_end(row)` 返回该行当前显示子树的最后一行；折叠节点与 List 行返回自身，越界返回 nil。
    范围动作与跳过子树的遍历用它取边界，不导出 decorated rows。
  - `frame:flags(id)`、`frame:marked_nodes(visible_only)` 与 `frame:all_marked(ids)` 见 [selection](selection.md#lua-api)。
  - 以上读取的行数、项数与 key 字节上限，以及 NodeId 数组输入上限，见[默认容量](action.md#默认容量)。
- `source:same_content(other)` 比较同一 DataHandle 内的 NodeId 集合、parent 关系与完整 NodeData（含 fields 和 native payload）；
  加载状态、children 完整性、请求进度和 sibling 顺序不参与比较，不同 owner 始终返回 false。
  只检查两份 Source 之间变化的节点，成本取决于变化量而不是节点总数，可在每次装饰判定时调用。
  按行缓存还须独立校验 layout revision，不能据此跨布局复用。

当前 consumer 的 records、metadata、查询与 Frame 接入见 [results.md](results.md)；
Filetree 的资源 identity 与目录读取见 [Filetree](../filetree.md)。
