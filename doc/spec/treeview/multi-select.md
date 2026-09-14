# Explorer 多选接入 Treeview

Status: Draft。本文说明 Explorer 的选区用途、按键、callback 与任务接入；上层业务细节仍由
[Explorer](../explorer/module.md) 细化。Treeview 的已确认规则以对应 Design 专题为准。

已确认的选取范围、集合、判空与消费边界以
[Rust Treeview selection](selection.md) 为准。
版本编码、继承、自身覆盖及 reparent 使用 [共用标记算法](stamps.md)。
Visual 的 frame 保留与提交条件遵循 [Visual 圈选契约](visual.md)。

## 职责

- Rust Treeview 持有 selection、版本标记和选区锁，依据 opaque NodeId 与 parent/children 计算状态。
- 上层提供数据与 callback，负责 mode、rename/move 和资源身份；文件操作经 Rust provider 执行，再提交节点和选区更新。
- Lua 负责输入、Visual 范围与展示，不维护第二份权威选区。Treeview 不绑定 filepath。
- 共享 data 不强制共享 selection；共享 selection 时，mode、generation 和任务锁也必须共享。

## 选取语义

选取范围、两类集合、Add/Toggle 判据、判空与 UI 边界以 [selection 契约](selection.md) 为准。
本文递归业务源项 `S = subtree_roots`；`self_only_nodes` 仅表示剩余的自身选择，不能与 S 合并后
归并为递归操作根。完整源项通过 [源项准备](selection.md#源项准备) 取得，执行动作不自动加入光标项。

## Explorer 标记交互

本节 Add/Toggle 映射到 `select_node` / `toggle_node`，反选使用 `deselect_node`，均显式传 `recursive=true`。
其他上层输入映射可以选择 `recursive=false`；core 不根据 consumer 自动切换范围。

一个选区只有一种 mode：`select`、`copy` 或 `cut`；copy/cut 隐含选择能力，标记本身不执行文件 IO。
无选区时不处于 multiselection；显式选择一项也进入该状态。此 mode 与 Neovim Normal/Visual 分开。
任何选择事务最终确定两组均为空时，退出 multiselection 并清除 mode；仅递归源项为空时保留 mode。
反选只取消目标子树；取消最后一个已选子项后，祖先自身仍可能在 `self_only_nodes` 中，此时继续保留 mode。
表中的“已选中”按 `marked` 判断，包含 `self_only_nodes` 中的节点。

| 按键    | 光标项未选中          | 光标项已选中                            |
| ------- | --------------------- | --------------------------------------- |
| `<Tab>` | 加入，保留 mode       | 反选，保留 mode                         |
| `c`     | 加入，整个选区切 copy | 已是 copy 则反选；否则保留选区并切 copy |
| `x`     | 加入，整个选区切 cut  | 已是 cut 则反选；否则保留选区并切 cut   |

- 无选区时，首次 `<Tab>` 进入 select，`c` 进入 copy，`x` 进入 cut。
- Normal c/x 在已选项上仅切换 mode 时，只提交 feature 变化，不调用 Add 或刷新 selection stamp。
- Tree 的 Visual `[i`／`]i` 只移动 cursor 和范围，显式按 `<Tab>`、`c`、`x` 才修改 selection；List 不支持这两个导航键。
- Visual 从进入时固定本 view 的布局；提交 handler 在切换 mode 或刷新前捕获实际 frame 和行范围，
  按该 frame 的 source 关系去重、归并最外层节点。后台布局变化不改变这次行输入。
- Visual `c`／`x` 对这些根执行显式 Add 并统一 mode；已 full 的根也刷新 stamp，整批共用一个新 generation。
  `<Tab>` 对每个根 toggle 一次，保留 mode。
- 范围操作按提交前状态决定结果，一次提交 selection 与 mode；中途暂时为空不提前退出。
- 归并后的目标仍须存活，当前祖先归并结果须相同；Toggle 的 marked 判断须与捕获 frame 一致。
  纯插入其他行、重排或无关 revision 推进不拒绝提交；真正失效时整次拒绝，刷新并提示用户调整。
- 清空选取与取消任务是两个独立 action menu 入口，暂不设默认键；不新增或覆盖 `<Esc>`。
- 清空选取保留 root 和展开，不主动移光标；原节点被选区过滤隐藏时按光标恢复规则定位。

## Explorer 通过 callback 消费选区

- `p` 仅在 copy/cut 生效，分别复制/移动 `S`；`d` 删除 `S`。选中的目录按整棵子树操作，不重复提交后代。
- `S` 确定为空但仍有 `self_only_nodes` 时，不执行递归文件 IO，保留 selection/mode，不回退到光标项。
  Container 自身的其他业务用途由 Explorer 定义；不能将两组 ID 合并后再按祖先归并成目录操作源。
- `p` 的目标为光标目录，光标为文件时用其父目录；默认空树用 workspace root。源项与目标分别确定。
- Rename 支持文件和目录、仅修改同一 parent 内的名称；无选区用光标项，单个源项用选中项，多源项禁用。
- 批量打开跳过 `S` 中的目录，不递归打开后代；通过窗口选择/新建策略确定一个目标 pane，加载所选文件，
  显示最后一个成功项并聚焦该 pane，不隐式替换 Explorer window。
- 打开成功、部分失败或取消 window picker 均保留 selection 和 mode。
- 路径复制、Quickfix、Add to AI 消费最外层源项，不递归展开目录；Add to AI 只添加位置，不发送消息。

## 执行与生命周期

- 提交业务动作时固定 selection revision、mode 和目标，取得选区锁并准备完整源项；Ready 时固定 cleanup context，校验后执行。
- 准备、执行、等待确认、正在取消期间禁止改选、清空、切 mode、重复提交或启动新的文件修改动作；
  浏览、折叠、显示切换、查看进度和关闭 pane 仍可使用。
- 锁覆盖全部共享 views；持锁 owner 可以提交结果，旧 callback 不能释放后续任务的锁。
- 普通 children 加载/刷新不取得选区锁，按最新 selection 展示；加载 callback 不直接解除业务锁。
  若失败读取是源项准备的必要依赖，由任务 owner 按 [准备失败与重试](selection.md#准备失败与重试)
  终止任务并解锁，保留有效数据和选区；显式重试创建新任务。
- Copy/move 冲突逐项询问是否 override；拒绝则 skipped，继续后续项。执行及等待确认期间展示对应进度状态。
- `p`／`d` 在 cleanup context 有效时移除 success 项，failed/skipped/取消后未完成项保留原 mode；
  任务终止后按清理后的两组重新判空，只有 selection 确定为空才退出 multiselection。
- 成功清理与交互反选均只取消目标子树，不额外取消祖先自身；源项全部成功后仍有 self-only 选择时保留 mode。
- 相关外部 topology 已变化时，整批选区清理返回 Stale，不写成功项取消标记；保留逐项 IO 结果和当前选区，
  提示重新选择。终止任务仍释放自己的锁，不重放 IO；完整规则见
  [业务结果清理](selection.md#业务结果清理)。
- 取消任务在当前项结束或安全中止点生效；确认停止前保持“正在取消”和锁，不回滚已完成部分。
- 关闭 pane 不清空选区、不取消任务；重新连接同一 Rust state 可继续查看选择和进度。
- 退出 Neovim 有未完成任务时默认“等待”：取消本次退出，任务完成后不自动退出；选择“退出”则请求取消，
  等待 Rust 安全停止后继续正常退出。

## 上层业务边界

Treeview 的 Empty/Nonempty/Pending 通知不自行清空 stamp 或切换业务 mode；用途与显式成功项清理由上层提交。
Explorer 在非任务阶段对确定两组均为空的 selection 退出 mode；仅递归源项为空时不退出。
若后续结构变化自然产生选区且没有用途，则进入 select，不自动恢复 copy/cut。
任务期间保留既定用途，终止后按成功/失败结果处理，不把准备或执行中的暂时空集合当作全部成功。

以下仍由 Explorer/provider 设计，不进入 Treeview 标记算法：目录内部分成功、覆盖/合并、文件执行失败后的重试、删除确认/trash、
无选区 fallback、直接 copy/move-to-path、隐藏 pane 的确认路由，以及退出超时与未保存 buffer 检查。
