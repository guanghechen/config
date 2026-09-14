# Treeview filter、sort 与派生缓存

Status: Design。本文定义 Rust Treeview 的展示投影与缓存有效性；核心运行协议见 [module.md](module.md)。

## Ground truth 与所有权

DataHandle 对应的 source tree 是节点数据、identity 和父子关系的唯一 ground truth。
这里的 tree 指 provider 提供的有序 forest，不限定为 filesystem tree，也不等同于 Tree 展示模式。
Selection、expansion 等交互状态仍由 StateHandle 持有。

List 是 source tree 经 filter 与 sort 计算出的派生缓存：

```text
list = project(tree, filter, sort; display_context)
```

- List 保存 NodeId 顺序、匹配位置和必要索引，引用对应版本的 source 数据；不复制一套权威业务数据。
- Filter 或 sort 改变不通过 Remove、Reparent 或 Reorder 修改 source，也不分配新 NodeId。
  Source 的真实变化仍由 data owner 提交节点更新批次。
- Tree 展示同样由 source 与当前展示条件派生。两种模式不需要互相同步另一份节点集合或 parent 关系。
- Rust 负责匹配、排序、缓存和行映射；Lua 不维护另一份 tree/list，不逐节点提供跨 FFI 谓词。

## 输入与缓存有效性

每份缓存及计算产物关联完整的输入身份：DataHandle 与 data revision、filter 输入版本、sort 输入版本，
以及实际使用的 display context。版本属于内部有效性契约，不要求 Lua 每帧接收完整输入或索引。

- Tree 数据、filter 或 sort 任一变化，旧缓存即不再是当前输入的有效结果；输入相同且缓存仍在时复用。
  完全回退到旧条件也必须核对全部输入，不能仅因 pattern 相同就复用其他 data revision 的结果。
- Filter 输入包含 pattern、开关及谓词依赖的数据；sort 输入包含排序方式、参数及排名依据。
  例如 frecency 分数更新即使未改变节点数据，也必须更新 sort 输入版本；不能只比较谓词对象地址。
- Display context 包含当前展示范围与模式，以及参与计算的状态。Selected-only 依赖当前 selection；
  Tree 可见行还依赖 expansion 和压缩设置。Root、相关选择或展开状态改变后不能继续使用旧可见行。
  普通 cursor 移动若不参与筛选或排序，不使结果顺序缓存失效。
- 缓存失效要求重新计算当前结果，不要求丢弃全部可复用的内部索引。实现可以复用经验证仍适用的
  子计算，但不能把旧产物直接标记为新输入的结果；具体优化由测量决定。
- 输入版本变化不必推进 layout revision。重算后只有行映射、导航、source 祖先归并等布局信息
  实际变化才推进该 revision；其他展示变化仍按完整 snapshot 发布规则处理。

## Tree 与 List

