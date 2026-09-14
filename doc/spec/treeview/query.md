# Provider 查询生命周期

Status: Design。本文定义向 Rust Treeview 提供结果的 provider 查询会话、generation、取消和结果替换。
节点提交与 identity 遵循 [核心契约](module.md)及 [data 接入契约](data.md)，串行提交与资源预算遵循 [action queue](action.md)。

## 会话与归属

每个 provider 查询会话由上层 Rust 持有，绑定目标 DataHandle 及明确归属的结果范围。
一个会话共享一份当前查询；需要同时保留不同查询的消费者使用独立会话，各自只能替换所属范围。
不能让两个独立会话无归属协调地覆盖同一结果范围，也不能用一个全局 generation 作废所有 provider。

- 会话具有生命周期内不混淆的身份；generation 在该会话内单调推进，溢出前报错、不回绕。
  会话销毁后重建不能让旧 token 重新有效。Lua 若接触这些身份，使用 opaque token 原样传递。
- 每次查询固定 pattern、搜索范围及实际影响结果的 options。任一条件变化或显式重试都产生新 generation；
  `a -> ab -> a` 的两次 a 不是同一次查询，不能仅按文本相等接受旧结果。
- 数据批次、进度、成功、失败和取消通知均携带会话与 generation 归属；分页额外携带顺序信息。
  同一轮内部的 worker 由 provider 汇合，不通过多个无协调的写入者修改 tree。
- Provider 负责执行查询与取消，data owner 的串行入口负责验证归属和提交；Rust Treeview core
  不解释搜索算法、LSP 方法或业务 payload，Lua 不维护另一份查询调度与结果权威数据。
  涉及 Neovim/Lua API 的 provider 调用由主线程 adapter 执行并回传带归属的通知，worker 不直接调用 Lua/Neovim。

查询 generation 与 data revision、filter/sort 输入版本、children request epoch、selection/expansion
标记 generation 分开使用。前者决定一次 provider 查询是否仍有提交资格，不代替其他版本校验。

## 接受新查询与调度

新查询通过 owner 的 action queue 做短提交：固定输入、推进 generation、替换该会话的最新待执行请求，
并使旧 generation 失去修改当前查询数据和状态的资格。异步工作随后按 provider 预算启动，不占住队列等待 IO。
只有这次提交成功后新查询才生效；入队或校验失败保持原查询，不提前作废仍有效的工作，也不延迟重放被拒绝输入。

- 每个会话尚未启动的请求只保留最新一个。被替换的待执行请求不启动 IO，也不要求依次完成用户输入过的 pattern。
- 在途旧查询收到尽力取消请求；无法即时取消时，其返回结果仍按过期处理。取消用于减少工作，
  提交校验保证正确性，不依赖外部服务确认取消后才使旧 generation 失效。
- 在途工作受 provider 的并发与内存预算约束。旧任务尚未停止时不能假定资源已释放，也不能为每次输入
  无界启动替代任务。恢复容量后启动最新仍有效的待执行请求；Rust 长任务在有界工作段之间检查取消。
- 新查询生效不调用 ClearSelection，不直接 Remove 节点，也不清空 buffer。旧已提交结果仍保留其原归属，
  等待新结果替换；推进查询 generation 本身不分配节点或改写选择标记。
- 显式取消而不发起新查询时，关闭当前查询的结果接收资格、移除其 pending 并请求取消在途工作。
  会话释放也关闭接收资格；迟到通知只完成旧工作清理。Detach 一个 view 本身不销毁仍被其他消费者持有的会话。

