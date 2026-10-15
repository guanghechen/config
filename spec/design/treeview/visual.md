# Treeview Visual 圈选

Status: Design。适用于 Treeview 的 Lua View 与 surface；文档入口见 [Treeview](README.md)。

Visual 是尚未提交的行范围。正在进行的圈选保持稳定，后台变化在用户完成圈选后再重排列表。
标记提交仍遵循 [selection 契约](selection.md)，Visual 本身不持有另一份权威 selection。
字符、整行和块模式（`v`、`V`、`CTRL-V`）均按两个端点之间的完整行确定节点目标；列只用于恢复端点位置。
Lua [View](../../../lua/ux/treeview/view.lua) 捕获输入与 gesture，
[surface](../../../lua/ux/treeview/surface.lua) 负责正文、Frame 与端点的一致发布。

## Frame 与 View

- 进入 Visual 时，当前 View 持有实际显示的不可变 Frame，固定本次圈选的布局。Lua 保存 Visual
  mode、anchor 和 cursor 的行/byte column、块模式的虚拟列偏移，以及本次 gesture 身份；范围随用户移动端点而变化。
- `layout_revision` 表示圈选布局：display root、Tree/List 模式、有序行与代表 NodeId、folded chain、
  导航索引和范围归并所需的 source 祖先关系。布局变化时推进该 revision；纯展示数据变化不推进。
  `frame_id` 标识完整展示快照，两个 Frame 可以有相同 layout revision 和不同 metadata。
- 同一 Frame 必须能按自己的 source 祖先关系归并行范围，不能借用已变化的 live topology 解释旧范围。
  Source 关系保存在不可变索引中，Lua 不重新遍历树。
- Visual 期间，当前 View 暂缓交换会改变上述布局的 Frame。后台加载、Filetree 数据、Rust state、
  业务任务与其他 View 继续更新；Visual 不取得 selection 任务锁。
