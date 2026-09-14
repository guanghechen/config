# Rust Treeview Visual 圈选

Status: Design。适用于 Rust Treeview 的 Lua surface；文档入口见 [Treeview](README.md)。

Visual 是尚未提交的行范围。正在进行的圈选保持稳定，后台变化在用户完成圈选后再重排列表。
标记提交仍遵循 [selection 契约](selection.md)，Visual 本身不持有另一份权威 selection。

## Frame 与 view

- 进入 Visual 时，当前 view 持有实际显示的不可变 frame，固定本次圈选的布局。Lua 保存 Visual
  mode、anchor 和 cursor 的行/byte column，以及本次 gesture 身份；范围随用户移动端点而变化。
- `layout_revision` 表示圈选布局：display root、Tree/List 模式、有序行与代表 NodeId、folded chain、
  导航索引和范围归并所需的 source 祖先关系。布局变化时推进该 revision；纯展示数据变化不推进。
  `frame_id` 标识完整展示快照，两个 frame 可以有相同 layout revision 和不同 metadata。
- 同一 frame 必须能按自己的 source 祖先关系归并行范围，不能借用已变化的 live topology 解释旧范围。
  Source 关系保存在不可变索引中，Lua 不重新遍历树。
- Visual 期间，当前 view 暂缓交换会改变上述布局的 frame。后台加载、Filetree 数据、Rust state、
  业务任务与其他 views 继续更新；Visual 不取得 selection 任务锁。
- 每个独立 view 使用专用的正文 buffer，Rust snapshot 可以共享。多个独立 view 不能写同一个
  buffer，否则无法只为正在圈选的 view 暂缓帧交换。
- 每个 view 只保留当前显示的 frame 和一个最新待显示 snapshot 引用。后来的更新替换待显示项，
  不积压重绘队列，也不提前为每个待显示 snapshot 构建 Lua 行数组。

## 不改变布局的更新

- 图标、诊断、Git 状态等更新在 layout revision 不变时可以显示。仍发布同一 commit revision 下的
  完整 core/feature envelope，不把新 snapshot 的几列拼到旧 frame 上。
- 正文发布前保存两个端点与 Visual mode，应用局部 splice 或 Reset 后在同一次不 yield 的 surface 提交中恢复。
  保持 anchor/cursor 的方向，byte column 按新行的合法位置钳位；不能只恢复 cursor。
