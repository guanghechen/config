# Treeview 设计

下列专题均为 `Design`；未确认的提案放在 `spec/draft/` 并标为 `Draft`。

## 当前实现

Rust core 位于 `rust/yoz/src/ux/treeview/`，Lua 入口为 `yoz.ux.treeview` 和 `require("ux.treeview")`。
Data 持有 source topology；State 持有 selection、expansion、display root 与逻辑 cursor；Frame 提供不可变行映射。
Lua 负责输入、窗口、buffer、业务 metadata 和 viewport decorations，不维护第二套交互树。

| Consumer                                                   | 数据路径                                                                                              |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Explorer                                                   | native Filetree Data；native Explorer policy 解释浏览、用途与 Job                                     |
| Find Explorer、目录 preview                                | 共享 Filetree Data，各自使用单层 List State                                                           |
| 文件 Picker、Searcher、diagnostics、LSP symbols/references | Lua producer 准备业务 records，经 ResultTree 导入 native Data                                         |
| 普通 List、AI 多选 picker                                  | ResultTree；多选标记与确认结果使用同一 native selection                                               |
| Diffview                                                   | Git 结果经 `pane/tree.lua` 准备 records，交由 ResultTree 发布                                         |
| Git Files                                                  | Staged / Unstaged 两棵 `era.view.GitFiles`（ResultFiles）树，业务见 [Git Files](../feat/git-files.md) |

结果集不因展示层级而扫描真实目录。Explorer、Find Explorer、文件 Picker 的文件修改及 Diffview 的 untracked discard
统一使用 Filetree Jobs；Git tracked 文件的 discard 由 Git 领域处理。

## 文档导航

| 文档                             | 职责                                                                        |
| -------------------------------- | --------------------------------------------------------------------------- |
| [integration.md](integration.md) | 接入步骤、最小示例与验证命令                                                |
| [module.md](module.md)           | 句柄、命令、revision、effect 交付与 Lua API 索引                            |
| [data.md](data.md)               | Provider key、写入范围、快照/增量/分块导入与所有权                          |
| [action.md](action.md)           | 串行提交、Future、投影批次、读取调度、背压与默认容量                        |
| [projection.md](projection.md)   | Tree/List、DisplayOptions、filter/sort、文本与缓存                          |
| [render.md](render.md)           | 局部更新、RenderPlan、Lua 发布与节奏、失败恢复、cursor 回退与 viewport 装饰 |
| [performance.md](performance.md) | 成本边界、测量口径与验收目标                                                |
| [query.md](query.md)             | Query 会话、generation、取消与分页（已实现，当前无生产 consumer）           |
| [stamps.md](stamps.md)           | Selection/expansion 共用标记算法                                            |
| [selection.md](selection.md)     | 选择状态、交互、聚合、判空与 Lua API                                        |
| [tasks.md](tasks.md)             | 选区锁、源项准备、cleanup context、授权更新与 native Job discovery          |
| [expansion.md](expansion.md)     | 展开、折叠、后代记忆、加载与 consumer 动作边界                              |
| [roots.md](roots.md)             | 展示入口、topology 归并与失效                                               |
| [visual.md](visual.md)           | 圈选持帧、输入提交与 view 生命周期                                          |
| [indentline.md](indentline.md)   | 正文缩进与装饰、压缩链与结构导航                                            |
| [results.md](results.md)         | 业务 records 与 List/Picker/Searcher/Diffview/LSP 接入                      |

## 术语

| 术语                                | 含义                                                                                                                 |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Data / owner                        | 一个 DataHandle 及其串行提交线程，唯一持有 Source 与全部 State                                                       |
| Source                              | 某个 data revision 的不可变 topology 与节点数据；旧 Source 可被 Frame 或任务继续持有。文中 snapshot 只泛指不可变版本 |
| State                               | 绑定一份 Data 的交互状态：display root、DisplayOptions、cursor、selection、expansion、用途与锁                       |
| Frame                               | 固定 Source、State 与投影结果的不可变行映射，Lua 行输入以它为准；`state:snapshot()` 与 `view:frame()` 返回 Frame     |
| View / surface                      | View 是 State 在一个窗口中的 surface 连接；surface 指 Lua 侧的 buffer、窗口与装饰发布                                |
| Feature commit                      | Consumer `prepare_frame` 返回的提交回调，与 Frame 一起发布该 viewport 的业务装饰                                     |
| Display root                        | State 的展示入口：`ChildrenOf(node)` 展示某节点的直接 children，`Forest(nodes)` 展示一组节点                         |
| `subtree_roots` / `self_only_nodes` | Selection 的两组派生集合，见 [selection.md](selection.md#状态与派生集合)                                             |
| `selection_purpose`                 | Consumer 解释的不透明用途字符串，与 selection 原子发布                                                               |
| Task                                | 持有选区锁、准备源项并在结束时清理与解锁的任务，见 [tasks.md](tasks.md)                                              |
| Provider / 写入范围                 | 独占一段 Source 范围的写入者，见 [data.md](data.md#写入范围)                                                         |
| Query 会话                          | Provider 的查询生命周期，见 [query.md](query.md)                                                                     |
| Revision                            | `commit`、`data`、`state`、`selection` 与 `layout_revision`，定义见 [module.md](module.md#revision-与过期输入)       |

`core/feature envelope` 不再使用；需要同时描述两者时写“Frame 及其 feature commit”。
标记字段与代码名称的对应见 [stamps.md](stamps.md#独立状态与版本)。

## 规范边界

- 每条契约只在所属文档定义，其他文档链接引用；总体协议见 `module.md`，算法与细节以对应专题为准。
- Consumer 业务各在 feat 文档定义，通过链接引用这里的契约：
  [Explorer](../feat/explorer.md) 定义键位、用途与 UI 文案；[Filetree](../filetree.md) 定义资源、文件 Job 与自有限额；
  [Git Files](../feat/git-files.md) 定义 Git 文件列表与操作。文件操作名称、资源 identity 与用途不进入通用标记算法。
- 性能目标保留在 Design，具体版本的实验数据保留在[测量记录](../../../__test__/bench/treeview.md)。
  VFS、跨重启恢复等未确认范围分别保留在 Filetree/Explorer Draft。