Tree 保留 source 层级，在 display roots 内应用 filter、兄弟排序、展开与压缩，再生成 DFS 可见行。
匹配到后代时保留展示路径所需的连接祖先；连接祖先不因此变成直接匹配项。匹配本身不写展开标记，
不越过 display roots 或自动展开已折叠的分支。Hidden 与 selected-only 的优先级仍遵循
[selection 契约](selection.md#selected-only-与-hidden)，连接线与压缩遵循 [indentline](indentline.md)。

List 的候选范围递归覆盖 display roots，不受 Tree 折叠影响；filter 决定结果成员，sort 决定平铺顺序。
递归候选范围不要求输出按 DFS 排列。普通文本匹配不强制加入只用于连接的祖先行；selected-only
要求保留的必要祖先与 pending 范围仍遵循 selection 契约。

- Finder 可以按相关性或 frecency 跨父节点排序；行序不反写 source 的 sibling 顺序。
- Explorer 继续使用其已确认的各层目录优先、名称升序 DFS 规则，保留通过过滤的目录与文件行。
  这是该 consumer 的排序规则，不是所有 List 的固定顺序。
- Sort 必须确定同分项的顺序，使同一份完整输入重复计算得到同一结果；具体比较规则由上层提供。
- List 无视觉缩进、连接线或压缩，不支持 Tree 专用结构导航与折叠动作；切回 Tree 使用保存的展开状态。
- 未加载范围仍报告真实的 partial/loading/error，按现有 children 调度补载。不能仅因当前缓存已算完，
  就把尚未加载的候选范围声明为完整；有效补载提交更新 tree 后使缓存失效。

Filter、sort 和模式切换不改变 selection 标记。递归 action 的输入祖先归并仍使用 source 关系，
不会因平铺、排序或隐藏了部分后代而缩小为屏幕上的几行；自身 action 只去重实际输入 ID，不归并父子目标。

## 异步计算与显示

- 每个 state 的计算与合并遵循 [action 调度](action.md#投影与发布)：最多一个运行中的投影与一个
  最新待处理需求。Worker 读取不可变输入，提交时核对其完整输入身份是否仍适用于当前需求。
- 过期结果不能成为当前有效缓存或发布为当前结果；输入变化只合并派生计算，不丢弃已接受的标记命令。
- 失效不等于立刻清空 buffer。新结果尚未准备好时可以显示旧 frame，但必须保留它原来的输入身份、
  数据版本与行映射，不能将它伪装成新 filter/sort 的结果。
- 新 frame 通过既有 surface 协议交换。输入始终捕获实际显示的 frame，由该 frame 映射 NodeId，
  再校验当前节点与动作前提；缓存失效本身不意味着用户针对旧 frame 的所有输入都失效。
- Visual 持帧、完整 envelope 与关闭后的引用释放继续遵循 [visual.md](visual.md)。
  派生缓存可以淘汰，但不得破坏仍被 view、命令或任务持有的不可变数据。

已有候选上的 Finder 查询只需更新 filter/sort 输入，候选未变化时不重复导入 tree。
跨文件内容搜索则须由 provider 对新 pattern 执行搜索，接收的新源数据通过 owner 更新 tree；
不能靠过滤上次命中来发现此前未返回的匹配。Provider 的查询取消与结果替换遵循 [query 契约](query.md)，
数据接入遵循 [data 契约](data.md)。查询结果的归属与当前目标查询也是发布时需要核对的输入，
不与派生缓存有效性混为一套生命周期。

本契约决定派生结果是否仍有效；失效后的局部依赖重算、共享行序列、一般 diff 及 Neovim 发布方式遵循
[render 契约](render.md)。一个完整目标 snapshot 不要求整表复制或全量发布。

## 例子与验收

Source 中 `src` 的 children 为 `[a.lua, b.lua]`，之后的 `test` 下有 `c.lua`。
Finder 仅保留文件，排名为 `b > c > a` 时，List 应为：

```text
src/b.lua
test/c.lua
src/a.lua
```

切回 Tree 仍是 `src -> [a.lua, b.lua]`、`test -> [c.lua]` 的 source 关系；展示兄弟顺序按该模式的 sort
计算，不因此前平铺时两个 src 文件被分开而产生 Reparent。

- 验证输入不变时重复读取复用缓存；tree、filter、sort 各自改变均使旧缓存失效。
- 验证 `a -> ab -> a`：扩大候选范围时从当前 source 重算，不仅过滤上一次较窄的结果；
  期间 tree 发生更新时，不复用先前 pattern 为 a 的过期列表。
- 验证上述跨目录排名、同分项确定性、仅 sort 分数更新，以及 Explorer 既定 DFS 顺序。
- 验证普通文本匹配中父节点不匹配但后代匹配时，Tree 保留必要祖先，List 不强制加入连接祖先；
  不擅自展开，也不改变 selected-only 已确认的祖先与 pending 保留规则。
- 验证 root、selected-only、相关 selection 和 Tree expansion 变化，不复用其他 context 的可见行。
- 验证补载后的数据更新使结果失效，partial/error 不被缓存完成状态覆盖。
- 验证旧计算晚到、旧 frame 输入、Visual 期间 filter/sort 更新及退出后交换最新适用结果。
- 验证过滤、排序、切换模式不改 NodeId、source parent 与选择标记；淘汰缓存后仍可从权威输入重建。
