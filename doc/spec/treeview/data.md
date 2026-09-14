# Treeview 数据接入与所有权

Status: Design。本文定义通用 Rust data owner、provider key、更新范围及 Rust/Lua 数据交接。
原子提交与节点生命周期见 [module.md](module.md)，查询归属见 [query.md](query.md)。

## Data owner 与 provider

Rust 提供通用 data owner，创建 DataHandle 并接收 provider 的完整快照与增量批次。
Filetree、Searcher、Symbols 和 Diffview 使用同一接入契约，按需要共享或独立持有 DataHandle。
Provider 解释业务资源、采集结果并决定节点 identity；owner 负责 key 对齐、NodeId 分配、source topology、
必要数据的所有权以及原子发布。Treeview state 通过该 owner 的 readonly source 读取唯一权威 tree。

- 原生 provider 可将 owned 数据交给 owner，或共享不可变的原始结果；不能通过外部可变引用绕过 owner 修改已发布数据。
- 原始 Git/LSP/搜索结果可以是 provider 的业务数据；Treeview 不要求 provider 或 Lua 再保存另一棵同步更新的交互树。
- Selection、expansion、display roots 和 cursor 仍由 StateHandle 持有；数据刷新不能携带旧交互状态覆盖它们。
- 各 consumer 可以提供不同形状的 forest。Treeview core 不依赖 filepath、URI、LSP symbol kind 或 Git stage enum。

## Provider key 与 NodeId

Provider key 是 DataHandle 内唯一的 opaque key，由 provider 决定，Rust owner 建立 key 到 NodeId 的索引。
Lua 来源使用字符串表达 key，按其值精确比较，不隐式正规化路径、名称、大小写或 Unicode。
多个 provider 共用 DataHandle 时，由接入层分配互不冲突的 key 空间；不同 DataHandle 可使用相同 key。

- 同一存活 key 保留 NodeId，更新 label、业务位置、metadata、parent 或 sibling 顺序不更换身份。
  Parent 改变仍执行既有 Reparent 与标记继承规则，不能仅因 ID 不变而跳过状态补丁。
- 新 key 由 owner 分配 NodeId；provider 不从路径、行号或对象地址生成 Treeview NodeId。
  NodeId 使用既定 opaque u64/string 协议，不经 Lua number 传输。
- 真正 Remove 后 key 的当前映射失效；相同 key 再出现分配新 NodeId。旧 frame、任务和已知 NodeId
  不能通过重新查询 key 被悄悄替换为新节点。缓存淘汰不等同于 Remove。
- 完整快照内同一 key 只能声明一次。增量批次对同一节点的多次操作按顺序解释；显式 Remove 后再 Insert
  是新 identity，不等同于 Update。校验失败不发布任何候选节点或 key 映射。
- 同一业务资源可以有多个 occurrence，例如 `staged:src/a.lua` 与 `unstaged:src/a.lua`，分别使用不同 key/NodeId。
  业务资源 identity 留在 payload，不用于隐式合并树节点。
- Provider 对跨刷新 key 的稳定性负责。LSP symbol 从第 10 行移至第 11 行时，若 provider 保持原 key，
  owner 更新位置并保留 identity；若 provider 无法确认对应关系而提交新 key，则按新节点处理。
  Treeview 不承诺仅凭相同名称或邻近位置自动恢复原来的选择与展开状态。

## 逻辑输入与更新范围

接入输入固定目标 DataHandle、provider 写入范围、更新方式和来源 context，再提供节点数据。
以下定义逻辑字段，不要求原生 Rust 与 Lua binding 使用相同的物理编码：

- Identity 与结构：provider key、parent 关系、有序 sibling/children 关系，以及 children 完整性。
  完整快照必须能确定有序 forest；同一节点不能有两个 parent，也不能形成环。
- 节点属性：是否可展开及显示、filter/sort 需要的结构化字段。声明为 leaf 时 children 必须为空且 complete；
  是否是业务“文件”不直接决定它在这个 provider 的 tree 中是否为 leaf。
- 业务详情：打开、预览或执行业务动作所需的数据，或指向不可变 Rust 业务数据的引用，由 provider 解释。
  Treeview 的选择与导航只使用 NodeId、结构和已定义的交互前提，不解析业务 payload。
- 来源 context：直接更新的 base data revision、provider source 版本，或相应查询会话/generation、children request token。
  使用实际适用的 context，不把这些版本当作可互换的 token。

Key 输入由 owner 解析为当前 NodeId；已有可靠 NodeId 的 Rust 接入可直接使用低层 TreeChangeBatch。
批内 parent 索引等紧凑编码只是一种传输形式，不是持久 identity；必须验证索引边界和目标归属。
输入若同时携带 parent 与 children 描述，两者必须一致，不能维护两套相互矛盾的结构事实。