查询输入替换只合并尚未执行的 provider 工作；Add、Toggle、SetExpanded 等用户标记命令仍逐项按序提交。
若接入经 dispatch 返回 Future，沿用 [一次完成协议](action.md#dispatch-与-future)：Applied 表示输入已提交，
不表示搜索或显示完成。后续被新查询替换不修改已经完成的 Future，查询结果状态由 provider 单独表达。

## 提交时校验

结果回到 action queue 后，在真正发布 data/state/query 补丁的同一提交阶段校验：

1. DataHandle、会话和目标结果范围仍有效，来源有权修改该范围。
2. 通知的 generation 仍是该会话当前接受结果的 generation，本轮未取消或结束。
3. 分页属于本轮、顺序有效，数据更新满足 topology、identity、容量与其他实际动作前提。
4. Owner 按当前数据准备更新，原子提交节点变化与本轮进度/终态，再释放借用并通知 views。

收到结果或入队前可以提前拒绝已知过期内容，但不能省略最终校验。私有候选在后台准备时，也必须在发布前重验归属。
Generation 校验不能绕过 `TreeChangeBatch` 的 base revision 或其他 context 检查；异步 provider 可以由 owner
在当前版本上解释仍有效的结果，不能将旧 revision 的 operations 不经验证地套用到新 topology。

- 过期成功与数据批次不写 tree；过期失败、进度和取消通知不改当前查询的 loading、error、计数或结果。
  普通过期通知不作为当前查询失败向用户报告。
- 重复或乱序 page 不重复追加、不推进本轮页序，不把缺页标为完整。成功终态必须确认此前各页均已提交；
  本轮结束后拒绝后续数据与重复终态，不重复完成回调。
- 旧通知仍须清理自身工作。通知预留、payload 暂存及实际 worker 资源按 [已接受工作的收尾](action.md#已接受工作的收尾)
  释放；不得释放新任务或另一份仍有效分页请求的预留，不得因拒收 payload 留下永远未处理的终态。

## 结果替换与分页

Provider 维护当前目标查询的身份，以及已提交结果所属的查询身份。两者在等待新结果时可以不同，
必须与查询状态一起记录；Lua 显示通过同一次提交的 core/feature envelope 取得一致信息。
该归属随 source 结果保存在 Rust，List 仍只是 [filter/sort 派生缓存](projection.md)。

- 新一轮首次提交结果时，以本轮已接受结果替换该会话上一轮的结果范围；首次提交可以携带首批数据。
  结果范围、generation 归属与完整性原子切换，不能先把新数据追加到上一轮集合，再另行清除旧项。
- 后续 page 只扩充本轮结果，未完成时报告 partial。非分页 provider 一次提交完整结果；分页 provider
  只有有效成功终态才能报告 complete，不能根据某一页为空判断整轮零命中。
- 整轮成功且零命中时，该会话的结果范围为空；上一轮的 100 项不能留在新一轮的空结果中。
  清空或替换只作用于该会话拥有的查询结果，不删除共享 source 中不属于该范围的数据。
- 结果替换通过 data owner 的显式原子更新表达。Generation 不充当 NodeId，也不要求先删除全部节点再重建；
  保留 identity 的已有节点继续沿用 NodeId。真正 Remove 则失效对应节点和状态，删除后重现不复活旧 ID。
  Provider key 与数据接入方式遵循 [data.md](data.md#provider-key-与-nodeid)，不按名称、路径或位置猜测跨轮身份。
- 更换查询结果范围是 provider 明确声明的替换动作；普通 children 刷新仍不能根据 partial 结果缺项推断删除。
  分页接入必须显式区分首批替换与本轮后续追加，不能仅凭“收到了一个 batch”猜测语义。

当前查询失败时：尚未提交新结果则保留此前结果及原归属；已经提交本轮部分结果则保留这些事实并报告未完成/error。
不能将失败、取消、deadline 或 ResourceLimit 解释为成功零命中，也不回滚已提交的部分结果来恢复旧一轮。
数据批次超过硬容量时整批拒绝，保持最近有效数据和 frame，并处理本轮失败终态；资源改善后的重试创建新 generation。

等待新结果时允许暂留旧 frame。UI 必须能区分当前输入与所显示结果的归属，不能把旧数据的计数或 complete
当作新查询的状态；发布新 frame 时继续校验其查询与投影输入是否适用。Visual 与实际行输入的 identity 校验
仍遵循 [visual.md](visual.md)，不因 query generation 变化就用新行号解释旧输入。

## 与其他协议的边界

- 已有候选上的 Finder 过滤使用 projection 输入失效规则，source 不变时无需发起新的 provider 查询。
  跨文件内容搜索、远程查询等产生新源数据时，才使用本协议验证写入资格；随后 tree 更新使投影缓存失效。
- 普通目录读取在折叠或关闭 view 后可继续提交有效 children；不能将此规则推广为允许旧搜索结果写入当前查询。
- 只改变展示 root 的动作遵循 Treeview 范围契约；改变 provider 搜索范围才替换查询。两者不是同一种 generation。
- 查询替换不持有或释放业务 selection 锁；节点更新造成的任务源项失效仍由既有任务 context 处理。
- 查询分页与 Neovim 局部/追加发布是不同边界；接受分页不表示 Lua 可以跳过既有 frame 原子交换协议。

## 例子与验收

```text
accept a    -> generation 41, start 41
accept ab   -> generation 42, cancel 41, pending 42
accept abc  -> generation 43, replace pending 42 with 43
result 41   -> discard payload, finish own cleanup
capacity    -> start 43
page 43/1   -> replace previous result scope, partial
page 43/2   -> append to generation 43 only
complete 43 -> mark generation 43 complete
```

- 验证连续输入、删除字符、搜索范围/options 变化与显式重试；同 pattern 的旧 generation 不被重新接受。
- 验证只保留最新 pending，取消慢或不受支持时旧结果仍被拒绝，实际并发与通知预留保持有界。
- 验证结果入队时仍有效、排在它前面的新查询先提交后，该结果在最终提交处被拒绝。
- 验证新查询入队失败不改变当前 generation，不自动重放被拒绝请求；标记命令不被查询合并吞掉。
- 验证独立会话、共享会话、会话销毁/重建与结果范围隔离，旧通知不能改另一会话的结果或状态。
- 验证旧成功、失败、进度、取消及重复终态都不覆盖新查询，旧工作仅释放自己的资源。
- 验证上一轮 100 项被新一轮 3 项替换、整轮零命中清空、首批替换和后续追加不混轮；空 page 不提前完成。
- 验证重复/乱序/缺页、失败前无新结果及失败前已有部分结果、硬容量整批拒绝和显式重试。
- 验证保留节点的 identity、真正 Remove 的失效、普通 children partial 不删除缺项，以及旧 frame/Visual 输入。
- 验证查询输入提交、provider 结果提交与 surface 显示是不同完成时点，旧结果的归属与完整性不伪装成新查询。
