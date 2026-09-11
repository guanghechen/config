# Notepad 设计

`era.m.notepad` 提供 Markdown 便签、浮动编辑窗口和 nvimbar 导航。
便签按 source 隔离，每个 source 使用 `folder` 或 `json` storage engine。

## 模块边界

| 模块                                      | 职责                                          |
| ----------------------------------------- | --------------------------------------------- |
| `lua/era/m/notepad/state.lua`             | Source 配置、实例缓存、名称索引与当前便签通知 |
| `lua/era/m/notepad/source-folder.lua`     | Markdown 文件与 metadata 存储                 |
| `lua/era/m/notepad/source-json.lua`       | 单 JSON 文件存储                              |
| `lua/era/m/notepad/view.lua`              | 编辑 buffer、浮窗、内容同步与 nvimbar 组装    |
| `lua/era/m/notepad/action.lua`            | 用户命令、picker、输入与确认交互              |
| `lua/era/m/nvimbar/component/notepad.lua` | 便签列表、新增按钮与 source 切换入口          |
| `lua/era/m/notepad/types.lua`             | Source、item 与持久化数据类型                 |

## Source 与数据

Source 配置以 `name` 为唯一标识，包含 `title`、`engine`、`filepath` 与 `default_item_name`。
当前内置 sources 均使用 `folder`：

| Source            | 路径解析                                                    |
| ----------------- | ----------------------------------------------------------- |
| `workspace:local` | `dot.path.locate_workspace_config(".neovim/notepad/local")` |
| `workspace:notes` | `dot.path.locate_workspace_config(".neovim/notepad/notes")` |
| `shared:notes`    | `dot.path.locate_shared_filepath("notepad/notes")`          |

`state.retrieve_source(name)` 按需创建并缓存 source；未知名称回退到第一个配置。
当前 source 由 `dot.context.module.notepad_source` 保存。

每个 source 独立持有：

- `items`：按 UUID 索引的便签；metadata 为 `uuid/name`，内容状态为 `content/original`，未加载内容可为 nil。
- `orders` 与 `active_uuid`：显示顺序及当前便签。
- `name_to_uuid`：名称索引。
- `note_uuid_history` 与 `history_index`：source 内的导航历史。

Source 提供 load/list/retrieve、create/update/rename/remove、activation、history、flush 与 JSON import/export。
创建同名便签返回已有项；rename 拒绝名称冲突；remove 拒绝删除最后一项。空白名称由 source 的默认名称规则处理。

`state.focus_note(uuid)` 更新当前 source 的 active UUID，并通过 `o_activated_uuid` 通知消费者。
Source 身份由容器持有，不要求每个 item 增加 `source` 字段。

## 持久化

- `folder`：便签写为 `.md`，名称先转换为 filesystem-safe filename；`.__notepad__` 保存 metadata。
- `json`：在一个文件中保存 `items`、`orders` 与 `activated_item_uuid`。
- 两个 engine 均使用 3000 ms debounce；`source:flush()` 强制落盘。
- Engine 切换通过 `dump_to_json()` / `load_from_json()` 传递统一数据，由 state 更新配置和 source cache。

View 切换 source 前同步当前 buffer 内容并 flush。Action 将保存、创建、重命名、删除与 source 选择
分派到 view/source，输入与确认使用 UI prompt，结果由 `stl.reporter` 报告。

## View 与 nvimbar

`era.m.notepad.View` 管理居中浮窗，按最小/最大尺寸限制和 theme winblend 布局。
编辑 buffer 为 unlisted、`nofile`、`bufhidden = "hide"`、可修改且关闭 swapfile。
默认 Notepad filetype 注册到 Markdown parser。

`TextChanged`、`TextChangedI`、`TextChangedP` 将内容同步到 source，并避免同步重入。
View 订阅 source 与 active UUID 变化，更新编辑内容和 winbar。

Nvimbar 使用 `dot.G` click callbacks；名称最多显示 12 个字符，附带 index badge、分隔符与新增按钮。
空间允许时居中显示当前项，溢出时显示左右导航箭头与隐藏数量；source 组件显示当前 source/engine。

## 命令与快捷键

命令定义位于 `dot.command.definitions.notepad`，由 `era.m.notepad.action` 执行。
映射为 buffer-local；下表列出主要交互，完整模式与 aliases 以 `view.lua` 为准。

| 按键                                                 | 行为                                                            |
| ---------------------------------------------------- | --------------------------------------------------------------- |
| `<C-s>`、`<C-a>s`；aliases `<D-s>`、`<M-s>`          | 保存                                                            |
| `<C-n>`                                              | 创建便签                                                        |
| `<C-/>`                                              | 重命名                                                          |
| `<C-d>`、`<leader>dd`                                | 删除                                                            |
| `<C-,>` / `<C-.>`                                    | 上一个 / 下一个 source                                          |
| `<C-[>` / `<C-]>`、`<leader>[` / `<leader>]`         | 上一个 / 下一个便签                                             |
| `<C-S-,>` / `<C-S-.>`；aliases `<C-S-[>` / `<C-S-]>` | 左右交换便签顺序                                                |
| `<C-1>`…`<C-9>`                                      | 按 index 选择便签                                               |
| `<leader>0` / `<leader>1` / `<leader>2`              | 切换 engine / 选择 source / 选择便签                            |
| `<M-i>` / `<M-o>`                                    | 后退 / 前进                                                     |
| `<leader><cr>`                                       | Normal 发送当前 split block，Visual 发送 selection，均提交给 AI |
| `q`                                                  | Normal mode 关闭窗口                                            |
