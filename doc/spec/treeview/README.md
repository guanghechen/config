# Treeview 设计

本目录是 Treeview 契约的唯一权威位置。下列专题均为 `Design`；未确认的提案须单独标为 `Draft`。

## 当前实现

Rust core 位于 `rust/yoz/src/ux/treeview/`，Lua 入口为 `yoz.ux.treeview` 和 `require("ux.treeview")`。
Data 持有 source topology；State 持有 selection、expansion、display root 与逻辑 cursor；Frame 提供不可变行映射。
Lua 负责输入、窗口、buffer、业务 metadata 和 viewport decorations，不维护第二套交互树。

| Consumer                                                   | 数据路径                                                          |
| ---------------------------------------------------------- | ----------------------------------------------------------------- |
| Explorer                                                   | native Filetree Data；native Explorer policy 解释浏览、用途与 Job |
| Find Explorer、目录 preview                                | 共享 Filetree Data，各自使用单层 List State                       |
| 文件 Picker、Searcher、diagnostics、LSP symbols/references | Lua producer 准备业务 records，经 ResultTree 导入 native Data     |
| 普通 List、AI 多选 picker                                  | ResultTree；多选标记与确认结果使用同一 native selection           |
| Diffview                                                   | Git 结果经 `pane/tree.lua` 准备 records，交由 ResultTree 发布     |

结果集不因展示层级而扫描真实目录。Explorer、Find Explorer 和文件 Picker 的文件修改统一使用 Filetree Jobs。
接入步骤见 [Treeview 接入](../../treeview.md)，业务 records、匹配与发布边界见 [结果集](results.md)。

## 文档导航

| 文档                                 | 职责                                             |
| ------------------------------------ | ------------------------------------------------ |
| [module.md](module.md)               | 句柄、命令、revision、snapshot 与生命周期        |
| [data.md](data.md)                   | Provider key、更新范围、导入与所有权             |
| [action.md](action.md)               | 串行提交、Future、读取队列与容量恢复             |
| [projection.md](projection.md)       | Tree/List、filter/sort、文本与缓存               |
| [render.md](render.md)               | 增量投影、正文 splice、装饰与发布恢复            |
| [performance.md](performance.md)     | 成本边界、测量口径与验收目标                     |
| [query.md](query.md)                 | Native Query 会话、generation、取消与分页        |
| [stamps.md](stamps.md)               | Selection/expansion 共用标记算法                 |
| [selection.md](selection.md)         | 选择范围、聚合、源项准备与清理                   |
| [job-discovery.md](job-discovery.md) | Native Job 私有遍历的节点准入                    |
| [expansion.md](expansion.md)         | 展开、折叠、后代记忆与加载                       |
| [roots.md](roots.md)                 | 展示入口、topology 归并与失效                    |
| [visual.md](visual.md)               | 圈选持帧、输入提交与 view 生命周期               |
| [indentline.md](indentline.md)       | 缩进、压缩链、结构导航与 cursor                  |
| [results.md](results.md)             | 业务 records、List/Picker/Searcher/Diffview 接入 |

## 规范边界

- 总体协议由 `module.md` 定义，算法和细节以对应专题为准；其他设计文档通过链接引用，不复制契约。
- [Explorer Design](../../../spec/design/feat/explorer.md) 与 [Filetree Design](../../../spec/design/filetree.md) 保留各自的业务说明；
  它们通过链接引用这里的 Treeview 契约，文件操作名称、资源 identity 与用途不进入通用标记算法。
- 性能目标保留在 Design，具体版本的实验数据保留在[测量记录](../../../__test__/bench/treeview.md)。
  VFS、跨重启恢复等未确认范围分别保留在 Filetree/Explorer Draft。
