# Treeview 设计

## 概览

Rust core 位于 `rust/yoz/src/ux/treeview/`，Lua 入口为 `yoz.ux.treeview` 和 `require("ux.treeview")`。
Data 持有 source topology；State 持有 selection、expansion、display root 与逻辑 cursor；Frame 提供不可变行映射。
Lua 负责输入、窗口、buffer、业务 metadata 和 viewport decorations，不维护第二套交互树。

| Consumer                                                   | 数据路径                                                                                                 |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Explorer                                                   | native Filetree Data；native Explorer policy 解释浏览、用途与 Job                                        |
| Find Explorer、目录 preview                                | 共享 Filetree Data，各自使用单层 List State                                                              |
| 文件 Picker、Searcher、diagnostics、LSP symbols/references | Lua producer 准备业务 records，经 ResultTree 导入 native Data                                            |
| 普通 List、AI 多选 picker                                  | ResultTree；多选标记与确认结果使用同一 native selection                                                  |
| Diffview                                                   | Git 结果经 `pane/tree.lua` 准备 records，交由 ResultTree 发布                                            |
| Git Files                                                  | Staged / Unstaged 两棵 `era.view.GitFiles`（ResultFiles）树，业务见 [Git Files](../../feat/git-files.md) |

结果集不因展示层级而扫描真实目录。Explorer、Find Explorer、文件 Picker 的文件修改及 Diffview 的 untracked discard
统一使用 Filetree Jobs；Git tracked 文件的 discard 由 Git 领域处理。

## 文档导航

| 文档                                | 职责                                                               |
| ----------------------------------- | ------------------------------------------------------------------ |
| [integration.md](integration.md)    | 接入步骤与最小示例                                                 |
| [module.md](module.md)              | 句柄、术语、命令、revision、effect 交付与 Lua API 索引             |
| [data.md](data.md)                  | Provider key、写入范围、快照/增量/分块导入与所有权                 |
| [action.md](action.md)              | 串行提交、Future、投影批次、读取调度、背压与默认容量               |
| [projection.md](projection.md)      | Display roots、Tree/List、DisplayOptions、filter/sort、文本与缓存  |
| [render.md](render.md)              | 局部更新、RenderPlan、Lua 发布与节奏、失败恢复与 cursor 回退       |
| [performance.md](performance.md)    | 成本边界、测量口径与验收目标                                       |
| [query.md](query.md)                | Query 会话、generation、取消与分页                                 |
| [stamps.md](stamps.md)              | Selection/expansion 共用标记算法                                   |
| [selection.md](selection.md)        | 选择状态、交互、聚合与判空                                         |
| [tasks.md](tasks.md)                | 选区锁、源项准备、cleanup context、授权更新与 native Job discovery |
| [expansion.md](expansion.md)        | 展开、折叠、后代记忆、加载与 consumer 动作边界                     |
| [view.md](view.md)                  | View 生命周期、默认键位与 Visual 圈选                              |
| [indentline.md](indentline.md)      | 正文、viewport 装饰、压缩链与结构导航                              |
| [results.md](../../feat/results.md) | 业务 records 与 List/Picker/Searcher/Diffview/LSP 接入             |

句柄与术语见 [module.md](module.md#句柄)。

## 规范边界

- 每条契约只在所属文档定义，其他文档链接引用；总体协议见 `module.md`，算法与细节以对应专题为准。
- Consumer 业务各在 feat 文档定义，通过链接引用这里的契约：
  [Explorer](../../feat/explorer/README.md) 定义键位、用途与 UI 文案；[Filetree](../filetree/README.md) 定义资源、文件 Job 与自有限额；
  [Git Files](../../feat/git-files.md) 定义 Git 文件列表与操作。文件操作名称、资源 identity 与用途不进入通用标记算法。
- 性能目标保留在 Design，具体版本的实验数据保留在[测量记录](../../../../__test__/bench/treeview/README.md)。
  VFS、跨重启恢复等未确认范围保留在 [UX Draft](../../../draft/ux.md)。
