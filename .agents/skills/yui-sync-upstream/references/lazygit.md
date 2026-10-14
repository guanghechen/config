# lazygit

## 镜像取材

- 仓库：[guanghechen/mirror](https://github.com/guanghechen/mirror.git)。
- 预期 ref：`refs/heads/nvim@lazygit`；2026-10-14 远端查询未找到，尚待建立或确认映射。
- 分支可用前仅保留本地来源盘点。以下同步步骤以确认镜像分支为前提，不从原始项目补取材料。

## 来源与本地范围

- 原始项目（仅归属说明）：`jesseduffield/lazygit`，算法入口 `pkg/gui/presentation/graph/`。
- 本地：[lua/era/m/diffview/commit_graph.lua](../../../../lua/era/m/diffview/commit_graph.lua)。
- 来源证据：本地声明从 lazygit 的 pipe-set model 移植；旧来源注释指向原项目可变的 `master`，没有固定历史 commit。
- 关系：Go → Lua 的纯拓扑渲染算法移植。本地 Diffview 集成以 [设计说明](../../../../spec/design/feat/diffview/main.md) 为准。

## 如何更新

1. 固定上游目标 SHA，先建立 pipe、lane、parent 与 cell 的对应关系；首次核对不推断历史导入 SHA。
2. 对相关 upstream graph 修复构造相同 commit DAG，比较拓扑连接与列占用，再按本地 `IPipe/ICell/INode` 结构移植算法。
3. 保留本地根节点/缺失父节点处理、merge/connection 表达，以及消费者要求的稳定输出；Git 数据获取、TUI 配色和快捷键属于其他模块。
4. 比较跨语言实现时使用 DAG 与结构输出，不要求 Go/Lua 源码逐行相同；采纳代码时核对许可并记录来源。

## 验证

```sh
nvim -l __test__/run.lua __test__/specs/era/m/diffview/commit_graph_spec.lua
```

重点覆盖线性历史、分叉、merge、多父节点、断开的历史与长 lane。变更复杂度时再使用大 DAG 验证，而非同步整个 lazygit runtime。

## 最近检查（2026-10-14）

- 本次远端 refs 查询仍未找到 `refs/heads/nvim@lazygit`；没有可固定的同步目标。
- 已保留本地来源盘点；未进行代码移植或推进已同步 revision。镜像分支可用后再执行上述核对与验证。
