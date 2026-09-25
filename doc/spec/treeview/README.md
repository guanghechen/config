# Treeview 设计

本目录是 Treeview 规范的权威位置，统一收录 Rust 交互树与现有 Lua layout 工具的契约。
`Design` 表示已确认的设计，`Draft` 表示仍需审阅的设计提案或接入说明；设计状态不代表 runtime 已实现或切换。

## API 关系

- `stl.c.Tree` 与 `stl.view.treeview.layout` 使用 [Lua Tree / TreeLayout 契约](lua-layout.md)：
  Tree 管理结构，layout 纯计算可见行和导航；使用该 API 的 feature 持有自己的交互状态与 surface。
- `yoz.ux.treeview` 使用 [Rust Treeview 核心契约](module.md)：data owner 提供真实 topology，
  Treeview state 持有 selection、expansion、display root 和逻辑 cursor，Lua 负责输入与 surface。
- 新 Explorer 使用 Rust Treeview；其 Lua surface 不再保存另一份权威 selection/expansion。
  Picker、Searcher、Diffview 等调用方在使用 Lua API 时继续遵循 Lua 契约。
- 两个 API 的输入、状态所有权与生命周期不同，按各自契约并存。Consumer 接入 Rust Treeview 时，
  一起明确 data/state 与 surface 的职责，不将旧 layout 调用直接当作新 API 的别名。

## 文档导航

| 文档                               | 范围                                                          | 状态   |
| ---------------------------------- | ------------------------------------------------------------- | ------ |
| [module.md](module.md)             | Rust Treeview 的句柄、更新、命令、请求、snapshot 与生命周期   | Design |
| [data.md](data.md)                 | 通用 data owner、provider key、更新范围与 Rust/Lua 数据交接   | Design |
| [action.md](action.md)             | 命令与异步结果的串行提交、Future、读取队列及预算恢复          | Design |
| [projection.md](projection.md)     | Source ground truth、Tree/List 投影、filter/sort 与缓存有效性 | Design |
| [render.md](render.md)             | 增量投影、正文 splice、可见区域装饰与发布恢复                 | Design |
| [performance.md](performance.md)   | 成本边界、延迟目标、压力档与合计内存验收                      | Design |
| [query.md](query.md)               | Provider 查询会话、generation、取消、结果替换与分页           | Design |
| [stamps.md](stamps.md)             | Selection/expansion 共用的版本标记、继承、查询与 reparent     | Design |
| [selection.md](selection.md)       | Recursive 选择范围、标记聚合、源项准备与任务结果清理          | Design |
| [expansion.md](expansion.md)       | 普通/递归展开折叠、后代记忆与异步加载                         | Design |
| [roots.md](roots.md)               | 显式展示入口、topology 归并与入口生命周期                     | Design |
| [visual.md](visual.md)             | 稳定圈选布局、输入提交、重绘与 view 生命周期                  | Design |
| [indentline.md](indentline.md)     | 缩进、压缩链、结构导航与 cursor 恢复                          | Design |
| [multi-select.md](multi-select.md) | Explorer 的选区用途、按键、callback 与任务接入说明            | Draft  |
| [lua-layout.md](lua-layout.md)     | 现有 Lua Tree、纯 layout、TreeLayout 与 renderer 边界         | Design |

## 规范边界

- 核心运行协议由 `module.md` 定义，各状态与交互规则由对应专题定义；同一算法只在所属专题中维护。
  `multi-select.md` 引用核心规范，保留 Explorer 接入与尚未定案的业务边界，不另建一套标记算法。
- 本目录外的设计索引只提供导航，不保存 Treeview 的规范副本。目录内的 draft 与未决部分显式标记，
  不因相邻文档已经定稿而自动成为已确认决策。
- [Explorer Design](../../../spec/design/feat/explorer.md) 与 [Filetree](../filetree/module.md) 保留各自的业务说明；
  它们通过链接引用这里的 Treeview 契约，文件操作名称、资源 identity 与用途不进入通用标记算法。
- 本目录按用户指定作为 Treeview 的独立归档位置；仓库默认的 `spec/design/` / `spec/draft/`
  目录规则对 Treeview 使用这一明确例外。
