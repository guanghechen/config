# Native Job discovery

Status: Design。定义 native Job 的资源准入与并发浏览资格；入口见 [Treeview](README.md)。

Native provider 可以自行遍历资源，不要求先将整棵操作子树装入 Source。
原任务根仍由 PrepareSources 固定；需要更新或清理未知成功项时，provider 按执行时身份
做最小节点准入，普通 Lua 不获得这个入口。资源签名和 filesystem 路径仍由 provider 校验。

## 独立提交来源

`JobDiscovery { state, job, lock, cleanup, parent, root }` 绑定精确 native Job、
selection lock、原 cleanup context、prepared root 与直接父节点。批次只可包含该父节点的 Insert。
Owner 检查 context 有效、native Job 匹配、父节点属于原根或已准入成员，且原/current slot
都允许首次发现。已 Complete 的父 slot、新旧 read 中曾受限的资格不能因当前 Partial 而放宽。

Source 插入、指定任务的 members 与 provider 自己的资源 index 在同一候选事务发布。
其他任务沿用相关 topology 失效规则，不因父节点相同而获得同一任务的资格。
错误或预算不足不发布半份成员关系；外部失效与已 Remove 的 occurrence 不恢复。

Discovery 按普通 Source mutation 推进父 epoch，使旧 read page 失效；有真实 demand 时才重启。
不得借用 `request = Some(parent)`：那会抑制 epoch 推进，但新节点不在旧 ReadWork.received，
旧扫描完成时可能把它 Remove。Discovery 不修改 received、page sequence 或 task.needed。

## 并发浏览的资格

ReadWork 创建时固定起始 completeness，真实 ReadToken 是授权边界。
Ready 已捕获为 Complete 的槽位可在 native Job claim 前绑定封闭 read grant；普通任务同样只接受
该读取的完整性变化，不能借此准入新成员。未知/部分槽位的发现资格仍要求 native Job 归属。
有效 native prepared Task 可为其原根或已准入后代绑定 read grant；Job 中途 claim
已经开始的 read 也使用原起始值。绑定不创造读取需求，已失效任务不阻止正常 browse 数据发布。
Claim 绑定当时仍有效的 reads；新 read 在首个 page 前绑定资格。从 Complete 开始的 read，
以及 native Task 期间完成的完整 read，都将对应 slot 记为 closed，直到该 task 结束。
closed 与单个 read grant 的 epoch/lifetime 分离，finish、cancel 与 restart 不重新放宽。
Native worker 可在一次 publication read lock 内取得同版 Source、task 身份/有效性和 closed 集合；
该 crate-private 观察不创建 read、grant 或 Source 节点，也不为普通 Lua 开放准入能力。
closed 和成员资格使用同一 data retained 计费；只读 snapshot 持有资格时继续持有其计费，
最后引用释放才回收。自动 read 准入同样遵循 [调度预算与恢复](action.md#硬容量不足)。

Unknown/Partial slot 的可信 Insert 可登记 task members；从 Complete 开始的 refresh，
即使后续 Source 已显示 Partial，仍不得准入新名字。替换、Remove、跨范围移动继续使 context Stale。
Restart 保持或收紧原资格；旧 epoch 取消/完成不能移除新 epoch 的 grant。

## 结果清理

Provider 可以分批准入已确认的成功 frontier，但只能在整个 frontier 与原 context 校验成功后，
调用一次原子 Unselect。任一批失败时不提交 cleanup stamp；此前发布的资源 facts 继续有效。
完整成功子树使用成功根；partial 只清成功文件/完整成功子树，保留失败、未遍历旁支和严格祖先自身。
已由本任务 Remove 的节点不复活，终止后精确解锁；迟到 callback 不能清理或解锁新任务。

通用协议不规定 provider 的私有遍历顺序、IO 原子性或容量。
Filetree 的执行时签名、staging、结果身份与预算由其自己的设计规定。