- 纯装饰变化交换完整 envelope 与装饰输入后请求可见范围 redraw，不必改写正文或构造全表 extmarks。
  无正文变化但 layout revision 改变的 target 仍须暂缓；具体流程见 [render 契约](render.md#cursorvisual-与多-view)。
- 这些程序写入产生的 CursorMoved/ModeChanged 不作为用户导航或退出 Visual，不能提前释放圈选 frame。
- 新 frame 必须经 owner 验证仍适用；旧 metadata 结果不能覆盖更新的状态。若不能取得与圈选布局
  一致的完整 envelope，则继续显示当前 frame，将最新 snapshot 留待圈选结束。
- 更新展示快照后仍保持本次布局与两个端点，后续输入捕获实际显示的 frame 及其中的标记状态。
  Gesture 随之持有新的展示 frame；旧 frame 在没有在途命令引用后释放，不额外保留一份入场快照。

## 移动与共享 state

- `j`/`k`、首尾行、翻页及 Tree 的 `[i`/`]i` 均在实际显示的圈选布局上移动。
  结构导航使用该 frame 和当前 cursor 端点，不能使用后台最新布局或另一个 view 的逻辑 cursor。
- 共享 state 的 root、展开、cursor 等更新可以产生待显示 snapshot，但不拉动本 view 的 Visual 两端。
  用户在此 view 的移动仍可按现有前提同步有效的逻辑 cursor；失效或在当前 state 中不可定位的节点，
  只保留临时 surface 位置，不把失效 NodeId 写回 state。
- 用户正常退出 Visual，或明确执行会结束 Visual 的命令后，显示最新可用 snapshot。
  不为 `<Esc>` 新增映射；退出圈选不执行 ClearSelection，也不切换 select/copy/cut 用途。

## 提交圈选

1. 上层 Visual handler 在任何 mode 切换或待显示 frame 交换之前，固定实际 frame、行范围和明确的
   action 及其 recursive 值。Rust 将行映射为原 NodeIds：自身 action 只去重，递归 action 按该 frame 的 source
   关系归并为最外层目标。Explorer 既有 `<Tab>`、`c`、`x` 映射继续使用 recursive=true。
2. Owner 在同一事务中校验当前节点与动作前提，再提交 selection/mode。校验针对真实前提：
   - 按 action scope 解析后的目标必须属于原 DataHandle 且仍存活；目标失效返回 MissingNode，不替换为同名或同位置节点。
   - 递归 action 的原范围中仍存活输入按当前 source 关系归并后，必须得到相同目标集合；关系变化导致集合
     改变时返回 Stale。被祖先覆盖的冗余输入节点消失，本身不使仍有效的祖先目标失效。
   - 自身 action 保留每个去重后的输入 ID；即使父子同时在范围内也不能丢弃子节点。Reparent 本身不改变
     这份目标集合，但各目标的身份与实际动作前提仍须有效。
   - 两种 toggle 对目标的当前 `marked` 判断必须与捕获 frame 中显示的判断一致；不一致时返回 Stale，
     不能改用另一个 marked 或 scope 重放。Select 保持显式并集意图，Explorer Visual `c`/`x` 仍显式设置对应用途。
   - 当前业务锁及该动作实际依赖的其他前提继续校验；Visual 不能绕过任务锁。
3. Frame/layout/data/selection revision 变大本身不构成拒绝理由。纯排序、在范围前后或中间插入
   其他节点、修改 metadata，以及未改变上述前提的范围外变化，不使本次圈选失效。
4. Dispatch 的 Future 完成为 Applied/NoChange 后结束 Visual；入队本身不代表标记已提交。
   随后显示覆盖本次提交或更新状态的 snapshot，以原 cursor NodeId 按正常规则恢复位置。
   不可见时回退到可见祖先或附近行，不恢复旧 selection。

冻结的是行输入对象及动作 scope。递归 action 覆盖其整棵子树，包括新出现或未加载的后代，
不会变成 filesystem 内容快照；自身 action 只修改所指定节点自身，不因画面上有 children 而扩展范围。

## 退出、失败与生命周期

- 正常退出但未提交时，丢弃待提交范围并交换最新 snapshot。不会把尚未提交的圈选写入逻辑 selection。
- 提交被 MissingNode/Stale/Busy 等拒绝时，不提交部分标记；结束本次 Visual，显示最新可用 snapshot
  并指出失效对象或实际阻塞原因，由用户调整后重新触发。数据事实及既有逻辑 selection 不回滚。
- ModeChanged 不能抢在 Visual handler 捕获范围之前释放 frame。已捕获的命令保持 Visual 动作种类，
  不因 Neovim 已进入 Normal 就退化为光标单点操作；提交期间由命令持有 frame 直到处理结束。
- 提交后，owner 确认待显示 snapshot 已包含本次结果再发布。尚未就绪时暂留当前画面，不能先显示
  标记提交之前的待显示 snapshot，再用旧 selection/mode 覆盖刚完成的动作。
- View/gesture 的迟到回调不得结束新一轮 Visual 或移动其端点。Detach 释放 view 的 frame 引用；
  已提交命令按既有 state 生命周期完成，其回调不得写入已关闭或重新绑定的 buffer/window。
- Surface API 部分写入失败时不能继续用旧 frame 解释已变化的正文；隔离行输入并按 [发布恢复](render.md#surface-提交与失败恢复)
  完整 resync。恢复不自动提交 Visual 选择或重放业务动作，必要时终止本次 gesture 并报告显示错误。

## 例子

用户圈选同层的 leaf 节点 B、C，后台在它们之间插入同层的 leaf 节点 X：

```text
圈选期间仍显示：B, C
后台最新列表：  B, X, C
```

按 `c` 时提交 B、C 的 NodeIds；完成后显示 B、X、C，只有 B、C 因本次动作被标记。
若 B 在提交前已删除，则该次提交返回 MissingNode，刷新后提示 B 已失效，不把 X 当成 B。

## 验证要求

- 覆盖范围前、中、后的插入、排序/过滤/压缩变化、持续递归加载，以及退出后只显示最新 snapshot。
- 在实际 Neovim 中验证 Visual/Visual-line、正反向圈选、UTF-8 文本变化和两个端点恢复。
- 验证目标删除、同名重建、目标间祖先关系变化、被祖先覆盖的冗余节点删除，以及 Toggle 判断变化。
- 验证自身 action 范围中的父子节点均被提交，reparent 不触发祖先归并，以及入队后上层输入映射变化不改原 recursive。
- 验证共享 view 的 cursor/root 更新不打断圈选、元数据完整 envelope 发布，以及提交后不发布旧 snapshot。
- 在独立 Neovim buffers 中验证同一 state 的另一 view 可以刷新，当前 Visual 的范围与画面保持稳定。
- 覆盖用户退出、命令引发的 mode 切换、程序重绘、关闭 view、旧 gesture 回调与新一轮 Visual。