- 每个独立 View 使用专用的正文 buffer，Rust snapshot 可以共享。多个独立 View 不能写同一个
  buffer，否则无法只为正在圈选的 View 暂缓帧交换。待显示 target 的保留规则见 [render](render.md#lua-发布)。

## 不改变布局的更新

- 图标、诊断、Git 状态等更新在 layout revision 不变时可以显示。仍整体发布新 Frame 及其 feature commit
  （consumer `prepare_frame` 的结果），不把新 snapshot 的几列拼到旧 Frame 上。
- 正文发布前保存两个端点与 Visual mode，应用局部 splice 或 Reset 后在同一次不 yield 的 surface 提交中恢复。
  保持 anchor/cursor 的方向，byte column 按新行的合法位置钳位；不能只恢复 cursor。
- 纯装饰变化以 Swap 交换 Frame 与装饰输入后请求可见范围 redraw，不必改写正文或构造全表 extmarks。
  无正文变化但 layout revision 改变的 target 仍须暂缓；发布流程见 [render 契约](render.md#lua-发布)。
- 这些程序写入产生的 CursorMoved/ModeChanged 不作为用户导航或退出 Visual，不能提前释放圈选 Frame。
- 新 Frame 必须经 owner 验证仍适用；旧 metadata 结果不能覆盖更新的状态。若不能取得与圈选布局
  一致的 Frame 及其 feature commit，则继续显示当前 Frame，将最新 snapshot 留待圈选结束。
- 更新展示快照后仍保持本次布局与两个端点，后续输入捕获实际显示的 Frame 及其中的标记状态。
  Gesture 随之持有新的展示 Frame；旧 Frame 在没有在途命令引用后释放，不额外保留一份入场快照。

## 移动与共享 state

- `j`/`k`、首尾行、翻页及 Tree 的 `[i`/`]i` 均在实际显示的圈选布局上移动。
  结构导航使用该 Frame 和当前 cursor 端点，不能使用后台最新布局或另一个 View 的逻辑 cursor。
- 共享 state 的 root、展开、cursor 等更新可以产生待显示 snapshot，但不拉动本 View 的 Visual 两端。
  用户在此 View 的移动仍可按现有前提同步有效的逻辑 cursor；失效或在当前 state 中不可定位的节点，
  只保留临时 surface 位置，不把失效 NodeId 写回 state。
- 用户正常退出 Visual，或明确执行会结束 Visual 的命令后，显示最新可用 snapshot。
  单次 `<Esc>` 保留原有行为；退出圈选不执行 ClearSelection，也不切换 selection purpose。
- Core View 在未设 `keymaps = false` 时为 Normal/Visual 绑定 buffer-local `<Esc><Esc>`：退出圈选并提交
  ClearSelection，清空该 state 的全部标记及 selection purpose，包括当前不可见的选择；共享 state 的其他 View 同步更新。
  使用现有 `timeoutlen` 识别连续按键，不修改全局映射或 timeout。持有任务锁时按原契约拒绝清空并报告原因，
  不取消任务。ResultTree 的 View 一律 `keymaps = false`，由 consumer 自行定义是否提供该键位。

## 提交圈选

1. 上层 Visual handler 在任何 mode 切换或待显示 Frame 交换之前，固定实际 Frame、行范围和明确的
   action 及其 recursive 值。Rust 将行映射为原 NodeIds：自身 action 只去重，递归 action 按该 Frame 的 source
   关系归并为最外层目标。recursive 值由 consumer 映射显式给出：core `<Tab>` 使用 `selection_recursive`，
   Explorer 的映射见 [Explorer 行输入与 Visual](../feat/explorer.md#行输入与-visual)。
2. Owner 在同一事务中校验当前节点与动作前提，再提交 selection/mode。校验针对真实前提：
   - 按 action scope 解析后的目标必须属于原 DataHandle 且仍存活；目标失效返回 MissingNode，不替换为同名或同位置节点。
   - 递归 action 的原范围中仍存活输入按当前 source 关系归并后，必须得到相同目标集合；关系变化导致集合
     改变时返回 Stale。被祖先覆盖的冗余输入节点消失，本身不使仍有效的祖先目标失效。
   - 自身 action 保留每个去重后的输入 ID；即使父子同时在范围内也不能丢弃子节点。Reparent 本身不改变
     这份目标集合，但各目标的身份与实际动作前提仍须有效。
   - 两种 toggle 对目标的当前 `marked` 判断必须与捕获 Frame 中显示的判断一致；不一致时返回 Stale，
     不能改用另一个 marked 或 scope 重放。Select 保持显式并集意图；用途切换由 consumer 动作显式提交。
   - 当前业务锁及该动作实际依赖的其他前提继续校验；Visual 不能绕过任务锁。
3. Frame/layout/data/selection revision 变大本身不构成拒绝理由。纯排序、在范围前后或中间插入
   其他节点、修改 metadata，以及未改变上述前提的范围外变化，不使本次圈选失效。
4. Dispatch 的 Future 完成后结束 Visual；入队本身不代表标记已提交。
   随后显示覆盖本次提交或更新状态的 snapshot，光标按 [cursor 回退](render.md#cursor-回退) 恢复，不恢复旧 selection。

冻结的是行输入对象及动作 scope。递归 action 覆盖其整棵子树，包括新出现或未加载的后代，
不会变成 filesystem 内容快照；自身 action 只修改所指定节点自身，不因画面上有 children 而扩展范围。

## 退出、失败与生命周期

- 正常退出但未提交时，丢弃待提交范围并交换最新 snapshot。不会把尚未提交的圈选写入逻辑 selection。
- 提交被 MissingNode/Stale/Busy 等拒绝时，不提交部分标记；结束本次 Visual，显示最新可用 snapshot
  并指出失效对象或实际阻塞原因，由用户调整后重新触发。数据事实及既有逻辑 selection 不回滚。
- ModeChanged 不能抢在 Visual handler 捕获范围之前释放 Frame。已捕获的命令保持 Visual 动作种类，
  不因 Neovim 已进入 Normal 就退化为光标单点操作；提交期间由命令持有 Frame 直到处理结束。
- 提交后，owner 确认待显示 snapshot 已包含本次结果再发布。尚未就绪时暂留当前画面，不能先显示
  标记提交之前的待显示 snapshot，再用旧 selection/mode 覆盖刚完成的动作。
- View/gesture 的迟到回调不得结束新一轮 Visual 或移动其端点。Detach 释放 View 的 Frame 引用；
  已提交命令按既有 state 生命周期完成，其回调不得写入已关闭或重新绑定的 buffer/window。
- 可复用的 View 可以 `suspend()` / `resume(winnr)`：suspend 先退出 Visual，保留专用 buffer 和已发布 Frame，
  释放原窗口的 buffer/options binding、停止活动 View polling，并递增 epoch 使在途 prepare/gesture callback 失效。
  Buffer 在隐藏时仍由该 View 独占；resume 要求 buffer 仍有效，changedtick 与已发布记录不一致时按失步完整 Reset，
  恢复窗口配置与 viewport 后以保留的 Frame 为 base 发布最新状态。
  `detach()` 始终彻底释放资源；直接关闭活动窗口仍触发 detach。
- Surface API 部分写入失败时不能继续用旧 Frame 解释已变化的正文；隔离行输入并按 [失败恢复](render.md#失败恢复)
  完整 resync。恢复不自动提交 Visual 选择或重放业务动作，必要时终止本次 gesture 并报告显示错误。

## 例子

用户圈选同层的 leaf 节点 B、C，后台在它们之间插入同层的 leaf 节点 X：

```text
圈选期间仍显示：B, C
后台最新列表：  B, X, C
```

执行选择动作时提交 B、C 的 NodeIds；完成后显示 B、X、C，只有 B、C 因本次动作被标记。
若 B 在提交前已删除，则该次提交返回 MissingNode，刷新后提示 B 已失效，不把 X 当成 B。