写入范围由 owner 在接入时明确校验，可以覆盖整个 forest，或 provider 拥有的子树、children 槽位、查询结果范围。
范围不由当前显示的行、filter 结果或本批恰好列出的 key 推断；范围外的数据不因本次刷新缺项而删除。
例如刷新文件 A 的 symbols，只替换 A 的 symbol 范围，不能删除文件 B 的 symbols。
替换一个 parent 的 children 槽位只声明直接子项集合，不因存活 child 的后代未在响应中展开而清空其后代。

Owner 必须校验跨范围引用与删除影响。Remove 的子树若包含另一个 provider 仍拥有的数据，不能把整棵子树
视为本次替换范围；由有权协调这些范围的上层提交显式更新，否则拒绝。范围锚点失效时不能按同名对象重绑定。

## 完整快照、增量与分页

完整快照表示 provider 对所声明范围给出的完整权威结果。Owner 按 key 与当前数据对齐：

- 存活 key 更新字段及关系，新 key 分配节点，范围内明确缺失的成员移除；完整成功空快照清空该范围。
- 需要保留的节点先迁移到合法位置，再移除旧 parent；由 owner 从快照生成满足逐步约束的内部更新顺序。
  快照记录的传输先后不要求等同于这一内部提交顺序。
- 未枚举或仍 unknown/partial 的范围不能伪装成完整快照，以缺项为理由删除未返回的数据。
  Provider 只知道直接 children 时声明该槽位的范围；只知道部分变化时使用增量或相应分页协议。

增量批次只修改显式列出的节点、字段或关系，未列出的成员保持不变。增量可表达 Insert、Update、Reparent、
Reorder 和 Remove 等既有操作；字段未提供表示保留，清除可选字段须明确表达。显式 operations 保留输入顺序，
不能当作完整快照任意改排。Provider 已有 delta 时直接提交；只有完整快照时由 Rust 对齐，不要求 Lua 维护树来求差异。

分页使用对应来源协议，不能仅根据“这是一个 batch”决定是否删除旧数据：

- 普通 children 读取按 request epoch/sequence 合并已知子项；刷新时保留旧集合，完整成功终态才确认缺失项移除。
  同一请求已提交的前几页也属于完整结果，不能只用最后一页与旧集合比较。
