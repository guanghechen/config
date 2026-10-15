# Treeview 查询会话

Status: Design，已实现，当前无生产 consumer。本文定义 provider 查询会话、generation、取消、分页与结果替换；
文档入口见 [Treeview](README.md)。节点提交与 identity 遵循 [核心契约](module.md) 及 [data 契约](data.md)，
串行提交与资源预算遵循 [action queue](action.md)。

本协议对应 `data:create_provider(scope)`、`provider:create_query(handler)` 与 `query:start(input)`，Rust 位于 `query.rs`。
当前 Searcher 使用独立的 `yoz.search` Job 和 Lua FileSearch 调度，完成后通过 ResultTree 导入 records，
见[检索设计](../feat/yoz/search.md)；已有候选的 Finder 过滤使用 display 输入，不创建 Query。

## 会话与归属

查询会话属于一个 provider，其结果范围就是该 provider 的写入范围；每个 provider 至多一个会话，
范围互斥规则见 [写入范围](data.md#写入范围)。需要同时保留不同查询的消费者使用不同 provider 与会话，
各自只能替换所属范围；不使用一个全局 generation 作废所有 provider。

- 会话具有生命周期内不混淆的身份；generation 在会话内单调推进，溢出前报错、不回绕。
  会话销毁后重建不能让旧 token 重新有效。Lua 使用 opaque token 原样传递。
- 每次查询固定 pattern 及 options。任一条件变化或显式重试都产生新 generation；
  `a -> ab -> a` 的两次 a 不是同一次查询，不能仅按文本相等接受旧结果。
- 数据页、失败和取消通知均携带会话与 generation 归属，分页另带 sequence。同一轮内部的 worker 由 provider 汇合，
  不通过多个无协调的写入者修改 tree。
- Provider 执行查询与取消，owner 的串行入口验证归属并提交；core 不解释搜索算法、LSP 方法或业务 payload。
  涉及 Neovim/Lua API 的 provider 调用由主线程 handler 执行，worker 不直接调用 Lua/Neovim。

查询 generation 与 data revision、filter/sort 输入、children request epoch、标记 generation 分开使用，
它只决定一次查询是否仍有提交资格，不代替其他版本校验。

### Query 拥有的槽位

会话范围内的 children 槽位（forest 范围为全部节点，`descendants` 为锚点子树，`children` 为锚点）由会话负责：

- 不参与普通 children 读取调度；对它们调用 `data:request_children()` 返回 `InvalidUpdate`，须通过新查询刷新。
  任务的 `prepare_sources(true)` 也不重试这些槽位。
- 有锚点的范围，未完成的页把锚点槽位置为 Partial 且 loading，成功终态置为 Complete，失败记录 error。
- 非 `children` 范围的成功终态把范围内仍未 Complete 的可展开节点标记为 Complete。
- 查询失败时，所需槽位属于该会话的准备中任务按 [准备失败](tasks.md#准备失败与重试) 终止。

## 接受新查询与调度

`query:start(input)` 经 action queue 做短提交：固定输入、推进 generation、替换会话的待执行请求，并使旧 generation
失去提交资格。只有这次提交成功后新查询才生效；入队或校验失败保持原查询，不提前作废仍有效的工作，也不重放被拒绝输入。

- 每个会话尚未启动的请求只保留最新一个；被替换的待执行请求不启动 IO。
- 在途旧查询收到尽力取消（`CancelQuery`）；无法即时取消时，其返回结果仍按过期处理。取消用于减少工作，
  提交校验保证正确性。
- Query 工作与 children 读取共用 `concurrent_reads` 并发名额；名额恢复后启动最新仍有效的待执行请求。
  Native 长任务在有界工作段之间检查取消。
- 新查询生效不调用 ClearSelection，不直接 Remove 节点，也不清空 buffer；旧结果保留原归属，等待新结果替换。
- `query:cancel()` 关闭当前查询的接收资格、移除待执行请求并取消在途工作；会话释放同样关闭接收资格。
  迟到通知只完成旧工作清理。Detach 一个 view 不销毁仍被其他消费者持有的会话。

查询输入替换只合并尚未执行的 provider 工作；selection、expansion 等用户命令仍逐项按序提交。
`query:start()` 的 `Applied` 只表示输入已提交，不表示搜索或显示完成；之后被新查询替换也不修改已完成的 Future。

## 分页与提交校验

分页是拉取式的：owner 以 `Query` effect 请求第 1 页，handler 返回 `{ records, done }` 或完成为该值的 Future；
每页提交后，未完成的查询以下一个 sequence 再次请求，直到 `done`。

结果回到 action queue 后，在发布 data/state/query 补丁的同一提交中校验：

1. DataHandle、会话与 provider 范围仍有效。
2. 通知的 generation 是会话当前接受结果的 generation，本轮未取消或结束。
3. 页属于本轮且 sequence 连续，数据满足 topology、identity、容量与其他前提。
4. 原子提交节点变化与本轮进度/终态，再释放借用并唤醒 views。

入队时可以提前拒绝已知过期内容，但不能省略最终校验；generation 校验不绕过 base revision 或其他 context 检查。

- 过期页不写 tree；过期失败与取消通知不改当前查询的 loading、error 或结果，也不作为当前查询失败报告。
- 重复或乱序页不追加、不推进页序；本轮结束后拒绝后续数据与重复终态。
- 旧通知仍完成自身工作的清理，按 [已接受工作的收尾](action.md#已接受工作的收尾) 释放资格，不影响新查询或其他请求。

## 结果替换与分页

会话同时记录当前目标查询（`generation`、`load_state`、`error`）与已提交结果所属的查询（`result_generation`、`completeness`），
等待新结果时两者可以不同。Lua 通过同一 publication 的 Frame header `queries` 读取各会话的这些字段，
通过 `frame:source():query_result(scope)` 读取已提交结果的会话、generation、pattern 与 completeness；
这份归属随 Source 保留，会话释放后仍可读取。List 仍只是 [filter/sort 派生缓存](projection.md)。

- 第 1 页以本轮结果整体替换会话范围内的上一轮结果，范围、generation 归属与完整性原子切换，
  不先追加再另行清除旧项；第 1 页可以为空。
- 后续页只扩充本轮结果，未完成时报告 partial；只有成功终态才报告 complete，不能根据某一页为空判断整轮零命中。
- 整轮成功且零命中时结果范围为空；替换只作用于会话范围，不删除共享 Source 中范围外的数据。
- 替换通过 owner 的显式原子更新表达，保留 key 的节点沿用 NodeId；真正 Remove 的节点失效，删除后重现不复活旧 ID。
  Key 规则见 [data.md](data.md#provider-key-与-nodeid)。
- 首页替换只属于 Query；普通 children 刷新仍不能根据 partial 结果缺项推断删除。

当前查询失败时：尚未提交新结果则保留此前结果及原归属；已提交本轮部分结果则保留这些事实并报告 error。
失败、取消或 `ResourceLimit` 不解释为成功零命中，也不回滚已提交的部分结果。数据页超过硬容量时整批拒绝，
保持最近有效数据和 Frame 并以失败结束本轮；资源改善后的重试创建新 generation。

等待新结果时允许暂留旧 Frame。UI 必须区分当前输入与所显示结果的归属，不能把旧结果的计数或 complete 当作新查询的状态；
发布新 Frame 时继续校验其 Query 输入是否适用。Visual 与行输入的 identity 校验仍遵循 [visual.md](visual.md)。

## 与其他协议的边界

- 已有候选上的过滤使用 projection 输入失效规则，source 不变时无需新查询；产生新源数据时才使用本协议。
- 普通目录读取在折叠或关闭 view 后可继续提交有效 children；该规则不允许旧查询结果写入当前查询。
- 只改变展示 root 的动作遵循范围契约；改变 provider 搜索范围才替换查询。
- 查询替换不持有或释放 selection 锁；节点更新对任务源项的影响由 [cleanup context](tasks.md#cleanup-context) 判断。
- 查询分页与 Neovim 局部发布是不同边界，接受分页不表示 Lua 可以跳过 Frame 原子交换协议。

## 例子

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