- 新查询首批是 [query 契约](query.md#结果替换与分页)中的显式结果范围替换，可以声明本轮仍 partial；
  它结束的是旧查询结果集合，不能推广为普通 partial children 刷新也可删除缺项。后续 page 只追加本轮数据。
- 流式新查询首批未保留而被真正 Remove 的旧节点，后续页即使再次出现同 key，也只能取得新 NodeId。
  分页不延长已删除 identity 的生命周期；需要保留的 identity 必须由 provider 明确保持存活，不能事后复活。

完整快照可以分块传输到有界私有候选，完整接收并校验后才提交；传输分块本身不是对外发布部分数据的许可。
若 provider 希望逐页发布，必须使用有明确 partial、归属和终态的分页协议。候选、在途结果和旧 snapshot
共同受资源预算约束，不为实现完整快照建立无界暂存。

所有输入都经 owner 的 [串行原子提交](module.md#节点更新批次)。写入前校验范围、identity、topology、
实际 context 与容量；查询结果在真正提交处重验 generation。过期结果不能通过重新分配 NodeId 绕过失效。
失败丢弃本批候选，保留此前已提交的数据和状态；错误分类、背压、完成通知预留及显式重试沿用 [action.md](action.md)。
Data/source/state 的原子性不回滚 provider 已发生的业务 IO。

## Rust 原生路径

Rust 搜索、Git 与文件 provider 的结果通过 Rust 接口直接交接，不先展开 Lua table 再导回 owner。
Owned 数据可以移动所有权；不可变结果可以共享持有。Owner 建立必要的结构和 identity 索引，数据所有权
与引用生命周期可追踪，不能从仍被 provider 修改的容器借用数据构建 snapshot。

共享结果不保证所有后续操作零分配或零复制。输入类型与 owner 表示不同时仍需转换或建立索引；旧 frame 持有
不可变版本时，更新需要保留旧版本可读性。使用受影响节点的 overlay/journal 准备更新，不为局部候选修改深复制整树；
具体共享布局与 COW 粒度通过实际持帧和更新分布测量决定。

完整快照对齐仍须读取整个输入范围，不能将其性能描述为只与变化量有关；已有 delta 才能直接缩小输入工作量。
只有来源与语义均未变化且版本可验证时，才能利用 provider revision/changedtick 跳过重复导入。

## Lua 来源与 FFI

LSP/Tree-sitter 等来源由主线程 adapter 提取必要字段并批量交给 Rust。热路径与大批量输入优先扁平列式，
adapter 在提取时直接填充批次，不先构造第二套完整节点对象。小量行式输入可以使用同一逻辑契约；binding
缓存重复字段名，所有入口执行相同的长度、类型、引用和语义校验。列长度、缺失字段与清除标记须无歧义。

- 异步工作或后续队列处理需要的数据，必须在离开本次 Lua 调用前取得 Rust 所有权或有效的不可变 Rust 引用。
  同步期间可以借用 Lua 字节进行校验与比较，但不能将 Lua 临时借用交给 worker。
- 导入后 Lua 修改或回收原 table/string 不改变已提交数据或在途候选。原始 LSP response、TS 对象、Lua 函数
  和 Neovim 可变对象引用不作为通用 worker 的节点 payload；adapter 提供后续工作真正需要的结构化值。
- 可共享未变的 Rust 字符串与业务数据，但 Lua 来源的必要字符串通常仍需取得 owned 副本。按节点数与字节数
  限制导入批次与暂存，不承诺无复制，也不采用未经收益验证的裸指针共享内存或自定义二进制协议。
  解码与暂存本身计入预算，不能先无界导入再检查硬容量。
- Source 不变时，Finder 后续输入只更新 filter/sort，候选不重复传输；跨文件内容搜索仍由 provider 执行新查询。
- Lua 数据提交 binding 进入同一 owner 提交路径；返回提交结果与必要句柄，不默认返回整份 key 到 NodeId 映射。
  单项定位需要映射时按需查询。经过 dispatch 的命令继续使用既有 Future 完成协议。

Rust 原生路径与 Lua 路径共享逻辑语义，不要求两者都经过 Lua 列式编码。
具体 binding 方法名、列排布及内部容器在实现中确定；这些实现选择不能改变本契约的所有权、identity 或提交语义。

## Snapshot 与出站读取

Data、snapshot、frame 和原生结果通过 userdata 句柄在 Lua 侧引用，数据、topology、key 索引和 row 到 NodeId
映射留在 Rust。句柄持有相应 Rust 所有权，不依赖临时 provider/Lua 对象继续存活。

- 绘制时批量读取当前发布所需的文本与装饰；不每帧导出完整节点记录、parent 链或业务 payload。
  变更正文与可见装饰的导出、分段 staging 及 frame 交换遵循 [render 契约](render.md)，不将按需读取等同于 viewport 文本虚拟化。
- 行输入传实际 frame 与 row/range，由 Rust 解析目标。打开、预览或业务动作按需读取目标详情，并绑定所请求的
  snapshot/节点身份；副作用执行前继续校验当前动作前提，不用同 key 的重建节点替代原目标。
- 旧 snapshot 可共享不可变业务数据；provider 外部更新不能改写旧版本。字段裁剪与共享不意味着可以借用
  可变业务对象冒充不可变 payload，也不要求为了单项读取重新物化整棵树。

## Consumer 接入与验收

- Filetree：Rust 目录读取/watch 提供快照或 delta，普通分页遵循 children 完整性规则。资源 identity 与重命名
  由 Filetree 决定；Treeview 接收既有节点更新，不从 filepath 猜测移动。
- Searcher：原生结果直接交接，文件与每条 match 都是 provider tree 中有 key/NodeId 的节点，文件可拥有命中 children。
  命中包含业务定位与展示所需字段；Lua 不在 layout 完成后插入没有 Rust 行映射的命中行。替换与分页按 query context 提交。
- LSP/Tree-sitter Finder：Lua adapter 提取层级、必要字段和 provider key，Rust 对齐 scoped snapshot 并保留候选；
  对已有候选的输入过滤只更新 filter/sort；需要服务端按 pattern 检索时遵循 query 协议接收新结果。
  Provider 的 symbol identity 稳定程度由其 key 策略决定。
- Diffview filetree：Rust Git 结果直接进入 owner，staged/unstaged 等 occurrence 使用独立 key/NodeId，共享业务文件资料。
  更新一个所属范围不清除另一个范围；具体 stage 与资源操作由上层解释。

使用同一组语义 fixture 验证原生 owned、共享不可变数据与 Lua 批量输入：

- 同 key 的 metadata、位置、重排与 reparent 保留 NodeId，显式删除后同 key 重现取得新 ID；旧任务不能重绑定。
- 重复 key、非法 parent/循环、外实例 ID、越界批内索引、列长度错误、越权范围和 stale context 均不发布部分候选。
- Scoped snapshot 的缺项移除与空结果，delta 未列出项保持，直接 children 刷新保留存活 child 的已有后代。
- Query 首批替换与普通 children partial 缺项的区别、跨页同 key、完整终态及硬容量失败；不复活已移除的 ID。
- Lua 输入在导入后被修改或 GC、原生 source 释放、旧 snapshot 与新更新同时存活，所得数据和 identity 保持一致。
- 四类 consumer 的行输入均由 Rust frame 映射；展示裁剪、业务单项读取及缓存淘汰不改变 source/selection。
- 记录完整快照扫描、已知 delta、FFI 调用与字节量、分配、持帧更新以及 Rust/Lua/Neovim 合计内存。
  本契约不将实验的合成数据耗时作为生产延迟保证；端到端规模与发布策略遵循 [性能验收](performance.md)。
